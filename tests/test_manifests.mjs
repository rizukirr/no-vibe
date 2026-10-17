import assert from 'node:assert/strict'
import { spawnSync } from 'node:child_process'
import { existsSync, readFileSync } from 'node:fs'
import path from 'node:path'
import { fileURLToPath } from 'node:url'

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..')
const read = file => readFileSync(path.join(root, file), 'utf8')
const json = file => JSON.parse(read(file))

const config = json('no-vibe.config.json')
const hooks = json('hooks/hooks.json').hooks

// Codex loads hooks only from a path, never from an inline object.
assert.equal(json('.codex-plugin/plugin.json').hooks, './hooks/hooks.json')
assert.equal(json('.claude-plugin/plugin.json').hooks, undefined)

// Every hook command names a script that exists, through the wrapper.
const commands = [...hooks.PreToolUse, ...hooks.SessionStart].flatMap(group => group.hooks.map(h => h.command))
for (const command of commands) {
  assert.ok(command.includes('/hooks/run-hook.cmd'), `${command} goes through run-hook.cmd`)
  assert.ok(existsSync(path.join(root, 'hooks', command.split(' ').pop())), `${command} names an existing script`)
}
assert.ok(!commands.some(c => c.includes('validate-memory-write')), 'memory validation hook is gone')

// The matchers catch the tool names both hosts report.
const matches = tool => hooks.PreToolUse.some(group => new RegExp(`^(${group.matcher})$`).test(tool))
for (const tool of ['Edit', 'Write', 'MultiEdit', 'NotebookEdit', 'apply_patch', 'Bash']) {
  assert.ok(matches(tool), `PreToolUse matches ${tool}`)
}

// Each command skill has a Claude and a Codex command.
for (const name of ['no-vibe', 'no-vibe-btw', 'no-vibe-challenge']) {
  assert.ok(existsSync(path.join(root, `commands/${name}.md`)), `commands/${name}.md`)
  assert.ok(existsSync(path.join(root, `commands/${name}.toml`)), `commands/${name}.toml`)
}

// The wrapper runs a guard end to end: a project write is refused.
const cwd = spawnSync('mktemp', ['-d'], { encoding: 'utf8' }).stdout.trim()
spawnSync('bash', ['-c', `mkdir -p "${cwd}/.no-vibe" && touch "${cwd}/.no-vibe/active"`])
const run = spawnSync('bash', [path.join(root, 'hooks/run-hook.cmd'), 'block-writes.sh'], {
  input: JSON.stringify({ tool_name: 'Write', tool_input: { file_path: `${cwd}/a.txt` }, cwd }),
  encoding: 'utf8',
})
spawnSync('rm', ['-rf', cwd])
assert.equal(run.status, 2, 'run-hook.cmd block-writes.sh refuses a project write')

assert.equal(json('.claude-plugin/plugin.json').version, config.version)
console.log('test_manifests: ok')
