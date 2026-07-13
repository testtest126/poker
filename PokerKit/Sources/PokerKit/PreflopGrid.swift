import Foundation

/// The classic 13x13 starting-hand grid used to visualize preflop ranges: pairs on
/// the diagonal, suited combos above it, offsuit combos below — the standard poker
/// convention. Both axes run A down to 2.
///
/// This is purely an enumeration/layout helper — it reuses `PushFoldRange` and
/// `ChenScore` for the actual push/fold decisions rather than introducing any new
/// range model.
public enum PreflopGrid {
    /// Ranks A...2, in the order the grid's rows and columns are indexed.
    public static let ranks: [Rank] = Rank.allCases.sorted(by: >)

    /// Canonical notation ("AKs", "72o", "TT") for the cell at (row, col), both
    /// 0-indexed A...2. Cells above the diagonal (col > row) are suited; cells
    /// below (row > col) are offsuit; the diagonal (row == col) is pairs.
    public static func notation(row: Int, col: Int) -> String {
        let higher = ranks[Swift.min(row, col)]
        let lower = ranks[Swift.max(row, col)]
        if row == col { return "\(higher.symbol)\(higher.symbol)" }
        return row < col ? "\(higher.symbol)\(lower.symbol)s" : "\(higher.symbol)\(lower.symbol)o"
    }

    /// All 169 canonical starting hands laid out as a 13x13 grid, indexed [row][col].
    public static let hands: [[HoleCards]] = {
        (0..<ranks.count).map { row in
            (0..<ranks.count).map { col in
                HoleCards(canonical: notation(row: row, col: col))!
            }
        }
    }()

    /// The push/fold decision for every cell, for a given position and effective stack.
    public static func decisions(position: Position, effectiveStackBB: Double) -> [[PushFoldDecision]] {
        hands.map { row in
            row.map { PushFoldRange.decide(hand: $0, position: position, effectiveStackBB: effectiveStackBB) }
        }
    }
}
