-- ============================================================
-- File: 08_Monitoring_Queries.sql
-- Description: Monitoring queries for partition operations
-- ============================================================

USE DBADB
GO

PRINT '===================================================='
PRINT '📊 Creating Monitoring Queries'
PRINT '===================================================='
PRINT ''

-- ============================================================
-- Query 1: View Current Operations
-- ============================================================
PRINT '📝 Query 1: View Current Operations'

IF OBJECT_ID('dbo.vw_CurrentOperations', 'V') IS NOT NULL
    DROP VIEW dbo.vw_CurrentOperations
GO

CREATE VIEW dbo.vw_CurrentOperations
AS
SELECT 
    LogID,
    DatabaseName,
    TableName,
    SchemaName,
    PartitionColumn,
    StepName,
    StepDescription,
    StartTime,
    DATEDIFF(SECOND, StartTime, GETDATE()) AS ElapsedSeconds,
    CASE 
        WHEN DATEDIFF(SECOND, StartTime, GETDATE()) < 60 
        THEN CAST(DATEDIFF(SECOND, StartTime, GETDATE()) AS NVARCHAR) + ' seconds'
        WHEN DATEDIFF(SECOND, StartTime, GETDATE()) < 3600 
        THEN CAST(DATEDIFF(SECOND, StartTime, GETDATE()) / 60 AS NVARCHAR) + ' minutes'
        ELSE CAST(DATEDIFF(SECOND, StartTime, GETDATE()) / 3600 AS NVARCHAR) + ' hours'
    END AS ElapsedTime,
    Status,
    ExecutionMode,
    AdditionalInfo,
    CASE 
        WHEN Status = 'Running' THEN '🔄'
        WHEN Status = 'Pending' THEN '⏳'
        WHEN Status = 'Success' THEN '✅'
        WHEN Status = 'Failed' THEN '❌'
        ELSE 'ℹ️'
    END AS StatusIcon,
    LogDate
FROM dbo.PartitioningLog
WHERE Status IN ('Running', 'Pending')
  AND StepName != 'START'
ORDER BY StartTime DESC
GO

PRINT '✅ vw_CurrentOperations created'
PRINT ''

-- ============================================================
-- Query 2: Recent Operations History
-- ============================================================
PRINT '📝 Query 2: Recent Operations History'

IF OBJECT_ID('dbo.vw_RecentOperations', 'V') IS NOT NULL
    DROP VIEW dbo.vw_RecentOperations
GO

CREATE VIEW dbo.vw_RecentOperations
AS
SELECT TOP 100
    LogID,
    DatabaseName,
    TableName,
    SchemaName,
    PartitionColumn,
    StepName,
    Status,
    StartTime,
    EndTime,
    DurationSeconds,
    CASE 
        WHEN DurationSeconds < 60 THEN CAST(DurationSeconds AS NVARCHAR) + ' sec'
        WHEN DurationSeconds < 3600 THEN CAST(DurationSeconds / 60 AS NVARCHAR) + ' min'
        ELSE CAST(DurationSeconds / 3600 AS NVARCHAR) + ' hrs'
    END AS Duration,
    CASE 
        WHEN Status = 'Success' THEN '✅'
        WHEN Status = 'Failed' THEN '❌'
        WHEN Status = 'DryRunComplete' THEN '🔬'
        ELSE 'ℹ️'
    END AS StatusIcon,
    ExecutionMode,
    CASE 
        WHEN ErrorMessage IS NOT NULL THEN LEFT(ErrorMessage, 100) + '...'
        ELSE NULL
    END AS ErrorPreview,
    LogDate
FROM dbo.PartitioningLog
WHERE StepName != 'START'
ORDER BY LogID DESC
GO

PRINT '✅ vw_RecentOperations created'
PRINT ''

-- ============================================================
-- Query 3: Error Summary
-- ============================================================
PRINT '📝 Query 3: Error Summary'

IF OBJECT_ID('dbo.vw_ErrorSummary', 'V') IS NOT NULL
    DROP VIEW dbo.vw_ErrorSummary
GO

CREATE VIEW dbo.vw_ErrorSummary
AS
SELECT 
    DatabaseName,
    TableName,
    COUNT(*) AS ErrorCount,
    MAX(StartTime) AS LastErrorDate,
    MIN(StartTime) AS FirstErrorDate,
    STRING_AGG(DISTINCT StepName, ', ') AS ErrorSteps,
    COUNT(DISTINCT StepName) AS UniqueStepsWithErrors,
    CAST(COUNT(*) * 100.0 / 
        (SELECT COUNT(*) FROM dbo.PartitioningLog WHERE Status = 'Failed') AS DECIMAL(5,2)) AS ErrorPercentage
FROM dbo.PartitioningLog
WHERE Status = 'Failed'
GROUP BY DatabaseName, TableName
HAVING COUNT(*) > 1
ORDER BY ErrorCount DESC
GO

PRINT '✅ vw_ErrorSummary created'
PRINT ''

-- ============================================================
-- Query 4: Performance Trends
-- ============================================================
PRINT '📝 Query 4: Performance Trends'

IF OBJECT_ID('dbo.vw_PerformanceTrends', 'V') IS NOT NULL
    DROP VIEW dbo.vw_PerformanceTrends
GO

CREATE VIEW dbo.vw_PerformanceTrends
AS
SELECT 
    CAST(StartTime AS DATE) AS OperationDate,
    DatabaseName,
    TableName,
    COUNT(*) AS OperationsCount,
    AVG(DurationSeconds) AS AvgDurationSeconds,
    MIN(DurationSeconds) AS MinDurationSeconds,
    MAX(DurationSeconds) AS MaxDurationSeconds,
    SUM(CASE WHEN Status = 'Success' THEN 1 ELSE 0 END) AS SuccessCount,
    SUM(CASE WHEN Status = 'Failed' THEN 1 ELSE 0 END) AS FailureCount,
    CAST(SUM(CASE WHEN Status = 'Success' THEN 1 ELSE 0 END) * 100.0 / COUNT(*) AS DECIMAL(5,2)) AS SuccessRate
FROM dbo.PartitioningLog
WHERE StepName != 'START'
  AND StartTime >= DATEADD(DAY, -30, GETDATE())
GROUP BY CAST(StartTime AS DATE), DatabaseName, TableName
HAVING COUNT(*) > 1
ORDER BY OperationDate DESC
GO

PRINT '✅ vw_PerformanceTrends created'
PRINT ''

-- ============================================================
-- Query 5: Table Size Analysis
-- ============================================================
PRINT '📝 Query 5: Table Size Analysis'

IF OBJECT_ID('dbo.vw_TableSizeAnalysis', 'V') IS NOT NULL
    DROP VIEW dbo.vw_TableSizeAnalysis
GO

CREATE VIEW dbo.vw_TableSizeAnalysis
AS
SELECT 
    DatabaseName,
    TableName,
    COUNT(*) AS PartitionOperations,
    MAX(StartTime) AS LastOperation,
    AVG(CAST(AdditionalInfo AS INT)) AS AvgRowsMoved -- Assumes AdditionalInfo contains row count
FROM dbo.PartitioningLog
WHERE StepName = 'MOVE_DATA'
  AND Status = 'Success'
  AND AdditionalInfo IS NOT NULL
  AND ISNUMERIC(AdditionalInfo) = 1
GROUP BY DatabaseName, TableName
HAVING COUNT(*) > 1
ORDER BY AvgRowsMoved DESC
GO

PRINT '✅ vw_TableSizeAnalysis created'
PRINT ''

-- ============================================================
-- Monitoring Scripts
-- ============================================================
PRINT '📝 Creating monitoring stored procedures...'

IF OBJECT_ID('dbo.sp_MonitorPartitionOperations', 'P') IS NOT NULL
    DROP PROCEDURE dbo.sp_MonitorPartitionOperations
GO

CREATE PROCEDURE dbo.sp_MonitorPartitionOperations
    @DatabaseName NVARCHAR(128) = NULL,
    @Status NVARCHAR(20) = NULL,
    @HoursBack INT = 24
AS
BEGIN
    SET NOCOUNT ON
    
    PRINT '===================================================='
    PRINT '📊 Partition Operations Monitor'
    PRINT '===================================================='
    PRINT ''
    
    PRINT '📋 Recent Operations:'
    PRINT '-------------------'
    
    SELECT 
        StatusIcon,
        DatabaseName,
        TableName,
        StepName,
        Status,
        StartTime,
        Duration,
        ExecutionMode
    FROM dbo.vw_RecentOperations
    WHERE (@DatabaseName IS NULL OR DatabaseName = @DatabaseName)
      AND (@Status IS NULL OR Status = @Status)
      AND StartTime >= DATEADD(HOUR, -@HoursBack, GETDATE())
    ORDER BY StartTime DESC
    
    PRINT ''
    PRINT '📊 Summary Statistics:'
    PRINT '---------------------'
    
    SELECT 
        COUNT(*) AS TotalOperations,
        SUM(CASE WHEN Status = 'Success' THEN 1 ELSE 0 END) AS Successful,
        SUM(CASE WHEN Status = 'Failed' THEN 1 ELSE 0 END) AS Failed,
        SUM(CASE WHEN Status = 'Running' THEN 1 ELSE 0 END) AS Running,
        AVG(DurationSeconds) AS AvgDuration,
        MAX(DurationSeconds) AS MaxDuration
    FROM dbo.PartitioningLog
    WHERE (@DatabaseName IS NULL OR DatabaseName = @DatabaseName)
      AND (@Status IS NULL OR Status = @Status)
      AND StartTime >= DATEADD(HOUR, -@HoursBack, GETDATE())
      AND StepName != 'START'
    
    PRINT ''
    PRINT '⚠️ Recent Errors:'
    PRINT '----------------'
    
    SELECT TOP 10
        ErrorNumber,
        ErrorSeverity,
        ErrorMessage,
        ErrorDate,
        DatabaseName,
        TableName
    FROM dbo.PartitioningErrorLog el
    INNER JOIN dbo.PartitioningLog pl ON el.LogID = pl.LogID
    WHERE (@DatabaseName IS NULL OR pl.DatabaseName = @DatabaseName)
      AND ErrorDate >= DATEADD(HOUR, -@HoursBack, GETDATE())
    ORDER BY ErrorDate DESC
    
    PRINT ''
    PRINT '===================================================='
END
GO

PRINT '✅ sp_MonitorPartitionOperations created'
PRINT ''

-- ============================================================
-- Alerting Script
-- ============================================================
IF OBJECT_ID('dbo.sp_CheckPartitionAlerts', 'P') IS NOT NULL
    DROP PROCEDURE dbo.sp_CheckPartitionAlerts
GO

CREATE PROCEDURE dbo.sp_CheckPartitionAlerts
    @CheckMinutes INT = 60,
    @FailureThreshold INT = 3
AS
BEGIN
    SET NOCOUNT ON
    
    DECLARE @AlertMessages TABLE (AlertMessage NVARCHAR(MAX))
    
    -- Check for recent failures
    IF EXISTS (
        SELECT 1
        FROM dbo.PartitioningLog
        WHERE Status = 'Failed'
          AND StartTime >= DATEADD(MINUTE, -@CheckMinutes, GETDATE())
        GROUP BY DatabaseName, TableName
        HAVING COUNT(*) >= @FailureThreshold
    )
    BEGIN
        INSERT INTO @AlertMessages
        SELECT 
            '⚠️ ALERT: Multiple failures detected for ' + DatabaseName + '.' + TableName + 
            ' (' + CAST(COUNT(*) AS NVARCHAR) + ' failures in last ' + CAST(@CheckMinutes AS NVARCHAR) + ' minutes)'
        FROM dbo.PartitioningLog
        WHERE Status = 'Failed'
          AND StartTime >= DATEADD(MINUTE, -@CheckMinutes, GETDATE())
        GROUP BY DatabaseName, TableName
        HAVING COUNT(*) >= @FailureThreshold
    END
    
    -- Check for long-running operations
    IF EXISTS (
        SELECT 1
        FROM dbo.PartitioningLog
        WHERE Status = 'Running'
          AND StartTime <= DATEADD(MINUTE, -30, GETDATE())
    )
    BEGIN
        INSERT INTO @AlertMessages
        SELECT 
            '⏰ ALERT: Long-running operation detected for ' + DatabaseName + '.' + TableName +
            ' (Running for ' + CAST(DATEDIFF(MINUTE, StartTime, GETDATE()) AS NVARCHAR) + ' minutes)'
        FROM dbo.PartitioningLog
        WHERE Status = 'Running'
          AND StartTime <= DATEADD(MINUTE, -30, GETDATE())
    END
    
    -- Output alerts
    SELECT AlertMessage AS 'Alert', GETDATE() AS 'AlertTime'
    FROM @AlertMessages
    
    IF NOT EXISTS (SELECT 1 FROM @AlertMessages)
    BEGIN
        PRINT '✅ No alerts at this time'
    END
END
GO

PRINT '✅ sp_CheckPartitionAlerts created'
PRINT ''

PRINT '===================================================='
PRINT '✅ All monitoring queries and views created!'
PRINT '📊 Available views:'
PRINT '   - vw_CurrentOperations'
PRINT '   - vw_RecentOperations'
PRINT '   - vw_ErrorSummary'
PRINT '   - vw_PerformanceTrends'
PRINT '   - vw_TableSizeAnalysis'
PRINT '📊 Available procedures:'
PRINT '   - sp_MonitorPartitionOperations'
PRINT '   - sp_CheckPartitionAlerts'
PRINT '===================================================='
GO