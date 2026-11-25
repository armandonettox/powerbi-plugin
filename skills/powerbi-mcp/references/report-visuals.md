# Power BI Report Visuals (PBIR)

Reference material for the `powerbi-mcp` skill, for use when working with Power BI reports in the PBIR format (Power BI enhanced Report format) used by modern PBIP projects. It covers where each thing lives in the JSON, a catalog of visuals with when to use each one, step-by-step file editing, and dashboard design best practices.

## 1. PBIR format overview

A modern PBIP project with PBIR enabled has this structure inside `[Name].Report/`:

```text
[Name].Report/
├── definition.pbir              # points to the semantic model (byPath or byConnection)
├── report.json                  # legacy (PBIR-Legacy) -- does not exist if PBIR is active
├── .platform
├── StaticResources/
├── CustomVisuals/
└── definition/                  # only exists in PBIR (modern)
    ├── version.json
    ├── report.json              # report metadata (report-level filters/formatting)
    ├── reportExtensions.json     # report-level measures, etc.
    ├── pages/
    │   ├── pages.json           # page order, active page
    │   └── [pageName]/
    │       ├── page.json        # page filters and formatting
    │       └── visuals/
    │           └── [visualName]/
    │               ├── visual.json      # this is the file that defines the visual
    │               └── mobile.json      # mobile-specific layout (optional)
    └── bookmarks/
        ├── bookmarks.json
        └── [bookmarkName].bookmark.json
```

Golden rule: each visual lives in its own folder with a `visual.json`. This is what makes PBIR "diff friendly" -- moving, copying or editing a visual does not touch the other files.

### Where each thing lives

| I need to change... | File |
|---|---|
| Visual type, fields, formatting, position of ONE visual | `pages/[page]/visuals/[visual]/visual.json` |
| Page-level filter, page theme/background | `pages/[page]/page.json` |
| Report-level filter, report base theme | `definition/report.json` |
| Page order, which page opens by default | `pages/pages.json` |
| Which semantic model the report is connected to | `definition.pbir` (root) |
| Bookmarks (saved state of filters/selections) | `bookmarks/[name].bookmark.json` |

### Schema and validation

Every PBIR file has a `$schema` at the top pointing to a public JSON Schema in `github.com/microsoft/json-schemas` (folder `fabric/item/report/definition/`). Opening the file in VS Code with the JSON extension gives IntelliSense and automatic validation -- always prefer editing this way over editing blind.

Best practices when editing manually:
- Always keep the `$schema` and the `version` of the original file.
- Edit a single `visual.json` when you only want to change that visual -- there is no need to touch `report.json` or `page.json`.
- Default to the safe behavior: close Power BI Desktop before editing the files manually, and reopen it afterwards. Newer Desktop versions detect external changes to PBIP/PBIR files, so closing is a precaution for the case where the model has unsaved changes, not an absolute requirement. If the project is open with unsaved changes, Desktop may overwrite external edits.
- If the user explicitly asks not to close Desktop: re-read the file immediately before each `Edit` (never reuse a read from a previous message) and re-read afterwards to confirm the change survived -- Desktop can rewrite `visual.json` on its own even if the user did not save.

Avoid:
- Editing `report.json` (PBIR-Legacy) manually -- that format is not publicly documented and has no stable schema. If the project still uses PBIR-Legacy, convert it to PBIR first (in Power BI Desktop options, preview feature "Store reports using enhanced metadata format (PBIR)").
- Manually inventing visual folder/file names without need -- the name is an auto-generated 20-character ID; renaming is supported but can break references (bookmarks, drillthrough, tooltips) if not done carefully.
- Editing `mobileState.json` or `semanticModelDiagramLayout.json` -- they have no supported external editing.

## 2. Visual catalog: when to use and when to avoid

| Visual | When to use | When to avoid |
|---|---|---|
| Card | A single highlighted metric (top-of-page KPI: total revenue, customer count). Quick answer to "what is the number?" | When there are more than 3-4 metrics -- it becomes a "wall of cards" with no context. It shows neither trend nor comparison. |
| Multi-row card | A short list of metrics per category (e.g. top 5 products with value). | When the list is long or needs interactive sorting/filtering -- use a table. |
| Table | Detailed data, exact values the user will copy/check, multiple heterogeneous columns (text + number). Good for auditing and "I want to see the exact numbers". | Visual comparison of magnitude across categories (a bar chart communicates that faster). Many rows without pagination/scrolling become unreadable. |
| Matrix | Hierarchical/crossed data (category x subcategory x period), with subtotals and drill-down. Ideal for a "pivot table". | When there is no real hierarchy -- in that case a simple table is more direct. |
| Bar/column chart | Compare values across categories. Columns (vertical) when category names are short or in time order; bars (horizontal) when category labels are long (product names, customers). | Long, continuous time series (prefer line) or many categories (more than 15-20) -- it becomes unreadable, consider Top N + "Other". |
| Line chart | Trend over time, continuous evolution, comparison of a few time series. | Comparing categories without a time axis (use bars). Many overlapping lines (more than 5-6 series) are confusing -- consider small multiples or a filter. |
| Combo chart (line + column) | Two related metrics with different scales (e.g. sales volume as columns + margin % as a line). | When the two metrics have no logical relationship that justifies the dual axis -- a dual axis can mislead visually (changing the scale changes the perceived relationship). |
| Pie / Donut | Part-to-whole composition with few categories (ideally 2-4, at most 6-8), when the point is to show the proportion of a total, not to compare absolute values with each other. | Avoid almost always with more than 5-6 categories, when categories have similar values (the human eye discriminates angles poorly), or when the goal is comparison (bars are always better then -- comparing position/length is more precise than comparing area/angle). SQLBI recommends treating pie charts as an exception, not the default. |
| Map (Map/Filled map/Shape map) | Data with an explicit geographic component that is relevant to the business context (distribution by state, region, country). | When geography is not the central point of the analysis -- then the map is decoration and a table/sorted bar communicates the values better. |
| Scatter | Relationship/correlation between two continuous numeric variables, optionally with a third dimension (bubble size) or category (color). Good for spotting outliers and clusters. | Few data points (no pattern to see) or when the audience is not familiar with reading scatter plots. |
| KPI | A metric with a defined goal/target, showing current value, trend (sparkline) and progress toward the goal in a single compact visual. | When there is no real goal defined -- then it is just a card with a sparkline, use a Card. |
| Gauge | Progress of a single metric against a target/limit, in an executive context with little space. | Comparing multiple items (gauges do not stack well) or when value precision matters more than the "feel" of progress -- then a KPI or a card + goal in a table is better. |
| Slicer | A visible interactive filter on the page, giving the user direct control over what is displayed (period, category, region). | Many stacked slicers that take up more space than the analytical content -- consider page/report filters for what does not need to be manipulated constantly. |
| Decomposition tree | Exploratory investigation: "why is this number this value?" -- lets the user choose the breakdown dimension dynamically, with AI suggestion (highest value / largest contribution). | When the analysis path is already known and fixed -- then a matrix or hierarchical bar chart is more predictable and quicker to read. |
| Key influencers | Understand which variables most influence (positively or negatively) a binary or continuous metric -- uses logistic regression/decision trees behind the scenes. Good for "what impacts customer satisfaction?". | When the causal relationship is already known/obvious, or the dataset is too small for the statistical model to be significant. |
| Q&A | One-off exploration in natural language for users who do not navigate structured reports well, or to quickly find a visual during a meeting. | As a fixed visual in a production dashboard -- Q&A depends on synonyms/well-named fields, and is not a consistent reading surface for all users. |
| Custom visuals (AppSource/organization) | A specific need not covered by native visuals (e.g. Sankey chart, heat calendar, dynamic text visual). | Avoid over-customizing the dashboard with third-party visuals without real need -- each custom visual increases load time and the risk of breaking on Power BI updates. Always prefer native when native solves it. |

## 3. How to edit/create a visual in the JSON

### Minimal structure of a visual.json

Based on the official `visualContainer` schema (folder `definition/report/definition/visualContainer/` in the `microsoft/json-schemas` repository):

```json
{
  "$schema": "https://developer.microsoft.com/json-schemas/fabric/item/report/definition/visualContainer/2.1.0/schema.json",
  "name": "a1b2c3d4e5f6g7h8i9j0",
  "position": {
    "x": 40,
    "y": 60,
    "width": 320,
    "height": 240,
    "z": 1000,
    "tabOrder": 1000
  },
  "visual": {
    "visualType": "columnChart",
    "query": {
      "queryState": {
        "Category": {
          "projections": [
            { "field": { "Column": { "Expression": { "SourceRef": { "Entity": "Product" } }, "Property": "Category" } }, "queryRef": "Product.Category", "active": true }
          ]
        },
        "Y": {
          "projections": [
            { "field": { "Measure": { "Expression": { "SourceRef": { "Entity": "Sales" } }, "Property": "Total Sales" } }, "queryRef": "Sales.Total Sales", "active": true }
          ]
        }
      }
    },
    "objects": {
      "title": [
        {
          "properties": {
            "text": { "expr": { "Literal": { "Value": "Sales by Category" } } }
          }
        }
      ]
    }
  }
}
```

### Axis with a hierarchy (drill-down)

To use a hierarchy (`user_hierarchy_operations` in TOM) on a Category/Values axis instead of a standalone column, each field uses `HierarchyLevel` (not `Column`). **Critical rule: list ONE projection PER LEVEL of the hierarchy, in order from highest to lowest, with `active: true` only on the last (lowest) level and `active: false` on the others.** Omitting the intermediate levels (declaring only the active level) raises no error at all -- Power BI Desktop accepts and saves it silently, but the visual shows only that single flat level, with no drill-down arrow (same caution as the "Uncertain formatting property name" paragraph further below: a silent failure, not a visible error):

```json
{
  "field": {
    "HierarchyLevel": {
      "Expression": {
        "Hierarchy": {
          "Expression": { "SourceRef": { "Entity": "dim_calendar" } },
          "Hierarchy": "Date Hierarchy"
        }
      },
      "Level": "Year"
    }
  },
  "queryRef": "dim_calendar.Date Hierarchy.Year",
  "nativeQueryRef": "Year",
  "active": false
}
```

`Level` uses the **name of the hierarchy level** (defined in TOM), not the name of the column behind it -- the two can differ (e.g. a "Month" level pointing to a `YearMonth` column formatted as text "September 2026" for display, keeping the level name stable even if the column is swapped). Every projection must also carry `queryRef` and `active` (see the projection rule under "Cautions" below).

Recreating or editing the hierarchy via TOM/MCP (`user_hierarchy_operations`) **while Power BI Desktop is open** can leave the visual's `HierarchyLevel` field binding stuck on the old version (model/DAX correct, but the chart on screen does not reflect the change) -- just exporting to TMDL does not fix it; you need to close and reopen Desktop to force the binding to be re-resolved.

### Main fields

| Field | Required | Description |
|---|---|---|
| `$schema` | Yes | URL of the schema version used. Always keep it in line with what Power BI Desktop generated. |
| `name` | Yes | Unique identifier of the visual on the page (up to 50 characters). Auto-generated, editable with caution. |
| `position` | Yes | `x`, `y`, `width`, `height` required; `z` (stacking order), `tabOrder` (keyboard navigation order) and `angle` optional. |
| `visual` | One of the two (`visual` or `visualGroup`) | Contains `visualType` (string, e.g. `columnChart`, `card`, `tableEx`, `pieChart`, `slicer`), `query` (fields used, grouped by visual "role": Category, Y, Series...), `objects` (formatting: title, colors, axes, etc.) |
| `visualGroup` | Alternative to `visual` | Marks the container as a grouper of other visuals (not both together). |
| `filterConfig` | No | Filters applied only to this visual, in addition to page/report filters. |
| `isHidden` | No | Hides the visual (used, for example, in bookmarks or tooltip support visuals). |
| `howCreated` | No | Tracks origin (Copilot, drag and drop, etc.) -- informational. |
| `annotations` | No | Free name-value pairs, ignored by Power BI Desktop but useful for external scripts (e.g. marking the default page for deployment). |

### Practical steps to edit an existing visual

1. Recent versions of Power BI Desktop detect external changes to PBIP project files (visual.json, page.json, hand-edited TMDL) and reload on their own -- **closing Desktop to edit a file directly is a precaution, not a requirement** (for example when the model has unsaved changes). The exception is when the change is made **via MCP/TOM instead of via file** (e.g. recreating an entire table with `table_operations Create/Delete`) -- that does not go through Desktop's file watch and leaves the Power Query "mashup" out of sync (error "Import X does not match any export" when trying to load); in that case, close and reopen Desktop afterwards, exporting the model to TMDL before closing (otherwise the change stays stuck in the dead session).
2. Locate the visual's folder: use "Copy object name" in Desktop (right-click the visual, copy name) to find the right folder at `pages/[page]/visuals/[name]/visual.json` without relying on `displayName` (visuals in PBIR have no friendly name in the file).
3. Read the whole `visual.json` before editing -- check `visualType`, `query.queryState` (which fields are in each role) and `objects` (formatting already applied).
4. Make the minimum necessary edit (swap a field in `queryState`, change `visualType`, adjust `position`, add a property in `objects`).
5. Validate the JSON against the schema (opening it in VS Code with the schema extension already does this automatically through the declared `$schema`).
6. Reopen in Power BI Desktop and confirm that no blocking error appeared (invalid schema/missing property) nor a non-blocking one (e.g. invalid active page configuration, fixed automatically).

### Practical steps to create a new visual from scratch

1. Prefer creating the visual through the Power BI Desktop interface and only then adjusting details in the JSON -- manually replicating all the query/objects logic from scratch is fragile and prone to schema errors.
2. If you really must create it via file (e.g. batch automation), copy the structure of an existing `visual.json` of the same type as a template, generate a new `name` (unique ID, 20 alphanumeric characters) and adjust `position`, `query.queryState` and `objects`. **Confirm that Desktop is closed (check the process, do not just ask) BEFORE writing the file, not only before reopening** -- if Desktop is open at the time of creation, it does not know about the new folder and silently deletes it on save/close, even if the file was valid.
3. Create the `visuals/[newName]/` folder inside the right page and save the `visual.json` there.
4. There is no need to register the visual anywhere else -- the existence of the folder with a valid `visual.json` is enough; `page.json` does not list individual visuals.

Best practices:
- Copy an existing `visual.json` of the same `visualType` as a starting point when creating a new visual manually -- it guarantees the query/objects structure is correct for that type.
- Use scripts for batch editing when you need to apply the same change to many visuals (e.g. hide all visual-level filters, swap a theme in bulk) -- this is exactly the scenario PBIR was designed to enable.

Cautions:
- **Uncertain formatting property name: verify before applying, do not guess.** Power BI Desktop frequently accepts and silently saves an invalid or unrecognized `objects` property with no error at all -- it just has no visual effect, which looks like "I applied it but it did not work" instead of warning that the name is wrong. Before applying a formatting property whose name is not confirmed in this document, search public `capabilities.json` files of related visuals on GitHub (`gh search code "<suspectProperty>"`) to confirm the exact name and the correct parent object.
- **`cardVisual`: the container background and the value background are two different objects.** `visualContainerObjects.background.show = false` removes the background/frame of the visual container (confirmed working). That is not the same object that controls the fill behind the number/callout itself -- when investigating a "white background" that will not go away, first compare the visual's size with sibling visuals of the same type (a card much larger than its content leaves empty space that looks like a background without being one). Before applying a light (white) font to any text, confirm the PAGE background color (not just the visual's) -- light page background + white font = invisible text.
- **Slicer (`slicer`) -- search box:** the correct property is `selfFilterEnabled` (boolean) under the `general` object, not `isSearchEnabled` (which has no effect).
- **Slicer (`slicer`) -- style (List/Dropdown/Between/single field):** property `objects.data[0].properties.mode` (`expr.Literal.Value`), not publicly documented (native visual, no public `capabilities.json`). Values confirmed via real `visual.json` files from other projects: `'Dropdown'` (dropdown list), `'Between'` (two min/max fields, used for a numeric or date range), `'Basic'` (single field -- use for a numeric What-If Parameter column where the user types/slides a value). Before applying a value not confirmed here, search real public `visual.json` files (`gh search code "'<Value>'" filename:visual.json`) instead of guessing -- wrong names raise no error, they just have no effect (same caution as the previous paragraph about uncertain properties).
- **The "Responsive" toggle ignores a fixed `fontSize`.** Editing `fontSize` in `objects.categoryAxis`/`objects.labels`/etc. in the JSON may have no visual effect at all if the visual has "Responsive" turned on (Desktop: select the visual > Visualizations pane > General > Properties > Advanced options > "Responsive" toggle) -- in that mode the text is calculated dynamically from the container size, ignoring the saved value. If the user reports "I changed the fontSize but nothing changed", or Desktop says the field "only grows if the visual grows", advise turning Responsive off (or increase the visual's `position.width`/`height` instead of just the `fontSize`).
- **Every field projection in `queryState.<Role>.projections` needs a `queryRef` (format `"Table.Field"`) and `active: true` -- on ALL fields, not just the first.** Without `queryRef`, Power BI rejects the file with an explicit schema error (recoverable). Without `active: true` on fields beyond the first, the result is worse: it can crash the rendering engine at runtime (error `Cannot read properties of undefined (reading 'isMeasure')` in `PivotTableVisuals.min.js`, capable of taking down the whole Desktop and losing the in-memory model) or Desktop may simply silently discard the visual folder, with no error on screen. Confirmed in real use.
- Do not edit `query.queryState` referencing a table/column/measure that does not exist in the semantic model -- Power BI Desktop will fail when reopening the report.
- Do not copy an entire `visual.json` from another report without reviewing `query` -- the `queryRef` values and entity names (`SourceRef.Entity`) must exist in the target semantic model.
- Do not leave `position` with x/y/width/height outside the page bounds (the page layout in `page.json` defines total width/height) -- the visual ends up cut off or invisible.

## 4. Dashboard design best practices

### Information density

- General rule: each page should answer one main business question, with 1-2 supporting questions. If the page tries to answer five unrelated questions, split it into pages.
- Prioritize the top/left of the page (where the eye lands first, in Western reading cultures) for the most important KPIs; details and drill-down go below/to the right.
- Fewer well-chosen visuals communicate more than many small visuals. If a value is hard to read because of its size, the dashboard has too many visuals on the page.

### KPIs vs. charts

- Use cards/KPIs at the top to "answer the question in 3 seconds" (what is the number, is it good or bad, did it go up or down).
- Use charts below to explain the reason -- breakdown by category, trend over time, comparison between segments.
- Do not duplicate the same information in a KPI and a chart without reason -- each visual on the page should add a new answered question.

### Colors

- Use color to encode meaning, not to decorate. E.g. consistent red/green for negative/positive across the whole page; a highlight color reserved only for the item that matters (e.g. "this month" vs. gray for "previous months").
- Limit the categorical palette to a few distinct colors (the human eye discriminates more than 6-8 colors in a chart poorly). If there are more categories than that, group them into "Other" or use selective highlighting (one strong color + grays for the rest).
- Never use color as the only code of meaning -- consider color blindness (about 8% of men have some form of it). Combine color with position, data labels or pattern/texture when the data is critical.

### When not to use pie/donut (reinforcement)

- SQLBI rule of thumb: pie/donut charts are only justified for simple composition with 2 to 4 categories, when the central point is "proportion of the whole", not magnitude comparison.
- Any situation of "compare who is bigger among A, B, C, D..." should be a bar, not a pie -- comparing position/length (bar) is read much more precisely by the human eye than comparing angle/area (pie).
- Gauge has the same limitation: good for an isolated "am I close to the goal?", bad for comparing several items with each other.

### Accessibility

- Ensure enough contrast between text/value and background (avoid light gray text on white background just for aesthetics).
- Add clear titles and axis labels on every visual -- do not assume the audience will infer what is being measured from the page context.
- Set `tabOrder` on visuals (field in `position`) logically for keyboard/screen-reader users -- the visual order (left to right, top to bottom) should match the navigation order whenever possible.
- Avoid relying only on a tooltip for essential information -- tooltips are not accessible via keyboard/screen reader by default; critical information should be in the visible label.

## References

- Power BI Desktop project report folder — Microsoft Learn: https://learn.microsoft.com/en-us/power-bi/developer/projects/projects-report
- PBIR JSON Schemas — microsoft/json-schemas (GitHub): https://github.com/microsoft/json-schemas/tree/main/fabric/item/report/definition
- Tips for designing a great Power BI dashboard — Microsoft Learn: https://learn.microsoft.com/en-us/power-bi/create-reports/service-dashboards-design-tips
- Using pie charts is not the end of the world — SQLBI: https://www.sqlbi.com/articles/using-pie-charts-is-not-the-end-of-the-world/
- Power BI enhanced report format (PBIR) — Fabric Community Blog: https://community.fabric.microsoft.com/t5/Power-BI-Updates-Blog/Power-BI-enhanced-report-format-PBIR-in-Power-BI-Desktop/ba-p/5174449
