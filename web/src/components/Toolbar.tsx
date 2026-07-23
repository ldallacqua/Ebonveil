import { Search, X, Sparkles } from "lucide-react"
import { Input } from "@/components/ui/input"
import { cn } from "@/lib/utils"

export interface CategoryChip {
  id: string
  name: string
  count: number
}

interface ToolbarProps {
  query: string
  onQuery: (v: string) => void
  categories: CategoryChip[]
  active: string
  onActive: (id: string) => void
  showManaged: boolean
  onToggleManaged: () => void
  managedCount: number
}

export function Toolbar({
  query,
  onQuery,
  categories,
  active,
  onActive,
  showManaged,
  onToggleManaged,
  managedCount,
}: ToolbarProps) {
  return (
    <div className="sticky top-3 z-20 mx-auto max-w-6xl px-6">
      <div className="glass rounded-2xl border border-border p-3 shadow-2xl shadow-black/30">
        <div className="flex flex-col gap-3">
          <div className="relative">
            <Search className="pointer-events-none absolute left-3 top-1/2 size-4 -translate-y-1/2 text-muted-foreground" />
            <Input
              value={query}
              onChange={(e) => onQuery(e.target.value)}
              placeholder="Search mods, categories, notes…"
              className="h-11 border-transparent bg-secondary/40 pl-10 pr-10 text-base"
            />
            {query && (
              <button
                onClick={() => onQuery("")}
                className="absolute right-3 top-1/2 -translate-y-1/2 text-muted-foreground hover:text-foreground"
                aria-label="Clear search"
              >
                <X className="size-4" />
              </button>
            )}
          </div>

          <div className="flex flex-wrap items-center gap-1.5">
            <Chip active={active === "all"} onClick={() => onActive("all")}>
              All
            </Chip>
            {categories.map((c) => (
              <Chip
                key={c.id}
                active={active === c.id}
                onClick={() => onActive(c.id)}
              >
                {c.name}
                <span className="ml-1.5 text-xs opacity-60 tabular-nums">
                  {c.count}
                </span>
              </Chip>
            ))}

            {managedCount > 0 && (
              <button
                onClick={onToggleManaged}
                className={cn(
                  "ml-auto inline-flex items-center gap-1.5 rounded-full border px-3 py-1.5 text-xs font-medium transition-colors",
                  showManaged
                    ? "border-accent/40 bg-accent/15 text-accent"
                    : "border-border text-muted-foreground hover:text-foreground"
                )}
              >
                <Sparkles className="size-3.5" />
                {showManaged ? "Hide" : "Show"} Bethesda content
                <span className="opacity-60 tabular-nums">{managedCount}</span>
              </button>
            )}
          </div>
        </div>
      </div>
    </div>
  )
}

function Chip({
  active,
  onClick,
  children,
}: {
  active: boolean
  onClick: () => void
  children: React.ReactNode
}) {
  return (
    <button
      onClick={onClick}
      className={cn(
        "inline-flex items-center rounded-full border px-3 py-1.5 text-xs font-medium transition-colors",
        active
          ? "border-primary/50 bg-primary/15 text-primary"
          : "border-border text-muted-foreground hover:border-primary/30 hover:text-foreground"
      )}
    >
      {children}
    </button>
  )
}
