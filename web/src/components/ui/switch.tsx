import * as React from 'react'
import * as SwitchPrimitive from '@radix-ui/react-switch'
import { cn } from '@/lib/utils'

function Switch({ className, ...props }: React.ComponentProps<typeof SwitchPrimitive.Root>) {
  return (
    <SwitchPrimitive.Root
      data-slot="switch"
      className={cn(
        'peer relative inline-flex h-5 w-9 shrink-0 items-center rounded-full transition-colors outline-none data-[state=checked]:bg-white data-[state=unchecked]:bg-white/[0.1] disabled:cursor-not-allowed disabled:opacity-40',
        className,
      )}
      {...props}
    >
      <SwitchPrimitive.Thumb
        data-slot="switch-thumb"
        className="pointer-events-none block size-4 rounded-full transition-all data-[state=checked]:translate-x-[18px] data-[state=checked]:bg-ink data-[state=unchecked]:translate-x-0.5 data-[state=unchecked]:bg-white/60"
      />
    </SwitchPrimitive.Root>
  )
}

export { Switch }
