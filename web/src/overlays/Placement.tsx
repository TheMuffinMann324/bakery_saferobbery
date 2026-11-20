import { AlertTriangle, CheckCircle2, XCircle } from 'lucide-react'
import { cn } from '@/lib/utils'
import { Kbd } from '@/components/common'

export interface PlaceState {
  active: boolean
  mode?: 'safe' | 'lockbox' | 'note'
  stage?: 'aim' | 'test'
  label?: string
  issues?: { text: string; level: 'warn' | 'bad' }[]
  level?: 'ok' | 'warn' | 'bad'
  snapped?: boolean
  opened?: boolean
  speed?: number
  hasAim?: boolean
}

const NOUN = { safe: 'safe', lockbox: 'lockbox', note: 'sticky note' } as const

// Free-cam placement HUD: what you're placing and whether the spot is good up top,
// and only the keys that matter right now along the bottom.
export default function Placement({ state }: { state: PlaceState }) {
  const mode = state.mode ?? 'safe'
  const test = state.stage === 'test'
  const issues = Array.isArray(state.issues) ? state.issues : []
  const level = test ? 'ok' : state.level ?? 'ok'

  const step = mode === 'note' ? 'Stick the note somewhere' : test ? `Step 2 of 2 · Try it out` : `Step 1 of 2 · Put the ${NOUN[mode]} down`
  const keys: [string, string][] = test
    ? [
      ['O', state.opened ? 'Close it' : 'Open it'],
      ...(mode === 'safe' && !state.opened ? [['X', 'Blow it open'] as [string, string]] : []),
      ['Enter', 'Save'],
      ['Backspace', 'Move it again'],
    ]
    : [['E', mode === 'note' ? 'Stick it here' : 'Put it here'], ['Scroll', mode === 'note' ? 'Spin' : 'Turn']]

  return (
    <div className="pointer-events-none fixed inset-0 z-30">
      {/* top: what and how good the spot is */}
      <div className="absolute top-6 left-1/2 flex -translate-x-1/2 flex-col items-center gap-2">
        <div className="pop-in flex items-stretch overflow-hidden rounded-lg border border-white/[0.07] bg-panel/92 shadow-[0_12px_40px_rgba(0,0,0,0.7)] backdrop-blur-md">
          <div className={cn('w-1', level === 'ok' && 'bg-good', level === 'warn' && 'bg-warn', level === 'bad' && 'bg-bad')} />
          <div className="px-5 py-3 text-center">
            <div className="text-[10px] font-extrabold tracking-[0.16em] text-white/40 uppercase">{step}</div>
            <div className="text-[20px] leading-tight font-black tracking-tight text-white uppercase">{state.label || NOUN[mode]}</div>
          </div>
        </div>
        {!test && state.hasAim && <Status level={level} issues={issues} mode={mode} snapped={!!state.snapped} />}
        {!test && !state.hasAim && <Hint>{mode === 'note' ? 'Aim at a wall, a desk or the floor' : 'Aim at the floor'}</Hint>}
        {test && <Hint>Fly round it and check it looks right</Hint>}
      </div>

      {/* bottom: the keys */}
      <div className="absolute bottom-6 left-1/2 flex -translate-x-1/2 flex-col items-center gap-2">
        <div className="flex items-center gap-5 rounded-lg border border-white/[0.07] bg-panel/92 px-5 py-3 shadow-[0_12px_40px_rgba(0,0,0,0.7)] backdrop-blur-md">
          {keys.map(([k, label]) => (
            <span key={k} className="flex items-center gap-2 whitespace-nowrap">
              <Kbd className="h-6 min-w-6 text-[11px]">{k}</Kbd>
              <span className="text-[12.5px] font-extrabold tracking-[0.03em] text-white uppercase">{label}</span>
            </span>
          ))}
          <span className="h-5 w-px bg-white/[0.12]" />
          <span className="flex items-center gap-2 whitespace-nowrap">
            <Kbd className="h-6 min-w-6 bg-white/45 text-[11px]">Esc</Kbd>
            <span className="text-[12.5px] font-extrabold tracking-[0.03em] text-white/55 uppercase">Cancel</span>
          </span>
        </div>
        <p className="text-[10.5px] font-bold tracking-[0.08em] text-white/55 uppercase [text-shadow:0_1px_3px_#000]">
          WASD move · Space / Ctrl up and down · Shift faster
        </p>
      </div>
    </div>
  )
}

function Hint({ children }: { children: string }) {
  return <p className="text-[11px] font-bold tracking-[0.06em] text-white/80 uppercase [text-shadow:0_1px_4px_rgba(0,0,0,0.9)]">{children}</p>
}

function Status({ level, issues, mode, snapped }: { level: 'ok' | 'warn' | 'bad'; issues: { text: string; level: 'warn' | 'bad' }[]; mode: string; snapped: boolean }) {
  const Icon = level === 'ok' ? CheckCircle2 : level === 'warn' ? AlertTriangle : XCircle
  const text = level === 'ok'
    ? mode === 'note' ? 'Good spot' : snapped ? 'Good spot · backed against the wall' : 'Good spot'
    : issues[0]?.text ?? ''
  return (
    <div className="flex flex-col items-center gap-1">
      <span className={cn(
        'flex items-center gap-1.5 rounded-md border px-3 py-1.5 text-[11px] font-extrabold tracking-[0.06em] uppercase backdrop-blur-md',
        level === 'ok' && 'border-good/25 bg-[#0f1a13]/90 text-good',
        level === 'warn' && 'border-warn/25 bg-[#1a160c]/90 text-warn',
        level === 'bad' && 'border-bad/25 bg-[#1a1113]/90 text-bad',
      )}>
        <Icon className="size-3.5" /> {text}
        {issues.length > 1 && <span className="text-white/45">+{issues.length - 1} more</span>}
      </span>
      {level === 'bad' && <span className="text-[10px] font-bold tracking-[0.08em] text-white/45 uppercase [text-shadow:0_1px_3px_#000]">Hold Shift + E to place it anyway</span>}
    </div>
  )
}
