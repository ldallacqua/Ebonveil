import { Terminal } from "lucide-react"
import { GithubMark } from "@/components/icons"

interface FooterProps {
  repoUrl: string
  generatedAt: string
}

export function Footer({ repoUrl, generatedAt }: FooterProps) {
  const date = new Date(generatedAt)
  const stamp = Number.isNaN(date.getTime())
    ? generatedAt
    : date.toLocaleDateString(undefined, {
        year: "numeric",
        month: "short",
        day: "numeric",
      })

  return (
    <footer className="mx-auto mt-20 max-w-6xl px-6 pb-16">
      <div className="glass rounded-2xl border border-border p-6 sm:p-8">
        <div className="flex flex-col items-center gap-4 text-center">
          <h3 className="font-display text-2xl font-semibold text-gradient">
            Clone it. Restore it. Make it yours.
          </h3>
          <p className="max-w-xl text-sm text-muted-foreground">
            Ebonveil is a version-controlled Mod Organizer 2 instance. This page is
            generated straight from the tracked load order — no manual list-keeping.
          </p>
          <div className="mt-1 w-full max-w-xl rounded-lg border border-border bg-black/40 p-4 text-left font-mono text-xs text-muted-foreground">
            <div className="flex items-center gap-2 text-primary/80">
              <Terminal className="size-3.5" /> restore on a fresh machine
            </div>
            <pre className="mt-2 overflow-x-auto whitespace-pre leading-relaxed">
{`git clone ${repoUrl.replace("https://github.com/", "git@github.com:")}.git
pwsh -File tools/bootstrap-mo2.ps1
pwsh -File tools/configure-mo2.ps1
pwsh -File tools/restore-mods.ps1
pwsh -File tools/install-m1.ps1`}
            </pre>
          </div>
          <a
            href={repoUrl}
            target="_blank"
            rel="noreferrer"
            className="inline-flex items-center gap-2 text-sm text-muted-foreground transition-colors hover:text-foreground"
          >
            <GithubMark className="size-4" /> {repoUrl.replace("https://github.com/", "")}
          </a>
          <p className="text-xs text-muted-foreground/60">
            Generated {stamp} · built with Vite, React & Tailwind
          </p>
        </div>
      </div>
    </footer>
  )
}
