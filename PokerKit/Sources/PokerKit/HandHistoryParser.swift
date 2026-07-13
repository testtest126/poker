import Foundation

/// Parses PokerStars tournament hand-history export files (the standard
/// "PokerStars Hand #... Tournament #..." .txt format) into `ParsedHand` values.
///
/// The hero is identified as whichever player the file deals hole cards to —
/// PokerStars only ever shows hole cards for the account the history was
/// exported for, so this works without the caller having to supply a username.
///
/// Parsing is defensive: a hand that doesn't match the expected shape is
/// recorded in `HandHistoryFile.skipped` with a reason, and the rest of the
/// file is still parsed. Nothing here throws.
public enum HandHistoryParser {
    public static func parse(_ text: String) -> HandHistoryFile {
        var hands: [ParsedHand] = []
        var skipped: [HandHistoryFile.SkippedHand] = []

        for block in splitIntoHandBlocks(text) {
            switch parseHand(block) {
            case .success(let hand):
                hands.append(hand)
            case .failure(let error):
                skipped.append(.init(rawText: block, reason: error.reason))
            }
        }

        return HandHistoryFile(hands: hands, skipped: skipped)
    }

    private struct ParseFailure: Error {
        let reason: String
    }

    // MARK: - Splitting

    static func splitIntoHandBlocks(_ text: String) -> [String] {
        let lines = text.components(separatedBy: .newlines)
        var blocks: [[String]] = []
        var current: [String] = []

        for line in lines {
            if line.hasPrefix("PokerStars Hand #") || line.hasPrefix("PokerStars Game #") {
                if !current.isEmpty { blocks.append(current) }
                current = [line]
            } else if !current.isEmpty {
                current.append(line)
            }
        }
        if !current.isEmpty { blocks.append(current) }

        return blocks.map { $0.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines) }
    }

    // MARK: - Per-hand parsing

    private static func parseHand(_ block: String) -> Result<ParsedHand, ParseFailure> {
        let lines = block.components(separatedBy: "\n")
        guard let headerLine = lines.first, let header = parseHeader(headerLine) else {
            return .failure(ParseFailure(reason: "unrecognized header line"))
        }

        let seats = lines.compactMap(parseSeatLine)
        guard !seats.isEmpty else {
            return .failure(ParseFailure(reason: "no seat lines found"))
        }

        guard let buttonSeat = parseButtonSeat(lines) else {
            return .failure(ParseFailure(reason: "button seat not found"))
        }

        guard let dealt = parseDealtTo(lines) else {
            return .failure(ParseFailure(reason: "no hero hole cards found (\"Dealt to\" line missing)"))
        }
        guard let heroCards = HoleCards(dealt.first, dealt.second) else {
            return .failure(ParseFailure(reason: "invalid hero hole cards"))
        }

        let heroSeatInfo = seats.first { $0.name == dealt.name }
        let heroPosition = heroSeatInfo.flatMap {
            positionLabel(seats: seats, buttonSeat: buttonSeat, heroSeat: $0.seat)
        }

        let (actions, board) = parseBody(lines: lines)
        let ante = actions.first(where: { $0.kind == .postAnte })?.amount ?? 0
        let heroNet = computeHeroNet(actions: actions, lines: lines, heroName: dealt.name)
        let heroBounty = computeHeroBounty(lines: lines, heroName: dealt.name)
        let wentToShowdown = lines.contains { $0.trimmingCharacters(in: .whitespaces).hasPrefix("*** SHOW DOWN ***") }

        let hand = ParsedHand(
            handId: header.handId,
            tournamentId: header.tournamentId,
            date: header.date,
            smallBlind: header.smallBlind,
            bigBlind: header.bigBlind,
            ante: ante,
            heroName: dealt.name,
            heroSeat: heroSeatInfo?.seat,
            heroPosition: heroPosition,
            heroHoleCards: heroCards,
            heroStartingStack: heroSeatInfo?.stack,
            actions: actions,
            board: board,
            heroNetChips: heroNet,
            heroBountyWon: heroBounty,
            wentToShowdown: wentToShowdown,
            rawText: block
        )
        return .success(hand)
    }

    // MARK: - Header

    private struct Header {
        let handId: String
        let tournamentId: String?
        let smallBlind: Decimal
        let bigBlind: Decimal
        let date: Date?
    }

    private static func parseHeader(_ line: String) -> Header? {
        guard let handId = captures(#"PokerStars (?:Hand|Game) #(\d+)"#, in: line)?[1] else {
            return nil
        }
        let tournamentId = captures(#"Tournament #(\d+)"#, in: line)?[1]

        var smallBlind: Decimal = 0
        var bigBlind: Decimal = 0
        if let m = captures(#"\(\$?([\d,.]+)/\$?([\d,.]+)(?:/\$?[\d,.]+)?\)"#, in: line) {
            smallBlind = decimal(from: m[1] ?? "0")
            bigBlind = decimal(from: m[2] ?? "0")
        }

        var date: Date?
        if let raw = captures(#"(\d{4}/\d{2}/\d{2} \d{2}:\d{2}:\d{2})"#, in: line)?[1] {
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.dateFormat = "yyyy/MM/dd HH:mm:ss"
            formatter.timeZone = TimeZone(identifier: "UTC")
            date = formatter.date(from: raw)
        }

        return Header(handId: handId, tournamentId: tournamentId, smallBlind: smallBlind, bigBlind: bigBlind, date: date)
    }

    // MARK: - Seats / button / hero

    private static func parseSeatLine(_ line: String) -> (seat: Int, name: String, stack: Decimal)? {
        guard let m = captures(#"^Seat (\d+): (.+?) \(([\d,]+) in chips"#, in: line),
              let seatStr = m[1], let name = m[2], let stackStr = m[3],
              let seat = Int(seatStr) else { return nil }
        return (seat, name, decimal(from: stackStr))
    }

    private static func parseButtonSeat(_ lines: [String]) -> Int? {
        for line in lines {
            if let s = captures(#"Seat #(\d+) is the button"#, in: line)?[1], let seat = Int(s) {
                return seat
            }
        }
        return nil
    }

    private static func parseDealtTo(_ lines: [String]) -> (name: String, first: Card, second: Card)? {
        for line in lines {
            guard let m = captures(#"^Dealt to (.+?) \[(\S{2}) (\S{2})\]"#, in: line),
                  let name = m[1], let c1 = m[2], let c2 = m[3],
                  let card1 = parseCard(c1), let card2 = parseCard(c2) else { continue }
            return (name, card1, card2)
        }
        return nil
    }

    /// Standard position labels by table size, starting at the button and going
    /// clockwise (the order seats act relative to the button).
    private static let positionLabelsByCount: [Int: [String]] = [
        2: ["BTN", "BB"],
        3: ["BTN", "SB", "BB"],
        4: ["BTN", "SB", "BB", "CO"],
        5: ["BTN", "SB", "BB", "HJ", "CO"],
        6: ["BTN", "SB", "BB", "UTG", "HJ", "CO"],
        7: ["BTN", "SB", "BB", "UTG", "MP", "HJ", "CO"],
        8: ["BTN", "SB", "BB", "UTG", "UTG+1", "MP", "HJ", "CO"],
        9: ["BTN", "SB", "BB", "UTG", "UTG+1", "MP", "MP+1", "HJ", "CO"],
    ]

    private static func positionLabel(
        seats: [(seat: Int, name: String, stack: Decimal)],
        buttonSeat: Int,
        heroSeat: Int
    ) -> String? {
        let present = seats.map(\.seat).sorted()
        guard present.count >= 2, present.count <= 9 else { return nil }
        guard let buttonIndex = present.firstIndex(of: buttonSeat) else { return nil }

        let rotated = Array(present[buttonIndex...]) + Array(present[..<buttonIndex])
        guard let labels = positionLabelsByCount[present.count],
              let heroIndex = rotated.firstIndex(of: heroSeat) else { return nil }
        return labels[heroIndex]
    }

    // MARK: - Body (streets, actions, board)

    private static func parseBody(lines: [String]) -> (actions: [HandAction], board: [Card]) {
        var actions: [HandAction] = []
        var board: [Card] = []
        var street: Street = .preflop

        for rawLine in lines {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            if line.hasPrefix("*** SUMMARY ***") { break }
            if line.hasPrefix("*** SHOW DOWN ***") { break }
            if line.hasPrefix("*** FLOP ***") {
                street = .flop
                board = parseCards(from: line)
                continue
            }
            if line.hasPrefix("*** TURN ***") {
                street = .turn
                board = parseCards(from: line)
                continue
            }
            if line.hasPrefix("*** RIVER ***") {
                street = .river
                board = parseCards(from: line)
                continue
            }
            if line.hasPrefix("***") { continue }

            guard let (name, rest) = splitNameAction(line) else { continue }
            guard let (kind, amount, isAllIn) = classifyAction(rest) else { continue }
            actions.append(HandAction(street: street, player: name, kind: kind, amount: amount, isAllIn: isAllIn))
        }

        return (actions, board)
    }

    private static func splitNameAction(_ line: String) -> (name: String, rest: String)? {
        guard let range = line.range(of: ": ") else { return nil }
        let name = String(line[line.startIndex..<range.lowerBound])
        let rest = String(line[range.upperBound...])
        guard !name.isEmpty else { return nil }
        return (name, rest)
    }

    private static func classifyAction(_ rest: String) -> (ActionKind, Decimal, Bool)? {
        let isAllIn = rest.contains("all-in")

        if rest.hasPrefix("folds") { return (.fold, 0, isAllIn) }
        if rest.hasPrefix("checks") { return (.check, 0, isAllIn) }
        if rest.hasPrefix("posts the ante") { return (.postAnte, firstDecimal(in: rest) ?? 0, isAllIn) }
        if rest.hasPrefix("posts small & big blinds") { return (.postBigBlind, firstDecimal(in: rest) ?? 0, isAllIn) }
        if rest.hasPrefix("posts small blind") { return (.postSmallBlind, firstDecimal(in: rest) ?? 0, isAllIn) }
        if rest.hasPrefix("posts big blind") { return (.postBigBlind, firstDecimal(in: rest) ?? 0, isAllIn) }
        if rest.hasPrefix("calls") { return (.call, firstDecimal(in: rest) ?? 0, isAllIn) }
        if rest.hasPrefix("bets") { return (.bet, firstDecimal(in: rest) ?? 0, isAllIn) }
        if rest.hasPrefix("raises") {
            guard let total = captures(#"raises [\d,.]+ to ([\d,.]+)"#, in: rest)?[1] else { return nil }
            return (.raise, decimal(from: total), isAllIn)
        }
        return nil
    }

    // MARK: - Money

    /// Hero's net chip result: everything returned/collected minus everything invested.
    /// A raise's `amount` is the new total bet for that street (not the increment), so
    /// this tracks each player's running commitment per street to work out what was
    /// actually added on each action.
    private static func computeHeroNet(actions: [HandAction], lines: [String], heroName: String) -> Decimal {
        var committedThisStreet: [String: Decimal] = [:]
        var currentStreet: Street?
        var heroInvested: Decimal = 0

        for action in actions {
            if action.street != currentStreet {
                committedThisStreet = [:]
                currentStreet = action.street
            }

            let increment: Decimal
            switch action.kind {
            case .raise:
                let already = committedThisStreet[action.player] ?? 0
                increment = max(action.amount - already, 0)
                committedThisStreet[action.player] = action.amount
            case .call, .bet, .postAnte, .postSmallBlind, .postBigBlind:
                increment = action.amount
                committedThisStreet[action.player, default: 0] += action.amount
            case .fold, .check:
                increment = 0
            }

            if action.player == heroName {
                heroInvested += increment
            }
        }

        var heroReturned: Decimal = 0
        for line in lines {
            if let m = captures(#"Uncalled bet \(\$?([\d,.]+)\) returned to (.+)"#, in: line),
               let amountStr = m[1], let name = m[2], name == heroName {
                heroReturned += decimal(from: amountStr)
            }
            if let m = captures(#"^(.+?) collected \$?([\d,.]+) from"#, in: line),
               let name = m[1], let amountStr = m[2], name == heroName {
                heroReturned += decimal(from: amountStr)
            }
        }

        return heroReturned - heroInvested
    }

    private static func computeHeroBounty(lines: [String], heroName: String) -> Decimal? {
        var total: Decimal = 0
        var found = false
        for line in lines {
            if let m = captures(#"^(.+?) wins (?:the )?\$?([\d,.]+) (?:bounty )?for eliminating"#, in: line),
               let name = m[1], let amountStr = m[2], name == heroName {
                total += decimal(from: amountStr)
                found = true
            }
        }
        return found ? total : nil
    }

    // MARK: - Cards

    private static func parseCard(_ token: String) -> Card? {
        let chars = Array(token)
        guard chars.count == 2, let rank = Rank.from(symbol: chars[0]) else { return nil }
        switch chars[1] {
        case "h", "H": return Card(rank: rank, suit: .hearts)
        case "d", "D": return Card(rank: rank, suit: .diamonds)
        case "c", "C": return Card(rank: rank, suit: .clubs)
        case "s", "S": return Card(rank: rank, suit: .spades)
        default: return nil
        }
    }

    private static func parseCards(from line: String) -> [Card] {
        var cards: [Card] = []
        var buffer = ""
        var inBrackets = false
        for ch in line {
            if ch == "[" { inBrackets = true; buffer = ""; continue }
            if ch == "]" {
                inBrackets = false
                for token in buffer.split(separator: " ") {
                    if let card = parseCard(String(token)) { cards.append(card) }
                }
                continue
            }
            if inBrackets { buffer.append(ch) }
        }
        return cards
    }

    // MARK: - Regex / number helpers

    private static func decimal(from string: String) -> Decimal {
        Decimal(string: string.replacingOccurrences(of: ",", with: "")) ?? 0
    }

    private static func firstDecimal(in text: String) -> Decimal? {
        guard let s = captures(#"([\d,]+(?:\.\d+)?)"#, in: text)?[1] else { return nil }
        return decimal(from: s)
    }

    /// Index 0 is the whole match, subsequent indexes are capture groups (nil if
    /// that group didn't participate in the match).
    private static func captures(_ pattern: String, in text: String) -> [String?]? {
        guard let regex = try? Regex(pattern) else { return nil }
        guard let match = text.firstMatch(of: regex) else { return nil }
        return match.output.map { $0.substring.map(String.init) }
    }
}
