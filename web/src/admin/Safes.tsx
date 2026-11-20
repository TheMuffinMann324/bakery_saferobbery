import { useState, type ReactNode } from 'react'
import { Box, Check, Copy, Dices, MapPinned, Navigation, Plus, RotateCcw, StickyNote, Trash2, Vault } from 'lucide-react'
import { cn } from '@/lib/utils'
import { call, nui } from '@/lib/nui'
import type { Coords, Kind, NotePos, Safe } from '@/lib/types'
import { Button } from '@/components/ui/button'
import { Input } from '@/components/ui/input'
import { Switch } from '@/components/ui/switch'
import { Dialog, DialogContent, DialogDescription, DialogHeader, DialogTitle } from '@/components/ui/dialog'
import { Empty, toast } from '@/components/common'
import { status, useAdmin } from './store'
import { Cell, EditorHeader, ListCard, ListRow, OpenChevron, Pill, SaveBar, Toolbar, Warning, control } from './fields'
import RewardsEditor from './Rewards'

type PlaceResult = Coords & { cancelled?: boolean; note?: NotePos }

const place = (opts: Record<string, unknown>) => nui<PlaceResult>('admin:place', opts, 0)
const NAME = { safe: 'Big safe', lockbox: 'Lockbox' } as const

export function KindBadge({ kind, className }: { kind: Kind; className?: string }) {
  const Icon = kind === 'lockbox' ? Box : Vault
  return (
    <span className={cn('flex size-10 shrink-0 -skew-x-[10deg] items-center justify-center rounded-[4px]', kind === 'lockbox' ? 'bg-[#8fa66a] text-ink' : 'bg-white text-ink', className)}>
      <Icon className="size-5 skew-x-[10deg]" />
    </span>
  )
}

export default function Safes() {
  const { data, saveSafe, now } = useAdmin()
  const [open, setOpen] = useState<string | null>(null)
  const [choosing, setChoosing] = useState(false)

  // Pick a type, place and test it in the world, then it's saved and opened for the rest.
  const create = async (kind: Kind) => {
    setChoosing(false)
    const res = await place({ mode: kind, label: kind === 'lockbox' ? 'New lockbox' : 'New safe' })
    if (!res || res.cancelled || res.x === undefined) return
    const area = await nui<{ label?: string }>('admin:area', res)
    const code = kind === 'safe' ? (await call<{ code?: string }>('admin:randomCode'))?.code : undefined
    const s = await saveSafe({
      kind, x: res.x, y: res.y, z: res.z, h: res.h ?? 0, enabled: true, code,
      label: area?.label ? `${area.label} ${kind === 'lockbox' ? 'lockbox' : 'safe'}` : NAME[kind],
    })
    if (s) {
      toast(kind === 'safe' ? 'Placed. Next: hide the code on a sticky note.' : 'Lockbox placed.', 'success')
      setOpen(s.id)
    }
  }

  const current = open ? data.safes.find((s) => s.id === open) : null
  if (current) return <Editor key={current.id} safe={current} onBack={() => setOpen(null)} onOpen={setOpen} />

  const cols = '44px minmax(0,1.6fr) minmax(0,1fr) 200px 24px'
  const noNote = data.safes.filter((s) => s.kind === 'safe' && s.enabled && !s.note)

  return (
    <div>
      <Toolbar text="Everything placed in the city. Click one to change it.">
        <Button onClick={() => setChoosing(true)}><Plus /> Add</Button>
      </Toolbar>
      {noNote.length > 0 && <Warning>{noNote.length === 1 ? `${noNote[0].label} has` : `${noNote.length} safes have`} no sticky note yet, so players can only blow {noNote.length === 1 ? 'it' : 'them'} open.</Warning>}
      {data.safes.length === 0 ? (
        <Empty title="Nothing placed yet" icon={<Vault />}>Press Add to put down your first safe or lockbox.</Empty>
      ) : (
        <ListCard cols={cols} head={['', 'Name', 'Way in', 'Status', '']} count={data.safes.length}>
          {data.safes.map((s) => {
            const st = status(s, now)
            return (
              <ListRow key={s.id} cols={cols} onOpen={() => setOpen(s.id)} muted={!s.enabled}>
                <KindBadge kind={s.kind} className="size-8 [&_svg]:size-4" />
                <Cell title={s.label} sub={NAME[s.kind]} />
                <span className="text-[12px] text-white/70">
                  {s.kind === 'lockbox' ? 'Break the padlock'
                    : s.note ? <span className="flex items-center gap-1.5">Code <span className="font-mono font-bold tracking-[0.15em] text-white">{s.code}</span> on a note</span>
                    : <span className="text-warn">Charge only, no note</span>}
                </span>
                <div className="min-w-0"><Pill tone={st.tone}>{st.text}</Pill></div>
                <OpenChevron />
              </ListRow>
            )
          })}
        </ListCard>
      )}

      <Dialog open={choosing} onOpenChange={setChoosing}>
        <DialogContent className="sm:max-w-lg">
          <DialogHeader>
            <DialogTitle>What are you placing?</DialogTitle>
            <DialogDescription>You'll place it with the free cam and try it out before it's saved.</DialogDescription>
          </DialogHeader>
          <div className="grid grid-cols-2 gap-3">
            <Choice kind="safe" title="Big safe" text="Keypad on the door. Players find the code on a sticky note, or blow the door off." onClick={() => create('safe')} />
            <Choice kind="lockbox" title="Lockbox" text="Small box with a padlock. Players break the padlock off." onClick={() => create('lockbox')} />
          </div>
        </DialogContent>
      </Dialog>
    </div>
  )
}

function Choice({ kind, title, text, onClick }: { kind: Kind; title: string; text: string; onClick: () => void }) {
  return (
    <button onClick={onClick} className="group flex flex-col items-start gap-3 rounded-lg border border-white/[0.08] bg-white/[0.03] p-4 text-left transition hover:border-white/40 hover:bg-white/[0.06]">
      <KindBadge kind={kind} />
      <span className="text-[15px] font-black tracking-tight uppercase">{title}</span>
      <span className="text-[11.5px] leading-relaxed text-white/50">{text}</span>
    </button>
  )
}

/** A numbered step of the editor: number, title and a line of help on the left, the controls on the right. */
function Step({ n, title, text, done, children }: { n: number; title: string; text: string; done?: boolean; children: ReactNode }) {
  return (
    <section className="grid grid-cols-[230px_minmax(0,1fr)] gap-6 border-t border-white/[0.05] py-5 first:border-t-0 first:pt-1">
      <div className="flex gap-3">
        <span className={cn('flex size-6 shrink-0 items-center justify-center rounded-full text-[11px] font-black', done ? 'bg-good text-ink' : 'bg-white/[0.08] text-white/60')}>
          {done ? <Check className="size-3.5" /> : n}
        </span>
        <div>
          <h4 className="text-[12px] font-black tracking-[0.12em] text-white uppercase">{title}</h4>
          <p className="mt-1 text-[11.5px] leading-relaxed text-white/40">{text}</p>
        </div>
      </div>
      <div className="flex min-w-0 flex-wrap items-center gap-2 self-center">{children}</div>
    </section>
  )
}

function Editor({ safe, onBack, onOpen }: { safe: Safe; onBack: () => void; onOpen: (id: string) => void }) {
  const { data, saveSafe, deleteSafe, resetSafe, now } = useAdmin()
  const [draft, setDraft] = useState<Safe>(() => structuredClone(safe))
  const [dirty, setDirty] = useState(false)
  const [saving, setSaving] = useState(false)
  const set = (fn: (d: Safe) => void) => { setDraft((d) => { const c = structuredClone(d); fn(c); return c }); setDirty(true) }
  const live = data.safes.find((s) => s.id === safe.id) ?? safe
  const st = status(live, now)
  const isSafe = draft.kind === 'safe'
  const codeOk = /^\d{4}$/.test(draft.code ?? '')
  const needsReset = live.state !== 'locked' || !!(live.lockoutUntil && live.lockoutUntil > now)

  const save = async () => {
    if (isSafe && !codeOk) { toast('The code has to be 4 digits.', 'error'); return }
    setSaving(true)
    const v = await saveSafe(draft)
    setSaving(false)
    if (v) { setDraft(structuredClone(v)); setDirty(false); toast('Saved.', 'success') }
  }

  const move = async () => {
    const res = await place({ mode: draft.kind, label: draft.label, start: { x: draft.x, y: draft.y, z: draft.z, h: draft.h } })
    if (res && !res.cancelled && res.x !== undefined) set((d) => { d.x = res.x; d.y = res.y; d.z = res.z; d.h = res.h ?? d.h })
  }
  const placeNote = async () => {
    const res = await place({ mode: 'note', label: `Code for ${draft.label}`, anchor: { x: draft.x, y: draft.y, z: draft.z, h: draft.h, kind: draft.kind, label: draft.label } })
    if (res?.note && !res.cancelled) set((d) => { d.note = res.note })
  }
  // Same safe, same rewards, somewhere else: place it, and it opens ready for its own note.
  const duplicate = async () => {
    if (dirty) { toast('Save your changes first.', 'error'); return }
    const res = await place({ mode: draft.kind, label: `Copy of ${draft.label}` })
    if (!res || res.cancelled || res.x === undefined) return
    const area = await nui<{ label?: string }>('admin:area', res)
    const code = isSafe ? (await call<{ code?: string }>('admin:randomCode'))?.code : undefined
    const copy = await saveSafe({
      kind: draft.kind, enabled: true, code, note: null,
      x: res.x, y: res.y, z: res.z, h: res.h ?? 0,
      label: area?.label ? `${area.label} ${isSafe ? 'safe' : 'lockbox'}` : `${draft.label} (copy)`,
      rewards: structuredClone(draft.rewards),
    })
    if (copy) {
      toast(isSafe ? 'Copied with the same rewards. Now hide its note.' : 'Copied with the same rewards.', 'success')
      onOpen(copy.id)
    }
  }

  const randomCode = async () => {
    const r = await call<{ code?: string }>('admin:randomCode')
    if (r?.code) set((d) => { d.code = r.code })
  }

  return (
    <div>
      <EditorHeader
        back="Back to the list"
        onBack={onBack}
        title={draft.label}
        meta={NAME[draft.kind]}
        badge={<KindBadge kind={draft.kind} />}
        onDelete={async () => { if (await deleteSafe(draft.id)) onBack() }}
        deleteText="Removes it from the world for everyone. This can't be undone."
      >
        <Pill tone={st.tone}>{st.text}</Pill>
        {needsReset && <Button size="sm" variant="secondary" onClick={() => resetSafe(draft.id)}><RotateCcw /> Lock it again</Button>}
        <Button size="sm" variant="secondary" onClick={duplicate}><Copy /> Duplicate</Button>
      </EditorHeader>

      <Step n={1} title="Name" text="Shown in this panel and in police alerts." done={!!draft.label}>
        <Input className={cn(control, 'w-[320px]')} value={draft.label} maxLength={48} onChange={(e) => set((d) => { d.label = e.target.value })} />
        <label className="ml-auto flex items-center gap-2 text-[11px] font-extrabold tracking-[0.08em] text-white/60 uppercase">
          <Switch checked={draft.enabled} onCheckedChange={(v) => set((d) => { d.enabled = v })} /> {draft.enabled ? 'In the world' : 'Hidden'}
        </label>
      </Step>

      <Step n={2} title="Location" text="Opens the free cam so you can move it and test it again." done>
        <Button size="sm" variant="secondary" onClick={move}><MapPinned /> Move it</Button>
        <Button size="sm" variant="ghost" onClick={() => nui('admin:teleport', { ...draft })}><Navigation /> Go there</Button>
      </Step>

      {isSafe && (
        <>
          <Step n={3} title="Keypad code" text={data.settings.randomizeCode ? 'Changes by itself every time the safe resets (see Settings).' : 'The 4 digits that open the safe.'} done={codeOk}>
            <Input
              className={cn(control, 'h-11 w-[150px] text-center font-mono text-[24px] font-black tracking-[0.5em]')}
              value={draft.code ?? ''}
              maxLength={4}
              inputMode="numeric"
              onChange={(e) => { const v = e.target.value.replace(/\D/g, '').slice(0, 4); set((d) => { d.code = v }) }}
            />
            <Button size="sm" variant="ghost" onClick={randomCode}><Dices /> Random</Button>
          </Step>
          <Step n={4} title="Sticky note" text="Hide the code somewhere players can find it: a desk, a wall, behind a monitor." done={!!draft.note}>
            <Button size="sm" variant={draft.note ? 'secondary' : 'default'} onClick={placeNote}><StickyNote /> {draft.note ? 'Move the note' : 'Place the note'}</Button>
            {draft.note && <Button size="sm" variant="ghost" className="hover:text-bad" onClick={() => set((d) => { d.note = null })}><Trash2 /> Remove</Button>}
          </Step>
        </>
      )}

      <Step n={isSafe ? 5 : 3} title="Rewards" text="What this one can have inside. Duplicate copies these to a new spot." done={(draft.rewards?.items.length ?? 0) > 0}>
        {draft.rewards && <RewardsEditor kind={draft.kind} value={draft.rewards} onChange={(fn) => set((d) => { if (d.rewards) fn(d.rewards) })} />}
      </Step>

      <SaveBar dirty={dirty} saving={saving} onSave={save} onDiscard={() => { setDraft(structuredClone(safe)); setDirty(false) }} />
    </div>
  )
}
