// runtimes/pi.mjs
export const id = 'pi'

export function emit() {
  return {}
}

export function pkg() {
  return {
    pi: {
      skills: ['./skills'],
      prompts: ['./.pi-plugin/prompts'],
      extensions: ['./.pi-plugin/extensions'],
    },
  }
}

export function ships() {
  return ['.pi-plugin/']
}
