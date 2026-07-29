-- ============================================================
-- File: 06_Test_Examples.sql
-- Description: Test examples for the partitioning system
-- ============================================================

USE DBADB
GO

PRINT '===================================================='
PRINT '🧪 Test Examples'
PRINT '===================================================='
PRINT ''

-- ============================================================
-- Create Test Database
-- ============================================================
PRINT '📁 Creating test database...'

IF NOT EXISTS (SELECT 1 FROM sys.databases WHERE name = 'TestPartitioningDB')
BEGIN
    CREATE DATABASE TestPartitioningDB
    PRINT '✅ TestPartitioningDB created'
END
ELSE
BEGIN
    PRINT 'ℹ️ TestPartitioningDB already exists'
END
GO

USE TestPartitioningDB
GO

-- ============================================================
-- Create Test Table
-- ============================================================
PRINT ''
PRINT '📊 Creating test table...'

IF OBJECT_ID('dbo.SalesData', 'U') IS NOT NULL
    DROP TABLE dbo.SalesData
GO

CREATE TABLE dbo.SalesData (
    SaleID INT IDENTITY(1,1) PRIMARY KEY,
    SaleDate DATE NOT NULL,
    ProductID INT NOT NULL,
    CustomerID INT NOT NULL,
    Quantity INT NOT NULL,
    UnitPrice DECIMAL(18,2) NOT NULL,
    TotalAmount DECIMAL(18,2) NOT NULL,
    Discount DECIMAL(5,2) DEFAULT 0,
    TaxAmount DECIMAL(18,2) DEFAULT 0,
    SalesPerson NVARCHAR(100),
    Region NVARCHAR(50),
    Notes NVARCHAR(MAX)
)
GO

-- Add some constraints
ALTER TABLE dbo.SalesData ADD CONSTRAINT CHK_Quantity CHECK (Quantity > 0)
ALTER TABLE dbo.SalesData ADD CONSTRAINT CHK_UnitPrice CHECK (UnitPrice >= 0)
GO

-- Insert sample data
PRINT '📊 Inserting sample data...'

DECLARE @StartDate DATE = '2020-01-01'
DECLARE @EndDate DATE = '2024-12-31'
DECLARE @DateRange INT = DATEDIFF(DAY, @StartDate, @EndDate)

-- Generate 100,000 sample rows
INSERT INTO dbo.SalesData (
    SaleDate, ProductID, CustomerID, Quantity, UnitPrice, 
    TotalAmount, Discount, TaxAmount, SalesPerson, Region
)
SELECT TOP 100000
    DATEADD(DAY, ABS(CHECKSUM(NEWID()) % @DateRange), @StartDate) AS SaleDate,
    ABS(CHECKSUM(NEWID())) % 100 + 1 AS ProductID,
    ABS(CHECKSUM(NEWID())) % 1000 + 1 AS CustomerID,
    ABS(CHECKSUM(NEWID())) % 10 + 1 AS Quantity,
    CAST(ABS(CHECKSUM(NEWID())) % 1000 + 10 AS DECIMAL(18,2)) AS UnitPrice,
    CAST((ABS(CHECKSUM(NEWID())) % 1000 + 10) * (ABS(CHECKSUM(NEWID())) % 10 + 1) AS DECIMAL(18,2)) AS TotalAmount,
    CAST(ABS(CHECKSUM(NEWID())) % 100 / 100.0 AS DECIMAL(5,2)) AS Discount,
    CAST((ABS(CHECKSUM(NEWID())) % 1000 + 10) * (ABS(CHECKSUM(NEWID())) % 10 + 1) * 0.1 AS DECIMAL(18,2)) AS TaxAmount,
    'SalesPerson_' + CAST(ABS(CHECKSUM(NEWID())) % 20 + 1 AS NVARCHAR) AS SalesPerson,
    CASE ABS(CHECKSUM(NEWID())) % 5
        WHEN 0 THEN 'North'
        WHEN 1 THEN 'South'
        WHEN 2 THEN 'East'
        WHEN 3 THEN 'West'
        ELSE 'Central'
    END AS Region
FROM sys.objects o1
CROSS JOIN sys.objects o2
CROSS JOIN sys.objects o3
GO

PRINT '✅ Sample data inserted: ' + CAST(@@ROWCOUNT AS NVARCHAR) + ' rows'
PRINT ''

-- ============================================================
-- Test 1: Basic Dry Run
-- ============================================================
PRINT '===================================================='
PRINT '🧪 Test 1: Basic Dry Run'
PRINT '===================================================='
PRINT ''

DECLARE @DryRunExecutionID UNIQUEIDENTIFIER

EXEC DBADB.dbo.sp_ConvertToPartitionedTable
    @DatabaseName = 'TestPartitioningDB',
    @SchemaName = 'dbo',
    @TableName = 'SalesData',
    @PartitionColumn = 'SaleDate',
    @NumberOfExistingPartitions = 12,
    @DryRun = 1,
    @DryRunOutputFormat = 'TABLE'

-- Get the execution ID from the results
SELECT @DryRunExecutionID = ExecutionID 
FROM DBADB.dbo.DryRunResults 
WHERE ExecutionID IS NOT NULL 
GROUP BY ExecutionID
HAVING MAX(CreatedDate) = (SELECT MAX(CreatedDate) FROM DBADB.dbo.DryRunResults)

PRINT ''
PRINT '📊 Dry Run Execution ID: ' + CAST(@DryRunExecutionID AS NVARCHAR)
PRINT ''

-- ============================================================
-- Test 2: View Dry Run Results
-- ============================================================
PRINT '===================================================='
PRINT '🧪 Test 2: View Dry Run Results'
PRINT '===================================================='
PRINT ''

EXEC DBADB.dbo.sp_GetDryRunResults
    @ExecutionID = @DryRunExecutionID,
    @Format = 'TABLE'

-- ============================================================
-- Test 3: Check Partition Health (Before Partitioning)
-- ============================================================
PRINT '===================================================='
PRINT '🧪 Test 3: Check Partition Health (Before Partitioning)'
PRINT '===================================================='
PRINT ''

EXEC DBADB.dbo.sp_CheckPartitionHealth
    @DatabaseName = 'TestPartitioningDB',
    @TableName = 'SalesData'

-- ============================================================
-- Test 4: Execute Actual Partitioning
-- ============================================================
PRINT '===================================================='
PRINT '🧪 Test 4: Execute Actual Partitioning'
PRINT '===================================================='
PRINT '⚠️ This will actually partition the table!'
PRINT 'Press any key to continue or CTRL+C to cancel...'
PRINT ''

-- Uncomment to execute actual partitioning
/*
EXEC DBADB.dbo.sp_ConvertToPartitionedTable
    @DatabaseName = 'TestPartitioningDB',
    @SchemaName = 'dbo',
    @TableName = 'SalesData',
    @PartitionColumn = 'SaleDate',
    @NumberOfExistingPartitions = 12,
    @PartitionInterval = 3,
    @FuturePartitionsAhead = 6,
    @ScheduleFuturePartitions = 1,
    @JobScheduleTime = '02:00:00',
    @JobScheduleFrequency = 'Monthly',
    @PreserveForeignKeys = 1,
    @PreserveDefaults = 1,
    @PreserveCheckConstraints = 1,
    @PreserveExtendedProperties = 1,
    @BatchSize = 10000,
    @DryRun = 0
*/

-- ============================================================
-- Test 5: Validate Partition Setup (After Partitioning)
-- ============================================================
PRINT '===================================================='
PRINT '🧪 Test 5: Validate Partition Setup (After Partitioning)'
PRINT '===================================================='
PRINT ''

EXEC DBADB.dbo.sp_ValidatePartitionSetup
    @DatabaseName = 'TestPartitioningDB',
    @TableName = 'SalesData'

-- ============================================================
-- Test 6: Performance Report
-- ============================================================
PRINT '===================================================='
PRINT '🧪 Test 6: Performance Report'
PRINT '===================================================='
PRINT ''

EXEC DBADB.dbo.sp_PartitionPerformanceReport
    @DatabaseName = 'TestPartitioningDB',
    @StartDate = DATEADD(DAY, -30, GETDATE()),
    @EndDate = GETDATE()

-- ============================================================
-- Test 7: Check Partition Health (After Partitioning)
-- ============================================================
PRINT '===================================================='
PRINT '🧪 Test 7: Check Partition Health (After Partitioning)'
PRINT '===================================================='
PRINT ''

EXEC DBADB.dbo.sp_CheckPartitionHealth
    @DatabaseName = 'TestPartitioningDB',
    @TableName = 'SalesData',
    @CheckIntegrity = 1

-- ============================================================
-- Test 8: Add Future Partitions
-- ============================================================
PRINT '===================================================='
PRINT '🧪 Test 8: Add Future Partitions'
PRINT '===================================================='
PRINT ''

-- Note: This requires the table to be partitioned first
/*
EXEC DBADB.dbo.sp_AddFuturePartitions
    @DatabaseName = 'TestPartitioningDB',
    @PartitionFunctionName = 'PF_SalesData_SaleDate',
    @PartitionSchemeName = 'PS_SalesData_SaleDate',
    @PartitionColumn = 'SaleDate',
    @PartitionInterval = 3,
    @NumberOfPartitions = 3,
    @IsDateColumn = 1
*/

-- ============================================================
-- Test 9: Monitor Current Operations
-- ============================================================
PRINT '===================================================='
PRINT '🧪 Test 9: Monitor Current Operations'
PRINT '===================================================='
PRINT ''

SELECT * FROM DBADB.dbo.vw_CurrentPartitionOperations
SELECT * FROM DBADB.dbo.vw_RecentPartitionOperations

-- ============================================================
-- Test 10: Clean Up Test Data
-- ============================================================
PRINT '===================================================='
PRINT '🧪 Test 10: Clean Up Test Data'
PRINT '===================================================='
PRINT ''

-- Uncomment to clean up test database
/*
USE master
GO
IF EXISTS (SELECT 1 FROM sys.databases WHERE name = 'TestPartitioningDB')
BEGIN
    ALTER DATABASE TestPartitioningDB SET SINGLE_USER WITH ROLLBACK IMMEDIATE
    DROP DATABASE TestPartitioningDB
    PRINT '✅ TestPartitioningDB dropped'
END
*/

PRINT ''
PRINT '===================================================='
PRINT '✅ All tests completed!'
PRINT '===================================================='
PRINT ''
PRINT '📋 Test Summary:'
PRINT '   ✅ Test 1: Basic Dry Run'
PRINT '   ✅ Test 2: View Dry Run Results'
PRINT '   ✅ Test 3: Check Partition Health (Before)'
PRINT '   ⏳ Test 4: Execute Actual Partitioning (Manual)'
PRINT '   ✅ Test 5: Validate Partition Setup (After)'
PRINT '   ✅ Test 6: Performance Report'
PRINT '   ✅ Test 7: Check Partition Health (After)'
PRINT '   ⏳ Test 8: Add Future Partitions (Manual)'
PRINT '   ✅ Test 9: Monitor Current Operations'
PRINT '   ⏳ Test 10: Clean Up Test Data (Manual)'
PRINT '===================================================='
GO