---
name: power-bi-screenshot
description: Takes a screenshot of the open Power BI Desktop window and saves it as a PNG so the result of a report or visual change can be checked by looking at it. Use after editing a report page, a visual or a layout, when the user says "take a screenshot", "show me how it looks", "check the page", or when a change to PBIR/visual JSON needs a visual confirmation. Windows only.
---

# Power BI screenshot

Captures the Power BI Desktop window (process `PBIDesktop`) to a PNG file, then you open the image to look at the report.

## When to use

- After changing a page, a visual or a layout through the report JSON (PBIR) or the MCP, to confirm the result with your own eyes.
- When the user asks how a page looks and Desktop is already open.
- Before and after a visual change, to compare.

Do not use it to read data from the report: use DAX queries through the `powerbi-mcp` skill for numbers.

## How to run

```powershell
powershell -NoProfile -File "${CLAUDE_PLUGIN_ROOT}/skills/power-bi-screenshot/scripts/capture-screenshot.ps1" -Output "$env:TEMP\claude\powerbi-screenshot.png"
```

| Parameter | Default | Meaning |
|---|---|---|
| `-Output` | `%TEMP%\claude\powerbi-screenshot.png` | Where the PNG is saved. The folder is created if missing. |
| `-ProcessName` | `PBIDesktop` | Process whose window is captured. Change it only for a different build of Desktop. |

The script prints the path of the saved file. Open that file (for example with the Read tool, which shows images) to look at it.

## Steps

1. Check that Desktop is open with the right model: `Get-Process PBIDesktop | Select-Object Id, StartTime, MainWindowTitle`. With two reports open, the script captures the first window it finds, so confirm the title first.
2. Run the script. It restores the window if it is minimized and brings it to the front, then waits half a second before capturing.
3. Open the PNG and describe what is on screen. Compare with what the change should have produced.
4. If the screen shows the old version, the window may have started before your edits. Compare the window `StartTime` with the time of the edits, and ask the user to close and reopen the file (see the `powerbi-mcp` skill).

## Limits

- The script captures the screen area where the window is, so another window on top of Desktop appears in the image. It brings Desktop to the front first, which avoids this in most cases.
- It does not click or navigate: to see another page, the user changes the page in Desktop, or you edit which page is active in the report JSON.
- It needs a visible window: with Desktop closed the script exits with an error.

**Motivation:** a report change can look right in the JSON and still render wrong (a hidden field, a wrong theme, a visual outside the page). Looking at the real window is the cheapest way to catch it, and the bring-to-front step exists because a screenshot of a covered window shows the wrong thing.
