-- Example 1: Basic Dry Run
EXEC DBADB.dbo.sp_ConvertToPartitionedTable
    @DatabaseName = 'SalesDB',
    @TableName = 'Orders',
    @PartitionColumn = 'OrderDate',
    @DryRun = 1
GO

-- Example 2: Dry Run with All Options
EXEC DBADB.dbo.sp_ConvertToPartitionedTable
    @DatabaseName = 'SalesDB',
    @SchemaName = 'Sales',
    @TableName = 'OrderDetails',
    @PartitionColumn = 'OrderDate',
    @PartitionRangeType = 'RANGE RIGHT',
    @PartitionInterval = 3,
    @NumberOfExistingPartitions = 24,
    @FuturePartitionsAhead = 12,
    @ScheduleFuturePartitions = 1,
    @PreserveForeignKeys = 1,
    @PreserveDefaults = 1,
    @PreserveCheckConstraints = 1,
    @PreserveExtendedProperties = 1,
    @DryRun = 1,
    @DryRunOutputFormat = 'TABLE' -- TABLE, XML, JSON
GO

-- Example 3: Get Dry Run Results
DECLARE @ExecutionID UNIQUEIDENTIFIER = 'your-execution-id-here'
EXEC DBADB.dbo.sp_GetDryRunResults
    @ExecutionID = @ExecutionID,
    @Format = 'TABLE'
GO

-- Example 4: Review Specific Step Details
SELECT 
    StepOrder,
    StepName,
    StepDescription,
    SQLToExecute,
    Warnings
FROM dbo.DryRunResults
WHERE ExecutionID = 'your-execution-id-here'
  AND StepName LIKE '%VALIDATE%'
ORDER BY StepOrder
GO

-- Example 5: Get Estimated Duration Summary
SELECT 
    COUNT(*) AS TotalSteps,
    SUM(EstimatedDurationSeconds) AS TotalEstimatedDurationSeconds,
    SUM(EstimatedRowCount) AS TotalEstimatedRows,
    COUNT(CASE WHEN Warnings IS NOT NULL AND Warnings <> '' THEN 1 END) AS WarningCount
FROM dbo.DryRunResults
WHERE ExecutionID = 'your-execution-id-here'
GO

-- Example 6: Execute After Successful Dry Run
-- Run dry run first
EXEC DBADB.dbo.sp_ConvertToPartitionedTable
    @DatabaseName = 'SalesDB',
    @TableName = 'Orders',
    @PartitionColumn = 'OrderDate',
    @DryRun = 1

-- Review results, then execute actual
EXEC DBADB.dbo.sp_ConvertToPartitionedTable
    @DatabaseName = 'SalesDB',
    @TableName = 'Orders',
    @PartitionColumn = 'OrderDate',
    @DryRun = 0
GO

-- Example 7: XML Output
EXEC DBADB.dbo.sp_ConvertToPartitionedTable
    @DatabaseName = 'SalesDB',
    @TableName = 'Orders',
    @PartitionColumn = 'OrderDate',
    @DryRun = 1,
    @DryRunOutputFormat = 'XML'
GO

-- Example 8: JSON Output
EXEC DBADB.dbo.sp_ConvertToPartitionedTable
    @DatabaseName = 'SalesDB',
    @TableName = 'Orders',
    @PartitionColumn = 'OrderDate',
    @DryRun = 1,
    @DryRunOutputFormat = 'JSON'
GO
