export interface ModNexus {
  modId: number
  domain: string
  url: string
}

export interface ModEntry {
  name: string
  slug: string
  order: number
  enabled: boolean
  managed: boolean
  category: string
  nexus: ModNexus | null
  version: string | null
  source: string | null
  required: boolean | null
  notes: string | null
}

export interface ModSection {
  id: string
  name: string
  blurb: string | null
  mods: ModEntry[]
}

export interface ModListStats {
  total: number
  enabled: number
  managed: number
  plugins: number
  sections: number
  nexusLinked: number
}

export interface ModListData {
  generatedAt: string
  profile: string
  game: string
  gameVersion: string | null
  repoUrl: string
  stats: ModListStats
  plugins: string[]
  sections: ModSection[]
}
