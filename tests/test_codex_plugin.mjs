import assert from "node:assert/strict"
import fs from "node:fs"
import path from "node:path"
import { fileURLToPath } from "node:url"

const __dirname = path.dirname(fileURLToPath(import.meta.url))
const repoRoot = path.resolve(__dirname, "..")
const codexPluginDir = path.join(repoRoot, ".codex-plugin")

const run = async () => {
  // C1 — manifest exists and carries required top-level fields
  const manifestPath = path.join(codexPluginDir, "plugin.json")
  assert.ok(fs.existsSync(manifestPath), ".codex-plugin/plugin.json must exist")
  const manifest = JSON.parse(fs.readFileSync(manifestPath, "utf8"))
  for (const key of ["name", "description", "version", "hooks"]) {
    assert.ok(manifest[key], `manifest must contain '${key}'`)
  }

  // C2 — version parity with package.json (the canonical bump anchor)
  const pkg = JSON.parse(fs.readFileSync(path.join(repoRoot, "package.json"), "utf8"))
  assert.equal(
    pkg.version,
    manifest.version,
    "package.json version must match .codex-plugin/plugin.json version",
  )

  // C3 — PreToolUse and SessionStart hooks declared
  assert.ok(Array.isArray(manifest.hooks.PreToolUse), "hooks.PreToolUse must be an array")
  assert.ok(Array.isArray(manifest.hooks.SessionStart), "hooks.SessionStart must be an array")
  assert.ok(manifest.hooks.PreToolUse.length >= 3, "must declare write/bash/memory PreToolUse hooks")

  // C4 — every hook command points at a file that exists, with one of the
  // supported runtime variables Codex provides (PLUGIN_ROOT or
  // CLAUDE_PLUGIN_ROOT). Hook scripts must be executable so Codex can spawn
  // them; npm publish preserves the bits if they exist locally.
  const allHooks = [...manifest.hooks.PreToolUse, ...manifest.hooks.SessionStart].flatMap(
    (group) => group.hooks ?? [],
  )
  assert.ok(allHooks.length >= 4, "expected at least 4 hook command entries")
  for (const h of allHooks) {
    assert.equal(h.type, "command", `hook entry must be type=command, got ${h.type}`)
    const match = h.command.match(/^\$\{(PLUGIN_ROOT|CLAUDE_PLUGIN_ROOT)\}(.*)$/)
    assert.ok(match, `hook command must use \${PLUGIN_ROOT} or \${CLAUDE_PLUGIN_ROOT}: ${h.command}`)
    const relPath = match[2].replace(/^\//, "")
    const absPath = path.join(repoRoot, relPath)
    assert.ok(fs.existsSync(absPath), `hook script must exist on disk: ${relPath}`)
    const mode = fs.statSync(absPath).mode
    // Owner-executable bit (0o100) — required for Codex to spawn the script.
    assert.ok((mode & 0o100) !== 0, `hook script must be executable (chmod +x): ${relPath}`)
  }

  // C5 — write-guard matcher covers both Claude and Codex tool names so the
  // same hook fires on either runtime. Codex's primary write tool is
  // `apply_patch`; we keep the broader matcher for cross-runtime portability.
  const writeMatcher = manifest.hooks.PreToolUse[0].matcher
  for (const tool of ["apply_patch", "Edit", "Write"]) {
    assert.ok(
      new RegExp(writeMatcher).test(tool),
      `PreToolUse[0].matcher must match '${tool}'`,
    )
  }

  // C6 — Bash matcher must catch both `Bash` (Claude) and `shell` (Codex
  // shell tool naming variant) since the same hook serves both runtimes.
  const bashMatcher = manifest.hooks.PreToolUse[1].matcher
  for (const tool of ["Bash", "shell"]) {
    assert.ok(
      new RegExp(bashMatcher).test(tool),
      `PreToolUse[1].matcher must match '${tool}'`,
    )
  }

  // C7 — author URL matches the actual GitHub user (regression guard for the
  // `rizkirr` typo previously present in both Claude and Codex manifests).
  if (manifest.author?.github) {
    assert.ok(
      /\/rizukirr\b/.test(manifest.author.github),
      `author.github must reference 'rizukirr', got: ${manifest.author.github}`,
    )
  }

  // C8 — Codex plugin add resolves through an on-repo marketplace snapshot.
  // Keep this in sync with docs (`codex plugin add no-vibe --marketplace no-vibe`).
  const marketplacePath = path.join(repoRoot, ".agents", "plugins", "marketplace.json")
  assert.ok(
    fs.existsSync(marketplacePath),
    ".agents/plugins/marketplace.json must exist for codex plugin add",
  )
  const marketplace = JSON.parse(fs.readFileSync(marketplacePath, "utf8"))
  assert.equal(
    marketplace.name,
    "no-vibe",
    "Codex marketplace snapshot name must be 'no-vibe'",
  )
  assert.ok(Array.isArray(marketplace.plugins), "marketplace.plugins must be an array")
  assert.ok(
    marketplace.plugins.some((p) => p?.name === "no-vibe"),
    "marketplace must include plugin entry named 'no-vibe'",
  )
  const noVibeEntry = marketplace.plugins.find((p) => p?.name === "no-vibe")
  assert.ok(noVibeEntry?.policy, "no-vibe marketplace entry must include policy")
  assert.ok(
    ["ON_INSTALL", "ON_USE"].includes(noVibeEntry.policy.authentication),
    "no-vibe marketplace entry policy.authentication must be ON_INSTALL or ON_USE",
  )

  console.log("ok — codex plugin parity checks pass")
}

run().catch((err) => {
  console.error(err)
  process.exit(1)
})
