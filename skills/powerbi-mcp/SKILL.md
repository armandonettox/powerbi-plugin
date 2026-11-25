---
name: powerbi-mcp
description: >  
  Author and inspect Power BI semantic models, DAX, and report visuals via the powerbi-modeling-mcp MCP: list tables, columns, measures, relationships; create, edit, deploy, refresh, and manage models; optimize DAX; build Import, DirectQuery, and Direct Lake models; configure data sources, permissions, connections; edit report visuals (PBIR/JSON); and prepare for AI/Copilot.
  Load this skill before acting on any semantic model authoring, DAX, report visual, or read-only inspection request: it picks the correct tool and method for the environment and permissions, and pushes as much of the work through the MCP as possible instead of asking the user to do it manually.
  Authoring-scoped: does not answer natural-language or data questions about a model's data.
  Does NOT manage workspaces or manage RLS/OLS role membership.
  Triggers: "create or edit a semantic model", "create or edit a DAX measure", "discover semantic model metadata", "list tables, columns, or measures in a semantic model", "refresh semantic model", "deploy semantic model to Fabric", "prepare semantic model for AI/Copilot", "set semantic model permissions", "edit a Power BI visual", "which visual should I use", "editing PBIP report JSON (page.json/visual.json) directly, even without an explicit Power BI request framing", "connecting to a live Power BI Desktop instance via powerbi-modeling-mcp for any reason (measure/column/table edits, DAX validation, or ad-hoc troubleshooting)".
---

> **Telemetry — MANDATORY.** Every `api.fabric.microsoft.com` call must carry
> `x-ms-fabric-skill: semantic-model-authoring` (`az rest`: `--headers "x-ms-fabric-skill=semantic-model-authoring"`),
> including every LRO poll, `fabric_lro` and retry. Snippets omit it — add it anyway.

> **CRITICAL NOTES**
> 1. To find the workspace details (including its ID) from workspace name: list all workspaces and, then, use JMESPath filtering
> 2. To find the item details (including its ID) from workspace ID, item type, and item name: list all items of that type in that workspace and, then, use JMESPath filtering
> 3. Always consider the [Tool selection priority](#tool-selection-priority) when choosing which tool to use for each operation. Do not default to TMDL edits or `az rest` if MCP is available and connected to the target model.

# Power BI Semantic Model Authoring — CLI Skill

## Workflow Selector

Use this decision tree to route to the correct workflow based on user intent:

| User wants to...                                                                | Workflow                                                                             |
| ------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------ |
| Create a semantic model from scratch                                            | [Create new semantic model](#workflow-create-new-semantic-model)                     |
| Inspect or discover model metadata (tables, columns, measures, relationships)   | [Discover Semantic Model Metadata](#workflow-discover-semantic-model-metadata)      |
| Add/edit semantic model objects (e.g. measures, tables, columns, relationships) | [Modify an Existing Model](#workflow-modify-an-existing-model)                       |
| Write or refactor DAX code                                                      | [Modify an Existing Model](#workflow-modify-an-existing-model)                       |
| Improve DAX query or measure performance                                        | [Optimize DAX Performance](#workflow-optimize-dax-performance)                       |
| Analyze semantic model against best practices                                   | [Analyze Best Practices](#workflow-analyze-best-practices)                           |
| Prepare a semantic model for AI consumption (Copilot / Data Agents)             | [Semantic Model AI Readiness](#workflow-semantic-model-ai-readiness)                 |
| Deploy a model to a Fabric workspace                                            | [Deploy to Fabric](#workflow-deploy-to-fabric)                                       |
| Refresh a semantic model                                                        | [Refresh Semantic Model](#workflow-refresh-semantic-model)                           |
| Configure data sources, parameters, or permissions                              | [Manage Semantic Model in Fabric](#workflow-manage-semantic-model-in-fabric)         |
| Bind a semantic model to a Fabric connection (or unbind)                        | [Bind Semantic Model to a Connection](#connection-binding) |
| Export / Get semantic model definition as PBIP                                  | [Export to PBIP](#workflow-export-to-pbip)           |
| Create/edit a report visual, or decide which visual to use for a question       | Load [report-visuals.md](./references/report-visuals.md) directly — this is not a semantic model workflow |

## Table of Contents

Load these references on demand when a workflow step requires them. Do not load all at once.

| Topic                            | Reference                                                                          | When to load                                                                                |
| -------------------------------- | ---------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------- |
| Modeling Best Practices          | [modeling-guidelines.md](./references/modeling-guidelines.md)                      | Before creating or editing any model                                                        |
| Dimensional Modeling Patterns     | [dimensional-modeling-patterns.md](./references/dimensional-modeling-patterns.md)  | When deciding whole-model architecture: galaxy schema, composite models, grain, SCD, extending a published model |
| Table Types (Fact/Dim/Bridge)     | [table-types.md](./references/table-types.md)                                      | Before modeling a new table — identify its type (fact variant, dimension variant, bridge, parameter, aggregation) |
| Relationships — Advanced          | [relationships-advanced.md](./references/relationships-advanced.md)                | Virtual relationships, many-to-many, role-playing dimensions, filter ambiguity, diagnosing fan traps |
| Measure Organization              | [measure-organization.md](./references/measure-organization.md)                    | Structuring displayFolder, measure tables vs. distributed measures, base/derived naming |
| Calculated Columns Decision Guide  | [calculated-columns-decision-guide.md](./references/calculated-columns-decision-guide.md) | Deciding column vs. measure vs. M vs. calculated table                                |
| Avoid Redundancy                 | [avoid-redundancy.md](./references/avoid-redundancy.md)                            | Before creating ANY new measure/column/table — checklist to avoid duplicating or over-adding |
| MCP Automation Playbook          | [mcp-automation.md](./references/mcp-automation.md)                                | Batch builds, idempotency, environment detection, auto-validation, auto-recovery from common errors |
| DAX Measure Pattern Catalog       | [dax-measure-patterns.md](./references/dax-measure-patterns.md)                    | Business-pattern catalog: time intelligence, ranking, running totals, retention, allocation |
| Report Visuals (PBIR/JSON)        | [report-visuals.md](./references/report-visuals.md)                                | When editing/creating report visuals, choosing which visual to use, or editing PBIR JSON |
| Self-Improvement (skill maintenance) | [self-improvement.md](./references/self-improvement.md)                         | When a real error/correction happens that isn't documented yet, or the user asks to review/improve this skill |
| Common Errors & Prevention        | [common-errors-prevention.md](./references/common-errors-prevention.md)            | Before authoring TMDL/DAX/deploy/refresh/permissions — root-cause catalog to avoid repeating known errors |
| Naming Conventions               | [naming-conventions.md](./references/naming-conventions.md)                        | When naming or renaming tables, columns, measures                                           |
| Direct Lake Modeling             | [direct-lake-guidelines.md](./references/direct-lake-guidelines.md)                | When model connects to OneLake                                                              |
| TMDL Editing                     | [tmdl-guidelines.md](./references/tmdl-guidelines.md)                              | Before generating or editing any TMDL file                                                  |
| PBIP Projects                    | [pbip.md](./references/pbip.md)                                                    | When working with PBIP folders                                                              |
| DAX Language                     | [dax-guidelines.md](./references/dax-guidelines.md)                                | When writing or reviewing any DAX code                                                      |
| Metadata Discovery (DAX INFO functions) | [metadata-discovery.md](./references/metadata-discovery.md)                 | When discovering model metadata via DAX INFO functions (see [Workflow: Discover Semantic Model Metadata](#workflow-discover-semantic-model-metadata)) |
| DAX Performance Decision Guide   | [dax-perf-decision-guide.md](./references/dax-perf-decision-guide.md)              | Start here when optimizing DAX                                                             |
| DAX Performance Pattern Catalog  | [dax-perf-patterns.md](./references/dax-perf-patterns.md)                          | Load on demand after the decision guide identifies candidate patterns                       |
| DAX Review Output Format         | [dax-review-format.md](./references/dax-review-format.md)                          | Before presenting any DAX change to the user (optimization or authoring)                    |
| Semantic Model AI Readiness                | [semantic-model-ai-readiness.md](./references/semantic-model-ai-readiness.md)                          | When preparing a model for Copilot or Data Agents                                           |
| Semantic Model REST API          | [semantic-model-rest-api.md](./references/semantic-model-rest-api.md)              | When using `az rest` for TMDL CRUD, refresh, parameters, permissions, or property retrieval |
| Connection Binding               | [connection-binding.md](./references/connection-binding.md)                        | When binding/unbinding a semantic model to a Fabric data connection (gateway, cloud, VNet, automatic, none) |
| Fabric REST API (workspaces, items, authentication, long-running operations) | [Microsoft Learn: Fabric REST API](https://learn.microsoft.com/en-us/rest/api/fabric/) | When resolving workspace/item IDs, using `az rest`, authenticating with `az login` (wrong audience = 401), polling long-running operations, or building TMDL definition payloads |
| Examples                         | [Examples](#examples)                                                              | Reference end-to-end walkthroughs. |

---

## Tool Selection Priority

Priority order (highest first):

1. **Tier 1 — `powerbi-modeling-mcp` MCP is registered** -> Use MCP for authoring (new or edit) operations against the model from any source: Power BI Desktop, Fabric workspace, or local PBIP folder. MCP is the most reliable and full-featured way to edit semantic models, with immediate effect on the live model and no risk of TMDL desync.

   **Important:** In case of dynamic search tools is available (e.g. `tool_search_tool_regex`) search for an available MCP server matching the pattern `powerbi-modeling-mcp`.

   **This includes BOTH writes AND reads/inspection.**
   - To inspect or verify changes -> use the corresponding MCP operations (List / Get).
   - **Anti-pattern:** opening, `view`-ing, `glob`-ing or otherwise reading TMDL files (`*.tmdl`) while MCP is connected. The MCP-loaded model is the source of truth - the on-disk TMDL is stale. The only exceptions is when the user explicitly asks to work with the TMDL files, or when you only need to confirm what the user already saved to disk (file timestamp, whether an object or measure is present): that checks persistence, not the model content, and does not break this rule.

2. **Tier 2 — MCP not registered + PBIP folder or Fabric workspace** -> Edit TMDL files directly. Load [tmdl-guidelines.md](./references/tmdl-guidelines.md) and [pbip.md](./references/pbip.md). When the source is a Fabric workspace, use `az rest` to round-trip the TMDL (load [semantic-model-rest-api.md](./references/semantic-model-rest-api.md)): `getDefinition` -> edit TMDL locally -> `updateDefinition`.

**Exception — small edit on a closed model:** when Power BI Desktop does NOT have the model open and the change is one or two lines (for example a filter step in a partition's M query), editing the `.tmdl` file by hand and validating it with `connection_operations` `ConnectFolder` on the `.SemanticModel` folder (offline engine: counts tables/measures/relationships, `partition_operations` `Get` shows the loaded M) is accepted and is less invasive than `ExportToTmdlFolder`, which rewrites every table file. Check `Get-Process PBIDesktop` first (a window with that model open means use the live MCP connection instead), show the `git diff` of the line, and do not refresh without asking. **Motivation:** a one-line filter applied and validated this way produces a 3-line diff, instead of re-exporting the whole model and rewriting every table file.

**Fallback — none of the above available (e.g., Power BI Desktop with no PBIP and no MCP)** -> STOP. The agent cannot author the model in this configuration. Instruct the user to either (a) install and register the `powerbi-modeling-mcp` MCP server, or (b) save the PBIX as a PBIP project, then restart the workflow.

> **All workflows below are tool-agnostic.** Workflow steps describe the *intent* (connect, create, edit, save, deploy, refresh). The tool used to perform each step is determined here. Always select the highest-priority tool available for the current environment; do not mix tools when a higher-priority option works. Some workflows OVERRIDE this default priority, always check the workflow's own tool-selection rules before defaulting to Tier 1.

### Connecting to a Semantic Model

A semantic model can live in three locations. Resolve the connection per [Tool Selection Priority](#tool-selection-priority):

- **Power BI Desktop**: Locate the running Power BI Desktop instance and connect to its local model.
- **Fabric workspace**: First, find the workspace and semantic model using the Fabric REST API (see the Fabric REST API row in the topics table): list workspaces to resolve the workspace ID by name, then list items of type `SemanticModel` in that workspace to resolve the model ID by name. Then connect to the model (live) or export its TMDL definition for local editing.
- **PBIP project**: Connect to the `[Name].SemanticModel/definition` folder. Load [pbip.md](./references/pbip.md) to understand the PBIP folder structure - only load the `[Name].SemanticModel/definition` folder that includes the TMDL code.

### Saving Changes to a Semantic Model

How changes are persisted depends on where the model lives and which tool tier (per [Tool Selection Priority](#tool-selection-priority)) is in use:

**Live connection (Tier 1 - MCP against Desktop or Fabric workspace):**

- Changes are applied immediately as each operation executes against the live model. No explicit save step is needed.
- **PBIP project (live via MCP)**: Serialize the model back to the `[Name].SemanticModel/definition` folder at the end of the session. If the PBIP folder does not exist yet, follow [Export to PBIP](#workflow-export-to-pbip) to create the full structure first.

**Local TMDL editing (Tier 2 - direct file edits or `az rest` round-trip):**

- **PBIP project**: Changes are already written to the TMDL files during editing. No additional save step is needed.
- **Fabric workspace**: Changes were made to local TMDL files exported from the service. Re-deploy the model (load [semantic-model-rest-api.md](./references/semantic-model-rest-api.md) for the `updateDefinition` flow) to push changes back to the workspace.

---

## Workflow: Create new Semantic Model

**When this applies:** User asks to create a new semantic model from scratch.

Steps:

1. **Gather requirements** - interview the user until both reach a shared understanding of: purpose of the model, data source connection details and schemas, and key business entities/facts. **If data source information is not available, STOP and use `ask_user`. Do not guess or fabricate.**
2. **Determine storage mode** - data source is Fabric OneLake -> **Direct Lake**; otherwise default to **Import**. Only use **DirectQuery** when the user explicitly asks for it.
3. **Design star schema** - identify fact and dimension tables and relationship keys.
   - If fact table includes date field(s), create a separate date dimension table and link it to the fact with a relationship. If not explicitly requested, use PowerQuery/M partition instead of DAX calculated table.
4. **Load applicable guidelines** - **MANDATORY: load [modeling-guidelines.md](./references/modeling-guidelines.md) before building any object** (including the Tier 1 MCP path below); also load [direct-lake-guidelines.md](./references/direct-lake-guidelines.md) if Direct Lake. Don't build from memory.
5. **Build** - follow [Tool Selection Priority](#tool-selection-priority): **prefer the modeling MCP to build the whole model when one is available; otherwise use the TMDL code-edit path.** Create an empty database (compatibility level 1702+), then for each table follow the execution order from [Modify an Existing Model](#workflow-modify-an-existing-model) (partitions -> columns -> relationships -> measures). Storage-mode specifics:
   - **Import / DirectQuery** - create M parameters for the data source (`Server`, `Database`, ...) and reference them in partition M code; ensure proper `dataType` and `sourceColumn` mapping on columns.
   - **Direct Lake** - create a shared named expression for the Direct Lake connection using the `AzureStorage.DataLake` connector; use `EntityPartitionSource` with `directLake` mode mapped to the lakehouse table columns.

   > **Build the whole model in one pass, then deploy once.** Add every table, column, relationship and measure before deploying - don't deploy a partial model and edit-redeploy. On the MCP path, keep the model in the session end to end.
6. **Deploy or save** - Fabric workspace available -> [Deploy to Fabric](#workflow-deploy-to-fabric); otherwise -> [Export to PBIP](#workflow-export-to-pbip). See [Saving Changes to a Semantic Model](#saving-changes-to-a-semantic-model). Deploy through the same path you built with.
7. **Validate** - run [Validation Checklist](#validation-checklist).

---

## Workflow: Discover Semantic Model Metadata

**When this applies:** User asks to inspect, list, or discover the model's structure - tables, columns, measures, relationships, hierarchies, partitions, roles, or storage internals. Also used internally by other workflows ([Modify](#workflow-modify-an-existing-model), [Analyze Best Practices](#workflow-analyze-best-practices), [AI Readiness](#workflow-semantic-model-ai-readiness)) to inventory the model before editing.

> **Scope:** This workflow covers **metadata** discovery only. To answer natural-language/data questions against the model, use the `FabricIQ` skill instead.

Pick a discovery method (highest priority first):

1. **`powerbi-modeling-mcp` TOM inspection (List / Get)** - the default when `powerbi-modeling-mcp` is registered and connected to the target model **with Write access**. It returns the structured object model directly and stays in sync with pending edits, so it is preferred while authoring.

2. **DAX `INFO` functions** - query the model's `INFO.VIEW.*` / `INFO.*` metadata rowsets. **MANDATORY: before writing or running ANY `INFO`-function DAX, you MUST load [metadata-discovery.md](./references/metadata-discovery.md) first**. Do NOT compose `INFO` queries from memory; load the reference and use its patterns. **Prioritize this method when any of the following is true:**
   - **You lack Write permission** on the model. `powerbi-modeling-mcp` operations require Write access; with Read or Build access, use `INFO` functions.
   - **`powerbi-modeling-mcp` is not registered or not available** in the current environment.
 
   Execute the `INFO`-function DAX through one of these tools (highest priority first):
   - **FabricIQ `ExecuteQuery`** - requires only **Read** permission on the model. Load the `FabricIQ` skill for artifact discovery (`DiscoverArtifacts`) and execution mechanics.
   - **`powerbi-modeling-mcp` `dax_query_operations`** - requires **Write** permission. Use this when the modeling MCP is already connected with Write access.

> **Do NOT use FabricIQ `GetSemanticModelSchema` for authoring metadata discovery** - it is a data-consumption tool that can return stale metadata and miss recent edits. Even when FabricIQ is available, always use the `INFO` functions (via `ExecuteQuery`); they query the live model.

Start narrow: run the scope-estimation and `INFO.VIEW.*` queries first, then project/filter to only the objects relevant to the task (see [metadata-discovery.md](./references/metadata-discovery.md)).

**Before connecting to a model, check the context (sensitive data guard).** `ListLocalInstances` already shows the Power BI Desktop window title (the file name) - that alone is enough to decide. If the file name, the workspace or the paths in the request suggest data from an employer or client (a company folder, health, payroll, customer or personnel data) and the current session context is different (e.g. a personal session on a shared machine), STOP and say so BEFORE connecting: "this looks like <company> data and this session is <personal/other>; do you want to switch context?". Do not connect first and check afterwards.
**Motivation:** when a request for a corporate model arrives in a personal session, connecting and reading the model exposes partition code with company paths and people's names in the wrong conversation before the mismatch is noticed.

**`processId` and `startTime` in the `ListLocalInstances` result belong to the analysis engine (`msmdsrv`), not to the Desktop window (`PBIDesktop`).** To find or close the window use `Get-Process PBIDesktop` (match by window title); to confirm that Desktop was really reopened, check that `processId`, `startTime` and `port` changed in a new `ListLocalInstances`.
**Motivation:** treating the engine PID as the window makes `CloseMainWindow` do nothing; an unchanged `startTime` is also the only sign that the user has not yet reopened the file.

**Before opening a `.pbip` yourself (`Start-Process`), check whether the user already opened it, and wait if they are doing it.** Run `Get-Process PBIDesktop` and read the window titles. A general permission such as "you can open Power BI if you need to" is not a request to open it right now: say you are going to open it and give the user a moment first. If two instances of the same model end up open, do not close either one; tell the user and let them choose. Read the open model only with queries (no Refresh, no save).
**Motivation:** after a general "you can open Power BI if you need to", opening the file with `Start-Process` while the user was already opening it left two `PBIDesktop` and two `msmdsrv` (two ports) with the same model.

**Before asking the user to check a change you made on disk, compare the `StartTime` of the open `PBIDesktop` with the time of your edits.** Run `Get-Process PBIDesktop | Select-Object Id, StartTime, MainWindowTitle` (and `Get-Date`). A window started before the edits shows the old version, and `Start-Process` on a `.pbip` that is already open does not open a new window. If the window is older than the edits, ask the user to close it (`CloseMainWindow` does not close the Desktop, it only raises the "Save changes?" prompt; the user answers "Don't save" when the repo is clean and nothing was changed through the MCP, and "Save" when it was), then reopen and confirm a new `StartTime`. When another report is open, close and open only the window with the model's title and connect the MCP only to its port (`parentWindowTitle` in `ListLocalInstances`).
**Motivation:** a user reported "nothing changed for me" because the open window had started 53 minutes before the edits and was still showing the old layout, and `CloseMainWindow` did not close it; checking `StartTime` would have shown this before the user looked.

**When the MCP is not connected and the task is to reproduce the model's numbers elsewhere (a SQL engine, Excel), read the definitions from the PBIP on disk, read-only, and leave the model untouched.** This is the Tier 2 path: list the `.tmdl` files, read the measures and only the part of the fact table that defines its rows (the M that decides which row each key keeps), not the connection details. Rebuild the logic in the other tool and validate it against numbers the report already showed (totals, minimum, maximum, average) before delivering; a total that differs by only the new rows since the last load is a pass. Say in the delivery that the report was not opened or refreshed.
**Motivation:** when the `powerbi-modeling-mcp` fails to connect and the user requires the report to stay untouched, the fact table's row logic (for example "first row of each key") can still be read from the TMDL and reproduced elsewhere, and the result can be checked against numbers the report already showed.

**Prefer listing over exporting when discovering.** Use List operations (tables, columns, measures, relationships, partition names and source types) first. Only `Get`/export the M code of a partition (`partition_operations` `Get`, `ExportTMDL`) when the user asks for it or the task truly needs the source query - M code carries file paths, server names and hard-coded business data (mappings, names) that are usually not needed to plan a change. When it is needed, fetch one partition, not all of them.

---

## Workflow: Modify an Existing Model

**When this applies:** User asks to add/edit/remove measures, tables, columns, relationships, write DAX code, refactor with UDFs, or edit TMDL directly.

Steps:

1. **Connect & discover** - per [Connecting to a Semantic Model](#connecting-to-a-semantic-model) and [Discover Semantic Model Metadata](#workflow-discover-semantic-model-metadata). List tables, relationships, existing measures, and identify storage mode (it dictates which guidelines apply).
2. **Load applicable guidelines** - [modeling-guidelines.md](./references/modeling-guidelines.md) always; [common-errors-prevention.md](./references/common-errors-prevention.md) always (root-cause catalog to avoid repeating known errors, e.g. table_operations vs partition_operations for M edits, locked column dataType); [direct-lake-guidelines.md](./references/direct-lake-guidelines.md) if Direct Lake; [tmdl-guidelines.md](./references/tmdl-guidelines.md) when editing TMDL directly; [dax-guidelines.md](./references/dax-guidelines.md) for any DAX changes (includes UDF refactoring).
3. **Plan changes** - identify exactly what to add, modify, or remove. Check for naming conflicts and duplicates.
4. **Execute** in correct order:
   - **Adding tables** - partitions -> columns -> relationships -> measures.
   - **Adding relationships** - ensure key columns exist on both sides with matching data types;
   - **Adding measures** - verify referenced columns/tables exist;
5. **Save & validate** - per [Saving Changes to a Semantic Model](#saving-changes-to-a-semantic-model) and [Validation Checklist](#validation-checklist).

---

## Workflow: Optimize DAX Performance

**When this applies:** User asks to improve DAX query performance, diagnose slow measures, or optimize calculations.

> **Hard requirement:** Requires a trace-capable client (MCP preferred))

Steps:

1. **Pull the formula from the live model** - via [Discover Semantic Model Metadata](#workflow-discover-semantic-model-metadata) (MCP List/Get or `INFO` functions). Do not ask the user to paste the DAX if a connected model already has it.
2. **Diagnose** - load [dax-perf-decision-guide.md](./references/dax-perf-decision-guide.md) and follow the framework: tier model for optimization effort, trace diagnostics to identify bottlenecks. Load [dax-perf-patterns.md](./references/dax-perf-patterns.md) only when applying candidate optimization patterns.
3. **Present the change** - per [dax-review-format.md](./references/dax-review-format.md): before/after formula, what changed, expected impact, trade-offs. Wait for approval.
4. **Apply & validate** - per [Workflow: Modify an Existing Model](#workflow-modify-an-existing-model) and the [Validation Checklist](#validation-checklist).

---

## Workflow: Analyze Best Practices

**When this applies:** User asks to review, audit, or analyze a semantic model against best practices.

Steps:

1. **Connect & inventory** - per [Connecting to a Semantic Model](#connecting-to-a-semantic-model) and [Discover Semantic Model Metadata](#workflow-discover-semantic-model-metadata). Capture all tables, columns, relationships, measures, and storage mode.
2. **Load applicable guidelines** - [modeling-guidelines.md](./references/modeling-guidelines.md) always; [direct-lake-guidelines.md](./references/direct-lake-guidelines.md) if Direct Lake; [naming-conventions.md](./references/naming-conventions.md) when assessing naming; [dax-guidelines.md](./references/dax-guidelines.md) when assessing DAX.
3. **Evaluate** - compare the model against the loaded guidelines (star schema, naming, relationship cardinality and cross-filter, explicit measures with `formatString`, column data types and `sourceColumn`, hidden FK columns, calculated-column-vs-measure choices, Direct Lake constraints, etc.).
4. **Present findings** grouped by severity (critical, recommended, optional). For each item state the rule violated and the proposed fix. Wait for user approval.
5. **Apply approved fixes** via [Modify an Existing Model](#workflow-modify-an-existing-model).
6. **Save & validate** - per [Saving Changes to a Semantic Model](#saving-changes-to-a-semantic-model) and [Validation Checklist](#validation-checklist).

---

## Workflow: Semantic Model AI Readiness

**When this applies:** User asks to make a semantic model ready for Microsoft Fabric Copilot, a Power BI Data Agent, or any conversational BI experience. Triggers include "Copilot readiness", "AI readiness", "Prep for AI", "prepare model for Copilot".

Load [semantic-model-ai-readiness.md](./references/semantic-model-ai-readiness.md) before starting.

Steps:

1. **Confirm scope & gather context** - via `ask_user`, confirm consumption mode (reports only / conversational BI / both) and model stability per the *When to Apply* section. Collect business context (process, key metrics, common natural-language questions, vocabulary). Do not invent.
2. **Connect & inventory** - per [Connecting to a Semantic Model](#connecting-to-a-semantic-model). Capture model contents and the source location (PBIP / Fabric workspace / Desktop-only).
3. **Evaluate & route** - walk the [Readiness Checklist](./references/semantic-model-ai-readiness.md#readiness-checklist) in order; for each gap, classify the fix per [Editing Capability](./references/semantic-model-ai-readiness.md#editing-capability) (agent-editable TOM metadata vs AI-specific artifacts the user configures in the Power BI "Prep data for AI" UI).
4. **Present findings** grouped by severity, each tagged with routing (agent-applicable vs user-action-required). Wait for approval.
5. **Apply approved changes** - apply TOM metadata fixes via [Modify an Existing Model](#workflow-modify-an-existing-model); for AI instructions, AI Data Schema, and Verified Answers, instruct the user to configure them in the Power BI "Prep data for AI" UI and, only if the user agrees, offer suggestions per the readiness reference; Desktop-only PBIX -> instruct user.
6. **Save, validate, recommend live testing** - per [Saving Changes to a Semantic Model](#saving-changes-to-a-semantic-model) and [Validation Checklist](#validation-checklist); advise the user to test representative natural-language prompts in Copilot or the Data Agent and iterate.

---

## Workflow: Export to PBIP

**When this applies:** User asks to export or save a semantic model to a PBIP project folder, or there is no Fabric workspace available to deploy to (e.g., after building a model in-memory).

> **Key fact:** Exporting a model only produces the TMDL definition files. It does NOT create the surrounding PBIP folder structure (Report folder, `definition.pbism`, `definition.pbir`, `.pbip` entry point). The agent must scaffold these before exporting, otherwise the result cannot be opened in Power BI Desktop.

Load [pbip.md](./references/pbip.md) before starting and follow the PBIP folder structure defined there.

Steps:

1. **Determine target** - via `ask_user`, get the target folder path and the semantic model name. If only a folder is provided, use the model's database name as the semantic model folder name.
2. **Scaffold the PBIP structure** - per [pbip.md](./references/pbip.md), ensure `<Name>.SemanticModel/` (with `definition/` and `definition.pbism`), `<Name>.Report/` (with `definition/` and `definition.pbir` using a `byPath` reference), and `<Name>.pbip` exist. Create any missing piece.
3. **Export TMDL** into `<Name>.SemanticModel/definition/`, per [Tool Selection Priority](#tool-selection-priority):
   - **Tier 1 (MCP)** - use the MCP export/save operation against the live model.
   - **Tier 2 (Fabric workspace, no MCP)** - call `getDefinition` (load [semantic-model-rest-api.md](./references/semantic-model-rest-api.md)) and write the returned parts.
   - **Local TMDL files already on disk** - copy or move them into the `definition/` folder.
4. **Validate** - confirm the `definition/` folder contains at minimum `model.tmdl` and table `.tmdl` files; confirm `definition.pbism`, `<Name>.Report/definition.pbir` (with correct `byPath` to `../<Name>.SemanticModel`), and `<Name>.pbip` exist and reference each other correctly.

---

## Workflow: Deploy to Fabric

**When this applies:** User asks to deploy or publish a semantic model to a Fabric workspace.

> **Hard rule — this workflow OVERRIDES the default [Tool Selection Priority](#tool-selection-priority).** Do not default to MCP just because it is available. The deployment path is determined by the **source of the model**, not by which tools are connected. If the source is PBIP/TMDL files on disk, you **MUST** use the Fabric REST API even when an MCP session is active.

Decision tree (pick exactly one — top-down, first match wins):

1. **Are there PBIP / TMDL files on disk that need to be deployed?**
   -> **YES — use Fabric REST API.** Call `az rest` with `createItemWithDefinition` (new model) or `updateDefinition` (existing model). Load [semantic-model-rest-api.md](./references/semantic-model-rest-api.md).
   - Rationale: deploying TMDL files directly via the Fabric API is more reliable, faster, and avoids unnecessarily loading the model into MCP only to push it back out.
   - **Do NOT** open the PBIP in MCP first and then deploy via MCP. That is an explicit anti-pattern for this workflow.
2. **Is the model already loaded in a live MCP session** (e.g., just built in-memory, or currently being edited via MCP) **with no PBIP/TMDL files involved?**
   -> Use MCP tool to deploy with the target workspace and semantic model name.
3. **Is the model live in Power BI Desktop with no PBIP saved?**
   -> Use MCP Deploy if MCP is connected to Desktop. If MCP is not available, instruct the user to save as PBIP first, then restart this workflow at step 1.

Verify deployment succeeded by listing workspace items of type `SemanticModel`.

> **Deploy exactly once; the deploy is NOT idempotent.** A retried deploy creates a *second* model with the same name, after which the deploy fails with `There are multiple datasets named '<name>'`. If you hit that error, do NOT retry blindly: list the workspace's semantic models, **delete every duplicate with that name**, then deploy once from the clean state. If deploying a model that may already exist, delete the existing same-named model(s) *before* the single deploy.

---

## Workflow: Refresh Semantic Model

**When this applies:** User asks to refresh data in a semantic model.

Refresh is only possible when working against a live model in Desktop or Fabric Service. If working with local TMDL files, deploy the model first.

Trigger a refresh per [Tool Selection Priority](#tool-selection-priority):

- **Power BI Desktop**: Tier 1 (MCP) only — use the MCP Refresh operation.
- **Fabric Service**: Tier 1 (MCP Refresh operation) or fallback to the Power BI Enhanced Refresh API (load [semantic-model-rest-api.md](./references/semantic-model-rest-api.md)).

> **After editing a source file (CSV/Excel/etc.) behind an M partition, prefer `model_operations` `Refresh`/`Full` over a single-table `table_operations` `Refresh`.** A table-scoped refresh can report success without actually re-reading the changed source file, leaving stale data in place. If a DAX validation query still shows old values right after a table refresh, retry with a full model refresh before concluding the data is correct (or incorrect).

If the refresh fails with a credential error, **stop immediately** and instruct the user to configure the data source connections manually in Power BI Service. Do not attempt to retry or work around credential errors programmatically.

### Refresh, performance and standing rules

**Motivation:** long optimization sessions exposed gaps: refreshes that reported success without loading anything, a Desktop left in a zombie state after a Power Query error, measures that were correct but froze a visual, and two default rules (ask before editing Report JSON, ask before refreshing) that must be applied at the start, not discovered halfway.

1. **Before editing Report JSON or calling Refresh, ask.** Ask, and have Desktop closed, before editing `visual.json`/`page.json` with the model open (the user closes with "Don't save" when the model is already saved, then reopens the `.pbip` afterwards). Do not call Refresh on your own: prepare the change and ask "may I refresh?". An explicit authorization covers that one edit or refresh, not the next ones: ask again.
2. **To force a real reload and to time it, use `partition_operations` Refresh with `refreshType: Full`.** A single-table `table_operations` Refresh can answer `success` in seconds without reading the source. Always confirm with `INFO.PARTITIONS()` (`RefreshedTime`, shown in UTC) that the partition really refreshed.
3. **A refresh longer than ~2 minutes moves to the background.** Do not query or edit the model while it runs (the call queues behind the lock) and do not poll the model; wait for the notification. If the user asks "how is it going", check the CPU of `msmdsrv` and `Microsoft.Mashup.Container*` with `Get-Process` over 10 to 15 s (no model query): CPU growing = loading data; CPU at 0 = stuck (a Power BI window waiting for the user, or a hung Mashup session). **Motivation:** a refresh once waited for more than 1 hour with CPU at 0 and nobody noticed until the user asked.
4. **When source columns are removed in M, delete the same columns from the model before refreshing** (`column_operations` Delete, `shouldCascadeDelete: false` so a missed dependency becomes an error). Otherwise the commit fails with "column X does not exist in the rowset". Changing a column type from text to number can fail at commit if the current text has values like `.35`: let M convert and refresh first, then change the type. A newly created calculated column cannot be queried until `partition_operations` Refresh with `refreshType: Calculate` runs on its table (error "needs to be recalculated or refreshed"); Calculate does not read the source again. **Motivation:** creating several calculated columns in one session hit this each time.
5. **If Desktop shows `Could not find a PackageSession for the given sessionID` during an MCP refresh:** stop retrying, stop the pending MCP tasks, have the user save and close Desktop, check leftover processes (`PBIDesktop`, `msmdsrv`, `Microsoft.Mashup.Container.NetFX45`), end them only after the user confirms, reopen the `.pbip`, run `ListLocalInstances` again (the port changes on every open) and reconnect. If the user asks to keep Desktop open, try at most once and say it is stuck: the engine stays locked (even `EVALUATE ROW("ok", 1)` waits more than 2 minutes, and `Get-Process` shows 0 CPU in `msmdsrv`, `PBIDesktop` and `Microsoft.Mashup.Container*`), so more attempts only queue behind the lock. **Motivation:** insisting on keeping Desktop open after this error once cost about 40 minutes before the processes were ended and the `.pbip` reopened.
5a. **When a new column replaces another:** read the old column with `column_operations` `Get` and copy `dataCategory` (for example `WebUrl`), `summarizeBy`, `formatString` and `isHidden` into the new one; a new link column without `dataCategory: WebUrl` shows as plain text in the table visual.
6. **After changing a measure used in a high-cardinality visual, compare values AND time the same query before and after.** A correct measure can still freeze a table (an item x document grid took >100 s with ~70 microseconds per cell). First measure the floor with a trivial measure; if the floor is fast, the cost is the measure, and the fix is a simple `SUM` over pre-computed columns plus an active relationship.
7. **To run large validation grids without pasting queries into the MCP,** use ADOMD from PowerShell (`Microsoft.AnalysisServices.AdomdClient.dll`, found in the on-premises data gateway folder) against `localhost:<port>` from `ListLocalInstances`, with the queries in a file and an automatic diff before/after.
8. **Removing tables, columns, relationships and measures:** go in this order: visuals and measures that read the object, then relationships, then columns, then tables. Always `shouldCascadeDelete: false` so a missed dependency becomes an error; cascade delete and a batch of many tables (8, with the biggest one) can be blocked by the Claude Code classifier even after `/permissions`, while batches of 1 to 6 passed. A table with millions of rows takes more than 120 s and moves to the background: do not query the model until the completion notice. Each tool (`measure_operations`, `column_operations`, `relationship_operations`, `table_operations`) asks for its own permission. The auto date tables (`LocalDateTable_*`, `DateTableTemplate_*`) cannot be removed through the MCP: the column keeps a Variation and the commit fails; use the Desktop option "Auto date/time". **Motivation:** a migration that removed 16 tables had 3 attempts blocked or failed before the order and batch size were right.
9. **Diagnostic DAX that misleads:** `LOOKUPVALUE` returns the alternate result also when several rows match with different values, so it is not a "does not exist" test; `TRIM` collapses inner double spaces, so compare against a normalized column (`UPPER(TRIM(x))`) on the dimension side too; use `GROUPBY` with `CURRENTGROUP()` to aggregate per group, because `SUMMARIZE` plus `COUNTROWS(table)` repeats the grand total; a control column that comes out at 100% or 0% is usually a query error. Always check that the classes add up to the known total before telling the user. `SEARCH(txt, col, 1, 0)` returns 0 (not BLANK) when not found, so `ISNUMBER(SEARCH(...))` is always TRUE: test `SEARCH(...) > 0`. To try a new calculated column or classification rule without touching the model, declare it in the query with `DEFINE COLUMN Table[col] = ...` and use the report's own measures with it. **Motivation:** three wrong conclusions were once given to the user in a single session, and a `SEARCH` test classified every row as the same type.
10. **Results with thousands of rows** are saved by the MCP in a `tool-results` JSON file (list of `{type, text}`, the text is a CSV whose first line is glued to `{"success":true}[Resource ...]`). Parse with Python (`json.load`, `csv.reader`, drop the first row) instead of reading it. With `resultMode: "Inline"` and `maxRows` high (up to 100000) the over-limit result is saved as one JSON object, and the rows are in `json.load(f)["data"]["rows"]` (a list of dicts keyed like `[col]`), so no CSV step is needed; check `data.isTruncated` is false. For keys missing from a lookup dimension, add a fixed row (for example `NOT_REGISTERED`) and a hidden key column on the fact (`COALESCE(LOOKUPVALUE(...), "NOT_REGISTERED")`), so the slicer can select "not informed".
11. **A column condition inside `CALCULATE` replaces the report filter on that column; use `KEEPFILTERS`.** `Status = "Done"` inside 7 measures ignored the report's Status filter, and `code <> ""` ignored the Code filter; `ALL(table)` also does not block a filter that arrives through a relationship (use `REMOVEFILTERS()` on the card that must not change). To find every affected measure: `FILTER(INFO.MEASURES(), SEARCH("column", [Expression], 1, 0) > 0)`. `measure_operations` Update with only `expression` preserves description, format and folder (confirm with Get on the first case). **Motivation:** the user selected a status and two measures stayed high; only a DAX test per filter showed why.
12. **Validate an edited or renamed PBIP on disk without Desktop, and know whether Desktop was reopened.** `connection_operations ConnectFolder` on the `.SemanticModel` folder loads the TMDL in the offline engine: it lists tables, measures and relationships and shows each measure's `state` (`dax_query_operations` does not work offline). Always test on a copy before a bulk change. After a "saved", `ListLocalInstances` with the same `processId` and `startTime` for the engine is the old instance, and Ctrl+S with no change does not rewrite the files. Close and reopen through PowerShell (`Stop-Process` on the right window, check that `PBIDesktop` and `msmdsrv` are gone, `Start-Process` on the `.pbip`) only when everything is committed. **Motivation:** a rename of 26 measures, 3 tables and 16 columns was validated in the engine before touching the real project, and the key totals matched the ones from before on the new instance.
13. **Desktop reopen, interrupted call and new calculated table.** After closing and reopening Desktop the MCP loses the connection and the port changes: run `ListLocalInstances` and `Connect` again before any query (errors "connection lost" or "No connectionName provided"). If an MCP call is interrupted or refused by the user, check whether the object was created before repeating (a refused `table_operations Create` had already created the table and the repeat answered "already exists"): `List` or `Get` first. `named_expression_operations` Update answers with no output; confirm with `Get`. A new calculated table, or one with a changed expression, stays "needs to be recalculated" and a query that reads its rows fails, but `ISFILTERED` does not read rows and works. `partition_operations RefreshWithXMLA` with `refreshType: Calculate` on that table only does not read the source and takes seconds (10 thousand to 1 million rows), but it is a refresh: ask "may I calculate only this table?". **Motivation:** the connection dropped three times in one session because of Desktop reopens, a table was created even though the call showed as refused, and a table only answered after the authorized Calculate.
14. **A date column that the Service reads differently, a `dataType` that reverts by itself, and replacing a column that has a relationship.** Declaring a date column with `column_operations` Update `dataType: DateTime` is not a durable fix: Desktop rewrote `string` the same day and again a few minutes after saving, with nobody asking. When the M query already returns `type date`, bring the date from the query itself in a new column (final step `Table.AddColumn(..., "dt_x_date", each [dt_x], type nullable date)` plus `column_operations` Create with `dataType: DateTime`) instead of a calculated column that reads text with `DATE(YEAR(x), MONTH(x), DAY(x))`. To replace a column that is a relationship endpoint: (1) list what depends on it with `FILTER(INFO.DEPENDENCIES(), [REFERENCED_OBJECT] = "column")` (the relationship shows as `ACTIVE_RELATIONSHIP`) and search for the column in the report JSON; (2) create the new column; (3) delete and recreate the relationship (there is no column Update on a relationship); (4) repoint measures and calculated columns with `expression` only, confirming with `Get`; (5) `column_operations` Delete on the old one with `shouldCascadeDelete: false` and repeat the dependency query, which must come back empty. Creating a date column in Desktop makes it generate a hidden automatic table `LocalDateTable_...` with its own relationship and two new `.tmdl` files (the MCP does not remove it; use the file's "Auto date/time" option). After the user closes and reopens, check what remained with `Get` before calling it solved, and only close the case after comparing the Service with Desktop. **Motivation:** the Service once showed far more rows than Desktop because a date column was text again, 14 days after a fix reported as done; a date typed in the M query plus the relationship reconnected took text out of the path.
15. **All visuals fail with "relationship ... depends on a column that is not in a valid state": look at the "one" side table before touching the relationship.** When the "one" side table is calculated (for example `SUMMARIZE`) and a duplicate key value arrives, the column goes to `EvaluationError` and the whole relationship drops, so any visual that goes through it fails. Read-only diagnosis: `column_operations` Get on both ends (`state`), `INFO.PARTITIONS()` of the "one" side table with `QueryDefinition`, `State` and `ErrorMessage` (the message names the duplicate value), and a query that counts groups per key in the source fact. Fix the table expression with `partition_operations` Update (validate first as an `EVALUATE` with the same `VAR`s), ask for authorization and run `RefreshWithXMLA` `Calculate` only on it, then confirm with `Get` (`Ready`) and `CROSSFILTER` (every key passing). A duplicate test with `CALCULATE(COUNTROWS(variable))` does not filter: compare `COUNTROWS` with `DISTINCTCOUNT` of the key. With two `.pbip` files open, `Get-Process PBIDesktop` shows the titles and `ListLocalInstances` the `parentWindowTitle`: connect only to the requested model's port and do not touch the other. **Motivation:** a record that arrived without one attribute duplicated a key in a calculated dimension and took down every page; the cause only appeared by reading the partition's `ErrorMessage`.
16. **Two Desktop instances open, deleting many columns, and renaming tables.** (a) With more than one Desktop open, `ListLocalInstances` shows one port per window and MCP operations without `connectionName` use the **last** connection: pass `connectionName` (for example `PBIDesktop-<report>-<port>`) in every call and do not touch the other window. (b) `column_operations` Delete returns a warning per column (about 1,400 characters each); a batch of 50 columns goes over 70 thousand characters and the output is saved to a file without showing success or error. Delete in batches of up to ~25 and confirm through the model state (`INFO.VIEW.COLUMNS()` with the remaining count), without reading the file; with `shouldCascadeDelete: false` a forgotten dependency becomes an error. (c) Renaming tables in a PBIP makes Desktop lose their cache and recalculate the calculated ones: if the fact's date column is text in the loaded model, `MIN`/`MAX` come out in alphabetical order and `CALENDAR` fails (`INFO.PARTITIONS()` shows `State = 6`). Check the types first (`INFO.VIEW.COLUMNS()`) and type the date in the M query. (d) A new calculated column only gets values after `RefreshWithXMLA` Calculate on its table (ask for authorization); without reading the source it takes seconds.
    **Motivation:** deleting 103 columns once answered with only a huge file, the MCP kept pointing at the last connection with two Desktops open, and a table rename took down the calendar through text dates.
17. **Field parameter created by the MCP and used in a matrix written in `visual.json`.** (a) `table_operations Create` of a calculated table does not accept `columns` (error "Columns cannot be specified for calculated tables"): create it with only `daxExpression` (tuples `(group, name, NAMEOF('_Measures'[measure]), order)`), rename `Value1..N` with `column_operations Rename` and adjust with `Update`: hidden fields column with `extendedProperties` `ParameterMetadata` = `{"version":3,"kind":2}`, `sortByColumn` on the order and `groupByColumns` of the display column pointing to the fields column. An extra `group` column plus a single-select slicer allows options like Only inflows / Only outflows / Both (the same field can repeat in different groups). Changing the table expression returns it to the "needs recalculation" state: `RefreshWithXMLA` `Calculate` only on it, with authorization. (b) In the visual's `Values` role, besides `projections` (display column, `active: true`) the `fieldParameters` block is required (`parameterExpr` with the same column, `index: 0`, `length: 1`); without it Power BI treats it as a regular column and shows "Can't determine relationships between the fields". (c) Edit the report JSON with Desktop open only with the user's explicit authorization for that edit; they must close with "Don't save" (the model already saved) and reopen, otherwise saving overwrites the JSON. The project's `visual.json` files may use CRLF: rewriting with `json.dumps(indent=2, ensure_ascii=False)` and replacing `\n` with `\r\n` reproduces the file byte for byte (test first).
    **Motivation:** the first version of a page filter failed with the relationship error because only `projections` was written; the `fieldParameters` block fixed it.

---

## Workflow: Manage Semantic Model in Fabric

**When this applies:** User asks to configure data sources, update parameters, or manage permissions for a semantic model in Fabric Service.

> **Hard rule — this workflow OVERRIDES the default [Tool Selection Priority](#tool-selection-priority).** Do not default to MCP (Tier 1) prefer using `az rest` and REST APIs.

### Data Sources & Parameters

Get/update data sources and parameters via Power BI REST API. Load [semantic-model-rest-api.md](./references/semantic-model-rest-api.md#data-sources--parameters-power-bi-datasets-api).

### Permissions

List/grant/update dataset user permissions via Power BI REST API. Load [semantic-model-rest-api.md](./references/semantic-model-rest-api.md#permissions-power-bi-datasets-api).

### Connection Binding

Load [connection-binding.md](./references/connection-binding.md) and follow it. The reference covers prerequisites, the `bindConnection` endpoint, the discover -> match -> bind -> validate steps, all `connectivityType` values, the unbind pattern, and troubleshooting.

Key rules (full details in the reference):

- Use the Fabric **Bind Semantic Model Connection** REST API (supersedes the legacy Power BI `BindToGateway`).
- **One bind request per data source reference** - the API does not support bulk binding.
- Discover the model's data source references via `List Item Connections`, then match `connectionDetails` against `List Connections` to find the target `id`. Create a connection first if no match exists.
- Validate by re-listing item connections and triggering a refresh.

---

## Validation Checklist

Run after any model creation or modification:

**Always (works with PBIP, Desktop, and Fabric Service):**

1. **Check the PBIP structure** - if the model is sourced from a PBIP folder, ensure the folder structure and files are correct (see [pbip.md](./references/pbip.md)).
2. **Verify against modeling guidelines** - re-check every change against [modeling-guidelines.md](./references/modeling-guidelines.md) (and [direct-lake-guidelines.md](./references/direct-lake-guidelines.md) for Direct Lake models).

**Only when connected to an Analysis Services database (Power BI Desktop or Fabric Service):**

3. **Test new measures** - for each new measure, run a simple DAX query to validate it returns expected results (e.g., `EVALUATE { [Measure Name] }`). Skip this step when working with local TMDL/PBIP files only.
4. **Test table refresh** - when new tables were created, trigger a refresh to verify that partitions, data source expressions, and column mappings are correct. A failed refresh typically indicates mismatched `sourceColumn` names, invalid M expressions, or incorrect Direct Lake entity references. Skip this step when working with local TMDL/PBIP files only.

If any check fails, fix the issue and re-run validation.

---

## Must/Prefer/Avoid

### MUST

- **Understand the data source schema before starting** - analyze source tables, columns, and data types before designing or modifying the model.
- **Follow modeling guidelines** - load [modeling-guidelines.md](./references/modeling-guidelines.md) before creating or editing any model; apply star schema design, naming conventions, and column/measure rules
- **Follow [Tool Selection Priority](#tool-selection-priority)** - always pick the highest-priority tool tier available for the current environment; do not mix tiers when a higher-priority option works

### PREFER

- **Star schema over snowflake or flat tables** - denormalized dimensions with single-column relationship keys
- **Consistency with existing model patterns** - when editing an existing model, match its naming conventions and structure rather than imposing new ones
- **TMDL format over TMSL** - text-based, diff-friendly, preferred for Fabric
- **Validate after changes** - use [Workflow: Discover Semantic Model Metadata](#workflow-discover-semantic-model-metadata) to confirm objects landed.

### AVOID

- **Hardcoded workspace/item IDs** - resolve dynamically via API
- **Reading TMDL files when MCP is connected** - `view`/`glob` on `*.tmdl` while a Tier 1 MCP session is live is an anti-pattern (see [Tool Selection Priority](#tool-selection-priority)).
- **Hand-authoring TMDL files when MCP is registered** - using `create`/`edit`/file-write tools to scaffold `model.tmdl`, `database.tmdl`, `relationships.tmdl`, or `tables/*.tmdl` is a Tier 1 anti-pattern, including for brand-new models. Build and export via MCP tools.

### DENY

- **Manage RLS/OLS role membership** - do not propose REST calls, `az rest` URLs, MCP operations, or TMDL changes to add/remove users or groups from a security role. Refuse the request as out-of-scope here and redirect the user to the Power BI portal.

---

## Examples

> **Scope note** — examples use `az rest` for discovery to resolve ID's and discover Fabric metadata (listing workspaces and items through the Fabric REST API). Authoring of the semantic model definition is routed through [Tool Selection Priority](#tool-selection-priority): Tier 1 MCP `powerbi-modeling-mcp` when available, Tier 2 TMDL editing via `getDefinition` / `updateDefinition` otherwise.

### Example 1: Modify an Existing Semantic Model

**Prompt**: "Create base measures for all aggregable columns in the semantic model **Sales** in workspace **Marketing**."

**Agent response** - follows [Workflow: Modify an Existing Model](#workflow-modify-an-existing-model).

1. **Discover IDs** via `az rest`.
2. **Connect to the model** per [Connecting to a Semantic Model](#connecting-to-a-semantic-model) and [Tool Selection Priority](#tool-selection-priority). With `powerbi-modeling-mcp` registered, connect MCP directly to the Fabric workspace model (Tier 1). Otherwise fall back to Tier 2 (`getDefinition` -> edit TMDL locally).
3. **Inspect & plan** - list tables and columns via the active tool tier; identify aggregable columns (numeric, not foreign keys, not hidden surrogate IDs) and decide on `SUM` / `AVERAGE` / `MIN` / `MAX` per column following [modeling-guidelines.md](./references/modeling-guidelines.md) and [naming-conventions.md](./references/naming-conventions.md). Load [dax-guidelines.md](./references/dax-guidelines.md) before writing DAX.
4. **Add measures** per [Workflow: Modify an Existing Model](#workflow-modify-an-existing-model).
   - **Tier 1 (MCP)**: call tool create for each new measure with `expression`, `formatString`, and target table. Do not hand-author TMDL.
   - **Tier 2 (no MCP)**: edit the table's `.tmdl` file directly and round-trip via `updateDefinition` REST API.
5. **Save & validate** per [Saving Changes to a Semantic Model](#saving-changes-to-a-semantic-model).

---

### Example 2: Create a New Semantic Model from a Fabric Lakehouse

**Prompt**: "Create a new Power BI semantic model in workspace **Marketing**, using the **SalesLakehouse** in the same workspace as the data source."

**Agent response** - follows [Workflow: Create new Semantic Model](#workflow-create-new-semantic-model).

1. **Discover workspace + lakehouse IDs** via `az rest`.
2. **Discover lakehouse schema** - list tables and columns via the Lakehouse OneLake APIs or the SQL Endpoint of the lakehouse. Capture table names, column names, and data types - these drive semantic model table, column definitions and partition metadata.
3. **Select tool tier** per [Tool Selection Priority](#tool-selection-priority): prefer Tier 1 (`powerbi-modeling-mcp`) for the full build. Tier 2 (PBIP/TMDL scaffolding then deploy) only if MCP is not registered.
4. **Build the model** following [Workflow: Create new Semantic Model](#workflow-create-new-semantic-model) - data source is OneLake so the storage mode is **Direct Lake** (load [direct-lake-guidelines.md](./references/direct-lake-guidelines.md) and [modeling-guidelines.md](./references/modeling-guidelines.md)). Design a star schema from the lakehouse tables, then:
   - Create the empty database.
   - Create one shared named expression for the lakehouse connection.
   - For each table: add `EntityPartitionSource` (mode `directLake`) -> columns mapped to lakehouse columns -> relationships -> measures.
5. **Deploy** per [Workflow: Deploy to Fabric](#workflow-deploy-to-fabric):
6. **Validate** per the [Validation Checklist](#validation-checklist) - confirm the model appears in the workspace and trigger an initial refresh to verify Direct Lake column mappings resolve.

---

### Example 3: Bind a Semantic Model to a Fabric Connection

**Prompt**: "Bind semantic model **Sales** in workspace **Marketing** to the **sql-prod** connection."

**Agent response** - follows [Workflow: Manage Semantic Model in Fabric § Connection Binding](#connection-binding). **No MCP** - this workflow overrides [Tool Selection Priority](#tool-selection-priority) and is REST-only.

1. **Discover workspace + model IDs** via `az rest`.
2. **Discover the target connection** in Fabric by matching the server name:

   ```bash
   SERVER="sql-prod"
   CONN_ID=$(az rest --method get --resource "https://api.fabric.microsoft.com" \
     --url "https://api.fabric.microsoft.com/v1/connections" \
     --query "value[?connectionDetails.path | contains(@, '$SERVER')] | [0].id" -o tsv)
   ```

   If no connection matches, **stop** and instruct the user to create one first per [connection-binding.md](./references/connection-binding.md).
3. **Execute the bind** per [Workflow: Manage Semantic Model in Fabric § Connection Binding](#connection-binding) - load [connection-binding.md](./references/connection-binding.md) and follow the discover -> match -> bind -> validate flow:
   - List the model's data source references (`List Item Connections`).
   - For each reference whose `connectionDetails` matches `$CONN_ID`, call the Fabric `bindConnection` endpoint **one request per data source reference** (no bulk binding).
4. **Validate** - re-list item connections to confirm the binding, prompt the user to trigger a refresh per [Workflow: Refresh Semantic Model](#workflow-refresh-semantic-model). Credential errors -> stop and direct the user to the Service portal (per TROUBLESHOOTING).

---

## TROUBLESHOOTING

| Symptom                              | Fix                                                                                                                   |
| ------------------------------------ | --------------------------------------------------------------------------------------------------------------------- |
| MCP connection failure               | Fall back to TMDL editing (see Tool Selection Priority). Inform the user about the fallback.                          |
| `ListLocalInstances` returns 0 instances (Desktop closed) and the user wants numbers from the report, or said not to touch it | Do not open the `.pbip` yourself and do not connect. Read the rules (measures, filters, the M that decides each row) from the PBIP on disk, rebuild them in the other tool (SQL engine, Excel) and validate against a known total; say in the delivery that the report was not opened or refreshed (see "When the MCP is not connected and the task is to reproduce the model's numbers elsewhere" above). |
| MCP `CONNECTION_CLOSED` after a VS Code update | The extension folder name changed (e.g. 0.4.0 to 1.0.0): check that the exe path in the MCP block still exists (this plugin starts the server with `npx`, so the path does not depend on the extension folder). Version 1.0.0 also needs the EULA accepted by the user (`--accept-eula` in args) and no longer has `--skipconfirmation`. |
| TMDL validation errors               | Read error details, fix syntax, re-validate. Load [tmdl-guidelines.md](./references/tmdl-guidelines.md).              |
| `403 Forbidden` / `identity None`    | User needs Contributor+ role - stop immediately. Do not retry.                                                        |
| `401 Unauthorized`                   | Correct the `--resource` audience once (see [semantic-model-rest-api.md](./references/semantic-model-rest-api.md)). If it persists after the audience is right, it is missing permissions - stop and tell the user. Do not retry-loop. |
| `202 Accepted` but no result         | Poll LRO to completion.                                                                                               |
| Parts missing after updateDefinition | Must include ALL parts - modified + unmodified.                                                                       |
| Refresh credential error             | Direct user to configure in Service portal. Do not retry.                                                             |
| DAX errors in measures               | Check column/table name references (case-sensitive). Verify referenced objects exist.                                 |
| Deployment failure                   | Check workspace permissions, model compatibility level, and Direct Lake expression source references.                 |
| Missing data source                  | Verify M parameters or named expressions are correctly defined.                                                       |
