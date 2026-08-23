# status-event-aging

A pure T-SQL query that calculates stage durations and summary KPIs from a chronological status-change log.

It processes active sources belonging to a configurable group, maps business statuses into generic numeric stages, measures the time spent in each stage, and produces four key metrics per source/entry pair.

## What it does

1. Orders every status-change event chronologically within each `SourceID` + `EntryID`.
2. Assigns a numeric stage (1–6) based on the new status value.
3. Computes the duration (in days) between consecutive events.
4. Aggregates four KPIs:
   - **Aging Supplier** – total days spent in “Rework”
   - **Aging Review** – total days spent in stages 3 + 4 + 5
   - **Aging Final** – total days spent only in stage 5
   - **Release Time** – sum of all stage durations

## Expected tables

| Table | Purpose |
|-------|---------|
| `dbo.StatusEvent` | Chronological log of status changes (`SourceID`, `EntryID`, `EventDate`, `OldStatus`, `NewStatus`) |
| `dbo.SourceRegistry` | Source master data (`SourceID`, `SourceGroup`, `IsActive`) |

## Stage mapping (fully abstracted)

| Stage | Status values that map to it |
|-------|------------------------------|
| 1 | `Due` |
| 2 | `Rework` |
| 3 | `Delivered` |
| 4 | `Reviewed & Ready for Business Approval`, `Rejected` |
| 5 | `Approved & Ready for Final Approval`, `Accepted & Ready for Final Approval`, `Accepted with Comments & Ready for Final Approval`, `Reviewed & Ready for Secondary Review` |
| 6 | All terminal / release / hold / reference statuses |

You can freely edit the `CASE` expression to match your own status vocabulary.

## Usage

```sql
-- Simply execute the query (or wrap it in a stored procedure / view)
-- No parameters required; filtering is done inside the CTEs.
```

## Customization points

- Change the source-group filter (`SourceGroup = 'DOC'`) to any value you need.
- Adjust the stage-mapping `CASE` expression.
- Rename the four KPI columns if desired.
- Add additional filters or output columns as required.

## Requirements

- SQL Server 2012 or later (uses window functions and `LEAD`)
- Read access to the two tables listed above

## License

MIT License – free for personal or commercial use.
```