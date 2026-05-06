import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { fileURLToPath } from "node:url";
import type { ExtensionAPI } from "@mariozechner/pi-coding-agent";

const SCRIPT_DIR = path.dirname(fileURLToPath(import.meta.url));

const findSharedDir = (): string => {
  const candidates = [
    path.resolve(SCRIPT_DIR, "..", "..", "..", "shared"),
    path.resolve(SCRIPT_DIR, "..", "..", "..", "..", "..", "shared"),
    path.resolve(SCRIPT_DIR, "..", "..", "shared"),
  ];
  for (const c of candidates) if (fs.existsSync(c)) return c;
  return candidates[0];
};

const SHARED_DIR = findSharedDir();

const loadJson = (p: string): any => {
  try { return JSON.parse(fs.readFileSync(p, "utf8")); } catch { return null; }
};

const writeToolsConfig = loadJson(path.join(SHARED_DIR, "guard", "write-tools.json")) || {
  tools: ["Edit", "Write", "NotebookEdit", "MultiEdit", "ApplyPatch", "apply_patch"],
  path_fields: ["file_path", "notebook_path"],
};
const WRITE_TOOLS = new Set<string>(writeToolsConfig.tools.map((t: string) => t.toLowerCase()));
const PATH_FIELDS: string[] = writeToolsConfig.path_fields;
const BASH_TOOLS = new Set(["bash", "shell"]);
const SAFE_DEV_PATHS = new Set(["/dev/null", "/dev/stdout", "/dev/stderr", "/dev/tty"]);

const stripFrontmatter = (content: string): string => {
  const match = content.match(/^---\n[\s\S]*?\n---\n?([\s\S]*)$/);
  return match ? match[1] : content;
};

// Bundle every shared/skill/*.md into the bootstrap. Pi has no lazy
// file-load path for the model, so SKILL.md's references to phases.md /
// curriculum.md / teaching-style.md / reference-grounding.md would
// otherwise be dangling pointers. Order matches scripts/sync.sh.
const SKILL_FILES = [
  "SKILL.md",
  "phases.md",
  "teaching-style.md",
  "reference-grounding.md",
  "curriculum.md",
];

const buildBootstrap = (): string => {
  const parts: string[] = [];
  for (const name of SKILL_FILES) {
    const p = path.join(SHARED_DIR, "skill", name);
    if (!fs.existsSync(p)) continue;
    const body = stripFrontmatter(fs.readFileSync(p, "utf8")).trim();
    if (!body) continue;
    if (parts.length === 0) {
      parts.push(body);
    } else {
      parts.push(`<!-- ===== shared/skill/${name} ===== -->\n\n${body}`);
    }
  }
  const skillBody =
    parts.length > 0
      ? parts.join("\n\n")
      : "You are in no-vibe tutor mode. Teach in chat; never write project files.";
  return [
    "<EXTREMELY_IMPORTANT>",
    "no-vibe tutor mode is available in this repository.",
    "",
    skillBody,
    "",
    "**Tool mapping for Pi:** built-in tools are `read`, `write`, `edit`, `bash`. The write guard refuses `write`/`edit` outside `.no-vibe/` and rejects destructive `bash` patterns when `.no-vibe/active` exists. Show code in chat — do not call write tools on project files.",
    "</EXTREMELY_IMPORTANT>",
  ].join("\n");
};

const tryRealpath = (p: string): string | null => {
  try { return fs.realpathSync(p); } catch { return null; }
};

const canonicalize = (absolutePath: string): string => {
  if (fs.existsSync(absolutePath)) return tryRealpath(absolutePath) || path.resolve(absolutePath);
  const resolved = path.resolve(absolutePath);
  let parent = path.dirname(resolved);
  while (parent !== path.dirname(parent) && !fs.existsSync(parent)) parent = path.dirname(parent);
  const canonicalParent = tryRealpath(parent) || path.resolve(parent);
  return path.resolve(canonicalParent, path.relative(parent, resolved));
};

const isWithinNoVibeDir = (cwd: string, abs: string): boolean => {
  const projectRoot = canonicalize(path.resolve(cwd, ".no-vibe"));
  const homeRoot = canonicalize(path.resolve(os.homedir(), ".no-vibe"));
  const t = canonicalize(abs);
  if (t === projectRoot || t.startsWith(`${projectRoot}${path.sep}`)) return true;
  if (t === homeRoot || t.startsWith(`${homeRoot}${path.sep}`)) return true;
  return false;
};

const isSafeBashTarget = (cwd: string, rawPath: string): boolean => {
  if (!rawPath) return false;
  let p = rawPath;
  if ((p.startsWith('"') && p.endsWith('"')) || (p.startsWith("'") && p.endsWith("'"))) p = p.slice(1, -1);
  if (!p) return false;
  if (/[\$`]/.test(p)) return false;
  if (SAFE_DEV_PATHS.has(p) || p.startsWith("/dev/fd/")) return true;
  if (p === "/tmp" || p.startsWith("/tmp/") || p === "/var/tmp" || p.startsWith("/var/tmp/")) return true;
  const abs = path.isAbsolute(p) ? path.resolve(p) : path.resolve(cwd, p);
  const scratch = canonicalize(path.resolve(cwd, ".no-vibe"));
  const homeScratch = canonicalize(path.resolve(os.homedir(), ".no-vibe"));
  const c = canonicalize(abs);
  if (c === scratch || c.startsWith(`${scratch}${path.sep}`)) return true;
  if (c === homeScratch || c.startsWith(`${homeScratch}${path.sep}`)) return true;
  if (c === "/tmp" || c.startsWith("/tmp/")) return true;
  if (c === "/var/tmp" || c.startsWith("/var/tmp/")) return true;
  return false;
};

const splitTokens = (s: string): string[] => s.split(/\s+/).filter(Boolean);

const inspectBashCommand = (cwd: string, command: string): string | null => {
  if (!command) return null;
  const clean = command.replace(/[0-9]+>&[0-9]+/g, "").replace(/[0-9]+<&[0-9]+/g, "");

  let m: RegExpExecArray | null;
  const redirRe = /(&>>?|>>?)\s*([^\s|&;<>()]+)/g;
  while ((m = redirRe.exec(clean)) !== null) {
    if (!isSafeBashTarget(cwd, m[2])) return `redirection writes to '${m[2]}'`;
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
      if (!isSafeBashTarget(cwd, tok)) return `tee writes to '${tok}'`;
    }
  }

  const sedMatch = clean.match(/(?:^|[\s|;&(])sed\s+([^|;&]*)/);
  if (sedMatch) {
    const tokens = splitTokens(sedMatch[1]);
    const hasInPlace = tokens.some((t) => /^-[a-zA-Z]*i$/.test(t) || t.startsWith("-i") || t === "--in-place" || t.startsWith("--in-place="));
    if (hasInPlace) {
      let skipNext = false, sawScript = false;
      for (const tok of tokens) {
        if (skipNext) { skipNext = false; continue; }
        if (tok === "-e" || tok === "-f") { skipNext = true; continue; }
        if (tok.startsWith("-")) continue;
        if (!sawScript) { sawScript = true; continue; }
        if (!isSafeBashTarget(cwd, tok)) return `sed -i mutates '${tok}'`;
      }
    }
  }

  for (const cmdName of ["cp", "mv", "install"]) {
    const args = findArgsAfter(cmdName);
    if (!args) continue;
    let last: string | null = null;
    for (const tok of args) { if (!tok.startsWith("-")) last = tok; }
    if (last && !isSafeBashTarget(cwd, last)) return `${cmdName} destination '${last}'`;
  }

  const ddRe = /of=([^\s|&;()]+)/g;
  while ((m = ddRe.exec(clean)) !== null) {
    if (!isSafeBashTarget(cwd, m[1])) return `dd of=${m[1]}`;
  }

  return null;
};

const lower = (s: unknown): string => String(s ?? "").toLowerCase();

const getTargetPath = (input: any): string | null => {
  for (const f of PATH_FIELDS) {
    if (input?.[f]) return input[f];
    const camel = f.replace(/_([a-z])/g, (_: string, c: string) => c.toUpperCase());
    if (input?.[camel]) return input[camel];
  }
  if (input?.path) return input.path;
  return null;
};

const resumeHint = (projectRoot: string): string | null => {
  const sessionMd = path.join(projectRoot, ".no-vibe", "session.md");
  if (!fs.existsSync(sessionMd)) return null;
  let content: string;
  try { content = fs.readFileSync(sessionMd, "utf8"); } catch { return null; }
  const topicMatch = content.match(/^# Lesson:\s*(.+)$/m);
  const topic = topicMatch ? topicMatch[1].trim() : "untitled";
  const total = (content.match(/^- \[[ x]\]/gm) || []).length;
  const done = (content.match(/^- \[x\]/gm) || []).length;
  if (total === 0 || done >= total) return null;
  return `resuming "${topic}" (${done}/${total} layers complete)`;
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
          reason: `no-vibe is active. Refusing Bash — ${reason}. Safe targets: '.no-vibe/**', '$HOME/.no-vibe/**', '/tmp/**', '/var/tmp/**', '/dev/{null,stdout,stderr,tty,fd/*}'. Variable / command-substitution destinations fail closed. Show code in chat; user runs it. '/no-vibe off' to exit.`,
        };
      }
      return;
    }

    if (!WRITE_TOOLS.has(toolName)) return;

    const targetPath = getTargetPath(input);
    if (!targetPath) {
      return {
        block: true,
        reason: `no-vibe is active. Refusing '${toolName}' — no target path provided. Show code in chat; user types it. '/no-vibe off' to exit.`,
      };
    }

    const absolute = path.isAbsolute(targetPath) ? path.resolve(targetPath) : path.resolve(cwd, targetPath);
    if (isWithinNoVibeDir(cwd, absolute)) return;

    return {
      block: true,
      reason: `no-vibe is active. Cannot write to '${absolute}'. Show code in chat; user types it. Use '.no-vibe/' for notes. '/no-vibe off' to exit.`,
    };
  });
}
