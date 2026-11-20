import { useEffect, useRef, useState, type ReactNode } from 'react'
import { Activity, Settings, Vault, X } from 'lucide-react'
import { cn } from '@/lib/utils'
import { isNui, nui } from '@/lib/nui'
import { Button } from '@/components/ui/button'
import { Logo, Toaster } from '@/components/common'
import { AdminProvider } from './store'
import Live from './Live'
import Safes from './Safes'
import SettingsSection from './SettingsSection'

const SECTIONS = [
  { id: 'live', label: 'Live', icon: Activity },
  { id: 'safes', label: 'Safes', icon: Vault },
  { id: 'settings', label: 'Settings', icon: Settings },
] as const
type SectionId = (typeof SECTIONS)[number]['id']

export default function Panel({ hidden }: { hidden: boolean }) {
  const [section, setSection] = useState<SectionId>('safes')
  const [drag, setDrag] = useState({ x: 0, y: 0 })
  const [dragStart, setDragStart] = useState<{ x: number; y: number } | null>(null)
  const workspace = useRef<HTMLElement>(null)

  useEffect(() => {
    if (!dragStart) return
    const move = (e: MouseEvent) => setDrag({ x: e.clientX - dragStart.x, y: e.clientY - dragStart.y })
    const up = () => setDragStart(null)
    window.addEventListener('mousemove', move)
    window.addEventListener('mouseup', up)
    return () => { window.removeEventListener('mousemove', move); window.removeEventListener('mouseup', up) }
  }, [dragStart])

  useEffect(() => {
    const onKey = (e: KeyboardEvent) => {
      if (e.key !== 'Escape' || hidden) return
      if (document.querySelector('[role="dialog"]')) return
      if (isNui) nui('admin:close')
    }
    window.addEventListener('keydown', onKey)
    return () => window.removeEventListener('keydown', onKey)
  }, [hidden])

  const current = SECTIONS.find((s) => s.id === section)!

  return (
    <div className={cn('fixed inset-0 flex items-center justify-center p-3 sm:p-6', hidden && 'invisible')}>
      <div
        className="fade-up grain relative grid h-full max-h-[780px] w-full max-w-[1240px] grid-cols-[48px_minmax(0,1fr)] grid-rows-[64px_minmax(0,1fr)] overflow-hidden rounded-xl border border-white/[0.09] bg-panel shadow-[0_24px_64px_rgba(0,0,0,0.85)] motion-reduce:animate-none sm:grid-cols-[64px_minmax(0,1fr)] sm:grid-rows-[68px_minmax(0,1fr)]"
        style={{ translate: `${drag.x}px ${drag.y}px` }}
      >
        <div className="col-start-1 row-start-1 grid place-items-center">
          <Logo className="size-8 sm:size-9" />
        </div>
        <header
          onMouseDown={(e) => {
            if (e.button === 0) setDragStart({ x: e.clientX - drag.x, y: e.clientY - drag.y })
          }}
          className={cn('col-start-2 row-start-1 flex min-w-0 items-center justify-between gap-4 pr-3 pl-3 sm:pr-4 sm:pl-4', dragStart ? 'cursor-grabbing' : 'cursor-grab')}
        >
          <div className="min-w-0">
            <p className="text-[10px] leading-tight font-extrabold tracking-[0.17em] text-white/50 uppercase">Safe robbery</p>
            <h1 id="admin-title" className="mt-1 text-[20px] leading-none font-black tracking-tight text-white uppercase">{current.label}</h1>
          </div>
          <Button
            variant="ghost"
            size="icon"
            className="size-9 shrink-0 text-white/55 hover:text-white"
            aria-label="Close admin panel"
            onMouseDown={(e) => e.stopPropagation()}
            onClick={() => {
              if (isNui) nui('admin:close')
            }}
          ><X aria-hidden="true" /></Button>
        </header>
        <nav aria-label="Admin sections" className="relative z-10 col-start-1 row-start-2 flex min-h-0 flex-col items-center gap-1.5 pt-1.5">
          {SECTIONS.map((s) => (
            <NavButton key={s.id} active={section === s.id} label={s.label} onClick={() => {
              if (section === s.id) return
              workspace.current?.scrollTo(0, 0)
              setSection(s.id)
            }}><s.icon aria-hidden="true" /></NavButton>
          ))}
        </nav>
        <main
          ref={workspace}
          aria-labelledby="admin-title"
          className="col-start-2 row-start-2 mr-2.5 mb-2.5 min-h-0 min-w-0 overflow-auto rounded-lg border border-white/[0.06] bg-panel-2 p-3 shadow-[inset_0_1px_2px_rgba(0,0,0,0.22)] [scrollbar-gutter:stable] sm:mr-3 sm:mb-3 sm:p-4"
        >
          <AdminProvider>
            <div key={section} className="fade-up min-w-0 motion-reduce:animate-none">
              {section === 'live' && <Live />}
              {section === 'safes' && <Safes />}
              {section === 'settings' && <SettingsSection />}
            </div>
          </AdminProvider>
        </main>
        <Toaster />
      </div>
    </div>
  )
}

function NavButton({ active, label, onClick, children }: { active: boolean; label: string; onClick: () => void; children: ReactNode }) {
  return (
    <button
      type="button"
      aria-label={label}
      aria-current={active ? 'page' : undefined}
      onClick={onClick}
      className={cn(
        'group relative flex size-8 shrink-0 items-center justify-center rounded-md transition-colors duration-150 focus-visible:ring-2 focus-visible:ring-white/65 focus-visible:ring-offset-2 focus-visible:ring-offset-panel focus-visible:outline-none sm:size-9 [&_svg]:size-[17px]',
        active ? 'bg-white text-ink' : 'text-white/45 hover:bg-white/[0.07] hover:text-white',
      )}
    >
      {children}
      <span aria-hidden="true" className="pointer-events-none absolute left-full ml-3 rounded-[5px] bg-white px-2 py-1 text-[10.5px] font-extrabold tracking-[0.07em] whitespace-nowrap text-ink uppercase opacity-0 shadow-lg transition-opacity group-focus-visible:opacity-100 group-hover:opacity-100">
        {label}
      </span>
    </button>
  )
}
