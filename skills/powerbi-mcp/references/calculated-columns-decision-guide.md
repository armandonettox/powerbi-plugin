# Decision Guide: Calculated Column vs Measure vs Native Column vs Calculated Table

This document is an in-depth decision tree for choosing the right type of object in the model. It does not repeat the basic rules in `modeling-guidelines.md` (prefer measures, avoid RELATED, do not use for filter context) — the focus here is on the mandatory cases, anti-patterns, and the technical "why".

## Decision tree

```
Does the value need to be calculated?
|
+-- NO, the data already comes ready or only needs transformation/cleanup
|     -> NATIVE COLUMN (Power Query / M) or a source column
|        E.g.: trim, split a DateTime, type conversion, table merge,
|              concatenation of a key that should come from the database
|
+-- YES, it needs a calculation
      |
      +-- Does the calculation change according to the report filter
      |   (visual context, slicer, page, drillthrough)?
      |     -> YES -> MEASURE (DAX with aggregation: SUM, CALCULATE, etc.)
      |
      +-- Is the value fixed per row, unaffected by report filters?
            |
            +-- Does it need to be used as:
            |     - a visual axis/legend
            |     - a slicer/filter field
            |     - one side of a relationship
            |     - RLS context (security rule)
            |     - a sort-by column
            |   -> YES to any of them -> CALCULATED COLUMN (DAX, row by row)
            |      (mandatory: a measure cannot fill these roles)
            |
            +-- NO to all of them, it is just a derived value
                 for use inside another measure or as an informational attribute?
                   -> Ask: "can I push this calculation to the source (M/SQL)?"
                     -> YES, almost always possible -> NATIVE COLUMN (M) at the source
                     -> NO (depends on a relationship between model tables,
                        complex row context, or a DAX function
                        with no equivalent in M/SQL) -> CALCULATED COLUMN,
                        as a last resort

Is the object an entire TABLE (not a column)?
|
+-- Does the table not exist at the source and need to be GENERATED
    (calendar, parameter table, field parameter table,
     small static mapping table)?
      -> YES -> CALCULATED TABLE (DAX: CALENDAR, GENERATESERIES,
         SELECTCOLUMNS over other model tables, etc.)
      -> NO, the table exists at the source but you are "recreating" it
         via DAX because it is easier -> SIGN OF WRONG MODELING.
         Bring the table in via M/Power Query or directly from the source.
```

## Cases where a calculated column is MANDATORY

There is no measure-based alternative in these scenarios — the Power BI/Tabular engine requires a materialized value per row:

### 1. Axis, legend, or category of a visual
A bar chart, matrix, or category visual needs a column (dimension) on the axis, not a measure. If the categorization depends on row-by-row conditional logic coming from more than one table with no natural key, a calculated column solves it:

```dax
'Sales'[Value Band] =
SWITCH(
    TRUE(),
    'Sales'[Total Value] <= 100, "Up to $100",
    'Sales'[Total Value] <= 500, "$100 to $500",
    "Above $500"
)
```
Prefer doing this in M if the logic only depends on columns of the same source table — only use DAX if it depends on another model table (RELATED) or on a calculation that M cannot easily reach.

### 2. Relationship key
When the source does not provide a unique key and it has to be built (concatenating columns, for example), no measure can be one side of a relationship — only columns can.

```dax
'Fact Visit'[Customer-Date Key] =
'Fact Visit'[Customer ID] & "-" & FORMAT('Fact Visit'[Date], "YYYYMMDD")
```
**Caution:** this is also the most common anti-pattern (see the section below). Only accept this solution when the key really cannot come from the source.

### 3. Slicer / report filter
A slicer operates on the distinct values of a column. If the grouping (e.g., age bands, product ABC classification) needs to exist as a filter option, it has to be a column:

```dax
'Product'[ABC Class] =
VAR ProductRank = RANKX(ALL('Product'), [Total Revenue])
RETURN
    SWITCH(
        TRUE(),
        ProductRank <= 10, "A",
        ProductRank <= 30, "B",
        "C"
    )
```
Warning: RANKX in a calculated column evaluates in the row context of the whole table at refresh time, not in the report's filter context — the result is fixed until the next refresh. If the classification needs to react to report filters, that is a measure's job, not a column's (see the tree above).

### 4. Row-Level Security (RLS)
RLS rules in the DAX Filter Expression compare a column value with `USERPRINCIPALNAME()` or similar. A measure cannot be used there. If the "who sees what" logic depends on a combination of columns, it is often worth materializing it in a calculated column (or better, in a native column coming from the source) to simplify the rule and improve RLS performance.

### 5. Sort-by column
Sort columns (`sortByColumn`) can only point to another column of the same type/cardinality — never to a measure. If the correct order (e.g., "Quarter" sorted numerically, "Status" in a specific business order) does not exist at the source, a calculated column solves it, but prefer creating this column via M/the source when possible, because it is static.

### 6. Hierarchies defined in the model (user hierarchies)
Like relationships, the levels of a hierarchy defined in the model need to be materialized columns.

## Common anti-patterns (where developers go wrong)

### Concatenating a "unique key" that should come from the source
See above: creating `[Customer ID] & "-" & [Year]` via DAX when the data warehouse or the source query could generate that key directly (concatenation in SQL, or `Table.AddColumn` in M). The DAX calculation runs row by row during the tabular model refresh, using the VertiPaq processor instead of the source's processor (which is usually more efficient for this kind of bulk operation), and it also prevents filter push-down. **Fix:** move the concatenation to the SQL/M query whenever the source allows it.

### Simple boolean flags that should be M
`'Order'[Is Late] = IF('Order'[Delivery Date] > 'Order'[Expected Date], TRUE(), FALSE())` works, but if both date columns already exist in the same source table, this comparison is trivial in Power Query (`Table.AddColumn` with a conditional expression) or even better, in the SQL query itself. Practical reason: M/native columns are computed outside the VertiPaq engine (in most cases on the source side or in the mashup engine) and do not add to the column calculation time of tabular processing; they are also easier to debug outside DAX.

### Row-by-row aggregate calculations that should be a measure
A classic mistake: creating a calculated column that sums values from another table via `RELATED`/`CALCULATE` expecting to see the total "per report context", but the value stays frozen since the refresh because a calculated column does not react to a visual filter.

```dax
-- WRONG: calculated column trying to simulate filter context
'Customer'[Total Purchases] =
CALCULATE(SUM('Sales'[Value]), RELATEDTABLE('Sales'))
```
This only returns the fixed total since the last refresh — it will never respect a date slicer in the report. The right pattern is a measure:
```dax
[Total Purchases] = SUM('Sales'[Value])
```
And if you need to show "Total Purchases" as a customer attribute (for example, for an ABC segmentation done once per refresh), then the calculated column is acceptable — but count it under the "mandatory" section, not here.

### Duplicating in DAX what the source already provides
Recreating in a calculated column a piece of business logic that exists as a view/computed column in the data warehouse. Warning sign: if you have write access to the source SQL query and the logic only depends on columns of the same table, the calculated column is compensating for an upstream modeling problem, not solving a real problem of the semantic model.

## Performance and memory: calculated column vs native column

Technical summary, without repeating what is already in `modeling-guidelines.md`:

- **Compression**: native columns (coming from M/the partition) are compressed by VertiPaq during normal table processing, in the same pass that reads and sorts the source data. Calculated columns are computed **after** the entire table (and all related tables used in the DAX expression) has been processed, and VertiPaq can only compress the calculated column in that second pass — this means re-sorting and recompressing the whole table every time a calculated column is added or changed, which can be expensive on large tables.
- **Compression order**: the order in which columns are processed affects the compression rate of all the table's columns (RLE/dictionary encoding depends on row ordering). High-cardinality calculated columns tend to compress worse than equivalent native columns, because they do not take part in the initial sorting phase.
- **Refresh time**: each calculated column adds a *serial* calculation step after the data load (it does not parallelize as well as partition reads). On large fact tables with several calculated columns that depend on RELATED/CALCULATE, this can dominate the total refresh time.
- **Dependencies between calculated columns**: if a calculated column depends on another calculated column (or on a calculated table), the engine has to resolve the calculation order, which can cause cascading recalculations on every incremental refresh, even when only a small part of the data changed.
- **Rule of thumb**: for any calculated column that **could** be resolved at the source (SQL) or in M, the cost of keeping it in DAX is strictly higher — both in refresh time and in final model size — with no functional gain. It is only worth keeping in DAX when the logic depends on a relationship between tables of the tabular model itself (something M cannot reach) or on a DAX function with no practical equivalent in M/SQL.

## Calculated tables: when to create them and when it is a sign of error

### Legitimate cases
- **Calendar/date table**: generated via `CALENDAR`/`CALENDARAUTO` + calculated columns for Year, Month, Quarter, etc. This is the classic, recommended case, because the table does not physically exist at the source and needs one row per day within a range controlled by the model.
  ```dax
  Calendar =
  ADDCOLUMNS(
      CALENDAR(DATE(2020,1,1), DATE(2026,12,31)),
      "Year", YEAR([Date]),
      "Month", FORMAT([Date], "MMMM")
  )
  ```
- **Parameter table (What-if / field parameter)**: a small static table generated in DAX (`GENERATESERIES`, `UNION` of `ROW`) to serve as a selection axis within the report — it does not represent business data, it represents interface options.
- **Small, static mapping/bridge table**: when the mapping logic is short, does not change often, and does not exist (nor is it worth having) at the source — for example, a "Target bands" table with 5 fixed rows.
- **Tables derived from other model tables via DAX** (`SUMMARIZECOLUMNS`, `SELECTCOLUMNS`) when the goal is a "role-playing" or disconnected dimension table, created from the distinct values of an existing column, and that could not come from anywhere else without duplicating business logic.

### Sign of wrong modeling
- Recreating via DAX a fact or dimension table that **exists** at the source, just because "it is faster to write the formula now". This ignores the M/SQL engine (better suited to transforming large sets), duplicates business logic inside the semantic model (hard to maintain/test), and leaves the table outside the normal incremental refresh flow.
- Large calculated tables (thousands/millions of rows) are an anti-pattern — the calculation runs entirely in memory during model processing and does not benefit from incremental partitioning the way an M table pulled from the source does.
- Using a calculated table to "solve" a many-to-many relationship that should be modeled with a bridge table coming from the source.

## Field parameters as the modern alternative

Field parameters (a Power BI Desktop feature, generated as a special calculated table with the `[Parameter Order]` column and field parameter metadata) replace several older uses of "selection" calculated columns:

- **Before**: creating a calculated column like `'Sales'[Selected Metric]` fed by a numeric What-if parameter, combined with `SWITCH` in a measure to switch between KPIs.
- **Now**: creating a field parameter that lists the **measures** (Revenue, Quantity, Margin) as slicer options, letting the user switch what appears on a chart's Y axis without needing a calculated column or a manual `SWITCH` over a numeric parameter.

When to use a field parameter instead of a selection calculated column:
- The "selection" is between different measures for the same visual (metric switch) -> field parameter of measures.
- The "selection" is between different columns to group a visual by (switching the analysis dimension, e.g., analyzing by Region vs by Salesperson) -> field parameter of columns.
- The selection involves real business logic (not just switching a visual's axis/metric) that needs to be reused in RLS, a relationship, or an export -> then consider a calculated column, because a field parameter is a report-layer feature (Power BI Desktop), not an object persisted equivalently to a column in the tabular engine for all purposes (it does not work for RLS or for relationships).

Field parameters are implemented as a calculated table with a special metadata column (`Parameter Order`) and a DAX expression generated automatically by Desktop — in practice, it is a specific, already-solved case of a "calculated table for interface purposes", exactly the legitimate pattern described in the previous section.
