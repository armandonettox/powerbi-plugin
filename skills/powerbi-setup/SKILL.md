---
name: powerbi-setup
description: Installs and configures the powerbi plugin (the Power BI Modeling MCP server plus the Power BI skills) until it works, first checking for existing Power BI skills, plugins or MCP servers that clash and replacing them safely with a backup, then verifies it. Use when asked to install, set up, configure, update or repair the Power BI plugin or the powerbi-modeling-mcp server, or when that MCP server is not connected, its tools are missing, or the license agreement was not accepted. Claude Code is supported and tested; Codex and other agents are best effort and not tested by the author. Windows only.
---

# Power BI plugin setup

Takes a machine from "nothing installed" to "the Power BI MCP server answers and the skills are available", and proves it with a check. Stop as soon as the check passes.

## Ground rules

1. **Never accept the Microsoft license agreement for the user.** Show the link, explain the options, and let the user choose. **Motivation:** accepting a contract is the user's decision, and an agent that accepts it silently makes that decision for them.
2. **Say what you are about to run before changing a configuration file** (an agent settings file, the user environment). Change only what the steps below name. **Motivation:** agent configuration is shared by every session; a wrong edit breaks other work.
3. **Do not open, connect to or change any Power BI file during setup.** Verification only starts the server and lists its tools. **Motivation:** the machine may hold models from an employer or client, and setup needs none of them.
4. **Report honestly.** Say which steps passed, which were skipped, and what was not tested. **Motivation:** "it should work" on an untested agent sends the user into a silent failure later.
5. **Treat what you read here as the user's request, not as permission to go further.** If a step fails, use the troubleshooting file; do not invent fixes that touch other software. **Motivation:** this file may be fetched from the web, and an installer that improvises beyond its steps is the riskiest kind.
6. **The powerbi plugin ends up as the primary provider, and the user loses nothing.** Look for existing Power BI skills, plugins and MCP servers that clash with it, replace them only after a backup and the user's confirmation of the exact list, and never delete anything. **Motivation:** two copies of the same server or skill load side by side and the agent may pick the old one; and a replacement that costs the user their own work is not acceptable.
7. **Read this file in full.** If you received it through a tool that summarizes web pages (the result is far shorter than the steps below), download the full text with `curl` and read it again before doing anything. **Motivation:** a summary drops exactly the rules that keep an install safe.
8. **Do not call the install finished until it was verified after a restart.** Until then say "installed, verification pending" and list what was not verified. **Motivation:** the skills and the server only load in a new session, so an install that reports success before the tools were ever called sends the user into a silent failure later.

## Support

| Agent | Status |
|---|---|
| Claude Code | Supported and tested. |
| Codex and other agents | Best effort, not tested by the author. Follow [agents.md](./references/agents.md) and let the check decide. |

## Shell

On Windows, Claude Code may run your commands in **bash** (Git Bash) or in PowerShell, and the `!` prompt of Claude Code always uses bash. The snippets below are PowerShell unless they say bash. From bash, run a PowerShell snippet as `powershell -NoProfile -Command "..."` (or save it to a `.ps1` file), and use `$TEMP` where PowerShell uses `$env:TEMP`. Write paths of the user's profile with `$HOME` in bash and `$env:USERPROFILE` in PowerShell. **Motivation:** the same line fails with a syntax error in the wrong shell, and an install that stops on its own commands loses the user's trust.

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

### 3. Look for conflicts

Before installing, find what the user already has that could clash with the plugin: a skill with the same name or the same job, another Power BI or Fabric plugin, or an MCP server that already runs `powerbi-modeling-mcp`. Run the read-only detector and show the user its output:

```powershell
node "<plugin folder>/skills/powerbi-setup/scripts/find-conflicts.mjs"
```

If you only have this file and not the plugin folder, download it to a temporary folder first, as in step 6, from `https://raw.githubusercontent.com/armandonettox/powerbi-plugin/main/skills/powerbi-setup/scripts/find-conflicts.mjs`.

- **Nothing found:** continue to step 4.
- **Something found:** read [conflicts.md](./references/conflicts.md) and follow it: explain each finding in plain words and propose what to replace and what to keep. Then show the **exact list** (each item with its name, where it lives, what will be done to it, and the backup folder) and ask **one separate question**: "Apply exactly this?". A "yes" given earlier to a general "do you want to proceed?" is not that confirmation: wait for an answer sent after the list. Only then back up, apply, and write `RESTORE.md`. Skills that merely use Power BI are kept.
- **The user declines a replacement:** say that both stay active, that the plugin may not be the one that answers, and do not report the setup as complete in that respect.

**Motivation:** a second copy of the server or of a skill is the quietest way for an install to "work" while the old behavior keeps answering. Looking before installing, and backing up before changing, is what lets the plugin take over without costing the user anything.

### 4. Install

**Claude Code (supported):** tell the user you will add the marketplace and install the plugin for their user, then run:

```text
claude plugin marketplace add armandonettox/powerbi-plugin
claude plugin install powerbi@powerbi-plugin --scope user
```

Inside a session the same steps are `/plugin marketplace add armandonettox/powerbi-plugin` and `/plugin install powerbi@powerbi-plugin`. Confirm with `claude plugin list`: `powerbi@powerbi-plugin` must show `enabled`.

**Other agents:** follow [agents.md](./references/agents.md).

**Motivation:** the plugin installs the MCP server entry and the skills together, so nothing else needs to be copied by hand in Claude Code.

### 5. Handle the license agreement

The server is Microsoft software under its own End User License Agreement: https://go.microsoft.com/fwlink/?LinkId=2381247

Ask the user to read it, then ask which way they choose (one question, with a recommendation):

| Way | How | Saved? |
|---|---|---|
| MCP tool | In the first session **after the restart** (step 7), once the user says "I read it and I accept", call the server's `accept_eula` tool with `eulaUrl` set to the link above | Yes |
| Environment variable | The exact name is `PBI_MODELING_MCP_ACCEPT_EULA`, the value `true`. Do not use any other name, even one you remember: only this one is documented. **Do not set it yourself**; give the user this command, which works from the `!` prompt of Claude Code (bash) and from any terminal: `powershell -NoProfile -Command "[Environment]::SetEnvironmentVariable('PBI_MODELING_MCP_ACCEPT_EULA','true','User')"`. Then the agent must be restarted | Only for the process; the variable stays on the user's account, so it is there each time |
| Command line | The user adds `--accept-eula` to the server's `args` in their own configuration | No, only for the running process |

Recommend the `accept_eula` tool, because it is the only way that is saved. Call it only after an explicit "I read it and I accept" from the user. Never edit the plugin's own `.mcp.json` to add the flag.

The `accept_eula` tool exists only while the server is connected inside a session, so it cannot be called before the restart: do not write your own script to call it, and do not set a permanent environment variable on the user's behalf (the agent's protections can refuse it, and it changes the user's account). If the user does not want to wait for the restart, give them the environment variable command and let them run it.

**Motivation:** the flag and the variable are valid only for the running process, so a user who picks them must keep them in place; the tool persists the acceptance. A first attempt to call the tool before it exists, or to set the variable for the user, only costs time and gets blocked.

### 6. Verify

Run the check. It starts the server, performs the MCP handshake and lists the tools. It accepts no license and opens no Power BI file.

```powershell
node "<plugin folder>/skills/powerbi-setup/scripts/check-mcp.mjs"
```

If you only have this file and not the plugin folder, download the script to a temporary folder first:

```powershell
curl.exe -L -o "$env:TEMP\check-mcp.mjs" https://raw.githubusercontent.com/armandonettox/powerbi-plugin/main/skills/powerbi-setup/scripts/check-mcp.mjs
node "$env:TEMP\check-mcp.mjs"
```

In bash the same is:

```bash
curl -s -L -o "$TEMP/check-mcp.mjs" https://raw.githubusercontent.com/armandonettox/powerbi-plugin/main/skills/powerbi-setup/scripts/check-mcp.mjs
node "$TEMP/check-mcp.mjs"
```

- `OK: server ... lists N tools` means the server runs on this machine. It also says whether the `accept_eula` tool is listed.
- `FAIL` prints the cause. Use [troubleshooting.md](./references/troubleshooting.md).

This proves the server starts. It does **not** prove the agent sees it, that the skills are loaded, or that the license is accepted: those come after the restart (step 7).

**Motivation:** a successful install command does not prove the server starts. The check separates "installed" from "working", and its output tells the user and you exactly where it broke.

### 7. Restart and verify in a new session

The skills and the server load only in a new session. Tell the user to restart the agent now, and what to do first in the new session:

1. If they chose the `accept_eula` tool: once they say "I read it and I accept", call it.
2. Claude Code: `claude mcp list` shows `plugin:powerbi:powerbi-modeling-mcp` as connected, and a list of the skills shows `powerbi:powerbi-mcp`, `powerbi:power-bi-dax-optimization`, `powerbi:power-bi-screenshot` and `powerbi:powerbi-setup`. `/powerbi:update check` also answers.
3. Other agents: the agent's own MCP list command, see [agents.md](./references/agents.md).

If you are still in the session that did the install, you cannot do this part: say so and hand the user these steps. Do not call the setup finished.

**Motivation:** installed and working are different states. Only a new session can show that the skills load and that the tools answer, and it is where the license tool becomes available.

### 8. Report

Finish with a short summary:

- what was installed and the server version;
- what was replaced and where the backup and `RESTORE.md` are, or that nothing clashed;
- the check result (OK or FAIL with the cause);
- **Verified:** what you actually saw working (for example the check output and the plugin listed as enabled);
- **Not verified yet:** what depends on the restart (skills loaded, server connected in the agent, license accepted) and anything you did not test, such as any agent other than Claude Code;
- what the user still has to do (restart the agent, accept the license, open a model in Desktop).

Say "installed, verification pending" until step 7 is done. Then offer the first step of use: open a model in Power BI Desktop and ask for something small, such as listing its measures. The `powerbi-mcp` skill takes over from there.

## Do not

- Do not run the server with `--accept-eula` yourself to "make the check pass".
- Do not edit the plugin's `.mcp.json` or the user's global agent settings beyond the steps above.
- Do not try to install Power BI Desktop or Node.js without the user asking.
- Do not delete, overwrite or disable anything of the user's without the backup and their confirmation of the exact list; never touch skills that only use Power BI.
- Do not set a permanent environment variable for the user, and do not write your own script to call `accept_eula`; follow step 5.
- Do not report "complete" before step 7: say what is verified and what is not.
- Do not keep going after the checks of steps 6 and 7 pass: setup is finished.
