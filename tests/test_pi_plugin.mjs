import assert from "node:assert/strict"
import fs from "node:fs"
import path from "node:path"
import { fileURLToPath } from "node:url"

const __dirname = path.dirname(fileURLToPath(import.meta.url))
const repoRoot = path.resolve(__dirname, "..")
const piPluginDir = path.join(repoRoot, "runtimes", "pi", ".pi-plugin")

const run = async () => {
  // C1 — manifest exists and well-formed
  const manifestPath = path.join(piPluginDir, "plugin.json")
  assert.ok(fs.existsSync(manifestPath), "runtimes/pi/.pi-plugin/plugin.json must exist")
  const manifest = JSON.parse(fs.readFileSync(manifestPath, "utf8"))
  for (const key of ["name", "description", "version"]) {
    assert.ok(manifest[key], `manifest must contain '${key}'`)
  }

  // C2 — package.json pi key
  const pkg = JSON.parse(fs.readFileSync(path.join(repoRoot, "package.json"), "utf8"))
  assert.ok(Array.isArray(pkg.keywords) && pkg.keywords.includes("pi-package"), "package.json must declare 'pi-package' keyword")
  assert.ok(pkg.pi && typeof pkg.pi === "object", "package.json must have 'pi' key")
  for (const sub of ["skills", "prompts", "extensions"]) {
    assert.ok(Array.isArray(pkg.pi[sub]) && pkg.pi[sub].length > 0, `package.json.pi.${sub} must be a non-empty array`)
  }

  // Version parity with manifest
  assert.equal(pkg.version, manifest.version, "package.json version must match plugin.json version")

  // C3 — extension exists with v2 hooks
  const extPath = path.join(piPluginDir, "extensions", "no-vibe", "index.ts")
  assert.ok(fs.existsSync(extPath), "pi extension index.ts must exist")
  const extSrc = fs.readFileSync(extPath, "utf8")
  assert.ok(extSrc.includes("before_agent_start"), "extension must hook 'before_agent_start' to inject bootstrap")
  assert.ok(extSrc.includes("tool_call"), "extension must hook 'tool_call' for write-guard enforcement")
  assert.ok(extSrc.includes(".no-vibe") && extSrc.includes("active"), "extension must check '.no-vibe/active' marker")

  // Parity with OpenCode plugin allowlist
  const ocSrc = fs.readFileSync(path.join(repoRoot, "runtimes/opencode/plugins/no-vibe.js"), "utf8")
  const allowlistTokens = ["/tmp", "/var/tmp", "/dev/null", "/dev/stdout", "/dev/stderr", "/dev/tty", "/dev/fd/"]
  for (const tok of allowlistTokens) {
    assert.ok(extSrc.includes(tok), `pi extension must include allowlist token '${tok}'`)
    assert.ok(ocSrc.includes(tok), `opencode plugin must include allowlist token '${tok}' (parity check)`)
  }

  // Bash patterns parity
  for (const pat of ["tee", "sed", "cp", "mv", "install", "dd", "of="]) {
    assert.ok(extSrc.includes(pat), `pi extension must inspect bash pattern '${pat}'`)
  }

  // C4 — shared command prose present
  const promptsDir = path.join(repoRoot, "shared", "commands")
  for (const name of ["no-vibe.md", "no-vibe-btw.md", "no-vibe-challenge.md", "no-vibe-forget.md", "no-vibe-clear.md"]) {
    const p = path.join(promptsDir, name)
    assert.ok(fs.existsSync(p), `shared/commands/${name} must exist`)
    const body = fs.readFileSync(p, "utf8")
    assert.ok(body.startsWith("---\n"), `${name} must start with YAML frontmatter`)
    assert.ok(/\ndescription:/.test(body), `${name} must declare description in frontmatter`)
  }

  // C5 — v2 has no Turn Response Contract; explicitly assert it's gone
  const noVibeBody = fs.readFileSync(path.join(promptsDir, "no-vibe.md"), "utf8")
  assert.ok(!noVibeBody.includes("Turn Response Contract"), "v2 commands must not include the v1 Turn Response Contract")
  assert.ok(!noVibeBody.includes("[no-vibe] Phase:"), "v2 commands must not include the v1 phase header format")

  // C6 — shared skill memory contract present
  const skillBody = fs.readFileSync(path.join(repoRoot, "shared/skill/SKILL.md"), "utf8")
  assert.ok(skillBody.includes("NO-VIBE.md"), "SKILL.md must reference NO-VIBE.md memory file")
  assert.ok(skillBody.includes("Iron Law"), "SKILL.md must include Iron Law")

  console.log("ok — pi plugin v2 parity checks pass")
}

run().catch((err) => {
  console.error(err)
  process.exit(1)
})
