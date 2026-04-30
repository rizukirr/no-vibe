import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { fileURLToPath } from "node:url";
import type { ExtensionAPI } from "@mariozechner/pi-coding-agent";

const WRITE_TOOLS = new Set(["edit", "write", "notebookedit", "multiedit", "apply_patch", "applypatch"]);
const BASH_TOOLS = new Set(["bash", "shell"]);
const SAFE_DEV_PATHS = new Set(["/dev/null", "/dev/stdout", "/dev/stderr", "/dev/tty"]);

const PLUGIN_ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..", "..", "..");
const SKILLS_DIR = path.join(PLUGIN_ROOT, "skills");

const stripFrontmatter = (content: string): string => {
  const match = content.match(/^---\n[\s\S]*?\n---\n?([\s\S]*)$/);
  return match ? match[1] : content;
};

const buildBootstrap = (): string => {
  const skillPath = path.join(SKILLS_DIR, "no-vibe", "SKILL.md");
  const schemaPath = path.join(SKILLS_DIR, "no-vibe", "DATA-SCHEMA.md");
  let skillBody = "You are in no-vibe mode. Teach in chat and never write project files directly.";
  let schemaBody = "";

  if (fs.existsSync(skillPath)) {
    skillBody = stripFrontmatter(fs.readFileSync(skillPath, "utf8")).trim();
  }
  if (fs.existsSync(schemaPath)) {
    schemaBody = "\n\n## Data Schema Reference\n\n" + stripFrontmatter(fs.readFileSync(schemaPath, "utf8")).trim();
  }

  return [
    "<EXTREMELY_IMPORTANT>",
    "no-vibe mode is available in this repository.",
    "",
    skillBody,
    schemaBody,
    "",
    "**Tool Mapping for Pi:**",
    "Pi's built-in tools are `read`, `write`, `edit`, `bash`. The write guard refuses `write`/`edit` outside `.no-vibe/` and rejects destructive `bash` patterns when `.no-vibe/active` exists. Show code in chat — do not call write tools on project files.",
    "</EXTREMELY_IMPORTANT>",
  ].join("\n");
};

const tryRealpath = (p: string): string | null => {
  try { return fs.realpathSync(p); } catch { return null; }
};

const canonicalize = (absolutePath: string): string => {
  if (fs.existsSync(absolutePath)) {
    return tryRealpath(absolutePath) || path.resolve(absolutePath);
  }
  const resolved = path.resolve(absolutePath);
  let parent = path.dirname(resolved);
  while (parent !== path.dirname(parent) && !fs.existsSync(parent)) {
    parent = path.dirname(parent);
  }
  const canonicalParent = tryRealpath(parent) || path.resolve(parent);
  return path.resolve(canonicalParent, path.relative(parent, resolved));
};

const isWithinNoVibeDir = (cwd: string, absoluteTargetPath: string): boolean => {
  const projectRoot = canonicalize(path.resolve(cwd, ".no-vibe"));
  const homeRoot = canonicalize(path.resolve(os.homedir(), ".no-vibe"));
  const canonicalTarget = canonicalize(absoluteTargetPath);
  if (canonicalTarget === projectRoot || canonicalTarget.startsWith(`${projectRoot}${path.sep}`)) return true;
  if (canonicalTarget === homeRoot || canonicalTarget.startsWith(`${homeRoot}${path.sep}`)) return true;
  return false;
};

const isSafeBashTarget = (cwd: string, rawPath: string): boolean => {
  if (!rawPath) return false;
  let p = rawPath;
  if ((p.startsWith('"') && p.endsWith('"')) || (p.startsWith("'") && p.endsWith("'"))) {
    p = p.slice(1, -1);
  }
  if (!p) return false;
  if (/[\$`]/.test(p)) return false;
  if (SAFE_DEV_PATHS.has(p) || p.startsWith("/dev/fd/")) return true;
  if (p === "/tmp" || p.startsWith("/tmp/") || p === "/var/tmp" || p.startsWith("/var/tmp/")) return true;
  const abs = path.isAbsolute(p) ? path.resolve(p) : path.resolve(cwd, p);
  const scratch = canonicalize(path.resolve(cwd, ".no-vibe"));
  const homeScratch = canonicalize(path.resolve(os.homedir(), ".no-vibe"));
  const canonical = canonicalize(abs);
  if (canonical === scratch || canonical.startsWith(`${scratch}${path.sep}`)) return true;
  if (canonical === homeScratch || canonical.startsWith(`${homeScratch}${path.sep}`)) return true;
  if (canonical === "/tmp" || canonical.startsWith("/tmp/")) return true;
  if (canonical === "/var/tmp" || canonical.startsWith("/var/tmp/")) return true;
  return false;
};

const splitTokens = (segment: string): string[] => segment.split(/\s+/).filter(Boolean);

const inspectBashCommand = (cwd: string, command: string): string | null => {
  if (!command) return null;
  const clean = command.replace(/[0-9]+>&[0-9]+/g, "").replace(/[0-9]+<&[0-9]+/g, "");

  const redirRe = /(&>>?|>>?)\s*([^\s|&;<>()]+)/g;
  let m: RegExpExecArray | null;
  while ((m = redirRe.exec(clean)) !== null) {
    if (!isSafeBashTarget(cwd, m[2])) {
      return `redirection writes to '${m[2]}' outside .no-vibe/ or /tmp/`;
    }
  }

  const findArgsAfter = (cmdName: string): string[] | null => {
    const re = new RegExp(`(?:^|[\\s|;&(])${cmdName}\\s+([^|;&]*)`);
    const match = clean.match(re);
    return match ? splitTokens(match[1]) : null;
  };

  const teeArgs = findArgsAfter("tee");
  if (teeArgs) {
    for (const tok of teeArgs) {
      if (tok.startsWith("-")) continue;
      if (!isSafeBashTarget(cwd, tok)) {
        return `tee writes to '${tok}' outside .no-vibe/ or /tmp/`;
      }
    }
  }

  const sedRe = /(?:^|[\s|;&(])sed\s+([^|;&]*)/;
  const sedMatch = clean.match(sedRe);
  if (sedMatch) {
    const tokens = splitTokens(sedMatch[1]);
    const hasInPlace = tokens.some((t) => /^-[a-zA-Z]*i$/.test(t) || t.startsWith("-i") || t === "--in-place" || t.startsWith("--in-place="));
    if (hasInPlace) {
      let skipNext = false;
      let sawScript = false;
      for (const tok of tokens) {
        if (skipNext) { skipNext = false; continue; }
        if (tok === "-e" || tok === "-f") { skipNext = true; continue; }
        if (tok.startsWith("-")) continue;
        if (!sawScript) { sawScript = true; continue; }
        if (!isSafeBashTarget(cwd, tok)) {
          return `sed -i mutates '${tok}' outside .no-vibe/ or /tmp/`;
        }
      }
    }
  }

  for (const cmdName of ["cp", "mv", "install"]) {
    const args = findArgsAfter(cmdName);
    if (!args) continue;
    let last: string | null = null;
    for (const tok of args) {
      if (tok.startsWith("-")) continue;
      last = tok;
    }
    if (last && !isSafeBashTarget(cwd, last)) {
      return `${cmdName} destination '${last}' outside .no-vibe/ or /tmp/`;
    }
  }

  const ddRe = /of=([^\s|&;()]+)/g;
  while ((m = ddRe.exec(clean)) !== null) {
    if (!isSafeBashTarget(cwd, m[1])) {
      return `dd of=${m[1]} writes outside .no-vibe/ or /tmp/`;
    }
  }

  return null;
};

const lower = (s: unknown): string => String(s ?? "").toLowerCase();

const getTargetPath = (input: any): string | null =>
  input?.filePath || input?.file_path || input?.path || input?.notebookPath || input?.notebook_path || null;

const resumeHint = (projectRoot: string): string | null => {
  const sessionsDir = path.join(projectRoot, ".no-vibe", "data", "sessions");
  if (!fs.existsSync(sessionsDir)) return null;
  let entries: string[];
  try { entries = fs.readdirSync(sessionsDir).filter((n) => n.endsWith(".json")); } catch { return null; }
  let best: any = null;
  let bestMtime = -Infinity;
  for (const name of entries) {
    const full = path.join(sessionsDir, name);
    let raw: string;
    try { raw = fs.readFileSync(full, "utf8"); } catch { continue; }
    let parsed: any;
    try { parsed = JSON.parse(raw); } catch { continue; }
    if (parsed?.status !== "in_progress") continue;
    let mtime = 0;
    try { mtime = fs.statSync(full).mtimeMs; } catch { /* fall through */ }
    if (mtime > bestMtime) { bestMtime = mtime; best = parsed; }
  }
  if (!best) return null;
  const topic = best.topic ?? "untitled";
  const cur = best.current_layer ?? 0;
  const tot = best.layers_total ?? 0;
  const phase = best.current_phase ?? "?";
  return `resuming "${topic}" (layer ${cur}/${tot}, ${phase})`;
};

const statusLine = (projectRoot: string): string | null => {
  if (!fs.existsSync(path.join(projectRoot, ".no-vibe"))) return null;
  if (!fs.existsSync(path.join(projectRoot, ".no-vibe", "active"))) return "no-vibe: OFF";
  const hint = resumeHint(projectRoot);
  return hint ? `no-vibe: ON — ${hint}` : "no-vibe: ON";
};

export default async function (pi: ExtensionAPI) {
  const bootstrap = buildBootstrap();

  pi.on("before_agent_start", async (event: any) => {
    const cwd = path.resolve(event?.cwd || process.cwd());
    const status = statusLine(cwd);
    const framed = status ? `${status}\n\n${bootstrap}` : bootstrap;
    return { systemPrompt: `${event.systemPrompt}\n\n${framed}` };
  });

  pi.on("tool_call", async (event: any, ctx: any) => {
    const cwd = path.resolve(ctx?.cwd || process.cwd());
    const markerPath = path.join(cwd, ".no-vibe", "active");
    if (!fs.existsSync(markerPath)) return;

    const toolName = lower(event?.toolName || event?.tool);
    const input = event?.input || {};

    if (BASH_TOOLS.has(toolName)) {
      const command = input.command || input.cmd || "";
      const reason = inspectBashCommand(cwd, command);
      if (reason) {
        return {
          block: true,
          reason: `no-vibe mode is active. Refusing Bash command — ${reason}. Safe targets: '.no-vibe/**', '$HOME/.no-vibe/**', '/tmp/**', '/var/tmp/**', '/dev/{null,stdout,stderr,tty,fd/*}'. Variable / command-substitution destinations fail closed. Show the code in chat and let the user run it. Run '/no-vibe off' to disable.`,
        };
      }
      return;
    }

    if (!WRITE_TOOLS.has(toolName)) return;

    const targetPath = getTargetPath(input);
    if (!targetPath) {
      return {
        block: true,
        reason: `no-vibe mode is active. Refusing '${toolName}' because no target path was provided. Show code in chat and let the user type it, or run '/no-vibe off'.`,
      };
    }

    const absoluteTargetPath = path.isAbsolute(targetPath) ? path.resolve(targetPath) : path.resolve(cwd, targetPath);
    if (isWithinNoVibeDir(cwd, absoluteTargetPath)) return;

    return {
      block: true,
      reason: `no-vibe mode is active. Refusing write to '${absoluteTargetPath}'. Show code in chat and let the user type it. Use '.no-vibe/' for notes, or run '/no-vibe off' to disable.`,
    };
  });
}
