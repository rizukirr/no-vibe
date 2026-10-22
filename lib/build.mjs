// lib/build.mjs
import { readFileSync } from 'node:fs'
import { join } from 'node:path'
import { buildModel } from './model.mjs'
import { applyRegion } from './markers.mjs'

export const MANIFEST = '.no-vibe-manifest'

// Merges each emitter's path→contents map. Two emitters claiming one path is an
// error rather than last-write-wins: a silent overwrite is precisely the kind of
// drift this generator exists to prevent.
export function mergeEmitters(emitters, model) {
  const files = {}
  const owner = {}
  for (const emitter of emitters) {
    for (const [path, contents] of Object.entries(emitter.emit(model))) {
      if (path in files) {
        throw new Error(`'${path}' emitted by both '${owner[path]}' and '${emitter.id}'`)
      }
      files[path] = contents
      owner[path] = emitter.id
    }
  }
  return { files, owner }
}

// The second merge point. `emit` returns files; `pkg` and `ships` return
// fragments of a file another emitter owns, which the path-collision rule
// cannot express. Same discipline: a key claimed twice is an error, because a
// silent overwrite is the drift this generator exists to prevent.
export function mergeContributions(emitters, model) {
  const pkg = {}
  const owner = {}
  const ships = new Set()
  for (const emitter of emitters) {
    for (const [key, value] of Object.entries(emitter.pkg?.(model) ?? {})) {
      if (key in pkg) {
        throw new Error(`'${key}' contributed by both '${owner[key]}' and '${emitter.id}'`)
      }
      pkg[key] = value
      owner[key] = emitter.id
    }
    for (const path of emitter.ships?.(model) ?? []) ships.add(path)
  }
  return { pkg, ships: [...ships].sort() }
}

// Mutates `files` in place. No return value: an ignored return reads like the
// caller has a choice, and it does not.
export function applyRegions(emitters, model, files, owner, io) {
  for (const emitter of emitters) {
    if (!emitter.regions) continue
    for (const [path, regions] of Object.entries(emitter.regions(model))) {
      if (path in files) {
        throw new Error(`'${path}' is claimed by both '${owner[path]}' and '${emitter.id}'`)
      }
      let text = io.read(path)
      if (text === null) throw new Error(`'${path}' has a generated region but does not exist`)
      for (const [id, content] of Object.entries(regions)) text = applyRegion(text, id, content)
      files[path] = text
      owner[path] = emitter.id
    }
  }
}

// Compares the in-memory map against disk. `previous` is the manifest from the
// last run; only paths it lists are eligible for removal, so the generator can
// never delete a file it did not create.
export function planChanges(files, io, previous) {
  const write = []
  for (const [path, contents] of Object.entries(files)) {
    if (io.read(path) !== contents) write.push(path)
  }
  const emitted = new Set(Object.keys(files))
  const remove = previous.filter(path => !emitted.has(path))
  return { write, remove }
}

// Default filesystem reader. Returns null for a missing file rather than
// throwing, because "absent" and "different" are the same case to planChanges.
export function fsReader(root) {
  return {
    read(path) {
      try { return readFileSync(join(root, path), 'utf8') } catch { return null }
    },
  }
}

async function loadEmitters(config) {
  const emitters = []
  for (const id of ['core', ...config.runtimes]) {
    let module
    try {
      module = await import(new URL(`../runtimes/${id}.mjs`, import.meta.url))
    } catch (error) {
      throw new Error(`runtimes/${id}.mjs could not be loaded: ${error.message}`)
    }
    if (module.id !== id) throw new Error(`runtimes/${id}.mjs exports id '${module.id}'`)
    emitters.push(module)
  }
  return emitters
}

// The whole assembly, so the sequencing is under test rather than living in the
// CLI. The CLI is left with argument parsing and writing.
export async function build(root, io = fsReader(root)) {
  const config = JSON.parse(readFileSync(join(root, 'no-vibe.config.json'), 'utf8'))
  const model = buildModel(config, join(root, 'skills'))
  const emitters = await loadEmitters(config)

  model.contributions = mergeContributions(emitters, model)
  const { files, owner } = mergeEmitters(emitters, model)
  applyRegions(emitters, model, files, owner, io)

  const previous = (io.read(MANIFEST) ?? '').split('\n').filter(Boolean)
  // The manifest lists itself: it is a generated file, and a manifest that
  // omits one is a manifest you cannot trust to be complete.
  files[MANIFEST] = `${[...Object.keys(files), MANIFEST].sort().join('\n')}\n`

  const { write, remove } = planChanges(files, io, previous)
  return { emitters, model, files, write, remove }
}
