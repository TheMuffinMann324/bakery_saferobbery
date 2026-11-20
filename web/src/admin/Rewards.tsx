import { Plus, Trash2 } from 'lucide-react'
import { cn } from '@/lib/utils'
import type { Kind, LootItem, Rewards } from '@/lib/types'
import { Button } from '@/components/ui/button'
import { Input } from '@/components/ui/input'
import { CATEGORIES, money } from '@/components/common'
import { NumberInput, SelectField, Stepper, Warning, control } from './fields'

// What one safe / lockbox can have inside. Every entry rolls its own chance when it's opened.
export default function RewardsEditor({ kind, value, onChange }: { kind: Kind; value: Rewards; onChange: (fn: (r: Rewards) => void) => void }) {
  const cap = kind === 'lockbox' ? 3 : 6
  const cols = '160px minmax(0,1fr) minmax(0,1fr) 172px 68px 68px 70px 32px'
  const setItem = (i: number, fn: (e: LootItem) => void) => onChange((r) => fn(r.items[i]))
  const guaranteed = value.items.filter((e) => e.chance >= 100).length

  return (
    <div className="w-full space-y-3">
      <div className="flex flex-wrap items-center gap-4">
        <span className="flex items-center gap-2 text-[11px] font-extrabold tracking-[0.08em] text-white/55 uppercase">
          At least <Stepper value={value.minItems} onChange={(v) => onChange((r) => { r.minItems = Math.min(v, r.maxItems) })} step={1} min={0} max={cap} unit="items" />
        </span>
        <span className="flex items-center gap-2 text-[11px] font-extrabold tracking-[0.08em] text-white/55 uppercase">
          At most <Stepper value={value.maxItems} onChange={(v) => onChange((r) => { r.maxItems = v; r.minItems = Math.min(r.minItems, v) })} step={1} min={1} max={cap} unit="items" />
        </span>
        <span className="text-[11px] text-white/35">Room for {cap} things inside</span>
      </div>

      {guaranteed > value.maxItems && <Warning>{guaranteed} rewards are at 100% but only {value.maxItems} fit, so some won't make it in.</Warning>}

      <div className="overflow-hidden rounded-lg border border-white/[0.06] bg-black/20">
        <div className="grid items-center gap-2 border-b border-white/[0.06] px-3 py-2 text-[9.5px] font-extrabold tracking-[0.14em] text-white/35 uppercase" style={{ gridTemplateColumns: cols }}>
          <span>Looks like</span><span>Item name</span><span>Label</span><span>Gives</span><span>Min</span><span>Max</span><span>Chance</span><span />
        </div>
        {value.items.length === 0 && <div className="px-4 py-6 text-center text-[11.5px] text-white/35">Nothing yet. With no rewards it opens empty.</div>}
        {value.items.map((e, i) => (
          <div key={i} className="grid items-center gap-2 border-b border-white/[0.04] px-3 py-2 last:border-0" style={{ gridTemplateColumns: cols }}>
            <SelectField value={e.category} onChange={(v) => setItem(i, (x) => { x.category = v as LootItem['category'] })}
              options={CATEGORIES.map((c) => ({ value: c.value, label: <span className="flex items-center gap-1.5"><c.icon className="size-3.5" />{c.label}</span> }))} />
            <Input className={cn(control, 'font-mono text-[12px] font-medium')} value={e.item} disabled={e.type === 'money'} placeholder="item_name" onChange={(ev) => setItem(i, (x) => { x.item = ev.target.value.trim() })} />
            <Input className={control} value={e.label} maxLength={48} onChange={(ev) => setItem(i, (x) => { x.label = ev.target.value })} />
            <div className="flex gap-1">
              <SelectField className="w-[92px]" value={e.type} onChange={(v) => setItem(i, (x) => { x.type = v as LootItem['type']; if (v === 'money') { x.item = 'money'; x.account = x.account || 'cash' } })}
                options={[{ value: 'item', label: 'Item' }, { value: 'money', label: 'Money' }]} />
              {e.type === 'money' && <Input className={cn(control, 'w-[66px] font-mono text-[11px]')} value={e.account ?? 'cash'} title="Account" onChange={(ev) => setItem(i, (x) => { x.account = ev.target.value.trim() })} />}
            </div>
            <NumberInput className={cn(control, 'text-center')} min={1} value={e.min} onChange={(v) => setItem(i, (x) => { x.min = Math.max(1, Math.round(v)) })} />
            <NumberInput className={cn(control, 'text-center')} min={1} value={e.max} onChange={(v) => setItem(i, (x) => { x.max = Math.max(1, Math.round(v)) })} />
            <div className="relative">
              <NumberInput className={cn(control, 'pr-5 text-center')} min={0} max={100} value={e.chance} onChange={(v) => setItem(i, (x) => { x.chance = Math.min(100, Math.max(0, Math.round(v))) })} />
              <span className="pointer-events-none absolute top-1/2 right-2 -translate-y-1/2 text-[10px] font-black text-white/30">%</span>
            </div>
            <Button size="icon-sm" variant="ghost" className="hover:text-bad" onClick={() => onChange((r) => { r.items.splice(i, 1) })}><Trash2 /></Button>
          </div>
        ))}
      </div>
      <div className="flex items-center justify-between">
        <Button size="sm" variant="secondary" onClick={() => onChange((r) => { r.items.push({ item: '', label: 'New reward', type: 'item', min: 1, max: 1, chance: 50, category: 'valuables' }) })}><Plus /> Add reward</Button>
        {value.items.some((e) => e.type === 'money') && <span className="text-[11px] text-white/35">Money pays straight into the account, e.g. {money(4000)} - {money(12000)}</span>}
      </div>
    </div>
  )
}
