// Saves one MCP server entry to a backup folder and writes a script that restores it.
// Usage: node backup-mcp-entry.mjs <name> <scope> <backup-folder>
//   scope: user | local | project  (the same words as `claude mcp ... -s <scope>`)
// Run it from the project folder when the scope is local or project.
//
// It never prints the entry: the values of `env` and `args` may be secrets.
// It writes <backup-folder>/mcp/<name>.json and <backup-folder>/mcp/restore-<name>.sh.
// To restore, run the .sh file with Git Bash (`bash restore-<name>.sh`): running a file keeps
// the JSON out of the conversation, and Git Bash keeps its quotes intact.
// It changes nothing in any configuration file.

import fs from "node:fs";
import os from "node:os";
import path from "node:path";

const [name, scope, backupDir] = process.argv.slice(2);
if (!name || !["user", "local", "project"].includes(scope) || !backupDir) {
  console.error("Usage: node backup-mcp-entry.mjs <name> <user|local|project> <backup-folder>");
  process.exit(2);
}

const cwd = process.cwd();
const norm = (p) => p.replace(/\\/g, "/").replace(/\/+$/, "").toLowerCase();

function readJson(file) {
  try {
    return JSON.parse(fs.readFileSync(file, "utf8"));
  } catch {
    return null;
  }
}

let entry;
if (scope === "user") {
  const config = readJson(path.join(os.homedir(), ".claude.json"));
  entry = config && config.mcpServers && config.mcpServers[name];
} else if (scope === "local") {
  const config = readJson(path.join(os.homedir(), ".claude.json"));
  const projects = (config && config.projects) || {};
  const key = Object.keys(projects).find((k) => norm(k) === norm(cwd));
  entry = key && projects[key].mcpServers && projects[key].mcpServers[name];
} else {
  const config = readJson(path.join(cwd, ".mcp.json"));
  entry = config && config.mcpServers && config.mcpServers[name];
}

if (!entry) {
  console.error('FAIL: no server named "' + name + '" in scope "' + scope + '"' + (scope === "user" ? "" : " for " + cwd) + ". Nothing was saved.");
  process.exit(1);
}

const mcpDir = path.join(backupDir, "mcp");
fs.mkdirSync(mcpDir, { recursive: true });
const jsonFile = path.join(mcpDir, name + ".json");
const shFile = path.join(mcpDir, "restore-" + name + ".sh");
if (fs.existsSync(jsonFile) || fs.existsSync(shFile)) {
  console.error("FAIL: a backup for this name already exists in " + mcpDir + ". Nothing was overwritten.");
  process.exit(1);
}

const json = JSON.stringify(entry);
fs.writeFileSync(jsonFile, JSON.stringify(entry, null, 2) + "\n", "utf8");

const quote = (text) => "'" + String(text).replace(/'/g, "'\\''") + "'";
const lines = ["#!/bin/bash", "# Restores the MCP server '" + name + "' (scope " + scope + "). Run with Git Bash: bash restore-" + name + ".sh", "export MSYS_NO_PATHCONV=1"];
if (scope !== "user") lines.push("cd " + quote(cwd.replace(/\\/g, "/")));
lines.push("claude mcp add-json " + quote(name) + " " + quote(json) + " -s " + scope);
fs.writeFileSync(shFile, lines.join("\n") + "\n", "utf8");

const envKeys = entry.env ? Object.keys(entry.env) : [];
console.log("OK: saved '" + name + "' (scope " + scope + ", type " + (entry.type || "stdio") + ") to " + jsonFile);
console.log("Restore script: " + shFile);
if (envKeys.length) console.log("It has environment values (hidden): " + envKeys.join(", ") + ". The backup file keeps them as they were.");
