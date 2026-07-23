#!/usr/bin/env node
/*
 * Ebonveil data generator.
 * Reads the tracked MO2 profile (modlist/plugins) + manifest and emits
 * web/src/data/modlist.json, which the React app renders.
 *
 * Pure Node, no deps. Safe to run in CI (missing local-only files are tolerated).
 */
import { readFileSync, writeFileSync, existsSync, mkdirSync } from 'node:fs'
import { fileURLToPath } from 'node:url'
import { dirname, join, resolve } from 'node:path'
import { execSync } from 'node:child_process'

const __dirname = dirname(fileURLToPath(import.meta.url))
const webRoot = resolve(__dirname, '..')
const repoRoot = resolve(webRoot, '..')

const PROFILE = process.env.EBONVEIL_PROFILE ?? 'Default'
const profileDir = join(repoRoot, 'mo2', 'profiles', PROFILE)
const manifestPath = join(repoRoot, 'manifest', 'mods.json')
const resolvedPath = join(repoRoot, 'mo2', 'downloads', '.ebonveil-resolved.json')
const outDir = join(webRoot, 'src', 'data')
const outPath = join(outDir, 'modlist.json')

const CATEGORY_ORDER = [
  'Script Extender & Core',
  'Frameworks & Resources',
  'User Interface',
  'Gameplay',
  'Graphics & Visuals',
  'Immersion & Atmosphere',
  'Characters & Romance',
  'Audio',
  'Other Mods',
  'Official DLC',
  'Creation Club',
]

const CATEGORY_BLURB = {
  'Script Extender & Core': 'The foundation every other mod is built on.',
  'Frameworks & Resources': 'Shared libraries and assets other mods depend on.',
  'User Interface': 'A cleaner, controller-friendly, information-rich HUD and menus.',
  Gameplay: 'Systems, combat and mechanics that reshape how Skyrim plays.',
  'Graphics & Visuals': 'Textures, lighting and effects for a modern look.',
  'Immersion & Atmosphere': 'Weather, survival and world detail that pull you in.',
  'Characters & Romance': 'NPCs, followers and relationship overhauls.',
  Audio: 'Music, ambience and sound design.',
  'Other Mods': 'Everything else in the load order.',
  'Official DLC': 'Bethesda add-ons managed by the game.',
  'Creation Club': 'Bethesda Creation Club content managed by the game.',
}

function readJson(path, fallback) {
  try {
    return JSON.parse(readFileSync(path, 'utf8'))
  } catch {
    return fallback
  }
}

function readLines(path) {
  if (!existsSync(path)) return []
  return readFileSync(path, 'utf8')
    .split(/\r?\n/)
    .map((l) => l.trimEnd())
    .filter((l) => l.length > 0 && !l.startsWith('#'))
}

function slugify(s) {
  return s
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, '-')
    .replace(/(^-|-$)/g, '')
}

function detectRepoUrl() {
  if (process.env.EBONVEIL_REPO_URL) return process.env.EBONVEIL_REPO_URL
  try {
    const raw = execSync('git config --get remote.origin.url', {
      cwd: repoRoot,
      stdio: ['ignore', 'pipe', 'ignore'],
    })
      .toString()
      .trim()
    const m = raw.match(/github\.com[:/]+(.+?)(?:\.git)?$/i)
    if (m) return `https://github.com/${m[1]}`
  } catch {
    /* not a repo / no remote */
  }
  return 'https://github.com/ldallacqua/Ebonveil'
}

// --- inputs ---
const manifest = readJson(manifestPath, { mods: [] })
const resolved = readJson(resolvedPath, {})
const modlistLines = readLines(join(profileDir, 'modlist.txt'))
const pluginLines = readLines(join(profileDir, 'plugins.txt'))

// index manifest by a normalized match key
const manifestMods = Array.isArray(manifest.mods) ? manifest.mods : []
function matchManifest(name) {
  const lower = name.toLowerCase()
  return (
    manifestMods.find((m) => {
      const key = (m.match ?? m.name ?? '').toLowerCase()
      return key && (lower === key || lower.startsWith(key) || lower.includes(key))
    }) ?? null
  )
}

function deriveCategory(name, managed, manifestEntry) {
  if (manifestEntry?.category) return manifestEntry.category
  if (name.startsWith('Creation Club')) return 'Creation Club'
  if (name.startsWith('DLC:')) return 'Official DLC'
  if (managed) return 'Official DLC'
  return 'Other Mods'
}

// MO2 modlist.txt: first line = highest priority. Prefix +enabled -disabled *game-managed.
const mods = []
let order = 0
for (const line of modlistLines) {
  const prefix = line[0]
  const name = line.slice(1)
  if (name.endsWith('_separator')) continue // separators are cosmetic here
  order += 1
  const enabled = prefix === '+' || prefix === '*'
  const managed = prefix === '*'
  const manifestEntry = managed ? null : matchManifest(name)
  const category = deriveCategory(name, managed, manifestEntry)

  const resolvedEntry = manifestEntry ? resolved?.[manifestEntry.id] : null

  mods.push({
    name,
    slug: slugify(name),
    order,
    enabled,
    managed,
    category,
    nexus: manifestEntry?.nexus
      ? {
          modId: manifestEntry.nexus.modId,
          domain: manifestEntry.nexus.domain,
          url:
            manifestEntry.nexus.url ??
            `https://www.nexusmods.com/${manifestEntry.nexus.domain}/mods/${manifestEntry.nexus.modId}`,
        }
      : null,
    version: resolvedEntry?.version ?? null,
    source: manifestEntry?.source ?? (managed ? 'bethesda' : null),
    required: manifestEntry ? Boolean(manifestEntry.required) : null,
    notes: manifestEntry?.notes ?? null,
  })
}

// group by category, ordered
const byCategory = new Map()
for (const mod of mods) {
  if (!byCategory.has(mod.category)) byCategory.set(mod.category, [])
  byCategory.get(mod.category).push(mod)
}
const orderedCats = [
  ...CATEGORY_ORDER.filter((c) => byCategory.has(c)),
  ...[...byCategory.keys()].filter((c) => !CATEGORY_ORDER.includes(c)),
]
const sections = orderedCats.map((cat) => ({
  id: slugify(cat),
  name: cat,
  blurb: CATEGORY_BLURB[cat] ?? null,
  mods: byCategory.get(cat),
}))

const plugins = pluginLines
  .filter((l) => l.startsWith('*') || /\.es[plm]$/i.test(l))
  .map((l) => (l.startsWith('*') ? l.slice(1) : l))

const gameVersion =
  Object.values(resolved).map((r) => r?.skyrimVersion).find(Boolean) ?? null

const data = {
  generatedAt: new Date().toISOString(),
  profile: PROFILE,
  game: manifest.game === 'skyrimspecialedition' ? 'Skyrim Special Edition' : manifest.game ?? 'Skyrim Special Edition',
  gameVersion,
  repoUrl: detectRepoUrl(),
  stats: {
    total: mods.length,
    enabled: mods.filter((m) => m.enabled).length,
    managed: mods.filter((m) => m.managed).length,
    plugins: plugins.length,
    sections: sections.length,
    nexusLinked: mods.filter((m) => m.nexus).length,
  },
  plugins,
  sections,
}

mkdirSync(outDir, { recursive: true })
writeFileSync(outPath, JSON.stringify(data, null, 2) + '\n', 'utf8')
console.log(
  `Ebonveil: wrote ${outPath} (${data.stats.total} mods, ${data.stats.sections} sections, ${data.stats.plugins} plugins)`
)
