import type { LucideIcon } from "lucide-react"
import { Boxes, Sparkles, Puzzle, Layers, Link2 } from "lucide-react"
import type { ModListStats } from "@/types"
import { cn } from "@/lib/utils"

interface StatsBarProps {
  stats: ModListStats
}

function Stat({
  icon: Icon,
  label,
  value,
  accent,
}: {
  icon: LucideIcon
  label: string
  value: number | string
  accent?: string
}) {
  return (
    <div className="group relative flex items-center gap-3 rounded-xl border border-border glass px-4 py-3.5 transition-colors hover:border-primary/40">
      <span
        className={cn(
          "grid size-9 place-items-center rounded-lg bg-primary/12 text-primary transition-colors",
          accent
        )}
      >
        <Icon className="size-5" />
      </span>
      <div className="leading-tight">
        <div className="font-display text-2xl font-semibold tabular-nums">
          {value}
        </div>
        <div className="text-xs text-muted-foreground">{label}</div>
      </div>
    </div>
  )
}

export function StatsBar({ stats }: StatsBarProps) {
  const curated = stats.total - stats.managed
  return (
    <div className="mx-auto grid max-w-6xl grid-cols-2 gap-3 px-6 sm:grid-cols-3 lg:grid-cols-5">
      <Stat icon={Sparkles} label="Curated mods" value={curated} accent="bg-accent/15 text-accent" />
      <Stat icon={Boxes} label="In load order" value={stats.total} />
      <Stat icon={Link2} label="Nexus-linked" value={stats.nexusLinked} />
      <Stat icon={Puzzle} label="Active plugins" value={stats.plugins} />
      <Stat icon={Layers} label="Categories" value={stats.sections} />
    </div>
  )
}
