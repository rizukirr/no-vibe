import fs from "node:fs"
import os from "node:os"
import path from "node:path"
import { fileURLToPath } from "node:url"

// Plugin root post-install: <plugin-root>/plugins/no-vibe.js
// Plugin root in repo dev:   <repo>/runtimes/opencode/plugins/no-vibe.js
// shared/ lives at:          <plugin-root>/shared/  (post-install)
//                            <repo>/shared/         (dev)
const SCRIPT_DIR = path.dirname(fileURLToPath(import.meta.url))
const PLUGIN_ROOT = path.resolve(SCRIPT_DIR, "..")
const REPO_ROOT = path.resolve(PLUGIN_ROOT, "..", "..")

const findSharedDir = () => {
  const candidates = [
    path.join(PLUGIN_ROOT, "shared"),
    path.join(REPO_ROOT, "shared"),
  ]
  for (const c of candidates) if (fs.existsSync(c)) return c
  return path.join(PLUGIN_ROOT, "shared")
}

const SHARED_DIR = findSharedDir()
const BOOTSTRAP_SENTINEL = "NO_VIBE_OPENCODE_BOOTSTRAP_V2"

const loadJson = (p) => {
  try { return JSON.parse(fs.readFileSync(p, "utf8")) } catch { return null }
}

const writeToolsConfig = loadJson(path.join(SHARED_DIR, "guard", "write-tools.json")) || {
  tools: ["Edit", "Write", "NotebookEdit", "MultiEdit", "ApplyPatch", "apply_patch"],
  path_fields: ["file_path", "notebook_path"],
}
const WRITE_TOOLS = new Set(writeToolsConfig.tools.map((t) => t.toLowerCase()))
const PATH_FIELDS = writeToolsConfig.path_fields
const BASH_TOOLS = new Set(["bash", "shell"])

const stripFrontmatter = (content) => {
  const match = content.match(/^---\n[\s\S]*?\n---\n?([\s\S]*)$/)
  return match ? match[1] : content
}

// Bundle every shared/skill/*.md into the bootstrap. OpenCode registers
// the shared/skill directory as a skills path, but only SKILL.md has
// frontmatter — phases.md / curriculum.md / teaching-style.md /
// reference-grounding.md are companion docs, not standalone skills, so
// they are not auto-discovered. Inline them so the model sees the full
// teaching discipline at session start. Order matches scripts/sync.sh.
const SKILL_FILES = [
  "SKILL.md",
  "phases.md",
  "teaching-style.md",
  "reference-grounding.md",
  "curriculum.md",
]

const buildBootstrap = () => {
  const parts = []
  for (const name of SKILL_FILES) {
    const p = path.join(SHARED_DIR, "skill", name)
    if (!fs.existsSync(p)) continue
    const body = stripFrontmatter(fs.readFileSync(p, "utf8")).trim()
    if (!body) continue
    if (parts.length === 0) {
      parts.push(body)
    } else {
      parts.push(`<!-- ===== shared/skill/${name} ===== -->\n\n${body}`)
    }
  }
  const skillBody =
    parts.length > 0
      ? parts.join("\n\n")
      : "You are in no-vibe tutor mode. Teach in chat; never write project files."
  return [
    `<!-- ${BOOTSTRAP_SENTINEL} -->`,
    "<EXTREMELY_IMPORTANT>",
    "no-vibe tutor mode is available in this repository.",
    "",
    skillBody,
    "",
    "**Tool mapping for OpenCode:** when skill content references tools you do not have, use OpenCode equivalents (`todowrite`, native subagent dispatch, native `skill` tool, native file/shell tools).",
    "</EXTREMELY_IMPORTANT>",
  ].join("\n")
}

const SAFE_DEV_PATHS = new Set(["/dev/null", "/dev/stdout", "/dev/stderr", "/dev/tty"])

const isSafeBashTarget = (cwd, rawPath) => {
  if (!rawPath) return false
  let p = rawPath
  if ((p.startsWith('"') && p.endsWith('"')) || (p.startsWith("'") && p.endsWith("'"))) p = p.slice(1, -1)
  if (!p) return false
  if (/[\$`]/.test(p)) return false
  if (SAFE_DEV_PATHS.has(p) || p.startsWith("/dev/fd/")) return true
  if (p === "/tmp" || p.startsWith("/tmp/") || p === "/var/tmp" || p.startsWith("/var/tmp/")) return true
  const abs = path.isAbsolute(p) ? path.resolve(p) : path.resolve(cwd, p)
  const scratch = canonicalize(path.resolve(cwd, ".no-vibe"))
  const homeScratch = canonicalize(path.resolve(os.homedir(), ".no-vibe"))
  const canonical = canonicalize(abs)
  if (canonical === scratch || canonical.startsWith(`${scratch}${path.sep}`)) return true
  if (canonical === homeScratch || canonical.startsWith(`${homeScratch}${path.sep}`)) return true
  if (canonical === "/tmp" || canonical.startsWith("/tmp/")) return true
  if (canonical === "/var/tmp" || canonical.startsWith("/var/tmp/")) return true
  return false
}

const splitTokens = (s) => s.split(/\s+/).filter(Boolean)

const inspectBashCommand = (cwd, command) => {
  if (!command) return null
  const clean = command.replace(/[0-9]+>&[0-9]+/g, "").replace(/[0-9]+<&[0-9]+/g, "")

  let m
  const redirRe = /(&>>?|>>?)\s*([^\s|&;<>()]+)/g
  while ((m = redirRe.exec(clean)) !== null) {
    if (!isSafeBashTarget(cwd, m[2])) return `redirection writes to '${m[2]}'`
  }

  const findArgsAfter = (cmdName) => {
    const re = new RegExp(`(?:^|[\\s|;&(])${cmdName}\\s+([^|;&]*)`)
    const match = clean.match(re)
    return match ? splitTokens(match[1]) : null
  }

  const teeArgs = findArgsAfter("tee")
  if (teeArgs) {
    for (const tok of teeArgs) {
      if (tok.startsWith("-")) continue
      if (!isSafeBashTarget(cwd, tok)) return `tee writes to '${tok}'`
    }
  }

  const sedMatch = clean.match(/(?:^|[\s|;&(])sed\s+([^|;&]*)/)
  if (sedMatch) {
    const tokens = splitTokens(sedMatch[1])
    const hasInPlace = tokens.some((t) => /^-[a-zA-Z]*i$/.test(t) || t.startsWith("-i") || t === "--in-place" || t.startsWith("--in-place="))
    if (hasInPlace) {
      let skipNext = false, sawScript = false
      for (const tok of tokens) {
        if (skipNext) { skipNext = false; continue }
        if (tok === "-e" || tok === "-f") { skipNext = true; continue }
        if (tok.startsWith("-")) continue
        if (!sawScript) { sawScript = true; continue }
        if (!isSafeBashTarget(cwd, tok)) return `sed -i mutates '${tok}'`
      }
    }
  }

  for (const cmdName of ["cp", "mv", "install"]) {
    const args = findArgsAfter(cmdName)
    if (!args) continue
    let last = null
    for (const tok of args) { if (!tok.startsWith("-")) last = tok }
    if (last && !isSafeBashTarget(cwd, last)) return `${cmdName} destination '${last}'`
  }

  const ddRe = /of=([^\s|&;()]+)/g
  while ((m = ddRe.exec(clean)) !== null) {
    if (!isSafeBashTarget(cwd, m[1])) return `dd of=${m[1]}`
  }

  return null
}

const tryRealpath = (p) => { try { return fs.realpathSync(p) } catch { return null } }

const canonicalize = (absolutePath) => {
  if (fs.existsSync(absolutePath)) return tryRealpath(absolutePath) || path.resolve(absolutePath)
  const resolved = path.resolve(absolutePath)
  let parent = path.dirname(resolved)
  while (parent !== path.dirname(parent) && !fs.existsSync(parent)) parent = path.dirname(parent)
  const canonicalParent = tryRealpath(parent) || path.resolve(parent)
  return path.resolve(canonicalParent, path.relative(parent, resolved))
}

const isWithinNoVibeDir = (cwd, abs) => {
  const projectRoot = canonicalize(path.resolve(cwd, ".no-vibe"))
  const homeRoot = canonicalize(path.resolve(os.homedir(), ".no-vibe"))
  const t = canonicalize(abs)
  if (t === projectRoot || t.startsWith(`${projectRoot}${path.sep}`)) return true
  if (t === homeRoot || t.startsWith(`${homeRoot}${path.sep}`)) return true
  return false
}

const isWriteTool = (name) => WRITE_TOOLS.has(String(name || "").toLowerCase())
const isBashTool = (name) => BASH_TOOLS.has(String(name || "").toLowerCase())

const getTargetPath = (args) => {
  for (const f of PATH_FIELDS) {
    if (args?.[f]) return args[f]
    const camel = f.replace(/_([a-z])/g, (_, c) => c.toUpperCase())
    if (args?.[camel]) return args[camel]
  }
  return null
}

export const NoVibePlugin = async ({ directory } = {}) => {
  const projectRoot = path.resolve(directory || process.cwd())
  const bootstrap = buildBootstrap()

  const resumeHint = () => {
    const sessionMd = path.join(projectRoot, ".no-vibe", "session.md")
    if (!fs.existsSync(sessionMd)) return null
    let content
    try { content = fs.readFileSync(sessionMd, "utf8") } catch { return null }
    const topicMatch = content.match(/^# Lesson:\s*(.+)$/m)
    const topic = topicMatch ? topicMatch[1].trim() : "untitled"
    const total = (content.match(/^- \[[ x]\]/gm) || []).length
    const done = (content.match(/^- \[x\]/gm) || []).length
    if (total === 0 || done >= total) return null
    return `resuming "${topic}" (${done}/${total} layers complete)`
  }

  const statusLine = () => {
    if (!fs.existsSync(path.join(projectRoot, ".no-vibe"))) return null
    if (!fs.existsSync(path.join(projectRoot, ".no-vibe", "active"))) return "no-vibe: OFF"
    const hint = resumeHint()
    return hint ? `no-vibe: ON — ${hint}` : "no-vibe: ON"
  }

  return {
    config: async (config = {}) => {
      config.skills = config.skills || {}
      config.skills.paths = config.skills.paths || []
      const skillsDir = path.join(SHARED_DIR, "skill")
      if (!config.skills.paths.some((entry) => path.resolve(entry) === skillsDir)) {
        config.skills.paths.push(skillsDir)
      }
      return config
    },

    "experimental.chat.messages.transform": async (_input, output) => {
      const messages = output?.messages
      if (!Array.isArray(messages) || messages.length === 0) return
      const firstUserMessage = messages.find((m) => m?.info?.role === "user")
      if (!firstUserMessage || !Array.isArray(firstUserMessage.parts)) return
      const alreadyInjected = firstUserMessage.parts.some(
        (part) => part?.type === "text" && typeof part.text === "string" && part.text.includes(BOOTSTRAP_SENTINEL),
      )
      if (alreadyInjected) return
      const status = statusLine()
      const text = status ? `${status}\n\n${bootstrap}` : bootstrap
      firstUserMessage.parts.unshift({ type: "text", text })
    },

    "tool.execute.before": async (input, output) => {
      const cwd = path.resolve(input?.session?.cwd || input?.cwd || projectRoot)
      const markerPath = path.join(cwd, ".no-vibe", "active")
      if (!fs.existsSync(markerPath)) return

      if (isBashTool(input?.tool)) {
        const args = output?.args || input?.args || {}
        const command = args.command || args.cmd || ""
        const reason = inspectBashCommand(cwd, command)
        if (reason) {
          throw new Error(
            `no-vibe is active. Refusing Bash — ${reason}. Safe targets: '.no-vibe/**', '$HOME/.no-vibe/**', '/tmp/**', '/var/tmp/**', '/dev/{null,stdout,stderr,tty,fd/*}'. Variable / command-substitution destinations fail closed. Show code in chat; user runs it. '/no-vibe off' to exit.`,
          )
        }
        return
      }

      if (!isWriteTool(input?.tool)) return

      const targetPath = getTargetPath(output?.args || input?.args || {})
      if (!targetPath) {
        throw new Error(
          `no-vibe is active. Refusing '${String(input?.tool || "unknown")}' — no target path provided. Show code in chat; user types it. '/no-vibe off' to exit.`,
        )
      }

      const absolute = path.isAbsolute(targetPath) ? path.resolve(targetPath) : path.resolve(cwd, targetPath)
      if (isWithinNoVibeDir(cwd, absolute)) return

      throw new Error(
        `no-vibe is active. Cannot write to '${absolute}'. Show code in chat; user types it. Use '.no-vibe/' for notes. '/no-vibe off' to exit.`,
      )
    },
  }
}

export default NoVibePlugin
