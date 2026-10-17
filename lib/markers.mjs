// lib/markers.mjs

const CLOSE = '<!-- /no-vibe:generated -->'

// Replaces the content between a named open marker and the next close marker.
// Prose outside the region is untouched: this is what lets CLAUDE.md be
// authored by a human and still carry a machine-owned table.
export function applyRegion(text, id, replacement) {
  const open = `<!-- no-vibe:generated:${id} -->`

  const start = text.indexOf(open)
  if (start === -1) throw new Error(`missing marker '${id}'`)
  if (text.indexOf(open, start + open.length) !== -1) throw new Error(`duplicate marker '${id}'`)

  const from = start + open.length
  const end = text.indexOf(CLOSE, from)
  if (end === -1) throw new Error(`unbalanced marker '${id}'`)

  return `${text.slice(0, from)}\n${replacement}\n${text.slice(end)}`
}
