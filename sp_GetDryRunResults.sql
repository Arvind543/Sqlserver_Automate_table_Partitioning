-- Procedure to view dry run results
CREATE PROCEDURE dbo.sp_GetDryRunResults
    @ExecutionID UNIQUEIDENTIFIER,
    @Format NVARCHAR(20) = 'TABLE' -- TABLE, XML, JSON
AS
BEGIN
    SET NOCOUNT ON
    
    IF @Format = 'XML'
    BEGIN
        SELECT 
            (SELECT 
                ExecutionID,
                StepOrder,
                StepName,
                StepDescription,
                EstimatedDurationSeconds,
                EstimatedRowCount,
                SQLToExecute,
                Prerequisites,
                Warnings,
                Status,
                CreatedDate
             FROM dbo.DryRunResults 
             WHERE ExecutionID = @ExecutionID
             ORDER BY StepOrder
             FOR XML AUTO, ROOT('DryRunResults'))
    END
    ELSE IF @Format = 'JSON'
    BEGIN
        SELECT 
            (SELECT 
                ExecutionID,
                StepOrder,
                StepName,
                StepDescription,
                EstimatedDurationSeconds,
                EstimatedRowCount,
                SQLToExecute,
                Prerequisites,
                Warnings,
                Status,
                CreatedDate
             FROM dbo.DryRunResults 
             WHERE ExecutionID = @ExecutionID
             ORDER BY StepOrder
             FOR JSON AUTO)
    END
    ELSE -- TABLE format
    BEGIN
        SELECT 
            StepOrder,
            StepName,
            StepDescription,
            EstimatedDurationSeconds AS [EstDurationSec],
            EstimatedRowCount AS [EstRows],
            LEFT(SQLToExecute, 500) AS [SQLToExecute_Preview],
            Prerequisites,
            Warnings,
            Status,
            CreatedDate
        FROM dbo.DryRunResults 
        WHERE ExecutionID = @ExecutionID
        ORDER BY StepOrder
    END
END
GO

-- Procedure to compare dry run vs actual execution
CREATE PROCEDURE dbo.sp_CompareDryRunToActual
    @DryRunExecutionID UNIQUEIDENTIFIER,
    @ActualLogID INT
AS
BEGIN
    SET NOCOUNT ON
    
    SELECT 
        'Comparison Report' AS ReportType,
        d.StepName,
        d.StepDescription,
        d.EstimatedDurationSeconds AS DryRunEstDuration,
        DATEDIFF(SECOND, l.StartTime, l.EndTime) AS ActualDuration,
        CASE 
            WHEN DATEDIFF(SECOND, l.StartTime, l.EndTime) <= d.EstimatedDurationSeconds * 1.2 
            THEN 'Within Estimate'
            WHEN DATEDIFF(SECOND, l.StartTime, l.EndTime) <= d.EstimatedDurationSeconds * 1.5 
            THEN 'Slightly Exceeded Estimate'
            ELSE 'Significantly Exceeded Estimate'
        END AS PerformanceNote,
        d.Status AS DryRunStatus,
        l.Status AS ActualStatus
    FROM dbo.DryRunResults d
    INNER JOIN dbo.PartitioningLog l ON l.TableName = d.SQLToExecute -- This is simplified, adjust as needed
    WHERE d.ExecutionID = @DryRunExecutionID
      AND l.LogID = @ActualLogID
    ORDER BY d.StepOrder
END
GO
