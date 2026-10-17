// runtimes/core.mjs
export const id = 'core'

// Shipped by every install. Runtime-specific paths come from each emitter's
// ships(), so a runtime's files are listed where the runtime is defined.
const FILES = [
  'AGENTS.md',
  'INSTALL.codex.md',
  'INSTALL.pi.md',
  'LICENSE',
  'README.md',
  'commands/',
  'hooks/',
  'skills/',
  '.claude-plugin/',
  '.codex-plugin/',
  'GEMINI.md',
  'INSTALL.gemini.md',
  'gemini-extension.json',
  '.gemini/',
]

export function emit(model) {
  const { config } = model
  const { pkg: contributed = {}, ships = [] } = model.contributions ?? {}
  const pkg = {
    name: config.name,
    version: config.version,
    description: config.description,
    type: config.npm.type,
    license: config.license,
    author: config.author,
    homepage: config.homepage,
    repository: { type: 'git', url: `git+${config.repository}.git` },
    bugs: { url: `${config.repository}/issues` },
    keywords: config.keywords,
    engines: config.npm.engines,
    scripts: config.npm.scripts,
    files: [...new Set([...FILES, ...ships])].sort(),
    ...contributed,
  }
  return { 'package.json': `${JSON.stringify(pkg, null, 2)}\n` }
}

export function commandTable(skills) {
  return [
    '| Command | Effect |',
    '|---|---|',
    ...skills
      .filter(skill => skill.command)
      .map(skill => `| \`/${skill.name}${skill.hint ? ` ${skill.hint}` : ''}\` | ${skill.description.replace(/\|/g, '\\|')} |`),
  ].join('\n')
}

export function regions(model) {
  return { 'README.md': { commands: commandTable(model.skills) } }
}
