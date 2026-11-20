import { createContext, useCallback, useContext, useEffect, useMemo, useState, type ReactNode } from 'react'
import { call } from '@/lib/nui'
import { list, type AdminData, type Safe } from '@/lib/types'
import { toast } from '@/components/common'

type Section = 'settings'

interface Ctx {
  data: AdminData
  reload: () => Promise<void>
  save: <K extends Section>(section: K, value: AdminData[K]) => Promise<boolean>
  reset: (section: Section) => Promise<boolean>
  saveSafe: (safe: Partial<Safe>) => Promise<Safe | null>
  deleteSafe: (id: string) => Promise<boolean>
  resetSafe: (id: string) => Promise<boolean>
  setSafes: (safes: Safe[], serverTime?: number) => void
  /** server unix time, ticking */
  now: number
}

const AdminCtx = createContext<Ctx | null>(null)

function normalise(d: AdminData): AdminData {
  return {
    ...d,
    safes: list<Safe>(d.safes).map((s) => (s.rewards ? { ...s, rewards: { ...s.rewards, items: list(s.rewards.items) } } : s)),
    settings: { ...d.settings, policeJobs: list<string>(d.settings?.policeJobs) },
  }
}

export function AdminProvider({ children }: { children: ReactNode }) {
  const [data, setData] = useState<AdminData | null>(null)
  const [offset, setOffset] = useState(0)
  const [tick, setTick] = useState(() => Date.now())

  const reload = useCallback(async () => {
    const d = await call<AdminData>('admin:getData')
    if (d && d.settings) {
      setData(normalise(d))
      setOffset(d.serverTime - Date.now() / 1000)
    } else {
      toast((d as any)?.error || 'Could not load the admin data.', 'error')
    }
  }, [])
  useEffect(() => { reload() }, [reload])
  useEffect(() => {
    const t = window.setInterval(() => setTick(Date.now()), 1000)
    return () => window.clearInterval(t)
  }, [])

  const save = useCallback(async <K extends Section>(section: K, value: AdminData[K]) => {
    const res = await call<{ ok: boolean; value?: AdminData[K]; error?: string }>('admin:save', { section, value })
    if (!res?.ok) { toast(res?.error || 'Save failed.', 'error'); return false }
    setData((d) => (d ? normalise({ ...d, [section]: res.value ?? value }) : d))
    toast('Saved.', 'success')
    return true
  }, [])

  const reset = useCallback(async (section: Section) => {
    const res = await call<{ ok: boolean; value?: unknown; error?: string }>('admin:reset', { section })
    if (!res?.ok) { toast(res?.error || 'Reset failed.', 'error'); return false }
    setData((d) => (d ? normalise({ ...d, [section]: res.value } as AdminData) : d))
    toast('Restored defaults from config.lua.', 'success')
    return true
  }, [])

  const saveSafe = useCallback(async (safe: Partial<Safe>) => {
    const res = await call<{ ok: boolean; value?: Safe; error?: string }>('admin:saveSafe', safe)
    if (!res?.ok || !res.value) { toast(res?.error || 'Save failed.', 'error'); return null }
    const v = res.value
    setData((d) => {
      if (!d) return d
      const i = d.safes.findIndex((s) => s.id === v.id)
      const safes = [...d.safes]
      if (i >= 0) safes[i] = v
      else safes.push(v)
      return { ...d, safes }
    })
    return v
  }, [])

  const deleteSafe = useCallback(async (id: string) => {
    const res = await call<{ ok: boolean }>('admin:deleteSafe', { id })
    if (!res?.ok) { toast('Delete failed.', 'error'); return false }
    setData((d) => (d ? { ...d, safes: d.safes.filter((s) => s.id !== id) } : d))
    toast('Removed.', 'success')
    return true
  }, [])

  const resetSafe = useCallback(async (id: string) => {
    const res = await call<{ ok: boolean; value?: Safe; error?: string }>('admin:resetSafe', { id })
    if (!res?.ok) { toast(res?.error || 'Reset failed.', 'error'); return false }
    if (res.value) setData((d) => (d ? { ...d, safes: d.safes.map((s) => (s.id === id ? res.value! : s)) } : d))
    toast('Closed and locked.', 'success')
    return true
  }, [])

  const setSafes = useCallback((safes: Safe[], serverTime?: number) => {
    setData((d) => (d ? { ...d, safes: list<Safe>(safes) } : d))
    if (serverTime) setOffset(serverTime - Date.now() / 1000)
  }, [])

  const value = useMemo<Ctx | null>(() => data && ({
    data, reload, save, reset, saveSafe, deleteSafe, resetSafe, setSafes,
    now: Math.floor(tick / 1000 + offset),
  }), [data, reload, save, reset, saveSafe, deleteSafe, resetSafe, setSafes, tick, offset])

  if (!value) return <div className="flex h-full items-center justify-center text-[11px] font-extrabold tracking-[0.14em] text-white/40 uppercase">Loading...</div>
  return <AdminCtx.Provider value={value}>{children}</AdminCtx.Provider>
}

export function useAdmin() {
  const c = useContext(AdminCtx)
  if (!c) throw new Error('useAdmin outside provider')
  return c
}

/** Local draft of a value with dirty tracking. */
export function useDraft<T>(source: T) {
  const [draft, setDraft] = useState<T>(() => structuredClone(source))
  const [dirty, setDirty] = useState(false)
  useEffect(() => { setDraft(structuredClone(source)); setDirty(false) }, [source])
  const update = (fn: (d: T) => T | void) => {
    setDraft((d) => {
      const copy = structuredClone(d)
      const res = fn(copy)
      return (res ?? copy) as T
    })
    setDirty(true)
  }
  return { draft, dirty, update, setDirty, discard: () => { setDraft(structuredClone(source)); setDirty(false) } }
}

/** Live status of a safe, for chips and the live view. */
export function status(s: Safe, now: number): { text: string; tone: 'good' | 'warn' | 'bad' | 'mute' } {
  if (!s.enabled) return { text: 'Disabled', tone: 'mute' }
  if (s.state === 'charged') return { text: `Charge armed ${Math.max(0, (s.fuseEnd ?? now) - now)}s`, tone: 'bad' }
  if (s.state === 'open') {
    const left = Math.max(0, (s.cooldownUntil ?? now) - now)
    const m = Math.floor(left / 60), sec = left % 60
    return { text: `Open · resets in ${m}:${String(sec).padStart(2, '0')}`, tone: 'warn' }
  }
  if (s.lockoutUntil && s.lockoutUntil > now) return { text: `Keypad locked ${s.lockoutUntil - now}s`, tone: 'bad' }
  if (s.busy) return { text: s.busyBy ? `In use · ${s.busyBy}` : 'In use', tone: 'warn' }
  return { text: 'Ready', tone: 'good' }
}
