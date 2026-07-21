import Foundation

/// One of the off-table study tools the app is built around.
public enum StudyTool: String, CaseIterable, Identifiable, Hashable, Sendable {
    case preflopRanges
    case pushFold
    case equityCalculator
    case bankroll
    case handHistoryImport
    case drills

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .preflopRanges: return "Preflop Ranges"
        case .pushFold: return "Push/Fold Trainer"
        case .equityCalculator: return "Equity Calculator"
        case .bankroll: return "Bankroll Tracker"
        case .handHistoryImport: return "Hand History Import & Leaks"
        case .drills: return "Practice Your Leaks"
        }
    }

    public var summary: String {
        switch self {
        case .preflopRanges:
            return "Opening (raise-first-in) ranges for standard stacks, plus push/fold shove ranges for short stacks — by position and effective stack."
        case .pushFold:
            return "Shove-or-fold decisions for short stacks (~1-20bb), by position and effective stack."
        case .equityCalculator:
            return "Win/tie/lose probability for any hand or hand class vs. another, on any board — exact math, not a rule of thumb."
        case .bankroll:
            return "Buy-ins, cashes, ROI, variance, and bankroll-management guardrails for MTTs."
        case .handHistoryImport:
            return "Parse PokerStars hand histories and surface your recurring leaks."
        case .drills:
            return "Push/fold drills weighted toward the exact spots your imported hands show you misplay."
        }
    }
}
