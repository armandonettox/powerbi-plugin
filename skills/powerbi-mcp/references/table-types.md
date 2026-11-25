# Table Types Catalog

This document goes deeper into the TYPES of tables that exist in a dimensional/Power BI model. It does not repeat generic table/column/relationship rules -- those are in [modeling-guidelines.md](modeling-guidelines.md). Use this file to decide, before modeling any new table, **which type it is** and how that changes grain, cardinality, relationships and TMDL properties.

## How to decide the type before modeling

Ask, in this order:

1. **Does the table store events/measurements that happened, or entities/context that describe those events?**
   - Events/measurements -> it is a **Fact**. Go to "Which fact grain?".
   - Entities/context -> it is a **Dimension** (or a variant).
2. **Which fact grain?**
   - One row per individual transaction -> **Transactional**.
   - One row per entity at each fixed time interval (balance, status), even without a transaction -> **Periodic snapshot**.
   - One row per process/pipeline, updated as it advances through stages (multiple milestone dates) -> **Accumulating snapshot**.
   - Only relates dimensions, with no numeric measure (records that an event occurred or a combination is valid) -> **Factless fact**.
3. **Does the dimension change over time and do you need the historical value (as it was on the sale date)?**
   - No, the current value is always enough -> **SCD Type 1**.
   - Yes, I need the history -> **SCD Type 2**.
4. **Does the dimension only exist to serve ONE specific fact and have no attributes of its own beyond a code/number that is embedded in the fact?** -> **Degenerate dimension**.
5. **Is the same physical dimension (e.g. Calendar) used in different roles in the same fact (Order Date, Delivery Date, Payment Date)?** -> **Role-playing dimension**.
6. **A bunch of low-cardinality attributes with no logical relationship to each other, which would be left loose in the fact?** -> **Junk dimension**.
7. **Do two entities have a many-to-many relationship (a Customer has several contact Emails, a Product belongs to several Categories)?** -> **Bridge table**.
8. **Does the table exist only to feed a slicer/parameter that does not physically filter anything (it switches what a measure displays)?** -> **Parameter/disconnected table**.
9. **Does the table exist only to speed up queries by pre-aggregating a larger fact?** -> **Aggregation table**.

---

## 1. Fact Tables

### 1.1 Transactional Fact

The most common type. One row per discrete event, at the moment it occurs.

- **Grain**: one event = one row (e.g. one row per item sold in an order).
- **Examples**: sales lines, financial entries, clicks, opened tickets.
- **When to use**: whenever the business asks "what happened" and each occurrence is independent and does not repeat over time.
- **Behavior in the model**:
  - No visible primary key of its own -- `isKey` must never be `true` on a fact column (see modeling-guidelines.md).
  - Foreign keys to all relevant dimensions, always hidden (`isHidden = true`).
  - Numeric measures with `summarizeBy` configured so that implicit aggregation is blocked -- always create an explicit measure.
  - Grows continuously; usually the largest table in the model -- the best candidate for incremental partitioning.

```tmdl
table 'Sales'
    measure 'Total Sold' = SUM('Sales'[Item Value])
        formatString: "$#,##0.00"

    column 'Customer Key'
        dataType: int64
        isHidden

    column 'Item Value'
        dataType: decimal
        isHidden
        summarizeBy: sum
```

### 1.2 Periodic Snapshot Fact

One row per entity at each fixed time interval (day, week, month, end of day), regardless of whether there was a transaction.

- **Grain**: one row per [entity] per [period] (e.g. one row per bank account per day with the balance).
- **Examples**: daily inventory balance, account balance, contract status at the end of each month, number of active subscribers per month.
- **When to use**: when the business needs to see "how X was at a given moment", not just "what changed". Metrics that cannot be summed over time (balances, inventory) require this format -- summing daily balances over a month makes no business sense.
- **Behavior in the model**:
  - One date key per row, always related to the Calendar table.
  - Measures are usually "semi-additive": summable across entities in the same period, but not across periods -- use `LASTDATE`/`LASTNONBLANK` in the measures instead of a direct `SUM` over time.
  - Row volume grows by (number of entities x number of periods) -- it can get big fast; consider a coarser granularity (monthly instead of daily) if volume is a problem.

### 1.3 Accumulating Snapshot Fact

One row per instance of a process with multiple stages/milestone dates, updated (UPDATE, not INSERT) as the process advances.

- **Grain**: one row per process (e.g. one order, from the start to the end of the flow).
- **Examples**: order pipeline (order date -> approval date -> shipping date -> delivery date), support ticket funnel, sales pipeline (lead -> proposal -> close).
- **When to use**: when the business wants to measure time between stages of a process with a finite, known number of stages.
- **Behavior in the model**:
  - Multiple date columns, one per milestone -- each becomes a role-playing relationship with the Calendar (see section 2.3).
  - Duration measures between stages are usually calculated as columns or DAX measures using `DATEDIFF` between the milestones.
  - Unlike the transactional fact: the row is updated repeatedly until the process completes, so in the ETL the load strategy is different (upsert, not append-only) -- this is relevant for explaining to the user why the refresh is not a simple incremental one.

### 1.4 Factless Fact

A fact table with no numeric measure -- only foreign keys. It records that an event occurred or that a combination of dimensions is valid.

Two subtypes:
- **Event without measure**: records an occurrence (e.g. student attendance in a class, page access log). The metric is the row count itself.
- **Coverage/eligibility**: records valid combinations even without an event (e.g. which products were on promotion in each store in each week, to later compare against what actually sold).

- **When to use**: to answer "how many times X happened" when there is no value to sum, or to enable "what should have happened vs. what happened" analyses (comparing an eligibility factless fact against the actual transactional fact).
- **Behavior in the model**:
  - No numeric measure column -- the measure is always `COUNTROWS` of the table itself or `DISTINCTCOUNT` of one of the keys.
  - Easy to confuse with a small dimension -- the difference is that the factless fact has an event/combination grain (several rows per dimension member), while a dimension has one row per entity.

### Fact table comparison

| Type | Grain | Typical measure | Changes over time? | Volume |
|---|---|---|---|---|
| Transactional | 1 event | Direct SUM | Append-only | High, grows linearly |
| Periodic snapshot | 1 entity x 1 period | Semi-additive (LASTDATE) | Append per period | entities x periods |
| Accumulating snapshot | 1 process | DATEDIFF between milestones | Update (upsert) | Moderate, stable |
| Factless fact | 1 event/combination | COUNTROWS / DISTINCTCOUNT | Depends on subtype | Variable |

---

## 2. Dimension Tables

### 2.1 Regular Dimension

Describes the "who, what, where" of a fact event. One row per business entity.

- **Behavior in the model**: primary key (`isKey = true`) only on the dimension, never on the fact. One-directional 1:N relationship (dimension:fact).

### 2.2 Degenerate Dimension

An attribute that stays in the fact table itself instead of a separate dimension, because it has no additional attributes -- it is just an identifier of the event itself (invoice number, order number, ticket number).

- **When to use**: when the only "attribute" is the transaction identifier itself, and creating a separate dimension would produce a table the same size as the fact without bringing any extra attribute (a dimension with cardinality = number of fact rows).
- **Behavior in the model**: stays as a column in the fact itself, usually hidden if used only for technical grouping, or visible if the user needs to filter/display by order number. It does not become a table or a relationship.
- **DON'T**: turn an order/invoice number into a separate dimension "because it looks like a dimension" -- that creates a huge, useless table with no attributes.

### 2.3 Role-Playing Dimension (multiple roles)

The same physical dimension table is used in different roles in the same fact -- the classic example is the Calendar: Order Date, Shipping Date, Delivery Date, Payment Date all reference the same Calendar table.

- **When to use**: whenever a fact has more than one date column (or other dimension) conceptually referencing the same entity.
- **Behavior in the model -- the most important part**:
  - Power BI/Tabular Model **does not natively support multiple simultaneously active relationships** between the same two tables. Only one can be `isActive = true`; the others stay `isActive = false` and need an explicit `USERELATIONSHIP` in the measures that use them.
  - **DON'T**: create inactive relationships without the corresponding measure with `USERELATIONSHIP` -- that is an orphan and signals incomplete modeling (see modeling-guidelines.md, Relationships section).
  - **More robust, recommended alternative**: create physical copies of the dimension (calculated table or view at the source) for each role -- `Order Date`, `Delivery Date` -- each with a single active relationship. This avoids `USERELATIONSHIP` scattered across several measures and makes the model more readable for self-service users, at the cost of duplicating the table in memory (usually low cost for a Calendar table).
  - Choose between the two approaches depending on how many measures will vary by role: few fixed measures per role -> `USERELATIONSHIP`; user needs to freely switch the role in any visual -> duplicated physical tables.

### 2.4 Slowly Changing Dimension (SCD)

Handles how a dimension behaves when its attributes change over time.

**SCD Type 1 -- overwrite**
- The old value is lost; the row is updated in place.
- **When to use**: when the attribute's history does not matter for analysis (e.g. correcting a registration error, a customer's phone number).
- **Behavior in the model**: no structural change -- it is the default pattern of any dimension without special handling.

**SCD Type 2 -- version**
- Each change generates a new row, with its own surrogate key, and validity control columns (`StartDate`, `EndDate`, `IsCurrent`).
- **When to use**: when the business needs "the salesperson was in the South Region when the sale was made, even though today they are in the Southeast Region" -- correct historical analysis requires the value in effect on the fact date, not the current value.
- **Behavior in the model**:
  - The key linking fact->dimension must be the surrogate key, not the business (natural) key -- otherwise the fact always points to the wrong or an ambiguous version.
  - This means the ETL at the source must resolve, when loading the fact, which surrogate key was in effect on the event date (lookup by validity interval) -- it is not something resolved inside the Tabular/DAX model.
  - `IsCurrent` should stay hidden if used only internally by the ETL; expose a "Current Version" attribute (Yes/No) if the user needs to filter only the current snapshot.
- **DON'T**: implement SCD Type 2 inside Power BI via DAX -- that is the responsibility of the ETL/warehouse layer. The semantic model only consumes the table already correctly versioned.

### 2.5 Junk Dimension

Combines multiple low-cardinality attributes with no strong logical relationship to each other (flags, codes, Yes/No indicators) into a single table, instead of leaving them loose as columns in the fact or creating a mini-dimension for each one.

- **When to use**: when the fact has several small categorical attributes without enough context of their own to justify separate dimensions (e.g. Payment Method + Channel + Discount Applied Indicator + Shipping Type, each with few possible values).
- **Behavior in the model**:
  - One row per distinct observed combination of the attributes (theoretical Cartesian product, but in practice only the combinations that occur).
  - Reduces the number of foreign keys in the fact (one key to the junk dimension instead of 4-5 separate keys), which helps keep the fact narrower.
  - **DON'T**: use a junk dimension for high-cardinality attributes -- the Cartesian product explodes and the table becomes as large as the fact, losing the benefit.

### 2.6 Bridge Table (many-to-many relationship)

An intermediate table that resolves an N:N relationship between two dimensions (or between a dimension and a fact) that the tabular model does not directly support with a single key.

- **Examples**: a Customer with several Salespeople responsible simultaneously; a Product belonging to several Categories; an Account with multiple Holders.
- **Behavior in the model**:
  - The bridge table sits "in the middle", with one row per valid combination of the two related entities -- it is itself, structurally, a coverage factless fact (section 1.4).
  - Relationships: Dimension A (1) -> Bridge (N) and Dimension B (1) -> Bridge (N). The relationship between the bridge and at least one of the sides often needs to be bidirectional for the filter to propagate correctly -- this is one of the few situations where bidirectional is justified (see modeling-guidelines.md, bidirectional exception for N:N).
  - Beware of double counting: if the fact connects to a dimension through an N:N bridge, a simple `SUM` measure can count the same fact value multiple times (once per combination in the bridge). Use `DISTINCTCOUNT` at the right granularity or weight the measure by participation share when the business requires allocation.
- **DON'T**: resolve N:N by creating a direct bidirectional relationship between the two dimensions without a bridge table -- Tabular does not reliably model native N:N without an intermediate table (the engine creates a hidden bridge automatically in direct N:N relationships, but without control or visibility, making debugging harder).

### Dimension table comparison

| Type | One row represents | Key used in the fact | When to use |
|---|---|---|---|
| Regular | 1 entity | Surrogate or natural key | Default |
| Degenerate | (stays in the fact) | — | Only attribute = transaction ID |
| Role-playing | 1 entity, multiple roles | Same dimension, several FKs or several physical tables | Multiple dates/actors in the same fact |
| SCD Type 1 | 1 entity, current value | Natural key | Attribute history does not matter |
| SCD Type 2 | 1 version of the entity | Surrogate key (in effect on the fact date) | Attribute history matters |
| Junk | 1 combination of flags/codes | Surrogate of the combination | Many small attributes without their own context |
| Bridge | 1 valid combination between two entities | Links two dimensions (or dimension-fact) | N:N relationship |

---

## 3. Parameter / Disconnected Table

A table with no physical relationship to the rest of the model. It exists only to feed a slicer that controls a measure's behavior via DAX (`SELECTEDVALUE`, `SWITCH`), not to filter data through a relationship.

- **Examples**: a "Show by: Value / Quantity / Margin" slicer that switches which measure a matrix displays; a currency conversion parameter; an "Actual vs Target vs Variance %" toggle.
- **When to use**: when the user needs to switch what is displayed, not filter which rows appear.
- **Behavior in the model**:
  - No relationship (`isKey` irrelevant, no corresponding FK column in any other table).
  - Normally created as a calculated table in DAX (`{1;2;3}` or `GENERATESERIES`/`DATATABLE`) or via Power Query with a few fixed values.
  - The measure that consumes the parameter uses `SELECTEDVALUE('Parameter'[Value])` inside a `SWITCH` to decide what to calculate -- the decision logic lives entirely in the measure, not in the relational model.
  - It does not need (and should not have) a partition tied to a real data source if it is small and static -- in that case, prefer `CalculatedPartitionSource` with DAX (see the partitions table in modeling-guidelines.md).
- **DON'T**: create a physical relationship between a parameter table and any other table -- that defeats the purpose (it must stay disconnected, otherwise it starts filtering instead of just switching the display).

---

## 4. Aggregation Table

A pre-aggregated table, at a higher grain than the detailed fact, used by the engine to speed up queries without the user noticing -- through aggregation mapping (`Manage Aggregations`), the query is automatically redirected to the smaller table when the requested aggregation is compatible with its grain.

- **When to use**: very large DirectQuery or Direct Lake models where queries at the detailed grain are slow, but most reports ask for totals at a higher grain (e.g. a transactional fact at order-item level, but 90% of reports look at totals by Day/Product/Store).
- **Behavior in the model**:
  - It stays in **Import** storage mode even when the detailed fact is DirectQuery/Direct Lake -- this mix ("Import aggregation over a DirectQuery fact") is precisely the most common usage pattern.
  - The aggregation columns must correspond 1:1 to columns or valid groupings of the detailed fact, and the aggregation mapping (`Aggregations` in TMDL/TOM) must explicitly declare `Sum`, `GroupBy`, `Count`, etc. per column.
  - It is **hidden** from the end user (`isHidden = true` on the whole table) -- the user never navigates to it directly; the engine decides internally.
  - It needs the same relationships with the shared dimensions (on the columns where the aggregation preserves the dimension's grain) so the engine can redirect queries filtered by those dimensions.
- **DON'T**: expose the aggregation table to the user or treat it as an ordinary "summary fact" -- it is performance infrastructure, not an analysis object. Also do not use an aggregation table as a substitute for correct periodic snapshot modeling (they have different purposes: aggregation is about query performance, snapshot is about business semantics).

---

## Quick summary of TMDL properties by type

| Table type | `isKey` on the fact? | Hidden (`isHidden`)? | Typical relationship | Typical storage mode |
|---|---|---|---|---|
| Transactional fact | Never | No | 1:N coming from dimensions | Import/DirectQuery/Direct Lake |
| Periodic snapshot fact | Never | No | 1:N coming from dimensions + Calendar | Import/DirectQuery |
| Accumulating snapshot fact | Never | No | Multiple date FKs (role-playing) | Import |
| Factless fact | Never | No (unless bridge) | 1:N coming from dimensions | Import |
| Regular dimension | — (key stays in the dimension) | No | 1:N to the fact | Import |
| Degenerate dimension | — (not a table) | — | — | — |
| Role-playing (physical copies) | — | No | Single 1:N per copy | Import (usually calculated) |
| SCD Type 2 | — | No (control flag yes) | 1:N via surrogate key | Import |
| Junk dimension | — | No | 1:N to the fact | Import |
| Bridge table | — | Usually yes (technical) | N:1 to both dimensions, one side bidirectional | Import |
| Parameter/disconnected | — | No (visible in the slicer) | None | Calculated (DAX) |
| Aggregation | — | Yes, always | Same as the detailed fact on the columns it preserves | Import |
