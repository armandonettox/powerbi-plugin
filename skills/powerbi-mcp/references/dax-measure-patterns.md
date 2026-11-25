# DAX Measure Pattern Catalog

A quick-reference catalog by business category: the "what" and "when" of each measure pattern. For language syntax, query rules and UDFs, see `dax-guidelines.md`. For performance (storage engine, expensive filter context, variables, materialization), see `dax-perf-decision-guide.md` and `dax-perf-patterns.md`. Assumes a calendar table marked as a Date Table (see `calendar_operations` / `direct-lake-guidelines.md` where applicable).

Reference sources: SQLBI DAX Patterns (patterns.daxpatterns.com), Microsoft Learn DAX reference.

## Index

| Pattern | When to use | Section |
|---|---|---|
| YTD / QTD / MTD | Cumulative for the current year/quarter/month up to the date | [#time-intelligence-ytd-qtd-mtd](#time-intelligence-ytd--qtd--mtd) |
| Prior year comparison (LY) | Show the value of the same period in the previous year | [#comparison-with-prior-year-ly](#comparison-with-prior-year-ly) |
| YoY growth % | Percentage change between the current period and the prior year | [#yoy-growth-](#yoy-growth-) |
| Same period previous month (MoM) | Comparison with the immediately previous month | [#same-period-previous-month-mom](#same-period-previous-month-mom) |
| Moving averages | Smooth seasonality/noise, see the trend | [#moving-averages](#moving-averages) |
| Top N | Show only the N largest items of a dimension | [#top-n](#top-n) |
| RANKX / dynamic ranking | Position of an item within the current filter context | [#rankx--dynamic-ranking](#rankx--dynamic-ranking) |
| Running total / cumulative | Progressive sum along an axis (time or other) | [#running-total--cumulative](#running-total--cumulative) |
| % of grand total | Share of a row in the grand total, ignoring row filters | [#-of-grand-total](#-of-grand-total) |
| % of parent (hierarchy) | Share of a level within its immediate parent level | [#-of-parent-hierarchy](#-of-parent-hierarchy) |
| New vs returning vs lost | Segment customers/items by behavior between periods | [#new-vs-returning-vs-lost](#new-vs-returning-vs-lost) |
| Allocation / proportional split | Distribute an aggregated value across dimensions by weight | [#allocation--proportional-split](#allocation--proportional-split) |
| Currency / unit conversion | Normalize values in different currencies/units to a common base | [#currency--unit-conversion](#currency--unit-conversion) |
| What-if with parameters | Simulate scenarios by varying a slicer-controlled parameter | [#what-if-with-parameters](#what-if-with-parameters) |
| Distinct count vs count (many-to-many) | Count unique entities correctly in an m:n relationship | [#distinct-count-vs-count-many-to-many](#distinct-count-vs-count-many-to-many) |

---

## Time Intelligence: YTD / QTD / MTD

**When to use:** fiscal/calendar cumulative KPIs (YTD sales, QTD target) displayed alongside the selected current period.

```dax
Sales YTD =
CALCULATE (
    [Total Sales],
    DATESYTD ( 'Calendar'[Date] )       -- swap for DATESQTD/DATESMTD for QTD/MTD
)

// Variation: fiscal year ending on a date other than 12/31
Sales YTD Fiscal =
CALCULATE (
    [Total Sales],
    DATESYTD ( 'Calendar'[Date], "06-30" )   -- fiscal year ending on Jun 30
)
```

Common variations: `TOTALYTD([Total Sales], 'Calendar'[Date])` is equivalent and more direct when there are no other filters to compose. For QTD/MTD, swap `DATESYTD` for `DATESQTD`/`DATESMTD` or use `TOTALQTD`/`TOTALMTD`.

## Comparison with Prior Year (LY)

**When to use:** show "same period, previous year" next to the current value, for direct benchmarking (this is not a growth %, it is the raw value).

```dax
Sales LY =
CALCULATE (
    [Total Sales],
    SAMEPERIODLASTYEAR ( 'Calendar'[Date] )
)

// Variation: N years back using DATEADD (more flexible than SAMEPERIODLASTYEAR)
Sales N Years Ago =
CALCULATE (
    [Total Sales],
    DATEADD ( 'Calendar'[Date], -2, YEAR )
)
```

Caution: `SAMEPERIODLASTYEAR` and `DATEADD` respect the current period filter (partial month, quarter); if the current month is incomplete, the comparison will also be truncated. Combine with an "elapsed vs same elapsed LY" approach when that distorts the reading.

## YoY Growth %

**When to use:** percentage indicator of year-over-year change, the calculation most requested in executive dashboards.

```dax
YoY Growth % =
VAR CurrentSales = [Total Sales]
VAR SalesLY = [Sales LY]
RETURN
    DIVIDE ( CurrentSales - SalesLY, SalesLY )
```

Variation: absolute growth (`CurrentSales - SalesLY`) as a separate measure to show in cards next to the %. Always use `DIVIDE` (never `/`) to handle a zero/blank denominator without an error.

## Same Period Previous Month (MoM)

**When to use:** compare the current month with the immediately previous month (not the prior year). Common in short-term operational metrics (monthly churn, monthly average ticket).

```dax
Sales Previous Month =
CALCULATE (
    [Total Sales],
    DATEADD ( 'Calendar'[Date], -1, MONTH )
)

MoM Growth % =
VAR CurrentSales = [Total Sales]
VAR PreviousSales = [Sales Previous Month]
RETURN
    DIVIDE ( CurrentSales - PreviousSales, PreviousSales )
```

## Moving Averages

**When to use:** smooth volatile series (e.g. daily sales) to reveal the trend without short-term noise. Common: 3-month, 7-day, 12-month (trailing) moving average.

```dax
Moving Average 3M =
VAR MovingPeriod =
    DATESINPERIOD (
        'Calendar'[Date],
        LASTDATE ( 'Calendar'[Date] ),
        -3,
        MONTH
    )
RETURN
    CALCULATE ( AVERAGEX ( VALUES ( 'Calendar'[Month] ), [Total Sales] ), MovingPeriod )

// Simplified variation when the grain is already monthly
Moving Average 3M Simple =
AVERAGEX (
    DATESINPERIOD ( 'Calendar'[Date], LASTDATE ( 'Calendar'[Date] ), -3, MONTH ),
    [Total Sales]
)
```

Note: `AVERAGEX` over `DATESINPERIOD` at daily grain computes the average per day, not per month. Adjust the granularity of the virtual table to the desired grain of the average.

---

## Top N

**When to use:** "top 10 products", "top 5 customers by revenue", always respecting the active filter context (selected category, region, period).

```dax
Sales Top N Customers =
VAR N = 10
VAR RankedCustomers =
    TOPN ( N, VALUES ( Customer[Customer] ), [Total Sales], DESC )
RETURN
    CALCULATE ( [Total Sales], RankedCustomers )
```

Variation: Top N parameterized via a parameter table (disconnected table) tied to a slicer, so the user can adjust N in the report without editing the measure.

## RANKX / Dynamic Ranking

**When to use:** show the position (1st, 2nd, 3rd...) of a specific item within the current filter context, a ranking that recalculates as filters are applied (region, period).

```dax
Customer Ranking =
RANKX (
    ALLSELECTED ( Customer[Customer] ),      -- ranking universe: respects external filters, ignores row selection
    [Total Sales],
    ,
    DESC,
    DENSE                                   -- DENSE avoids "gaps" in the ranking on ties
)
```

Variations: `ALL(Customer[Customer])` instead of `ALLSELECTED` when the ranking must be fixed (against the full universe) regardless of page filters; `SKIP` (default) instead of `DENSE` when ties should "skip" positions, as in a traditional Olympic ranking.

---

## Running Total / Cumulative

**When to use:** progressive sum along an ordered axis. Not necessarily time (it can be a ranking, cumulative inventory value, a funnel).

```dax
Cumulative =
CALCULATE (
    [Total Sales],
    FILTER (
        ALLSELECTED ( 'Calendar'[Date] ),
        'Calendar'[Date] <= MAX ( 'Calendar'[Date] )
    )
)
```

Variation (generic running total over any numeric axis, not just date):

```dax
Cumulative by Rank =
VAR CurrentRank = [Customer Ranking]
RETURN
    CALCULATE (
        [Total Sales],
        FILTER ( ALLSELECTED ( Customer[Customer] ), [Customer Ranking] <= CurrentRank )
    )
```

---

## % of Grand Total

**When to use:** share of a category/product/region in the grand total, ignoring row filters (but keeping external page/slicer filters where applicable).

```dax
% of Grand Total =
DIVIDE (
    [Total Sales],
    CALCULATE ( [Total Sales], ALL ( Product ) )   -- ALL removes only the Product filter
)

// Variation: ignore ALL row filters, keep only explicit page slicers
% of Absolute Total =
DIVIDE ( [Total Sales], CALCULATE ( [Total Sales], ALLSELECTED () ) )
```

## % of Parent (Hierarchy)

**When to use:** within a hierarchy (Category > Subcategory > Product), show each level's share within its immediate parent level, which differs from % of grand total.

```dax
% of Parent (Subcategory) =
DIVIDE (
    [Total Sales],
    CALCULATE ( [Total Sales], ALL ( Product[Product] ) )   -- removes only the child level filter, keeps the subcategory one
)
```

General rule: `ALL()` on the most granular (child) level column preserves the filter of the level(s) above it in the hierarchy, producing the "% of parent". For hierarchies, use `ISFILTERED`/`HASONEVALUE` to handle the root level (where there is no parent) and avoid an unintended division by the grand total.

---

## New vs Returning vs Lost

**When to use:** segmenting customers (or any entity) by purchase/activity behavior between two periods, a pillar of retention/churn analysis.

```dax
New Customers =
VAR CurrentPeriodCustomers = CALCULATETABLE ( VALUES ( Customer[CustomerID] ) )
VAR PreviousPeriodCustomers =
    CALCULATETABLE (
        VALUES ( Customer[CustomerID] ),
        SAMEPERIODLASTYEAR ( 'Calendar'[Date] )     -- or DATEADD for previous month
    )
RETURN
    COUNTROWS ( EXCEPT ( CurrentPeriodCustomers, PreviousPeriodCustomers ) )

Returning Customers =
VAR CurrentPeriodCustomers = CALCULATETABLE ( VALUES ( Customer[CustomerID] ) )
VAR PreviousPeriodCustomers =
    CALCULATETABLE ( VALUES ( Customer[CustomerID] ), SAMEPERIODLASTYEAR ( 'Calendar'[Date] ) )
RETURN
    COUNTROWS ( INTERSECT ( CurrentPeriodCustomers, PreviousPeriodCustomers ) )

Lost Customers (Churn) =
VAR CurrentPeriodCustomers = CALCULATETABLE ( VALUES ( Customer[CustomerID] ) )
VAR PreviousPeriodCustomers =
    CALCULATETABLE ( VALUES ( Customer[CustomerID] ), SAMEPERIODLASTYEAR ( 'Calendar'[Date] ) )
RETURN
    COUNTROWS ( EXCEPT ( PreviousPeriodCustomers, CurrentPeriodCustomers ) )

// Variation: churn rate %
Churn Rate % =
DIVIDE ( [Lost Customers (Churn)], CALCULATE ( [Returning Customers] + [Lost Customers (Churn)] ) )
```

Basis: SQLBI's "New and Returning Customers" pattern (patterns.daxpatterns.com/new-and-returning-customers). `EXCEPT`/`INTERSECT` operate on single-column tables (`VALUES`), ensuring the comparison is by customer key, not by fact row.

---

## Allocation / Proportional Split

**When to use:** distribute a value known only at an aggregate level (e.g. indirect freight cost per order) across more granular dimensions (order items), proportionally to a weight (value, quantity, physical weight).

```dax
Allocated Cost per Item =
VAR OrderTotalCost = CALCULATE ( [Order Freight Cost], ALLEXCEPT ( 'Order', 'Order'[OrderID] ) )
VAR OrderItemsTotalValue =
    CALCULATE ( [Total Sales], ALLEXCEPT ( 'Order', 'Order'[OrderID] ) )
RETURN
    DIVIDE ( [Total Sales], OrderItemsTotalValue ) * OrderTotalCost
```

Variation: weight by quantity instead of value. Swap `[Total Sales]` for the desired weight (`SUM(Item[Quantity])`, `SUM(Item[WeightKg])`) keeping the same proportion `part / whole * total_to_allocate`. A pattern analogous to SQLBI's "Allocate a fixed cost".

---

## Currency / Unit Conversion

**When to use:** a model with transactions in multiple currencies or units (e.g. BRL/USD, kg/lb) that needs to report in a single base, with a rate that varies by date.

```dax
Sales in BRL =
SUMX (
    Sales,
    VAR DailyRate =
        LOOKUPVALUE (
            'ExchangeRate'[Rate],
            'ExchangeRate'[Currency], Sales[Currency],
            'ExchangeRate'[Date], Sales[TransactionDate]
        )
    RETURN
        Sales[OriginalAmount] * DailyRate
)

// Variation: monthly rate (more common in financial reports than a daily rate)
Sales in BRL (Monthly Rate) =
SUMX (
    Sales,
    Sales[OriginalAmount]
        * CALCULATE (
            VALUES ( 'ExchangeRate'[Rate] ),
            'ExchangeRate'[Currency] = Sales[Currency],
            'ExchangeRate'[YearMonth] = Sales[TransactionYearMonth]
        )
)
```

Preferred modeling: a rate table with explicit granularity (day or month) related by currency + date, avoiding `LOOKUPVALUE` in large models (per-row cost). In that case, prefer a physical relationship with `TREATAS` or a join via an auxiliary calendar. For unit conversion (kg<->lb, m<->ft), the same pattern applies with a fixed factor instead of a date-varying rate.

---

## What-If with Parameters

**When to use:** scenario simulation controlled by the user via slicer: "what if the price goes up X%?", "what if the conversion rate is Y%?", without changing real data.

```dax
// 1. Create a What-If parameter: Modeling > New Parameter > Numeric
//    Generates a disconnected table 'Price Change' with column 'Price Change Value'

Simulated Sales =
VAR SelectedChange = SELECTEDVALUE ( 'Price Change'[Price Change Value], 0 )
RETURN
    [Total Sales] * ( 1 + SelectedChange )

// Variation: combined parameter (price x volume) for elasticity
Simulated Sales Elasticity =
VAR PriceChange = SELECTEDVALUE ( 'Price Change'[Value], 0 )
VAR VolumeElasticity = -1.5                     -- business assumption, could be another parameter
RETURN
    [Total Sales] * ( 1 + PriceChange ) * ( 1 + PriceChange * VolumeElasticity )
```

Always use `SELECTEDVALUE` (not `VALUES`) for simulation parameters. It safely returns `BLANK`/the default when multiple values are selected, avoiding an ambiguous-context error.

---

## Distinct Count vs Count (Many-to-Many)

**When to use:** an m:n relationship (e.g. a customer can have multiple accounts, a product belongs to multiple categories) where a direct `COUNT`/`COUNTROWS` duplicates rows. Always prefer `DISTINCTCOUNT` on the key of the entity you want to count, not on the fact table.

```dax
Distinct Customers =
DISTINCTCOUNT ( Sales[CustomerID] )

// Wrong in m:n: COUNTROWS(Sales) counts transactions, not customers -- it inflates the number
// when there is a bridge table between Customer and Account

// Correct with a Customer <-> Account <-> Sales bridge table:
Distinct Customers via Bridge =
CALCULATE (
    DISTINCTCOUNT ( CustomerAccount[CustomerID] ),
    Sales  -- filter context propagates via the bridge table to the dimension table
)

// Variation: "correct" count in m:n using CROSSFILTER when the
// physical bridge->fact relationship is configured as single-direction filter
Customers with Purchase (m:n) =
CALCULATE (
    DISTINCTCOUNT ( Customer[CustomerID] ),
    CROSSFILTER ( CustomerAccount[AccountID], Sales[AccountID], BOTH )
)
```

Rule of thumb: in a model with a bridge table for m:n (the recommended pattern over a native m:n relationship), the fact row filter must reach the dimension via the bridge table. Confirm the relationship direction (`relationship_operations`) before assuming the `DISTINCTCOUNT` is correct. `COUNT`/`COUNTROWS` over the fact is almost never the right business metric when there is an m:n in the relationship chain.
