-- ============================================================
-- File: 10_Complete_Deployment.sql
-- Description: Complete deployment of the partitioning system
-- ============================================================

PRINT '===================================================='
PRINT '🚀 COMPLETE PARTITIONING SYSTEM DEPLOYMENT'
PRINT '===================================================='
PRINT ''

-- ============================================================
-- Step 1: Create DBADB Database
-- ============================================================
PRINT '📁 STEP 1: Creating DBADB Database'
PRINT '----------------------------------'

IF NOT EXISTS (SELECT 1 FROM sys.databases WHERE name = 'DBADB')
BEGIN
    CREATE DATABASE DBADB
    PRINT '✅ DBADB database created successfully!'
END
ELSE
BEGIN
    PRINT 'ℹ️ DBADB database already exists.'
END
PRINT ''

-- ============================================================
-- Step 2: Create Tables
-- ============================================================
PRINT '📊 STEP 2: Creating Tables'
PRINT '--------------------------'

:r 02_Create_Partitioning_Tables.sql

-- ============================================================
-- Step 3: Deploy Main Procedure
-- ============================================================
PRINT '🚀 STEP 3: Deploying Main Procedure'
PRINT '-----------------------------------'

:r 03_Main_Partitioning_Procedure.sql

-- ============================================================
-- Step 4: Deploy Helper Procedures
-- ============================================================
PRINT '🛠️ STEP 4: Deploying Helper Procedures'
PRINT '---------------------------------------'

:r 04_Helper_Procedures.sql

-- ============================================================
-- Step 5: Setup Users and Permissions
-- ============================================================
PRINT '🔐 STEP 5: Setting Up Users and Permissions'
PRINT '-------------------------------------------'

:r 05_User_Grants_Permissions.sql

-- ============================================================
-- Step 6: Deploy Dry Run Helpers
-- ============================================================
PRINT '🔬 STEP 6: Deploying Dry Run Helpers'
PRINT '------------------------------------'

:r 07_DryRun_Helper_Functions.sql

-- ============================================================
-- Step 7: Deploy Monitoring Queries
-- ============================================================
PRINT '📊 STEP 7: Deploying Monitoring Queries'
PRINT '---------------------------------------'

:r 08_Monitoring_Queries.sql

-- ============================================================
-- Step 8: Deploy Maintenance Procedures
-- ============================================================
PRINT '🔧 STEP 8: Deploying Maintenance Procedures'
PRINT '--------------------------------------------'

:r 09_Maintenance_Procedures.sql

-- ============================================================
-- Step 9: Initialize Configuration
-- ============================================================
PRINT '⚙️ STEP 9: Initializing Configuration'
PRINT '-------------------------------------'

USE DBADB
GO

-- Insert sample configuration
INSERT INTO dbo.PartitioningConfig (
    ConfigName,
    DatabaseName,
    TableName,
    SchemaName,
    PartitionColumn,
    PartitionRangeType,
    PartitionInterval,
    NumberOfExistingPartitions,
    FuturePartitionsAhead,
    ScheduleFuturePartitions,
    JobScheduleTime,
    JobScheduleFrequency,
    PreserveForeignKeys,
    PreserveDefaults,
    PreserveCheckConstraints,
    PreserveExtendedProperties,
    BatchSize,
    IsActive
)
SELECT 
    'Default_' + name,
    'TestPartitioningDB',
    name,
    'dbo',
    'SaleDate',
    'RANGE RIGHT',
    1,
    12,
    6,
    1,
    '02:00:00',
    'Monthly',
    1,
    1,
    1,
    1,
    10000,
    1
FROM sys.tables
WHERE name = 'SalesData'
  AND NOT EXISTS (SELECT 1 FROM dbo.PartitioningConfig WHERE ConfigName LIKE 'Default%')
PRINT '✅ Sample configuration inserted'

PRINT ''
PRINT '===================================================='
PRINT '✅ DEPLOYMENT COMPLETED SUCCESSFULLY!'
PRINT '===================================================='
PRINT ''
PRINT '📋 System Summary:'
PRINT '   ✅ Database: DBADB'
PRINT '   ✅ Tables: PartitioningLog, DryRunResults, PartitioningConfig, PartitioningErrorLog'
PRINT '   ✅ Procedures: Main procedure + 14 helper procedures'
PRINT '   ✅ Views: 7 monitoring views'
PRINT '   ✅ Functions: 3 helper functions'
PRINT '   ✅ Security: PartitionAdminRole and PartitionMonitorRole created'
PRINT ''
PRINT '🚀 Next Steps:'
PRINT '   1. Review and update default password in User_Grants_Permissions.sql'
PRINT '   2. Grant permissions on target databases (see section 8 of User_Grants_Permissions.sql)'
PRINT '   3. Run Test_Examples.sql to verify the system'
PRINT '   4. Schedule regular maintenance using the maintenance procedures'
PRINT ''
PRINT '📚 Documentation: See README.md for complete instructions'
PRINT '===================================================='
GO