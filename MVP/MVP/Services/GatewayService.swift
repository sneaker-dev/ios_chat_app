import Foundation
import SystemConfiguration
import Network

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

/// Detects the default IPv4 gateway via SystemConfiguration (reads the same
/// routing data that iOS Settings → Wi-Fi shows as "Router").
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

    // MARK: - Gateway IP via SCDynamicStore

    /// Reads "State:/Network/Global/IPv4" → "Router" from the system network
    /// configuration store. This is the exact same value iOS Settings shows
    /// under Wi-Fi → Router. Returns nil when no default route exists.
    private func defaultGatewayIPv4() -> String? {
        guard let store = SCDynamicStoreCreate(nil, "GatewayService" as CFString, nil, nil) else {
            return nil
        }
        let key = "State:/Network/Global/IPv4" as CFString
        guard let val = SCDynamicStoreCopyValue(store, key) as? [String: Any] else {
            return nil
        }
        return val["Router"] as? String
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
                case .ready:
                    finish(true)
                case .failed, .cancelled:
                    finish(false)
                default:
                    break
                }
            }
            connection.start(queue: .global(qos: .userInitiated))
            // 4-second hard timeout
            DispatchQueue.global().asyncAfter(deadline: .now() + 4) {
                finish(false)
            }
        }
    }
}
