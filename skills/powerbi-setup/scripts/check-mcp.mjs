// Checks that the Power BI Modeling MCP server starts and lists its tools.
// Usage: node check-mcp.mjs [version]
// Exit code 0 = server started and answered tools/list, 1 = it did not.
// It does not accept any license and does not touch any Power BI file.

import { spawn } from "node:child_process";

const version = process.argv[2] || "1.0.1";
const pkg = `@microsoft/powerbi-modeling-mcp@${version}`;
const isWindows = process.platform === "win32";
const [command, args] = isWindows
  ? ["cmd", ["/c", "npx", "-y", pkg, "--start"]]
  : ["npx", ["-y", pkg, "--start"]];

const TIMEOUT_MS = 120000;
const child = spawn(command, args, { stdio: ["pipe", "pipe", "pipe"] });

let buffer = "";
let stderrText = "";
let finished = false;

function send(message) {
  child.stdin.write(JSON.stringify(message) + "\n");
}

function stop(code, text) {
  if (finished) return;
  finished = true;
  console.log(text);
  if (isWindows) {
    spawn("taskkill", ["/pid", String(child.pid), "/T", "/F"], { stdio: "ignore" });
  } else {
    child.kill("SIGKILL");
  }
  setTimeout(() => process.exit(code), 500);
}

const timer = setTimeout(() => {
  stop(1, `FAIL: no answer after ${TIMEOUT_MS / 1000}s. The first run downloads the package, so try again once. Last server output:\n${stderrText.slice(-600)}`);
}, TIMEOUT_MS);

child.on("error", (error) => {
  clearTimeout(timer);
  stop(1, `FAIL: could not start "${command}": ${error.message}. Check that Node.js and npx are on the PATH.`);
});

child.on("exit", (code) => {
  if (!finished) {
    clearTimeout(timer);
    stop(1, `FAIL: the server exited early (code ${code}). Last server output:\n${(stderrText + buffer).slice(-600)}`);
  }
});

child.stderr.on("data", (chunk) => {
  stderrText += chunk.toString();
});

child.stdout.on("data", (chunk) => {
  buffer += chunk.toString();
  const lines = buffer.split("\n");
  buffer = lines.pop();
  for (const line of lines) {
    const text = line.trim();
    if (!text.startsWith("{")) continue;
    let message;
    try {
      message = JSON.parse(text);
    } catch {
      continue;
    }
    if (message.id === 1 && message.result) {
      send({ jsonrpc: "2.0", method: "notifications/initialized" });
      send({ jsonrpc: "2.0", id: 2, method: "tools/list" });
    } else if (message.id === 2 && message.result) {
      clearTimeout(timer);
      const names = (message.result.tools || []).map((tool) => tool.name);
      const eula = names.includes("accept_eula") ? "listed" : "NOT listed";
      stop(0, `OK: server ${version} started and lists ${names.length} tools. The accept_eula tool is ${eula}.\n${names.join(", ")}`);
    } else if (message.error) {
      clearTimeout(timer);
      stop(1, `FAIL: the server answered with an error: ${JSON.stringify(message.error).slice(0, 400)}`);
    }
  }
});

send({
  jsonrpc: "2.0",
  id: 1,
  method: "initialize",
  params: {
    protocolVersion: "2024-11-05",
    capabilities: {},
    clientInfo: { name: "powerbi-setup-check", version: "1.0.0" },
  },
});
