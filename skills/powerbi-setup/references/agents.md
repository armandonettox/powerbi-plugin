# Setup by agent

Claude Code is the only agent this plugin was built and tested on. The other sections are **best effort and not tested by the author**: they follow each agent's public documentation, mark what could not be confirmed, and always end with the same check, which decides whether it worked.

## Claude Code (supported and tested)

```text
claude plugin marketplace add armandonettox/powerbi-plugin
claude plugin install powerbi@powerbi-plugin --scope user
claude plugin list
claude mcp list
```

- `claude plugin list` must show `powerbi@powerbi-plugin` as `enabled`.
- `claude mcp list` must show `plugin:powerbi:powerbi-modeling-mcp` as connected.
- If the skills or the server do not show up in the current session, restart Claude Code.
- To remove it: `claude plugin uninstall powerbi@powerbi-plugin`, then `claude plugin marketplace remove powerbi-plugin`.

## Codex (best effort, not tested by the author)

Codex has no plugin marketplace like Claude Code's, so the two parts are set up separately: the MCP server and the skills. Both follow OpenAI's public documentation for Codex.

### 1. The MCP server

Ask the user before changing the Codex configuration, then use either way.

**With the command (preferred, Codex writes the entry):**

```text
codex mcp add powerbi-modeling-mcp -- cmd /c npx -y @microsoft/powerbi-modeling-mcp@1.0.1 --start
codex mcp list
```

**By editing `config.toml`:** the entry goes under an `mcp_servers` table in the Codex configuration file:

```toml
[mcp_servers.powerbi-modeling-mcp]
command = "cmd"
args = ["/c", "npx", "-y", "@microsoft/powerbi-modeling-mcp@1.0.1", "--start"]
startup_timeout_sec = 120
```

**Tested** by the author on Codex 0.172.0 on Windows, for the **configuration only**:

- `codex mcp add ... -- cmd /c npx ...` works and writes exactly the `[mcp_servers.powerbi-modeling-mcp]` block above; `codex mcp list` shows it as `enabled`.
- The file is `%USERPROFILE%\.codex\config.toml`, and the folder is created by the first `codex mcp add`. `%APPDATA%\codex` was not used. Setting `CODEX_HOME` moves the file; changing the `USERPROFILE` or `HOME` variables does not, because Codex still used the real profile.
- `startup_timeout_sec` is read: `codex mcp get powerbi-modeling-mcp` prints it. `codex mcp list` does not validate keys (an invented key raised no error), so use `get` to confirm a key.

**Not confirmed:**

- **That Codex starts the server.** `list` only says `enabled`, and a real start needs a login that the test did not use. If it fails with `spawn npx ENOENT` or similar, try `command = "npx"` with `args = ["-y", "@microsoft/powerbi-modeling-mcp@1.0.1", "--start"]`.
- **Start-up time.** The first run downloads the package, and start-up timeouts are reported on Windows, hence the larger `startup_timeout_sec`. Raise it if the first start still times out.
- **The skills folder** `~/.codex/skills` (next section) comes from OpenAI's documentation and was not tried.

A syntax error in the shared `config.toml` can break Codex for every project, so make a copy of the file before editing it by hand.

### 2. The skills

Codex reads skills from folders that contain a `SKILL.md`, for the user in `~/.codex/skills`. The four skills of this plugin use that same format.

```powershell
git clone --depth 1 https://github.com/armandonettox/powerbi-plugin "$env:TEMP\powerbi-plugin-src"
foreach ($name in "powerbi-mcp", "power-bi-dax-optimization", "power-bi-screenshot", "powerbi-setup") {
  Copy-Item -Recurse "$env:TEMP\powerbi-plugin-src\skills\$name" "$env:USERPROFILE\.codex\skills\$name"
}
```

Do not overwrite a folder that already exists: stop and ask the user. Codex detects skill changes by itself; if a skill does not appear, restart Codex. The `power-bi-screenshot` skill refers to `${CLAUDE_PLUGIN_ROOT}` in its command; in Codex use the real path of the copied script instead.

### 3. Verify

Run the check described in the main file. Then `codex mcp list` should list `powerbi-modeling-mcp`.

## Other agents (best effort, not tested by the author)

Any agent that can start a local MCP server over stdio can use the server. The generic entry is:

```json
{
  "mcpServers": {
    "powerbi-modeling-mcp": {
      "command": "cmd",
      "args": ["/c", "npx", "-y", "@microsoft/powerbi-modeling-mcp@1.0.1", "--start"]
    }
  }
}
```

The file name and place depend on the agent; read that agent's documentation instead of guessing. If the agent supports `SKILL.md` folders, copy the skills as shown for Codex. If not, the skills are plain Markdown and can be given to the agent as reference documents: start with `skills/powerbi-mcp/SKILL.md`.

Finish with the check from the main file. If it passes, the server works on this machine; whether the agent can reach it is what the agent's own MCP list must confirm.

**Motivation:** an install guide that claims support it has not verified is worse than none. Marking what was tested and what was not lets the user and the agent decide how much to trust each step, and the check gives a result that does not depend on the agent.
