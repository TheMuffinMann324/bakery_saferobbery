import { useEffect, useRef } from 'react'
import { mockCall, mockNui } from './mock'

declare global {
  interface Window {
    GetParentResourceName?: () => string
  }
}

export const isNui = typeof window !== 'undefined' && typeof window.GetParentResourceName === 'function'
const resource = isNui ? window.GetParentResourceName!() : 'bakery_saferobbery'

// Direct client NUI callback. timeoutMs = 0 waits forever (placement mode).
export async function nui<T = unknown>(event: string, data?: unknown, timeoutMs = 30000): Promise<T> {
  if (!isNui) return mockNui(event, data) as T
  const controller = new AbortController()
  const timer = timeoutMs > 0 ? window.setTimeout(() => controller.abort(), timeoutMs) : 0
  try {
    const res = await fetch(`https://${resource}/${event}`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json; charset=UTF-8' },
      body: JSON.stringify(data ?? {}),
      signal: controller.signal,
    })
    return (await res.json()) as T
  } catch {
    return { ok: false, error: 'No response.' } as T
  } finally {
    if (timer) window.clearTimeout(timer)
  }
}

// Admin server callback proxied through the client (client/nui.lua only lets admin:* through).
export function call<T = unknown>(name: string, args?: unknown): Promise<T> {
  if (!isNui) return Promise.resolve(mockCall(name, args) as T)
  return nui<T>('call', { name, args })
}

type Handler = (data: any) => void
const handlers = new Map<string, Set<Handler>>()

if (typeof window !== 'undefined') {
  window.addEventListener('message', (event) => {
    const { action, data } = event.data ?? {}
    if (!action) return
    handlers.get(action)?.forEach((h) => h(data))
  })
}

export function useNuiEvent<T = any>(action: string, handler: (data: T) => void) {
  const saved = useRef(handler)
  saved.current = handler
  useEffect(() => {
    const fn: Handler = (d) => saved.current(d)
    if (!handlers.has(action)) handlers.set(action, new Set())
    handlers.get(action)!.add(fn)
    return () => {
      handlers.get(action)?.delete(fn)
    }
  }, [action])
}

// ---------- sounds (keypad beeps) ----------

let ctx: AudioContext | null = null
function tone(freq: number, ms: number, delay = 0, type: OscillatorType = 'square', volume = 0.05) {
  try {
    ctx = ctx ?? new AudioContext()
    const t = ctx.currentTime + delay / 1000
    const o = ctx.createOscillator()
    const g = ctx.createGain()
    o.type = type
    o.frequency.value = freq
    g.gain.setValueAtTime(volume, t)
    g.gain.exponentialRampToValueAtTime(0.0001, t + ms / 1000)
    o.connect(g).connect(ctx.destination)
    o.start(t)
    o.stop(t + ms / 1000 + 0.02)
  } catch {
    /* no audio */
  }
}

export const sfx = {
  press: () => tone(1380, 70),
  clear: () => tone(700, 90),
  error: () => { tone(260, 180, 0, 'sawtooth', 0.04); tone(220, 260, 200, 'sawtooth', 0.04) },
  success: () => { tone(988, 110); tone(1319, 110, 120); tone(1760, 200, 240) },
  lock: () => { tone(200, 500, 0, 'sawtooth', 0.05) },
}
