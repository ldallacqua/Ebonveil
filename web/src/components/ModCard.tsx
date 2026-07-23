import { ExternalLink, ShieldCheck, Circle } from "lucide-react"
import type { ModEntry } from "@/types"
import { Badge } from "@/components/ui/badge"
import { Button } from "@/components/ui/button"
import { cn } from "@/lib/utils"

function sourceLabel(source: string | null) {
  switch (source) {
    case "nexus":
      return "Nexus"
    case "bethesda":
      return "Bethesda"
    case "github":
      return "GitHub"
    case "manual":
      return "Manual"
    default:
      return null
  }
}

export function ModCard({ mod }: { mod: ModEntry }) {
  return (
    <article
      className={cn(
        "group relative flex flex-col gap-3 rounded-xl border border-border bg-card p-4 transition-all duration-300",
        "hover:-translate-y-0.5 hover:border-primary/40 hover:ring-glow"
      )}
    >
      <div className="flex items-start justify-between gap-3">
        <div className="flex min-w-0 items-start gap-3">
          <span className="mt-0.5 grid size-8 shrink-0 place-items-center rounded-lg border border-border bg-secondary/60 font-display text-xs font-semibold tabular-nums text-muted-foreground">
            {mod.order}
          </span>
          <div className="min-w-0">
            <h3 className="truncate font-semibold leading-tight" title={mod.name}>
              {mod.name}
            </h3>
            <p className="mt-0.5 text-xs text-muted-foreground">{mod.category}</p>
          </div>
        </div>
        {mod.enabled ? (
          <span title="Enabled" className="mt-1 size-2 shrink-0 rounded-full bg-[var(--success)] shadow-[0_0_10px_2px_oklch(0.72_0.16_155_/_0.5)]" />
        ) : (
          <Circle className="mt-1 size-2 shrink-0 text-muted-foreground/40" />
        )}
      </div>

      {mod.notes && (
        <p className="line-clamp-2 text-sm text-muted-foreground/90">{mod.notes}</p>
      )}

      <div className="mt-auto flex flex-wrap items-center gap-1.5 pt-1">
        {mod.version && <Badge variant="muted">v{mod.version}</Badge>}
        {sourceLabel(mod.source) && (
          <Badge variant="outline">{sourceLabel(mod.source)}</Badge>
        )}
        {mod.required && (
          <Badge variant="success">
            <ShieldCheck /> Required
          </Badge>
        )}
        {mod.nexus && (
          <Button
            asChild
            size="sm"
            variant="ghost"
            className="ml-auto h-7 px-2 text-primary hover:text-primary"
          >
            <a href={mod.nexus.url} target="_blank" rel="noreferrer">
              Nexus <ExternalLink />
            </a>
          </Button>
        )}
      </div>
    </article>
  )
}

export function ManagedChip({ mod }: { mod: ModEntry }) {
  const label = mod.name.replace(/^Creation Club:\s*/, "").replace(/^DLC:\s*/, "")
  return (
    <div className="flex items-center gap-2 rounded-lg border border-border bg-card/60 px-3 py-2 text-sm transition-colors hover:border-accent/40">
      <span className="size-1.5 shrink-0 rounded-full bg-accent/70" />
      <span className="truncate text-muted-foreground" title={mod.name}>
        {label}
      </span>
    </div>
  )
}
