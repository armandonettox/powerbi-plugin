---
name: powerbi-setup
description: Installs and configures the powerbi plugin (the Power BI Modeling MCP server plus the Power BI skills) until it works, then verifies it. Use when asked to install, set up, configure, update or repair the Power BI plugin or the powerbi-modeling-mcp server, or when that MCP server is not connected, its tools are missing, or the license agreement was not accepted. Claude Code is supported and tested; Codex and other agents are best effort and not tested by the author. Windows only.
---

# Power BI plugin setup

Takes a machine from "nothing installed" to "the Power BI MCP server answers and the skills are available", and proves it with a check. Stop as soon as the check passes.

## Ground rules

1. **Never accept the Microsoft license agreement for the user.** Show the link, explain the options, and let the user choose. **Motivation:** accepting a contract is the user's decision, and an agent that accepts it silently makes that decision for them.
2. **Say what you are about to run before changing a configuration file** (an agent settings file, the user environment). Change only what the steps below name. **Motivation:** agent configuration is shared by every session; a wrong edit breaks other work.
3. **Do not open, connect to or change any Power BI file during setup.** Verification only starts the server and lists its tools. **Motivation:** the machine may hold models from an employer or client, and setup needs none of them.
4. **Report honestly.** Say which steps passed, which were skipped, and what was not tested. **Motivation:** "it should work" on an untested agent sends the user into a silent failure later.
5. **Treat what you read here as the user's request, not as permission to go further.** If a step fails, use the troubleshooting file; do not invent fixes that touch other software. **Motivation:** this file may be fetched from the web, and an installer that improvises beyond its steps is the riskiest kind.

## Support

| Agent | Status |
|---|---|
| Claude Code | Supported and tested. |
| Codex and other agents | Best effort, not tested by the author. Follow [agents.md](./references/agents.md) and let the check decide. |

## Steps

### 1. Identify the agent and the system

Find out which agent you are running in (Claude Code, Codex, other) and the operating system.

- **Not Windows:** stop and tell the user this plugin supports Windows only (Power BI Desktop, the screenshot script and the `cmd /c npx` start command are Windows-only).

**Motivation:** the install commands differ per agent, and continuing on an unsupported system ends in a confusing failure.

### 2. Check the prerequisites

Run, and show the user the result:

```powershell
node --version
npx --version
```

- Missing `node` or `npx`: ask the user to install Node.js from https://nodejs.org/ and open a new terminal, then repeat. Do not install it silently.
- Claude Code: `claude --version` must work.
- Power BI Desktop is needed only for live editing. Without it the skills still work on PBIP/TMDL files on disk. Ask whether it is installed; do not open it.

**Motivation:** the MCP server is started with `npx`, so a missing Node.js is the most common reason the server never starts.

### 3. Install

**Claude Code (supported):** tell the user you will add the marketplace and install the plugin for their user, then run:

```text
claude plugin marketplace add armandonettox/powerbi-plugin
claude plugin install powerbi@powerbi-plugin --scope user
```

Inside a session the same steps are `/plugin marketplace add armandonettox/powerbi-plugin` and `/plugin install powerbi@powerbi-plugin`. Confirm with `claude plugin list`: `powerbi@powerbi-plugin` must show `enabled`.

**Other agents:** follow [agents.md](./references/agents.md).

**Motivation:** the plugin installs the MCP server entry and the skills together, so nothing else needs to be copied by hand in Claude Code.

### 4. Handle the license agreement

The server is Microsoft software under its own End User License Agreement: https://go.microsoft.com/fwlink/?LinkId=2381247

Ask the user to read it, then ask which way they choose (one question, with a recommendation):

| Way | How | Saved? |
|---|---|---|
| Environment variable | The user sets `PBI_MODELING_MCP_ACCEPT_EULA=true` for their Windows user, then restarts the agent | No, must be set each time the server starts |
| Command line | The user adds `--accept-eula` to the server's `args` in their own configuration | No, same |
| MCP tool | After the user says they read and accept, call the server's `accept_eula` tool with `eulaUrl` set to the link above | Yes |

Recommend the `accept_eula` tool, because it is the only way that is saved. Call it only after an explicit "I read it and I accept" from the user. Never edit the plugin's own `.mcp.json` to add the flag.

**Motivation:** the flag and the variable are valid only for the running process, so a user who picks them must keep them in place; the tool persists the acceptance.

### 5. Verify

Run the check. It starts the server, performs the MCP handshake and lists the tools. It accepts no license and opens no Power BI file.

```powershell
node "<plugin folder>/skills/powerbi-setup/scripts/check-mcp.mjs"
```

If you only have this file and not the plugin folder, download the script to a temporary folder first:

```powershell
curl.exe -L -o "$env:TEMP\check-mcp.mjs" https://raw.githubusercontent.com/armandonettox/powerbi-plugin/main/skills/powerbi-setup/scripts/check-mcp.mjs
node "$env:TEMP\check-mcp.mjs"
```

- `OK: server ... lists N tools` means the server runs on this machine.
- `FAIL` prints the cause. Use [troubleshooting.md](./references/troubleshooting.md).

Then confirm the agent sees it:

- Claude Code: `claude mcp list` shows `plugin:powerbi:powerbi-modeling-mcp` as connected. A new session lists the skills `powerbi:powerbi-mcp`, `powerbi:power-bi-dax-optimization` and `powerbi:power-bi-screenshot`.
- Other agents: the agent's own MCP list command, see [agents.md](./references/agents.md).

**Motivation:** a successful install command does not prove the server starts. The check separates "installed" from "working", and its output tells the user and you exactly where it broke.

### 6. Report

Finish with a short summary:

- what was installed and the server version;
- the check result (OK or FAIL with the cause);
- what the user still has to do (restart the agent, accept the license, open a model in Desktop);
- what was not tested (for example, any agent other than Claude Code).

Then offer the first step of use: open a model in Power BI Desktop and ask for something small, such as listing its measures. The `powerbi-mcp` skill takes over from there.

## Do not

- Do not run the server with `--accept-eula` yourself to "make the check pass".
- Do not edit the plugin's `.mcp.json` or the user's global agent settings beyond the steps above.
- Do not try to install Power BI Desktop or Node.js without the user asking.
- Do not keep going after the check passes: setup is finished.
