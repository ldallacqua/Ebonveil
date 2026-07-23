import { useState } from "react"
import { ChevronDown } from "lucide-react"
import type { ModSection } from "@/types"
import { ModCard, ManagedChip } from "@/components/ModCard"
import { cn } from "@/lib/utils"

interface SectionGroupProps {
  section: ModSection
  compact?: boolean
  defaultCollapsed?: boolean
}

export function SectionGroup({
  section,
  compact = false,
  defaultCollapsed = false,
}: SectionGroupProps) {
  const [collapsed, setCollapsed] = useState(defaultCollapsed)

  return (
    <section className="scroll-mt-24" id={section.id}>
      <button
        onClick={() => setCollapsed((c) => !c)}
        className="group flex w-full items-center gap-3 border-b border-border/70 pb-3 text-left"
      >
        <ChevronDown
          className={cn(
            "size-5 shrink-0 text-muted-foreground transition-transform",
            collapsed && "-rotate-90"
          )}
        />
        <div className="min-w-0">
          <h2 className="font-display text-xl font-semibold tracking-tight">
            {section.name}
            <span className="ml-2 text-sm font-normal text-muted-foreground tabular-nums">
              {section.mods.length}
            </span>
          </h2>
          {section.blurb && (
            <p className="truncate text-sm text-muted-foreground">{section.blurb}</p>
          )}
        </div>
        <span className="ml-auto h-px flex-1" />
      </button>

      {!collapsed && (
        <div
          className={cn(
            "mt-5 animate-in fade-in slide-in-from-top-1 duration-300",
            compact
              ? "grid grid-cols-2 gap-2 sm:grid-cols-3 lg:grid-cols-4"
              : "grid gap-3 sm:grid-cols-2 lg:grid-cols-3"
          )}
        >
          {section.mods.map((mod) =>
            compact ? (
              <ManagedChip key={mod.slug + mod.order} mod={mod} />
            ) : (
              <ModCard key={mod.slug + mod.order} mod={mod} />
            )
          )}
        </div>
      )}
    </section>
  )
}
