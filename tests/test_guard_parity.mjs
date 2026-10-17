import assert from 'node:assert/strict'
import { spawnSync } from 'node:child_process'
import { mkdtempSync, mkdirSync, writeFileSync, rmSync, symlinkSync } from 'node:fs'
import os from 'node:os'
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

async function loadOpencode(location) {
  const { default: plugin } = await import(path.join(root, '.opencode/plugins/no-vibe.js'))
  const hooks = {}
  await plugin.setup({
    location,
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

async function loadPi() {
  const { default: register } = await import(path.join(root, '.pi-plugin/extensions/no-vibe/index.ts'))
  const handlers = {}
  register({ on: (name, fn) => { handlers[name] = fn } })
  return handlers
}

// Pi has no patch tool, so patch cases do not apply to it.
async function pi(handlers, c, cwd) {
  if (c.kind === 'patch') return c.allow
  const event = c.kind === 'write'
    ? { toolName: 'write', input: { path: path.join(cwd, c.rel), content: 'x' } }
    : { toolName: 'bash', input: { command: c.command } }
  const result = await handlers.tool_call(event, { cwd })
  return !result?.block
}

// Antigravity has no patch tool, so patch cases do not apply to it.
function agy(c, cwd) {
  if (c.kind === 'patch') return c.allow
  const toolCall = c.kind === 'write'
    ? { name: 'write_to_file', args: { TargetFile: path.join(cwd, c.rel), CodeContent: 'x' } }
    : { name: 'run_command', args: { CommandLine: c.command, Cwd: cwd } }
  const result = spawnSync('bash', [path.join(root, 'hooks/run-hook.cmd'), 'agy-guard.sh'], {
    input: JSON.stringify({ toolCall, workspacePaths: [cwd] }),
    encoding: 'utf8',
  })
  return JSON.parse(result.stdout).decision === 'allow'
}

const oc = await loadOpencode()
const piHandlers = await loadPi()

for (const c of CASES) {
  const cwd = project(true)
  const decisions = {
    claude: claude(c, cwd),
    opencode: await opencode(oc, c, cwd),
    pi: await pi(piHandlers, c, cwd),
    agy: agy(c, cwd),
  }
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

// Pi: no marker allows, PowerShell is refused while active, status is injected.
{
  const cwd = project(false)
  assert.equal(await pi(piHandlers, CASES[0], cwd), true, 'pi: no marker allows')
  rmSync(cwd, { recursive: true, force: true })
}
{
  const cwd = project(true)
  const result = await piHandlers.tool_call({ toolName: 'powershell', input: { command: 'ls' } }, { cwd })
  assert.equal(result?.block, true, 'pi: powershell refused')
  const started = await piHandlers.before_agent_start({ systemPrompt: 'base' }, { cwd })
  assert.equal(started?.systemPrompt, 'base\n\nno-vibe: ON', 'pi: status injected')
  rmSync(cwd, { recursive: true, force: true })
}

// opencode under the background service: process cwd is not the project, the
// project comes from ctx.location.directory.
{
  const cwd = project(true)
  const hooks = await loadOpencode({ directory: cwd })
  const before = process.cwd()
  process.chdir(os.homedir())
  try {
    const ev = { tool: 'write', input: { path: path.join(cwd, 'src/main.rs'), content: 'x' } }
    await assert.rejects(async () => hooks['tool:execute.before'](ev), /no-vibe/, 'opencode: project dir from ctx.location')
  } finally {
    process.chdir(before)
  }
  rmSync(cwd, { recursive: true, force: true })
}

// Pi loaded through a symlinked extension dir, as in INSTALL.pi.md Option C.
// Pi's loader keeps the symlink path in import.meta.url. Node realpaths
// imports unless --preserve-symlinks, so the import runs in a child.
{
  const cwd = project(true)
  const link = mkdtempSync(path.join(os.tmpdir(), 'no-vibe-pisym-'))
  symlinkSync(path.join(root, '.pi-plugin/extensions/no-vibe'), path.join(link, 'no-vibe'))
  const script = `
    const { default: register } = await import(${JSON.stringify(path.join(link, 'no-vibe', 'index.ts'))})
    const h = {}
    register({ on: (name, fn) => { h[name] = fn } })
    const cwd = ${JSON.stringify(cwd)}
    const allowed = async rel => !(await h.tool_call({ toolName: 'write', input: { path: cwd + '/' + rel, content: 'x' } }, { cwd }))?.block
    console.log(JSON.stringify([await allowed('.no-vibe/notes.md'), await allowed('src/main.rs')]))
  `
  const result = spawnSync(process.execPath, ['--preserve-symlinks', '--input-type=module', '-e', script], { encoding: 'utf8' })
  rmSync(link, { recursive: true, force: true })
  rmSync(cwd, { recursive: true, force: true })
  assert.deepEqual(JSON.parse(result.stdout), [true, false], `pi symlink: allow .no-vibe, refuse project\n${result.stderr}`)
}

console.log('test_guard_parity: ok')
