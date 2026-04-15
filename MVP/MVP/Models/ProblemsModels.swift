import Foundation

// MARK: - Catalog

struct ProblemCatalogItem: Codable, Identifiable {
    let key: String
    let title: String
    let summary: String
    let implementationStatus: String
    /// End-user-facing line from `GET /api/v1/problems/catalog` (optional; Redmine #45250).
    let description: String?

    var id: String { key }

    enum CodingKeys: String, CodingKey {
        case key, title, summary, description
        case implementationStatus = "implementation_status"
    }
}

struct ProblemCatalogResponse: Codable {
    let items: [ProblemCatalogItem]
}

// MARK: - Active problems

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
    let description: String?

    enum CodingKeys: String, CodingKey {
        case key, title, summary, enabled, note, description
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
        case deviceId      = "device_id"
        case activeProblems = "active_problems"
    }
}

// MARK: - Toggle

struct ProblemToggleResponse: Codable {
    let deviceId: String
    let problem: ActiveProblemState

    enum CodingKeys: String, CodingKey {
        case deviceId = "device_id"
        case problem
    }
}
