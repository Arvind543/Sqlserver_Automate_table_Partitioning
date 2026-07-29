# 🚀 SQL Server Advanced Partitioning Management System

## Complete Table Partitioning Solution with Dry-Run Support

---

## 📋 Table of Contents

1. [Overview](#-overview)
2. [Features](#-features)
3. [System Requirements](#-system-requirements)
4. [Installation Guide](#-installation-guide)
5. [Configuration](#-configuration)
6. [Usage Guide](#-usage-guide)
7. [Examples (see MainPage.txt for more)](#-examples)
8. [Dry Run Mode](#-dry-run-mode)
9. [Monitoring](#-monitoring)
10. [Maintenance](#-maintenance)
11. [Troubleshooting](#-troubleshooting)
12. [Security](#-security)
13. [Best Practices](#-best-practices)
14. [Performance Tips](#-performance-tips)
15. [FAQ](#-faq)

---

## 📖 Overview

The **SQL Server Advanced Partitioning Management System** is a comprehensive solution to automate converting existing tables to partitioned tables while preserving schema and minimizing downtime. It provides a dry-run preview mode, progress tracking, monitoring, automated maintenance jobs, and performance reporting.

Key capabilities:

- ✅ Full schema preservation: foreign keys, defaults, check constraints, indexes, and extended properties
- 🔬 Dry Run Mode: preview all operations without making changes
- 📊 Monitoring & alerting: views, procedures, and logs for tracking operations
- 🔧 Automated maintenance: SQL Agent jobs for future partition management
- 📈 Performance reporting and health checks

---

## ✨ Features

- 🎯 Automatic partition conversion for tables of any size
- 🧠 Intelligent partitioning: detects date/time vs integer partition columns
- 🔗 Handles inbound/outbound foreign keys and preserves constraints
- 🔬 Dry run and analysis tools to validate operations before execution
- 📊 Detailed logging and progress tracking
- 🤖 Automated SQL Agent job creation for future partitions
- ⚡ Configurable parallelism, batch sizes, and index handling options

---

## 💻 System Requirements

| Component | Requirement |
|-----------|-------------|
| SQL Server | 2012 or higher (2019 recommended) |
| Edition | Enterprise, Developer, or Standard (with partitioning support) |
| SQL Agent | Running for automated jobs |
| Memory | Minimum 4GB (8GB+ recommended for large tables) |
| Disk Space | At least 2x the size of the largest table during migration |
| Permissions | Sysadmin or equivalent for installation and execution |

---

## 📥 Installation Guide

### Step 1: Files in this package

Execute these scripts (order matters):

- `01_Create_DBADB_Database.sql`
- `02_Create_Partitioning_Tables.sql`
- `03_Main_Partitioning_Procedure.sql`
- `04_Helper_Procedures.sql`
- `05_User_Grants_Permissions.sql`
- `06_Test_Examples.sql`
- `07_DryRun_Helper_Functions.sql`
- `08_Monitoring_Queries.sql`
- `09_Maintenance_Procedures.sql`
- `10_Complete_Deployment.sql`

### Step 2: Execute Deployment

Method 1: run the combined deployment script

```sql
:r 10_Complete_Deployment.sql
```

Method 2: run files individually in order using SQLCMD or SSMS

```sql
:r 01_Create_DBADB_Database.sql
:r 02_Create_Partitioning_Tables.sql
:r 03_Main_Partitioning_Procedure.sql
:r 04_Helper_Procedures.sql
:r 05_User_Grants_Permissions.sql
:r 06_Test_Examples.sql
:r 07_DryRun_Helper_Functions.sql
:r 08_Monitoring_Queries.sql
:r 09_Maintenance_Procedures.sql
```

---

## ⚙️ Configuration

- After deployment, ensure the DBADB database exists and SQL Agent is running.
- Grant required roles (PartitionAdminRole, PartitionMonitorRole) to appropriate logins.
- Configure any environment-specific settings in the helper procedures (filegroup names, default filegroups, job schedules).

---

## 📌 Usage Guide

The main entrypoint is the stored procedure `DBADB.dbo.sp_ConvertToPartitionedTable`.

Basic usage (recommended: perform a dry run first):

1) Dry run (preview):

```sql
EXEC DBADB.dbo.sp_ConvertToPartitionedTable
    @DatabaseName = 'YourDatabase',
    @TableName = 'YourTable',
    @PartitionColumn = 'YourColumn',
    @DryRun = 1
```

2) Review dry run results (get the ExecutionID from dry run output):

```sql
DECLARE @ExecutionID UNIQUEIDENTIFIER = 'your-execution-id'
EXEC DBADB.dbo.sp_GetDryRunResults
    @ExecutionID = @ExecutionID,
    @Format = 'TABLE'
```

3) Execute actual partitioning after review:

```sql
EXEC DBADB.dbo.sp_ConvertToPartitionedTable
    @DatabaseName = 'YourDatabase',
    @TableName = 'YourTable',
    @PartitionColumn = 'YourColumn',
    @DryRun = 0
```

See the Examples section below for more complete invocations. The attached file MainPage.txt in this repository contains extensive examples and guidance — refer to it for full scenarios and sample parameter sets.

---

## 📝 Examples

Refer also to MainPage.txt (root of repo) for all example invocations. Below are selected examples copied from MainPage.txt.

Example 1: Monthly Partitioning for Large Sales Table

```sql
EXEC DBADB.dbo.sp_ConvertToPartitionedTable
    @DatabaseName = 'SalesDB',
    @SchemaName = 'dbo',
    @TableName = 'SalesData',
    @PartitionColumn = 'SaleDate',
    @PartitionRangeType = 'RANGE RIGHT',
    @PartitionInterval = 1,          -- Monthly partitions
    @NumberOfExistingPartitions = 24, -- 2 years of data
    @FuturePartitionsAhead = 12,     -- 1 year of future partitions
    @ScheduleFuturePartitions = 1,
    @JobScheduleTime = '02:00:00',
    @JobScheduleFrequency = 'Monthly',
    @PreserveForeignKeys = 1,
    @PreserveDefaults = 1,
    @PreserveCheckConstraints = 1,
    @PreserveExtendedProperties = 1,
    @BatchSize = 50000,
    @DryRun = 0
```

Example 2: Integer-Based Partitioning for Transaction Log

```sql
EXEC DBADB.dbo.sp_ConvertToPartitionedTable
    @DatabaseName = 'LogDB',
    @SchemaName = 'dbo',
    @TableName = 'TransactionLog',
    @PartitionColumn = 'TransactionID',
    @PartitionRangeType = 'RANGE RIGHT',
    @NumberOfExistingPartitions = 100,
    @FuturePartitionsAhead = 50,
    @ScheduleFuturePartitions = 1,
    @JobScheduleTime = '03:00:00',
    @JobScheduleFrequency = 'Daily',
    @BatchSize = 100000,
    @DryRun = 0
```

Example 3: Quarterly Partitioning with All Options

```sql
EXEC DBADB.dbo.sp_ConvertToPartitionedTable
    @DatabaseName = 'AnalyticsDB',
    @SchemaName = 'Analytics',
    @TableName = 'HistoricalData',
    @PartitionColumn = 'EventDate',
    @PartitionRangeType = 'RANGE RIGHT',
    @PartitionInterval = 3,          -- Quarterly
    @NumberOfExistingPartitions = 20, -- 5 years
    @FuturePartitionsAhead = 8,      -- 2 years
    @ScheduleFuturePartitions = 1,
    @JobScheduleTime = '01:00:00',
    @JobScheduleFrequency = 'Quarterly',
    @MaxParallelism = 8,
    @CreateIndexesOnPartitions = 1,
    @DropExistingIndexes = 0,        -- Keep indexes during migration
    @BatchSize = 25000,
    @SwitchToNewTable = 1,
    @PreserveForeignKeys = 1,
    @PreserveDefaults = 1,
    @PreserveCheckConstraints = 1,
    @PreserveTriggers = 1,
    @PreserveExtendedProperties = 1,
    @KeepOriginalTable = 0,
    @DryRun = 0
```

---

## 🔬 Dry Run Mode

What is Dry Run?

Dry Run is a preview mode that shows exactly what will happen during partitioning without making changes. Use it to validate approach, estimate time and resources, and identify potential issues.

Typical dry-run workflow:

```sql
-- Run dry run
EXEC DBADB.dbo.sp_ConvertToPartitionedTable
    @DatabaseName = 'SalesDB',
    @TableName = 'SalesData',
    @PartitionColumn = 'SaleDate',
    @DryRun = 1,
    @DryRunOutputFormat = 'TABLE'

-- Get results
EXEC DBADB.dbo.sp_GetDryRunResults
    @ExecutionID = 'your-execution-id',
    @Format = 'TABLE'

-- Analyze dry run
EXEC DBADB.dbo.sp_AnalyzeDryRun
    @ExecutionID = 'your-execution-id'
```

Dry run output columns include: StepOrder, StepName, StepDescription, EstimatedDurationSeconds, EstimatedRowCount, SQLToExecute, Warnings.

Output formats supported: TABLE (human-readable), XML, JSON.

---

## 📊 Monitoring

View current operations and recent operations:

```sql
SELECT * FROM DBADB.dbo.vw_CurrentOperations
SELECT * FROM DBADB.dbo.vw_RecentOperations
```

Monitoring procedures:

```sql
EXEC DBADB.dbo.sp_MonitorPartitionOperations
    @DatabaseName = 'SalesDB',
    @Status = 'Running',
    @HoursBack = 24

EXEC DBADB.dbo.sp_CheckPartitionAlerts
    @CheckMinutes = 60,
    @FailureThreshold = 3

EXEC DBADB.dbo.sp_PartitionPerformanceReport
    @DatabaseName = 'SalesDB',
    @StartDate = '2024-01-01',
    @EndDate = '2024-12-31'
```

Health checks:

```sql
EXEC DBADB.dbo.sp_CheckPartitionHealth
    @DatabaseName = 'SalesDB',
    @TableName = 'SalesData',
    @CheckIntegrity = 1

EXEC DBADB.dbo.sp_ValidatePartitionSetup
    @DatabaseName = 'SalesDB',
    @TableName = 'SalesData'
```

---

## 🔧 Maintenance

Archive old logs:

```sql
EXEC DBADB.dbo.sp_ArchivePartitionLogs
    @RetentionDays = 90,
    @BatchSize = 10000,
    @DryRun = 0
```

Update statistics:

```sql
EXEC DBADB.dbo.sp_UpdatePartitionStats
    @DatabaseName = 'SalesDB',
    @TableName = 'SalesData',
    @FullScan = 1

-- or for all tables
EXEC DBADB.dbo.sp_UpdatePartitionStats
    @DatabaseName = 'SalesDB',
    @FullScan = 0
```

Generate maintenance report:

```sql
EXEC DBADB.dbo.sp_GenerateMaintenanceReport
    @DaysBack = 30
```

Clean up failed operations:

```sql
EXEC DBADB.dbo.sp_CleanupFailedOperations
    @HoursBack = 24,
    @DryRun = 0
```

---

## 🐛 Troubleshooting

Common issues & solutions (short):

- Permission Denied: grant required permissions (see Security section)
- Out of Disk Space: free space or use larger filegroup
- Long Running Operations: reduce batch size or run during maintenance window
- Foreign Key Issues: use sp_RestoreForeignKeys
- NULL Values in Partition Column: update or filter NULLs
- Duplicate Partition Values: choose a different partition column

Error log queries:

```sql
SELECT * FROM DBADB.dbo.vw_ErrorSummary

SELECT * FROM dbo.PartitioningErrorLog
WHERE ErrorDate >= DATEADD(HOUR, -24, GETDATE())
ORDER BY ErrorDate DESC

-- Detailed error join
SELECT 
    pl.DatabaseName,
    pl.TableName,
    pl.StepName,
    el.ErrorNumber,
    el.ErrorSeverity,
    el.ErrorMessage,
    el.ErrorDate
FROM DBADB.dbo.PartitioningErrorLog el
INNER JOIN DBADB.dbo.PartitioningLog pl ON el.LogID = pl.LogID
WHERE el.ErrorDate >= DATEADD(DAY, -7, GETDATE())
ORDER BY el.ErrorDate DESC
```

Performance issue queries:

```sql
SELECT 
    DatabaseName,
    TableName,
    StepName,
    DurationSeconds,
    StartTime
FROM DBADB.dbo.PartitioningLog
WHERE DurationSeconds > 300  -- Operations taking > 5 minutes
  AND Status = 'Success'
ORDER BY DurationSeconds DESC

SELECT 
    DatabaseName,
    TableName,
    COUNT(*) AS Failures,
    MAX(StartTime) AS LastFailure
FROM DBADB.dbo.PartitioningLog
WHERE Status = 'Failed'
GROUP BY DatabaseName, TableName
HAVING COUNT(*) > 3
ORDER BY Failures DESC
```

---

## 🔐 Security

Required permissions:

- ALTER (Database)
- CREATE TABLE (Database)
- CREATE FUNCTION (Database)
- REFERENCES (Schema)
- VIEW DEFINITION (Schema)
- SELECT, INSERT, UPDATE, DELETE (Table)
- VIEW SERVER STATE (Server)
- EXECUTE on msdb procedures (to create SQL Agent jobs)

Best practices:

- Use Windows Authentication where possible
- Implement Role-Based Access (PartitionAdminRole, PartitionMonitorRole)
- Principle of Least Privilege
- Regular audits of partition operations
- Encrypt sensitive data in logs

Grant sample users and roles:

```sql
CREATE LOGIN PartitionAdmin WITH PASSWORD = 'StrongPassword!'
CREATE USER PartitionAdmin FOR LOGIN PartitionAdmin
EXEC sp_addrolemember 'PartitionAdminRole', 'PartitionAdmin'

CREATE LOGIN PartitionMonitor WITH PASSWORD = 'StrongPassword!'
CREATE USER PartitionMonitor FOR LOGIN PartitionMonitor
EXEC sp_addrolemember 'PartitionMonitorRole', 'PartitionMonitor'
```

---

## 💡 Best Practices

DO:
- Always run a dry run first before executing on production
- Test with a small dataset to validate the process
- Schedule operations during off-peak hours
- Monitor the transaction log during the operation
- Keep the original table until verification is complete
- Document all partition operations
- Regularly review partition health and performance

DON'T:
- Skip dry run on production systems
- Ignore warning messages from dry run
- Underestimate execution time for large tables
- Forget to update statistics after partitioning
- Run without proper backups in place
- Overlook foreign key relationships
- Use too large batch sizes for very large tables

---

## 📈 Performance Tips

Optimizing data movement (recommended batch sizes):

| Scenario | Recommended Batch Size |
|---|---|
| < 1 million rows | 50,000 - 100,000 |
| 1-10 million rows | 25,000 - 50,000 |
| > 10 million rows | 10,000 - 25,000 |

Index management tips:
- Create indexes AFTER data movement for better performance
- Use CREATE INDEX WITH (ONLINE = ON) when supported to minimize blocking
- Consider dropping non-critical indexes before the operation and rebuild after

Partition strategy guidance:

| Data Volume | Partition Interval Recommendation |
|---|---|
| < 1 million rows/month | Monthly (12-24 partitions) |
| 1-5 million rows/month | Monthly (24-36 partitions) |
| > 5 million rows/month | Weekly (52+ partitions) |

---

## ❓ FAQ

Q1: What happens to my data during partitioning?
A1: Data is moved to the new partitioned table. The original table is preserved if @KeepOriginalTable = 1.

Q2: Can I stop the process once started?
A2: Yes, but stopping may leave the database in an inconsistent state. Recommended to let it finish or restore from backup.

Q3: How long will partitioning take?
A3: Depends on table size, indexes, and hardware. Use dry run for estimates.

Q4: Will my application be affected?
A4: The table is unavailable during the final switch — schedule during maintenance windows.

Q5: Can I partition an already partitioned table?
A5: Yes. Prefer using sp_AddFuturePartitions to add partitions when possible.

Q6: What backup should I take before partitioning?
A6: Take a full database backup and transaction log backup.

Q7: Can I rollback a partition operation?
A7: Yes, by restoring the backup or using the original table if preserved.

Q8: How do I know if my table is partitioned?
A8: Use sp_CheckPartitionHealth or sp_ValidatePartitionSetup to verify.

Q9: What if I have multiple foreign keys?
A9: The system preserves foreign keys when @PreserveForeignKeys = 1.

Q10: Can I schedule partition creation automatically?
A10: Yes. The system can create SQL Agent jobs for future partitions.

---

## 📚 Additional Resources
