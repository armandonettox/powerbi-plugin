# Conflicts with what the user already has

Goal: when setup ends, the powerbi plugin is the **only active provider** of Power BI skills and of the Power BI modeling server, and the user has **lost nothing** of what they used before. Both come from the same procedure: detect, show, back up, change only what the user confirmed, and write down how to undo it.

## Principles

1. **The plugin is the primary one.** Two things that provide the same capability must not stay active together: the agent can pick the old one while the user believes the plugin is working. If the user declines a replacement, say plainly that both stay active and that setup is not complete in that respect.
2. **Nothing is deleted.** Skills are moved to a backup folder, plugins are disabled, and MCP entries are copied to the backup before they are removed. Everything is reversible with the commands in `RESTORE.md`.
3. **Nothing changes before the user confirms an exact list.** Show every item with its location and the action you propose, then ask once.
4. **Things that only use Power BI are not conflicts.** A skill that builds a monthly report from a model is a task that depends on the plugin. Keep it untouched.
5. **Never print secrets.** The detector hides environment values; when you copy an MCP entry to the backup, do not echo it back into the conversation.

**Motivation:** a replacement that silently removes the user's own work, or that leaves a second copy active, is worse than no setup. Backup first and a written restore path make the change safe to accept; keeping our plugin as the single provider makes the result predictable.

## Classify what the detector found

| Kind | Meaning | Default action |
|---|---|---|
| `same-name` skill | A skill with one of our names (`powerbi-mcp`, `power-bi-dax-optimization`, `power-bi-screenshot`, `powerbi-setup`) or Microsoft's original `semantic-model-authoring`, in a folder an agent reads | Move the folder to the backup. If it says "read by other agents (not read by Claude Code)", it does not clash in Claude Code: leave it and tell the user, unless they use that other agent |
| `same-name` MCP | A server entry that runs `powerbi-modeling-mcp` (the VS Code extension executable, an `npx` entry, any name) | Copy the entry to the backup, then remove it |
| `overlap` plugin | Another Power BI or Fabric plugin (for example a Microsoft authoring plugin) | Disable it with `claude plugin disable <id>` |
| `overlap` MCP | Another Power BI or Fabric server | Ask the user: it may be a hosted or Fabric server they need. Default is to leave it and explain the risk of two servers answering |
| `mentions` skill | The user's own task that uses Power BI | Keep. Offer to point its text at `powerbi:powerbi-mcp` if it names the old skill |
| `old-name` permission | Allow rules for the non-plugin server name | Do not carry them over; see below |

If the detector says a file could not be read, the entries in it were not checked: tell the user and ask them to look at that file before you continue.

## Customized skills

A skill the user edited may hold rules they care about. The backup keeps it whole. If it clearly differs from ours, offer one extra step: put only their own additions into a small personal skill with a distinct name (for example `my-powerbi-rules`) that adds to ours instead of repeating it. Do it only if the user asks; never merge their text into the plugin's files.

## Back up

Make one folder for this run and keep everything in it:

```powershell
$backup = Join-Path $env:USERPROFILE (".claude\backups\powerbi-plugin-" + (Get-Date -Format "yyyyMMdd-HHmmss"))
New-Item -ItemType Directory -Force $backup | Out-Null
```

- **Skill folder:** move the whole folder into `$backup\skills\` with `Move-Item`. If it is a symlink, record where it points (`(Get-Item <path>).Target`), then remove only the link: the folder it points to stays where it is.
- **MCP entry:** run `claude mcp get <name>` to see the scope, then save the entry as JSON in `$backup\mcp\<name>.json` (the same fields as in the configuration file, with the environment values it already had: the file stays on this machine, in the user's profile, like the configuration it came from).
- **Plugin:** nothing to copy; note the id and scope so it can be enabled again.

## Apply

Only after the user confirmed the list, one item at a time, checking each result:

| Item | Command |
|---|---|
| Skill folder | `Move-Item <path> $backup\skills\` (symlink: record the target, then remove the link) |
| MCP entry | `claude mcp remove <name> -s <scope>` |
| Plugin | `claude plugin disable <id>` |

## Write `RESTORE.md`

Put a `RESTORE.md` in the backup folder that lists, for each change, the exact command to undo it:

```text
Skill folder: Move-Item "<backup>\skills\<folder>" "<original parent folder>"
Symlink:      New-Item -ItemType SymbolicLink -Path "<original path>" -Target "<recorded target>"
MCP entry:    claude mcp add-json <name> '<the JSON saved in mcp\<name>.json>' -s <scope>
Plugin:       claude plugin enable <id>
```

Tell the user where the folder is. Restoring puts back the old copy, and then the old and the new are active together again, so remind them to disable the plugin or the old copy afterwards.

## Permissions

Allow rules written for the old server name (`mcp__powerbi-modeling-mcp__...`) do not apply to the plugin's server, whose tools are named `mcp__plugin_powerbi_powerbi-modeling-mcp__...`. The user will be asked for permission again the first time. Offer to add the equivalent rules; add them only if the user says yes, and never edit their settings otherwise.

## After the change

1. Run the check from the main file (`check-mcp.mjs`): it must print `OK`.
2. Claude Code: `claude mcp list` shows only `plugin:powerbi:powerbi-modeling-mcp` for Power BI, and a new session lists each of our skills once.
3. Run the detector again. The items you replaced must be gone from `same-name`; anything left is a decision the user made.

## Other agents (best effort, not tested by the author)

The detector also reads `~/.codex/config.toml` and the skill folders under `~/.agents/skills` and `~/.codex/skills`. Apply the same procedure with that agent's own commands and folders, and say what you could not verify.

## Never

- Never delete a skill, plugin or MCP entry, and never overwrite a file of the user's.
- Never replace something without the backup and without the user's confirmation of the exact list.
- Never touch skills that only use Power BI, other plugins, or any setting outside the list.
- Never leave both providers active and report the setup as finished.
