import { BookOpen, Gamepad2, Sparkles } from "lucide-react"
import { Button } from "@/components/ui/button"
import { Badge } from "@/components/ui/badge"
import { GithubMark } from "@/components/icons"

interface HeroProps {
  game: string
  profile: string
  gameVersion: string | null
  repoUrl: string
}

export function Hero({ game, profile, gameVersion, repoUrl }: HeroProps) {
  return (
    <header className="relative overflow-hidden">
      <div className="pointer-events-none absolute inset-0 -z-10">
        <div className="absolute left-1/2 top-[-8rem] h-[28rem] w-[52rem] -translate-x-1/2 rounded-full bg-primary/20 blur-[120px]" />
        <div className="absolute right-[-6rem] top-10 h-[20rem] w-[20rem] rounded-full bg-accent/10 blur-[100px]" />
      </div>

      <div className="mx-auto max-w-6xl px-6 pt-20 pb-14 text-center sm:pt-28">
        <div className="mb-6 inline-flex items-center gap-2 rounded-full border border-border glass px-4 py-1.5 text-xs text-muted-foreground animate-in fade-in slide-in-from-top-2 duration-700">
          <Sparkles className="size-3.5 text-accent" />
          Reproducible modlist · version-controlled · one-command restore
        </div>

        <h1 className="font-display text-6xl font-bold tracking-tight sm:text-8xl">
          <span className="text-gradient">Ebonveil</span>
        </h1>

        <p className="mx-auto mt-5 max-w-2xl text-balance text-lg text-muted-foreground">
          A curated {game} mod list — beautifully showcased, and fully
          reproducible on any machine. Fork it, deploy to GitHub Pages, and share
          your load order the way it deserves.
        </p>

        <div className="mt-7 flex flex-wrap items-center justify-center gap-2.5">
          <Badge variant="ember" className="px-3 py-1">
            <Gamepad2 /> {game}
          </Badge>
          <Badge variant="secondary" className="px-3 py-1">
            Profile · {profile}
          </Badge>
          {gameVersion && (
            <Badge variant="outline" className="px-3 py-1">
              Runtime {gameVersion}
            </Badge>
          )}
        </div>

        <div className="mt-9 flex flex-wrap items-center justify-center gap-3">
          <Button asChild size="lg" className="ring-glow">
            <a href={repoUrl} target="_blank" rel="noreferrer">
              <GithubMark className="size-4" /> View on GitHub
            </a>
          </Button>
          <Button asChild size="lg" variant="outline">
            <a href={`${repoUrl}/blob/main/docs/RESTORE.md`} target="_blank" rel="noreferrer">
              <BookOpen /> Restore guide
            </a>
          </Button>
        </div>
      </div>
    </header>
  )
}
