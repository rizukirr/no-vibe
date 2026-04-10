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
    ;({ NoVibePlugin } = await import("../.opencode/plugins/no-vibe.js"))
  } catch (err) {
    throw new Error("failed to import OpenCode no-vibe plugin module", { cause: err })
  }

  const plugin = await NoVibePlugin({ directory: repoRoot })

  const config = {}
  await plugin.config(config)
  assert.ok(config.skills?.paths?.length, "skills paths should be populated")
  assert.ok(
    config.skills.paths.some((p) => path.resolve(p) === skillsDir),
    "skills path should include repository skills dir",
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

  console.log("PASS test_opencode_plugin bootstrap/config")
}

run().catch((err) => {
  console.error("FAIL test_opencode_plugin bootstrap/config")
  console.error(err)
  process.exit(1)
})
