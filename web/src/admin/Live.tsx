import { useEffect, useState } from 'react'
import { Activity, Box, Lock, Navigation, RotateCcw, Unlock, Vault } from 'lucide-react'
import { call, nui } from '@/lib/nui'
import type { Safe } from '@/lib/types'
import { Button } from '@/components/ui/button'
import { Empty, StatTile } from '@/components/common'
import { status, useAdmin } from './store'
import { Cell, Confirm, ListCard, ListRow, NoOpen, Pill, Toolbar } from './fields'
import { KindBadge } from './Safes'

// What's happening right now: refreshed every couple of seconds while open.
export default function Live() {
  const { data, setSafes, resetSafe, now } = useAdmin()
  const [confirmAll, setConfirmAll] = useState(false)

  useEffect(() => {
    let alive = true
    const poll = async () => {
      const r = await call<{ safes: Safe[]; serverTime: number }>('admin:live')
      if (alive && r?.safes) setSafes(r.safes, r.serverTime)
    }
    poll()
    const t = window.setInterval(poll, 2500)
    return () => { alive = false; window.clearInterval(t) }
  }, [setSafes])

  const safes = data.safes
  const ready = safes.filter((s) => s.enabled && s.state === 'locked' && !(s.lockoutUntil && s.lockoutUntil > now)).length
  const open = safes.filter((s) => s.state === 'open').length
  const active = safes.filter((s) => s.state === 'charged' || s.busy || (s.lockoutUntil && s.lockoutUntil > now))
  const cols = '44px minmax(0,1.5fr) minmax(0,1.2fr) 90px 190px'
  const sorted = [...safes].sort((a, b) => rank(a, now) - rank(b, now))

  return (
    <div>
      <div className="mb-5 grid grid-cols-4 gap-3">
        <StatTile label="Big safes" value={safes.filter((s) => s.kind === 'safe').length} sub="placed in the city" icon={<Vault />} />
        <StatTile label="Lockboxes" value={safes.filter((s) => s.kind === 'lockbox').length} sub="placed in the city" icon={<Box />} />
        <StatTile label="Ready" value={ready} sub="locked and waiting" icon={<Lock />} />
        <StatTile label="Open" value={open} sub={active.length ? `${active.length} being worked on` : 'on cooldown'} icon={<Unlock />} />
      </div>
      <Toolbar text="Live state of everything placed. Close & lock ends a cooldown or lockout straight away.">
        <Button size="sm" variant="secondary" disabled={open === 0 && active.length === 0} onClick={() => setConfirmAll(true)}><RotateCcw /> Close & lock all</Button>
      </Toolbar>
      {safes.length === 0 ? (
        <Empty title="Nothing placed" icon={<Activity />}>Head to Safes to place the first one.</Empty>
      ) : (
        <ListCard cols={cols} head={['', 'Name', 'Status', 'Inside', '']} count={safes.length}>
          {sorted.map((s) => {
            const st = status(s, now)
            return (
              <ListRow key={s.id} cols={cols} muted={!s.enabled}>
                <KindBadge kind={s.kind} className="size-8 [&_svg]:size-4" />
                <Cell title={s.label} sub={s.method && s.state === 'open' ? `Opened with ${s.method === 'code' ? 'the code' : s.method === 'explosive' ? 'a charge' : s.method === 'padlock' ? 'a crowbar' : 'a restart'}` : s.kind === 'lockbox' ? 'Lockbox' : 'Big safe'} />
                <div className="min-w-0"><Pill tone={st.tone}>{st.text}</Pill></div>
                <span className="tnum text-[12px] text-white/60">{s.state === 'open' ? `${s.lootLeft ?? 0} left` : '-'}</span>
                <NoOpen className="flex justify-end gap-1.5">
                  <Button size="sm" variant="ghost" onClick={() => nui('admin:teleport', { ...s })}><Navigation /> Go</Button>
                  <Button size="sm" variant="secondary" disabled={s.state === 'locked' && !(s.lockoutUntil && s.lockoutUntil > now)} onClick={() => resetSafe(s.id)}><RotateCcw /> Reset</Button>
                </NoOpen>
              </ListRow>
            )
          })}
        </ListCard>
      )}
      <Confirm open={confirmAll} onOpenChange={setConfirmAll} title="Close and lock everything?" text="Every open safe shuts (whatever is left inside is gone), lockouts clear and padlocks go back on." confirm="Close all"
        onConfirm={async () => { await call('admin:resetAll'); const r = await call<{ safes: Safe[] }>('admin:live'); if (r?.safes) setSafes(r.safes) }} />
    </div>
  )
}

function rank(s: Safe, now: number) {
  if (s.state === 'charged') return 0
  if (s.busy) return 1
  if (s.lockoutUntil && s.lockoutUntil > now) return 2
  if (s.state === 'open') return 3
  return s.enabled ? 4 : 5
}
