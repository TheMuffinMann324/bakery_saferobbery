// Browser-only stand-ins for the game, so the UI can be worked on with `npm run dev`.
import type { AdminData, Rewards, Safe, Settings } from './types'

const now = () => Math.floor(Date.now() / 1000)

const settings: Settings = {
  policeRequired: 2, policeJobs: ['police', 'sheriff'], alertKeypadFail: true, alertExplosion: true, alertPadlock: 35,
  safeCooldown: 3600, lockboxCooldown: 1800, playerSafeCooldown: 600, playerLockboxCooldown: 180,
  keypadAttempts: 3, lockoutTime: 300, randomizeCode: true,
  explosiveItem: 'safe_charge', fuseTime: 10, explosionDamage: true, explosionLoss: 25,
  breakItem: 'weapon_crowbar', breakHits: 3, breakSkillCheck: true, breakDifficulty: 'medium',
  lootTime: 1200, interactDistance: 1.6,
}

const safeRewards: Rewards = {
  minItems: 3, maxItems: 6, items: [
    { item: 'money', label: 'Cash', type: 'money', account: 'cash', min: 4000, max: 12000, chance: 100, category: 'cash' },
    { item: 'rolex', label: 'Rolex', type: 'item', min: 1, max: 3, chance: 55, category: 'jewelry' },
    { item: 'goldbar', label: 'Gold bar', type: 'item', min: 1, max: 2, chance: 30, category: 'gold' },
    { item: 'coke_brick', label: 'Brick of coke', type: 'item', min: 1, max: 2, chance: 20, category: 'drugs' },
  ],
}
const boxRewards: Rewards = {
  minItems: 1, maxItems: 3, items: [
    { item: 'money', label: 'Cash', type: 'money', account: 'cash', min: 500, max: 2500, chance: 85, category: 'cash' },
    { item: 'weed_baggy', label: 'Bag of weed', type: 'item', min: 2, max: 6, chance: 40, category: 'drugs' },
  ],
}

const safes: Safe[] = [
  { id: 'safe_a1', label: 'Vinewood Pawn back office', kind: 'safe', enabled: true, x: 182.4, y: -1321.9, z: 29.3, h: 140, code: '4821', rewards: structuredClone(safeRewards), note: { x: 185, y: -1320, z: 30.2, ux: 0, uy: -1, uz: 0, fx: 0, fy: 0, fz: 1 }, state: 'locked' },
  { id: 'safe_b2', label: 'Grove Street trap house', kind: 'safe', enabled: true, x: -12.1, y: -1441.3, z: 31.1, h: 0, code: '0047', rewards: structuredClone(safeRewards), state: 'open', method: 'explosive', cooldownUntil: now() + 2400, lootLeft: 2 },
  { id: 'box_c3', label: 'Sandy Shores trailer', kind: 'lockbox', enabled: true, x: 1393.2, y: 3605.9, z: 34.9, h: 200, rewards: structuredClone(boxRewards), state: 'locked' },
  { id: 'safe_d4', label: 'Mirror Park garage', kind: 'safe', enabled: false, x: 1150.3, y: -455.7, z: 66.9, h: 90, code: '9910', rewards: structuredClone(safeRewards), state: 'locked', lockoutUntil: now() + 120 },
]

const data: AdminData = { settings, safes, serverTime: now() }

export function mockCall(name: string, args?: any): unknown {
  switch (name) {
    case 'admin:getData': return { ...structuredClone(data), serverTime: now() }
    case 'admin:live': return { safes: structuredClone(data.safes), serverTime: now() }
    case 'admin:save': (data as any)[args.section] = args.value; return { ok: true, value: args.value }
    case 'admin:reset': return { ok: true, value: (data as any)[args.section] }
    case 'admin:saveSafe': {
      const i = data.safes.findIndex((s) => s.id === args.id)
      const s = { ...args, id: args.id || `safe_${Math.random().toString(36).slice(2, 8)}`, state: 'locked' }
      if (i >= 0) data.safes[i] = { ...data.safes[i], ...s }
      else data.safes.push(s)
      return { ok: true, value: s }
    }
    case 'admin:deleteSafe': data.safes = data.safes.filter((s) => s.id !== args.id); return { ok: true }
    case 'admin:resetSafe': return { ok: true }
    case 'admin:resetAll': return { ok: true }
    case 'admin:randomCode': return { ok: true, code: String(Math.floor(Math.random() * 10000)).padStart(4, '0') }
  }
  return { ok: true }
}

export function mockNui(event: string, _data?: unknown): unknown {
  switch (event) {
    case 'admin:place': return new Promise((r) => setTimeout(() => r({ x: 100.12, y: -200.5, z: 30.2, h: 90, note: { x: 101, y: -201, z: 31, ux: 0, uy: -1, uz: 0, fx: 0, fy: 0, fz: 1 } }), 600))
    case 'admin:area': return { label: 'Strawberry Ave' }
    case 'keypad:submit': return { ok: (_data as any)?.code === '1234', attemptsLeft: 2 }
  }
  return { ok: true }
}
