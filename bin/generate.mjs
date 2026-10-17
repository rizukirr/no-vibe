#!/usr/bin/env node
// bin/generate.mjs
import { writeFileSync, mkdirSync, rmSync, existsSync } from 'node:fs'
import { dirname, join, resolve } from 'node:path'
import { fileURLToPath } from 'node:url'
import { build } from '../lib/build.mjs'

const ROOT = resolve(dirname(fileURLToPath(import.meta.url)), '..')
const check = process.argv.includes('--check')

// Validation failures are authoring mistakes, not crashes. A skill author who
// mistypes a gate value should see the sentence, not a Node stack trace.
let built
try {
  built = await build(ROOT)
} catch (error) {
  console.error(`no-vibe: ${error.message}`)
  process.exit(1)
}
const { files, write, remove } = built

if (check) {
  if (write.length === 0 && remove.length === 0) {
    console.log('up to date')
    process.exit(0)
  }
  console.error('generated files are out of date:')
  for (const path of write) console.error(`  stale: ${path}`)
  for (const path of remove) console.error(`  orphan: ${path}`)
  console.error('run: npm run generate')
  process.exit(1)
}

for (const path of write) {
  const absolute = join(ROOT, path)
  mkdirSync(dirname(absolute), { recursive: true })
  writeFileSync(absolute, files[path])
  console.log(`wrote ${path}`)
}
for (const path of remove) {
  if (existsSync(join(ROOT, path))) {
    rmSync(join(ROOT, path))
    console.log(`removed ${path}`)
  }
}
console.log('done')
