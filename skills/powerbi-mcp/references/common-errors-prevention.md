# Common Errors and Prevention Catalog

An in-depth catalog of real, recurring errors when authoring Power BI/Fabric semantic models (TMDL/MCP) and writing DAX. Each entry focuses on **root cause** and **prevention**: the goal is to never fall into the same error twice, not just to fix the one-off symptom.

> This file complements the [TROUBLESHOOTING](../SKILL.md#troubleshooting) section of `SKILL.md` (flow/operation errors) and the mechanical auto-correction table in [mcp-automation.md § 5](./mcp-automation.md#5-auto-correction-of-common-mcp-errors). Here the focus is the root-cause + prevention catalog, with more technical depth and coverage of categories those two do not handle (semantic DAX, permissions, Direct Lake in depth).

## Index

**1. Modeling / TMDL**
- [1.1 Relationship with incompatible data types](#11-relationship-with-incompatible-data-types)
- [1.2 sourceColumn not mapped or out of sync](#12-sourcecolumn-not-mapped-or-out-of-sync)
- [1.3 Composite key in a relationship](#13-composite-key-in-a-relationship)
- [1.4 Cycle of active relationships (path ambiguity)](#14-cycle-of-active-relationships-path-ambiguity)
- [1.5 Circular reference in a measure](#15-circular-reference-in-a-measure)
- [1.6 Editing partition M through table_operations does not persist](#16-editing-partition-m-through-table_operations-does-not-persist)
- [1.7 A table referenced by name inside another table's M is an invisible dependency](#17-a-table-referenced-by-name-inside-another-tables-m-is-an-invisible-dependency)
- [1.8 cache.abf and unappliedChanges.json override direct TMDL edits](#18-cacheabf-and-unappliedchangesjson-override-direct-tmdl-edits)
- [1.9 StaticResources and report.json edited externally disappear when Desktop reopens](#19-staticresources-and-reportjson-edited-externally-disappear-when-desktop-reopens)
- [1.10 A new relationship on a date column conflicts with Auto Date/Time (LocalDateTable)](#110-a-new-relationship-on-a-date-column-conflicts-with-auto-datetime-localdatetable)
- [1.11 A column dataType locked in the TOM ignores the real type coming from the M query](#111-a-column-datatype-locked-in-the-tom-ignores-the-real-type-coming-from-the-m-query)

**2. DAX**
- [2.1 Filter context lost through a misused CALCULATE](#21-filter-context-lost-through-a-misused-calculate)
- [2.2 Division by zero without DIVIDE](#22-division-by-zero-without-divide)
- [2.3 Wrong type comparison (implicit type coercion)](#23-wrong-type-comparison-implicit-type-coercion)
- [2.4 Table VAR used as a boolean filter in CALCULATE](#24-table-var-used-as-a-boolean-filter-in-calculate)
- [2.5 Row context vs. filter context in a calculated column](#25-row-context-vs-filter-context-in-a-calculated-column)
- [2.6 MAX()/MIN() on a date column stored as text](#26-maxmin-on-a-date-column-stored-as-text)
- [2.7 "Total for the selected period" measure reinvented instead of reusing the model's pattern](#27-total-for-the-selected-period-measure-reinvented-instead-of-reusing-the-models-pattern)

**3. Deploy / Publishing**
- [3.1 Duplicate deploy creating a model with a repeated name](#31-duplicate-deploy-creating-a-model-with-a-repeated-name)
- [3.2 updateDefinition failing because of a missing part](#32-updatedefinition-failing-because-of-a-missing-part)
- [3.3 Incompatible compatibility level](#33-incompatible-compatibility-level)
- [3.4 LRO (async operation) stuck on "Running" or "NotStarted"](#34-lro-async-operation-stuck-on-running-or-notstarted)

**4. Refresh**
- [4.1 Data source credential not configured](#41-data-source-credential-not-configured)
- [4.2 Refresh timeout in Direct Lake / framing](#42-refresh-timeout-in-direct-lake--framing)
- [4.3 Partition with M code referencing an unavailable source](#43-partition-with-m-code-referencing-an-unavailable-source)
- [4.3b Datasource does not map to the existing gateway connection because of a textual difference in the server](#43b-datasource-does-not-map-to-the-existing-gateway-connection-because-of-a-textual-difference-in-the-server)
- [4.4 Partial refresh with silently stale data](#44-partial-refresh-with-silently-stale-data)

**5. Permissions / Authentication**
- [5.1 401 because of the wrong token audience](#51-401-because-of-the-wrong-token-audience)
- [5.2 403 because of a missing Contributor+ role](#52-403-because-of-a-missing-contributor-role)
- [5.3 Misconfigured RLS breaking the view for the user](#53-misconfigured-rls-breaking-the-view-for-the-user)
- [5.4 Service Principal without access to the workspace or the data source](#54-service-principal-without-access-to-the-workspace-or-the-data-source)

**6. MCP pitfalls with Power BI Desktop open**
- [6. MCP pitfalls with Power BI Desktop open](#6-mcp-pitfalls-with-power-bi-desktop-open)

---

## 1. Modeling / TMDL

### 1.1 Relationship with incompatible data types

**Symptom:** When creating the relationship, the operation fails with something like "The relationship cannot be created because the columns have incompatible data types" or, worse, the relationship is created but never filters anything (silent behavior in some TMSL clients).

**Root cause:** The two key columns were created at different times (different working teams, tables coming from different sources) and nobody aligned the `dataType`. It is common to see `Int64` on one side and `String` on the other when the key is numeric in the fact table but was imported as text in the dimension (or vice versa, because of leading zeros such as "007").

**How to prevent:** Before creating ANY relationship, always `get`/`list` the two columns involved and compare `dataType` explicitly; never assume it from the column name. In the batch planning checklist (see [mcp-automation.md § 1](./mcp-automation.md#1-batch-sequencing-batch-build)), fix the `dataType` of each key BEFORE creating any column, and treat columns with the same semantic role (e.g. `CustomerKey` in `Sales` and in `Customer`) as a single type contract decided once. If the key comes from sources with different native types (e.g. `NUMBER` in Oracle vs `VARCHAR` in SQL Server), normalize the type already in the M/source query, not in the model.

**How to fix:** Identify which side has the "wrong" type (it normally follows the type of the primary key in the dimension) and change only the divergent side via `column_operations` (update), never both, so as not to introduce a second inconsistency. Recreate the relationship after the fix.

### 1.2 sourceColumn not mapped or out of sync

**Symptom:** Error on refresh ("Column 'X' of table 'Y' wasn't found") or an immediate error when saving the column/partition saying that `sourceColumn` does not exist in the query.

**Root cause:** `sourceColumn` is the name of the field *in the partition output* (M query, Direct Lake entity), not a free-form name, and it diverges from the column's display name in TMDL. Common cases: (a) renaming the display column in the model without updating `sourceColumn`; (b) the source renaming/removing the column after the model was already created; (c) a case difference between the real column name in the source and the value typed in `sourceColumn` (case-sensitive on case-sensitive sources, such as Lakehouse/Delta).

**How to prevent:** Treat `name` (display) and `sourceColumn` (contract with the source) as two independent fields from creation; never copy one from the other out of habit when you plan to rename later. Always check `sourceColumn` character by character against the real schema already obtained during discovery (lakehouse schema, result of a sample M query, or the source's `INFO`), never against memory or assumption. Renaming a display column is a separate operation from renaming `sourceColumn`; confirm that the intent is to change only the former.

**How to fix:** Recheck the real source schema, correct `sourceColumn` to the exact name (including casing), then validate with a test refresh of the isolated table before propagating the change to the rest of the model.

### 1.3 Composite key in a relationship

**Symptom:** An attempt to create a relationship between two (or more) columns fails, or the user asks to "relate by Year+Month+Product" and the tool does not accept multiple columns per side.

**Root cause:** The Tabular Object Model **does not natively support composite keys** in a physical relationship; each relationship links exactly one source column to one target column. Models migrated from a relational star schema (where composite keys are common) try to replicate the same structure in Power BI and hit this limit.

**How to prevent:** Never plan a relationship with more than one column per side. When you identify that the natural business key is composite (e.g. `Year + Month + CostCenter`), solve it in one of these ways, decided BEFORE creating any column: (a) concatenate the parts into a single surrogate column in the source (M/warehouse), typically with a separator that does not occur in the values, and use that concatenated column as the single relationship key; (b) generate an integer surrogate key in the source; (c) if the parts represent different conceptual roles that should not be physically joined, use a virtual relationship via `TREATAS` with multiple conditions inside the measure's DAX, instead of a physical relationship (see [relationships-advanced.md § 1](./relationships-advanced.md#1-virtual-relationships-via-dax-treatas)).

**How to fix:** If the model was already built expecting a composite key, add a concatenated column (calculated or, preferably, pushed to the source) on both sides, create the single relationship on that column, and hide the original supporting columns.

### 1.4 Cycle of active relationships (path ambiguity)

**Symptom:** Creating a new relationship is rejected, or it is accepted but the relationship is born inactive automatically; in reports, totals that "don't add up" or vary inconsistently when adding a seemingly unrelated slicer.

**Root cause:** More than one active filter path is possible between two tables (e.g. two dimensions each linked to two fact tables forming a "diamond", or a bidirectional bridge table that reopens a path already covered by another relationship). The Tabular engine requires at most one active filter path between any pair of tables and does not pick "the best one": it refuses the second active relationship or produces an ambiguous result if the combination of bidirectional relationships allows both paths at the same time. See the details in [relationships-advanced.md § 5](./relationships-advanced.md#5-filter-ambiguity-between-multiple-paths) and § 6 (bidirectional).

**How to prevent:** Before adding any new relationship, sketch mentally (or in text) the graph of tables already connected and ask: "is this table already reachable from the other by another path?". If so, it is a design smell; resolve it with a shared conformed dimension instead of linking fact-to-fact or dimension-to-dimension directly. Never make a relationship bidirectional "to make the slicer work" without checking the full graph; use `CROSSFILTER(..., BOTH)` scoped to the specific measure instead of changing the physical direction when the bidirectional effect is only needed in one calculation.

**How to fix:** List all relationships of the tables involved via `relationship_operations`, identify the duplicate path, deactivate one of them and, if the alternative logic is needed in specific measures, activate it on demand with `USERELATIONSHIP`.

### 1.5 Circular reference in a measure

**Symptom:** Error when saving/validating the measure such as "A circular dependency was detected" or the engine refuses the calculation (`INFO.MEASURES()` returns a populated `ErrorMessage`).

**Root cause:** A measure A references itself (directly or indirectly, through B, C...). It commonly appears during refactoring: the measure "Net Total" starts calling "Gross Total minus Discount", and later someone edits "Gross Total" to use "Net Total plus Discount" thinking it is simplifying, without noticing that the A→B→A cycle was closed.

**How to prevent:** When creating/editing a measure that references other measures, explicitly list the dependency chain (which measures it calls, and what those call) before saving; do not trust short-term memory during a long refactoring session. Avoid the anti-pattern "a measure that is just a reference to another measure" (already prohibited in [modeling-guidelines.md](./modeling-guidelines.md#measures--dax), `DON'T`: "Create measures that are just direct references to other measures"); that pattern is precisely what most easily evolves into a cycle when someone else edits one end without seeing the full graph.

**How to fix:** Map the call chain of the failing measure (via `measure_operations` list/get of all measures in the model, or `INFO.CALCDEPENDENCY` when available), identify the link that closes the cycle, and rewrite one of the measures to compute from a common base (direct columns/aggregations) instead of circularly depending on another derived measure.

### 1.6 Editing partition M through table_operations does not persist

**Symptom:** Calling `table_operations` (operation `Update`, field `mExpression`) to edit a table's M query returns `{"success":true}`, but when the TMDL is re-exported right after, the M query is still the old version; the change had no effect at all despite the success return.

**Root cause:** A table's M query lives in the **partition**, not in the table itself. The `mExpression` parameter of `table_operations` accepts the value without error, but does not necessarily apply it reliably to the real partition.

**How to prevent:** Always edit the M query via `partition_operations` (operation `Update`, with `tableName` + the partition `name` + `expression`), never via `table_operations.mExpression`. After any M edit, trigger a refresh with `refreshType: Full` via `partition_operations Refresh` or `model_operations Refresh`. **`table_operations Refresh` is not reliable for reprocessing an M edit**: in a real session it returned success without reloading the changed data, and only the full refresh (`Full`) actually re-read the partition.

**How to fix:** Re-export the partition (`partition_operations ExportTMDL`) to confirm that the change persisted before moving on to the refresh; if it still shows the old version, redo the call via `partition_operations` instead of `table_operations`.

**The same symptom also occurs on a calculated column.** Editing the DAX expression of a calculated column via `table_operations` (operation `Update`, field `columns`) behaves exactly the same: it returns success but does not persist. Always use `column_operations` (operation `Update`, with `tableName` + `name` + `expression`) to edit a calculated column, and then `model_operations Refresh` with `refreshType: Calculate` (`Full`/`Automatic` alone is not enough when only the column formula changed) to recalculate, and confirm via a DAX query.

### 1.7 A table referenced by name inside another table's M is an invisible dependency

**Symptom:** Deleting a table that `relationship_operations List` and a search in visuals do not show as used by anyone breaks another table, with an error like "The import X matches no exports. Did you miss a module reference?" (Power Query).

**Root cause:** A table can feed another via Power Query (M) by using its name as a bare identifier inside an expression (e.g. `Table.Group(plans_pq, ...)`, `= other_table` as the Source), without that creating a DAX relationship. `relationship_operations` and relationship-based dependency analysis do not see this kind of link.

**How to prevent:** Before deleting any "apparently unused" table, grep the M (`expression`/`mExpression`) of ALL the other tables in the model looking for its name as a loose identifier (not only as a string). `table_operations Get` returns the full partition expression; use it for this check in bulk before any cleanup.

**How to fix:** Restore the removed table (recreate it from the original TMDL/M) and relink the dependent table to it, or inline the removed table's source directly into the dependent one (this eliminates the reference by name, but duplicates logic if more than one table depended on it).

### 1.8 cache.abf and unappliedChanges.json override direct TMDL edits

**Symptom:** A Power Query error persists even after correctly fixing the TMDL (the file checks out, the re-export matches what is expected) and closing/reopening Power BI Desktop; the fix "doesn't stick".

**Root cause:** `<Model>.SemanticModel/.pbi/cache.abf` is a binary cache of the model that Desktop uses to open quickly without reprocessing the TMDL from scratch. `.pbi/unappliedChanges.json` is a separate snapshot of the Power Query Editor session ("pending" M text of each query); it can contain an outdated version of a query that the Editor loads instead of re-parsing the TMDL.

**How to prevent/fix:** If an M error persists even though the TMDL is correct, close Desktop and delete both files (`<Model>.SemanticModel/.pbi/cache.abf` and `.pbi/unappliedChanges.json`) before reopening; this forces Desktop to rebuild the model and the Query Editor session entirely from the TMDL on disk.

### 1.9 StaticResources and report.json edited externally disappear when Desktop reopens

**Symptom:** A custom icon/image added to a card via direct editing of the PBIR files (`StaticResources/RegisteredResources/*.svg` or `.png` + a reference in `report.json` + `cardImage` in `visual.json`) disappears (the file is deleted from the folder and the reference vanishes) every time Power BI Desktop opens the `.pbip`, even with everything correctly registered in the files.

**Root cause:** When loading a PBIP project, Desktop reconciles `StaticResources` against its own internal state of "known" resources. A file that was not registered through the normal UI flow (visual Format → Icon → Browse image) is treated as an orphan and removed, regardless of being referenced in `report.json`.

**How to prevent:** For card icons/images, always import through the Desktop UI (visual object Format → Icon → Browse image), pointing to a file already placed in `StaticResources/RegisteredResources/`; Desktop then registers the resource its own way and it survives reopening. Do not hand-author the reference in `report.json`/`cardImage` expecting it to persist.

**How to fix:** If two `cardImage` blocks coexist in the same card (one `"id": "default"` and another `"metadata": "<table>.<measure>"`), the `metadata` block (more specific) silently overrides what was imported into `default` through the UI; removing the extra block leaves only the version imported through the UI in effect.

### 1.10 A new relationship on a date column conflicts with Auto Date/Time (LocalDateTable)

**Symptom:** Trying to create an explicit relationship from a date column to a shared calendar table fails, or trying to delete the automatic relationship that already exists on that column returns an error citing a `Variation` object that references the relationship.

**Root cause:** With "Auto Date/Time" enabled (the Power BI default), every date column automatically gets a hidden calendar table (`LocalDateTable_*`) and a `Variation` linked to it. A column can only have one active relationship at a time; deleting just the relationship with `relationship_operations Delete` fails because the `Variation` still references that relationship.

**How to prevent/fix:** Before linking the column to a real calendar, delete the entire `LocalDateTable_*` in cascade (`table_operations Delete` with `shouldCascadeDelete: true`); this removes the relationship and the `Variation` together in one go. Only then create the explicit relationship. If the model locks up afterwards (an error like "the base version must not be negative when impact is requested for a transaction") after a delete+create sequence, close and reopen Power BI Desktop to reset the Analysis Services engine and reapply the changes; they do not persist on their own when the engine locks up in that state.

### 1.11 A column dataType locked in the TOM ignores the real type coming from the M query

**Symptom:** Measures with `SUM`/`AVERAGE`/`MIN`/numeric comparison on a column break with "function X cannot work with values of type String" (or an equivalent Text vs Integer comparison error), even though the column was always numeric and its M query does no obvious transformation to text. `ISNUMBER` on the column returns false for 100% of the rows.

**Root cause:** A column's `dataType` property is stored explicitly in the model (TOM); it is not always recomputed from the real type returned by the M query on each refresh. If the column's `dataType` is `String` (locked by a previous edit, an import, or drift between report versions), Analysis Services converts the data to text on load, even if the source and the M query return a number, with no refresh error (the partition stays `Ready` as normal).

**How to prevent:** When investigating a column "turning into text" with no visible change in the M query or in the source, check the stored `dataType` with `column_operations Get` **before** rewriting the entire M query. Comparing against the direct source table (`ISNUMBER` on the source vs on the derived table) helps isolate whether the problem is in the source, in the M query, or in the TOM `dataType`.

**How to fix:** `column_operations Update` with the correct `dataType` (e.g. `"Double"`) + `formatString` again, then `table_operations Refresh` on the table to reload the data already with the right type. Optionally, add a defensive conversion in the M query (`Number.From`/`Number.FromText` with locale) as a safety net against the source really sending text in the future.

---

## 2. DAX

### 2.1 Filter context lost through a misused CALCULATE

**Symptom:** A measure returns the same total value regardless of the row/column/slicer filters applied in the visual, when it should vary.

**Root cause:** A `CALCULATE` (explicit, or implicit inside any aggregation function) contains a filter that uses `ALL()`, `REMOVEFILTERS()` or an entire table unrelated to the current context, removing precisely the context that should be preserved. A very common case: `CALCULATE([Measure], ALL('Calendar'))` was copied from a "grand total" calculation and reused in a measure that should respect the date filter; the context removal "leaks" to the rest of the calculation because `CALCULATE` replaces the filter context of that column(s)/table(s) for the entire evaluation of the expression, not just a part of it.

**How to prevent:** Never use `ALL()`/`REMOVEFILTERS()` "by reflex" when copying a pattern from another measure; explicitly ask "should this filter really be removed for ALL the rest of the expression, or only for a sub-part?". When only part of the calculation needs to ignore a filter (e.g. compare against the category total but keep the date filter), isolate that part in a `VAR` with its own inner `CALCULATE`, instead of applying `ALL` at the outer level of the measure. Prefer `REMOVEFILTERS()` over `ALL()` precisely because the name makes the intent explicit (see [dax-guidelines.md](./dax-guidelines.md)); this also makes later review easier for another person (or for yourself in 3 months).

**How to fix:** Isolate the suspect `CALCULATE`, test the measure with `EVALUATE {[Measure]}` under different date/category filters via a test `CALCULATETABLE`, and restrict the filter-removal argument to the smallest necessary scope (a specific column, not an entire table; an intermediate `VAR`, not the measure's complete expression).

### 2.2 Division by zero without DIVIDE

**Symptom:** The visual shows "Infinity", "-Infinity", a generic calculation error, or (in some visualization engines) the cell is blank inconsistently with the rest of the table; it often only shows up in production when a filter reduces the denominator to zero (e.g. a category with no sales in the period), never during testing with full data.

**Root cause:** Use of the plain `/` operator (`SUM(Sales[Cost]) / SUM(Sales[Revenue])`) instead of `DIVIDE()`. Since the error only manifests when the denominator is actually zero or blank, it frequently passes the initial test (done with the full model, without extreme filters) and only appears later, when a user applies a filter that isolates a row with no denominator.

**How to prevent:** Treat `/` as forbidden by default in any measure expression; always use `DIVIDE(numerator, denominator[, alternateResult])`, even when "the denominator should never be zero in theory", because filter contexts in Power BI frequently create that case exactly where the business theory said it would not happen (an empty cell in a matrix visual, a "Total" with a breakdown that isolates an empty category). The only documented exception in [dax-guidelines.md](./dax-guidelines.md) is inside row-by-row iterators where the denominator has already been proven to be filtered to exclude zeros before the iterator; even then, document why it is safe in the measure's `description` or in a comment, because the next person who edits it will not know the guarantee exists.

**How to fix:** Replace `/` with `DIVIDE()`, explicitly deciding the third argument (default `BLANK()`, but sometimes `0` is more correct for the visual, e.g. KPIs that should show "0%" instead of an empty cell).

**Additional confirmed trap:** `DIVIDE(numerator, denominator, alternate)` only uses the third argument when the denominator is literally `0`. If the numerator **and** the denominator are both `BLANK()` (common inside `AVERAGEX`/`SUMX` over a period with no rows, where `SUM`/`DISTINCTCOUNT` return `BLANK()` instead of `0`), `DIVIDE(BLANK(), BLANK(), 0)` returns `BLANK()`, not `0`; the third argument is ignored. If the intent is to always get a number (never an empty cell), explicitly add `+ 0` on both sides before the `DIVIDE` (`DIVIDE(MonthSum + 0, MonthCount + 0, 0)`), or on the measure's final result, which turns the `BLANK()` into a real `0` before the division.

### 2.3 Wrong type comparison (implicit type coercion)

**Symptom:** A filter or condition (`IF`, a `CALCULATE` boolean filter, `FILTER`) never returns true for rows that should match, or returns true for rows that should not, with no explicit error, because DAX applies implicit type coercion in many comparisons.

**Root cause:** Comparing a text column with a number without conversion (`'Sales'[OrderID] = 12345` when `OrderID` is `String` and contains `"12345"` with a space or leading zero), or comparing a `DateTime` with a date text that does not exactly match the regional format expected by the engine (`'Calendar'[Date] = "2026-08-24"` behaving differently from expected depending on the model locale). Another common case: comparing a `TRUE()/FALSE()` boolean with the strings `"TRUE"`/`"FALSE"` coming from a column imported as text from the source.

**How to prevent:** Never rely on implicit coercion in critical filter comparisons; convert explicitly with `VALUE()`, `FORMAT()`, `DATEVALUE()` according to the target type before comparing, especially when one side comes from a text variable or user input (a parameter, a text slicer). When inspecting a new column, always confirm the real `dataType` via discovery ([modeling-guidelines.md](./modeling-guidelines.md#table-columns)) before writing any filter against it; do not assume it from the name (`IsActive` can be `Boolean` OR `String "Yes"/"No"` in the same model, depending on the adopted convention, see [modeling-guidelines.md § Table Columns](./modeling-guidelines.md)).

**How to fix:** Identify the real type of each side of the comparison via `column_operations` (get) or `INFO.VIEW.COLUMNS`, normalize explicitly (type conversion or `FORMAT`) before comparing, and test the condition in isolation with `EVALUATE FILTER(...)` to confirm the expected row count.

### 2.4 Table VAR used as a boolean filter in CALCULATE

**Symptom:** Syntax/validation error when saving the measure, something like "A boolean expression was expected", or the engine silently rejects the intended logic when the `VAR` was built to represent a condition.

**Root cause:** DAX does not allow a boolean expression to be assigned to a `VAR` and then reused as a filter argument of `CALCULATE`/`CALCULATETABLE` the way many procedural languages would (`VAR _cond = 'T'[Col] > 10 RETURN CALCULATE([M], _cond)` is not valid); this is an explicit restriction listed in [dax-guidelines.md](./dax-guidelines.md#calculate-and-calculatetable-filter-rules). The subtler error appears when the `VAR` holds a *table* (e.g. the result of `FILTER(...)`) but is used in a context where the engine expects a strictly boolean argument, or vice versa; confusing the "filter table" with the "boolean filter expression" as the two valid `CALCULATE` arguments.

**How to prevent:** Remember that `CALCULATE`/`CALCULATETABLE` accept two kinds of valid filter argument, a row-by-row boolean expression over a single table, or a filter table (e.g. the return of `FILTER`, `VALUES`, `TREATAS`), and never mix the two in an intermediate `VAR` while trying to "store the condition for later". If the logic needs to be reused, store the **filtered table** in a `VAR` (`VAR _filter = FILTER('T', 'T'[Col] > 10)`) and pass `_filter` as the filter-table argument of `CALCULATE`, not as a would-be boolean.

**How to fix:** Rewrite the `VAR` to materialize a filter table (via `FILTER`/`TREATAS`) instead of a loose boolean, and pass that table as the filter argument of `CALCULATE`.

### 2.5 Row context vs. filter context in a calculated column

**Symptom:** A calculated column shows the same value on every row of a table when it should vary per row, or shows a value that seems "leaked" from another row; very common when the column uses a measure (`[Measure]`) directly.

**Root cause:** Calculated columns are evaluated **row by row, in the table's row context**, with no visual/report filter context involved (they are computed once at refresh, not at query time). When the column expression references a measure (`[Total Sales]`), the implicit `CALCULATE` that every measure undergoes performs **context transition**: the current row context becomes an equivalent filter context (via the implicit `CALCULATE`), but this only filters the table ITSELF (and tables related through a relationship), not any other report context, because there is no report at that moment. The common mistake is the author thinking of the calculated column as if it were evaluated "inside a visual" (as a measure would be), leading to wrong assumptions about what is or is not filtered.

**How to prevent:** Before writing any calculated column that references another column of the same row (`RELATED()`, an implicit aggregation) or a measure, explicitly ask: "this will be evaluated at refresh time, row by row, with no report filter; does the result still make business sense at that moment?". Prefer measures whenever the calculation depends on dynamic filter context (see [modeling-guidelines.md § Calculated Columns](./modeling-guidelines.md#calculated-columns): "Don't use calculated columns for values that change with filter context"). If you really need a calculated column that uses `RELATED()`, confirm that the relationship traversed is exactly the expected "many to one" (a fact row can only see ONE related row from the "one" side); `RELATED()` returns an error/blank if there is not exactly one related row.

**How to fix:** If the intent was a value that reacts to report filters, convert the calculated column into a measure. If the intent really was a fixed per-row value computed at refresh, review the logic to make sure it did not implicitly depend on an external filter context that does not exist at evaluation time (e.g. replace a reference to an aggregated measure with a direct, explicit aggregation over the related table, using `SUMX`/`CALCULATE` with explicit row filters, not inherited from "outside").

### 2.6 MAX()/MIN() on a date column stored as text

**Symptom:** `MAX(table[DateColumn])` (or `MIN`) returns a value that is not actually the most recent/oldest chronologically; e.g. "31/12/2025" beats "28/02/2026" even though February/2026 is later.

**Root cause:** When the date column is of type `String` (common in sources that bring a timestamp as text "dd/mm/yyyy hh:mm:ss"), `MAX()`/`MIN()` compare **lexicographically** (string order), not chronologically; "31" > "28" as a string, regardless of the month.

**How to prevent:** Before aggregating any date column, confirm the real `dataType` via discovery (`column_operations` get or `INFO.VIEW.COLUMNS`). If it is `String`, never use a plain `MAX()`/`MIN()`; always parse into a date first inside a `MAXX`/`MINX`: `MAXX(VALUES(table[DateColumn]), DATEVALUE(LEFT([DateColumn],10)) + TIMEVALUE(RIGHT([DateColumn],8)))` (adjust the parse to the column's real format).

**How to fix:** Replace the direct `MAX()`/`MIN()` with the `MAXX`/`MINX` form + explicit parsing, and revalidate against a known sample of the data.

### 2.7 "Total for the selected period" measure reinvented instead of reusing the model's pattern

**Symptom:** A new measure, written to sum/count something within the period selected in a slicer (e.g. "last 3 months"), gives a number very different from expected: either much smaller (a single `DISTINCTCOUNT`/`SUM` over the combined window, without summing month by month) or much larger (a sum over the table's ENTIRE history, because the measure was not actually restricted to what the slicer filtered).

**Root cause:** Models with a disconnected period table (`dim_period`, with a `period_label`-type column selectable in a slicer) usually already have an established pattern in other measures of the same model: iterate `FILTER(SUMMARIZE(dim_period, period_month, period_year), period_month > 0)`, which automatically inherits the slicer selection, and aggregate (`SUMX`/`AVERAGEX`) over each individual month/year pair, never a single `CALCULATE` with a direct range filter on the fact's date column. Writing a new measure from scratch, based on `TODAY()-N` or on a single `DISTINCTCOUNT` over a combined window, ignores the page's real filtering mechanism and produces a number that only looks right in the isolated test the author chose.

**How to prevent:** Before writing any "total within the selected period" measure, look in the same model (`measure_operations` List/Get) for a sibling measure that already solves the same kind of per-period aggregation (even for another metric); copy its pattern (the way it iterates `dim_period`, the use of `SELECTEDVALUE`/`REMOVEFILTERS`) instead of inventing new logic based on `TODAY()`. If the fix seems to work in an ad-hoc test via `EVALUATE`, also validate it inside the real visual: a `RelativeDate` filter isolated on a single visual can mask that the measure does not work with the slicer mechanism used by the other visuals of the same type.

**How to fix:** Rewrite the measure following the pattern of the model's sibling measures (`SUMMARIZE(dim_period,...)` + `SUMX`/`AVERAGEX` depending on whether the total needs to be summed or averaged), and validate against a page that already shows the correct total (e.g. compare with an "Evolution" page that already sums/shows per individual period) before replicating the fix in other similar visuals. Visuals with an identical layout may depend on different filter mechanisms (slicer vs. a date filter directly on the visual), so a fix validated on one does not guarantee it works on the others.

---

## 3. Deploy / Publishing

### 3.1 Duplicate deploy creating a model with a repeated name

**Symptom:** Error `There are multiple datasets named '<name>'` on a subsequent deploy attempt, or the workspace ends up with two (or more) `SemanticModel` items with the same visible name.

**Root cause:** Deploy (item creation via the Fabric/Power BI API) **is not idempotent**: each `createItem`/publish call creates a new item, even if one with the same name already exists. This typically happens when: (a) a first deploy attempt returns a network/client timeout but was actually completed on the server, and the agent/user reruns the same call without checking; (b) two automated flows (e.g. a CI pipeline and a manual run) trigger the same deploy almost simultaneously.

**How to prevent:** Never rerun a deploy "blindly" after a timeout or ambiguous error; always list the workspace items of type `SemanticModel` first to confirm whether the model already exists before deciding whether it is a create or an update. Treat deploy as an operation of exactly one execution per session: plan it and confirm with the user before triggering it (see [SKILL.md § Workflow: Deploy to Fabric](../SKILL.md#workflow-deploy-to-fabric) and [mcp-automation.md § 6](./mcp-automation.md#6-when-to-stop-and-ask-even-in-automated-mode), which already require human confirmation before deploy). If a CI/CD pipeline is responsible for the deploy, make sure it uses `updateDefinition` on an already-resolved item ID (not re-creation by name) so it is automatically idempotent.

**How to fix:** List all workspace items with that name, delete the duplicates (keeping the most recent one or the one that already has consumers/reports pointing to it; confirm with the user which to keep before deleting), and then run the deploy exactly once from the clean state.

### 3.2 updateDefinition failing because of a missing part

**Symptom:** The `updateDefinition` call (Fabric REST) returns a validation error, or is accepted but the resulting model loses tables/objects that existed before the update.

**Root cause:** The `updateDefinition` payload for a Fabric item is a **complete definition envelope**: it replaces the item's entire definition and does not merge incrementally. Sending only the TMDL parts that were modified (e.g. only the file of the edited table) without including the parts that did not change (other tables, `model.tmdl`, `relationships.tmdl`, `database.tmdl`) results in a validation error or, in some cases, in the silent removal of the objects whose parts were not sent.

**How to prevent:** Always build the `updateDefinition` envelope from a recent `getDefinition` (fetch ALL current parts), apply the edits locally to the parts that changed, and resend the COMPLETE set (modified + unchanged); never build the payload with only the files the editing session touched. This rule is already in [SKILL.md § TROUBLESHOOTING](../SKILL.md#troubleshooting) ("Parts missing after updateDefinition -> Must include ALL parts"); reinforced here: the error normally appears because someone builds the payload incrementally thinking "just send what changed", which is the wrong mental model for this endpoint.

**How to fix:** Repeat `getDefinition` to obtain the latest complete state, reapply the intended edits over that complete set, and resend `updateDefinition` with all the parts.

### 3.3 Incompatible compatibility level

**Symptom:** Error when creating the database/model, or when using a specific feature (e.g. DAX UDFs, advanced calculation groups, Direct Lake), such as "This feature requires a higher compatibility level" or a silent failure in which the feature is simply not recognized.

**Root cause:** Each generation of Analysis Services Tabular features (Direct Lake, DAX UDFs, certain partition types, newer model properties) requires a minimum `compatibilityLevel` on the model. Models created with an old level (e.g. inherited from a template or from an older copied model) do not support new features until explicitly raised.

**How to prevent:** When creating a model from scratch, always fix `compatibility level 1702+` (a rule already present in [SKILL.md § Workflow: Create new Semantic Model](../SKILL.md#workflow-create-new-semantic-model) and in [mcp-automation.md § 1](./mcp-automation.md#1-batch-sequencing-batch-build)); do not inherit the level from an old template without checking. Before using any "new" feature (Direct Lake, DAX UDFs, recent DAX functions), confirm the model's current compatibility level via `database_operations`/`model_operations` (get) and compare it against the minimum required by the feature's documentation, instead of finding out through the error.

**How to fix:** Raise the model's `compatibilityLevel` (an operation that is generally irreversible downwards; warn the user first) and revalidate that all existing objects remain compatible after the upgrade.

### 3.4 LRO (async operation) stuck on "Running" or "NotStarted"

**Symptom:** A long-running operation in Fabric (item creation, `updateDefinition`, some refresh operations) returns `202 Accepted` with a `Location`/`operationId`, but the polling never reaches "Succeeded"; it stays indefinitely on "Running"/"NotStarted", or the client stops polling before it finishes.

**Root cause:** The caller treats `202 Accepted` as definitive success and does not poll the LRO to its real completion (e.g. moves on to the next step of the batch assuming the object already exists), or the polling is done only once and not resumed. It can also be a genuine service-side problem (workspace operation queue, capacity quota); in that case, insisting without investigating only masks a real capacity problem.

**How to prevent:** Never treat `202 Accepted` as completion; always follow the `Location` of the response header and poll until `Succeeded`/`Failed` before considering the step done and moving on to the next one that depends on it (see [SKILL.md § TROUBLESHOOTING](../SKILL.md#troubleshooting): "202 Accepted but no result -> Poll LRO to completion"). When automating, define a reasonable maximum polling time (e.g. a few minutes); if it is exceeded, it is a sign to investigate the workspace capacity status, not to keep trying indefinitely.

**How to fix:** Keep polling the existing `operationId` until a terminal state; if a reasonable time passes with no change, check the capacity/workspace status in the Fabric portal before trying to recreate the operation (recreating without confirming that the previous one actually failed can generate the duplicate described in 3.1).

---

## 4. Refresh

### 4.1 Data source credential not configured

**Symptom:** Refresh fails with an error such as "Credentials could not be found" / "The credentials provided for the data source are invalid" right on the first attempt after deploy, even though the model is technically correct.

**Root cause:** When publishing/moving a model to Fabric/Power BI Service for the first time, the data source credentials are NEVER automatically inherited from the development environment (Desktop); they must be explicitly configured in the Service for each data source used by the model (user, gateway, or identity). It also occurs when the existing credential expires (password rotation, expired OAuth token) months after a refresh had already worked before.

**How to prevent:** Treat "configure credentials in the Service" as an explicit step separate from "publish the model" in any deploy checklist; never assume the first refresh will work without this manual step. This is one of the few points of the flow where the skill's rule is already explicit and correct: **never attempt a programmatic workaround for a credential error**; instruct the user to configure it manually in the Service portal (already documented in [SKILL.md § Workflow: Refresh Semantic Model](../SKILL.md#workflow-refresh-semantic-model) and reinforced in [mcp-automation.md § 6](./mcp-automation.md#6-when-to-stop-and-ask-even-in-automated-mode)).

**How to fix:** Stop immediately on seeing the error, tell the user exactly which data source has no credential (the error/API message usually identifies the datasource ID), and direct them to the dataset's credential configuration screen in the Service portal.

### 4.2 Refresh timeout in Direct Lake / framing

**Symptom:** The "reframing" operation (updating the Direct Lake pointers to the latest versions of the Delta files) takes much longer than expected or returns a timeout, especially on very large tables or tables with many small Parquet files.

**Root cause:** Direct Lake does not import data row by row; it remaps the model to the current Delta/Parquet files in OneLake. A slow "framing" usually indicates that the underlying Delta table has too many small files (no `OPTIMIZE`/compaction in the Lakehouse), outdated column statistics, or that the data volume exceeds what is reasonable for the provisioned Fabric capacity SKU (automatic fallback-to-DirectQuery guardrails can silently kick in when the model exceeds row/size limits).

**How to prevent:** Before adopting Direct Lake for a large table, check the health of the Delta tables at the origin (compaction, regular `VACUUM`/`OPTIMIZE` scheduled in the data pipeline); Direct Lake does not fix a mistreated Delta Lake, it only reflects its state. Check the row/size limits of the Fabric capacity SKU in use BEFORE committing the design to Direct Lake for volumes that may exceed those limits (see [direct-lake-guidelines.md](./direct-lake-guidelines.md), when applicable, for specific limits and guardrails). Monitor the model's fallback mode; if the engine falls back to DirectQuery automatically through a guardrail, that is a symptom of a table too large for the SKU, not an isolated refresh bug.

**How to fix:** Run `OPTIMIZE`/compaction on the underlying Delta tables before trying again; if the timeout persists, check whether the data volume exceeds the current SKU's guardrail and, if so, consider additional partitioning at the source or a review of the capacity plan with the user (a cost decision; do not decide alone).

### 4.3 Partition with M code referencing an unavailable source

**Symptom:** Refresh fails with a connection error ("Couldn't refresh the entity... underlying connection was closed", "Unable to connect") even though the credentials are correct.

**Root cause:** The partition's M code references a server/path/gateway that is not reachable from where the refresh is being run. Common cases: (a) an on-premises source with no gateway configured or with the gateway offline; (b) M code with a local file path (`C:\...`) copied from the development environment, which does not exist in the Service; (c) a firewall/VNet blocking the source's reach from Fabric.

**How to prevent:** Never leave local file paths or "hardcoded" connection strings from the development environment in production M code; use model parameters (see [modeling-guidelines.md § Parameters](./modeling-guidelines.md#parameters)) for the server/path, and confirm before deploy that the parameter value in the target environment is resolvable from the Service (not from the developer's laptop). For on-premises sources, confirm the existence and "Online" status of the gateway before publishing, and explicitly bind the dataset to that gateway (see [connection-binding.md](./connection-binding.md)) instead of assuming automatic binding.

**How to fix:** Test the source connectivity in isolation (outside the model, e.g. test the M query in a separate Power Query, or test the gateway in the portal), fix the parameter/path in the M code, and revalidate with a test refresh of the isolated table before propagating.

### 4.3b Datasource does not map to the existing gateway connection because of a textual difference in the server

**Symptom:** In the model's Settings screen (Service), "Gateway and cloud connections" keeps showing the source with an error status / an "Add to gateway" link (instead of the already pre-selected dropdown), even with the gateway "Online" and a connection of the right type already registered on it.

**Root cause:** Power BI matches a datasource to a gateway connection by **exact textual** comparison of the server string (and database/path). `localhost`, `127.0.0.1` and the real hostname are the same host, but different strings, and they never match automatically, even with a healthy gateway and an accessible source. This is distinct from 4.3 (source genuinely inaccessible): here the source works, only the *match* fails.

**How to prevent:** Before publishing an on-premises source for the first time, compare the server string used in the M code against the connections already registered in "Manage connections and gateways" (each connection's Server field, visible in the connection Settings); use exactly the same string, not an equivalent one.

**How to fix:** Adjust the server string in the source (the partition's M code, via `partition_operations`; see 1.6) to match exactly the existing gateway connection, instead of creating a new connection or editing the existing connection unnecessarily (the existing connection may already be used by other models/repos). After fixing and republishing, the "Maps to" dropdown starts listing the existing connection automatically.

### 4.4 Partial refresh with silently stale data

**Symptom:** The report shows apparently normal data, but the numbers do not match the source; investigation reveals that a specific table has not been updated for days/weeks, with no alert having fired.

**Root cause:** An incremental refresh, or a refresh of specific tables (not the whole model), was configured in a way that left a table out of scope; e.g. a poorly configured incremental refresh policy that never reprocesses the most recent partition, or a refresh pipeline that lists tables explicitly and forgets to include a new table added later. Unlike the previous errors, this one generates no visible failure: the refresh "finishes successfully" because technically it updated what was requested, but the requested scope was incomplete.

**How to prevent:** Whenever you add a new table to a model that already has an incremental refresh policy or a schedule with explicit scope, update that scope/policy explicitly in the same work session; treat it as part of "Add table" and not as a separate, forgettable task. When configuring incremental refresh, deliberately test that the most recent partition IS reprocessed (not just that the refresh "passes"), comparing the date/time of the most recent data in the table against the source.

**How to fix:** Audit the incremental refresh policy/schedule scope against the model's current list of tables (`table_operations` list), include any missing table, and force a full (non-incremental) refresh once to reconcile the state before going back to the normal incremental schedule.

---

## 5. Permissions / Authentication

### 5.1 401 because of the wrong token audience

**Symptom:** A `az rest` or direct REST call returns `401 Unauthorized` even with an apparently valid token and the user having ample permission in the workspace.

**Root cause:** The access token was issued for the wrong `--resource`/audience. The Fabric (`api.fabric.microsoft.com`) and Power BI (`api.powerbi.com`) APIs require tokens issued with specific audiences; a token valid for `https://api.powerbi.com` is not accepted at `https://api.fabric.microsoft.com` and vice versa, even though it represents the same user/application.

**How to prevent:** Always confirm which audience the endpoint being called requires (Fabric vs legacy Power BI) BEFORE acquiring the token, instead of habitually reusing the last token acquired for a call to a different endpoint. Consult [semantic-model-rest-api.md](./semantic-model-rest-api.md) and the authentication section of the Fabric REST API documentation for the correct endpoint -> audience mapping before any new call to an endpoint not yet used in the session.

**How to fix:** Correct the `--resource` (or the equivalent audience parameter) and acquire a new token specifically for that endpoint. If the error persists with the audience already correct, it is no longer an audience problem; it is a real lack of permission (see 5.2), and insisting on audience variations only masks that. Already documented in [SKILL.md § TROUBLESHOOTING](../SKILL.md#troubleshooting).

### 5.2 403 because of a missing Contributor+ role

**Symptom:** `403 Forbidden` when trying to create, edit or deploy an item in the workspace, even with the correct audience/token and even though the user can VIEW the workspace and its items.

**Root cause:** Workspace roles in Fabric/Power BI have granularity; Viewer and even some "Member" roles can view without being able to create/edit/publish items. Write operations (create item, `updateDefinition`, deploy) require at least the **Contributor** role in the workspace. A user with read access to the model (shared individually) but without a sufficient workspace role sees exactly this pattern: reads everything, writes nothing.

**How to prevent:** Before starting any authoring/editing/deploy flow, explicitly confirm (by asking the user or by inspecting the workspace role listing response, when the API exposes it) that the identity in use has Contributor+; do not discover this only after having already planned and attempted a whole sequence of write operations. This is exactly the case where the skill already says to **stop immediately and not retry** (see [SKILL.md § TROUBLESHOOTING](../SKILL.md#troubleshooting): "403 Forbidden / identity None -> User needs Contributor+ role - stop immediately. Do not retry."); the reason, reinforced here: retrying the same call without elevating the role never resolves it, because the cause is access configuration, not transient.

**How to fix:** This is not a fix the agent can perform; instruct the user (or a workspace administrator) to elevate the identity in use to Contributor or higher in the target workspace, then resume the flow from scratch.

### 5.3 Misconfigured RLS breaking the view for the user

**Symptom:** A specific user (or group) sees the report completely empty, with "(Blank)" everywhere, or sees data from another business unit by mistake, while the developer, testing as themselves (normally with admin/RLS-bypass access), cannot reproduce the problem.

**Root cause:** The RLS filter expression references a column/relationship that does not correctly cover all mapped users (e.g. the user→region mapping table has missing rows for some users, resulting in an empty filter = no visible rows), or the RLS was tested only with "View As" in Desktop, which does not always reproduce the Service's behavior 100% for roles involving bidirectional/inactive relationships. Another common cause: RLS defined on a table that is also the target of `USERELATIONSHIP` in some measure, a combination that is already documented as prohibited ([modeling-guidelines.md § Relationships](./modeling-guidelines.md#relationships): "Use USERELATIONSHIP against a table that also has Row-Level Security (causes errors)").

**How to prevent:** Always test RLS with "View As Role" simulating a real user from the mapping (not just the developer) before publishing, and ideally also confirm in the Service (not just in Desktop) for the same test user, since the behavior may differ in combination with bidirectional relationships. Before applying RLS to a table, check whether that table is the target of any `USERELATIONSHIP` in the model (`relationship_operations`/`measure_operations` list); if so, resolve the design conflict before publishing, not after a user reports an empty screen. Keep the user→security mapping table/logic audited to ensure 100% coverage of active users (no user without a mapping row).

**How to fix:** Reproduce the problem by testing "View As Role" with the specific affected user/group, check whether the mapping table has a row for that user, and fix the filter expression or the mapping data; never "temporarily turn off RLS" as a solution, however tempting; this is out of scope for this skill anyway (RLS/OLS management is an explicit DENY, see [SKILL.md § DENY](../SKILL.md#deny)) and should be redirected to the portal/administrator.

### 5.4 Service Principal without access to the workspace or the data source

**Symptom:** An automation/pipeline (CI/CD, scheduling) fails with `403`/`401` even though it works perfectly when the same operations are run manually by a human user.

**Root cause:** Automated flows typically authenticate as a Service Principal (SPN), which is an identity separate from human users and must be added EXPLICITLY both to the workspace (Contributor+ role) and, separately, to the data source's credentials/permissions (an SPN with workspace access may still have no credential configured for the refresh's data source). It is also common for the tenant to have "Service Principals can use Fabric APIs" disabled in the Admin Portal, blocking any SPN call before it even reaches item permission.

**How to prevent:** When planning any automation (deploy CI/CD, scheduled refresh outside the standard portal), confirm as an explicit prerequisite, before writing any call: (a) the tenant configuration allows SPNs to use the Fabric APIs; (b) the SPN was added to the workspace with the Contributor+ role; (c) the data source credentials were configured specifically for that SPN (not inherited from a human user). Document these three prerequisites alongside any automation script/pipeline so the next person setting up a new environment does not rediscover this by trial and error.

**How to fix:** Check each of the three points above in order (tenant configuration, workspace role, source credential), fixing whatever is missing; instruct the user/administrator when the fix requires Admin Portal access to the tenant, which is outside the reach of modeling operations.

## 6. MCP pitfalls with Power BI Desktop open

These come from real sessions against a model open in Power BI Desktop.

- **Calculated table formula:** `table_operations Update` with `daxExpression` can return success and change only the description. Change it through the partition (`partition_operations Update` with `expression`) and confirm with Get.
- **Recalculating a calculated table with relationships:** `table_operations Refresh` and `model_operations Refresh` can fail with "the base version must not be negative"; `partition_operations Refresh` with `refreshType: Automatic` passed.
- **Automatic date tables:** deleting only the relationship fails (the column has a `Variation` pointing to it); `table_operations Delete` with `shouldCascadeDelete: true` removes the table, the variation and the relationship. The `__PBI_TimeIntelligenceEnabled` annotation cannot be written through the MCP: turn it off in File, Options, Current File settings, Data Load.
- **Validating a relationship in DAX:** the filter does not propagate from the many side to the one side; test a dimension name with `LOOKUPVALUE`, not with `CALCULATE` through the fact key.
