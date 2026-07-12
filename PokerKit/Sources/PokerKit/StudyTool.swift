import Foundation

/// One of the off-table study tools the app is built around.
public enum StudyTool: String, CaseIterable, Identifiable, Hashable, Sendable {
    case preflopRanges
    case icmPushFold
    case bankroll
    case handHistoryImport
    case drills

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .preflopRanges: return "Preflop Ranges"
        case .icmPushFold: return "ICM / Push-Fold Trainer"
        case .bankroll: return "Bankroll Tracker"
        case .handHistoryImport: return "Hand History Import & Leaks"
        case .drills: return "Drills"
        }
    }

    public var summary: String {
        switch self {
        case .preflopRanges:
            return "Build and review opening/3-bet/4-bet ranges by position and stack depth."
        case .icmPushFold:
            return "Push/fold and calling drills weighted by ICM pressure near the bubble and at final tables."
        case .bankroll:
            return "Buy-ins, cashes, ROI, variance, and bankroll-management guardrails for MTTs."
        case .handHistoryImport:
            return "Parse PokerStars hand histories and surface your recurring leaks."
        case .drills:
            return "Short, repeatable off-table exercises built from your own leaks and hand history."
        }
    }
}
