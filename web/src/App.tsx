import { useState } from 'react'
import '@fontsource/share-tech-mono/400.css'
import { isNui, useNuiEvent } from '@/lib/nui'
import { cn } from '@/lib/utils'
import Panel from '@/admin/Panel'
import Placement, { type PlaceState } from '@/overlays/Placement'
import Keypad, { mockKeypad, type KeypadState } from '@/overlays/Keypad'

export default function App() {
  const [admin, setAdmin] = useState({ open: false, hidden: false })
  const [place, setPlace] = useState<PlaceState>({ active: false })
  const [keypad, setKeypad] = useState<KeypadState>({ open: false })

  useNuiEvent<{ open: boolean; hidden?: boolean }>('admin', (d) => setAdmin({ open: !!d?.open, hidden: !!d?.hidden }))
  useNuiEvent<PlaceState>('place', (d) => setPlace(d ?? { active: false }))
  useNuiEvent<KeypadState>('keypad', (d) => setKeypad(d ?? { open: false }))

  return (
    <div className={isNui ? '' : 'min-h-full bg-[radial-gradient(ellipse_at_30%_20%,#3a3d44,#0b0c0f_70%)]'}>
      {place.active && <Placement state={place} />}
      {keypad.open && <Keypad key={keypad.id ?? 'k'} state={keypad} />}
      {admin.open && <Panel hidden={admin.hidden} />}
      {!isNui && <DevBar set={{ setAdmin, setPlace, setKeypad }} />}
    </div>
  )
}

// Browser only: switch between screens while working on the UI (npm run dev).
function DevBar({ set }: { set: Record<string, (v: any) => void> }) {
  const [cur, setCur] = useState('admin')
  const show = (name: string) => {
    setCur(name)
    set.setAdmin({ open: name === 'admin', hidden: false })
    set.setPlace(name === 'place' ? { active: true, mode: 'safe', stage: 'aim', label: 'New safe', hasAim: true, heading: 135, nudge: 0, snap: true, snapped: true, speed: 1, level: 'warn', issues: [{ text: 'The door can\'t swing all the way open', level: 'warn' }] }
      : name === 'test' ? { active: true, mode: 'safe', stage: 'test', label: 'New safe', heading: 135, speed: 1 } : { active: false })
    set.setKeypad(name === 'keypad' ? mockKeypad() : { open: false })
  }
  return (
    <div className="fixed top-2 left-2 z-[100] flex gap-1 rounded-md bg-black/70 p-1">
      {['admin', 'place', 'test', 'keypad'].map((n) => (
        <button key={n} onClick={() => show(n)} className={cn('rounded px-2 py-1 text-[10px] font-bold uppercase', cur === n ? 'bg-white text-black' : 'text-white/60')}>{n}</button>
      ))}
    </div>
  )
}
