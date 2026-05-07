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
    first.text.includes("Iron Law") && first.text.includes("PROFILE.md"),
    "bootstrap should include skill body (Iron Law) and reference PROFILE.md",
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

  // --- Test: status line surfaces resume hint for in-progress session ---
  const resumeDir = fs.mkdtempSync(path.join(os.tmpdir(), "no-vibe-resume-"))
  fs.mkdirSync(path.join(resumeDir, ".no-vibe", "data", "sessions"), { recursive: true })
  fs.writeFileSync(path.join(resumeDir, ".no-vibe", "active"), "")
  fs.writeFileSync(
    path.join(resumeDir, ".no-vibe", "data", "sessions", "build-a-linear-layer.json"),
    JSON.stringify({
      topic: "Build a Linear Layer",
      status: "in_progress",
      current_layer: 3,
      layers_total: 7,
      current_phase: "phase3",
    }),
  )
  const resumePlugin = await NoVibePlugin({ directory: resumeDir })
  const resumeOutput = makeOutput()
  await resumePlugin["experimental.chat.messages.transform"]({}, resumeOutput)
  const resumeText = resumeOutput.messages[0].parts[0].text
  assert.ok(
    resumeText.startsWith('no-vibe: ON — resuming "Build a Linear Layer" (layer 3/7, phase3)'),
    `status line should surface resume hint; got: ${resumeText.slice(0, 120)}`,
  )

  // Completed sessions should NOT trigger the resume hint
  fs.writeFileSync(
    path.join(resumeDir, ".no-vibe", "data", "sessions", "build-a-linear-layer.json"),
    JSON.stringify({ topic: "Build a Linear Layer", status: "completed" }),
  )
  const completedPlugin = await NoVibePlugin({ directory: resumeDir })
  const completedOutput = makeOutput()
  await completedPlugin["experimental.chat.messages.transform"]({}, completedOutput)
  const completedText = completedOutput.messages[0].parts[0].text
  assert.ok(
    completedText.startsWith("no-vibe: ON\n") || completedText.startsWith("no-vibe: ON\r\n") ||
      completedText === "no-vibe: ON" || completedText.match(/^no-vibe: ON(?!\s*—)/),
    `completed-only sessions should not surface resume hint; got: ${completedText.slice(0, 120)}`,
  )
  fs.rmSync(resumeDir, { recursive: true, force: true })

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

  // --- Test: PROFILE.md + user/ directory injection model ---
  const adaptationCwd = fs.mkdtempSync(path.join(os.tmpdir(), "no-vibe-adaptation-"))
  fs.mkdirSync(path.join(adaptationCwd, ".no-vibe"), { recursive: true })
  fs.writeFileSync(path.join(adaptationCwd, ".no-vibe", "active"), "")

  // Isolate $HOME so the dev machine's real ~/.no-vibe files don't bleed in.
  const fakeHome = fs.mkdtempSync(path.join(os.tmpdir(), "no-vibe-home-"))
  const realHome = process.env.HOME
  const realUserProfile = process.env.USERPROFILE
  process.env.HOME = fakeHome
  process.env.USERPROFILE = fakeHome

  try {
    // ----- Phase A: PROFILE.md / SUMMARY.md absent, user/ absent -----
    const phaseAplugin = await NoVibePlugin({ directory: adaptationCwd })
    const phaseAoutput = makeOutput()
    await phaseAplugin["experimental.chat.messages.transform"]({}, phaseAoutput)
    const phaseAtext = phaseAoutput.messages[0].parts[0].text
    assert.ok(phaseAtext.includes("## Background Memory"), "Background Memory preamble emitted")
    assert.ok(phaseAtext.includes("Use this memory sparingly"), "use-sparingly preamble emitted")
    assert.ok(phaseAtext.includes("GLOBAL PROFILE"), "global PROFILE section labeled when absent")
    assert.ok(phaseAtext.includes("PROJECT SUMMARY"), "project SUMMARY section labeled when absent")
    assert.ok(phaseAtext.includes("PROFILE.md missing"), "PROFILE.md placeholder used when file absent")
    assert.ok(phaseAtext.includes("SUMMARY.md not yet created"), "SUMMARY.md placeholder used when file absent")
    assert.ok(phaseAtext.includes("GLOBAL USER OVERRIDES"), "global user/ section labeled when absent")
    assert.ok(phaseAtext.includes("PROJECT USER OVERRIDES"), "project user/ section labeled when absent")
    assert.ok(phaseAtext.includes("No user-authored override files"), "user/ placeholder used when dir absent")

    // Plugin must NOT create PROFILE.md, SUMMARY.md, or user/ — those are AI's / user's job
    assert.ok(
      !fs.existsSync(path.join(adaptationCwd, ".no-vibe", "SUMMARY.md")),
      "plugin must not create project SUMMARY.md",
    )
    assert.ok(
      !fs.existsSync(path.join(fakeHome, ".no-vibe", "PROFILE.md")),
      "plugin must not create global PROFILE.md",
    )
    assert.ok(
      !fs.existsSync(path.join(adaptationCwd, ".no-vibe", "user")),
      "plugin must not create project user/ dir",
    )
    assert.ok(
      !fs.existsSync(path.join(fakeHome, ".no-vibe", "user")),
      "plugin must not create global user/ dir",
    )

    // ----- Phase B: PROFILE.md (global) + SUMMARY.md (project) present -----
    fs.mkdirSync(path.join(fakeHome, ".no-vibe"), { recursive: true })
    fs.writeFileSync(
      path.join(fakeHome, ".no-vibe", "PROFILE.md"),
      "# PROFILE — global\n## Identity & expertise\n- CS background, Rust solid (seen 4×)\n",
    )
    fs.writeFileSync(
      path.join(adaptationCwd, ".no-vibe", "SUMMARY.md"),
      "# SUMMARY — project\n## Accomplishments\n- async-rust layer 3/5 Clear\n",
    )
    const phaseBplugin = await NoVibePlugin({ directory: adaptationCwd })
    const phaseBoutput = makeOutput()
    await phaseBplugin["experimental.chat.messages.transform"]({}, phaseBoutput)
    const phaseBtext = phaseBoutput.messages[0].parts[0].text
    assert.ok(phaseBtext.includes("CS background, Rust solid"), "global PROFILE.md content injected when present")
    assert.ok(phaseBtext.includes("async-rust layer 3/5"), "project SUMMARY.md content injected when present")

    // ----- Phase C: user/*.md loaded, sorted, .md only -----
    fs.mkdirSync(path.join(fakeHome, ".no-vibe", "user"), { recursive: true })
    fs.mkdirSync(path.join(adaptationCwd, ".no-vibe", "user"), { recursive: true })
    fs.writeFileSync(
      path.join(fakeHome, ".no-vibe", "user", "a-style.md"),
      "- skip 12-year-old framing — CS background\n",
    )
    fs.writeFileSync(
      path.join(fakeHome, ".no-vibe", "user", "b-extra.md"),
      "- prefer mechanism over analogy\n",
    )
    fs.writeFileSync(
      path.join(fakeHome, ".no-vibe", "user", "notes.txt"),
      "this should not appear in output",
    )
    fs.writeFileSync(
      path.join(adaptationCwd, ".no-vibe", "user", "conventions.md"),
      "- this project uses tabs, not spaces\n",
    )
    const phaseCplugin = await NoVibePlugin({ directory: adaptationCwd })
    const phaseCoutput = makeOutput()
    await phaseCplugin["experimental.chat.messages.transform"]({}, phaseCoutput)
    const phaseCtext = phaseCoutput.messages[0].parts[0].text
    assert.ok(
      phaseCtext.includes("skip 12-year-old framing"),
      "first global user/*.md content should be injected",
    )
    assert.ok(
      phaseCtext.includes("prefer mechanism over analogy"),
      "second global user/*.md content should be injected",
    )
    assert.ok(
      phaseCtext.includes("this project uses tabs"),
      "project user/*.md content should be injected",
    )
    assert.ok(
      !phaseCtext.includes("this should not appear"),
      "non-.md files in user/ must be ignored",
    )
    // Sort order: a-style.md before b-extra.md
    const posA = phaseCtext.indexOf("skip 12-year-old framing")
    const posB = phaseCtext.indexOf("prefer mechanism over analogy")
    assert.ok(posA >= 0 && posB >= 0 && posA < posB, "user/*.md files loaded in sorted filename order")
  } finally {
    if (realHome === undefined) delete process.env.HOME
    else process.env.HOME = realHome
    if (realUserProfile === undefined) delete process.env.USERPROFILE
    else process.env.USERPROFILE = realUserProfile
    fs.rmSync(adaptationCwd, { recursive: true, force: true })
    fs.rmSync(fakeHome, { recursive: true, force: true })
  }

  console.log("PASS test_opencode_plugin bootstrap/config")
}

run().catch((err) => {
  console.error("FAIL test_opencode_plugin bootstrap/config")
  console.error(err)
  process.exit(1)
})
