# Relationships — Advanced Topics

This document goes beyond the basic relationship rules in `modeling-guidelines.md` (single-direction, integer keys, no composite keys, bi-directional/many-to-many caution, USERELATIONSHIP, RLS). It covers virtual relationships, real many-to-many patterns, role-playing dimensions, limited relationships, ambiguity resolution, cross-filter bugs, and diagnosis of relationship problems.

## 1. Virtual relationships via DAX (TREATAS)

A virtual relationship propagates filters between tables using DAX instead of a physical relationship in the model. `TREATAS` applies the values of one table's column(s) as filters on another table's column(s), as if a relationship existed.

**When to use instead of a physical relationship:**
- The join key is not unique on either side and a physical relationship would be "limited" (see section 4) or simply not creatable (many-to-many on both directions with ambiguity risk).
- You need multiple simultaneous "what-if" relationships that change per measure without cluttering the model with inactive relationships.
- The relationship only needs to exist for one or two measures, not for general slicing/filtering across the whole model (a physical relationship affects every report visual; TREATAS affects only the measure that uses it).
- You are bridging a table that should NOT be visible to Q&A/Copilot or used for generic filtering, only for a specific calculation.

**DON'T** reach for TREATAS as a substitute for correct star-schema design. If the relationship should exist for every report visual, model it physically. TREATAS is a scalpel for specific measures, not a replacement for basic modeling.

```dax
Sales in Selected Region :=
CALCULATE (
    [Total Sales],
    TREATAS ( VALUES ( 'Region Filter'[Region] ), 'Sales'[Region] )
)
```

**Trade-off:** TREATAS is evaluated at query time and does not use the same storage-engine relationship optimizations (no `USERELATIONSHIP`-style plan reuse, no relationship-based cardinality estimation). On large fact tables it can be materially slower than a physical relationship. Test with real data volume before committing to it as the primary mechanism.

## 2. Real many-to-many: bridge table vs native m:m relationship

Power BI supports a native many-to-many relationship (no unique key on either side), but "supported" is not the same as "recommended" for every case.

**Bridge table pattern (DO, preferred for most cases):**
Introduce a dimension-like bridge table containing only the distinct combinations of the many-to-many keys, with 1:m relationships from each side into the bridge.

```
'Customer'[CustomerKey] 1 --- m 'Customer Account Bridge'[CustomerKey]
'Customer Account Bridge'[AccountKey] m --- 1 'Account'[AccountKey]
```

- Filter propagation is explicit and easy to reason about.
- The bridge table can carry attributes of the relationship itself (e.g., % allocation, effective dates).
- Works predictably with bi-directional filtering when needed on just the bridge, not on the fact tables.

**Native m:m relationship (relationship directly between two tables, neither column unique):**
- Simpler to set up, no extra table.
- **DON'T** use it when you need to also filter or weight by the relationship's own attributes (allocation %, date ranges) — there is no place to store them.
- Harder to diagnose (see section 6): duplicated key values on both sides make it easy to accidentally fan out row counts.
- Storage engine handles it, but query plans for m:m are generally more expensive than 1:m through a bridge, especially with bi-directional filtering combined.

**Rule of thumb:** if the relationship needs weighting, has its own attributes, or spans more than two tables (e.g., customer-to-account-to-cost-center), always use a bridge. Use the native m:m relationship only for simple, two-table, unweighted cases with low cardinality.

## 3. Role-playing dimensions — multiple relationships between the same two tables

Example: `Order Date`, `Ship Date`, `Due Date` all reference the same `Date` table.

**DO:**
- Keep exactly one relationship **active** (usually the primary business date, e.g. Order Date) and mark the others **inactive**.
- Activate the inactive relationship per measure with `USERELATIONSHIP`, never by trying to make several relationships active — TMDL/the model only allows one active path between two tables at a time anyway.

```dax
Sales by Ship Date :=
CALCULATE (
    [Total Sales],
    USERELATIONSHIP ( 'Sales'[ShipDateKey], 'Date'[DateKey] )
)
```

- Alternative for a cleaner reporting experience: create **role-playing physical copies** of the dimension (e.g., a calculated table or separate import `Ship Date`, `Due Date` tables) when users need to slice by more than one date role *simultaneously in the same visual*. USERELATIONSHIP only swaps which single relationship is active for that one measure call — it cannot make a visual filter by two roles at once.
- Name the inactive relationship's measures clearly (`Sales by Ship Date`, not `Sales 2`) so the role is obvious without inspecting the model.

**DON'T:**
- Don't leave multiple relationships active between the same two tables — Power BI will simply not allow it; you'll be forced to pick one, so decide deliberately which is the default context for plain filtering (e.g., slicers, default date visual).
- Don't create a `USERELATIONSHIP` measure for every possible combination speculatively — only build the ones actual report requirements need. Each one is a maintenance burden.

## 4. Weak / limited relationships (non-unique column on both sides)

A "limited relationship" (Tabular term) happens when the column on the "one" side is not guaranteed unique — Analysis Services can't validate uniqueness (common in DirectQuery, or Import tables where the engine hasn't been told the column is a key).

**Implications:**
- The engine cannot assume "1" cardinality even if you set the relationship as one-to-many; it may fall back to treating it more conservatively, which changes context transition behavior in DAX (e.g., `RELATED()` can behave unexpectedly, and some engine optimizations are skipped).
- In DirectQuery models this is very common because SQL Server can't always push down a uniqueness guarantee; check that the source column actually has a primary key/unique constraint and that it's declared in the model.
- Symptom: a relationship you expect to be "one-to-many" instead behaves as "many-to-many" in the model view, with the round/diamond marker Power BI shows for m:m, even though you never intended that.

**DO:**
- Always enforce a real unique constraint (PK) on the dimension key in the source system when possible, and verify the Power BI relationship shows the correct one-side cardinality after creation — don't just trust what you clicked.
- After creating a relationship, use `relationship_operations` (or Model view) to inspect `fromCardinality`/`toCardinality` and confirm it matches intent. A relationship silently downgraded to m:m due to duplicate keys is a common source of double-counted totals.
- If duplicates are a real, permanent property of the source data (not a data-quality bug), treat it explicitly as many-to-many (bridge table, section 2) rather than letting the engine guess.

**DON'T:**
- Don't ignore a warning that a relationship's expected "1" side has duplicate values — this is very often the root cause of numbers that don't tie to the source report.

## 5. Filter ambiguity between multiple paths

Power BI's engine requires that between any two tables there be **at most one active** filter path. If your model design implies two plausible paths (e.g., two dimensions each connected to two different fact tables, forming a diamond), the engine does not "pick the best one" — it typically:
- Refuses to create the second active relationship at all (forces you to leave it inactive), or
- If both are somehow active via different chains, results become inconsistent/ambiguous and Power BI may show an error or silently return unexpected numbers when the model does allow it (e.g., via composite/bi-directional combinations).

**DO:**
- Diagram the intended filter paths before building. Any table reachable from a filter via two different chains is a design smell — resolve it, don't let the engine "figure it out."
- Use a single bridge/conformed dimension shared by both fact tables (classic star-schema fix) instead of relating fact-to-fact tables or letting two dimensions both connect directly to each other.
- If an ambiguous path is unavoidable, keep only one relationship active and use `USERELATIONSHIP` for the alternate path in the few measures that need it (same pattern as role-playing dimensions).

**DON'T:**
- Don't relate two fact tables directly to "make a number work" — this is almost always solvable by adding a shared dimension or using TREATAS, and it opens the door to ambiguity as soon as a second fact table needs a similar connection.

## 6. Cross-filter direction — performance and correctness impact

**Real bug example: bi-directional filtering causing inflated totals.**

Model: `Sales` (fact) 1:m from `Product`, and `Product` also m:m or bi-directional to `Product Category Target` (a table with one row per category holding budget targets). If the relationship `Product` → `Sales` is set to bi-directional (so a slicer on `Sales` measures can filter `Product`), and `Product Category Target` is also bi-directionally connected to `Product`, then filtering by any `Sales` attribute now also filters `Product Category Target`, and — worse — if there's any other path back to `Sales` through category, you can get filter context leaking in a loop that inflates or deflates aggregates unexpectedly. The visible symptom is usually: a total that's correct with no slicers, but wrong (often duplicated) as soon as an unrelated slicer touches a bi-directional path.

**DO:**
- Default every relationship to single-direction (dimension → fact). This matches the guidance in `modeling-guidelines.md`; the deeper reason is that bi-directional filtering is a global setting affecting *every* visual and *every* measure that touches those tables — you can't scope it to one report page or one measure the way you can scope `USERELATIONSHIP` or `CROSSFILTER()`.
- If you need bi-directional behavior for a specific measure only (not model-wide), use `CROSSFILTER( 'A'[Key], 'B'[Key], BOTH )` inside that one `CALCULATE`, and keep the physical relationship single-direction.

```dax
Products with Sales in Region :=
CALCULATE (
    DISTINCTCOUNT ( 'Product'[ProductKey] ),
    CROSSFILTER ( 'Sales'[ProductKey], 'Product'[ProductKey], BOTH )
)
```

- Performance: bi-directional relationships restrict the query engine's ability to use certain join optimizations and increase the risk of the ambiguity described in section 5 as the model grows. Every bi-directional relationship you add is a compounding cost on every future table you connect nearby.

**DON'T:**
- Don't set a relationship to bi-directional "to make a slicer work" without checking whether that slicer's table has any other path back into the fact table. Check the full graph, not just the two tables you're currently looking at.

## 7. Diagnosing relationship problems

**Fact rows that don't connect to a dimension (orphan/missing keys):**
- Add a validation query: `COUNTROWS ( FILTER ( Sales, ISBLANK ( RELATED ( 'Product'[ProductKey] ) ) ) )` — nonzero means fact rows have keys with no match in the dimension. Blank/(Unknown) rows in visuals are a symptom of this.
- Fix at the source (referential integrity in ETL) if possible; otherwise add an explicit "Unknown Member" row to the dimension rather than letting Power BI silently produce a blank category.

**Duplicated / inflated counts (fan trap):**
- Classic cause: a measure aggregates a fact table that is joined through a dimension which itself has a 1:m (or m:m) relationship to *another* table containing multiple rows per key, and that second table's rows silently multiply the fact rows during evaluation — most often seen with snowflaked or denormalized-then-rejoined dimensions, or an accidental m:m from section 4.
- Diagnostic: compare `SUM ( Sales[Amount] )` with no relationships involved (e.g., a disconnected total via a measure with `ALL` on the suspect tables) against the same measure filtered through the suspicious path. A jump in total when adding an unrelated dimension to a visual is the tell-tale sign of a fan trap.
- Check `relationship_operations` output for any relationship where you expected 1:m but cardinality shows m:m ("limited") — this is the single most common cause.

**General workflow before shipping a relationship change:**
1. List all relationships touching the changed table (`relationship_operations`) and confirm cardinality and direction match intent.
2. Re-run a small set of "known good" totals (numbers already validated against source) and confirm they didn't move.
3. Add one unrelated dimension from elsewhere in the model to the same visual and confirm the total doesn't change — if it does, you have ambiguity or a fan trap, not a coincidence.
