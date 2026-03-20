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

/// Detects the default IPv4 gateway by parsing the BSD kernel routing table
/// via sysctl — fully available on iOS, no macOS-only frameworks required.
final class GatewayService {

    static let shared = GatewayService()
    private init() {}

    // MARK: - Public API

    /// Resolves the default gateway and probes port 80 reachability.
    /// Always returns on the main actor.
    func resolve() async -> GatewayResult {
        guard let ip = defaultGatewayIPv4() else {
            return .notOnLAN
        }
        let reachable = await probePort80(host: ip)
        return reachable ? .found(ip: ip) : .unreachable(ip: ip)
    }

    // MARK: - Gateway IP via sysctl routing table

    /// Reads the kernel routing table (NET_RT_FLAGS / RTF_GATEWAY) and returns
    /// the gateway address of the default route (destination 0.0.0.0).
    /// This is identical to what `netstat -rn` reports as the default route.
    private func defaultGatewayIPv4() -> String? {
        var mib: [Int32] = [CTL_NET, PF_ROUTE, 0, AF_INET, NET_RT_FLAGS, RTF_GATEWAY]
        var needed = 0

        guard sysctl(&mib, UInt32(mib.count), nil, &needed, nil, 0) == 0, needed > 0 else {
            return nil
        }

        var buf = [UInt8](repeating: 0, count: needed)
        guard sysctl(&mib, UInt32(mib.count), &buf, &needed, nil, 0) == 0 else {
            return nil
        }

        return buf.withUnsafeBytes { raw -> String? in
            var offset = 0
            while offset + MemoryLayout<rt_msghdr>.size <= needed {
                let msg = raw.load(fromByteOffset: offset, as: rt_msghdr.self)
                let msgLen = Int(msg.rtm_msglen)
                guard msgLen > 0 else { break }
                defer { offset += msgLen }

                // Must have both destination and gateway sockaddrs
                guard msg.rtm_addrs & RTA_DST != 0,
                      msg.rtm_addrs & RTA_GATEWAY != 0 else { continue }

                // sockaddrs are packed immediately after rt_msghdr
                var addrOff = offset + MemoryLayout<rt_msghdr>.size
                var dstIsDefault = false
                var gatewayIP: String? = nil

                for bit in 0 ..< RTAX_MAX {
                    guard msg.rtm_addrs & (1 << bit) != 0 else { continue }
                    guard addrOff + MemoryLayout<sockaddr>.size <= needed else { break }

                    let sa = raw.load(fromByteOffset: addrOff, as: sockaddr.self)
                    // sa_len = 0 means the sockaddr uses the minimum struct size
                    let saLen = Int(sa.sa_len) > 0 ? Int(sa.sa_len) : MemoryLayout<sockaddr>.size

                    if bit == RTAX_DST, sa.sa_family == UInt8(AF_INET) {
                        let sin = raw.load(fromByteOffset: addrOff, as: sockaddr_in.self)
                        // Default route has destination address 0.0.0.0
                        dstIsDefault = sin.sin_addr.s_addr == 0
                    }

                    if bit == RTAX_GATEWAY, sa.sa_family == UInt8(AF_INET) {
                        var sin = raw.load(fromByteOffset: addrOff, as: sockaddr_in.self)
                        var chars = [CChar](repeating: 0, count: Int(INET_ADDRSTRLEN))
                        if inet_ntop(AF_INET, &sin.sin_addr, &chars, socklen_t(INET_ADDRSTRLEN)) != nil {
                            gatewayIP = String(cString: chars)
                        }
                    }

                    // sockaddrs in routing messages are 4-byte aligned
                    addrOff += (saLen + 3) & ~3
                }

                if dstIsDefault, let gw = gatewayIP {
                    return gw
                }
            }
            return nil
        }
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
                case .ready:          finish(true)
                case .failed, .cancelled: finish(false)
                default: break
                }
            }
            connection.start(queue: .global(qos: .userInitiated))
            DispatchQueue.global().asyncAfter(deadline: .now() + 4) { finish(false) }
        }
    }
}
