// Port of PokerKit/Sources/PokerKit/HandHistory.swift + HandHistoryParser.swift — parses
// PokerStars tournament hand-history exports (the standard "PokerStars Hand #...
// Tournament #..." .txt format) into structured `ParsedHand` values. See
// ai-docs/HAND-HISTORY.md for the full design notes this port follows exactly: how the
// hero is identified (whichever player the file deals hole cards to), the defensive
// "never throws, skip malformed hands" parsing strategy, and the known limitations
// (position-label collisions above 6-max, naive timestamps).
//
// Per CLAUDE.md §1, this only ever operates on histories from hands that have already
// finished — a file parser, not a live reader. There is no code path here that reads
// table state while a hand is in progress.
//
// Deliberate addition beyond the Swift original: `seats` and `buttonSeat` are exposed on
// `ParsedHand` (Swift's version only exposes `heroSeat`/`heroPosition`, since PokerKit's
// leak analysis only ever needed hero's own position). The web Leak Finder needs every
// player's position, not just hero's, to determine who hero is facing — see
// `leakFinder.ts`.

import { type Card, cardFromNotation } from '../engine/card'
import { type HoleCards, holeCards } from '../engine/holeCards'

export type Street = 'preflop' | 'flop' | 'turn' | 'river'

export type ActionKind = 'postAnte' | 'postSmallBlind' | 'postBigBlind' | 'fold' | 'check' | 'call' | 'bet' | 'raise'

/** One action taken by one player on one street. `amount` for a `raise` is the new
 * *total* bet for that street (not the increment) — matches how PokerStars logs it
 * ("raises 100 to 150"). Every other kind's `amount` is the chips that action itself put
 * in (0 for folds/checks). See `computeHeroNet` for how the raise-is-a-total quirk gets
 * turned into actual per-action increments. */
export interface HandAction {
  readonly street: Street
  readonly player: string
  readonly kind: ActionKind
  readonly amount: number
  readonly isAllIn: boolean
}

export interface Seat {
  readonly seat: number
  readonly name: string
  readonly stack: number
}

/** A single hand parsed from a PokerStars hand-history file, from the hero's point of
 * view. The hero is identified as whichever player the file deals hole cards to. */
export interface ParsedHand {
  readonly handId: string
  readonly tournamentId: string | undefined
  readonly date: Date | undefined
  readonly smallBlind: number
  readonly bigBlind: number
  readonly ante: number

  /** Every seated player, in seat order — not just hero. */
  readonly seats: readonly Seat[]
  readonly buttonSeat: number | undefined

  readonly heroName: string
  readonly heroSeat: number | undefined
  /** Standard position label ("BTN", "SB", "BB", "UTG", "UTG+1", "MP", "MP+1", "HJ",
   * "CO"), derived from seat count and distance from the button. `undefined` if it
   * couldn't be determined (e.g. button seat not found, or an unsupported table size). */
  readonly heroPosition: string | undefined
  readonly heroHoleCards: HoleCards | undefined
  readonly heroStartingStack: number | undefined

  readonly actions: readonly HandAction[]
  readonly board: readonly Card[]

  /** Hero's net chip result for the hand: total collected/returned minus total invested. */
  readonly heroNetChips: number
  /** The bounty hero collected this hand for eliminating an opponent, if any (PKO
   * tournaments). `undefined` (not `0`) when the hand had none. */
  readonly heroBountyWon: number | undefined
  /** True only if "*** SHOW DOWN ***" appears — a hand can reach the river and still end
   * without a showdown if the last bet takes the pot uncontested. */
  readonly wentToShowdown: boolean

  readonly rawText: string
}

/** True if hero was still in the hand when the flop was dealt. Checked via "did hero
 * fold preflop", not "did hero act on the flop" — when the remaining players are all-in
 * preflop, PokerStars deals the rest of the board straight through with no further
 * action lines at all, so checking for a flop-street action would miss those hands. */
export function heroSawFlop(hand: ParsedHand): boolean {
  if (hand.board.length < 3) return false
  const foldedPreflop = hand.actions.some((a) => a.street === 'preflop' && a.player === hand.heroName && a.kind === 'fold')
  return !foldedPreflop
}

export function heroWonHand(hand: ParsedHand): boolean {
  return hand.heroNetChips > 0
}

export interface SkippedHand {
  readonly rawText: string
  readonly reason: string
}

/** All hands parsed from one hand-history file, plus anything that couldn't be parsed.
 * Malformed hands are skipped rather than failing the whole import. */
export interface HandHistoryFile {
  readonly hands: readonly ParsedHand[]
  readonly skipped: readonly SkippedHand[]
}

/** All hands from a single tournament, grouped together for a per-session summary. */
export interface TournamentSession {
  readonly tournamentId: string | undefined
  readonly hands: readonly ParsedHand[]
}

export function sessionNetChips(session: TournamentSession): number {
  return session.hands.reduce((sum, h) => sum + h.heroNetChips, 0)
}

export function sessionBountiesWon(session: TournamentSession): number {
  return session.hands.reduce((sum, h) => sum + (h.heroBountyWon ?? 0), 0)
}

export function sessionHandsWithFlopSeen(session: TournamentSession): number {
  return session.hands.filter(heroSawFlop).length
}

/** Hands grouped into sessions by tournament id, ordered by each session's earliest
 * hand. Hands with no tournament id are grouped under `undefined`, sorted last. */
export function sessionsFromHands(hands: readonly ParsedHand[]): TournamentSession[] {
  const order: (string | undefined)[] = []
  const buckets = new Map<string | undefined, ParsedHand[]>()
  for (const hand of hands) {
    if (!buckets.has(hand.tournamentId)) {
      buckets.set(hand.tournamentId, [])
      order.push(hand.tournamentId)
    }
    buckets.get(hand.tournamentId)!.push(hand)
  }
  const withTournament = order.filter((id) => id !== undefined)
  const withoutTournament = order.filter((id) => id === undefined)
  return [...withTournament, ...withoutTournament].map((id) => ({ tournamentId: id, hands: buckets.get(id)! }))
}

/** Parses PokerStars tournament hand-history export text into `ParsedHand` values.
 * Never throws — a hand that doesn't match the expected shape is recorded in the
 * returned `skipped` list with a reason, and the rest of the file is still parsed. */
export function parseHandHistory(text: string): HandHistoryFile {
  const hands: ParsedHand[] = []
  const skipped: SkippedHand[] = []

  for (const block of splitIntoHandBlocks(text)) {
    const result = parseHand(block)
    if (result.ok) {
      hands.push(result.hand)
    } else {
      skipped.push({ rawText: block, reason: result.reason })
    }
  }

  return { hands, skipped }
}

// MARK: - Splitting

function splitIntoHandBlocks(text: string): string[] {
  const lines = text.split(/\r\n|\r|\n/)
  const blocks: string[][] = []
  let current: string[] = []

  for (const line of lines) {
    if (line.startsWith('PokerStars Hand #') || line.startsWith('PokerStars Game #')) {
      if (current.length > 0) blocks.push(current)
      current = [line]
    } else if (current.length > 0) {
      current.push(line)
    }
  }
  if (current.length > 0) blocks.push(current)

  return blocks.map((lines) => lines.join('\n').trim())
}

// MARK: - Per-hand parsing

type ParseResult = { ok: true; hand: ParsedHand } | { ok: false; reason: string }

function parseHand(block: string): ParseResult {
  const lines = block.split('\n')
  const headerLine = lines[0]
  const header = headerLine !== undefined ? parseHeader(headerLine) : undefined
  if (!header) return { ok: false, reason: 'unrecognized header line' }

  const seats = lines.map(parseSeatLine).filter((s): s is Seat => s !== undefined)
  if (seats.length === 0) return { ok: false, reason: 'no seat lines found' }

  const buttonSeat = parseButtonSeat(lines)
  if (buttonSeat === undefined) return { ok: false, reason: 'button seat not found' }

  const dealt = parseDealtTo(lines)
  if (!dealt) return { ok: false, reason: 'no hero hole cards found ("Dealt to" line missing)' }
  const heroCards = holeCards(dealt.first, dealt.second)
  if (!heroCards) return { ok: false, reason: 'invalid hero hole cards' }

  const heroSeatInfo = seats.find((s) => s.name === dealt.name)
  const heroPosition = heroSeatInfo ? positionLabelForSeat(seats, buttonSeat, heroSeatInfo.seat) : undefined

  const { actions, board } = parseBody(lines)
  const ante = actions.find((a) => a.kind === 'postAnte')?.amount ?? 0
  const heroNet = computeHeroNet(actions, lines, dealt.name)
  const heroBounty = computeHeroBounty(lines, dealt.name)
  const wentToShowdown = lines.some((l) => l.trim().startsWith('*** SHOW DOWN ***'))

  const hand: ParsedHand = {
    handId: header.handId,
    tournamentId: header.tournamentId,
    date: header.date,
    smallBlind: header.smallBlind,
    bigBlind: header.bigBlind,
    ante,
    seats,
    buttonSeat,
    heroName: dealt.name,
    heroSeat: heroSeatInfo?.seat,
    heroPosition,
    heroHoleCards: heroCards,
    heroStartingStack: heroSeatInfo?.stack,
    actions,
    board,
    heroNetChips: heroNet,
    heroBountyWon: heroBounty,
    wentToShowdown,
    rawText: block,
  }
  return { ok: true, hand }
}

// MARK: - Header

interface Header {
  readonly handId: string
  readonly tournamentId: string | undefined
  readonly smallBlind: number
  readonly bigBlind: number
  readonly date: Date | undefined
}

function parseHeader(line: string): Header | undefined {
  const handIdMatch = captures(/PokerStars (?:Hand|Game) #(\d+)/, line)
  const handId = handIdMatch?.[1]
  if (!handId) return undefined

  const tournamentId = captures(/Tournament #(\d+)/, line)?.[1]

  let smallBlind = 0
  let bigBlind = 0
  const blindsMatch = captures(/\(\$?([\d,.]+)\/\$?([\d,.]+)(?:\/\$?[\d,.]+)?\)/, line)
  if (blindsMatch) {
    smallBlind = decimalFrom(blindsMatch[1] ?? '0')
    bigBlind = decimalFrom(blindsMatch[2] ?? '0')
  }

  let date: Date | undefined
  const dateMatch = captures(/(\d{4})\/(\d{2})\/(\d{2}) (\d{2}):(\d{2}):(\d{2})/, line)
  if (dateMatch) {
    const [, y, mo, d, h, mi, s] = dateMatch
    date = new Date(Date.UTC(Number(y), Number(mo) - 1, Number(d), Number(h), Number(mi), Number(s)))
  }

  return { handId, tournamentId, smallBlind, bigBlind, date }
}

// MARK: - Seats / button / hero

function parseSeatLine(line: string): Seat | undefined {
  const m = captures(/^Seat (\d+): (.+?) \(([\d,]+) in chips/, line)
  if (!m || !m[1] || !m[2] || !m[3]) return undefined
  const seat = Number(m[1])
  if (!Number.isInteger(seat)) return undefined
  return { seat, name: m[2], stack: decimalFrom(m[3]) }
}

function parseButtonSeat(lines: readonly string[]): number | undefined {
  for (const line of lines) {
    const m = captures(/Seat #(\d+) is the button/, line)
    if (m?.[1]) return Number(m[1])
  }
  return undefined
}

function parseDealtTo(lines: readonly string[]): { name: string; first: Card; second: Card } | undefined {
  for (const line of lines) {
    const m = captures(/^Dealt to (.+?) \[(\S{2}) (\S{2})\]/, line)
    if (!m || !m[1] || !m[2] || !m[3]) continue
    const card1 = cardFromNotation(m[2])
    const card2 = cardFromNotation(m[3])
    if (!card1 || !card2) continue
    return { name: m[1], first: card1, second: card2 }
  }
  return undefined
}

/** Standard position labels by table size, starting at the button and going clockwise
 * (the order seats act relative to the button). */
const POSITION_LABELS_BY_COUNT: Record<number, readonly string[]> = {
  2: ['BTN', 'BB'],
  3: ['BTN', 'SB', 'BB'],
  4: ['BTN', 'SB', 'BB', 'CO'],
  5: ['BTN', 'SB', 'BB', 'HJ', 'CO'],
  6: ['BTN', 'SB', 'BB', 'UTG', 'HJ', 'CO'],
  7: ['BTN', 'SB', 'BB', 'UTG', 'MP', 'HJ', 'CO'],
  8: ['BTN', 'SB', 'BB', 'UTG', 'UTG+1', 'MP', 'HJ', 'CO'],
  9: ['BTN', 'SB', 'BB', 'UTG', 'UTG+1', 'MP', 'MP+1', 'HJ', 'CO'],
}

/** The position label for any seat at the table (not just hero's) — `seats` and
 * `buttonSeat` are the same values recorded on `ParsedHand`, so callers needing an
 * opponent's position (the Leak Finder) can call this directly instead of re-deriving it. */
export function positionLabelForSeat(seats: readonly Seat[], buttonSeat: number, targetSeat: number): string | undefined {
  const present = [...new Set(seats.map((s) => s.seat))].sort((a, b) => a - b)
  if (present.length < 2 || present.length > 9) return undefined
  const buttonIndex = present.indexOf(buttonSeat)
  if (buttonIndex === -1) return undefined

  const rotated = [...present.slice(buttonIndex), ...present.slice(0, buttonIndex)]
  const labels = POSITION_LABELS_BY_COUNT[present.length]
  const targetIndex = rotated.indexOf(targetSeat)
  if (!labels || targetIndex === -1) return undefined
  return labels[targetIndex]
}

// MARK: - Body (streets, actions, board)

function parseBody(lines: readonly string[]): { actions: HandAction[]; board: Card[] } {
  const actions: HandAction[] = []
  let board: Card[] = []
  let street: Street = 'preflop'

  for (const rawLine of lines) {
    const line = rawLine.trim()
    if (line.startsWith('*** SUMMARY ***')) break
    if (line.startsWith('*** SHOW DOWN ***')) break
    if (line.startsWith('*** FLOP ***')) {
      street = 'flop'
      board = parseCards(line)
      continue
    }
    if (line.startsWith('*** TURN ***')) {
      street = 'turn'
      board = parseCards(line)
      continue
    }
    if (line.startsWith('*** RIVER ***')) {
      street = 'river'
      board = parseCards(line)
      continue
    }
    if (line.startsWith('***')) continue

    const split = splitNameAction(line)
    if (!split) continue
    const classified = classifyAction(split.rest)
    if (!classified) continue
    actions.push({ street, player: split.name, kind: classified.kind, amount: classified.amount, isAllIn: classified.isAllIn })
  }

  return { actions, board }
}

function splitNameAction(line: string): { name: string; rest: string } | undefined {
  const idx = line.indexOf(': ')
  if (idx === -1) return undefined
  const name = line.slice(0, idx)
  const rest = line.slice(idx + 2)
  if (!name) return undefined
  return { name, rest }
}

function classifyAction(rest: string): { kind: ActionKind; amount: number; isAllIn: boolean } | undefined {
  const isAllIn = rest.includes('all-in')

  if (rest.startsWith('folds')) return { kind: 'fold', amount: 0, isAllIn }
  if (rest.startsWith('checks')) return { kind: 'check', amount: 0, isAllIn }
  if (rest.startsWith('posts the ante')) return { kind: 'postAnte', amount: firstDecimalIn(rest) ?? 0, isAllIn }
  if (rest.startsWith('posts small & big blinds')) return { kind: 'postBigBlind', amount: firstDecimalIn(rest) ?? 0, isAllIn }
  if (rest.startsWith('posts small blind')) return { kind: 'postSmallBlind', amount: firstDecimalIn(rest) ?? 0, isAllIn }
  if (rest.startsWith('posts big blind')) return { kind: 'postBigBlind', amount: firstDecimalIn(rest) ?? 0, isAllIn }
  if (rest.startsWith('calls')) return { kind: 'call', amount: firstDecimalIn(rest) ?? 0, isAllIn }
  if (rest.startsWith('bets')) return { kind: 'bet', amount: firstDecimalIn(rest) ?? 0, isAllIn }
  if (rest.startsWith('raises')) {
    const total = captures(/raises [\d,.]+ to ([\d,.]+)/, rest)?.[1]
    if (!total) return undefined
    return { kind: 'raise', amount: decimalFrom(total), isAllIn }
  }
  return undefined
}

// MARK: - Money

/** Hero's net chip result: everything returned/collected minus everything invested. A
 * raise's `amount` is the new total bet for that street (not the increment), so this
 * tracks each player's running commitment per street to work out what was actually
 * added on each action. */
function computeHeroNet(actions: readonly HandAction[], lines: readonly string[], heroName: string): number {
  let committedThisStreet = new Map<string, number>()
  let currentStreet: Street | undefined
  let heroInvested = 0

  for (const action of actions) {
    if (action.street !== currentStreet) {
      committedThisStreet = new Map()
      currentStreet = action.street
    }

    let increment: number
    switch (action.kind) {
      case 'raise': {
        const already = committedThisStreet.get(action.player) ?? 0
        increment = Math.max(action.amount - already, 0)
        committedThisStreet.set(action.player, action.amount)
        break
      }
      case 'call':
      case 'bet':
      case 'postAnte':
      case 'postSmallBlind':
      case 'postBigBlind':
        increment = action.amount
        committedThisStreet.set(action.player, (committedThisStreet.get(action.player) ?? 0) + action.amount)
        break
      case 'fold':
      case 'check':
        increment = 0
        break
    }

    if (action.player === heroName) heroInvested += increment
  }

  let heroReturned = 0
  for (const line of lines) {
    const uncalled = captures(/Uncalled bet \(\$?([\d,.]+)\) returned to (.+)/, line)
    if (uncalled?.[1] && uncalled[2] === heroName) {
      heroReturned += decimalFrom(uncalled[1])
    }
    const collected = captures(/^(.+?) collected \$?([\d,.]+) from/, line)
    if (collected?.[1] === heroName && collected[2]) {
      heroReturned += decimalFrom(collected[2])
    }
  }

  return heroReturned - heroInvested
}

function computeHeroBounty(lines: readonly string[], heroName: string): number | undefined {
  let total = 0
  let found = false
  for (const line of lines) {
    const m = captures(/^(.+?) wins (?:the )?\$?([\d,.]+) (?:bounty )?for eliminating/, line)
    if (m?.[1] === heroName && m[2]) {
      total += decimalFrom(m[2])
      found = true
    }
  }
  return found ? total : undefined
}

// MARK: - Cards

function parseCards(line: string): Card[] {
  const cards: Card[] = []
  let buffer = ''
  let inBrackets = false
  for (const ch of line) {
    if (ch === '[') {
      inBrackets = true
      buffer = ''
      continue
    }
    if (ch === ']') {
      inBrackets = false
      for (const token of buffer.split(' ')) {
        if (!token) continue
        const card = cardFromNotation(token)
        if (card) cards.push(card)
      }
      continue
    }
    if (inBrackets) buffer += ch
  }
  return cards
}

// MARK: - Regex / number helpers

function decimalFrom(s: string): number {
  const n = Number(s.replace(/,/g, ''))
  return Number.isFinite(n) ? n : 0
}

function firstDecimalIn(text: string): number | undefined {
  const s = captures(/([\d,]+(?:\.\d+)?)/, text)?.[1]
  return s ? decimalFrom(s) : undefined
}

/** Index 0 is the whole match, subsequent indexes are capture groups (`undefined` if
 * that group didn't participate in the match) — mirrors the Swift original's `captures`. */
function captures(pattern: RegExp, text: string): (string | undefined)[] | undefined {
  const match = text.match(pattern)
  return match ? Array.from(match, (g) => g ?? undefined) : undefined
}
