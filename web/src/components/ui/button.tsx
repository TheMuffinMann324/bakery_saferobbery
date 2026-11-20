import * as React from 'react'
import { cva, type VariantProps } from 'class-variance-authority'
import { cn } from '@/lib/utils'

const buttonVariants = cva(
  "relative inline-flex shrink-0 items-center justify-center gap-1.5 rounded-md font-extrabold tracking-[0.06em] whitespace-nowrap uppercase transition-all outline-none select-none active:translate-y-px disabled:pointer-events-none disabled:opacity-35 [&_svg]:pointer-events-none [&_svg]:shrink-0 [&_svg:not([class*='size-'])]:size-4 focus-visible:ring-2 focus-visible:ring-ring",
  {
    variants: {
      variant: {
        default: 'bg-white text-ink hover:bg-white/85',
        destructive: 'bg-bad/12 text-bad hover:bg-bad/20',
        secondary: 'bg-white/[0.07] text-white/85 hover:bg-white/[0.12] hover:text-white',
        ghost: 'text-white/50 hover:bg-white/[0.07] hover:text-white',
      },
      size: {
        default: 'h-8 px-3 text-[11px]',
        sm: 'h-7 px-2.5 text-[10.5px] [&_svg:not([class*=size-])]:size-3.5',
        icon: 'size-8',
        'icon-sm': 'size-7 [&_svg:not([class*=size-])]:size-3.5',
      },
    },
    defaultVariants: { variant: 'default', size: 'default' },
  },
)

function Button({
  className, variant, size, ...props
}: React.ComponentProps<'button'> & VariantProps<typeof buttonVariants>) {
  return <button data-slot="button" className={cn(buttonVariants({ variant, size, className }))} {...props} />
}

export { Button }
