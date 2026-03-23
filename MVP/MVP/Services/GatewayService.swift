import Foundation
import Network
import Darwin

enum GatewayResult {
    case found(ip: String)
    case notOnLAN
    case unreachable(ip: String)
}

final class GatewayService {

    static let shared = GatewayService()
    private init() {}

    func resolve() async -> GatewayResult {
        guard let ip = defaultGatewayIPv4() else {
            return .notOnLAN
        }
        let reachable = await probePort80(host: ip)
        return reachable ? .found(ip: ip) : .unreachable(ip: ip)
    }

    private func defaultGatewayIPv4() -> String? {
        var ifaddr: UnsafeMutablePointer<ifaddrs>? = nil
        guard getifaddrs(&ifaddr) == 0 else { return nil }
        defer { freeifaddrs(ifaddr) }

        var cursor = ifaddr
        while let ifa = cursor {
            defer { cursor = ifa.pointee.ifa_next }

            let name = String(cString: ifa.pointee.ifa_name)
            guard name == "en0",
                  let addrPtr = ifa.pointee.ifa_addr,
                  let maskPtr = ifa.pointee.ifa_netmask,
                  addrPtr.pointee.sa_family == UInt8(AF_INET)
            else { continue }

            let sin  = addrPtr.withMemoryRebound(to: sockaddr_in.self, capacity: 1) { $0.pointee }
            let mask = maskPtr.withMemoryRebound(to: sockaddr_in.self, capacity: 1) { $0.pointee }

            let ipHost      = UInt32(bigEndian: sin.sin_addr.s_addr)
            let maskHost    = UInt32(bigEndian: mask.sin_addr.s_addr)
            let networkHost = ipHost & maskHost
            let gatewayHost = networkHost + 1
            let gatewayBE   = gatewayHost.bigEndian

            var gwIn = in_addr(s_addr: gatewayBE)
            var buf  = [CChar](repeating: 0, count: Int(INET_ADDRSTRLEN))
            guard inet_ntop(AF_INET, &gwIn, &buf, socklen_t(INET_ADDRSTRLEN)) != nil else { continue }
            return String(cString: buf)
        }
        return nil
    }

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
