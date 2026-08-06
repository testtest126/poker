import { useMemo, useState, type ChangeEvent, type DragEvent } from 'react'
import { heroSawFlop, heroWonHand, parseHandHistory, type HandHistoryFile, type ParsedHand } from '../lib/handHistory'
import { holeCardsNotation } from '../engine/holeCards'

export function Import() {
  const [rawText, setRawText] = useState('')
  const [isDragging, setIsDragging] = useState(false)

  const file = useMemo<HandHistoryFile | null>(() => (rawText.trim() ? parseHandHistory(rawText) : null), [rawText])

  function loadFile(f: File) {
    const reader = new FileReader()
    reader.onload = () => {
      if (typeof reader.result === 'string') setRawText(reader.result)
    }
    reader.readAsText(f)
  }

  function handleDrop(e: DragEvent<HTMLDivElement>) {
    e.preventDefault()
    setIsDragging(false)
    const dropped = e.dataTransfer.files[0]
    if (dropped) loadFile(dropped)
  }

  function handleFileInput(e: ChangeEvent<HTMLInputElement>) {
    const chosen = e.target.files?.[0]
    if (chosen) loadFile(chosen)
  }

  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-2xl font-bold tracking-tight">Import Hand History</h1>
        <p className="mt-1 text-sm text-slate-600 dark:text-slate-400">
          Paste or drop a PokerStars tournament hand-history <code>.txt</code> export.
        </p>
        <p className="mt-2 rounded-md border border-amber-300 bg-amber-50 px-3 py-2 text-xs text-amber-900 dark:border-amber-800 dark:bg-amber-950 dark:text-amber-200">
          <strong>Preflop leak-finding, not a postflop solver</strong> — this checks your
          preflop decisions against the same charted ranges as Preflop Ranges and the
          Trainer. It doesn't analyze flop/turn/river play.
          <br />
          <strong>100% client-side</strong> — your hand histories are parsed in this
          browser tab and never leave your device. Nothing is uploaded anywhere.
        </p>
      </div>

      <div
        onDragOver={(e) => {
          e.preventDefault()
          setIsDragging(true)
        }}
        onDragLeave={() => setIsDragging(false)}
        onDrop={handleDrop}
        className={`rounded-lg border-2 border-dashed p-6 text-center text-sm transition-colors ${
          isDragging ? 'border-indigo-500 bg-indigo-50 dark:bg-indigo-950' : 'border-slate-300 dark:border-slate-700'
        }`}
      >
        <p className="text-slate-600 dark:text-slate-400">Drop a .txt hand-history file here, or</p>
        <label className="mt-2 inline-block cursor-pointer rounded-md bg-slate-200 px-3 py-1.5 text-sm font-medium text-slate-700 hover:bg-slate-300 dark:bg-slate-800 dark:text-slate-300 dark:hover:bg-slate-700">
          Choose File
          <input type="file" accept=".txt" className="hidden" onChange={handleFileInput} />
        </label>
      </div>

      <div>
        <span className="mb-1 block text-xs font-medium text-slate-500">Or paste hand history text</span>
        <textarea
          value={rawText}
          onChange={(e) => setRawText(e.target.value)}
          rows={8}
          placeholder="PokerStars Hand #..."
          spellCheck={false}
          className="w-full rounded-md border border-slate-300 bg-white px-3 py-2 font-mono text-xs focus:border-indigo-500 focus:outline-none dark:border-slate-700 dark:bg-slate-900"
        />
      </div>

      {file && <ParsedResults file={file} />}
    </div>
  )
}

function ParsedResults({ file }: { file: HandHistoryFile }) {
  if (file.hands.length === 0 && file.skipped.length === 0) {
    return <p className="text-sm text-slate-500">No PokerStars hands found in this text.</p>
  }

  return (
    <div className="space-y-4">
      <div className="flex flex-wrap gap-4 text-sm">
        <span className="font-semibold text-slate-900 dark:text-slate-100">
          {file.hands.length} hand{file.hands.length === 1 ? '' : 's'} parsed
        </span>
        {file.skipped.length > 0 && (
          <span className="text-amber-700 dark:text-amber-400">
            {file.skipped.length} skipped (couldn't be parsed)
          </span>
        )}
      </div>

      {file.skipped.length > 0 && <SkippedList skipped={file.skipped} />}

      {file.hands.length > 0 && (
        <div className="overflow-x-auto rounded-lg border border-slate-200 dark:border-slate-800">
          <table className="w-full text-left text-sm">
            <thead className="bg-slate-100 text-xs font-medium text-slate-500 dark:bg-slate-800">
              <tr>
                <th className="px-3 py-2">Hand</th>
                <th className="px-3 py-2">Position</th>
                <th className="px-3 py-2">Hole Cards</th>
                <th className="px-3 py-2">Saw Flop</th>
                <th className="px-3 py-2">Showdown</th>
                <th className="px-3 py-2 text-right">Result</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-slate-200 dark:divide-slate-800">
              {file.hands.map((hand) => (
                <HandRow key={hand.handId} hand={hand} />
              ))}
            </tbody>
          </table>
        </div>
      )}
    </div>
  )
}

function HandRow({ hand }: { hand: ParsedHand }) {
  const won = heroWonHand(hand)
  const resultClass = hand.heroNetChips === 0 ? 'text-slate-500' : won ? 'text-emerald-600' : 'text-rose-600'
  return (
    <tr>
      <td className="whitespace-nowrap px-3 py-2 text-slate-500">#{hand.handId}</td>
      <td className="whitespace-nowrap px-3 py-2">{hand.heroPosition ?? '—'}</td>
      <td className="whitespace-nowrap px-3 py-2 font-mono">{hand.heroHoleCards ? holeCardsNotation(hand.heroHoleCards) : '—'}</td>
      <td className="whitespace-nowrap px-3 py-2">{heroSawFlop(hand) ? 'Yes' : 'No'}</td>
      <td className="whitespace-nowrap px-3 py-2">{hand.wentToShowdown ? 'Yes' : 'No'}</td>
      <td className={`whitespace-nowrap px-3 py-2 text-right font-semibold tabular-nums ${resultClass}`}>
        {hand.heroNetChips > 0 ? '+' : ''}
        {hand.heroNetChips.toLocaleString()}
      </td>
    </tr>
  )
}

function SkippedList({ skipped }: { skipped: HandHistoryFile['skipped'] }) {
  return (
    <details className="rounded-md border border-slate-200 p-3 text-xs text-slate-600 dark:border-slate-800 dark:text-slate-400">
      <summary className="cursor-pointer font-medium text-slate-700 dark:text-slate-300">Why were hands skipped?</summary>
      <ul className="mt-2 list-inside list-disc space-y-1">
        {skipped.slice(0, 20).map((s, i) => (
          <li key={i}>{s.reason}</li>
        ))}
      </ul>
      {skipped.length > 20 && <p className="mt-2">…and {skipped.length - 20} more.</p>}
    </details>
  )
}
