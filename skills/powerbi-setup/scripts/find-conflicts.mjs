// Lists skills, plugins, MCP servers and permissions that may conflict with the powerbi plugin.
// Usage: node find-conflicts.mjs [--json]
// Read-only: it changes nothing, starts nothing and does not print secrets
// (environment values are never shown, and long token-like strings are masked).

import fs from "node:fs";
import os from "node:os";
import path from "node:path";

const home = os.homedir();
const cwd = process.cwd();
const asJson = process.argv.includes("--json");

const OUR_SKILLS = new Set(["powerbi-mcp", "power-bi-dax-optimization", "power-bi-screenshot", "powerbi-setup"]);
const UPSTREAM_ALIASES = new Set(["semantic-model-authoring"]);
const OUR_SERVER = "powerbi-modeling-mcp";
const OUR_PLUGIN_ID = "powerbi@powerbi-plugin";

const MENTIONS_POWERBI = /power[\s_-]?bi|powerbi|\bpbi(?:desktop|p)?\b|semantic[\s-]model|tmdl|\bdax\b/i;
const MCP_POWERBI = /power[\s_-]?bi|powerbi|\bpbi\b|semantic[\s-]model|fabric/i;

const findings = [];
const notes = [];

function short(p) {
  const normalized = p.replace(/\\/g, "/");
  const h = home.replace(/\\/g, "/");
  return normalized.startsWith(h) ? "~" + normalized.slice(h.length) : normalized;
}

function mask(text) {
  return String(text)
    .replace(/(token|key|secret|password|pwd)=\S+/gi, "$1=***")
    .replace(/[A-Za-z0-9_\-]{32,}/g, "***");
}

function readJson(file) {
  let text;
  try {
    text = fs.readFileSync(file, "utf8");
  } catch {
    return null;
  }
  try {
    return JSON.parse(text);
  } catch (error) {
    notes.push("WARNING: " + short(file) + " exists but could not be read (" + error.message + "). Its entries were NOT checked.");
    return null;
  }
}

function add(finding) {
  findings.push(finding);
}

// MCP servers configured in Claude Code files
function scanMcpEntries(servers, where) {
  for (const [name, cfg] of Object.entries(servers || {})) {
    const args = Array.isArray(cfg.args) ? cfg.args : [];
    const command = cfg.command ? path.basename(String(cfg.command)) : "";
    const text = [name, cfg.command || "", args.join(" "), cfg.url || ""].join(" ");
    const sameServer = text.includes(OUR_SERVER);
    if (!sameServer && !MCP_POWERBI.test(text)) continue;
    add({
      type: "mcp",
      kind: sameServer ? "same-name" : "overlap",
      name,
      where,
      detail: mask([cfg.type || "stdio", command, args.join(" ")].filter(Boolean).join(" ")),
      envKeys: cfg.env ? Object.keys(cfg.env) : [],
    });
  }
}

const claudeJson = readJson(path.join(home, ".claude.json"));
if (claudeJson) {
  scanMcpEntries(claudeJson.mcpServers, short(path.join(home, ".claude.json")) + " (user)");
  for (const [project, value] of Object.entries(claudeJson.projects || {})) {
    scanMcpEntries(value && value.mcpServers, short(path.join(home, ".claude.json")) + " (project " + short(project) + ")");
  }
}
const projectMcp = readJson(path.join(cwd, ".mcp.json"));
if (projectMcp) scanMcpEntries(projectMcp.mcpServers, short(path.join(cwd, ".mcp.json")));

// MCP servers configured in Codex
try {
  const toml = fs.readFileSync(path.join(home, ".codex", "config.toml"), "utf8");
  const blocks = toml.split(/^\[/m).slice(1);
  for (const block of blocks) {
    const header = block.split("\n", 1)[0];
    const match = header.match(/^mcp_servers\.("?)([^\]"]+)\1\]/);
    if (!match) continue;
    const sameServer = block.includes(OUR_SERVER);
    if (!sameServer && !MCP_POWERBI.test(block)) continue;
    add({
      type: "mcp",
      kind: sameServer ? "same-name" : "overlap",
      name: match[2],
      where: "~/.codex/config.toml",
      detail: mask(block.split("\n").slice(1, 4).join(" ").trim()),
      envKeys: [],
    });
  }
} catch {
  // no Codex configuration
}

// Plugins installed in Claude Code
const installed = readJson(path.join(home, ".claude", "plugins", "installed_plugins.json"));
for (const [id, entries] of Object.entries((installed && installed.plugins) || {})) {
  if (id === OUR_PLUGIN_ID) continue;
  if (!MENTIONS_POWERBI.test(id) && !/fabric/i.test(id)) continue;
  const first = Array.isArray(entries) ? entries[0] || {} : {};
  add({
    type: "plugin",
    kind: "overlap",
    name: id,
    where: "~/.claude/plugins (" + (first.scope || "?") + ")",
    detail: "version " + (first.version || "?"),
    envKeys: [],
  });
}

// Skills in the folders that agents read
const SKILL_ROOTS = [
  { dir: path.join(home, ".claude", "skills"), loadedBy: "Claude Code (user)" },
  { dir: path.join(cwd, ".claude", "skills"), loadedBy: "Claude Code (project)" },
  { dir: path.join(home, ".agents", "skills"), loadedBy: "other agents (not read by Claude Code)" },
  { dir: path.join(cwd, ".agents", "skills"), loadedBy: "other agents (not read by Claude Code)" },
  { dir: path.join(home, ".codex", "skills"), loadedBy: "Codex" },
];

function frontmatter(file) {
  try {
    const text = fs.readFileSync(file, "utf8").replace(/\r/g, "");
    const match = text.match(/^---\n([\s\S]*?)\n---/);
    if (!match) return {};
    const body = match[1];
    const name = (body.match(/^name:\s*(.+)$/m) || [])[1];
    const descStart = body.search(/^description:/m);
    let description = "";
    if (descStart >= 0) {
      description = body
        .slice(descStart)
        .replace(/^description:\s*[>|]?-?\s*/, "")
        .split(/\n(?=[a-z-]+:)/)[0]
        .replace(/\s+/g, " ")
        .trim();
    }
    return { name: name ? name.trim().replace(/^["']|["']$/g, "") : undefined, description };
  } catch {
    return {};
  }
}

function walk(dir, depth, found) {
  if (depth > 3) return;
  let entries = [];
  try {
    entries = fs.readdirSync(dir, { withFileTypes: true });
  } catch {
    return;
  }
  for (const entry of entries) {
    const full = path.join(dir, entry.name);
    let isDir = entry.isDirectory();
    let target;
    if (entry.isSymbolicLink()) {
      try {
        target = fs.readlinkSync(full);
        isDir = fs.statSync(full).isDirectory();
      } catch {
        continue;
      }
    }
    if (!isDir) continue;
    if (fs.existsSync(path.join(full, "SKILL.md"))) {
      found.push({ full, folder: entry.name, target });
    } else {
      walk(full, depth + 1, found);
    }
  }
}

// The same folder can be reached twice (for example when the agent runs in the home folder),
// so each real folder is scanned once.
function uniqueByRealPath(items, pick) {
  const seen = new Set();
  return items.filter((item) => {
    let real;
    try {
      real = fs.realpathSync.native(pick(item)).toLowerCase();
    } catch {
      return false;
    }
    if (seen.has(real)) return false;
    seen.add(real);
    return true;
  });
}

for (const root of uniqueByRealPath(SKILL_ROOTS, (r) => r.dir)) {
  const found = [];
  walk(root.dir, 0, found);
  for (const skill of found) {
    const meta = frontmatter(path.join(skill.full, "SKILL.md"));
    const name = meta.name || skill.folder;
    const sameName =
      OUR_SKILLS.has(name) || OUR_SKILLS.has(skill.folder) || UPSTREAM_ALIASES.has(name) || UPSTREAM_ALIASES.has(skill.folder);
    const mentions = MENTIONS_POWERBI.test(name + " " + (meta.description || ""));
    if (!sameName && !mentions) continue;
    add({
      type: "skill",
      kind: sameName ? "same-name" : "mentions",
      name,
      where: short(skill.full),
      detail: (skill.target ? "symlink to " + short(skill.target) + "; " : "") + "read by " + root.loadedBy + "; " + mask((meta.description || "").slice(0, 140)),
      envKeys: [],
    });
  }
}

// Permission rules that name the old, non-plugin server
for (const file of uniqueByRealPath(
  [
    path.join(home, ".claude", "settings.json"),
    path.join(home, ".claude", "settings.local.json"),
    path.join(cwd, ".claude", "settings.json"),
    path.join(cwd, ".claude", "settings.local.json"),
  ],
  (f) => f
)) {
  const settings = readJson(file);
  const rules = [];
  for (const list of Object.values((settings && settings.permissions) || {})) {
    if (Array.isArray(list)) rules.push(...list.filter((rule) => typeof rule === "string" && /^mcp__powerbi-modeling-mcp/.test(rule)));
  }
  if (rules.length) {
    add({
      type: "permission",
      kind: "old-name",
      name: rules.length + " rule(s) for the non-plugin server",
      where: short(file),
      detail: "they do not apply to the plugin's server (mcp__plugin_powerbi_powerbi-modeling-mcp__*)",
      envKeys: [],
    });
  }
}

notes.push("Read-only: nothing was changed. Environment values are never printed.");

if (asJson) {
  console.log(JSON.stringify({ findings, notes }, null, 2));
} else {
  const kinds = {
    "same-name": "SAME NAME OR SAME SERVER (a second copy of what the plugin provides)",
    overlap: "OVERLAP (another Power BI or Fabric tool that may answer the same requests)",
    mentions: "MENTIONS POWER BI (usually your own task, which uses it; keep unless it duplicates the plugin)",
    "old-name": "PERMISSIONS FOR THE OLD SERVER NAME",
  };
  if (!findings.length) console.log("No conflicts found: nothing outside the plugin provides Power BI skills, plugins or servers.");
  for (const [kind, title] of Object.entries(kinds)) {
    const group = findings.filter((f) => f.kind === kind);
    if (!group.length) continue;
    console.log("\n" + title);
    for (const f of group) {
      console.log("- [" + f.type + "] " + f.name + "  |  " + f.where);
      if (f.detail) console.log("    " + f.detail);
      if (f.envKeys && f.envKeys.length) console.log("    env keys (values hidden): " + f.envKeys.join(", "));
    }
  }
  console.log("\n" + notes.join("\n"));
}
