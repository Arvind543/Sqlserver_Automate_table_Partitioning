# Dry Run Mode

## Table of Contents
- [Quick Start](#quick-start)
- [Dry Run Parameters](#dry-run-parameters)
- [Quick Queries](#quick-queries)
- [Best Practices](#best-practices)
- [Scenarios](#scenarios)

## Quick Start
A concise guide to preview and validate partitioning operations before executing them.

1. Run a dry run to preview steps and SQL without making changes:

```sql
EXEC DBADB.dbo.sp_ConvertToPartitionedTable
    @DatabaseName = 'SalesDB',
    @TableName = 'Orders',
    @PartitionColumn = 'OrderDate',
    @DryRun = 1;
```

2. View the generated SQL for review:

```sql
SELECT
    StepName,
    SQLToExecute
FROM dbo.DryRunResults
WHERE ExecutionID = 'your-execution-id'
  AND SQLToExecute IS NOT NULL
ORDER BY StepOrder;
```

3. Get an overall time estimate:

```sql
SELECT
    SUM(EstimatedDurationSeconds) AS TotalEstimatedSeconds,
    SUM(EstimatedDurationSeconds) / 60 AS TotalEstimatedMinutes,
    COUNT(*) AS TotalSteps,
    COUNT(CASE WHEN Warnings IS NOT NULL AND Warnings <> '' THEN 1 END) AS WarningCount
FROM dbo.DryRunResults
WHERE ExecutionID = 'your-execution-id';
```

4. Export dry run results as XML/JSON if needed:

```sql
-- XML
EXEC DBADB.dbo.sp_ConvertToPartitionedTable
    @DatabaseName = 'SalesDB',
    @TableName = 'Orders',
    @PartitionColumn = 'OrderDate',
    @DryRun = 1,
    @DryRunOutputFormat = 'XML';

-- JSON
EXEC DBADB.dbo.sp_ConvertToPartitionedTable
    @DatabaseName = 'SalesDB',
    @TableName = 'Orders',
    @PartitionColumn = 'OrderDate',
    @DryRun = 1,
    @DryRunOutputFormat = 'JSON';
```

## Dry Run Parameters
- @DryRun: 0 = actual run, 1 = dry run
- @DryRunOutputFormat: TABLE, XML, JSON

## Quick Queries
- Check warnings count:

```sql
SELECT COUNT(*) AS WarningCount
FROM dbo.DryRunResults
WHERE ExecutionID = 'your-execution-id'
  AND Warnings IS NOT NULL
  AND Warnings <> '';
```

- Check foreign-key related steps:

```sql
SELECT COUNT(*) AS FKCount
FROM dbo.DryRunResults
WHERE ExecutionID = 'your-execution-id'
  AND StepName LIKE '%FOREIGN_KEY%';
```

## Best Practices
- Always run a dry run first.
- Review all generated SQL before executing.
- Address warnings and test in staging.
- Save dry run results for audit and planning.

## Scenarios (Examples)
- Large table with many constraints:

```sql
EXEC DBADB.dbo.sp_ConvertToPartitionedTable
    @DatabaseName = 'SalesDB',
    @TableName = 'LargeOrders',
    @PartitionColumn = 'OrderDate',
    @NumberOfExistingPartitions = 24,
    @PreserveForeignKeys = 1,
    @DryRun = 1;
```

- Performance-critical table with batch sizing:

```sql
EXEC DBADB.dbo.sp_ConvertToPartitionedTable
    @DatabaseName = 'SalesDB',
    @TableName = 'TransactionLog',
    @PartitionColumn = 'CreatedDate',
    @BatchSize = 50000,
    @DryRun = 1;
```

---

If you want, I can also add a short "Full Reference" section below the quick-start that preserves the original longer explanations and the full list of DryRunResult columns. Say the word and I will append it in the next commit.