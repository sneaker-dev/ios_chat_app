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

    // Reads the actual default-route gateway from the kernel routing table via sysctl.
    // Uses raw byte offsets so no <net/route.h> bridging header is required.
    // rt_msghdr layout on iOS (both 32-bit and 64-bit, pid_t = Int32):
    //   offset  0: rtm_msglen  (UInt16)
    //   offset  2: rtm_version (UInt8)
    //   offset  3: rtm_type    (UInt8)
    //   offset  4: rtm_index   (UInt16)
    //   offset  6: padding     (2 bytes)
    //   offset  8: rtm_flags   (Int32)
    //   offset 12: rtm_addrs   (Int32)
    //   offset 16..91: pid, seq, errno, use, inits, rt_metrics (76 bytes)
    //   total: 92 bytes
    private func gatewayFromRoutingTable() -> String? {
        // Routing constants from <net/route.h> — defined here to avoid bridging header.
        let rtfGateway: Int32 = 0x2   // RTF_GATEWAY
        let rtaDst:     Int32 = 0x1   // RTA_DST
        let rtaGateway: Int32 = 0x2   // RTA_GATEWAY
        let rtMsgHdrSize      = 92    // sizeof(rt_msghdr) — fixed on iOS

        var mib: [Int32] = [CTL_NET, PF_ROUTE, 0, AF_INET, NET_RT_FLAGS, rtfGateway]
        var needed = 0
        guard sysctl(&mib, 6, nil, &needed, nil, 0) == 0, needed > 0 else { return nil }
        var buf = [UInt8](repeating: 0, count: needed)
        guard sysctl(&mib, 6, &buf, &needed, nil, 0) == 0 else { return nil }

        let wordSize = MemoryLayout<Int>.size  // 8 on 64-bit iOS
        var pos = 0

        while pos + rtMsgHdrSize <= needed {
            // Read msglen, flags, addrs directly by byte offset.
            let msgLen = Int(buf.withUnsafeBytes {
                $0.load(fromByteOffset: pos, as: UInt16.self)
            })
            guard msgLen > 0, pos + msgLen <= needed else { break }

            let flags = buf.withUnsafeBytes { $0.load(fromByteOffset: pos + 8,  as: Int32.self) }
            let addrs = buf.withUnsafeBytes { $0.load(fromByteOffset: pos + 12, as: Int32.self) }

            if (flags & rtfGateway) != 0 && (addrs & rtaDst) != 0 && (addrs & rtaGateway) != 0 {
                let addrBase = pos + rtMsgHdrSize

                // sockaddr layout: offset 0 = sa_len (UInt8), offset 1 = sa_family (UInt8)
                // sockaddr_in:     offset 4 = sin_addr (4 bytes, network byte order)
                guard addrBase + 8 <= needed else { pos += msgLen; continue }

                let dstFamily = buf[addrBase + 1]
                if dstFamily == UInt8(AF_INET) {
                    // sin_addr is at offset 4 within sockaddr_in; 0 means 0.0.0.0 (default route)
                    let dstAddr = buf.withUnsafeBytes {
                        $0.load(fromByteOffset: addrBase + 4, as: UInt32.self)
                    }
                    if dstAddr == 0 {
                        // Advance past dst sockaddr using Darwin ROUNDUP to wordSize.
                        let dstSaLen = Int(buf[addrBase])
                        let dstAligned = dstSaLen > 0
                            ? 1 + ((dstSaLen - 1) | (wordSize - 1))
                            : wordSize
                        let gwBase = addrBase + dstAligned

                        guard gwBase + 8 <= pos + msgLen else { pos += msgLen; continue }

                        let gwFamily = buf[gwBase + 1]
                        if gwFamily == UInt8(AF_INET) {
                            var gwAddr = buf.withUnsafeBytes {
                                $0.load(fromByteOffset: gwBase + 4, as: in_addr.self)
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
