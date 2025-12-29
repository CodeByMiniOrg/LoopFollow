// LoopFollow
// TabPosition.swift

enum TabPosition: String, CaseIterable, Codable, Comparable {
    case position1
    case position2
    case position3
    case position4
    case position5
    case more
    case disabled

    var displayName: String {
        switch self {
        case .position1: return "Tab 1"
        case .position2: return "Tab 2"
        case .position3: return "Tab 3"
        case .position4: return "Tab 4"
        case .position5: return "Tab 5"
        case .more: return "More Menu"
        case .disabled: return "Hidden"
        }
    }

    /// The index in the tab bar (0-based)
    var tabIndex: Int? {
        switch self {
        case .position1: return 0
        case .position2: return 1
        case .position3: return 2
        case .position4: return 3
        case .position5: return 4
        case .more, .disabled: return nil
        }
    }

    /// Positions that represent actual tab bar slots
    static var tabBarPositions: [TabPosition] {
        [.position1, .position2, .position3, .position4, .position5]
    }

    // Comparable conformance for sorting
    static func < (lhs: TabPosition, rhs: TabPosition) -> Bool {
        let order: [TabPosition] = [.position1, .position2, .position3, .position4, .position5, .more, .disabled]
        guard let lhsIndex = order.firstIndex(of: lhs),
              let rhsIndex = order.firstIndex(of: rhs) else { return false }
        return lhsIndex < rhsIndex
    }
}

/// Represents a tab item that can be placed in any position
enum TabItem: String, CaseIterable, Codable, Identifiable {
    case home
    case alarms
    case remote
    case nightscout
    case snoozer
    case settings

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .home: return "Home"
        case .alarms: return "Alarms"
        case .remote: return "Remote"
        case .nightscout: return "Nightscout"
        case .snoozer: return "Snoozer"
        case .settings: return "Settings"
        }
    }

    var icon: String {
        switch self {
        case .home: return "house"
        case .alarms: return "alarm"
        case .remote: return "antenna.radiowaves.left.and.right"
        case .nightscout: return "safari"
        case .snoozer: return "zzz"
        case .settings: return "gear"
        }
    }
}
