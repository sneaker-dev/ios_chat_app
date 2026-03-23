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
        gatewayFromRoutingTable() ?? gatewayFromInterface()
    }

    // Reads the actual default-route gateway from the kernel routing table.
    // This is the correct approach: the gateway address is not always .1.
    private func gatewayFromRoutingTable() -> String? {
        var mib: [Int32] = [CTL_NET, PF_ROUTE, 0, AF_INET, NET_RT_FLAGS, RTF_GATEWAY]
        var needed = 0
        guard sysctl(&mib, 6, nil, &needed, nil, 0) == 0, needed > 0 else { return nil }
        var buf = [UInt8](repeating: 0, count: needed)
        guard sysctl(&mib, 6, &buf, &needed, nil, 0) == 0 else { return nil }

        let rtMsgSize = MemoryLayout<rt_msghdr>.size
        let wordSize  = MemoryLayout<Int>.size   // 8 on 64-bit iOS
        var pos = 0

        while pos + rtMsgSize <= needed {
            let (msgLen, addrs, flags) = buf.withUnsafeBytes { ptr -> (Int, Int32, Int32) in
                let hdr = ptr.load(fromByteOffset: pos, as: rt_msghdr.self)
                return (Int(hdr.rtm_msglen), hdr.rtm_addrs, hdr.rtm_flags)
            }
            guard msgLen > 0, pos + msgLen <= needed else { break }

            let isGatewayRoute = (flags & RTF_GATEWAY) != 0
            let hasDst         = (addrs & RTA_DST)     != 0
            let hasGW          = (addrs & RTA_GATEWAY) != 0

            if isGatewayRoute && hasDst && hasGW {
                let addrBase = pos + rtMsgSize

                // First sockaddr after rt_msghdr is RTA_DST.
                let dstFamily = buf.withUnsafeBytes {
                    $0.load(fromByteOffset: addrBase + 1, as: UInt8.self)
                }
                if dstFamily == UInt8(AF_INET) {
                    let dstAddr = buf.withUnsafeBytes {
                        $0.load(fromByteOffset: addrBase, as: sockaddr_in.self).sin_addr.s_addr
                    }
                    // Only the default route has destination 0.0.0.0
                    if dstAddr == 0 {
                        let dstLen = buf.withUnsafeBytes {
                            Int($0.load(fromByteOffset: addrBase, as: sockaddr.self).sa_len)
                        }
                        // Darwin ROUNDUP: align to wordSize boundary
                        let dstAligned = dstLen > 0
                            ? 1 + ((dstLen - 1) | (wordSize - 1))
                            : wordSize
                        let gwBase = addrBase + dstAligned

                        guard gwBase + MemoryLayout<sockaddr_in>.size <= pos + msgLen else {
                            pos += msgLen; continue
                        }
                        let gwFamily = buf.withUnsafeBytes {
                            $0.load(fromByteOffset: gwBase + 1, as: UInt8.self)
                        }
                        if gwFamily == UInt8(AF_INET) {
                            var gwAddr = buf.withUnsafeBytes {
                                $0.load(fromByteOffset: gwBase, as: sockaddr_in.self).sin_addr
                            }
                            var out = [CChar](repeating: 0, count: Int(INET_ADDRSTRLEN))
                            if inet_ntop(AF_INET, &gwAddr, &out, socklen_t(INET_ADDRSTRLEN)) != nil {
                                return String(cString: out)
                            }
                        }
                    }
                }
            }
            pos += msgLen
        }
        return nil
    }

    // Fallback: derive gateway from interface address and netmask.
    // Less accurate — assumes gateway is the first host in the subnet.
    private func gatewayFromInterface() -> String? {
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
            let gatewayBE   = (networkHost + 1).bigEndian

            var gwIn = in_addr(s_addr: gatewayBE)
            var out  = [CChar](repeating: 0, count: Int(INET_ADDRSTRLEN))
            guard inet_ntop(AF_INET, &gwIn, &out, socklen_t(INET_ADDRSTRLEN)) != nil else { continue }
            return String(cString: out)
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
