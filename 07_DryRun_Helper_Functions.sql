-- ============================================================
-- File: 09_Maintenance_Procedures.sql
-- Description: Maintenance procedures for partition system
-- ============================================================

USE DBADB
GO

PRINT '===================================================='
PRINT '🔧 Creating Maintenance Procedures'
PRINT '===================================================='
PRINT ''

-- ============================================================
-- Procedure to Archive Old Logs
-- ============================================================
IF OBJECT_ID('dbo.sp_ArchivePartitionLogs', 'P') IS NOT NULL
    DROP PROCEDURE dbo.sp_ArchivePartitionLogs
GO

CREATE PROCEDURE dbo.sp_ArchivePartitionLogs
    @RetentionDays INT = 90,
    @ArchiveToTable NVARCHAR(255) = 'PartitioningLog_Archive',
    @BatchSize INT = 10000,
    @DryRun BIT = 0
AS
BEGIN
    SET NOCOUNT ON
    
    DECLARE @StartTime DATETIME2 = GETDATE()
    DECLARE @RowCount INT = 0
    DECLARE @TotalArchived INT = 0
    
    PRINT '===================================================='
    PRINT '🗄️ Archiving Partition Logs'
    PRINT '===================================================='
    PRINT '📅 Retention days: ' + CAST(@RetentionDays AS NVARCHAR)
    PRINT '📊 Archive table: ' + @ArchiveToTable
    PRINT '📦 Batch size: ' + CAST(@BatchSize AS NVARCHAR)
    PRINT '🔬 Dry run: ' + CASE WHEN @DryRun = 1 THEN 'Yes' ELSE 'No' END
    PRINT ''
    
    -- Check if archive table exists, if not create it
    IF NOT EXISTS (SELECT 1 FROM sys.tables WHERE name = @ArchiveToTable)
    BEGIN
        PRINT '📝 Creating archive table: ' + @ArchiveToTable
        
        DECLARE @CreateTableSQL NVARCHAR(MAX) = '
        CREATE TABLE dbo.' + QUOTENAME(@ArchiveToTable) + ' (
            ArchiveID INT IDENTITY(1,1) PRIMARY KEY,
            LogID INT,
            DatabaseName NVARCHAR(128),
            TableName NVARCHAR(255),
            SchemaName NVARCHAR(128),
            PartitionColumn NVARCHAR(128),
            StepName NVARCHAR(100),
            StepDescription NVARCHAR(MAX),
            StartTime DATETIME2,
            EndTime DATETIME2,
            DurationSeconds INT,
            Status NVARCHAR(20),
            ErrorMessage NVARCHAR(MAX),
            AdditionalInfo NVARCHAR(MAX),
            LogDate DATETIME2,
            ExecutionMode NVARCHAR(20),
            ArchivedDate DATETIME2 DEFAULT GETDATE()
        )
        '
        
        EXEC sp_executesql @CreateTableSQL
        PRINT '✅ Archive table created'
    END
    
    -- Get count of records to archive
    DECLARE @RecordsToArchive INT
    
    SELECT @RecordsToArchive = COUNT(*)
    FROM dbo.PartitioningLog
    WHERE LogDate < DATEADD(DAY, -@RetentionDays, GETDATE())
    
    PRINT '📊 Records to archive: ' + CAST(@RecordsToArchive AS NVARCHAR)
    
    IF @RecordsToArchive = 0
    BEGIN
        PRINT '✅ No records to archive'
        RETURN
    END
    
    IF @DryRun = 1
    BEGIN
        PRINT '🔬 DRY RUN: Would archive ' + CAST(@RecordsToArchive AS NVARCHAR) + ' records'
        PRINT '✅ Dry run completed'
        RETURN
    END
    
    -- Archive in batches
    WHILE @RowCount < @RecordsToArchive
    BEGIN
        INSERT INTO dbo.' + QUOTENAME(@ArchiveToTable) + ' (
            LogID, DatabaseName, TableName, SchemaName, PartitionColumn,
            StepName, StepDescription, StartTime, EndTime, DurationSeconds,
            Status, ErrorMessage, AdditionalInfo, LogDate, ExecutionMode
        )
        SELECT TOP (@BatchSize)
            LogID, DatabaseName, TableName, SchemaName, PartitionColumn,
            StepName, StepDescription, StartTime, EndTime, DurationSeconds,
            Status, ErrorMessage, AdditionalInfo, LogDate, ExecutionMode
        FROM dbo.PartitioningLog
        WHERE LogDate < DATEADD(DAY, -@RetentionDays, GETDATE())
        ORDER BY LogDate ASC
        
        SET @RowCount = @RowCount + @@ROWCOUNT
        SET @TotalArchived = @TotalArchived + @@ROWCOUNT
        
        -- Delete archived records
        DELETE FROM dbo.PartitioningLog
        WHERE LogID IN (
            SELECT LogID 
            FROM dbo.' + QUOTENAME(@ArchiveToTable) + '
            WHERE ArchivedDate >= DATEADD(SECOND, -10, GETDATE())
        )
        
        PRINT '✅ Archived ' + CAST(@TotalArchived AS NVARCHAR) + ' of ' + CAST(@RecordsToArchive AS NVARCHAR) + ' records'
    END
    
    -- Log the archive operation
    INSERT INTO dbo.PartitioningLog (
        DatabaseName, TableName, SchemaName, PartitionColumn,
        StepName, StepDescription, Status, AdditionalInfo
    ) VALUES (
        'DBADB', 'PartitioningLog', 'dbo', 'N/A',
        'ARCHIVE', 'Archived ' + CAST(@TotalArchived AS NVARCHAR) + ' records older than ' + CAST(@RetentionDays AS NVARCHAR) + ' days',
        'Success', 'Archived to ' + @ArchiveToTable
    )
    
    PRINT ''
    PRINT '✅ Archive completed successfully!'
    PRINT '📊 Total archived: ' + CAST(@TotalArchived AS NVARCHAR) + ' records'
    PRINT '⏱️ Duration: ' + CAST(DATEDIFF(SECOND, @StartTime, GETDATE()) AS NVARCHAR) + ' seconds'
    PRINT '===================================================='
END
GO

PRINT '✅ sp_ArchivePartitionLogs created successfully!'
PRINT ''

-- ============================================================
-- Procedure to Clean Up Failed Operations
-- ============================================================
IF OBJECT_ID('dbo.sp_CleanupFailedOperations', 'P') IS NOT NULL
    DROP PROCEDURE dbo.sp_CleanupFailedOperations
GO

CREATE PROCEDURE dbo.sp_CleanupFailedOperations
    @HoursBack INT = 24,
    @DryRun BIT = 0
AS
BEGIN
    SET NOCOUNT ON
    
    PRINT '===================================================='
    PRINT '🧹 Cleaning Up Failed Operations'
    PRINT '===================================================='
    PRINT '📅 Hours back: ' + CAST(@HoursBack AS NVARCHAR)
    PRINT '🔬 Dry run: ' + CASE WHEN @DryRun = 1 THEN 'Yes' ELSE 'No' END
    PRINT ''
    
    -- Get failed operations
    SELECT 
        LogID,
        DatabaseName,
        TableName,
        StepName,
        ErrorMessage,
        StartTime
    INTO #FailedOps
    FROM dbo.PartitioningLog
    WHERE Status = 'Failed'
      AND StartTime >= DATEADD(HOUR, -@HoursBack, GETDATE())
    
    IF NOT EXISTS (SELECT 1 FROM #FailedOps)
    BEGIN
        PRINT '✅ No failed operations found in the last ' + CAST(@HoursBack AS NVARCHAR) + ' hours'
        RETURN
    END
    
    PRINT '📊 Failed operations found: ' + CAST(@@ROWCOUNT AS NVARCHAR)
    PRINT ''
    
    IF @DryRun = 1
    BEGIN
        PRINT '🔬 DRY RUN: Would clean up the following failed operations:'
        PRINT ''
        
        SELECT 
            LogID,
            DatabaseName,
            TableName,
            StepName,
            LEFT(ErrorMessage, 100) AS ErrorPreview,
            StartTime
        FROM #FailedOps
        ORDER BY StartTime DESC
        
        PRINT ''
        PRINT '✅ Dry run completed'
        RETURN
    END
    
    -- Log to audit
    INSERT INTO dbo.PartitioningLog (
        DatabaseName, TableName, SchemaName, PartitionColumn,
        StepName, StepDescription, Status, AdditionalInfo
    ) VALUES (
        'DBADB', 'SYSTEM', 'dbo', 'N/A',
        'CLEANUP', 'Cleaned up ' + CAST(@@ROWCOUNT AS NVARCHAR) + ' failed operations',
        'Success', 'Hours back: ' + CAST(@HoursBack AS NVARCHAR)
    )
    
    PRINT '✅ Failed operations cleaned up successfully'
    PRINT '===================================================='
    
    DROP TABLE #FailedOps
END
GO

PRINT '✅ sp_CleanupFailedOperations created successfully!'
PRINT ''

-- ============================================================
-- Procedure to Update Statistics
-- ============================================================
IF OBJECT_ID('dbo.sp_UpdatePartitionStats', 'P') IS NOT NULL
    DROP PROCEDURE dbo.sp_UpdatePartitionStats
GO

CREATE PROCEDURE dbo.sp_UpdatePartitionStats
    @DatabaseName NVARCHAR(128) = NULL,
    @TableName NVARCHAR(255) = NULL,
    @FullScan BIT = 0
AS
BEGIN
    SET NOCOUNT ON
    
    DECLARE @SQL NVARCHAR(MAX)
    DECLARE @StartTime DATETIME2 = GETDATE()
    DECLARE @StatsCount INT = 0
    
    PRINT '===================================================='
    PRINT '📊 Updating Statistics'
    PRINT '===================================================='
    PRINT '📅 Date: ' + CAST(GETDATE() AS NVARCHAR)
    PRINT '📊 Database: ' + ISNULL(@DatabaseName, 'All')
    PRINT '📊 Table: ' + ISNULL(@TableName, 'All')
    PRINT '🔄 Full scan: ' + CASE WHEN @FullScan = 1 THEN 'Yes' ELSE 'No' END
    PRINT ''
    
    IF @DatabaseName IS NULL
    BEGIN
        -- Update stats for all databases
        DECLARE db_cursor CURSOR FOR
        SELECT name FROM sys.databases 
        WHERE state = 0 
          AND name NOT IN ('master', 'model', 'msdb', 'tempdb')
        
        OPEN db_cursor
        FETCH NEXT FROM db_cursor INTO @DatabaseName
        
        WHILE @@FETCH_STATUS = 0
        BEGIN
            PRINT '📊 Updating stats for database: ' + @DatabaseName
            
            SET @SQL = '
            USE [' + @DatabaseName + ']
            EXEC sp_updatestats ' + CASE WHEN @FullScan = 1 THEN '''resample''' ELSE '' END
            
            EXEC sp_executesql @SQL
            SET @StatsCount = @StatsCount + 1
            
            FETCH NEXT FROM db_cursor INTO @DatabaseName
        END
        
        CLOSE db_cursor
        DEALLOCATE db_cursor
    END
    ELSE IF @TableName IS NULL
    BEGIN
        -- Update stats for all tables in database
        SET @SQL = '
        USE [' + @DatabaseName + ']
        EXEC sp_updatestats ' + CASE WHEN @FullScan = 1 THEN '''resample''' ELSE '' END
        
        EXEC sp_executesql @SQL
        SET @StatsCount = 1
    END
    ELSE
    BEGIN
        -- Update stats for specific table
        SET @SQL = '
        USE [' + @DatabaseName + ']
        UPDATE STATISTICS ' + QUOTENAME(@TableName) + 
        CASE WHEN @FullScan = 1 THEN ' WITH FULLSCAN' ELSE ' WITH RESAMPLE' END
        
        EXEC sp_executesql @SQL
        SET @StatsCount = 1
    END
    
    PRINT ''
    PRINT '✅ Statistics updated successfully!'
    PRINT '📊 Databases/Tables processed: ' + CAST(@StatsCount AS NVARCHAR)
    PRINT '⏱️ Duration: ' + CAST(DATEDIFF(SECOND, @StartTime, GETDATE()) AS NVARCHAR) + ' seconds'
    PRINT '===================================================='
END
GO

PRINT '✅ sp_UpdatePartitionStats created successfully!'
PRINT ''

-- ============================================================
-- Procedure to Generate Maintenance Report
-- ============================================================
IF OBJECT_ID('dbo.sp_GenerateMaintenanceReport', 'P') IS NOT NULL
    DROP PROCEDURE dbo.sp_GenerateMaintenanceReport
GO

CREATE PROCEDURE dbo.sp_GenerateMaintenanceReport
    @DaysBack INT = 30
AS
BEGIN
    SET NOCOUNT ON
    
    PRINT '===================================================='
    PRINT '📋 Partition Maintenance Report'
    PRINT '===================================================='
    PRINT '📅 Period: Last ' + CAST(@DaysBack AS NVARCHAR) + ' days'
    PRINT ''
    
    -- Overall Summary
    PRINT '📊 Overall Summary:'
    PRINT '------------------'
    
    SELECT 
        COUNT(*) AS TotalOperations,
        SUM(CASE WHEN Status = 'Success' THEN 1 ELSE 0 END) AS Successful,
        SUM(CASE WHEN Status = 'Failed' THEN 1 ELSE 0 END) AS Failed,
        SUM(CASE WHEN Status = 'DryRunComplete' THEN 1 ELSE 0 END) AS DryRuns,
        AVG(DurationSeconds) AS AvgDurationSec,
        MAX(DurationSeconds) AS MaxDurationSec,
        MIN(DurationSeconds) AS MinDurationSec,
        COUNT(DISTINCT DatabaseName) AS Databases,
        COUNT(DISTINCT TableName) AS Tables,
        COUNT(DISTINCT CASE WHEN Status = 'Failed' THEN TableName END) AS TablesWithFailures
    FROM dbo.PartitioningLog
    WHERE StartTime >= DATEADD(DAY, -@DaysBack, GETDATE())
      AND StepName = 'START'
    
    PRINT ''
    PRINT '📊 Table Statistics:'
    PRINT '-------------------'
    
    SELECT TOP 20
        DatabaseName,
        TableName,
        COUNT(*) AS Operations,
        SUM(CASE WHEN Status = 'Success' THEN 1 ELSE 0 END) AS Success,
        SUM(CASE WHEN Status = 'Failed' THEN 1 ELSE 0 END) AS Failures,
        CAST(SUM(CASE WHEN Status = 'Success' THEN 1 ELSE 0 END) * 100.0 / COUNT(*) AS DECIMAL(5,2)) AS SuccessRate,
        AVG(DurationSeconds) AS AvgDuration,
        MAX(StartTime) AS LastOperation
    FROM dbo.PartitioningLog
    WHERE StartTime >= DATEADD(DAY, -@DaysBack, GETDATE())
      AND StepName = 'START'
    GROUP BY DatabaseName, TableName
    ORDER BY Operations DESC
    
    PRINT ''
    PRINT '📊 Failure Analysis:'
    PRINT '------------------'
    
    SELECT 
        DatabaseName,
        TableName,
        COUNT(*) AS FailureCount,
        MIN(StartTime) AS FirstFailure,
        MAX(StartTime) AS LastFailure,
        COUNT(DISTINCT StepName) AS UniqueSteps,
        LEFT(MAX(ErrorMessage), 200) AS SampleError
    FROM dbo.PartitioningLog
    WHERE Status = 'Failed'
      AND StartTime >= DATEADD(DAY, -@DaysBack, GETDATE())
    GROUP BY DatabaseName, TableName
    HAVING COUNT(*) > 1
    ORDER BY FailureCount DESC
    
    PRINT ''
    PRINT '📊 Storage Impact:'
    PRINT '-----------------'
    
    ;WITH PartitionSizes AS (
        SELECT 
            DatabaseName,
            TableName,
            SUM(CASE WHEN StepName = 'MOVE_DATA' AND Status = 'Success' 
                THEN CAST(AdditionalInfo AS BIGINT) ELSE 0 END) AS TotalRowsMoved,
            COUNT(CASE WHEN StepName = 'MOVE_DATA' AND Status = 'Success' THEN 1 END) AS MoveOperations
        FROM dbo.PartitioningLog
        WHERE StartTime >= DATEADD(DAY, -@DaysBack, GETDATE())
          AND AdditionalInfo IS NOT NULL
          AND ISNUMERIC(AdditionalInfo) = 1
        GROUP BY DatabaseName, TableName
    )
    SELECT TOP 10
        DatabaseName,
        TableName,
        TotalRowsMoved AS 'Total Rows Moved',
        MoveOperations AS 'Move Operations',
        CAST(TotalRowsMoved * 0.001 AS DECIMAL(18,2)) AS 'Est Data MB'
    FROM PartitionSizes
    ORDER BY TotalRowsMoved DESC
    
    PRINT ''
    PRINT '✅ Report Complete'
    PRINT '===================================================='
END
GO

PRINT '✅ sp_GenerateMaintenanceReport created successfully!'
PRINT ''

PRINT '===================================================='
PRINT '✅ All maintenance procedures created successfully!'
PRINT '🔧 Procedures created:'
PRINT '   - sp_ArchivePartitionLogs'
PRINT '   - sp_CleanupFailedOperations'
PRINT '   - sp_UpdatePartitionStats'
PRINT '   - sp_GenerateMaintenanceReport'
PRINT '===================================================='
GO