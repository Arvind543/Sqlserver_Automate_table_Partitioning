-- ============================================================
-- File: 04_Helper_Procedures.sql
-- Description: Helper procedures for partition management
-- ============================================================

USE DBADB
GO

PRINT '===================================================='
PRINT '🛠️ Creating Helper Procedures'
PRINT '===================================================='
PRINT ''

-- ============================================================
-- 1. Procedure to Add Future Partitions
-- ============================================================
IF OBJECT_ID('dbo.sp_AddFuturePartitions', 'P') IS NOT NULL
    DROP PROCEDURE dbo.sp_AddFuturePartitions
GO

CREATE PROCEDURE dbo.sp_AddFuturePartitions
    @DatabaseName NVARCHAR(128),
    @PartitionFunctionName NVARCHAR(255),
    @PartitionSchemeName NVARCHAR(255),
    @PartitionColumn NVARCHAR(128),
    @PartitionInterval INT = 1,
    @NumberOfPartitions INT = 6,
    @IsDateColumn BIT = 1
AS
BEGIN
    SET NOCOUNT ON
    
    DECLARE @SQL NVARCHAR(MAX)
    DECLARE @MaxValue NVARCHAR(100)
    DECLARE @NewValue NVARCHAR(100)
    DECLARE @Counter INT = 0
    DECLARE @StartTime DATETIME2 = GETDATE()
    
    PRINT '===================================================='
    PRINT '🔄 Adding Future Partitions'
    PRINT '===================================================='
    PRINT '📊 Database: ' + @DatabaseName
    PRINT '📊 Function: ' + @PartitionFunctionName
    PRINT '📊 Scheme: ' + @PartitionSchemeName
    PRINT '📊 Number of partitions to add: ' + CAST(@NumberOfPartitions AS NVARCHAR)
    PRINT ''
    
    -- Get current max partition value
    SET @SQL = N'
    USE [' + @DatabaseName + N']
    
    SELECT value
    FROM sys.partition_range_values prv
    INNER JOIN sys.partition_functions pf ON prv.function_id = pf.function_id
    WHERE pf.name = ''' + @PartitionFunctionName + N'''
      AND prv.boundary_id = (
          SELECT MAX(boundary_id) 
          FROM sys.partition_range_values prv2
          WHERE prv2.function_id = prv.function_id
      )
    '
    
    CREATE TABLE #MaxValue (MaxValue NVARCHAR(100))
    INSERT INTO #MaxValue
    EXEC sp_executesql @SQL
    
    SELECT @MaxValue = MaxValue FROM #MaxValue
    DROP TABLE #MaxValue
    
    IF @MaxValue IS NULL
    BEGIN
        RAISERROR('❌ No partition values found for function %s', 16, 1, @PartitionFunctionName)
        RETURN
    END
    
    PRINT '📊 Current max value: ' + @MaxValue
    PRINT ''
    
    -- Add new partitions
    WHILE @Counter < @NumberOfPartitions
    BEGIN
        IF @IsDateColumn = 1
        BEGIN
            SET @NewValue = CONVERT(NVARCHAR, DATEADD(MONTH, @PartitionInterval, CAST(@MaxValue AS DATETIME2)), 23)
        END
        ELSE
        BEGIN
            SET @NewValue = CAST(CAST(@MaxValue AS BIGINT) + @PartitionInterval AS NVARCHAR)
        END
        
        SET @SQL = N'
        USE [' + @DatabaseName + N']
        
        ALTER PARTITION SCHEME ' + QUOTENAME(@PartitionSchemeName) + N'
        NEXT USED [PRIMARY]
        
        ALTER PARTITION FUNCTION ' + QUOTENAME(@PartitionFunctionName) + N'()
        SPLIT RANGE (''' + @NewValue + N''')
        '
        
        EXEC sp_executesql @SQL
        
        PRINT '✅ Added partition with boundary: ' + @NewValue
        
        SET @MaxValue = @NewValue
        SET @Counter = @Counter + 1
        
        -- Log the operation
        INSERT INTO dbo.PartitioningLog (
            DatabaseName, TableName, SchemaName, PartitionColumn,
            StepName, StepDescription, Status, AdditionalInfo
        ) VALUES (
            @DatabaseName, 'Manual', 'dbo', @PartitionColumn,
            'ADD_PARTITION', 'Added partition with boundary: ' + @NewValue, 
            'Success', 'Added ' + CAST(@Counter AS NVARCHAR) + ' of ' + CAST(@NumberOfPartitions AS NVARCHAR)
        )
    END
    
    PRINT ''
    PRINT '✅ Added ' + CAST(@NumberOfPartitions AS NVARCHAR) + ' partitions successfully!'
    PRINT '⏱️ Total time: ' + CAST(DATEDIFF(SECOND, @StartTime, GETDATE()) AS NVARCHAR) + ' seconds'
    PRINT '===================================================='
END
GO

PRINT '✅ sp_AddFuturePartitions created successfully!'
PRINT ''

-- ============================================================
-- 2. Procedure to Check Partition Health
-- ============================================================
IF OBJECT_ID('dbo.sp_CheckPartitionHealth', 'P') IS NOT NULL
    DROP PROCEDURE dbo.sp_CheckPartitionHealth
GO

CREATE PROCEDURE dbo.sp_CheckPartitionHealth
    @DatabaseName NVARCHAR(128),
    @TableName NVARCHAR(255),
    @SchemaName NVARCHAR(128) = 'dbo',
    @CheckIntegrity BIT = 0
AS
BEGIN
    SET NOCOUNT ON
    
    DECLARE @SQL NVARCHAR(MAX)
    DECLARE @PartitionCount INT = 0
    DECLARE @TotalRows BIGINT = 0
    
    PRINT '===================================================='
    PRINT '🔍 Partition Health Check'
    PRINT '===================================================='
    PRINT '📊 Database: ' + @DatabaseName
    PRINT '📊 Table: ' + @SchemaName + '.' + @TableName
    PRINT ''
    
    -- Check if table is partitioned
    SET @SQL = N'
    USE [' + @DatabaseName + N']
    
    SELECT 
        COUNT(DISTINCT partition_number) as PartitionCount,
        SUM(rows) as TotalRows
    FROM sys.partitions p
    INNER JOIN sys.tables t ON p.object_id = t.object_id
    INNER JOIN sys.schemas s ON t.schema_id = s.schema_id
    WHERE s.name = ''' + @SchemaName + N'''
      AND t.name = ''' + @TableName + N'''
      AND p.index_id = 1
    '
    
    CREATE TABLE #HealthStats (PartitionCount INT, TotalRows BIGINT)
    INSERT INTO #HealthStats
    EXEC sp_executesql @SQL
    
    SELECT @PartitionCount = PartitionCount, @TotalRows = TotalRows
    FROM #HealthStats
    DROP TABLE #HealthStats
    
    IF @PartitionCount = 0
    BEGIN
        PRINT '❌ Table is NOT partitioned!'
        RETURN
    END
    
    PRINT '✅ Table is partitioned'
    PRINT '📊 Number of partitions: ' + CAST(@PartitionCount AS NVARCHAR)
    PRINT '📊 Total rows: ' + CAST(@TotalRows AS NVARCHAR)
    PRINT ''
    
    -- Show partition details
    PRINT '📊 Partition Details:'
    PRINT '-------------------'
    
    SET @SQL = N'
    USE [' + @DatabaseName + N']
    
    SELECT 
        p.partition_number AS [Partition #],
        p.rows AS [Row Count],
        f.name AS [FileGroup],
        FORMAT(CAST(prv.value AS DATE), ''yyyy-MM-dd'') AS [Boundary Value],
        CASE 
            WHEN p.partition_number = 1 THEN ''⬅️ First''
            WHEN p.partition_number = (SELECT MAX(partition_number) FROM sys.partitions WHERE object_id = p.object_id) THEN ''➡️ Last''
            ELSE ''📌 Intermediate''
        END AS [Position],
        CAST(p.rows * 8.0 / 1024.0 / 1024.0 AS DECIMAL(18,2)) AS [Size GB]
    FROM sys.partitions p
    INNER JOIN sys.indexes i ON p.object_id = i.object_id AND p.index_id = i.index_id
    INNER JOIN sys.data_spaces d ON i.data_space_id = d.data_space_id
    INNER JOIN sys.filegroups f ON d.data_space_id = f.data_space_id
    LEFT JOIN sys.partition_range_values prv ON p.partition_number = prv.boundary_id
    WHERE OBJECT_NAME(p.object_id) = ''' + @TableName + N'''
      AND OBJECT_SCHEMA_NAME(p.object_id) = ''' + @SchemaName + N'''
      AND p.index_id = 1
    ORDER BY p.partition_number
    '
    
    EXEC sp_executesql @SQL
    
    PRINT ''
    
    -- Check for skew
    DECLARE @AvgRows BIGINT = @TotalRows / @PartitionCount
    DECLARE @MaxRows BIGINT
    
    SET @SQL = N'
    USE [' + @DatabaseName + N']
    
    SELECT MAX(rows) as MaxRows
    FROM sys.partitions p
    INNER JOIN sys.tables t ON p.object_id = t.object_id
    INNER JOIN sys.schemas s ON t.schema_id = s.schema_id
    WHERE s.name = ''' + @SchemaName + N'''
      AND t.name = ''' + @TableName + N'''
      AND p.index_id = 1
    '
    
    CREATE TABLE #MaxRows (MaxRows BIGINT)
    INSERT INTO #MaxRows
    EXEC sp_executesql @SQL
    
    SELECT @MaxRows = MaxRows FROM #MaxRows
    DROP TABLE #MaxRows
    
    IF @MaxRows > @AvgRows * 2
    BEGIN
        PRINT '⚠️ WARNING: Partition skew detected!'
        PRINT '   Avg rows per partition: ' + CAST(@AvgRows AS NVARCHAR)
        PRINT '   Max rows in partition: ' + CAST(@MaxRows AS NVARCHAR)
        PRINT '   Consider rebalancing partitions.'
    END
    ELSE
    BEGIN
        PRINT '✅ Partitions are well balanced'
        PRINT '   Avg rows per partition: ' + CAST(@AvgRows AS NVARCHAR)
        PRINT '   Max rows in partition: ' + CAST(@MaxRows AS NVARCHAR)
    END
    
    -- Check for future partitions
    IF @PartitionCount <= 2
    BEGIN
        PRINT '⚠️ WARNING: Very few partitions. Consider adding more.'
    END
    
    PRINT ''
    PRINT '===================================================='
END
GO

PRINT '✅ sp_CheckPartitionHealth created successfully!'
PRINT ''

-- ============================================================
-- 3. Procedure for Performance Report
-- ============================================================
IF OBJECT_ID('dbo.sp_PartitionPerformanceReport', 'P') IS NOT NULL
    DROP PROCEDURE dbo.sp_PartitionPerformanceReport
GO

CREATE PROCEDURE dbo.sp_PartitionPerformanceReport
    @DatabaseName NVARCHAR(128) = NULL,
    @StartDate DATETIME = NULL,
    @EndDate DATETIME = NULL
AS
BEGIN
    SET NOCOUNT ON
    
    IF @StartDate IS NULL SET @StartDate = DATEADD(DAY, -30, GETDATE())
    IF @EndDate IS NULL SET @EndDate = GETDATE()
    
    PRINT '===================================================='
    PRINT '📊 Partitioning Performance Report'
    PRINT '===================================================='
    PRINT '📅 Period: ' + CAST(@StartDate AS NVARCHAR) + ' to ' + CAST(@EndDate AS NVARCHAR)
    PRINT ''
    
    -- Summary statistics
    SELECT 
        CASE WHEN @DatabaseName IS NOT NULL THEN @DatabaseName ELSE 'All Databases' END AS DatabaseName,
        COUNT(*) AS TotalOperations,
        SUM(CASE WHEN Status = 'Success' THEN 1 ELSE 0 END) AS SuccessfulOps,
        SUM(CASE WHEN Status = 'Failed' THEN 1 ELSE 0 END) AS FailedOps,
        SUM(CASE WHEN Status = 'DryRunComplete' THEN 1 ELSE 0 END) AS DryRuns,
        AVG(DurationSeconds) AS AvgDurationSec,
        MAX(DurationSeconds) AS MaxDurationSec,
        MIN(DurationSeconds) AS MinDurationSec,
        COUNT(DISTINCT DatabaseName) AS DatabasesAffected,
        COUNT(DISTINCT TableName) AS TablesAffected
    FROM dbo.PartitioningLog
    WHERE StartTime BETWEEN @StartDate AND @EndDate
      AND (@DatabaseName IS NULL OR DatabaseName = @DatabaseName)
      AND StepName = 'START'
    
    PRINT ''
    PRINT '📊 Operations by Table:'
    PRINT '----------------------'
    
    SELECT TOP 20
        DatabaseName,
        TableName,
        COUNT(*) AS Operations,
        SUM(CASE WHEN Status = 'Success' THEN 1 ELSE 0 END) AS SuccessCount,
        SUM(CASE WHEN Status = 'Failed' THEN 1 ELSE 0 END) AS FailCount,
        AVG(DurationSeconds) AS AvgDuration,
        MAX(StartTime) AS LastOperation
    FROM dbo.PartitioningLog
    WHERE StartTime BETWEEN @StartDate AND @EndDate
      AND (@DatabaseName IS NULL OR DatabaseName = @DatabaseName)
      AND StepName = 'START'
    GROUP BY DatabaseName, TableName
    ORDER BY Operations DESC
    
    PRINT ''
    PRINT '📊 Recent Failures:'
    PRINT '-------------------'
    
    SELECT TOP 10
        DatabaseName,
        TableName,
        ErrorMessage,
        StartTime
    FROM dbo.PartitioningLog
    WHERE StartTime BETWEEN @StartDate AND @EndDate
      AND (@DatabaseName IS NULL OR DatabaseName = @DatabaseName)
      AND Status = 'Failed'
      AND ErrorMessage IS NOT NULL
    ORDER BY StartTime DESC
    
    PRINT ''
    PRINT '===================================================='
END
GO

PRINT '✅ sp_PartitionPerformanceReport created successfully!'
PRINT ''

-- ============================================================
-- 4. Procedure to Restore Foreign Keys
-- ============================================================
IF OBJECT_ID('dbo.sp_RestoreForeignKeys', 'P') IS NOT NULL
    DROP PROCEDURE dbo.sp_RestoreForeignKeys
GO

CREATE PROCEDURE dbo.sp_RestoreForeignKeys
    @DatabaseName NVARCHAR(128),
    @SchemaName NVARCHAR(128) = 'dbo',
    @TableName NVARCHAR(255)
AS
BEGIN
    SET NOCOUNT ON
    
    DECLARE @SQL NVARCHAR(MAX)
    DECLARE @FKName NVARCHAR(128)
    DECLARE @FKColumns NVARCHAR(MAX)
    DECLARE @RefTableName NVARCHAR(128)
    DECLARE @RefSchemaName NVARCHAR(128)
    DECLARE @RefColumns NVARCHAR(MAX)
    DECLARE @DeleteAction NVARCHAR(20)
    DECLARE @UpdateAction NVARCHAR(20)
    DECLARE @Counter INT = 0
    
    PRINT '===================================================='
    PRINT '🔗 Restoring Foreign Keys'
    PRINT '===================================================='
    PRINT '📊 Database: ' + @DatabaseName
    PRINT '📊 Table: ' + @SchemaName + '.' + @TableName
    PRINT ''
    
    -- Get foreign keys from original table
    SET @SQL = N'
    USE [' + @DatabaseName + N']
    
    SELECT 
        fk.name AS FKName,
        STUFF((
            SELECT '','' + QUOTENAME(c.name)
            FROM sys.foreign_key_columns fkc
            INNER JOIN sys.columns c ON fkc.parent_object_id = c.object_id 
                AND fkc.parent_column_id = c.column_id
            WHERE fkc.constraint_object_id = fk.object_id
            ORDER BY fkc.constraint_column_id
            FOR XML PATH('''')
        ), 1, 1, '''') AS Columns,
        rs.name AS RefSchemaName,
        rt.name AS RefTableName,
        STUFF((
            SELECT '','' + QUOTENAME(c.name)
            FROM sys.foreign_key_columns fkc
            INNER JOIN sys.columns c ON fkc.referenced_object_id = c.object_id 
                AND fkc.referenced_column_id = c.column_id
            WHERE fkc.constraint_object_id = fk.object_id
            ORDER BY fkc.constraint_column_id
            FOR XML PATH('''')
        ), 1, 1, '''') AS RefColumns,
        fk.delete_referential_action_desc AS DeleteAction,
        fk.update_referential_action_desc AS UpdateAction
    FROM sys.foreign_keys fk
    INNER JOIN sys.tables t ON fk.parent_object_id = t.object_id
    INNER JOIN sys.schemas s ON t.schema_id = s.schema_id
    INNER JOIN sys.tables rt ON fk.referenced_object_id = rt.object_id
    INNER JOIN sys.schemas rs ON rt.schema_id = rs.schema_id
    WHERE s.name = ''' + @SchemaName + N'''
      AND t.name = ''' + @TableName + N'''
    '
    
    CREATE TABLE #FKs (
        FKName NVARCHAR(128),
        Columns NVARCHAR(MAX),
        RefSchemaName NVARCHAR(128),
        RefTableName NVARCHAR(128),
        RefColumns NVARCHAR(MAX),
        DeleteAction NVARCHAR(20),
        UpdateAction NVARCHAR(20)
    )
    
    INSERT INTO #FKs
    EXEC sp_executesql @SQL
    
    DECLARE fk_cursor CURSOR FOR
    SELECT FKName, Columns, RefSchemaName, RefTableName, RefColumns, DeleteAction, UpdateAction
    FROM #FKs
    
    OPEN fk_cursor
    FETCH NEXT FROM fk_cursor INTO @FKName, @FKColumns, @RefSchemaName, @RefTableName, @RefColumns, @DeleteAction, @UpdateAction
    
    WHILE @@FETCH_STATUS = 0
    BEGIN
        SET @SQL = N'
        USE [' + @DatabaseName + N']
        
        ALTER TABLE ' + QUOTENAME(@SchemaName) + '.' + QUOTENAME(@TableName) + N'
        ADD CONSTRAINT ' + QUOTENAME(@FKName + '_Restored') + N'
        FOREIGN KEY (' + @FKColumns + N')
        REFERENCES ' + QUOTENAME(@RefSchemaName) + '.' + QUOTENAME(@RefTableName) + N'(' + @RefColumns + N')
        '
        
        IF @DeleteAction IS NOT NULL AND @DeleteAction <> 'NO_ACTION'
        BEGIN
            SET @SQL = @SQL + ' ON DELETE ' + @DeleteAction
        END
        
        IF @UpdateAction IS NOT NULL AND @UpdateAction <> 'NO_ACTION'
        BEGIN
            SET @SQL = @SQL + ' ON UPDATE ' + @UpdateAction
        END
        
        EXEC sp_executesql @SQL
        
        SET @Counter = @Counter + 1
        PRINT '✅ Restored foreign key: ' + @FKName
        
        FETCH NEXT FROM fk_cursor INTO @FKName, @FKColumns, @RefSchemaName, @RefTableName, @RefColumns, @DeleteAction, @UpdateAction
    END
    
    CLOSE fk_cursor
    DEALLOCATE fk_cursor
    DROP TABLE #FKs
    
    PRINT ''
    PRINT '✅ Restored ' + CAST(@Counter AS NVARCHAR) + ' foreign key(s) successfully!'
    PRINT '===================================================='
END
GO

PRINT '✅ sp_RestoreForeignKeys created successfully!'
PRINT ''

-- ============================================================
-- 5. Procedure to Validate Partition Setup
-- ============================================================
IF OBJECT_ID('dbo.sp_ValidatePartitionSetup', 'P') IS NOT NULL
    DROP PROCEDURE dbo.sp_ValidatePartitionSetup
GO

CREATE PROCEDURE dbo.sp_ValidatePartitionSetup
    @DatabaseName NVARCHAR(128),
    @TableName NVARCHAR(255),
    @SchemaName NVARCHAR(128) = 'dbo'
AS
BEGIN
    SET NOCOUNT ON
    
    DECLARE @SQL NVARCHAR(MAX)
    
    PRINT '===================================================='
    PRINT '✅ Validating Partition Setup'
    PRINT '===================================================='
    PRINT '📊 Database: ' + @DatabaseName
    PRINT '📊 Table: ' + @SchemaName + '.' + @TableName
    PRINT ''
    
    SET @SQL = N'
    USE [' + @DatabaseName + N']
    
    -- Check table exists and is partitioned
    SELECT 
        t.name AS TableName,
        s.name AS SchemaName,
        CASE 
            WHEN EXISTS (SELECT 1 FROM sys.partition_functions pf 
                         WHERE pf.name LIKE ''PF_%'' + t.name + ''%'') 
            THEN ''✅ Partitioned'' 
            ELSE ''❌ Not Partitioned'' 
        END AS PartitionStatus,
        CASE 
            WHEN EXISTS (SELECT 1 FROM sys.foreign_keys fk 
                         INNER JOIN sys.tables t2 ON fk.parent_object_id = t2.object_id
                         WHERE t2.name = t.name)
            THEN ''✅ Has Foreign Keys''
            ELSE ''ℹ️ No Foreign Keys''
        END AS ForeignKeyStatus,
        CASE 
            WHEN EXISTS (SELECT 1 FROM sys.default_constraints dc 
                         INNER JOIN sys.tables t2 ON dc.parent_object_id = t2.object_id
                         WHERE t2.name = t.name)
            THEN ''✅ Has Defaults''
            ELSE ''ℹ️ No Defaults''
        END AS DefaultStatus,
        CASE 
            WHEN EXISTS (SELECT 1 FROM sys.check_constraints cc 
                         INNER JOIN sys.tables t2 ON cc.parent_object_id = t2.object_id
                         WHERE t2.name = t.name)
            THEN ''✅ Has Check Constraints''
            ELSE ''ℹ️ No Check Constraints''
        END AS CheckConstraintStatus,
        CASE 
            WHEN EXISTS (SELECT 1 FROM sys.indexes i 
                         WHERE i.object_id = t.object_id 
                         AND i.index_id > 0 
                         AND i.is_primary_key = 0)
            THEN ''✅ Has Non-Clustered Indexes''
            ELSE ''ℹ️ No Non-Clustered Indexes''
        END AS IndexStatus
    FROM sys.tables t
    INNER JOIN sys.schemas s ON t.schema_id = s.schema_id
    WHERE s.name = ''' + @SchemaName + N'''
      AND t.name = ''' + @TableName + N'''
    
    -- Show partition information
    SELECT 
        p.partition_number AS [Partition #],
        p.rows AS [Row Count],
        f.name AS [FileGroup],
        CAST(prv.value AS NVARCHAR) AS [Boundary Value],
        CASE 
            WHEN p.partition_number = 1 THEN ''⬅️ First''
            WHEN p.partition_number = (SELECT MAX(partition_number) FROM sys.partitions WHERE object_id = p.object_id) THEN ''➡️ Last''
            ELSE ''📌 Intermediate''
        END AS [Position]
    FROM sys.partitions p
    INNER JOIN sys.indexes i ON p.object_id = i.object_id AND p.index_id = i.index_id
    INNER JOIN sys.data_spaces d ON i.data_space_id = d.data_space_id
    INNER JOIN sys.filegroups f ON d.data_space_id = f.data_space_id
    LEFT JOIN sys.partition_range_values prv ON p.partition_number = prv.boundary_id
    WHERE OBJECT_NAME(p.object_id) = ''' + @TableName + N'''
      AND OBJECT_SCHEMA_NAME(p.object_id) = ''' + @SchemaName + N'''
      AND p.index_id = 1
    ORDER BY p.partition_number
    '
    
    EXEC sp_executesql @SQL
    
    PRINT ''
    PRINT '✅ Validation complete!'
    PRINT '===================================================='
END
GO

PRINT '✅ sp_ValidatePartitionSetup created successfully!'
PRINT ''

-- ============================================================
-- 6. Procedure to Get Dry Run Results
-- ============================================================
IF OBJECT_ID('dbo.sp_GetDryRunResults', 'P') IS NOT NULL
    DROP PROCEDURE dbo.sp_GetDryRunResults
GO

CREATE PROCEDURE dbo.sp_GetDryRunResults
    @ExecutionID UNIQUEIDENTIFIER,
    @Format NVARCHAR(20) = 'TABLE' -- TABLE, XML, JSON
AS
BEGIN
    SET NOCOUNT ON
    
    PRINT '===================================================='
    PRINT '🔬 Dry Run Results'
    PRINT '===================================================='
    PRINT '📊 Execution ID: ' + CAST(@ExecutionID AS NVARCHAR)
    PRINT ''
    
    IF @Format = 'XML'
    BEGIN
        SELECT 
            (SELECT 
                ResultID,
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
                ResultID,
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
            StepOrder AS [#],
            StepName AS [Step Name],
            StepDescription AS [Description],
            EstimatedDurationSeconds AS [Est Dur (sec)],
            EstimatedRowCount AS [Est Rows],
            LEFT(SQLToExecute, 100) AS [SQL Preview],
            Warnings,
            Status,
            CreatedDate AS [Created]
        FROM dbo.DryRunResults 
        WHERE ExecutionID = @ExecutionID
        ORDER BY StepOrder
    END
    
    -- Summary
    SELECT 
        COUNT(*) AS TotalSteps,
        SUM(EstimatedDurationSeconds) AS TotalEstimatedSeconds,
        SUM(EstimatedDurationSeconds) / 60 AS TotalEstimatedMinutes,
        COUNT(CASE WHEN Status = 'Warning' THEN 1 END) AS WarningCount,
        COUNT(CASE WHEN Status = 'Failed' THEN 1 END) AS FailedCount,
        MAX(CreatedDate) AS RunDate
    FROM dbo.DryRunResults
    WHERE ExecutionID = @ExecutionID
    
    PRINT ''
    PRINT '===================================================='
END
GO

PRINT '✅ sp_GetDryRunResults created successfully!'
PRINT ''

PRINT '===================================================='
PRINT '✅ All helper procedures created successfully!'
PRINT '🛠️ Procedures created:'
PRINT '   - sp_AddFuturePartitions'
PRINT '   - sp_CheckPartitionHealth'
PRINT '   - sp_PartitionPerformanceReport'
PRINT '   - sp_RestoreForeignKeys'
PRINT '   - sp_ValidatePartitionSetup'
PRINT '   - sp_GetDryRunResults'
PRINT '===================================================='
GO