// The same building blocks as bakery_boosting's admin panel, so both read the same way:
//   Toolbar   - one line on what the tab is for, then its buttons
//   ListCard  - overview of everything in the tab; click a row to open it
//   EditorHeader + Group / Row - the editor for one thing
//   SaveBar   - pinned to the bottom whenever there's something to save
import { useEffect, useState, type HTMLAttributes, type ReactNode } from 'react'
import { AlertTriangle, ArrowLeft, ChevronRight, Minus, Plus, RotateCcw, Save, Trash2 } from 'lucide-react'
import { cn } from '@/lib/utils'
import { Button } from '@/components/ui/button'
import { Input } from '@/components/ui/input'
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from '@/components/ui/select'
import { Dialog, DialogContent, DialogDescription, DialogFooter, DialogHeader, DialogTitle } from '@/components/ui/dialog'

export function Toolbar({ text, children }: { text: ReactNode; children?: ReactNode }) {
  return (
    <div className="mb-4 flex min-h-8 items-center gap-2">
      <p className="mr-auto max-w-[560px] text-[11.5px] leading-relaxed text-white/45">{text}</p>
      {children}
    </div>
  )
}

export function DefaultsButton({ what, onReset }: { what: string; onReset: () => void }) {
  const [open, setOpen] = useState(false)
  return (
    <>
      <Button size="sm" variant="ghost" onClick={() => setOpen(true)}><RotateCcw /> Defaults</Button>
      <Confirm open={open} onOpenChange={setOpen} title="Restore defaults?" text={`Replaces all ${what} with the defaults from config.lua. Anything you've changed here is lost.`} confirm="Restore" onConfirm={onReset} />
    </>
  )
}

export function Confirm({ open, onOpenChange, title, text, confirm, onConfirm }: {
  open: boolean; onOpenChange: (v: boolean) => void; title: string; text: string; confirm: string; onConfirm: () => void
}) {
  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent className="sm:max-w-sm">
        <DialogHeader>
          <DialogTitle>{title}</DialogTitle>
          <DialogDescription>{text}</DialogDescription>
        </DialogHeader>
        <DialogFooter>
          <Button variant="ghost" onClick={() => onOpenChange(false)}>Cancel</Button>
          <Button variant="destructive" onClick={() => { onOpenChange(false); onConfirm() }}>{confirm}</Button>
        </DialogFooter>
      </DialogContent>
    </Dialog>
  )
}

export function SaveBar({ dirty, onSave, onDiscard, saving }: { dirty: boolean; onSave: () => void; onDiscard: () => void; saving?: boolean }) {
  if (!dirty) return null
  return (
    <div className="pointer-events-none sticky bottom-0 z-20 flex justify-center pt-5">
      <div className="fade-up pointer-events-auto flex items-center gap-3 rounded-lg border border-warn/25 bg-raised py-1.5 pr-1.5 pl-4 shadow-[0_14px_40px_rgba(0,0,0,0.75)]">
        <span className="pulse-dot size-1.5 rounded-full bg-warn" />
        <span className="text-[10.5px] font-extrabold tracking-[0.12em] text-white/80 uppercase">Unsaved changes</span>
        <span className="text-[11px] text-white/35">Nothing changes in game until you save</span>
        <div className="ml-2 flex gap-1.5">
          <Button size="sm" variant="ghost" onClick={onDiscard}>Discard</Button>
          <Button size="sm" disabled={saving} onClick={onSave}><Save /> Save changes</Button>
        </div>
      </div>
    </div>
  )
}

export function Warning({ children }: { children: ReactNode }) {
  return (
    <div className="mb-4 flex items-center gap-2.5 rounded-lg border border-warn/20 bg-warn/[0.06] px-4 py-2.5 text-[11.5px] text-warn">
      <AlertTriangle className="size-4 shrink-0" /> <span>{children}</span>
    </div>
  )
}

export function ListCard({ cols, head, children, empty, count }: { cols: string; head: ReactNode[]; children: ReactNode; empty?: ReactNode; count: number }) {
  return (
    <div className="overflow-hidden rounded-lg border border-white/[0.06] bg-white/[0.025]">
      <div className="grid items-center gap-3 border-b border-white/[0.06] px-4 py-2 text-[9.5px] font-extrabold tracking-[0.14em] text-white/35 uppercase" style={{ gridTemplateColumns: cols }}>
        {head.map((h, i) => <span key={i}>{h}</span>)}
      </div>
      {children}
      {count === 0 && <div className="px-4 py-10 text-center text-[11.5px] text-white/35">{empty ?? 'Nothing here yet.'}</div>}
    </div>
  )
}

export function ListRow({ cols, onOpen, muted, className, children, ...rest }: {
  cols: string; onOpen?: () => void; muted?: boolean; className?: string; children: ReactNode
} & Omit<HTMLAttributes<HTMLDivElement>, 'children' | 'onClick'>) {
  return (
    <div
      {...rest}
      onClick={onOpen}
      style={{ gridTemplateColumns: cols }}
      className={cn('group grid items-center gap-3 border-b border-white/[0.04] px-4 py-3 transition-colors last:border-0', onOpen && 'cursor-pointer hover:bg-white/[0.035]', className)}
    >
      {muted ? <div className="contents [&>*:not(.keep)]:opacity-40">{children}</div> : children}
    </div>
  )
}

export function OpenChevron() {
  return <ChevronRight className="keep ml-auto size-4 text-white/25 transition group-hover:translate-x-0.5 group-hover:text-white" />
}

export function NoOpen({ children, className }: { children: ReactNode; className?: string }) {
  return <div className={cn('keep', className)} onClick={(e) => e.stopPropagation()}>{children}</div>
}

export function Cell({ title, sub, mono }: { title: ReactNode; sub?: ReactNode; mono?: boolean }) {
  return (
    <div className="min-w-0">
      <div className="truncate text-[13px] font-bold">{title}</div>
      {sub != null && <div className={cn('mt-0.5 truncate text-[10.5px] text-white/35', mono && 'font-mono')}>{sub}</div>}
    </div>
  )
}

export function Pill({ tone, children }: { tone: 'good' | 'warn' | 'bad' | 'mute'; children: ReactNode }) {
  return (
    <span className={cn(
      'keep inline-flex h-6 items-center gap-1.5 rounded-[4px] px-2 text-[10px] font-extrabold tracking-[0.08em] whitespace-nowrap uppercase',
      tone === 'good' && 'bg-good/10 text-good',
      tone === 'warn' && 'bg-warn/10 text-warn',
      tone === 'bad' && 'bg-bad/10 text-bad',
      tone === 'mute' && 'bg-white/[0.06] text-white/45',
    )}>
      <span className={cn('size-1.5 rounded-full bg-current', tone !== 'mute' && 'pulse-dot')} />
      {children}
    </span>
  )
}

export function EditorHeader({ back, onBack, title, meta, badge, onDelete, deleteText, children }: {
  back: string; onBack: () => void; title: string; meta?: ReactNode; badge?: ReactNode
  onDelete?: () => void; deleteText?: string; children?: ReactNode
}) {
  const [confirm, setConfirm] = useState(false)
  return (
    <div className="mb-4 space-y-3">
      <button onClick={onBack} className="flex items-center gap-1.5 text-[10.5px] font-extrabold tracking-[0.12em] text-white/45 uppercase transition hover:text-white">
        <ArrowLeft className="size-3.5" /> {back}
      </button>
      <div className="flex items-center gap-4 rounded-lg border border-white/[0.06] bg-white/[0.025] px-4 py-3">
        {badge}
        <div className="min-w-0 flex-1">
          <div className="truncate text-[20px] leading-none font-black tracking-tight uppercase">{title || 'Untitled'}</div>
          {meta && <div className="mt-1.5 text-[11px] text-white/40">{meta}</div>}
        </div>
        {children}
        {onDelete && <Button size="sm" variant="ghost" className="hover:text-bad" onClick={() => setConfirm(true)}><Trash2 /> Delete</Button>}
      </div>
      {onDelete && <Confirm open={confirm} onOpenChange={setConfirm} title={`Delete ${title || 'this'}?`} text={deleteText ?? 'This can\'t be undone.'} confirm="Delete" onConfirm={onDelete} />}
    </div>
  )
}

export function Group({ title, text, children, actions }: { title: string; text?: string; children: ReactNode; actions?: ReactNode }) {
  return (
    <section className="grid grid-cols-[190px_minmax(0,1fr)] gap-6 border-t border-white/[0.05] py-5 first:border-t-0 first:pt-1">
      <div className="pt-2">
        <h4 className="text-[11px] font-black tracking-[0.16em] text-white uppercase">{title}</h4>
        {text && <p className="mt-1.5 text-[11.5px] leading-relaxed text-white/40">{text}</p>}
        {actions && <div className="mt-3 flex flex-col items-start gap-1.5">{actions}</div>}
      </div>
      <div className="min-w-0 divide-y divide-white/[0.04] self-start overflow-hidden rounded-lg border border-white/[0.06] bg-white/[0.025]">{children}</div>
    </section>
  )
}

export function Grid({ title, children }: { title?: string; children: ReactNode }) {
  return (
    <section className="mb-5 last:mb-0">
      {title && <h4 className="mb-2.5 text-[11px] font-black tracking-[0.16em] text-white uppercase">{title}</h4>}
      <div className="grid grid-cols-2 overflow-hidden rounded-lg border border-white/[0.06] bg-white/[0.025] [&>*:last-child:nth-child(odd)]:col-span-2 [&>*:last-child:nth-child(odd)]:border-r-0 [&>*:nth-child(n+3)]:border-t [&>*:nth-child(n+3)]:border-white/[0.04] [&>*:nth-child(odd)]:border-r [&>*:nth-child(odd)]:border-white/[0.04]">
        {children}
      </div>
    </section>
  )
}

export function Row({ icon, title, text, children, wide }: { icon?: ReactNode; title: string; text?: string; children: ReactNode; wide?: boolean }) {
  return (
    <div className="flex min-w-0 items-center justify-between gap-4 px-4 py-3.5">
      <div className="flex min-w-0 items-center gap-3">
        {icon && <span className="flex size-4 shrink-0 items-center justify-center text-white/35 [&_svg]:size-4">{icon}</span>}
        <div className="min-w-0">
          <p className="text-[13px] font-medium">{title}</p>
          {text && <p className="mt-0.5 text-[11px] leading-snug text-white/40">{text}</p>}
        </div>
      </div>
      <div className={cn('flex shrink-0 items-center justify-end gap-2', wide ? 'w-[300px]' : 'w-[168px]')}>{children}</div>
    </div>
  )
}

export const control = 'h-8 rounded-[5px] border-white/[0.06] bg-black/40 text-[12.5px] font-bold'

export function TextField({ value, onChange, mono, placeholder, maxLength, className }: {
  value: string; onChange: (v: string) => void; mono?: boolean; placeholder?: string; maxLength?: number; className?: string
}) {
  return (
    <Input
      className={cn(control, 'w-full text-right', mono && 'font-mono text-[12px] font-medium', className)}
      value={value}
      placeholder={placeholder}
      maxLength={maxLength}
      onChange={(e) => onChange(e.target.value)}
    />
  )
}

export function SelectField({ value, onChange, options, className }: { value: string; onChange: (v: string) => void; options: { value: string; label: ReactNode }[]; className?: string }) {
  return (
    <Select value={value} onValueChange={onChange}>
      <SelectTrigger className={cn(control, 'w-full', className)}><SelectValue /></SelectTrigger>
      <SelectContent>{options.map((o) => <SelectItem key={o.value} value={o.value}>{o.label}</SelectItem>)}</SelectContent>
    </Select>
  )
}

export function Segmented<T extends string>({ value, onChange, options }: { value: T; onChange: (v: T) => void; options: { value: T; label: ReactNode }[] }) {
  return (
    <div className="flex gap-1 rounded-md bg-white/[0.05] p-0.5">
      {options.map((o) => (
        <button
          key={o.value}
          type="button"
          onClick={() => onChange(o.value)}
          className={cn('h-7 rounded-[5px] px-2.5 text-[10.5px] font-extrabold tracking-[0.07em] whitespace-nowrap uppercase transition', value === o.value ? 'bg-white text-ink' : 'text-white/50 hover:text-white')}
        >
          {o.label}
        </button>
      ))}
    </div>
  )
}

export function NumberInput({ value, onChange, step, min, max, className }: { value: number | null | undefined; onChange: (v: number) => void; step?: number; min?: number; max?: number; className?: string }) {
  const [text, setText] = useState(value == null ? '' : String(value))
  useEffect(() => { if (Number(text) !== value) setText(value == null ? '' : String(value)) }, [value]) // eslint-disable-line react-hooks/exhaustive-deps
  return (
    <Input
      type="number"
      className={cn('tnum', className)}
      value={text}
      step={step}
      min={min}
      max={max}
      onChange={(e) => {
        setText(e.target.value)
        const n = parseFloat(e.target.value)
        if (!Number.isNaN(n)) onChange(n)
      }}
    />
  )
}

export function Stepper({ value, onChange, step, min, max, unit, full }: { value: number; onChange: (v: number) => void; step: number; min: number; max: number; unit?: string; full?: boolean }) {
  const fix = (v: number) => Math.round(Math.min(max, Math.max(min, v)) * 100) / 100
  const btn = 'flex h-full w-8 shrink-0 items-center justify-center text-white/40 transition hover:bg-white/[0.07] hover:text-white disabled:pointer-events-none disabled:opacity-25'
  return (
    <div className={cn('flex h-8 items-center overflow-hidden rounded-[5px] border border-white/[0.06] bg-black/40', full ? 'w-full' : 'w-[168px]')}>
      <button type="button" className={btn} disabled={value <= min} onClick={() => onChange(fix(value - step))}><Minus className="size-3.5" /></button>
      <div className="flex min-w-0 flex-1 items-baseline justify-center gap-1 px-1">
        <NumberInput className="h-6 w-16 border-0 bg-transparent p-0 text-center text-[12.5px] font-bold tnum shadow-none focus-visible:shadow-none" step={step} min={min} max={max} value={value} onChange={(v) => onChange(fix(v))} />
        {unit && <span className="text-[9.5px] font-extrabold tracking-[0.12em] text-white/35 uppercase">{unit}</span>}
      </div>
      <button type="button" className={btn} disabled={value >= max} onClick={() => onChange(fix(value + step))}><Plus className="size-3.5" /></button>
    </div>
  )
}

/** Comma separated list edited as text (police jobs). */
export function TagsField({ value, onChange }: { value: string[]; onChange: (v: string[]) => void }) {
  const [text, setText] = useState(value.join(', '))
  useEffect(() => { setText(value.join(', ')) }, [value.join(',')]) // eslint-disable-line react-hooks/exhaustive-deps
  return (
    <Input
      className={cn(control, 'w-full text-right font-mono text-[12px] font-medium')}
      value={text}
      onChange={(e) => setText(e.target.value)}
      onBlur={() => onChange(text.split(',').map((s) => s.trim()).filter(Boolean))}
    />
  )
}
