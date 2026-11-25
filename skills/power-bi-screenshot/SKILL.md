---
name: power-bi-screenshot
description: Takes screenshots of the open Power BI Desktop window, including tooltips shown on hover, and can scroll and click through report pages, so the result of a report or visual change can be checked by looking at it. Use after editing a report page, a visual or a layout, when the user says "take a screenshot", "show me how it looks", "check the page", "show the tooltip", or when a change to PBIR/visual JSON needs a visual confirmation. Windows only.
---

# Power BI screenshot

Captures the Power BI Desktop window (process `PBIDesktop`) to PNG files, then you open the images to look at the report. Four scripts cover four situations; pick the least invasive one that does the job.

## Choosing the script

| You need | Script | Takes over the mouse? |
|---|---|---|
| Look at the current page, with no interference | `bg-capture.ps1` | No. Captures in the background, without moving the window to the front or touching the cursor |
| A tooltip on one point | `hover-screenshot.ps1` | Yes. Moves the real cursor and brings the window to the front |
| Tooltips on several points, scrolling, or going through pages | `hover-batch.ps1` | Yes. Moves the cursor, scrolls and **clicks**; gives the cursor and the focus back at the end |
| A simple capture of the window as it appears on screen | `capture-screenshot.ps1` | No, but it brings the window to the front |

Start with `bg-capture.ps1`. Use the others only when a tooltip, a scroll or a click is really needed.

## Rules for the agent

1. **Ask before running a script that moves the mouse or clicks** (`hover-screenshot.ps1`, `hover-batch.ps1`). Tell the user it will take over the cursor for the duration, and that they should not touch the mouse or keyboard until it ends. **Motivation:** the scripts use real input events, and a person typing or moving the mouse at the same time breaks the capture and may click the wrong thing.
2. **Clicks can change the report** (page, filter, selection). Choose click targets from a snapshot, click only on navigation, and never on buttons that write, refresh or publish. **Motivation:** a click is an action on the user's session, not a read.
3. **Check the context before capturing.** The image shows what is on the screen, including data. If the model looks like it belongs to a different context than the current session (for example a company model in a personal session), stop and ask first, and do not share the image. **Motivation:** a screenshot moves data into the conversation just like a query does.
4. **Confirm which report is open** before capturing: `Get-Process PBIDesktop | Select-Object Id, StartTime, MainWindowTitle`. With two reports open the scripts use the first window they find. **Motivation:** capturing the wrong report looks like a successful capture.
5. **Open the image and say what you see.** Compare it with what the change should have produced, and say so when it does not match. If the screen shows the old version, the window may have started before your edits: compare its `StartTime` with the time of the edits and ask the user to close and reopen the file (see the `powerbi-mcp` skill). **Motivation:** the point of the capture is the comparison; a saved file nobody looked at proves nothing.

## `bg-capture.ps1` (background, default choice)

```powershell
powershell -NoProfile -File "${CLAUDE_PLUGIN_ROOT}/skills/power-bi-screenshot/scripts/bg-capture.ps1" -Output "$env:TEMP\claude\powerbi-bg.png"
```

| Parameter | Default | Meaning |
|---|---|---|
| `-Output` | `%TEMP%\claude\powerbi-bg.png` | Where the PNG is saved. |
| `-HoverX`, `-HoverY` | off | Point in the captured image to hover, sent as mouse-move window messages to the report surface, without moving the real cursor. |
| `-WaitMs` | `1500` | How long to wait after the hover before capturing. |
| `-Info` | off | Also prints the size of the main window and of each report surface, to help choose coordinates. It does not skip the capture: the image is still saved at `-Output`, so delete it if you do not need it. |

It uses `PrintWindow`, so a window covering Desktop does not appear in the image. `PrintWindow` does not include floating tooltip windows: when a tooltip does not appear with `-HoverX`/`-HoverY`, use `hover-screenshot.ps1` or `hover-batch.ps1`, which capture the screen.

## `hover-screenshot.ps1` (one tooltip)

```powershell
powershell -NoProfile -File "${CLAUDE_PLUGIN_ROOT}/skills/power-bi-screenshot/scripts/hover-screenshot.ps1" -X 1190 -Y 1660 -Output "$env:TEMP\claude\powerbi-hover.png"
```

| Parameter | Default | Meaning |
|---|---|---|
| `-X`, `-Y` | required | **Screen** coordinates of the point (the whole desktop, not the window). |
| `-Output` | `%TEMP%\claude\powerbi-hover.png` | Where the PNG is saved. |
| `-ProcessName` | `PBIDesktop` | Process whose window is captured. |
| `-WaitMs` | `1800` | How long the cursor rests on the point before the capture. |

It brings the window to the front, approaches the point in small steps so the visual sees a real mouse move, waits for the tooltip and captures the window area of the screen.

## `hover-batch.ps1` (several points, scroll, pages)

```powershell
powershell -NoProfile -File "${CLAUDE_PLUGIN_ROOT}/skills/power-bi-screenshot/scripts/hover-batch.ps1" -Targets "snapshot" -OutDir "$env:TEMP\claude\hover"
powershell -NoProfile -File "${CLAUDE_PLUGIN_ROOT}/skills/power-bi-screenshot/scripts/hover-batch.ps1" -Targets "bar-first:570:583;bar-second:640:583" -OutDir "$env:TEMP\claude\hover"
```

| Parameter | Default | Meaning |
|---|---|---|
| `-Targets` | required | `snapshot`, or targets separated by `;` in the form `name:x:y`. Coordinates are **pixels of the window image**, not screen coordinates. |
| `-OutDir` | required | Folder for the images, one `<name>.png` per target. |
| `-WaitMs` | `1600` | How long to wait on each target before capturing. |
| `-CropW`, `-CropH` | `760`, `520` | Accepted but not used: the whole window is saved, because the tooltip opens beside the cursor and a fixed crop cut it in half. |

Special target names:

| Name | Form | What it does |
|---|---|---|
| `snapshot` (the whole `-Targets` value) | `snapshot` | Saves one image of the window with no cursor movement. Use it first to pick coordinates. |
| `scroll-<name>` | `scroll-list:x:y:notches` | Moves to the point and turns the wheel; negative notches scroll down. |
| `click-<name>` | `click-next:x:y` | Clicks, moves the cursor away so no tooltip stays open, and waits at least 3.5 s for the page to draw. |
| `click-fast-<name>` | `click-fast-tab:x:y` | Same click, but waits only `-WaitMs`. |
| `ctrlclick-<name>` | `ctrlclick-go:x:y` | Ctrl+click, which Desktop needs to follow a button in a report. |

It saves the cursor position and the active window first, and gives both back at the end, also when something fails. It prints the cursor position it reached for each target and the path of the image.

## `capture-screenshot.ps1` (simple capture)

```powershell
powershell -NoProfile -File "${CLAUDE_PLUGIN_ROOT}/skills/power-bi-screenshot/scripts/capture-screenshot.ps1" -Output "$env:TEMP\claude\powerbi-screenshot.png"
```

| Parameter | Default | Meaning |
|---|---|---|
| `-Output` | `%TEMP%\claude\powerbi-screenshot.png` | Where the PNG is saved. |
| `-ProcessName` | `PBIDesktop` | Process whose window is captured. |

It copies the area of the screen where the window is, after bringing the window to the front. If Windows refuses to bring it to the front, another window on top appears in the image, so prefer `bg-capture.ps1`.

## Limits

- Windows only, and Desktop must have a visible window: with Desktop closed the scripts exit with an error.
- Coordinates depend on the window size and on the screen scaling. After the user resizes the window or moves it to another screen, take a new snapshot before choosing points.
- Hover and click scripts can fail silently when the first mouse move after a focus change is lost; `hover-batch.ps1` repeats the approach and prints where the cursor really arrived, so read that line.
- The scripts that copy the screen (`hover-screenshot.ps1`, `hover-batch.ps1`, `capture-screenshot.ps1`) copy the rectangle of the window, and the Windows frame has a few invisible pixels at the edges: whatever is behind the window can show in those edges. A maximized Desktop has no such strip, and `bg-capture.ps1` never has it.
- The scripts pick the largest visible window of the process and ignore tool windows such as tooltips, so a tooltip left on screen does not become "the window" to capture.
- All four scripts declare that they respect the screen scaling. Without it, a screen scaled above 100% puts the cursor and the crop in the wrong place.
- The images may contain data: save them in a temporary folder and delete them when the check is done.

## What was tested

The four scripts were run against a neutral test window with a button, a bar with a tooltip and a scrolling list, which logged the real mouse events it received. Hover reached the bar and the tooltip appeared in the image, the click changed the page, the wheel scrolled the list, the cursor was given back, and every image had the exact size of the window. That run also found and fixed two defects: a missing DPI declaration, and the choice of a leftover tooltip as the window to capture.

It was not run against Power BI Desktop. What is specific to it was written and used by the author, but is not covered by that test: hovering a visual with `-HoverX`/`-HoverY` through window messages, Ctrl+click on report buttons, and the way its own tooltips are drawn.

**Motivation:** a report change can look right in the JSON and still render wrong (a hidden field, a wrong theme, a visual outside the page, a tooltip showing the wrong measure). Looking at the real window is the cheapest way to catch it. The scripts exist in four levels of invasiveness because a capture that takes over the user's mouse has a cost, and most checks do not need it.
