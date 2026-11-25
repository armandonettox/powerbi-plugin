# Measure Organization in Large Semantic Models

This document goes deeper into measure organization than the basics already covered in
[modeling-guidelines.md](modeling-guidelines.md) (distributing measures across tables, `displayFolder`,
`description`, mandatory `formatString`). The focus here is **convention and scale**: how to keep
hundreds of measures navigable without confusing the people who consume the report.

## Hierarchical `displayFolder`

`displayFolder` accepts a hierarchy using `\` as the separator. This creates folders and subfolders in
the Power BI fields pane.

**DO:**
- Use a two-level hierarchy at most in most models: `Area\Subarea`. E.g. `Sales\YoY`,
  `Sales\Cumulative`, `Sales\Targets`.
- Reserve the third level for really large measure families (>15 measures in the same
  subarea). E.g. `Finance\Margin\By Channel`.
- Group by **business concept**, not by technical calculation type. `Sales\YoY` is better than
  `Time Intelligence\Sales`, because the business user thinks "sales" first.
- Keep the same folder name across different tables when the concept repeats (e.g. every fact table
  that has a year-over-year comparison uses the `YoY` subfolder), for the mental consistency of the
  user who navigates several tables.
- Put base measures (no suffix, the folder's "main measure") in the root of the parent folder, and only
  the derived variations in the subfolder. E.g. `[Total Sales]` goes in `Sales`, `[Total Sales LY]` goes in
  `Sales\Comparisons`.

**DON'T:**
- Create a hierarchy with 4+ levels. The Power BI fields pane becomes slow to navigate and the
  organizational gain disappears (the user loses the mental map of the structure).
- Create a folder for each individual measure (`displayFolder` with 1 item inside). That is noise, not
  organization. A folder only pays off from ~3 related measures.
- Mix grouping criteria in the same table (e.g. one folder per business area and another per
  calculation type). It produces an inconsistent and unpredictable structure.
- Use `/` as the separator. TMDL/TOM uses `\` for the folder hierarchy; `/` is treated as a
  literal character of the folder name, not as a separator.

**TMDL example:**

```tmdl
measure 'Total Sales' = SUM('Sales'[Net Amount])
	formatString: "$#,##0.00"
	displayFolder: Sales

measure 'Total Sales LY' = CALCULATE([Total Sales], SAMEPERIODLASTYEAR('Calendar'[Date]))
	formatString: "$#,##0.00"
	displayFolder: Sales\Comparisons

measure 'YoY Growth %' = DIVIDE([Total Sales] - [Total Sales LY], [Total Sales LY])
	formatString: "0.0%"
	displayFolder: Sales\Comparisons

measure 'Total Sales YTD' = TOTALYTD([Total Sales], 'Calendar'[Date])
	formatString: "$#,##0.00"
	displayFolder: Sales\Cumulative
```

## Dedicated "_Measures" table vs distributing across fact tables

The general rule in modeling-guidelines.md already says "avoid a single Measures table". Here is the
criterion for deciding when to make an exception.

**When to distribute across fact tables (default, prefer whenever possible):**
- Small and medium models (up to ~40-50 measures in total).
- Measures that clearly belong to a single fact table (e.g. `[Total Sales]` in `Sales`,
  `[Total Returns]` in `Returns`).
- Models with few business analysts browsing them. The proximity between measure and fact helps
  explain where the data comes from.

**When a dedicated table is worth it (`_Measures`, or one per business area such as `_Measures Finance`):**
- Large models (>80-100 measures) where many measures combine multiple fact tables (e.g. a
  margin measure that uses `Sales` and `Costs` together). There is no single natural "owner".
- Models with multiple conceptually equivalent fact tables (several countries/units with the
  same structure). Putting the measure in a central table avoids duplicating it in every fact.
- Models consumed by Copilot/Q&A, where a central KPI table makes semantic discovery easier
  (less ambiguous than "which fact table has the margin measure").
- One dedicated table per **business area** (`_Measures Sales`, `_Measures Finance`) is preferable
  to a single monolithic `_Measures` table once the model is past ~150 measures. It replicates the
  `displayFolder` logic, but at table level, which helps external tools (Analyze in
  Excel, Copilot) that do not navigate deep folders well.

**DO:**
- Prefix the dedicated table with `_` (e.g. `_Measures`) so it appears at the top of the table list in the
  fields pane, signaling visually that it is a utility table with no row data.
- Mark the dedicated table as hidden from data navigation when it has no visible columns
  (it exists only to host measures).
- Document in the dedicated table's `description` why it exists and which areas it covers.

**DON'T:**
- Create a `_Measures` table "out of habit" in small models. It moves the measure away from the data
  context it represents, with no real organizational gain.
- Mix: half of an area's measures in the fact table and the other half in `_Measures` with no clear
  criterion. It forces the user to look in two places.

## Base measures vs derived measures

Large models accumulate dependency chains: a base measure, a time variation, and a
comparison metric on top of the variation. Without a convention, this chain is invisible to anyone who only sees
the name in the fields pane.

**Naming pattern by layer:**

| Layer | Role | Example |
|---|---|---|
| Base | Direct aggregation of a column | `[Total Sales]` |
| Time-derived | Applies a time context over the base | `[Total Sales LY]`, `[Total Sales YTD]` |
| Comparison-derived | Combines base + time-derived | `[YoY Growth %]`, `[Variance vs LY]` |

**DO:**
- Always name the derived measure citing the base measure in its name, so the dependency relationship
  is readable without opening the formula. `[Total Sales LY]` makes clear it derives from `[Total Sales]`;
  `[LY]` alone does not.
- Keep the same name root between base and derived measures even when they change folders (`[Total Sales]` in
  `Sales`, `[Total Sales LY]` in `Sales\Comparisons`). The name root is what guarantees
  traceability; `displayFolder` is only visual organization.
- Describe in the derived measure's `description` field which measure is the base and what it adds. E.g.:
  `description: "Total Sales for the same period of the previous year. Base: [Total Sales]."`
- Limit the dependency chain to 3 levels (base -> time-derived -> comparison-derived).
  Beyond that, maintenance becomes fragile and the report user loses track of the calculation.

**DON'T:**
- Name the derived measure with a name disconnected from the base (e.g. base `[Total Sales]`, derived
  `[Annual Growth]` with no word in common). Whoever browses the fields pane
  cannot discover the relationship.
- Create a derived measure that points to another derived measure in an undocumented way, without making
  the full chain clear in the `description` (e.g. `[Variance vs Target YoY]` that depends on
  `[YoY Growth %]` which depends on `[Total Sales LY]` which depends on `[Total Sales]`).
- Duplicate the base logic inside the derived measure instead of referencing the base measure in the DAX.
  This breaks the maintenance chain (if the base changes, the derived measure does not follow).

## Calculation groups: organization, not definition

modeling-guidelines.md already covers when to use calculation groups to avoid measure explosion
(time intelligence). The focus here is how to name and organize the `calculation item`s inside the group,
and when **not** to use the pattern even when there are time variations.

**DO:**
- Name the calculation items with the same terms already used in the model's measure suffixes
  (see the naming pattern section below), so replacing a standalone measure with a
  calculation group does not require relearning vocabulary. If the model already uses the `LY` suffix, the
  calculation group item should be called `LY`, not `Previous Year` or `Prior Year`.
- Keep a single time intelligence calculation group per model (`Time Intelligence`), with
  all items (`Current`, `YTD`, `LY`, `LY YTD`, `% LY`) inside it. This avoids the user having to
  choose between multiple calculation group slicers for the same concept.
- Define the `ordinal` of each calculation item following the logical reading order (Current before
  YTD before LY before % LY), so it appears in that order in the slicer, not alphabetically.
- Use a `format string expression` on the percentage calculation item (`% LY`, `Var %`) so the
  format changes dynamically (currency -> percentage) when the item is selected. Without it, all
  measures in the group appear with the base measure's format, even when the result is a percentage.

**DON'T:**
- Create a calculation group for a variation that only applies to 1-2 measures in the model. The cost of
  understanding (the user has to understand the calculation group concept) outweighs the gain. In that
  case, an explicitly named derived measure is simpler.
- Create calculation items that are redundant with explicit measures that already exist for the same variation
  (e.g. having `[Total Sales LY]` as an explicit measure AND an `LY` item in the calculation group covering the
  same table). Choose one of the two paths and document the decision in the group's `description`.
- Apply the time intelligence calculation group over measures that are already cumulative by
  nature or over balance/inventory measures (semi-additive) without reviewing the logic. `CALCULATE` with
  `SAMEPERIODLASTYEAR` may not make semantic sense for balances.
- Mix items of a different nature in the same calculation group (e.g. time intelligence and
  currency conversion). Each calculation group must represent a single axis of variation, otherwise the
  interaction between groups (when there is more than one) becomes unpredictable.

## Naming pattern for time variations

A consistent suffix convention prevents the same concept from getting different names in different parts
of the model (`LY` in one table, `Previous Year` in another).

**DO: use a suffix, always in this order: `[Base Measure] [Period] [Type]`:**

| Suffix | Meaning | Example |
|---|---|---|
| `YTD` | Year To Date | `[Total Sales YTD]` |
| `MTD` | Month To Date | `[Total Sales MTD]` |
| `QTD` | Quarter To Date | `[Total Sales QTD]` |
| `LY` | Last Year (same period, previous year) | `[Total Sales LY]` |
| `LY YTD` | YTD of the previous year | `[Total Sales LY YTD]` |
| `% LY` | Percentage change vs previous year | `[Total Sales % LY]` |
| `LM` | Last Month | `[Total Sales LM]` |

- Always keep the suffix at the end of the name, never in the middle or as a prefix. It allows predictable
  alphabetical ordering in the fields pane (all variations of `[Total Sales]` sit together).
- Use `%` as the percentage marker always the same way (suffix `% LY`, not `LY %` or `Pct LY`).
  Pick one convention and apply it across 100% of the model, never mix.
- Document the suffix convention table (the same one above, adapted) in the `description` of the
  calculation group or in a project note, so other model developers follow the
  same pattern.

**DON'T:**
- Mix languages in the same model (`LY` in some measures, `Previous Year` in others). Even if the
  model is not in English, the acronyms `LY`/`YTD`/`MTD` are already universally understood in BI
  (see the acronyms rule in modeling-guidelines.md), so pick one standard and
  stick to it.
- Use the same suffix for different concepts (e.g. `LY` meaning "last year" in one table and
  "last load" in another).
- Put the period suffix before the measure name (`[YTD Total Sales]`). It breaks the
  alphabetical ordering by measure family in the fields pane.

## Auditing an existing model with `INFO.MEASURES()`

Before reorganizing a large model, audit its current state. The `INFO.MEASURES()` function returns
all the model's measures with their properties and the DAX expression. Use it to find
orphan, duplicate or poorly organized measures before proposing `displayFolder` or naming changes.

**Orphan measures (not referenced in any other measure or visible object):**

```dax
EVALUATE
VAR _Measures = INFO.MEASURES()
RETURN
    SELECTCOLUMNS(
        FILTER(_Measures, [IsHidden] = FALSE),
        "Name", [Name],
        "Table", [Table],
        "DisplayFolder", [DisplayFolder],
        "Expression", [Expression]
    )
```

After extracting the list, cross-check manually (or with a script) which measure names never appear
as a substring inside the `Expression` column of any other measure. That indicates the measure is only
used standalone in report visuals (which is normal) or is not used anywhere (a candidate for
removal, see the Maintenance checklist in modeling-guidelines.md).

**Measures without `displayFolder` (an indicator of incomplete organization):**

```dax
EVALUATE
FILTER(
    INFO.MEASURES(),
    [DisplayFolder] = "" || ISBLANK([DisplayFolder])
)
```

**Duplicate measures (same DAX expression, different names):**

```dax
EVALUATE
VAR _Measures = INFO.MEASURES()
VAR _Grouped =
    SUMMARIZE(
        _Measures,
        [Expression],
        "Qty", COUNTROWS(_Measures)
    )
RETURN
    FILTER(_Grouped, [Qty] > 1)
```

Identical expressions in two measures with different names are a sign of real duplication. Similar but
not identical expressions (e.g. one uses `SUM` and another `SUMX` for the same result) do not show up
here. Manually review measures with semantically close names (`[Total Sales]` vs
`[Sales Total]`) to find duplication caused by inconsistent naming.

**Measures without `formatString` (violation of a mandatory rule):**

```dax
EVALUATE
FILTER(
    INFO.MEASURES(),
    ISBLANK([FormatStringDefinition]) && [IsHidden] = FALSE
)
```

**DO:**
- Run these audit queries before any bulk reorganization of `displayFolder`. Without
  this diagnosis, the risk is reorganizing measures that should have been removed in the first place.
- Repeat the orphan audit periodically in models that receive contributions from multiple
  developers. Orphan measures pile up fast when nobody audits.
- Cross the empty `DisplayFolder` result with the orphan measure result: orphan measures without a folder are
  the first candidates for removal, not for reorganization.

**DON'T:**
- Rely only on visual inspection of the fields pane to find duplicates. Similar names
  hide logic duplication, and different names hide the same expression. Using the query is more
  reliable than manual review in models with more than ~50 measures.
- Remove an "orphan" measure without confirming it is not used in a published report (the query only
  sees references inside other measures of the model itself, not references in report visuals
  or in other composite models/live connections).
