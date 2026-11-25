# Automating the `powerbi-modeling-mcp` MCP

> Goal: reduce manual round-trips and avoidable questions when using the modeling MCP. This guide complements `SKILL.md` — it does not replace the [Tool Selection Priority](../SKILL.md#tool-selection-priority) or the MUST/PREFER/AVOID/DENY rules.

The plugin starts the MCP server with `npx -y @microsoft/powerbi-modeling-mcp`, so the server path does not depend on any editor extension folder.

---

## 1. Batch sequencing (batch build)

`SKILL.md` already says to "build the whole model in one pass, then deploy once" (see [Workflow: Create new Semantic Model](../SKILL.md#workflow-create-new-semantic-model), step 5). This section details the ORDER of calls that minimizes dependency errors.

### Correct creation order (dependencies first)

```
1. database_operations   -> create an empty database (compatibility level 1702+)
2. table_operations      -> create ALL empty tables (no columns yet, if the tool allows)
3. partition_operations  -> create partitions/connection named_expressions (M or Direct Lake)
4. column_operations     -> create ALL columns of ALL tables
5. relationship_operations -> create ALL relationships (both sides' columns must already exist)
6. measure_operations    -> create ALL measures (they can reference any column/table already created)
7. calculation_group_operations / user_hierarchy_operations / perspective_operations -> secondary objects, if requested
8. deploy (or export to PBIP)
```

**Why this order:** relationships fail if the key columns do not exist on both sides; measures fail if they reference columns or tables that have not been created yet. Going "one complete table at a time" (create table A with columns + relationships + measures, then table B...) feels natural but breaks when a relationship or measure in A depends on a column in B that does not exist yet. Going by LAYER (all tables, then all columns, then all relationships, then all measures) eliminates this kind of ordering error, because each layer only depends on earlier layers that are already 100% complete.

### Batching within each layer

- When calling `table_operations` / `column_operations` / `relationship_operations` / `measure_operations`, group multiple objects in the same call whenever the tool accepts a list/array of items. This reduces the number of MCP round-trips.
- If the tool only accepts one object per call, still keep the calls sequential within the same session — without pausing to ask anything between them, except for the triggers in section 6.
- Do not deploy or export between layers. Deploy/export is the LAST step, after ALL layers are finished.

### Planning checklist before starting the batch

Before the first tool call, have a closed list with:
- [ ] Names of all tables and their storage mode (Import/DirectQuery/Direct Lake)
- [ ] For each table: the complete list of columns with `name`, `dataType`, `sourceColumn`
- [ ] All relationships: source table/column, target table/column, cardinality, cross-filter direction
- [ ] All measures: name, target table, DAX expression, `formatString`
- [ ] If Direct Lake: the shared named expression/connection and the entity mapping per table

If any item on this list depends on information that was not provided (source schema, business names), that is where the STOP in section 6 applies — before starting the batch, not in the middle of it.

---

## 2. Idempotency and safe retry

Unlike Deploy to Fabric (which `SKILL.md` already documents as NOT idempotent — see [Workflow: Deploy to Fabric](../SKILL.md#workflow-deploy-to-fabric)), the modeling MCP operates on a live in-memory/session model. Even so, creating the same object twice produces an "already exists" error or a silent duplicate.

### Check-before-create playbook

| Object to create | Check before (List/Get) | Action if it already exists |
|---|---|---|
| Table | List the database's tables via `table_operations` (list/get) | If a table with the same name exists: skip creation and move on to that table's columns |
| Column | List the table's columns via `column_operations` (list/get) | If `name` already exists in the table: compare `dataType`/`sourceColumn` — if equal, skip; if different, treat it as a conflict and report to the user before overwriting |
| Relationship | List relationships via `relationship_operations` (list/get), compare the pair (source table/column, target table/column) | If one already exists between the same pair of columns: skip |
| Measure | List measures via `measure_operations` (list/get) | If `name` already exists in the table: do NOT overwrite automatically — report it as "measure already exists" and ask whether to edit it (editing is an explicit update, not a re-creation) |

**General rule:** before any `create`, run the matching `list`/`get` for the same object type in the relevant scope (table or model). It is one extra call, but it avoids the cost of an "already exists" error that interrupts the whole batch.

### Safe retry

- Transient network/timeout error on the tool call (not a business error from the model): re-running the SAME call is safe **only after a `list`/`get` confirming the object was not partially created**. Never re-run "blindly".
- Validation error (incompatible type, column not found, invalid DAX): this is NOT a retry — it is a correction (see section 5) followed by a new attempt with the corrected payload.
- After any error in the middle of a layer batch (e.g., the 8th of 12 columns failed), do not restart the whole layer — use `list` to identify which of the 12 objects already exist, and continue only with the missing ones.

---

## 3. Automatic environment detection

The agent should infer the environment (live Desktop / Fabric workspace / local PBIP) using the MCP's own tools, without asking when the answer is already available.

### How to infer without asking

1. **Active MCP sessions/connections** — use `connection_operations` (list) to see which databases/models the MCP is already connected to in this session. If there is already an active connection, use it; do not ask "which model do you want to connect to" when only one option is connected.
2. **PBIP folder in the working directory** — a glob/list of the project directory revealing `*.SemanticModel/definition/` indicates a local PBIP. Combine this with item 1: if the MCP is connected to that same path, it is the "live local PBIP via MCP" scenario described in [Saving Changes to a Semantic Model](../SKILL.md#saving-changes-to-a-semantic-model).
3. **Fabric workspace vs Desktop** — the result of `database_operations`/`connection_operations` (get) typically exposes the connection's server/endpoint (e.g., the XMLA endpoint of a Fabric workspace vs. a Desktop local port). Use this information to classify automatically, instead of asking the user "is this in Desktop or Fabric?".
4. **When the inference is ambiguous** — for example, the MCP is not connected to anything and no PBIP folder is visible: only then is it time to ask (see section 6), because the tools give no signal to decide.

### Practical rule

> Only ask about the environment if the `list`/`get`/`connection_operations` tools you already queried do not make the answer implicit. Running one extra read-only query is always preferable to a question to the user.

---

## 4. Automatic post-change validation

The [Validation Checklist](../SKILL.md#validation-checklist) in `SKILL.md` already defines what to validate; the distinction here is WHAT TO RUN WITHOUT ASKING PERMISSION vs WHAT REQUIRES CONFIRMATION.

### Runs automatically, without asking (read-only, no side effects)

- `EVALUATE { [Measure] }` or a simple equivalent for each new/changed measure (via `dax_query_operations`, when connected with Write, per [Validation Checklist](../SKILL.md#validation-checklist) item 3).
- `INFO.MEASURES()` (or the equivalent list/get of `measure_operations`) to confirm the measure was persisted without a syntax error.
- List newly created tables/columns/relationships via `table_operations`/`column_operations`/`relationship_operations` (list/get) to confirm the objects exist with the expected attributes.
- Re-read the PBIP structure (files/folders) when the source is a PBIP, per item 1 of the Validation Checklist.

These checks are read-only and do not change the state of the model or the data — there is no reason to stop and ask for permission.

### Requires human confirmation before running

| Action | Why it requires confirmation |
|---|---|
| Deploy to a Fabric workspace | Not idempotent (see [Workflow: Deploy to Fabric](../SKILL.md#workflow-deploy-to-fabric)); an error produces a duplicate model |
| Refresh (Desktop or Fabric) | Can be a long/expensive operation, and credential failures require manual action by the user in the portal |
| Deleting any object (table, column, relationship, measure) | Destructive action; may break reports or dependent measures already in use |
| Deleting duplicate model(s) before a redeploy | Same reason — destructive, even if it is to "clean up" an earlier error |
| Overwriting an existing object with a definition different from the new one (conflict detected in section 2) | May be intentional (a fix) or accidental (a duplicate name by mistake) |

---

## 5. Auto-correction of common MCP errors

An "error X -> action Y" playbook for trivial, recoverable errors. It applies only to mechanical/syntactic errors — never to business decisions or requirement ambiguity (those go to section 6).

| Symptom | Probable cause | Automatic correction action |
|---|---|---|
| Error creating a relationship: incompatible data type between the source and target columns | The two key columns were created with different `dataType` (e.g., `int64` vs `string`) | Query `column_operations` (get) on both sides, identify the intended correct `dataType` (usually that of the primary key in the dimension) and fix the column with the divergent type via `column_operations` (update). Re-run the relationship creation. |
| "sourceColumn not found" error when creating/editing a column or partition | `sourceColumn` references a name that does not exist in the source (typo, case sensitivity, or a column renamed at the source) | Query the real schema of the source (M query / lakehouse schema already discovered in the discovery step) and compare names character by character, including upper/lower case. Fix `sourceColumn` to the exact name. If the column really does not exist in the source, this is NOT auto-correctable — it becomes a STOP (section 6). |
| DAX syntax error when creating a measure (parenthesis, incorrect table/column reference) | The table/column name referenced in the expression does not exactly match the real name (missing quotes around names with spaces, reference to a hidden or renamed column) | Re-validate the expression against the list of tables/columns already confirmed via discovery (the "Discover Semantic Model Metadata" section of `SKILL.md`); fix names/quotes and re-create the measure. |
| "Already exists" when creating a table/column/relationship/measure | The object was already created in an earlier attempt (partial batch, retry without checking) | Run `list`/`get` for the object; if identical to what was intended, treat it as success and move on; if different, treat it as a conflict (do not overwrite without confirmation, see section 2) |
| Relationship created with the wrong cardinality/cross-filter direction (e.g., many-to-many when it should be one-to-many) | Source/target order reversed in the call, or the key column is not unique in the "one" table | Verify the uniqueness of the candidate "one" side column via discovery; if the column is already proven unique (the dimension's primary key), fix the relationship's direction/cardinality via `relationship_operations` (update) and re-validate. If uniqueness is unclear, do not fix it on your own — report it. |
| Error creating a Direct Lake partition: lakehouse entity/column not mapped | The table/column name in the lakehouse differs from the name used in the model | Re-check against the lakehouse schema obtained in the initial discovery; fix the `EntityPartitionSource` mapping. |

**General auto-correction rule:** only correct automatically when the correct information is already available (via discovery already done, schema already read, or from the error message itself). If the fix would require guessing a value that was not observed anywhere, it is not auto-correction — it is a STOP.

---

## 6. When to STOP and ask even in automated mode

Even in batch/automation, stop and use `ask_user` in these cases (aligned with `SKILL.md`, which already requires `ask_user` for missing requirements when creating a model):

- **Credentials or authentication** — any credential error during refresh or data connection; never attempt a programmatic workaround (this is already an explicit rule in `SKILL.md`, [Workflow: Refresh Semantic Model](../SKILL.md#workflow-refresh-semantic-model)).
- **Business decision** — choice of aggregation (`SUM` vs `AVERAGE`), granularity of a dimension, whether a column should be hidden or visible, business naming — anything without an objectively correct answer from the schema.
- **Requirement ambiguity** — data source not specified, model/workspace name not provided, a column referenced in the user's request but absent from the discovered schema.
- **Destructive actions** — deleting objects, deleting duplicate models, overwriting an existing definition with different content (see the table in section 4).
- **Deploy and refresh** — always ask for confirmation before triggering (deploy is not idempotent; refresh can be expensive or expose a credential error that only the user can resolve).
- **An error that does not fit any row of the section 5 playbook** — if the root cause is not clear from the error plus what has already been discovered about the schema, do not guess; explain the error to the user and ask how to proceed.
- **Conflict with an existing object that has a different definition** — never decide on your own whether to overwrite or keep it.

---

## Quick summary (for reference during the batch)

1. Plan everything before creating any object (checklist in section 1).
2. Create by layer: tables -> partitions/connection -> columns -> relationships -> measures.
3. Before each `create`, run `list`/`get` to check whether it already exists.
4. Deploy and refresh: always an `ask_user` before triggering.
5. After creating, run read-only validations automatically (simple EVALUATE, list of measures/tables).
6. Mechanical errors (incompatible type, wrong sourceColumn, DAX syntax) get one auto-correction attempt using already discovered data; if the cause requires new information, stop and ask.
