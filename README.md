## Dry Run Mode

### Overview
The procedure includes a comprehensive dry-run mode that allows you to preview all steps, estimated durations, and potential issues before executing the actual partitioning process.

### How Dry Run Works

1. **Step-by-Step Preview**: Shows every step that will be executed
2. **Estimated Duration**: Provides time estimates based on table size
3. **SQL Preview**: Shows the actual SQL that will be executed
4. **Issue Detection**: Identifies potential problems before they occur
5. **Resource Estimation**: Estimates row counts and batch sizes
6. **Multiple Output Formats**: TABLE, XML, or JSON

### Dry Run Parameters

| Parameter | Description | Options |
|-----------|-------------|---------|
| @DryRun | Enable dry run mode | 0 (Actual) or 1 (Dry Run) |
| @DryRunOutputFormat | Output format | TABLE, XML, JSON |

### Dry Run Output

The dry run results are stored in the `dbo.DryRunResults` table with the following columns:
- ExecutionID: Unique identifier for the dry run session
- StepOrder: Order of execution
- StepName: Name of the step
- StepDescription: Detailed description
- EstimatedDurationSeconds: Estimated time for this step
- EstimatedRowCount: Estimated rows affected
- SQLToExecute: The SQL that would be executed
- Prerequisites: Required conditions
- Warnings: Potential issues detected
- Status: Success, Warning, or Failed
- CreatedDate: Timestamp

### Using Dry Run Effectively

#### 1. Validate Before Execution
Always run a dry run first to understand what will happen:

```sql
EXEC DBADB.dbo.sp_ConvertToPartitionedTable
    @DatabaseName = 'SalesDB',
    @TableName = 'Orders',
    @PartitionColumn = 'OrderDate',
    @DryRun = 1;
```

## Estimate Total Duration
- Get overall time estimate:

```sql
SELECT 
    SUM(EstimatedDurationSeconds) AS TotalEstimatedSeconds,
    SUM(EstimatedDurationSeconds) / 60 AS TotalEstimatedMinutes,
    COUNT(*) AS TotalSteps,
    COUNT(CASE WHEN Warnings IS NOT NULL AND Warnings <> '' THEN 1 END) AS WarningCount
FROM dbo.DryRunResults
WHERE ExecutionID = 'your-execution-id'
```
5. View SQL to be Executed
Preview the actual SQL statements:

```sql

SELECT 
    StepName,
    SQLToExecute
FROM dbo.DryRunResults
WHERE ExecutionID = 'your-execution-id'
  AND SQLToExecute IS NOT NULL
ORDER BY StepOrder;
```
6. Export to XML or JSON
For integration with other tools:

```sql

-- XML Output
EXEC DBADB.dbo.sp_ConvertToPartitionedTable
    @DatabaseName = 'SalesDB',
    @TableName = 'Orders',
    @PartitionColumn = 'OrderDate',
    @DryRun = 1,
    @DryRunOutputFormat = 'XML'
```
-- JSON Output

```sql
EXEC DBADB.dbo.sp_ConvertToPartitionedTable
    @DatabaseName = 'SalesDB',
    @TableName = 'Orders',
    @PartitionColumn = 'OrderDate',
    @DryRun = 1,
    @DryRunOutputFormat = 'JSON'
```

Best Practices for Dry Run
Always Run First: Run dry run before actual execution

Review All Steps: Don't skip reviewing each step

Check Warnings: Address all warnings before proceeding

Estimate Time: Plan for the estimated duration

Test in Staging: Use staging environment first

Save Results: Keep dry run results for reference

Compare Versions: Run dry runs after any parameter changes

Common Dry Run Scenarios
Scenario 1: Large Table with Many Constraints

```sql
-- Dry run to assess complexity
EXEC DBADB.dbo.sp_ConvertToPartitionedTable
    @DatabaseName = 'SalesDB',
    @TableName = 'LargeOrders',
    @PartitionColumn = 'OrderDate',
    @NumberOfExistingPartitions = 24,
    @PreserveForeignKeys = 1,
    @DryRun = 1
```
-- Check for foreign key complexity
```sql
SELECT COUNT(*) as FKCount
FROM dbo.DryRunResults
WHERE ExecutionID = 'your-execution-id'
  AND StepName LIKE '%FOREIGN_KEY%'
```
Scenario 2: Performance Critical Table

```sql
-- Dry run to estimate impact
EXEC DBADB.dbo.sp_ConvertToPartitionedTable
    @DatabaseName = 'SalesDB',
    @TableName = 'TransactionLog',
    @PartitionColumn = 'CreatedDate',
    @BatchSize = 50000,
    @DryRun = 1
```
-- Get performance estimates

```sql
SELECT 
    StepName,
    EstimatedDurationSeconds,
    EstimatedRowCount
FROM dbo.DryRunResults
WHERE ExecutionID = 'your-execution-id'
ORDER BY EstimatedDurationSeconds DESC
```
--- Scenario 3: Comparison of Different Configurations

```sql
-- Run dry run with different partition intervals
-- Configuration 1: Monthly
EXEC DBADB.dbo.sp_ConvertToPartitionedTable
    @DatabaseName = 'SalesDB',
    @TableName = 'Orders',
    @PartitionColumn = 'OrderDate',
    @PartitionInterval = 1,
    @DryRun = 1
```
-- Configuration 2: Quarterly
``` sql
EXEC DBADB.dbo.sp_ConvertToPartitionedTable
    @DatabaseName = 'SalesDB',
    @TableName = 'Orders',
    @PartitionColumn = 'OrderDate',
    @PartitionInterval = 3,
    @DryRun = 1;
```

Key Capabilities
Complete Preview: Shows every step before execution
Time Estimation: Provides duration estimates based on data size
SQL Preview: Displays actual SQL that will be executed
Warning Detection: Identifies potential issues
Multiple Output Formats: TABLE, XML, JSON
Persistent Results: Stores results for later review
Comparison Tools: Compare dry run estimates with actual execution

Benefits
Risk Reduction: Understand impact before making changes
Planning: Better resource and time planning
Validation: Verify approach before execution
Documentation: Record of expected outcomes
Troubleshooting: Identify issues early
Education: Learn about the partitioning process

Use Cases
Production Migration: Validate before making changes
Performance Testing: Estimate time and resources
Configuration Testing: Compare different approaches
Audit Trail: Document planned changes
Team Review: Share plans with team members
Capacity Planning: Estimate resource requirements
