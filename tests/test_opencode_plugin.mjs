import assert from "node:assert/strict"
import fs from "node:fs"
import os from "node:os"
import path from "node:path"
import { fileURLToPath } from "node:url"

const __dirname = path.dirname(fileURLToPath(import.meta.url))
const repoRoot = path.resolve(__dirname, "..")
const skillsDir = path.join(repoRoot, "shared", "skill")

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

  // --- config: skills path points at shared/skill ---
  const config = {}
  await plugin.config(config)
  assert.ok(config.skills?.paths?.length, "skills paths should be populated")
  assert.ok(
    config.skills.paths.some((p) => path.resolve(p) === skillsDir),
    "skills path should include shared/skill",
  )

  // --- bootstrap injection in absence of .no-vibe/ → no status line ---
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
  assert.ok(first.text.includes("OpenCode"), "bootstrap should mention OpenCode tool mapping")
  assert.ok(
    first.text.includes("NO-VIBE.md") || first.text.includes("Iron Law"),
    "bootstrap should include v2 skill body (NO-VIBE.md memory or Iron Law)",
  )
  assert.ok(
    !first.text.includes("DATA-SCHEMA"),
    "bootstrap must NOT reference v1 DATA-SCHEMA (deleted in v2)",
  )
  assert.ok(
    !first.text.startsWith("no-vibe: ON") && !first.text.startsWith("no-vibe: OFF"),
    "status line absent when project has no .no-vibe/ dir",
  )

  // --- Status line present when .no-vibe/ exists ---
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

  // --- Resume hint sourced from session.md curriculum ---
  const resumeDir = fs.mkdtempSync(path.join(os.tmpdir(), "no-vibe-resume-"))
  fs.mkdirSync(path.join(resumeDir, ".no-vibe"), { recursive: true })
  fs.writeFileSync(path.join(resumeDir, ".no-vibe", "active"), "")
  fs.writeFileSync(
    path.join(resumeDir, ".no-vibe", "session.md"),
    `# Lesson: Build a Linear Layer
Mode: concept

## Curriculum
- [x] 1. Skeleton
- [x] 2. Forward
- [x] 3. Bias
- [ ] 4. Activation
- [ ] 5. Backward
- [ ] 6. Compare
- [ ] 7. Synth
`,
  )
  const resumePlugin = await NoVibePlugin({ directory: resumeDir })
  const resumeOutput = makeOutput()
  await resumePlugin["experimental.chat.messages.transform"]({}, resumeOutput)
  const resumeText = resumeOutput.messages[0].parts[0].text
  assert.ok(
    resumeText.startsWith('no-vibe: ON — resuming "Build a Linear Layer" (3/7 layers complete)'),
    `status line should surface curriculum-based resume hint; got: ${resumeText.slice(0, 120)}`,
  )

  // Fully-checked curriculum → no resume hint
  fs.writeFileSync(
    path.join(resumeDir, ".no-vibe", "session.md"),
    `# Lesson: Done
## Curriculum
- [x] 1. step
- [x] 2. step
`,
  )
  const completedPlugin = await NoVibePlugin({ directory: resumeDir })
  const completedOutput = makeOutput()
  await completedPlugin["experimental.chat.messages.transform"]({}, completedOutput)
  const completedText = completedOutput.messages[0].parts[0].text
  assert.ok(
    completedText.match(/^no-vibe: ON(?!\s*—)/),
    `fully-complete curriculum should not surface resume hint; got: ${completedText.slice(0, 120)}`,
  )
  fs.rmSync(resumeDir, { recursive: true, force: true })

  // --- Write guard: outside .no-vibe is blocked ---
  const tempCwd = fs.mkdtempSync(path.join(os.tmpdir(), "no-vibe-write-guard-"))
  const markerDir = path.join(tempCwd, ".no-vibe")
  fs.mkdirSync(path.join(markerDir, "memory"), { recursive: true })
  fs.writeFileSync(path.join(markerDir, "active"), "")

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
      /no-vibe|cannot write/i,
      "blocked write should return a guard-related error",
    )

    // --- Write inside .no-vibe is allowed ---
    await plugin["tool.execute.before"](
      { tool: "write", cwd: tempCwd, args: { filePath: ".no-vibe/NO-VIBE.md" } },
      { args: { filePath: ".no-vibe/NO-VIBE.md" } },
    )
    await plugin["tool.execute.before"](
      { tool: "write", cwd: tempCwd, args: { filePath: ".no-vibe/memory/NO-VIBE-2026-01-01.md" } },
      { args: { filePath: ".no-vibe/memory/NO-VIBE-2026-01-01.md" } },
    )
  } finally {
    fs.rmSync(tempCwd, { recursive: true, force: true })
  }

  fs.rmSync(fakeProjectDir, { recursive: true, force: true })

  console.log("ok — opencode plugin v2 bootstrap/config/guard")
}

run().catch((err) => {
  console.error("FAIL test_opencode_plugin")
  console.error(err)
  process.exit(1)
})
