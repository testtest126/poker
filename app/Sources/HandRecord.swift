import Foundation
import SwiftData
import PokerKit

/// SwiftData-backed persistence for an imported `ParsedHand`. Kept out of
/// PokerKit so the package's domain logic stays a plain, framework-free model.
///
/// `handId` is unique so re-importing the same hand-history file (or one that
/// overlaps a previous import) doesn't create duplicate rows.
@Model
final class HandRecord {
    var id: UUID
    @Attribute(.unique) var handId: String
    var tournamentId: String?
    var date: Date?
    var heroPosition: String?
    var heroHoleCardsDescription: String?
    var heroStartingStack: Decimal?
    var heroNetChips: Decimal
    var heroBountyWon: Decimal?
    var heroSawFlop: Bool
    var heroWonHand: Bool
    var boardDescription: String
    var rawText: String
    var importedAt: Date

    init(hand: ParsedHand, importedAt: Date = .now) {
        id = UUID()
        handId = hand.handId
        tournamentId = hand.tournamentId
        date = hand.date
        heroPosition = hand.heroPosition
        if let cards = hand.heroHoleCards {
            heroHoleCardsDescription = "\(cards.first.description) \(cards.second.description)"
        } else {
            heroHoleCardsDescription = nil
        }
        heroStartingStack = hand.heroStartingStack
        heroNetChips = hand.heroNetChips
        heroBountyWon = hand.heroBountyWon
        heroSawFlop = hand.heroSawFlop
        heroWonHand = hand.heroWonHand
        boardDescription = hand.board.map(\.description).joined(separator: " ")
        rawText = hand.rawText
        self.importedAt = importedAt
    }
}
