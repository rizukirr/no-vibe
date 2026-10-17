// runtimes/opencode.mjs
export const id = 'opencode'

export function emit() {
  return {}
}

export function pkg() {
  return { main: './index.js' }
}

export function ships() {
  return ['.opencode/', 'index.js']
}
