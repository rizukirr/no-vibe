import fs from "node:fs"
import path from "node:path"
import { fileURLToPath } from "node:url"

const WRITE_TOOLS = new Set(["edit", "write", "notebookedit", "multiedit", "apply_patch", "applypatch"])
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
  const allowedRoot = canonicalizePathForAllowlist(path.resolve(cwd, ".no-vibe"))
  const canonicalTarget = canonicalizePathForAllowlist(absoluteTargetPath)
  return canonicalTarget === allowedRoot || canonicalTarget.startsWith(`${allowedRoot}${path.sep}`)
}

export const NoVibePlugin = async ({ directory } = {}) => {
  const projectRoot = path.resolve(directory || process.cwd())
  const skillsDir = getSkillsDir()
  const bootstrap = buildBootstrap(skillsDir)
  const statusLine = () => {
    if (!fs.existsSync(path.join(projectRoot, ".no-vibe"))) return null
    return fs.existsSync(path.join(projectRoot, ".no-vibe", "active")) ? "no-vibe: ON" : "no-vibe: OFF"
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
