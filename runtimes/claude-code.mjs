// runtimes/claude-code.mjs
export const id = 'claude-code'

import { json, markdownCommand } from '../lib/emit.mjs'

// One hook entry per script, all through the polyglot wrapper so Windows runs
// them too. Codex reads the same file and reports its tools as apply_patch
// and Bash, so one matcher set serves both hosts.
const hook = script => ({
  type: 'command',
  command: `"\${CLAUDE_PLUGIN_ROOT}/hooks/run-hook.cmd" ${script}`,
  shell: 'bash',
  async: false,
})

export function hooksFile() {
  return {
    hooks: {
      PreToolUse: [
        { matcher: 'Edit|Write|NotebookEdit|MultiEdit|apply_patch', hooks: [hook('block-writes.sh')] },
        { matcher: 'Bash', hooks: [hook('block-bash-writes.sh')] },
      ],
      SessionStart: [
        { matcher: 'startup|clear|compact', hooks: [hook('status.sh')] },
      ],
    },
  }
}

export function emit(model) {
  const { config, skills } = model
  const files = {
    '.claude-plugin/plugin.json': json({
      name: config.name,
      description: config.description,
      version: config.version,
      author: config.author,
      homepage: config.homepage,
      repository: config.repository,
      license: config.license,
      keywords: config.keywords,
    }),
    '.claude-plugin/marketplace.json': json({
      $schema: 'https://anthropic.com/claude-code/marketplace.schema.json',
      name: config.name,
      description: config.description,
      owner: { name: config.author.name },
      plugins: [{
        name: config.name,
        description: config.description,
        version: config.version,
        author: { name: config.author.name },
        source: './',
        category: 'learning',
        homepage: config.homepage,
        tags: ['learning', 'tutor', 'no-vibe-coding', 'education'],
      }],
    }),
    'hooks/hooks.json': json(hooksFile()),
  }
  for (const skill of skills.filter(s => s.command)) {
    files[`commands/${skill.name}.md`] = markdownCommand(skill)
  }
  return files
}

export function ships() {
  return ['.claude-plugin/']
}
