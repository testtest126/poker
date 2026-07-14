import Foundation

/// One of the off-table study tools the app is built around.
public enum StudyTool: String, CaseIterable, Identifiable, Hashable, Sendable {
    case preflopRanges
    case pushFold
    case bankroll
    case handHistoryImport
    case drills

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .preflopRanges: return "Preflop Ranges"
        case .pushFold: return "Push/Fold Trainer"
        case .bankroll: return "Bankroll Tracker"
        case .handHistoryImport: return "Hand History Import & Leaks"
        case .drills: return "Practice Your Leaks"
        }
    }

    public var summary: String {
        switch self {
        case .preflopRanges:
            return "Build and review opening/3-bet/4-bet ranges by position and stack depth."
        case .pushFold:
            return "Shove-or-fold decisions for short stacks (~1-20bb), by position and effective stack."
        case .bankroll:
            return "Buy-ins, cashes, ROI, variance, and bankroll-management guardrails for MTTs."
        case .handHistoryImport:
            return "Parse PokerStars hand histories and surface your recurring leaks."
        case .drills:
            return "Push/fold drills weighted toward the exact spots your imported hands show you misplay."
        }
    }
}
