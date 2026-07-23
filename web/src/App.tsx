import { useMemo, useState } from "react"
import { SearchX } from "lucide-react"
import type { ModListData, ModSection } from "@/types"
import rawData from "@/data/modlist.json"
import { Hero } from "@/components/Hero"
import { StatsBar } from "@/components/StatsBar"
import { Toolbar, type CategoryChip } from "@/components/Toolbar"
import { SectionGroup } from "@/components/SectionGroup"
import { Footer } from "@/components/Footer"

const data = rawData as unknown as ModListData

function isManagedSection(section: ModSection) {
  return section.mods.length > 0 && section.mods.every((m) => m.managed)
}

function matchesQuery(text: string, q: string) {
  return text.toLowerCase().includes(q)
}

export default function App() {
  const [query, setQuery] = useState("")
  const [active, setActive] = useState("all")
  const [showManaged, setShowManaged] = useState(false)

  const curatedCategories: CategoryChip[] = useMemo(
    () =>
      data.sections
        .filter((s) => !isManagedSection(s))
        .map((s) => ({ id: s.id, name: s.name, count: s.mods.length })),
    []
  )

  const managedCount = useMemo(
    () =>
      data.sections
        .filter(isManagedSection)
        .reduce((n, s) => n + s.mods.length, 0),
    []
  )

  const visibleSections = useMemo(() => {
    const q = query.trim().toLowerCase()
    return data.sections
      .filter((s) => (active === "all" ? true : s.id === active))
      .filter((s) => {
        if (isManagedSection(s)) {
          // managed shows when explicitly toggled or explicitly selected
          return showManaged || active === s.id
        }
        return true
      })
      .map((s) => {
        if (!q) return s
        const mods = s.mods.filter(
          (m) =>
            matchesQuery(m.name, q) ||
            matchesQuery(m.category, q) ||
            (m.notes ? matchesQuery(m.notes, q) : false)
        )
        return { ...s, mods }
      })
      .filter((s) => s.mods.length > 0)
  }, [query, active, showManaged])

  const nothingFound = visibleSections.length === 0

  return (
    <div className="min-h-dvh">
      <Hero
        game={data.game}
        profile={data.profile}
        gameVersion={data.gameVersion}
        repoUrl={data.repoUrl}
      />

      <main className="pb-10">
        <StatsBar stats={data.stats} />

        <div className="mt-8">
          <Toolbar
            query={query}
            onQuery={setQuery}
            categories={curatedCategories}
            active={active}
            onActive={setActive}
            showManaged={showManaged}
            onToggleManaged={() => setShowManaged((v) => !v)}
            managedCount={managedCount}
          />
        </div>

        <div className="mx-auto mt-10 max-w-6xl space-y-12 px-6">
          {nothingFound ? (
            <div className="flex flex-col items-center gap-3 rounded-2xl border border-border glass py-20 text-center">
              <SearchX className="size-8 text-muted-foreground" />
              <p className="text-lg font-medium">No mods match your search</p>
              <p className="text-sm text-muted-foreground">
                Try a different term{!showManaged && managedCount > 0 ? " or reveal Bethesda content" : ""}.
              </p>
            </div>
          ) : (
            visibleSections.map((section) => (
              <SectionGroup
                key={section.id}
                section={section}
                compact={isManagedSection(section)}
                defaultCollapsed={isManagedSection(section) && active === "all"}
              />
            ))
          )}
        </div>
      </main>

      <Footer repoUrl={data.repoUrl} generatedAt={data.generatedAt} />
    </div>
  )
}
