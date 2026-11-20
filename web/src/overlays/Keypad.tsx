import { useCallback, useEffect, useRef, useState } from 'react'
import { cn } from '@/lib/utils'
import { isNui, nui, sfx } from '@/lib/nui'
import { Kbd } from '@/components/common'

interface Rect { x0: number; y0: number; x1: number; y1: number }
export interface KeypadState {
  open: boolean
  id?: string
  label?: string
  buttons?: (Rect & { label: string })[]
  lcd?: Rect
  housing?: Rect
  attemptsLeft?: number
}

type Display = { kind: 'entry' } | { kind: 'error' } | { kind: 'open' } | { kind: 'locked' } | { kind: 'busy' }

// The game camera is on the keypad of the safe door. Every button of the prop has a click area laid exactly
// over it (screen rects from client/keypad.lua), and the LCD shows what's typed.
export default function Keypad({ state }: { state: KeypadState }) {
  const [code, setCode] = useState('')
  const [display, setDisplay] = useState<Display>({ kind: 'entry' })
  const [pressed, setPressed] = useState<string | null>(null)
  const [attempts, setAttempts] = useState(state.attemptsLeft ?? 3)
  const busy = display.kind !== 'entry'
  const codeRef = useRef(code)
  codeRef.current = code

  const flash = (label: string) => {
    setPressed(label)
    window.setTimeout(() => setPressed((p) => (p === label ? null : p)), 140)
  }

  const submit = useCallback(async () => {
    const value = codeRef.current
    if (value.length < 4) { sfx.error(); return }
    setDisplay({ kind: 'busy' })
    const res = await nui<{ ok: boolean; attemptsLeft?: number; lockout?: boolean; error?: string }>('keypad:submit', { code: value })
    if (res?.ok) {
      sfx.success()
      setDisplay({ kind: 'open' })
      return
    }
    if (res?.lockout) {
      sfx.lock()
      setDisplay({ kind: 'locked' })
      return
    }
    sfx.error()
    if (typeof res?.attemptsLeft === 'number') setAttempts(res.attemptsLeft)
    setDisplay({ kind: 'error' })
    window.setTimeout(() => { setCode(''); setDisplay({ kind: 'entry' }) }, 1100)
  }, [])

  const press = useCallback((label: string) => {
    if (busy) return
    flash(label)
    if (label === 'C') { sfx.clear(); setCode(''); return }
    if (label === 'OK') { sfx.press(); submit(); return }
    sfx.press()
    setCode((c) => (c.length >= 4 ? c : c + label))
  }, [busy, submit])

  const close = useCallback(() => { if (display.kind !== 'open') nui('keypad:close') }, [display.kind])

  useEffect(() => {
    const onKey = (e: KeyboardEvent) => {
      if (e.key === 'Escape') return close()
      if (busy) return
      if (/^[0-9]$/.test(e.key)) press(e.key)
      else if (e.key === 'Enter') press('OK')
      else if (e.key === 'Backspace') { flash('C'); sfx.clear(); setCode((c) => c.slice(0, -1)) }
      else if (e.key.toLowerCase() === 'c' || e.key === 'Delete') press('C')
    }
    window.addEventListener('keydown', onKey)
    return () => window.removeEventListener('keydown', onKey)
  }, [busy, press, close])

  const buttons = state.buttons ?? []
  const lcd = state.lcd
  const housing = state.housing
  const W = window.innerWidth
  const H = window.innerHeight
  const box = (r: Rect) => ({ left: r.x0 * W, top: r.y0 * H, width: (r.x1 - r.x0) * W, height: (r.y1 - r.y0) * H })

  const text = display.kind === 'error' ? 'ERROR' : display.kind === 'open' ? 'OPEN' : display.kind === 'locked' ? 'LOCKED' : display.kind === 'busy' ? '....'
    : code.padEnd(4, '_').split('').join(' ')
  const colour = display.kind === 'error' || display.kind === 'locked' ? 'text-[#ff5a4f] [text-shadow:0_0_8px_rgba(255,80,70,0.9)]'
    : display.kind === 'open' ? 'text-[#7dff9b] [text-shadow:0_0_10px_rgba(110,255,150,0.95)]'
    : 'text-[#9dffb6] [text-shadow:0_0_7px_rgba(120,255,160,0.85)]'

  return (
    <div className="fixed inset-0 z-40 select-none">
      {/* browser preview only: a stand-in for the 3D keypad */}
      {!isNui && housing && <div className="absolute rounded-[10px] border-4 border-[#464a52] bg-[#1a1c20]" style={box(housing)} />}

      {/* the 12 buttons, laid over the prop's buttons */}
      {buttons.map((b) => (
        <button
          key={b.label}
          onMouseDown={(e) => { e.preventDefault(); press(b.label) }}
          className={cn(
            'absolute rounded-[6px] transition-[background,box-shadow] duration-75 outline-none',
            !isNui && 'bg-[#c4c7cc] text-[18px] font-black text-ink',
            'hover:bg-white/20 hover:shadow-[0_0_0_2px_rgba(255,255,255,0.55)]',
            pressed === b.label && 'bg-white/45 shadow-[0_0_0_2px_#fff,0_0_18px_rgba(255,255,255,0.6)]',
            busy && 'cursor-not-allowed',
          )}
          style={box(b)}
        >
          {!isNui && b.label}
        </button>
      ))}

      {/* LCD */}
      {lcd && (
        <div
          className={cn('absolute flex items-center justify-center overflow-hidden rounded-[3px] font-[Share_Tech_Mono] leading-none', !isNui && 'bg-[#0e2216]', colour)}
          style={{ ...box(lcd), fontSize: Math.max(10, (lcd.y1 - lcd.y0) * H * 0.62), fontFamily: "'Share Tech Mono', monospace", letterSpacing: '0.08em' }}
        >
          <span className={cn(display.kind === 'error' && 'animate-pulse')}>{text}</span>
        </div>
      )}

      {/* side card */}
      <div className="absolute top-1/2 right-[6%] w-[260px] -translate-y-1/2">
        <div className="slide-in-right overflow-hidden rounded-lg border border-white/[0.07] bg-panel/92 shadow-[0_12px_40px_rgba(0,0,0,0.7)] backdrop-blur-md">
          <div className="border-b border-white/[0.06] px-4 py-3">
            <div className="text-[10px] font-extrabold tracking-[0.16em] text-white/40 uppercase">Safe keypad</div>
            <div className="mt-0.5 truncate text-[18px] leading-tight font-black tracking-tight uppercase">{state.label || 'Safe'}</div>
          </div>
          <div className="flex items-center justify-between px-4 py-3">
            <span className="text-[10px] font-extrabold tracking-[0.16em] text-white/40 uppercase">Attempts left</span>
            <span className="flex gap-1">
              {Array.from({ length: Math.max(attempts, 0) }).map((_, i) => <span key={i} className="h-2 w-5 rounded-[2px] bg-white" />)}
              {attempts <= 0 && <span className="text-[11px] font-black text-bad uppercase">None</span>}
            </span>
          </div>
          <div className="grid grid-cols-2 gap-x-3 gap-y-2 border-t border-white/[0.06] bg-black/30 px-4 py-3 text-[10.5px] font-extrabold tracking-[0.06em] text-white/60 uppercase">
            <span className="flex items-center gap-1.5"><Kbd>0-9</Kbd> Type</span>
            <span className="flex items-center gap-1.5"><Kbd>Enter</Kbd> OK</span>
            <span className="flex items-center gap-1.5"><Kbd>⌫</Kbd> Delete</span>
            <span className="flex items-center gap-1.5"><Kbd>Esc</Kbd> Step away</span>
          </div>
        </div>
        <p className="mt-2 text-center text-[10.5px] font-bold tracking-[0.06em] text-white/55 uppercase [text-shadow:0_1px_4px_#000]">Click the buttons on the keypad</p>
      </div>
    </div>
  )
}

/** Browser preview layout, roughly where the game puts it. */
export function mockKeypad(): KeypadState {
  const cx = 0.45, cy = 0.5, w = 0.16, h = 0.62
  const cols = [-0.036, 0, 0.036], rows = [0.030, -0.002, -0.034, -0.066]
  const labels = [['1', '2', '3'], ['4', '5', '6'], ['7', '8', '9'], ['C', '0', 'OK']]
  const sx = w / 0.13, sy = h / 0.18
  const buttons = rows.flatMap((r, ri) => cols.map((c, ci) => ({
    label: labels[ri][ci],
    x0: cx + (c - 0.015) * sx * 0.5, x1: cx + (c + 0.015) * sx * 0.5,
    y0: cy - (r + 0.013) * sy * 0.5, y1: cy - (r - 0.013) * sy * 0.5,
  })))
  return {
    open: true, label: 'Vinewood Pawn back office', attemptsLeft: 3, buttons,
    lcd: { x0: cx - 0.05 * sx * 0.5, x1: cx + 0.05 * sx * 0.5, y0: cy - 0.076 * sy * 0.5, y1: cy - 0.052 * sy * 0.5 },
    housing: { x0: cx - 0.065 * sx * 0.5, x1: cx + 0.065 * sx * 0.5, y0: cy - 0.09 * sy * 0.5, y1: cy + 0.09 * sy * 0.5 },
  }
}
