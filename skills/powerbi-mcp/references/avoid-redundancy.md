# Preventing and diagnosing redundancy in semantic models

A systematic diagnosis guide. It does not repeat the point rules in `modeling-guidelines.md`
(duplicate measure, mirror measure, dead column). The focus here is the **process** of detecting
and avoiding model bloat before and after creating any object.

## Checklist before creating any new object

Run this mentally (or literally, with `INFO` functions) before every create call to `measure_operations`,
`column_operations` or `table_operations`:

1. **Does it already exist?** Search the model for a similar name, similar DAX, or the same business intent.
   Use `INFO.MEASURES()` / `INFO.VIEW.MEASURES()` and read the expressions, not just the names.
2. **Did the user ask for this now, or is the agent "getting ahead"?** If the question was "how much did I sell in
   2024?" the agent answers with a query; it does not create a `Sales 2024` measure "for the future".
   Create a new object only when the user asks for a new object (reusable measure, report column,
   relationship).
3. **Is it a measure or a calculated column?** See the dedicated section below. DAX that aggregates or changes
   granularity in the calculation is a measure; DAX that describes a fixed per-row attribute is a calculated
   column (and, better yet, should come from Power Query / the source).
4. **Is it a variation of something that already exists?** If the only difference is a filter (year, product,
   region) or the aggregation type (sum vs. average), the answer is to parameterize (field parameter,
   calculation group, or the user's own filter), not to duplicate the object.
5. **Will anyone use this after today?** If the answer is "only for this one-off analysis", do not
   materialize it in the model. Answer with ad-hoc DAX via `dax_query_operations` and do not persist it.

If any answer is "I'm not sure", ask the user before creating. Creating "just in case" is the
anti-pattern described below.

## DO / DON'T

**DO**
- Run `INFO`/DMVs to confirm an equivalent object does not exist before creating a new one.
- Prefer answering with an ad-hoc DAX query over creating a measure when the question is one-off.
- Consolidate variations of the same metric in a calculation group or field parameter.
- Measure the size and cardinality of any candidate new column before justifying its
  existence (Vertipaq Analyzer / `INFO.STORAGETABLECOLUMNS`).
- Check whether a column is referenced by a measure, relationship, hierarchy, sort-by or
  RLS before assuming it "must" keep existing.
- Explain to the user, in one sentence, why a new object is needed before creating it.

**DON'T**
- Create a calculated column, measure or table "just in case" without the user having asked for it.
- Duplicate a metric with a small filter variation instead of parameterizing.
- Trust the object's name to judge whether something equivalent already exists. Always look at the expression.
- Leave imported columns in place "because they came from the source" without checking actual use in the model.
- Add objects to the model to make it "more complete" without an explicit request.

## Detecting redundancy objectively (not by visual inspection)

Visual inspection of TMDL does not scale and is subjective. Use objective queries via
`dax_query_operations` (`INFO.*` functions or DMVs) to gather evidence before any
decision to remove, merge or not create an object.

### Columns never referenced

An unused column is a candidate for removal (or, at minimum, for `isHidden = true` and review). "Use"
means: referenced in some measure (DAX), used in a relationship, member of a hierarchy,
defined as the sort-by-column of another column, or used in RLS/perspective.

```dax
-- Model columns with storage metadata (Vertipaq)
EVALUATE
SELECTCOLUMNS(
    INFO.STORAGETABLECOLUMNS(),
    "Table", [TableName],
    "Column", [ColumnName],
    "Cardinality", [DistinctStates],
    "Bytes used", [UsedSize]
)
ORDER BY [Bytes used] DESC
```

```dax
-- Columns referenced by some measure (via the expression text)
-- Combine with INFO.COLUMNS() and do the cross-check outside DAX (script) when the volume
-- of measures is large, since DAX does not parse another measure's expression.
EVALUATE INFO.MEASURES()
```

In practice: export `INFO.MEASURES()` (`Expression` column), `INFO.COLUMNS()`,
`INFO.RELATIONSHIPS()`, `INFO.HIERARCHIES()` and `INFO.CALCULATIONITEMS()` and cross-check with a script
(the agent can do this by reading the TMDL directly instead of running DAX, since TMDL is greppable
text). Search for each `[ColumnName]` or `Table[Column]` in the expression bodies of other
measures, calculated columns, RLS and in the relationship/hierarchy/sort-by definitions. No
occurrence outside the column's own definition = candidate for removal.

### Tables without relationships (orphans)

```dax
EVALUATE
SELECTCOLUMNS(
    FILTER(
        INFO.TABLES(),
        NOT( [Name] IN SELECTCOLUMNS(INFO.RELATIONSHIPS(), "T", [FromTableName]) )
            && NOT( [Name] IN SELECTCOLUMNS(INFO.RELATIONSHIPS(), "T", [ToTableName]) )
    ),
    "TableWithoutRelationship", [Name]
)
```

An orphan table (other than parameter/disconnected tables used deliberately with
field parameters or "what-if") is a sign of an inflated model: imported data that was never
plugged into the star schema.

### Duplicate columns across tables

Same business meaning, present in two tables, without being the relationship key.
Detect by comparing name + type + value range (`MIN`/`MAX`/`DISTINCTCOUNT`) between columns
of different tables: if two columns in different tables have an identical or nearly identical
value distribution and are not PK/FK, one of them is probably redundant and should be
resolved via a relationship instead of repeating data.

### Semantically duplicate measures (different DAX, same result)

Beyond the obvious case (same DAX text, already covered in `modeling-guidelines.md`), the subtler case:
two measures with different DAX that always produce the same number. Signs:
- The same base `SUM`/`CALCULATE`, differing only in filter order or in an `ALL`/`REMOVEFILTERS`
  that changes nothing because the filtered column is not in any other report filter.
- One measure uses `DIVIDE(A,B)` and another uses `A/B` with the same `A` and `B`. Same intent; one is
  just less safe (it does not handle division by zero).
- One is an implicit measure (automatic aggregation of a column) and the other is the same aggregation
  written explicitly as an explicit measure. Keep only the explicit one and disable the implicit one
  when it makes sense for the model.

Confirm the suspicion by running both in `dax_query_operations` over the same set of test filters
and comparing the result, before proposing a merge to the user.

### Best Practice Analyzer (BPA) and Vertipaq Analyzer

- **Vertipaq Analyzer** (Tabular Editor rules / DAX Studio "VertiPaq Analyzer"): shows
  size on disk per column/table, cardinality and compression ratio. High-cardinality columns with low usage (few
  references) and high weight in bytes are the first candidates for removal or for a change of type/granularity.
- **BPA (Best Practice Analyzer)**: rules such as "avoid bidirectional relationships",
  "unnecessary columns not hidden", "check for measures with duplicate expressions", "avoid
  calculated columns" serve as an automated checklist equivalent to what this document asks to be
  done manually. When available in the environment, prefer running BPA and handling the
  findings by priority instead of hunting for redundancy only by reading TMDL.
- Rule of thumb: any column that appears at the top of Vertipaq Analyzer by size and does not
  appear in any measure/relationship/hierarchy/RLS is top priority for review.

## Calculated column vs. measure: decision criterion

- Does the value **change with the report's filter context** (time period, region, user selection)?
  -> measure.
- Is the value **fixed per row**, independent of any external filter, and used to
  group, sort, segment or build a relationship? -> column (ideally computed at the source/
  Power Query, not as a DAX calculated column, which does not compress as well and runs at processing time).
- If a "calculated column" only exists to be summed/counted later in a measure (e.g. a calculated
  column that is `0/1` for a condition, used only inside a `SUM` of another measure), that is a
  sign it should have been the measure itself with `CALCULATE`/`SUMX`/`COUNTROWS`, without
  materializing the helper column in the model.

## Anti-pattern: creating "just in case"

Creating a column, measure or table in anticipation of an unconfirmed future need is the main
generator of bloat:
- It inflates the model size (each column/measure takes up metadata and, for a column, space on
  disk in VertiPaq) even when unused.
- It confuses whoever uses the report: the fields pane shows 3 similar measures
  (`Sales`, `Total Sales`, `Sales (2)`) and the end user does not know which is the "right" one.
- It increases the maintenance surface: every new measure has to be maintained, documented and
  reviewed in future model changes, even if it was never used.
- Operational rule for the agent: **never create a model object as a speculative answer**.
  If the need was not stated by the user, answer with the information (via ad-hoc DAX query)
  or ask "do you want me to create this as a reusable measure, or just answer now?"
  before persisting any new object.

## Consolidating similar measures

When two or more measures have the same structure and differ only in what they measure (e.g.
`Sales`, `Cost`, `Margin` calculated the same way for different metrics) or in the filter
applied (e.g. `Sales Current Year`, `Sales Previous Year`, `Sales YTD`):

- **Field parameter**: when the variation is "which metric to show" and the user chooses it in a
  slicer. A parameter table with one column per measure, selectable in a single
  visual, instead of keeping N nearly identical measures and N nearly identical visuals.
- **Calculation group**: when the variation is "which time intelligence/comparison calculation to
  apply" over the same set of base measures (YTD, MoM, YoY, % of total). A single calculation
  group with N calculation items replaces N x M measures (N variations x M base metrics).
- Criterion to decide between the two: if the variation is in the **value being measured**, use a field
  parameter; if it is in the **filter/time transformation applied over the same base**, use a
  calculation group. Never keep both approaches in parallel for the same use case:
  choose one and migrate the existing duplicate measures to it, documenting the migration before
  deleting the old measures.
