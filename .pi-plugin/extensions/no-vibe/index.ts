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

const readSingleFile = (label: string, p: string, placeholder: string): string => {
  if (fs.existsSync(p)) {
    const body = fs.readFileSync(p, "utf8");
    return `\n\n=== ${label} (${p}) ===\n${body}\n=== END ${label} ===`;
  }
  return `\n\n=== ${label} (not present — ${p}) ===\n${placeholder}\n=== END ${label} ===`;
};

const readUserDir = (label: string, dir: string, placeholder: string): string => {
  if (!fs.existsSync(dir) || !fs.statSync(dir).isDirectory()) {
    return `\n\n=== ${label} (${dir}/) ===\n${placeholder}\n=== END ${label} ===`;
  }
  let entries: string[];
  try {
    entries = fs.readdirSync(dir).filter((n) => n.toLowerCase().endsWith(".md")).sort();
  } catch {
    return `\n\n=== ${label} (${dir}/) ===\n${placeholder}\n=== END ${label} ===`;
  }
  if (entries.length === 0) {
    return `\n\n=== ${label} (${dir}/) ===\n${placeholder}\n=== END ${label} ===`;
  }
  const parts = entries.map((name) => {
    const full = path.join(dir, name);
    let body = "";
    try { body = fs.readFileSync(full, "utf8"); } catch { body = ""; }
    return `--- ${full} ---\n${body}`;
  });
  return `\n\n=== ${label} (${dir}/) ===\n${parts.join("\n")}\n=== END ${label} ===`;
};

const buildBootstrap = (cwd: string): string => {
  const skillPath = path.join(SKILLS_DIR, "no-vibe", "SKILL.md");
  let skillBody = "You are in no-vibe mode. Teach in chat and never write project files directly.";

  if (fs.existsSync(skillPath)) {
    skillBody = stripFrontmatter(fs.readFileSync(skillPath, "utf8")).trim();
  }

  // Adaptation Iron Law: inject the AI's progression files
  // (~/.no-vibe/PROFILE.md = global stable identity, .no-vibe/SUMMARY.md =
  // project running journey) and the user's override files (every *.md
  // under user/, both scopes). The runtime never creates or writes any
  // of these — AI creates PROFILE.md on first activation and SUMMARY.md
  // at the first layer close worth recording per the schemas in
  // skills/no-vibe/SKILL.md; user owns user/. Gated on `.no-vibe/active`
  // existing — projects that have not opted into no-vibe mode should
  // not have a `.no-vibe/` directory created as a side effect of plugin
  // loading. The whole block is wrapped in a `## Background Memory`
  // preamble (DeepTutor pattern) telling the AI to use it sparingly.
  const noVibeActive = fs.existsSync(path.join(cwd, ".no-vibe", "active"));
  let backgroundMemory = "";
  if (noVibeActive) {
    const globalProfilePath = path.join(os.homedir(), ".no-vibe", "PROFILE.md");
    const projectSummaryPath = path.join(cwd, ".no-vibe", "SUMMARY.md");
    const globalUserDir = path.join(os.homedir(), ".no-vibe", "user");
    const projectUserDir = path.join(cwd, ".no-vibe", "user");
    const globalProfile = readSingleFile(
      "GLOBAL PROFILE",
      globalProfilePath,
      "PROFILE.md missing — AI creates it on first activation per the schema in SKILL.md \"PROFILE.md and SUMMARY.md — the progression files\".",
    );
    const projectSummary = readSingleFile(
      "PROJECT SUMMARY",
      projectSummaryPath,
      "SUMMARY.md not yet created — appears at the first layer close worth recording. Schema in SKILL.md \"PROFILE.md and SUMMARY.md — the progression files\".",
    );
    const globalUser = readUserDir(
      "GLOBAL USER OVERRIDES",
      globalUserDir,
      "No user-authored override files — defaults, PROFILE.md, and SUMMARY.md apply unmodified.",
    );
    const projectUser = readUserDir(
      "PROJECT USER OVERRIDES",
      projectUserDir,
      "No user-authored override files — defaults, PROFILE.md, and SUMMARY.md apply unmodified.",
    );
    backgroundMemory = [
      "",
      "## Background Memory",
      "Use this memory sparingly — only when directly relevant to the current turn.",
      "Read order: PROFILE (global stable) → SUMMARY (project running) → user/ (user overrides). user/ wins on conflict.",
      globalProfile,
      projectSummary,
      globalUser,
      projectUser,
    ].join("\n");
  }

  return [
    "<EXTREMELY_IMPORTANT>",
    "no-vibe mode is available in this repository.",
    "",
    skillBody,
    backgroundMemory,
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

// Validate full-content writes to PROFILE.md / SUMMARY.md against the
// canonical heading set. Mirrors hooks/validate-memory-write.sh and the
// OpenCode plugin. Only fires on full write (not edit) — edit is for
// incremental updates and existing files should already carry canonical
// headings. Returns null on pass, a string reason on fail.
const PROFILE_HEADINGS = /^(## Identity & expertise|## Learning style|## Disclosure mode|## Observed strengths|## Known gaps)\s*$/m;
const SUMMARY_HEADINGS = /^(## Current Focus|## Accomplishments|## Open Questions)\s*$/m;

const classifyMemoryTarget = (cwd: string, absoluteTargetPath: string): "profile" | "summary" | null => {
  const globalProfile = canonicalize(path.resolve(os.homedir(), ".no-vibe", "PROFILE.md"));
  const projectSummary = canonicalize(path.resolve(cwd, ".no-vibe", "SUMMARY.md"));
  const canonical = canonicalize(absoluteTargetPath);
  if (canonical === globalProfile) return "profile";
  if (canonical === projectSummary) return "summary";
  return null;
};

const validateMemoryContent = (kind: "profile" | "summary", content: unknown): string | null => {
  if (typeof content !== "string" || content.length === 0) return null;
  const re = kind === "profile" ? PROFILE_HEADINGS : SUMMARY_HEADINGS;
  if (re.test(content)) return null;
  if (kind === "profile") {
    return `proposed PROFILE.md content does not contain any canonical section heading. Expected one of: "## Identity & expertise", "## Learning style", "## Disclosure mode", "## Observed strengths", "## Known gaps". This usually means a chat reply was about to be written into the file by mistake. Re-issue the write with the correct schema, or use edit for incremental updates that preserve existing headings. See SKILL.md "PROFILE.md and SUMMARY.md — the progression files".`;
  }
  return `proposed SUMMARY.md content does not contain any canonical section heading. Expected one of: "## Current Focus", "## Accomplishments", "## Open Questions". This usually means a chat reply was about to be written into the file by mistake. Re-issue the write with the correct schema, or use edit for incremental updates that preserve existing headings. See SKILL.md "PROFILE.md and SUMMARY.md — the progression files".`;
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
  pi.on("before_agent_start", async (event: any) => {
    const cwd = path.resolve(event?.cwd || process.cwd());
    // Build per-session so PROFILE.md / user/*.md content reflects the
    // current cwd and any AI/user edits since the last session start.
    const bootstrap = buildBootstrap(cwd);
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
    if (isWithinNoVibeDir(cwd, absoluteTargetPath)) {
      // Inside the safe-zone — also validate canonical headings for
      // full-content writes targeting PROFILE.md / SUMMARY.md.
      if (toolName === "write") {
        const kind = classifyMemoryTarget(cwd, absoluteTargetPath);
        if (kind) {
          const content = (input as any).content ?? (input as any).text ?? (input as any).body ?? "";
          const reason = validateMemoryContent(kind, content);
          if (reason) {
            return {
              block: true,
              reason: `no-vibe heading-validation: refusing write to '${absoluteTargetPath}' — ${reason}`,
            };
          }
        }
      }
      return;
    }

    return {
      block: true,
      reason: `no-vibe mode is active. Refusing write to '${absoluteTargetPath}'. Show code in chat and let the user type it. Use '.no-vibe/' for notes, or run '/no-vibe off' to disable.`,
    };
  });
}
