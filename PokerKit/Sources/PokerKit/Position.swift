import Foundation

/// Preflop position for an unopened pot (nobody has entered yet), ordered earliest
/// to latest. The Big Blind is deliberately excluded: if action folds all the way
/// around, BB has already won the pot uncontested — there's no push/fold decision
/// to make. (BB facing a shove is a *calling* range, a different — and later — tool.)
public enum Position: String, CaseIterable, Identifiable, Sendable {
    case utg = "UTG"
    case middlePosition = "MP"
    case hijack = "HJ"
    case cutoff = "CO"
    case button = "BTN"
    case smallBlind = "SB"

    public var id: String { rawValue }

    public var fullName: String {
        switch self {
        case .utg: return "Under the Gun"
        case .middlePosition: return "Middle Position"
        case .hijack: return "Hijack"
        case .cutoff: return "Cutoff"
        case .button: return "Button"
        case .smallBlind: return "Small Blind"
        }
    }
}
