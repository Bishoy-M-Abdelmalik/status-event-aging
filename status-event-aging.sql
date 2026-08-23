/*
  Generic status-event aging / KPI query
  Calculates stage durations and summary metrics from a chronological
  status-change log for active sources belonging to a configurable group.
*/

WITH OrderedEvents AS (
    SELECT
        A.[SourceID],
        A.[EntryID],
        A.[EventDate],
        A.[OldStatus],
        A.[NewStatus],

        /* Map business statuses to generic numeric stages */
        [Stage] = CASE
            WHEN [NewStatus] = 'Due'                                                      THEN 1
            WHEN [NewStatus] = 'Rework'                                                   THEN 2
            WHEN [NewStatus] = 'Delivered'                                                THEN 3
            WHEN [NewStatus] IN (
                    'Reviewed & Ready for Business Approval',
                    'Rejected'
                 )                                                                       THEN 4
            WHEN [NewStatus] IN (
                    'Approved & Ready for Final Approval',
                    'Accepted & Ready for Final Approval',
                    'Accepted with Comments & Ready for Final Approval',
                    'Reviewed & Ready for Secondary Review'
                 )                                                                       THEN 5
            WHEN [NewStatus] IN (
                    'Accepted & No Release Required',
                    'Accepted with Comments & No Release Required',
                    'Approved & No Release Required',
                    'Not Required',
                    'Released',
                    'Reviewed & Agreed for this Phase',
                    'Reference',
                    'Deferred',
                    'Accepted & Ready for Release',
                    'Approved & Ready for Release',
                    'Released With No Concurrence',
                    'On Hold',
                    'Accepted with Comments & Ready for Release'
                 )                                                                       THEN 6
            ELSE NULL
        END,

        /* Chronological order of events per SourceID + EntryID */
        [EventOrder] = ROW_NUMBER() OVER (
            PARTITION BY A.[SourceID], A.[EntryID]
            ORDER BY A.[EventDate]
        )
    FROM dbo.StatusEvent AS A
    INNER JOIN dbo.SourceRegistry AS B
        ON  B.[SourceID]   = A.[SourceID]
        AND B.[SourceGroup] = 'DOC'          -- configurable group filter
        AND B.[IsActive]    = 1
),

StageDurations AS (
    SELECT
        [SourceID],
        [EntryID],
        [NewStatus],
        [Stage],

        /* Duration in days until the next event (0 for the last event) */
        [EventDuration] = CASE
            WHEN LEAD([EventDate], 1) OVER (
                     PARTITION BY [SourceID], [EntryID]
                     ORDER BY [EventOrder]
                 ) IS NOT NULL
            THEN DATEDIFF(
                     DAY,
                     [EventDate],
                     LEAD([EventDate], 1) OVER (
                         PARTITION BY [SourceID], [EntryID]
                         ORDER BY [EventOrder]
                     )
                 )
            ELSE 0
        END
    FROM OrderedEvents
),

KPIs AS (
    SELECT
        [SourceID],
        [EntryID],

        /* Time spent exclusively in Rework status */
        [Aging Supplier]   = SUM(CASE WHEN [NewStatus] = 'Rework' THEN [EventDuration] ELSE 0 END),

        /* Combined time in stages 3 + 4 + 5 */
        [Aging Review]     = SUM(CASE WHEN Stage IN (3, 4, 5) THEN [EventDuration] ELSE 0 END),

        /* Time spent only in stage 5 */
        [Aging Final]      = SUM(CASE WHEN Stage = 5 THEN [EventDuration] ELSE 0 END),

        /* Total elapsed time across all stages */
        [Release Time]     = SUM([EventDuration])
    FROM StageDurations
    GROUP BY
        [SourceID],
        [EntryID]
)

SELECT
    [SourceID],
    [EntryID],
    [Aging Supplier],
    [Aging Review],
    [Aging Final],
    [Release Time]
FROM KPIs
ORDER BY
    [SourceID],
    [EntryID];