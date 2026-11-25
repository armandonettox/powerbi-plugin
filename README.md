<p align="center">
  <a href="README.pt-BR.md">Português (Brasil)</a> | <b>English</b>
</p>

<p align="center">
  <img src="docs/cover.png" alt="Illustration of a data model with linked tables feeding a dashboard" width="760">
</p>

<h1 align="center">powerbi-plugin</h1>

<p align="center">
  Work on Power BI semantic models, DAX and report visuals from <a href="https://claude.com/claude-code">Claude Code</a>, with guardrails that ask before anything risky.
</p>

<p align="center">
  <img alt="License: MIT" src="https://img.shields.io/badge/license-MIT-4F5BD5">
  <img alt="Platform: Windows" src="https://img.shields.io/badge/platform-Windows-4F5BD5">
  <img alt="Claude Code plugin" src="https://img.shields.io/badge/Claude%20Code-plugin-E8A317">
</p>

---

## What you get

| Part | What it does |
|---|---|
| **MCP server** `powerbi-modeling-mcp` | Microsoft's server to read and change a semantic model: tables, columns, measures, relationships, DAX queries, partitions, security roles and more. Started with `npx`, never bundled. |
| **Skill** `powerbi-mcp` | Picks the right tool and method to author or inspect a model, DAX and report visuals (PBIR). Ships with 24 reference files: DAX patterns, modeling rules, TMDL, PBIP, and a catalog of common errors with how to prevent them. |
| **Skill** `power-bi-dax-optimization` | Analyzes a DAX formula and proposes a faster, more readable version. |
| **Skill** `power-bi-screenshot` | Takes screenshots of the open Power BI Desktop window, including tooltips shown on hover, and can scroll and click through report pages, so a change can be checked by looking at it. Four scripts, from a silent background capture to a hover-and-click batch. |
| **Skill** `powerbi-setup` | Installs and configures the plugin until it works, then proves it with a check. Meant to be driven by an agent. |
| **Command** `/powerbi:update` | Checks whether a newer version exists, shows the release notes, and updates only after you confirm. |

<p align="center">
  <img src="docs/architecture.svg" alt="How the plugin connects Claude Code to Power BI Desktop, PBIP files and Fabric" width="900">
</p>

## Install

<p align="center">
  <img src="docs/flow-install.svg" alt="Four steps: add the marketplace, install the plugin, accept the Microsoft EULA yourself, ask Claude" width="900">
</p>

In Claude Code:

```text
/plugin marketplace add armandonettox/powerbi-plugin
/plugin install powerbi@powerbi-plugin
```

If the skills or the MCP server do not show up right after installing, restart Claude Code.

### Install with an agent

Prefer to let an agent do it? Paste this into your agent:

```text
Install the Power BI plugin on this computer by following the instructions at
https://raw.githubusercontent.com/armandonettox/powerbi-plugin/main/skills/powerbi-setup/SKILL.md
Tell me what you will change before you change it, and do not accept any license agreement for me.
```

The agent reads the `powerbi-setup` skill, checks Node.js, **looks for Power BI skills, plugins or MCP servers you already have that would clash**, installs, asks you to read and accept the Microsoft license yourself, and ends by running a check that proves the server starts.

If something clashes, the plugin becomes the one that answers, and you lose nothing: the agent shows you the exact list first, backs everything up, only moves, disables or copies (it never deletes), and writes a `RESTORE.md` with the commands to undo each change. Skills of your own that merely use Power BI are left alone.

| Agent | Status |
|---|---|
| Claude Code | Supported and tested |
| Codex and other agents | Best effort, not tested by the author. The skill gives the steps and always ends with the same check, which tells you whether it worked. |

The link points to a file in this repository. Open it first if you want to see what your agent will be told to do.

### Requirements

- **Windows.** This plugin supports Windows only: Power BI Desktop and the screenshot script are Windows-only, and `.mcp.json` starts the server with the Windows form `cmd /c npx`. The Microsoft server is also published for Linux, but that setup is not tested or supported here.
- [Power BI Desktop](https://www.microsoft.com/power-platform/products/power-bi/desktop) for live editing. Without it, the skill can still edit PBIP/TMDL files on disk.
- [Node.js](https://nodejs.org/) (for `npx`). The server is downloaded the first time it runs.
- Claude Code.

### Accept the Microsoft EULA (required)

The Power BI Modeling MCP server is Microsoft software distributed under its own End User License Agreement. This plugin does **not** accept it for you. Read the agreement at <https://go.microsoft.com/fwlink/?LinkId=2381247> and accept it in one of these ways (from the server's own documentation):

| Way | How | Saved? |
|---|---|---|
| Environment variable | Set `PBI_MODELING_MCP_ACCEPT_EULA=true` before starting Claude Code | No, valid for the running process |
| Command line | Add `--accept-eula` to the `args` of the server in your own copy of the MCP configuration | No, valid for the running process |
| MCP tool | Ask Claude to call the server's `accept_eula` tool with the agreement URL | Yes |

## How a change is made

<p align="center">
  <img src="docs/flow-edit-model.svg" alt="You ask, the skill checks the context, connects, changes and tests, and asks you before any refresh or save" width="900">
</p>

1. **You ask** in plain language.
2. **Context check.** The skill looks at the file name and workspace. If the model looks like it belongs to a different context than the current session (for example a company model in a personal session), it stops and asks before connecting.
3. **Connect** to the open Desktop instance. The port changes every time Desktop opens, so the skill looks it up again.
4. **Change and test.** Edits go through the MCP, and the result is checked with a DAX query.
5. **You confirm.** The skill asks before calling Refresh and before editing report JSON while the model is open.

## Try it

Open a model in Power BI Desktop and ask, for example:

- "List the measures of the open model and flag the ones without a description."
- "Create a year-to-date sales measure and put it in the measures table."
- "Why is this matrix slow? Optimize the measure."
- "Take a screenshot of the report and tell me if the legend overlaps the chart."
- "Hover over the tallest bar and show me its tooltip."

The `powerbi-mcp` skill loads on its own when the request is about a semantic model, DAX or a report visual.

## Safety

- **Asks before risky steps.** Refresh and report-JSON edits with the model open need your go-ahead each time. One authorization covers one action, not the next.
- **Context guard.** Stops before connecting when the file or workspace looks like data from another context.
- **Your data stays with you.** The plugin contains no data, no credentials and no Power BI files. The server runs on your machine.
- **Screenshots show what is on screen, including data.** The default script (`bg-capture.ps1`) captures in the background and does not touch your mouse. The hover and click scripts take over the cursor while they run and can click inside the report, so the skill asks before using them. Check an image before sharing it.
- **Telemetry.** The authoring skill comes from Microsoft and keeps its original requirement of an `x-ms-fabric-skill` header on Fabric API calls.

## Troubleshooting

| Problem | What to do |
|---|---|
| The tools do not work on first use | Make sure you accepted the EULA (see above). The variable and the flag must be present every time the server starts. |
| Tools fail after reopening Desktop | The connection is lost and the port changes. Ask Claude to list the local instances and connect again. |
| `npx` is not found | Install Node.js and restart Claude Code. |
| Screenshot shows the wrong window | Ask for the background capture (`bg-capture.ps1`), which captures Desktop even when another window covers it. The simple script (`capture-screenshot.ps1`) copies the screen area, so close or move the covering window. |
| You want a newer server version | The version is pinned in `.mcp.json`. Change it after reading Microsoft's release notes. |

## Updates

Claude Code does not update third-party plugins by itself unless you turn it on.

- **With the command:** run `/powerbi:update`. It shows the installed and the latest version and the release notes, updates after you say yes, and tells you whether auto-update is on. `/powerbi:update check` only reports and changes nothing.
- **Automatic:** in Claude Code run `/plugin`, open the **Marketplaces** tab, select `powerbi-plugin` and turn auto-update on. After that, Claude Code checks shortly after a session starts and tells you when a new version was installed (`/reload-plugins` applies it; otherwise it loads on the next start).
- **Manual:** `/plugin marketplace update powerbi-plugin`, then `claude plugin update powerbi@powerbi-plugin`, then restart or run `/reload-plugins`.

Claude Code reads the `version` in `plugin.json`, not the GitHub release page: a new version reaches you when that number goes up. Release notes are on the [releases page](https://github.com/armandonettox/powerbi-plugin/releases).

## Credits and licenses

This plugin is MIT licensed (see [LICENSE](LICENSE)). It includes MIT-licensed material from Microsoft and GitHub, listed in [NOTICE](NOTICE):

- `semantic-model-authoring` by Microsoft Corporation, from [microsoft/skills-for-fabric](https://github.com/microsoft/skills-for-fabric), included here as `powerbi-mcp`, translated and extended.
- `power-bi-dax-optimization` by GitHub, from [github/awesome-copilot](https://github.com/github/awesome-copilot).

The Power BI Modeling MCP server is not part of this repository and is covered by Microsoft's own EULA.

This is an independent community project and is not affiliated with or endorsed by Microsoft.
