import { useEffect, useId, useState, type ReactNode } from 'react'
import { Banknote, Box, Diamond, FileText, FlaskConical, Gem, Leaf, Package, Pill, Snowflake, Sparkles, Watch } from 'lucide-react'
import { cn } from '@/lib/utils'
import type { Category } from '@/lib/types'

// The Bakery B-snap mark (same as bakery_racing / bakery_boosting).
const B_PATH =
  'M155 118 L274 118 C327 118 353 146 353 188 C353 214 340 234 321 243 C352 253 370 277 370 312 C370 359 336 390 279 390 L155 390Z M216 171 L268 171 C288 171 299 181 299 197 C299 214 288 224 268 224 L216 224Z M216 278 L277 278 C300 278 313 288 313 307 C313 327 300 338 277 338 L216 338Z'

export function Logo({ className, still, color = '#f6f6f5' }: { className?: string; still?: boolean; color?: string }) {
  const id = useId().replace(/:/g, '')
  return (
    <svg viewBox="0 0 512 512" className={cn(still && 'snap-still', className)} role="img" aria-label="Bakery">
      <defs>
        <path id={`b-${id}`} fillRule="evenodd" d={B_PATH} />
        <clipPath id={`top-${id}`}><path d="M0 0H512V212.56L0 274Z" /></clipPath>
        <clipPath id={`bottom-${id}`}><path d="M0 284L512 222.56V512H0Z" /></clipPath>
        <mask id={`stripes-${id}`} maskUnits="userSpaceOnUse" x="0" y="0" width="512" height="512">
          <rect width="512" height="512" fill="white" />
          <path d="M80 233.8L420 131.8 M80 246.8L420 144.8 M80 377.8L420 275.8 M80 390.8L420 288.8" fill="none" stroke="black" strokeWidth="3" />
        </mask>
      </defs>
      <g transform="matrix(1 0 -.13 1 33.28 0)" fill={color}>
        <g className="snap-top"><g clipPath={`url(#top-${id})`}><use href={`#b-${id}`} mask={`url(#stripes-${id})`} /></g></g>
        <g className="snap-bottom"><g clipPath={`url(#bottom-${id})`}><use href={`#b-${id}`} mask={`url(#stripes-${id})`} /></g></g>
      </g>
    </svg>
  )
}

export function Kbd({ children, className }: { children: ReactNode; className?: string }) {
  return (
    <kbd className={cn('inline-flex h-5 min-w-5 items-center justify-center rounded-[4px] bg-[#f2f2f2] px-1.5 font-sans text-[10px] font-black tracking-[0.04em] text-ink uppercase shadow-[inset_0_-2px_0_rgba(0,0,0,0.2)]', className)}>
      {children}
    </kbd>
  )
}

export function StatTile({ label, value, sub, icon }: { label: string; value: ReactNode; sub?: ReactNode; icon?: ReactNode }) {
  return (
    <div className="relative overflow-hidden rounded-lg border border-white/[0.06] bg-white/[0.025] p-4">
      <div className="flex items-center justify-between text-white/35 [&_svg]:size-3.5">
        <span className="text-[10px] font-extrabold tracking-[0.14em] uppercase">{label}</span>
        {icon}
      </div>
      <div className="tnum mt-2.5 text-[26px] leading-none font-black tracking-tight text-white">{value}</div>
      {sub && <div className="mt-1.5 truncate text-[11.5px] text-white/35">{sub}</div>}
    </div>
  )
}

export function Empty({ title, children, icon }: { title: string; children?: ReactNode; icon?: ReactNode }) {
  return (
    <div className="hatch flex flex-col items-center justify-center gap-2 rounded-lg border border-dashed border-white/[0.08] px-8 py-10 text-center">
      {icon && <div className="text-white/25 [&_svg]:size-5">{icon}</div>}
      <p className="text-[12.5px] font-extrabold tracking-[0.06em] text-white/65 uppercase">{title}</p>
      {children && <p className="text-xs text-white/30">{children}</p>}
    </div>
  )
}

// ---------- loot categories ----------

export const CATEGORIES: { value: Category; label: string; icon: typeof Banknote }[] = [
  { value: 'cash', label: 'Money piles', icon: Banknote },
  { value: 'jewelry', label: 'Jewelry', icon: Gem },
  { value: 'watches', label: 'Watches', icon: Watch },
  { value: 'diamonds', label: 'Diamonds', icon: Diamond },
  { value: 'gold', label: 'Gold bars', icon: Sparkles },
  { value: 'coke', label: 'Coke', icon: Snowflake },
  { value: 'weed', label: 'Weed', icon: Leaf },
  { value: 'meth', label: 'Meth', icon: FlaskConical },
  { value: 'drugs', label: 'Drug package', icon: Pill },
  { value: 'valuables', label: 'Valuables', icon: Box },
  { value: 'documents', label: 'Documents', icon: FileText },
  { value: 'other', label: 'Other', icon: Package },
]

// ---------- toasts ----------

type ToastKind = 'success' | 'error' | 'info'
interface Toast { id: number; message: string; kind: ToastKind }
let nextId = 1
const listeners = new Set<(t: Toast[]) => void>()
let toasts: Toast[] = []

export function toast(message: string, kind: ToastKind = 'info') {
  const t = { id: nextId++, message, kind }
  toasts = [...toasts.slice(-3), t]
  listeners.forEach((l) => l(toasts))
  window.setTimeout(() => {
    toasts = toasts.filter((x) => x.id !== t.id)
    listeners.forEach((l) => l(toasts))
  }, 3500)
}

export function Toaster({ className }: { className?: string }) {
  const [list, setList] = useState<Toast[]>(toasts)
  useEffect(() => {
    listeners.add(setList)
    return () => { listeners.delete(setList) }
  }, [])
  return (
    <div className={cn('pointer-events-none absolute bottom-5 left-1/2 z-[60] flex -translate-x-1/2 flex-col items-center gap-2', className)}>
      {list.map((t) => (
        <div
          key={t.id}
          className={cn(
            'pop-in flex items-center gap-2 rounded-md border px-3.5 py-2 text-[11px] font-extrabold tracking-[0.05em] uppercase shadow-[0_12px_32px_rgba(0,0,0,0.6)]',
            t.kind === 'error' && 'border-bad/25 bg-[#1a1113] text-bad',
            t.kind === 'success' && 'border-transparent bg-white text-ink',
            t.kind === 'info' && 'border-white/[0.08] bg-raised text-white',
          )}
        >
          {t.message}
        </div>
      ))}
    </div>
  )
}

export function money(n: number) {
  return '$' + Math.round(n).toLocaleString('en-US')
}

export function clock(sec: number) {
  sec = Math.max(0, Math.floor(sec))
  const h = Math.floor(sec / 3600)
  const m = Math.floor((sec % 3600) / 60)
  const s = sec % 60
  if (h > 0) return `${h}h ${m}m`
  if (m > 0) return `${m}m ${s.toString().padStart(2, '0')}s`
  return `${s}s`
}
