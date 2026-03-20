import Foundation

struct ProblemCatalogItem: Codable, Identifiable {
    let key: String
    let title: String
    let summary: String
    let implementationStatus: String

    var id: String { key }

    enum CodingKeys: String, CodingKey {
        case key, title, summary
        case implementationStatus = "implementation_status"
    }
}

struct ProblemCatalogResponse: Codable {
    let items: [ProblemCatalogItem]
}

struct ActiveProblemState: Codable {
    let key: String
    let title: String
    let summary: String
    let implementationStatus: String
    let enabled: Bool
    let enabledAt: String?
    let updatedAt: String?
    let requestedBy: String?
    let note: String

    enum CodingKeys: String, CodingKey {
        case key, title, summary, enabled, note
        case implementationStatus = "implementation_status"
        case enabledAt            = "enabled_at"
        case updatedAt            = "updated_at"
        case requestedBy          = "requested_by"
    }
}

struct DeviceProblemsResponse: Codable {
    let deviceId: String
    let activeProblems: [ActiveProblemState]

    enum CodingKeys: String, CodingKey {
        case deviceId       = "device_id"
        case activeProblems = "active_problems"
    }
}

struct ProblemToggleResponse: Codable {
    let deviceId: String
    let problem: ActiveProblemState

    enum CodingKeys: String, CodingKey {
        case deviceId = "device_id"
        case problem
    }
}
