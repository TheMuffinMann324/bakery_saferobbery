export type Kind = 'safe' | 'lockbox'
export type SafeState = 'locked' | 'charged' | 'open'
export type Category = 'cash' | 'jewelry' | 'watches' | 'diamonds' | 'gold' | 'coke' | 'weed' | 'meth' | 'drugs' | 'valuables' | 'documents' | 'other'

export interface NotePos { x: number; y: number; z: number; ux: number; uy: number; uz: number; fx: number; fy: number; fz: number }

export interface Safe {
  id: string
  label: string
  kind: Kind
  enabled: boolean
  x: number; y: number; z: number; h: number
  note?: NotePos | null
  code?: string
  rewards?: Rewards
  // live
  state?: SafeState
  method?: 'code' | 'explosive' | 'padlock' | 'restart'
  fuseEnd?: number
  lockoutUntil?: number
  cooldownUntil?: number
  busy?: boolean
  busyBy?: string
  lootLeft?: number
}

export interface LootItem {
  item: string
  label: string
  type: 'item' | 'money'
  account?: string
  min: number
  max: number
  chance: number
  category: Category
}

export interface Rewards { minItems: number; maxItems: number; items: LootItem[] }

export interface Settings {
  policeRequired: number
  policeJobs: string[]
  alertKeypadFail: boolean
  alertExplosion: boolean
  alertPadlock: number
  safeCooldown: number
  lockboxCooldown: number
  playerSafeCooldown: number
  playerLockboxCooldown: number
  keypadAttempts: number
  lockoutTime: number
  randomizeCode: boolean
  explosiveItem: string
  fuseTime: number
  explosionDamage: boolean
  explosionLoss: number
  breakItem: string
  breakHits: number
  breakSkillCheck: boolean
  breakDifficulty: 'easy' | 'medium' | 'hard'
  lootTime: number
  interactDistance: number
}

export interface AdminData {
  settings: Settings
  safes: Safe[]
  serverTime: number
}

export interface Coords { x: number; y: number; z: number; h?: number }

export interface Result { ok: boolean; error?: string; [k: string]: unknown }

/** Lua sends an empty table as {} - turn anything that isn't a list into one. */
export function list<T>(v: unknown): T[] {
  return Array.isArray(v) ? (v as T[]) : []
}
