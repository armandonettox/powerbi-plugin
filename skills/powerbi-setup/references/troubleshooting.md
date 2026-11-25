# Setup troubleshooting

Find the symptom, apply the fix, then run the check again. Stop when it prints `OK`.

| Symptom | Likely cause | What to do |
|---|---|---|
| `FAIL: could not start "cmd"` or `"npx"` | Node.js or npx is not installed, or not on the PATH | Install Node.js from https://nodejs.org/, open a new terminal so the PATH updates, and run the check again. |
| `FAIL: no answer after 120s` on the first run | The first run downloads the package | Run the check once more. If it fails again, check the internet connection and any proxy that blocks `npm`. |
| `npm error code ETARGET ... No matching version found` | The pinned server version does not exist or was withdrawn | Run `npm view @microsoft/powerbi-modeling-mcp versions` and ask the user before changing the version in `.mcp.json`. |
| `npm error` about network, certificate or registry | A proxy or company network blocks npm | Do not work around it. Tell the user what the error says; they or their IT decide. |
| The check says `OK` but the tools do not work in the agent | The license agreement is not accepted | Go back to step 5 of the main file. The variable and the flag must be present every time the server starts; `accept_eula` is saved. |
| `claude plugin list` does not show `powerbi@powerbi-plugin` | The install did not finish | Run the two install commands again and read their output. |
| The plugin shows but the skills are not listed | The session started before the install | Restart Claude Code and ask again. |
| `claude mcp list` says `Failed to connect ... connection timed out after 30000ms`, but `check-mcp.mjs` prints `OK` | The server is slow to start (`npx` plus the .NET server), which happens on a busy machine: on the author's, with high CPU and little free memory, it took 24 to 31 s, just over the 30 s limit | Close heavy programs and retry. If it persists, start Claude Code with a longer limit, for example `MCP_TIMEOUT=90000` (milliseconds); checked on the author's machine, where it made the server connect. The variable is in Claude Code's MCP documentation; reports say values above 60 s may not be honored. Tell the user how long `check-mcp.mjs` took |
| `claude mcp list` does not show `plugin:powerbi:powerbi-modeling-mcp` as connected | The server failed to start inside the agent | Run the check. If it passes, restart Claude Code; if it fails, use its message above. |
| Another Power BI MCP entry with the same tools appears (for example `powerbi-modeling-mcp` from a VS Code extension) | Two copies of the server are configured | Run the detector (step 3 of the main file) and follow [conflicts.md](./conflicts.md): back up, replace with the user's confirmation so the plugin is the only active provider, and write `RESTORE.md`. Never remove either copy without the backup and that confirmation. |
| Tools fail after the user reopens Power BI Desktop | The connection is lost and the port changes at every open | Not a setup problem: ask the agent to list the local instances and connect again. |
| Linux or macOS | The plugin supports Windows only | Stop. Say so, and mention the generic entry in [agents.md](./agents.md) as an unsupported option. |

## When nothing here matches

Show the user the exact output of the check and of the failing command, say what you already tried, and stop. Do not install other software, edit global settings or disable security tools to get past an error.

**Motivation:** most setup failures come from the machine (Node.js, network, proxy, license), not from the plugin. Naming the likely cause saves the user a long search, and stopping at the edge of the table avoids an agent making the machine worse while trying to be helpful.
