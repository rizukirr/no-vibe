// lib/model.mjs
import { readdirSync, readFileSync } from 'node:fs'
import { join } from 'node:path'
import { parseFrontmatter } from './frontmatter.mjs'

// Skills are discovered from skills/*/SKILL.md. There is no skill list
// anywhere else, so an emitter cannot forget one.
export function buildModel(config, skillsDir) {
  const dirs = readdirSync(skillsDir, { withFileTypes: true })
    .filter(entry => entry.isDirectory())
    .map(entry => entry.name)
    .sort()

  const skills = dirs.map(dir => {
    let data
    try {
      ({ data } = parseFrontmatter(readFileSync(join(skillsDir, dir, 'SKILL.md'), 'utf8')))
    } catch (error) {
      throw new Error(`${dir}: ${error.message}`)
    }
    if (data.name !== dir) {
      throw new Error(`${dir}: frontmatter name '${data.name}' does not match directory`)
    }
    if (typeof data.description !== 'string' || data.description.trim() === '') {
      throw new Error(`${dir}: frontmatter 'description' is required`)
    }
    if (data.command !== undefined && typeof data.command !== 'boolean') {
      throw new Error(`${dir}: 'command' must be true or false`)
    }
    return {
      name: data.name,
      description: data.description,
      hint: typeof data['argument-hint'] === 'string' ? data['argument-hint'] : '',
      command: data.command === true,
    }
  })

  return { config, skills }
}
