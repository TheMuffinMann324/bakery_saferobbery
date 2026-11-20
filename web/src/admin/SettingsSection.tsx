import { useState } from 'react'
import { Box, SlidersHorizontal, Vault } from 'lucide-react'
import { cn } from '@/lib/utils'
import { Switch } from '@/components/ui/switch'
import type { Settings } from '@/lib/types'
import { useAdmin, useDraft } from './store'
import { DefaultsButton, Group, Row, SaveBar, SelectField, Stepper, TagsField, TextField } from './fields'

type Tab = 'general' | 'safe' | 'lockbox'

const TABS: { id: Tab; label: string; text: string; icon: typeof Vault }[] = [
  { id: 'general', label: 'General', text: 'Police and looting', icon: SlidersHorizontal },
  { id: 'safe', label: 'Big safes', text: 'Keypad, charges, cooldowns', icon: Vault },
  { id: 'lockbox', label: 'Lockboxes', text: 'Padlock, cooldowns', icon: Box },
]

export default function SettingsSection() {
  const { data, save, reset } = useAdmin()
  const { draft, dirty, update, discard } = useDraft(data.settings)
  const [tab, setTab] = useState<Tab>('general')
  const set = <K extends keyof Settings>(k: K, v: Settings[K]) => update((d) => { d[k] = v })
  const num = (k: keyof Settings, unit: string, step: number, min: number, max: number) => (
    <Stepper value={draft[k] as number} onChange={(v) => set(k, v as never)} step={step} min={min} max={max} unit={unit} />
  )
  // stored in seconds, shown in minutes
  const mins = (k: keyof Settings, max: number) => (
    <Stepper value={Math.round(((draft[k] as number) / 60) * 10) / 10} onChange={(v) => set(k, Math.round(v * 60) as never)} step={5} min={0} max={max} unit="min" />
  )
  const toggle = (k: keyof Settings) => <Switch checked={draft[k] as boolean} onCheckedChange={(v) => set(k, v as never)} />

  return (
    <div>
      <div className="mb-5 flex items-stretch gap-2">
        {TABS.map((t) => (
          <button
            key={t.id}
            onClick={() => setTab(t.id)}
            className={cn(
              'flex flex-1 items-center gap-3 rounded-lg border px-4 py-3 text-left transition',
              tab === t.id ? 'border-white bg-white text-ink' : 'border-white/[0.06] bg-white/[0.025] text-white hover:bg-white/[0.05]',
            )}
          >
            <t.icon className={cn('size-5', tab === t.id ? 'text-ink' : 'text-white/40')} />
            <span>
              <span className="block text-[13px] font-black tracking-tight uppercase">{t.label}</span>
              <span className={cn('block text-[11px]', tab === t.id ? 'text-ink/60' : 'text-white/40')}>{t.text}</span>
            </span>
          </button>
        ))}
        <div className="flex items-center"><DefaultsButton what="settings" onReset={() => reset('settings')} /></div>
      </div>

      <div key={tab} className="fade-up">
        {tab === 'general' && (
          <>
            <Group title="Police" text="Robberies only start when enough police are on duty.">
              <Row title="Police needed" text="On duty before anything can be robbed. 0 = no police needed">{num('policeRequired', 'cops', 1, 0, 50)}</Row>
              <Row title="Police jobs" text="Job names that count as police, comma separated" wide><TagsField value={draft.policeJobs} onChange={(v) => set('policeJobs', v)} /></Row>
            </Group>
            <Group title="Looting" text="Taking things out of an open safe or lockbox.">
              <Row title="Time to grab one item">{num('lootTime', 'ms', 100, 0, 15000)}</Row>
              <Row title="Reach" text="How close a player has to stand">{num('interactDistance', 'm', 0.1, 0.8, 5)}</Row>
            </Group>
          </>
        )}

        {tab === 'safe' && (
          <>
            <Group title="Cooldowns" text="Big safes have their own timers, separate from lockboxes.">
              <Row title="Safe stays empty for" text="After it's opened. Then the door shuts and it relocks">{mins('safeCooldown', 10080)}</Row>
              <Row title="Player waits before the next safe" text="Doesn't stop them robbing a lockbox">{mins('playerSafeCooldown', 1440)}</Row>
            </Group>
            <Group title="Keypad" text="The quiet way in: find the sticky note and type the code.">
              <Row title="Wrong codes allowed" text="Then the keypad locks out">{num('keypadAttempts', 'tries', 1, 1, 20)}</Row>
              <Row title="Locked out for">{mins('lockoutTime', 1440)}</Row>
              <Row title="New code every time it resets" text="The sticky note updates with it">{toggle('randomizeCode')}</Row>
              <Row title="Tell police on a lockout">{toggle('alertKeypadFail')}</Row>
            </Group>
            <Group title="Breaching charge" text="The loud way in: blow the door off.">
              <Row title="Charge item" text="Used up when planted" wide><TextField mono value={draft.explosiveItem} onChange={(v) => set('explosiveItem', v)} /></Row>
              <Row title="Fuse">{num('fuseTime', 'sec', 1, 3, 120)}</Row>
              <Row title="Contents destroyed by the blast">{num('explosionLoss', '%', 5, 0, 100)}</Row>
              <Row title="Blast hurts people standing close">{toggle('explosionDamage')}</Row>
              <Row title="Tell police when it goes off">{toggle('alertExplosion')}</Row>
            </Group>
          </>
        )}

        {tab === 'lockbox' && (
          <>
            <Group title="Cooldowns" text="Lockboxes have their own timers, separate from big safes.">
              <Row title="Lockbox stays empty for" text="After it's opened. Then the padlock goes back on">{mins('lockboxCooldown', 10080)}</Row>
              <Row title="Player waits before the next lockbox" text="Doesn't stop them robbing a safe">{mins('playerLockboxCooldown', 1440)}</Row>
            </Group>
            <Group title="Padlock" text="Players break the padlock off to get in.">
              <Row title="Tool needed" text="Item or weapon name. Leave empty for bare hands" wide><TextField mono value={draft.breakItem} placeholder="none" onChange={(v) => set('breakItem', v)} /></Row>
              <Row title="Hits to break it">{num('breakHits', 'hits', 1, 1, 15)}</Row>
              <Row title="Skill check on every hit" text="Off = a short progress bar instead">{toggle('breakSkillCheck')}</Row>
              {draft.breakSkillCheck && (
                <Row title="Skill check difficulty">
                  <SelectField value={draft.breakDifficulty} onChange={(v) => set('breakDifficulty', v as Settings['breakDifficulty'])} options={[{ value: 'easy', label: 'Easy' }, { value: 'medium', label: 'Medium' }, { value: 'hard', label: 'Hard' }]} />
                </Row>
              )}
              <Row title="Chance police hear it">{num('alertPadlock', '%', 5, 0, 100)}</Row>
            </Group>
          </>
        )}
      </div>

      <SaveBar dirty={dirty} onSave={() => save('settings', draft)} onDiscard={discard} />
    </div>
  )
}
