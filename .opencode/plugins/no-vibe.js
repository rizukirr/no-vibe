import fs from "node:fs"
import os from "node:os"
import path from "node:path"
import { fileURLToPath } from "node:url"

const WRITE_TOOLS = new Set(["edit", "write", "notebookedit", "multiedit", "apply_patch", "applypatch"])
const BASH_TOOLS = new Set(["bash", "shell"])
const BOOTSTRAP_SENTINEL = "NO_VIBE_OPENCODE_BOOTSTRAP_V1"

const stripFrontmatter = (content) => {
  const match = content.match(/^---\n[\s\S]*?\n---\n?([\s\S]*)$/)
  return match ? match[1] : content
}

const PLUGIN_ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..", "..")

const getSkillsDir = () => path.resolve(PLUGIN_ROOT, "skills")

const buildBootstrap = (skillsDir) => {
  const skillPath = path.join(skillsDir, "no-vibe", "SKILL.md")
  const schemaPath = path.join(skillsDir, "no-vibe", "DATA-SCHEMA.md")
  let skillBody = "You are in no-vibe mode. Teach in chat and never write project files directly."
  let schemaBody = ""

  if (fs.existsSync(skillPath)) {
    skillBody = stripFrontmatter(fs.readFileSync(skillPath, "utf8")).trim()
  }

  if (fs.existsSync(schemaPath)) {
    schemaBody = "\n\n## Data Schema Reference\n\n" + stripFrontmatter(fs.readFileSync(schemaPath, "utf8")).trim()
  }

  return [
    `<!-- ${BOOTSTRAP_SENTINEL} -->`,
    "<EXTREMELY_IMPORTANT>",
    "no-vibe mode is available in this repository.",
    "",
    skillBody,
    schemaBody,
    "",
    "**Tool Mapping for OpenCode:**",
    "When skill content references tools you do not have, use OpenCode equivalents:",
    "- `TodoWrite` -> `todowrite`",
    "- `Task` with subagents -> OpenCode subagent dispatch",
    "- `Skill` tool -> OpenCode native `skill` tool",
    "- File and shell actions -> OpenCode native tools",
    "</EXTREMELY_IMPORTANT>",
  ].join("\n")
}

const isWriteTool = (toolName) => WRITE_TOOLS.has(String(toolName || "").toLowerCase())
const isBashTool = (toolName) => BASH_TOOLS.has(String(toolName || "").toLowerCase())

const SAFE_DEV_PATHS = new Set(["/dev/null", "/dev/stdout", "/dev/stderr", "/dev/tty"])

const isSafeBashTarget = (cwd, rawPath) => {
  if (!rawPath) return false
  let p = rawPath
  if ((p.startsWith('"') && p.endsWith('"')) || (p.startsWith("'") && p.endsWith("'"))) {
    p = p.slice(1, -1)
  }
  if (!p) return false
  if (/[\$`]/.test(p)) return false
  if (SAFE_DEV_PATHS.has(p) || p.startsWith("/dev/fd/")) return true
  if (p === "/tmp" || p.startsWith("/tmp/") || p === "/var/tmp" || p.startsWith("/var/tmp/")) return true
  const abs = path.isAbsolute(p) ? path.resolve(p) : path.resolve(cwd, p)
  const scratch = canonicalizePathForAllowlist(path.resolve(cwd, ".no-vibe"))
  const homeScratch = canonicalizePathForAllowlist(path.resolve(os.homedir(), ".no-vibe"))
  const canonical = canonicalizePathForAllowlist(abs)
  if (canonical === scratch || canonical.startsWith(`${scratch}${path.sep}`)) return true
  if (canonical === homeScratch || canonical.startsWith(`${homeScratch}${path.sep}`)) return true
  if (canonical === "/tmp" || canonical.startsWith("/tmp/")) return true
  if (canonical === "/var/tmp" || canonical.startsWith("/var/tmp/")) return true
  return false
}

const splitTokens = (segment) => segment.split(/\s+/).filter(Boolean)

const inspectBashCommand = (cwd, command) => {
  if (!command) return null
  const clean = command.replace(/[0-9]+>&[0-9]+/g, "").replace(/[0-9]+<&[0-9]+/g, "")

  const redirRe = /(&>>?|>>?)\s*([^\s|&;<>()]+)/g
  let m
  while ((m = redirRe.exec(clean)) !== null) {
    if (!isSafeBashTarget(cwd, m[2])) {
      return `redirection writes to '${m[2]}' outside .no-vibe/ or /tmp/`
    }
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
      if (!isSafeBashTarget(cwd, tok)) {
        return `tee writes to '${tok}' outside .no-vibe/ or /tmp/`
      }
    }
  }

  const sedRe = /(?:^|[\s|;&(])sed\s+([^|;&]*)/
  const sedMatch = clean.match(sedRe)
  if (sedMatch) {
    const tokens = splitTokens(sedMatch[1])
    const hasInPlace = tokens.some((t) => /^-[a-zA-Z]*i$/.test(t) || t.startsWith("-i") || t === "--in-place" || t.startsWith("--in-place="))
    if (hasInPlace) {
      let skipNext = false
      let sawScript = false
      for (const tok of tokens) {
        if (skipNext) { skipNext = false; continue }
        if (tok === "-e" || tok === "-f") { skipNext = true; continue }
        if (tok.startsWith("-")) continue
        if (!sawScript) { sawScript = true; continue }
        if (!isSafeBashTarget(cwd, tok)) {
          return `sed -i mutates '${tok}' outside .no-vibe/ or /tmp/`
        }
      }
    }
  }

  for (const cmdName of ["cp", "mv", "install"]) {
    const args = findArgsAfter(cmdName)
    if (!args) continue
    let last = null
    for (const tok of args) {
      if (tok.startsWith("-")) continue
      last = tok
    }
    if (last && !isSafeBashTarget(cwd, last)) {
      return `${cmdName} destination '${last}' outside .no-vibe/ or /tmp/`
    }
  }

  const ddRe = /of=([^\s|&;()]+)/g
  while ((m = ddRe.exec(clean)) !== null) {
    if (!isSafeBashTarget(cwd, m[1])) {
      return `dd of=${m[1]} writes outside .no-vibe/ or /tmp/`
    }
  }

  return null
}

const getTargetPath = (args) => args?.filePath || args?.file_path || args?.notebookPath || args?.notebook_path || null

const resolveTargetPath = (cwd, targetPath) => {
  if (!targetPath) return null
  return path.isAbsolute(targetPath) ? path.resolve(targetPath) : path.resolve(cwd, targetPath)
}

const tryRealpath = (targetPath) => {
  try {
    return fs.realpathSync(targetPath)
  } catch {
    return null
  }
}

const canonicalizePathForAllowlist = (absolutePath) => {
  if (fs.existsSync(absolutePath)) {
    return tryRealpath(absolutePath) || path.resolve(absolutePath)
  }

  const resolved = path.resolve(absolutePath)
  let parent = path.dirname(resolved)
  while (parent !== path.dirname(parent) && !fs.existsSync(parent)) {
    parent = path.dirname(parent)
  }

  const canonicalParent = tryRealpath(parent) || path.resolve(parent)
  return path.resolve(canonicalParent, path.relative(parent, resolved))
}

const isWithinNoVibeDir = (cwd, absoluteTargetPath) => {
  const projectRoot = canonicalizePathForAllowlist(path.resolve(cwd, ".no-vibe"))
  const homeRoot = canonicalizePathForAllowlist(path.resolve(os.homedir(), ".no-vibe"))
  const canonicalTarget = canonicalizePathForAllowlist(absoluteTargetPath)
  if (canonicalTarget === projectRoot || canonicalTarget.startsWith(`${projectRoot}${path.sep}`)) return true
  if (canonicalTarget === homeRoot || canonicalTarget.startsWith(`${homeRoot}${path.sep}`)) return true
  return false
}

export const NoVibePlugin = async ({ directory } = {}) => {
  const projectRoot = path.resolve(directory || process.cwd())
  const skillsDir = getSkillsDir()
  const bootstrap = buildBootstrap(skillsDir)
  const resumeHint = () => {
    const sessionsDir = path.join(projectRoot, ".no-vibe", "data", "sessions")
    if (!fs.existsSync(sessionsDir)) return null
    let entries
    try {
      entries = fs.readdirSync(sessionsDir).filter((name) => name.endsWith(".json"))
    } catch {
      return null
    }
    let best = null
    let bestMtime = -Infinity
    for (const name of entries) {
      const full = path.join(sessionsDir, name)
      let raw
      try {
        raw = fs.readFileSync(full, "utf8")
      } catch {
        continue
      }
      let parsed
      try {
        parsed = JSON.parse(raw)
      } catch {
        continue
      }
      if (parsed?.status !== "in_progress") continue
      let mtime = 0
      try {
        mtime = fs.statSync(full).mtimeMs
      } catch {
        // fall through with mtime=0
      }
      if (mtime > bestMtime) {
        bestMtime = mtime
        best = parsed
      }
    }
    if (!best) return null
    const topic = best.topic ?? "untitled"
    const cur = best.current_layer ?? 0
    const tot = best.layers_total ?? 0
    const phase = best.current_phase ?? "?"
    return `resuming "${topic}" (layer ${cur}/${tot}, ${phase})`
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

      if (!config.skills.paths.some((entry) => path.resolve(entry) === skillsDir)) {
        config.skills.paths.push(skillsDir)
      }

      return config
    },

    "experimental.chat.messages.transform": async (_input, output) => {
      const messages = output?.messages
      if (!Array.isArray(messages) || messages.length === 0) return

      const firstUserMessage = messages.find((message) => message?.info?.role === "user")
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
            `no-vibe mode is active. Refusing Bash command — ${reason}. Safe targets: '.no-vibe/**', '$HOME/.no-vibe/**', '/tmp/**', '/var/tmp/**', '/dev/{null,stdout,stderr,tty,fd/*}'. Variable / command-substitution destinations fail closed. Show the code in chat and let the user run it. Run '/no-vibe off' to disable.`,
          )
        }
        return
      }

      if (!isWriteTool(input?.tool)) return

      const targetPath = getTargetPath(output?.args || input?.args || {})
      if (!targetPath) {
        throw new Error(
          `no-vibe mode is active. Refusing '${String(input?.tool || "unknown")}' because no target path was provided. Show code in chat and let the user type it, or run '/no-vibe off'.`,
        )
      }

      const absoluteTargetPath = resolveTargetPath(cwd, targetPath)
      if (!absoluteTargetPath) {
        throw new Error(
          `no-vibe mode is active. Refusing '${String(input?.tool || "unknown")}' because target path could not be resolved. Show code in chat and let the user type it, or run '/no-vibe off'.`,
        )
      }

      if (isWithinNoVibeDir(cwd, absoluteTargetPath)) return

      throw new Error(
        `no-vibe mode is active. Refusing write to '${absoluteTargetPath}'. Show code in chat and let the user type it. Use '.no-vibe/' for notes, or run '/no-vibe off' to disable.`,
      )
    },
  }
}

export default NoVibePlugin
