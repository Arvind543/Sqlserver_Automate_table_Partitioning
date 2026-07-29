-- ============================================================
-- File: 02_Create_Partitioning_Tables.sql
-- Description: Creates the necessary tables for partitioning system
-- ============================================================

USE DBADB
GO

PRINT '===================================================='
PRINT '📊 Creating Partitioning System Tables'
PRINT '===================================================='
PRINT ''

-- Drop existing tables if they exist
IF OBJECT_ID('dbo.PartitioningLog', 'U') IS NOT NULL
BEGIN
    DROP TABLE dbo.PartitioningLog
    PRINT '🗑️ Dropped existing PartitioningLog table'
END

IF OBJECT_ID('dbo.DryRunResults', 'U') IS NOT NULL
BEGIN
    DROP TABLE dbo.DryRunResults
    PRINT '🗑️ Dropped existing DryRunResults table'
END

IF OBJECT_ID('dbo.PartitioningConfig', 'U') IS NOT NULL
BEGIN
    DROP TABLE dbo.PartitioningConfig
    PRINT '🗑️ Dropped existing PartitioningConfig table'
END

PRINT ''
PRINT '📝 Creating PartitioningLog table...'

-- Create PartitioningLog Table
CREATE TABLE dbo.PartitioningLog (
    LogID INT IDENTITY(1,1) PRIMARY KEY,
    DatabaseName NVARCHAR(128) NOT NULL,
    TableName NVARCHAR(255) NOT NULL,
    SchemaName NVARCHAR(128) NOT NULL DEFAULT 'dbo',
    PartitionColumn NVARCHAR(128) NOT NULL,
    StepName NVARCHAR(100) NOT NULL,
    StepDescription NVARCHAR(MAX) NULL,
    StartTime DATETIME2 NOT NULL DEFAULT GETDATE(),
    EndTime DATETIME2 NULL,
    DurationSeconds INT NULL,
    Status NVARCHAR(20) NOT NULL DEFAULT 'Running',
    ErrorMessage NVARCHAR(MAX) NULL,
    AdditionalInfo NVARCHAR(MAX) NULL,
    LogDate DATETIME2 NOT NULL DEFAULT GETDATE(),
    ExecutionMode NVARCHAR(20) DEFAULT 'Actual' -- 'Actual' or 'DryRun'
)
GO

-- Add indexes for performance
CREATE NONCLUSTERED INDEX IX_PartitioningLog_TableDate 
    ON dbo.PartitioningLog (DatabaseName, TableName, LogDate DESC)
GO

CREATE NONCLUSTERED INDEX IX_PartitioningLog_Status 
    ON dbo.PartitioningLog (Status)
GO

CREATE NONCLUSTERED INDEX IX_PartitioningLog_StepName 
    ON dbo.PartitioningLog (StepName)
GO

PRINT '✅ PartitioningLog table created successfully!'
PRINT ''

PRINT '📝 Creating DryRunResults table...'

-- Create DryRunResults Table
CREATE TABLE dbo.DryRunResults (
    ResultID INT IDENTITY(1,1) PRIMARY KEY,
    ExecutionID UNIQUEIDENTIFIER NOT NULL,
    StepOrder INT NOT NULL,
    StepName NVARCHAR(100) NOT NULL,
    StepDescription NVARCHAR(MAX) NULL,
    EstimatedDurationSeconds INT NULL,
    EstimatedRowCount BIGINT NULL,
    SQLToExecute NVARCHAR(MAX) NULL,
    Prerequisites NVARCHAR(MAX) NULL,
    Warnings NVARCHAR(MAX) NULL,
    Status NVARCHAR(20) NOT NULL DEFAULT 'Pending',
    CreatedDate DATETIME2 NOT NULL DEFAULT GETDATE(),
    ExecutionTime INT NULL -- Actual execution time in seconds
)
GO

-- Create indexes for dry run results
CREATE NONCLUSTERED INDEX IX_DryRunResults_ExecutionID 
    ON dbo.DryRunResults (ExecutionID)
GO

CREATE NONCLUSTERED INDEX IX_DryRunResults_Status 
    ON dbo.DryRunResults (Status)
GO

PRINT '✅ DryRunResults table created successfully!'
PRINT ''

PRINT '📝 Creating PartitioningConfig table...'

-- Create PartitioningConfig Table for storing configurations
CREATE TABLE dbo.PartitioningConfig (
    ConfigID INT IDENTITY(1,1) PRIMARY KEY,
    ConfigName NVARCHAR(255) NOT NULL,
    DatabaseName NVARCHAR(128) NOT NULL,
    TableName NVARCHAR(255) NOT NULL,
    SchemaName NVARCHAR(128) DEFAULT 'dbo',
    PartitionColumn NVARCHAR(128) NOT NULL,
    PartitionRangeType NVARCHAR(10) DEFAULT 'RANGE RIGHT',
    PartitionInterval INT DEFAULT 1,
    NumberOfExistingPartitions INT DEFAULT 12,
    FuturePartitionsAhead INT DEFAULT 6,
    ScheduleFuturePartitions BIT DEFAULT 1,
    JobScheduleTime NVARCHAR(20) DEFAULT '00:00:00',
    JobScheduleFrequency NVARCHAR(20) DEFAULT 'Monthly',
    PreserveForeignKeys BIT DEFAULT 1,
    PreserveDefaults BIT DEFAULT 1,
    PreserveCheckConstraints BIT DEFAULT 1,
    PreserveExtendedProperties BIT DEFAULT 1,
    BatchSize INT DEFAULT 10000,
    IsActive BIT DEFAULT 1,
    CreatedDate DATETIME2 DEFAULT GETDATE(),
    ModifiedDate DATETIME2 NULL,
    LastRunDate DATETIME2 NULL,
    LastRunStatus NVARCHAR(20) NULL,
    CreatedBy NVARCHAR(128) DEFAULT SYSTEM_USER
)
GO

CREATE NONCLUSTERED INDEX IX_PartitioningConfig_Active 
    ON dbo.PartitioningConfig (IsActive)
GO

CREATE NONCLUSTERED INDEX IX_PartitioningConfig_Table 
    ON dbo.PartitioningConfig (DatabaseName, TableName)
GO

PRINT '✅ PartitioningConfig table created successfully!'
PRINT ''

PRINT '📝 Creating Extended Logging table...'

-- Create Extended Error Log table
CREATE TABLE dbo.PartitioningErrorLog (
    ErrorID INT IDENTITY(1,1) PRIMARY KEY,
    LogID INT NULL,
    ErrorNumber INT NOT NULL,
    ErrorSeverity INT NOT NULL,
    ErrorState INT NOT NULL,
    ErrorProcedure NVARCHAR(255) NULL,
    ErrorLine INT NULL,
    ErrorMessage NVARCHAR(MAX) NOT NULL,
    ErrorDate DATETIME2 DEFAULT GETDATE(),
    AdditionalInfo NVARCHAR(MAX) NULL
)
GO

CREATE NONCLUSTERED INDEX IX_PartitioningErrorLog_LogID 
    ON dbo.PartitioningErrorLog (LogID)
GO

CREATE NONCLUSTERED INDEX IX_PartitioningErrorLog_Date 
    ON dbo.PartitioningErrorLog (ErrorDate DESC)
GO

PRINT '✅ PartitioningErrorLog table created successfully!'
PRINT ''

PRINT '📊 Creating views for easier monitoring...'

-- Create View for Current Partition Operations
CREATE VIEW dbo.vw_CurrentPartitionOperations AS
SELECT 
    LogID,
    DatabaseName,
    TableName,
    SchemaName,
    PartitionColumn,
    StepName,
    StepDescription,
    StartTime,
    EndTime,
    DATEDIFF(SECOND, StartTime, ISNULL(EndTime, GETDATE())) AS RunningSeconds,
    Status,
    ExecutionMode,
    AdditionalInfo
FROM dbo.PartitioningLog
WHERE Status IN ('Running', 'Pending')
ORDER BY StartTime DESC
GO

-- Create View for Recent Operations
CREATE VIEW dbo.vw_RecentPartitionOperations AS
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
        WHEN Status = 'Success' THEN '✅'
        WHEN Status = 'Failed' THEN '❌'
        WHEN Status = 'Running' THEN '🔄'
        WHEN Status = 'DryRunComplete' THEN '🔬'
        ELSE 'ℹ️'
    END AS StatusIcon,
    ExecutionMode
FROM dbo.PartitioningLog
ORDER BY LogID DESC
GO

PRINT '✅ Views created successfully!'
PRINT ''

PRINT '===================================================='
PRINT '✅ All tables and views created successfully!'
PRINT '📊 Tables created:'
PRINT '   - PartitioningLog'
PRINT '   - DryRunResults'
PRINT '   - PartitioningConfig'
PRINT '   - PartitioningErrorLog'
PRINT '📊 Views created:'
PRINT '   - vw_CurrentPartitionOperations'
PRINT '   - vw_RecentPartitionOperations'
PRINT '===================================================='
GO