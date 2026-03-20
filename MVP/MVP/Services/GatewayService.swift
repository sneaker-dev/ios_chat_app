import Foundation
import Network
import Darwin

// MARK: - Result types

enum GatewayResult {
    /// Device is on a LAN and the gateway IP was resolved.
    case found(ip: String)
    /// Device has no active LAN connection (cellular-only or airplane mode).
    case notOnLAN
    /// Gateway was found but port 80 did not respond within the timeout.
    case unreachable(ip: String)
}

// MARK: - GatewayService

/// Detects the default IPv4 gateway and probes port 80 reachability.
///
/// Gateway detection uses getifaddrs() to read the WiFi interface (en0)
/// address and subnet mask, then computes gateway = (ip & mask) + 1.
/// This is the standard convention used by virtually all home and office
/// routers (192.168.x.1, 10.x.x.1, etc.) and requires no private APIs.
final class GatewayService {

    static let shared = GatewayService()
    private init() {}

    // MARK: - Public API

    /// Resolves the default gateway and probes port 80 reachability.
    func resolve() async -> GatewayResult {
        guard let ip = defaultGatewayIPv4() else {
            return .notOnLAN
        }
        let reachable = await probePort80(host: ip)
        return reachable ? .found(ip: ip) : .unreachable(ip: ip)
    }

    // MARK: - Gateway IP via getifaddrs

    /// Finds the primary WiFi interface (en0), reads its IPv4 address and
    /// subnet mask, then returns (address & mask) + 1 as the gateway.
    ///
    /// Examples:
    ///   192.168.1.42 / 255.255.255.0  →  gateway 192.168.1.1
    ///   10.0.0.55    / 255.255.255.0  →  gateway 10.0.0.1
    private func defaultGatewayIPv4() -> String? {
        var ifaddr: UnsafeMutablePointer<ifaddrs>? = nil
        guard getifaddrs(&ifaddr) == 0 else { return nil }
        defer { freeifaddrs(ifaddr) }

        var cursor = ifaddr
        while let ifa = cursor {
            defer { cursor = ifa.pointee.ifa_next }

            // en0 is the primary WiFi adapter on all iOS devices
            let name = String(cString: ifa.pointee.ifa_name)
            guard name == "en0",
                  let addrPtr = ifa.pointee.ifa_addr,
                  let maskPtr = ifa.pointee.ifa_netmask,
                  addrPtr.pointee.sa_family == UInt8(AF_INET)
            else { continue }

            let sin  = addrPtr.withMemoryRebound(to: sockaddr_in.self, capacity: 1) { $0.pointee }
            let mask = maskPtr.withMemoryRebound(to: sockaddr_in.self, capacity: 1) { $0.pointee }

            // Both values are in network byte order (big-endian).
            // Convert to host order, compute network base, add 1, convert back.
            let ipHost  = UInt32(bigEndian: sin.sin_addr.s_addr)
            let maskHost = UInt32(bigEndian: mask.sin_addr.s_addr)
            let networkHost  = ipHost & maskHost
            let gatewayHost  = networkHost + 1          // .1 on the subnet
            let gatewayBE    = gatewayHost.bigEndian

            var gwIn = in_addr(s_addr: gatewayBE)
            var buf  = [CChar](repeating: 0, count: Int(INET_ADDRSTRLEN))
            guard inet_ntop(AF_INET, &gwIn, &buf, socklen_t(INET_ADDRSTRLEN)) != nil else { continue }
            return String(cString: buf)
        }
        return nil
    }

    // MARK: - TCP port-80 probe

    /// Attempts a TCP connection to <host>:80 with a 4-second timeout.
    /// Returns true if the connection succeeds (HTTP server is listening).
    private func probePort80(host: String) async -> Bool {
        await withCheckedContinuation { continuation in
            let connection = NWConnection(
                host: NWEndpoint.Host(host),
                port: 80,
                using: .tcp
            )
            var finished = false
            let finish: (Bool) -> Void = { result in
                guard !finished else { return }
                finished = true
                connection.cancel()
                continuation.resume(returning: result)
            }
            connection.stateUpdateHandler = { state in
                switch state {
                case .ready:              finish(true)
                case .failed, .cancelled: finish(false)
                default: break
                }
            }
            connection.start(queue: .global(qos: .userInitiated))
            DispatchQueue.global().asyncAfter(deadline: .now() + 4) { finish(false) }
        }
    }
}
