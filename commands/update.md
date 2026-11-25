---
description: Check whether a newer version of the powerbi plugin exists, show what changed, and update it after you confirm
argument-hint: "[check]"
allowed-tools: Bash(claude plugin list:*), Bash(claude plugin marketplace update:*), Bash(claude plugin update:*), Bash(curl:*)
disable-model-invocation: true
---

# Update the powerbi plugin

Arguments: `$ARGUMENTS`

If the argument is `check`, only report (steps 1 to 3 and 6) and change nothing. Otherwise follow every step. Answer in the language the user writes in.

## Rules

- Change nothing before the user confirms in step 4.
- Touch only `powerbi@powerbi-plugin` and the `powerbi-plugin` marketplace. Never update, remove or edit another plugin or the user's settings.
- Never turn auto-update on or off for the user: Claude Code only lets the user do that in its own menu, so explain where.

## Steps

1. **Installed version.** Run `claude plugin list` and find `powerbi@powerbi-plugin`. Report its version and scope. If it is not listed, tell the user the plugin is not installed through the marketplace and show the two install commands from the README, then stop.

2. **Latest version.** Read the version of the main branch:

   ```text
   curl -s https://raw.githubusercontent.com/armandonettox/powerbi-plugin/main/.claude-plugin/plugin.json
   ```

   Take the `version` field. If the request fails, say so and stop: do not guess.

3. **Compare.**
   - Same version: say the plugin is up to date, then go to step 6.
   - Installed is newer than the latest: say so (a local copy or a development version) and go to step 6.
   - Latest is newer: fetch the notes of the newest release and summarize them in a few lines (what is new, anything that needs action from the user):

     ```text
     curl -s https://api.github.com/repos/armandonettox/powerbi-plugin/releases/latest
     ```

     Use the `tag_name` and `body` fields. If there is no release for that version, say the notes are not published yet.

4. **Ask to update.** Show installed version, latest version and the summary, then ask one question: "Update now?". With the `check` argument, stop after saying an update is available and how to run it (`/powerbi:update`).

5. **Update (only after a yes).** Run, in this order:

   ```text
   claude plugin marketplace update powerbi-plugin
   claude plugin update powerbi@powerbi-plugin
   ```

   Then run `claude plugin list` again and confirm the new version. Tell the user the new version loads on the next start, or right away after `/reload-plugins`. If the update command reports an error, show it as is and stop: do not retry in a loop or remove the plugin.

6. **Auto-update status.** Read `~/.claude/plugins/known_marketplaces.json`, find `powerbi-plugin` and report its `autoUpdate` value (empty means the default, which is off for third-party marketplaces). If it is off, explain how to turn it on: run `/plugin`, open the **Marketplaces** tab, select `powerbi-plugin` and turn auto-update on. Do not edit the file.

## Why each step exists

- **Version comes from `plugin.json`, not from the releases page:** Claude Code decides there is an update from the `version` field, so step 2 reads that same field.
- **Confirmation before updating:** an update replaces the installed skills and the MCP entry that other work depends on.
- **Update both the marketplace and the plugin:** refreshing the marketplace only refreshes the listing; the plugin stays on its current version until it is updated.
- **Report the auto-update status instead of changing it:** third-party marketplaces start with it off, and the user is the one who decides to turn it on.
