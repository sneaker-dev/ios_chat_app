//
//  AvatarType.swift
//  MVP
//
//  v2.0: Enhanced with avatar state management matching Android app

import Foundation

/// Predefined avatar options (male / female). Extensible for future avatars.
enum AvatarType: String, CaseIterable, Codable {
    case male
    case female

    var displayName: String {
        switch self {
        case .male: return "Male"
        case .female: return "Female"
        }
    }

    /// Asset or identifier for this avatar (for future lip-sync / assets).
    var assetId: String { rawValue }
    
    /// Whether this avatar is female
    var isFemale: Bool { self == .female }
}

/// Avatar animation state matching Android's AvatarState enum
enum AvatarAnimState: Equatable {
    case idle
    case thinking
    case speaking
}
