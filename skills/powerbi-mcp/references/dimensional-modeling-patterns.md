# Architecture patterns in dimensional modeling

This file covers WHOLE-MODEL decisions: how tables combine with each other, when to use more
than one fact table, how to plan before creating objects. For individual table/column/relationship
rules, see `modeling-guidelines.md`, `table-types.md` and `relationships-advanced.md`.
Theoretical basis: Kimball Group (The Data Warehouse Toolkit), SQLBI, Microsoft
Learn (dimensional modeling in Power BI/Fabric).

---

## 1. Star schema vs galaxy schema (multi-fact)

A model needs more than one fact table when there are distinct business processes
with different granularities, for example "orders" and "shipments", or "sales" and "targets". Forcing
everything into a single fact causes fan-out (row duplication in indirect many-to-many
relationships) and wrong measures.

```
                DIM_DATE
               /          \
   FACT_SALES              FACT_INVENTORY
        \                     /
      DIM_PRODUCT --------- DIM_PRODUCT   (same table, shared)
        \                     /
      DIM_STORE  ----------- DIM_STORE    (same table, shared)
```

This is a **galaxy schema** (or "fact constellation"): several facts, each
with its own grain, linked to shared dimensions. The requirement for it to work without
producing wrong numbers is the **conformed dimension**: the same
DIM_PRODUCT, with the same key and the same granularity, serves both facts.
Do not create a DIM_PRODUCT_SALES and another DIM_PRODUCT_INVENTORY. That breaks
the ability to compare the two facts in the same visual.

**DO**
- Have a single dimension per business entity (product, store, date,
  customer) and connect it to all the facts that need it.
- Ensure the conformed key has the same granularity in both
  facts (e.g. product key at SKU level in both, not SKU in one and
  category in the other).
- Use a single calendar table for all facts with a date.

**DON'T**
- Duplicate the dimension to "simplify" the relationship of one specific fact.
  It prevents comparing facts and doubles the maintenance work.
- Create a fact just to avoid deciding the right granularity of the
  existing fact (see section 3).
- Relate a fact directly to another fact. Facts connect via a
  shared dimension, never fact-to-fact.

**When a galaxy schema is NOT needed:** if the two "processes" actually
share the same grain and the same dimensions (e.g. sales and returns at the
order item level), they normally fit in the same fact with a movement
type column, avoiding multiplying tables unnecessarily.

---

## 2. Composite models (Import + DirectQuery / multiple sources)

A composite model mixes storage modes in the same model: Import tables
alongside DirectQuery tables, or DirectQuery over different sources
among themselves.

**When it is worth it**
- A fact too large for Import (billions of rows) that must stay in
  DirectQuery, while the (small) dimensions stay in Import to give
  filter/slicer performance.
- A need for near real-time data in part of the model (DirectQuery) without
  losing Import performance in the rest.
- Combining data from two source systems that cannot be unified in a
  single query (e.g. on-prem ERP via DirectQuery + spreadsheet via Import).

**Trade-offs**
- An Import table linked to a DirectQuery table automatically creates a "mixed mode"
  calculation group: any measure that crosses the two modes becomes
  DirectQuery at query time, so part of the Import performance benefit is lost.
- Relationships between an Import table and a DirectQuery table are always
  limited by a "limiting relationship". The direction and cardinality
  must be checked carefully (see `relationships-advanced.md`
  for the technical detail of the relationship itself).
- Each additional DirectQuery source multiplies the failure surface
  (timeout, latency, source system availability) and the model comes to
  depend on that backend's real-time performance.
- Security (RLS) in composite models must be validated on each source
  separately. There is no automatic guarantee that the filter propagates
  the same way in both modes.

**DO**
- Reserve DirectQuery only for the truly large or truly
  real-time fact; keep dimensions in Import whenever possible.
- Test performance with production volume before deciding. A mixed mode
  that looks good with few rows may not scale.

**DON'T**
- Mix modes "just because". Each mode boundary is a source
  of complexity and of unexpected behavior in measures.
- Use a composite model as a shortcut to avoid migrating/consolidating data that
  should be in the same source.

---

## 3. Decide the fact grain BEFORE building

The most expensive mistake in dimensional modeling is starting to create tables before
answering: **"what exactly does one row of the fact represent?"**

Fixing the grain after the model is in production, with reports and
measures built on top, is the most expensive rework there is.
It usually requires recreating the fact, the relationships and a good part of the measures.

**Questions to answer before creating the first table:**
1. Is a row an event (a sale, a click, a completed visit) or a
   periodic snapshot (end-of-day balance, inventory at 11:59 pm)?
2. What is the minimum level of detail any report will ask for? (If
   there is any chance of needing the order item, the grain cannot be
   "order"; it has to be "order item".)
3. Do all the proposed dimensions make sense at the SAME grain? (If a
   dimension only exists at a more aggregated level than the chosen grain, it becomes
   a source of fan-out.)
4. Will there be more than one grain in the same business process (e.g. order and
   order item)? If so, they are two facts, not one.

**DO**
- Document the grain in one sentence, next to the table, before creating any
  column (e.g. "1 row = 1 item sold on 1 invoice").
- Choose the most atomic grain the source allows with reasonable effort.
  An atomic grain can be aggregated to any higher level; an aggregated grain cannot be
  disaggregated.
- Validate the grain against at least 2-3 real business questions before
  moving on.

**DON'T**
- Start from "which columns do I have in the source". That produces a
  source-mirror model (see section 6), not a model designed around the grain.
- Mix different grains in the same fact table "because they fit the same
  columns" (e.g. order and order item together, with conditional nulls).

---

## 4. Slowly Changing Dimension (SCD) in Power BI practice

SCD is about how to handle the CHANGE of a dimension attribute over time
(e.g. a customer moved city, a product changed category). Versioning is not
always necessary. The decision depends on which question the business
needs to answer.

| Type | What it does | When to use in BI |
|---|---|---|
| Type 0 | Attribute never changes (e.g. date of birth) | Truly immutable attributes. Requires no handling. |
| Type 1 | Overwrites the old value, no history | Correcting a registration error; attributes where the business always wants to see the CURRENT value applied to all history (e.g. "sales by the product's current category"). Simplest, most common, and the default. |
| Type 2 | Creates a new versioned row with a surrogate key and validity dates (`start_date`/`end_date`, `current_flag`) | When the business needs to reconstruct "how it was at the time" (e.g. a salesperson's territory in the month the sale occurred, so as not to distort historical performance). |

**How type 2 is represented in the Power BI model**
- The dimension gets a surrogate key different from the natural key.
  The same real person/product has N rows, one per version.
  The technical detail of creating this column/key is in `table-types.md`.
- The fact-dimension relationship uses the surrogate key corresponding to the
  version in effect AT THE TIME OF THE FACT EVENT, not the current version. This
  normally requires the surrogate key to arrive already resolved from the ETL/source;
  Power BI does not resolve "which version was in effect" at query time.
- If the requirement is only to show the current attribute (type 1), there is no
  need for a surrogate key or extra rows. Just overwrite.

**DO**
- Ask the stakeholder explicitly: "when this attribute changes,
  do you want to see the history with the old value or with the new one?" before
  deciding the type.
- Apply type 2 only to the attributes that actually need history,
  not to the whole dimension. It is common to have a dimension with some type 1
  attributes and others type 2 (hybrid SCD).
- Prefer resolving SCD type 2 in the data layer (ETL/dataflow) before
  it reaches the semantic model. Power BI has no native mechanism for
  automatic dimension versioning.

**DON'T**
- Apply type 2 by default "just in case". It inflates the dimension, creates a confusing
  granularity and forces every measure to deal with `current_flag`.
- Confuse type 2 with merely keeping an audit field
  (`updated_at`) without a surrogate key. That does not allow reconstructing
  the correct historical state in the relationship with the fact.

---

## 5. Extending existing facts without breaking published reports

Adding a fact/column/measure to a model that is already in production carries
the risk of breaking existing visuals and measures. The goal is an **additive**
change, never a destructive one.

**DO**
- Always add new columns and measures with a new name. Never reuse
  the name of a recently removed object (a report cache may
  still reference the old name with different semantics).
- Test the change on a copy of the model (or a dev workspace) before
  publishing over the production model.
- When adding a new fact table, check that it uses the SAME
  conformed dimensions of the existing model (section 1). Do not create a
  parallel dimension just for the new fact.
- Document the change (what was added, why, date). Model versioning
  here is basically a "change log" when there is no formal deployment
  pipeline tool.
- Use Fabric Deployment Pipelines / environments (dev -> test -> prod) when
  available, instead of editing the production model directly.

**DON'T**
- Rename or remove an existing column/measure/table without first checking
  which reports/pages reference it. Renaming breaks any visual
  or DAX measure that points to the old name.
- Change the data type of an existing column (e.g. text to number) without
  assessing every filter/slicer that depends on the current type.
- Change the granularity of an existing fact to "fit" a new requirement.
  If the grain changes, it is a new fact (or a planned migration),
  not an incremental adjustment.
- Publish directly over the production model without testing. Even an "only additive" change
  can trigger relationship reprocessing and affect measures that depend on the
  filter context of that table.

---

## 6. Anti-pattern: "source-mirror model"

This happens when the semantic model replicates the normalized (3NF) structure of the
transactional system (OLTP) directly in Power BI, instead of remodeling as a star
schema. It is the most common anti-pattern among people coming from relational databases without
dimensional BI training.

**How to recognize it when inspecting an existing model**
- Many small tables (10-20+) connected in long chains of
  relationships (table A -> B -> C -> D) instead of a central dimension
  linked directly to the fact.
- OLTP "junction"/associative tables brought into the model as
  they are, creating many-to-many relationships where a single
  denormalized dimension would suffice.
- Table and column names identical to the source database's technical names
  (`tb_cust_addr`, `fk_prod_id`) instead of business names.
- Extremely complex DAX measures using `RELATED`/`RELATEDTABLE` across
  several hops to "join" information that should be denormalized
  in a single dimension.
- No dedicated calendar table. Dates are scattered in each transactional
  table, each with its own independent relationship.
- Poor performance on simple measures (count, sum) because the engine
  has to cross several relationships to answer a question that
  should be a direct fact-dimension filter.

**Why it is wrong in the Power BI context**
- The VertiPaq engine is optimized for direct one-to-many fact-dimension
  relationships with few hops. Long relationship chains
  degrade performance and make filter behavior hard to
  predict (the filter context has to "cross" several tables).
- Denormalizing (joining related attributes into a single dimension, e.g.
  customer + address + segment in a single DIM_CUSTOMER table) is the very
  goal of the star schema. Normalizing back cancels that gain.
- A business user in Power BI (self-service, natural fields) gets lost in
  20 technical tables; a well-designed dimension with business names is
  navigable without external documentation.

**DO**
- When inheriting a model like this, map which normalized tables
  correspond to ONE business dimension and propose consolidation
  (denormalize into a single table with all the attributes of that entity).
- Ask "which business entity does this table represent" for each
  OLTP table before deciding whether it is a dimension, part of a larger
  dimension, or should not be in the model at all.

**DON'T**
- Import the OLTP schema "as is" just because it is faster in the short
  term. The cost shows up later, in performance and in unreadable
  DAX measures.
- Assume every source table has to become a table in the semantic
  model. Support/associative OLTP tables often should
  be resolved in the ETL and never reach the model.
