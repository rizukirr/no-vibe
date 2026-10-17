import assert from 'node:assert/strict'
import { spawnSync } from 'node:child_process'
import { mkdtempSync, mkdirSync, writeFileSync, rmSync } from 'node:fs'
import path from 'node:path'
import { fileURLToPath } from 'node:url'

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..')

// One intent per case, expressed per runtime. `allow` is the decision every
// runtime must reach while .no-vibe/active exists.
const CASES = [
  { name: 'write a project file', allow: false, kind: 'write', rel: 'src/main.rs' },
  { name: 'write inside .no-vibe', allow: true, kind: 'write', rel: '.no-vibe/syllabus.md' },
  { name: 'shell redirect into the project', allow: false, kind: 'shell', command: 'echo hi > src/main.rs' },
  { name: 'shell redirect into /tmp', allow: true, kind: 'shell', command: 'echo hi > /tmp/no-vibe-parity.txt' },
  { name: 'read-only shell', allow: true, kind: 'shell', command: 'ls -la' },
  { name: 'patch adding a project file', allow: false, kind: 'patch', rel: 'src/new.rs' },
  { name: 'patch adding a .no-vibe file', allow: true, kind: 'patch', rel: '.no-vibe/notes.md' },
]

const patchText = rel => `*** Begin Patch\n*** Add File: ${rel}\n+hello\n*** End Patch`

function project(active) {
  // Not under /tmp: the shell guard allows every path below it.
  const dir = mkdtempSync(path.join(root, '.parity-'))
  if (active) {
    mkdirSync(path.join(dir, '.no-vibe'))
    writeFileSync(path.join(dir, '.no-vibe', 'active'), '')
  }
  return dir
}

// Claude Code and Codex run the shell hooks through run-hook.cmd.
function claude(c, cwd) {
  const [script, payload] =
    c.kind === 'write' ? ['block-writes.sh', { tool_name: 'Write', tool_input: { file_path: path.join(cwd, c.rel) } }]
    : c.kind === 'patch' ? ['block-writes.sh', { tool_name: 'apply_patch', tool_input: { command: patchText(c.rel) } }]
    : ['block-bash-writes.sh', { tool_name: 'Bash', tool_input: { command: c.command } }]
  const result = spawnSync('bash', [path.join(root, 'hooks/run-hook.cmd'), script], {
    input: JSON.stringify({ ...payload, cwd }),
    encoding: 'utf8',
  })
  return result.status === 0
}

async function loadOpencode() {
  const { default: plugin } = await import(path.join(root, '.opencode/plugins/no-vibe.js'))
  const hooks = {}
  await plugin.setup({
    skill: { transform: async fn => fn({ add: () => {} }) },
    tool: { hook: async (name, fn) => { hooks[`tool:${name}`] = fn } },
    session: { hook: async (name, fn) => { hooks[`session:${name}`] = fn } },
  })
  return hooks
}

async function opencode(hooks, c, cwd) {
  const ev =
    c.kind === 'write' ? { tool: 'write', input: { path: path.join(cwd, c.rel), content: 'x' } }
    : c.kind === 'patch' ? { tool: 'patch', input: { patchText: patchText(c.rel) } }
    : { tool: 'shell', input: { command: c.command } }
  const before = process.cwd()
  process.chdir(cwd)
  try {
    await hooks['tool:execute.before'](ev)
    return true
  } catch {
    return false
  } finally {
    process.chdir(before)
  }
}

const oc = await loadOpencode()

for (const c of CASES) {
  const cwd = project(true)
  const decisions = { claude: claude(c, cwd), opencode: await opencode(oc, c, cwd) }
  rmSync(cwd, { recursive: true, force: true })
  for (const [runtime, allowed] of Object.entries(decisions)) {
    assert.equal(allowed, c.allow, `${runtime}: ${c.name}`)
  }
}

// Without the marker every runtime allows a project write.
{
  const cwd = project(false)
  assert.equal(claude(CASES[0], cwd), true, 'claude: no marker allows')
  assert.equal(await opencode(oc, CASES[0], cwd), true, 'opencode: no marker allows')
  rmSync(cwd, { recursive: true, force: true })
}

// Without bash the opencode guard refuses while active, even a safe write.
{
  const cwd = project(true)
  const saved = process.env.PATH
  process.env.PATH = ''
  try {
    assert.equal(await opencode(oc, CASES[1], cwd), false, 'opencode: no bash refuses')
  } finally {
    process.env.PATH = saved
  }
  rmSync(cwd, { recursive: true, force: true })
}

// The context hook injects the status line.
{
  const cwd = project(true)
  const before = process.cwd()
  process.chdir(cwd)
  const ev = { sessionID: 'parity', system: [] }
  try {
    await oc['session:context'](ev)
  } finally {
    process.chdir(before)
  }
  rmSync(cwd, { recursive: true, force: true })
  assert.deepEqual(ev.system, [{ type: 'text', text: 'no-vibe: ON' }], 'opencode: status injected')
}

console.log('test_guard_parity: ok')
