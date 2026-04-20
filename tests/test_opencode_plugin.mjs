import assert from "node:assert/strict"
import fs from "node:fs"
import os from "node:os"
import path from "node:path"
import { fileURLToPath } from "node:url"

const __dirname = path.dirname(fileURLToPath(import.meta.url))
const repoRoot = path.resolve(__dirname, "..")
const skillsDir = path.join(repoRoot, "skills")

const makeOutput = () => ({
  messages: [
    {
      info: { role: "user" },
      parts: [{ type: "text", text: "Teach me linear layers" }],
    },
  ],
})

const run = async () => {
  let NoVibePlugin
  try {
    ;({ default: NoVibePlugin } = await import("../index.js"))
  } catch (err) {
    throw new Error("failed to import OpenCode no-vibe plugin module", { cause: err })
  }

  const fakeProjectDir = fs.mkdtempSync(path.join(os.tmpdir(), "no-vibe-plugin-project-"))
  const plugin = await NoVibePlugin({ directory: fakeProjectDir })

  const config = {}
  await plugin.config(config)
  assert.ok(config.skills?.paths?.length, "skills paths should be populated")
  assert.ok(
    config.skills.paths.some((p) => path.resolve(p) === skillsDir),
    "skills path should include plugin-bundled skills dir",
  )

  assert.ok(
    !config.skills.paths.some((p) => path.resolve(p) === path.join(fakeProjectDir, "skills")),
    "skills path should not depend on current project directory",
  )

  const output = makeOutput()
  const originalPartsCount = output.messages[0].parts.length
  await plugin["experimental.chat.messages.transform"]({}, output)

  const first = output.messages[0].parts[0]
  assert.equal(first.type, "text")
  assert.equal(
    output.messages[0].parts.length,
    originalPartsCount + 1,
    "bootstrap should prepend one text part",
  )
  assert.notEqual(first.text, "Teach me linear layers", "first text part should be injected bootstrap")
  assert.ok(first.text.includes("no-vibe"), "bootstrap should mention no-vibe")
  assert.ok(first.text.includes("OpenCode"), "bootstrap should mention OpenCode")
  assert.ok(
    first.text.includes("Data Schema") || first.text.includes("DATA-SCHEMA") || first.text.includes("profile.json"),
    "bootstrap should include data schema content",
  )
  assert.ok(
    !first.text.startsWith("no-vibe: ON") && !first.text.startsWith("no-vibe: OFF"),
    "status line should be absent when project has no .no-vibe/ dir",
  )

  // Status line present when .no-vibe/ exists
  const optedInDir = fs.mkdtempSync(path.join(os.tmpdir(), "no-vibe-optedin-"))
  fs.mkdirSync(path.join(optedInDir, ".no-vibe"), { recursive: true })
  const optedInPlugin = await NoVibePlugin({ directory: optedInDir })
  const onOutput = makeOutput()
  fs.writeFileSync(path.join(optedInDir, ".no-vibe", "active"), "")
  await optedInPlugin["experimental.chat.messages.transform"]({}, onOutput)
  assert.ok(
    onOutput.messages[0].parts[0].text.startsWith("no-vibe: ON"),
    "status line should read ON when marker exists",
  )

  const offOutput = makeOutput()
  fs.rmSync(path.join(optedInDir, ".no-vibe", "active"))
  const offPlugin = await NoVibePlugin({ directory: optedInDir })
  await offPlugin["experimental.chat.messages.transform"]({}, offOutput)
  assert.ok(
    offOutput.messages[0].parts[0].text.startsWith("no-vibe: OFF"),
    "status line should read OFF when dir exists but marker missing",
  )
  fs.rmSync(optedInDir, { recursive: true, force: true })

  const tempCwd = fs.mkdtempSync(path.join(os.tmpdir(), "no-vibe-write-guard-"))
  const markerDir = path.join(tempCwd, ".no-vibe")
  const markerPath = path.join(markerDir, "active")

  fs.mkdirSync(path.join(markerDir, "notes"), { recursive: true })
  fs.writeFileSync(markerPath, "")

  try {
    let deniedError = null
    try {
      await plugin["tool.execute.before"](
        { tool: "write", cwd: tempCwd, args: { filePath: "src/app.js" } },
        { args: { filePath: "src/app.js" } },
      )
    } catch (err) {
      deniedError = err
    }

    assert.ok(deniedError, "write outside .no-vibe should be blocked")
    assert.match(
      String(deniedError.message || deniedError),
      /no-vibe|refusing write/i,
      "blocked write should return a guard-related error",
    )

    await plugin["tool.execute.before"](
      { tool: "write", cwd: tempCwd, args: { filePath: ".no-vibe/notes/session.md" } },
      { args: { filePath: ".no-vibe/notes/session.md" } },
    )
  } finally {
    fs.rmSync(tempCwd, { recursive: true, force: true })
  }

  // --- Test: write to .no-vibe/data/ is allowed ---
  const tempCwd2 = fs.mkdtempSync(path.join(os.tmpdir(), "no-vibe-data-write-"))
  const markerDir2 = path.join(tempCwd2, ".no-vibe")
  fs.mkdirSync(path.join(markerDir2, "data", "sessions"), { recursive: true })
  fs.writeFileSync(path.join(markerDir2, "active"), "")

  try {
    await plugin["tool.execute.before"](
      { tool: "write", cwd: tempCwd2, args: { filePath: ".no-vibe/data/profile.json" } },
      { args: { filePath: ".no-vibe/data/profile.json" } },
    )
  } finally {
    fs.rmSync(tempCwd2, { recursive: true, force: true })
  }

  fs.rmSync(fakeProjectDir, { recursive: true, force: true })

  console.log("PASS test_opencode_plugin bootstrap/config")
}

run().catch((err) => {
  console.error("FAIL test_opencode_plugin bootstrap/config")
  console.error(err)
  process.exit(1)
})
