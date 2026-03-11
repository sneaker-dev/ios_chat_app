import Foundation

enum AvatarType: String, CaseIterable, Codable {
    case male
    case female

    var displayName: String {
        switch self {
        case .male: return "Male"
        case .female: return "Female"
        }
    }

    var assetId: String { rawValue }

    var isFemale: Bool { self == .female }
}

enum AvatarAnimState: Equatable {
    case idle
    case thinking
    case speaking
}
