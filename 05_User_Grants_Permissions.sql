-- ============================================================
-- File: 05_User_Grants_Permissions.sql
-- Description: Sets up users, roles, and permissions
-- ============================================================

USE master
GO

PRINT '===================================================='
PRINT '🔐 Setting Up Users, Roles, and Permissions'
PRINT '===================================================='
PRINT ''

-- ============================================================
-- 1. Create Login and User
-- ============================================================
PRINT '👤 Creating login and user...'

-- Create login (change password as needed)
IF NOT EXISTS (SELECT 1 FROM sys.sql_logins WHERE name = 'PartitionAdmin')
BEGIN
    CREATE LOGIN PartitionAdmin 
    WITH PASSWORD = 'StrongP@ssw0rd2024!', 
         CHECK_POLICY = ON,
         CHECK_EXPIRATION = ON,
         DEFAULT_DATABASE = DBADB
    PRINT '✅ Login PartitionAdmin created'
END
ELSE
BEGIN
    PRINT 'ℹ️ Login PartitionAdmin already exists'
END
GO

USE DBADB
GO

IF NOT EXISTS (SELECT 1 FROM sys.database_principals WHERE name = 'PartitionAdmin')
BEGIN
    CREATE USER PartitionAdmin FOR LOGIN PartitionAdmin
    PRINT '✅ User PartitionAdmin created in DBADB'
END
ELSE
BEGIN
    PRINT 'ℹ️ User PartitionAdmin already exists in DBADB'
END
GO

-- ============================================================
-- 2. Create Roles
-- ============================================================
PRINT ''
PRINT '👥 Creating database roles...'

USE DBADB
GO

-- Drop roles if they exist
IF EXISTS (SELECT 1 FROM sys.database_principals WHERE name = 'PartitionAdminRole' AND type = 'R')
    DROP ROLE PartitionAdminRole
GO

IF EXISTS (SELECT 1 FROM sys.database_principals WHERE name = 'PartitionMonitorRole' AND type = 'R')
    DROP ROLE PartitionMonitorRole
GO

-- Create Admin Role
CREATE ROLE PartitionAdminRole
PRINT '✅ PartitionAdminRole created'

-- Create Monitor Role
CREATE ROLE PartitionMonitorRole
PRINT '✅ PartitionMonitorRole created'

-- ============================================================
-- 3. Grant Permissions to Admin Role
-- ============================================================
PRINT ''
PRINT '🔑 Granting permissions to PartitionAdminRole...'

-- Execute permissions on procedures
GRANT EXECUTE ON dbo.sp_ConvertToPartitionedTable TO PartitionAdminRole
GRANT EXECUTE ON dbo.sp_AddFuturePartitions TO PartitionAdminRole
GRANT EXECUTE ON dbo.sp_CheckPartitionHealth TO PartitionAdminRole
GRANT EXECUTE ON dbo.sp_PartitionPerformanceReport TO PartitionAdminRole
GRANT EXECUTE ON dbo.sp_RestoreForeignKeys TO PartitionAdminRole
GRANT EXECUTE ON dbo.sp_ValidatePartitionSetup TO PartitionAdminRole
GRANT EXECUTE ON dbo.sp_GetDryRunResults TO PartitionAdminRole

-- Data permissions on tables
GRANT SELECT, INSERT, UPDATE, DELETE ON dbo.PartitioningLog TO PartitionAdminRole
GRANT SELECT, INSERT, UPDATE, DELETE ON dbo.DryRunResults TO PartitionAdminRole
GRANT SELECT, INSERT, UPDATE, DELETE ON dbo.PartitioningConfig TO PartitionAdminRole
GRANT SELECT, INSERT, UPDATE, DELETE ON dbo.PartitioningErrorLog TO PartitionAdminRole

-- View definitions
GRANT VIEW DEFINITION ON SCHEMA::dbo TO PartitionAdminRole

PRINT '✅ Permissions granted to PartitionAdminRole'

-- ============================================================
-- 4. Grant Permissions to Monitor Role
-- ============================================================
PRINT ''
PRINT '🔑 Granting permissions to PartitionMonitorRole...'

-- Select only permissions for monitoring
GRANT SELECT ON dbo.PartitioningLog TO PartitionMonitorRole
GRANT SELECT ON dbo.DryRunResults TO PartitionMonitorRole
GRANT SELECT ON dbo.PartitioningConfig TO PartitionMonitorRole
GRANT SELECT ON dbo.PartitioningErrorLog TO PartitionMonitorRole
GRANT SELECT ON dbo.vw_CurrentPartitionOperations TO PartitionMonitorRole
GRANT SELECT ON dbo.vw_RecentPartitionOperations TO PartitionMonitorRole

-- Execute monitoring procedures
GRANT EXECUTE ON dbo.sp_CheckPartitionHealth TO PartitionMonitorRole
GRANT EXECUTE ON dbo.sp_PartitionPerformanceReport TO PartitionMonitorRole
GRANT EXECUTE ON dbo.sp_ValidatePartitionSetup TO PartitionMonitorRole
GRANT EXECUTE ON dbo.sp_GetDryRunResults TO PartitionMonitorRole

PRINT '✅ Permissions granted to PartitionMonitorRole'

-- ============================================================
-- 5. Add Users to Roles
-- ============================================================
PRINT ''
PRINT '👤 Adding users to roles...'

-- Add PartitionAdmin user to admin role
EXEC sp_addrolemember 'PartitionAdminRole', 'PartitionAdmin'
PRINT '✅ PartitionAdmin added to PartitionAdminRole'

-- Add additional users as needed
-- EXEC sp_addrolemember 'PartitionAdminRole', 'Domain\UserName'
-- EXEC sp_addrolemember 'PartitionMonitorRole', 'Domain\MonitorUser'

-- ============================================================
-- 6. Grant Server-Level Permissions
-- ============================================================
USE master
GO

PRINT ''
PRINT '🔑 Granting server-level permissions...'

-- Grant view server state for monitoring
GRANT VIEW SERVER STATE TO PartitionAdmin
GRANT VIEW SERVER STATE TO PartitionAdmin

-- Grant view any database
GRANT VIEW ANY DATABASE TO PartitionAdmin

PRINT '✅ Server-level permissions granted'

-- ============================================================
-- 7. Grant MSDB Permissions for SQL Agent Jobs
-- ============================================================
USE msdb
GO

PRINT ''
PRINT '🔑 Granting MSDB permissions for SQL Agent...'

-- Grant execute on job procedures
GRANT EXECUTE ON msdb.dbo.sp_add_job TO PartitionAdmin
GRANT EXECUTE ON msdb.dbo.sp_add_jobstep TO PartitionAdmin
GRANT EXECUTE ON msdb.dbo.sp_add_schedule TO PartitionAdmin
GRANT EXECUTE ON msdb.dbo.sp_attach_schedule TO PartitionAdmin
GRANT EXECUTE ON msdb.dbo.sp_add_jobserver TO PartitionAdmin
GRANT EXECUTE ON msdb.dbo.sp_delete_job TO PartitionAdmin
GRANT EXECUTE ON msdb.dbo.sp_start_job TO PartitionAdmin
GRANT EXECUTE ON msdb.dbo.sp_stop_job TO PartitionAdmin

-- Grant select on job tables
GRANT SELECT ON msdb.dbo.sysjobs TO PartitionAdmin
GRANT SELECT ON msdb.dbo.sysjobhistory TO PartitionAdmin
GRANT SELECT ON msdb.dbo.sysjobsteps TO PartitionAdmin

PRINT '✅ MSDB permissions granted'

-- ============================================================
-- 8. Grant Permissions on Target Databases
-- ============================================================
PRINT ''
PRINT '🔑 Granting permissions on target databases...'
PRINT 'ℹ️ Run this section for each database where partitioning will occur'

-- Example for a specific database
/*
USE [YourTargetDatabase]
GO

-- Grant schema-level permissions
GRANT ALTER ON SCHEMA::dbo TO PartitionAdmin
GRANT REFERENCES ON SCHEMA::dbo TO PartitionAdmin
GRANT VIEW DEFINITION ON SCHEMA::dbo TO PartitionAdmin

-- Grant object-level permissions
GRANT CREATE TABLE TO PartitionAdmin
GRANT CREATE FUNCTION TO PartitionAdmin
GRANT CREATE SCHEMA TO PartitionAdmin
GRANT CREATE VIEW TO PartitionAdmin

-- Grant data permissions
GRANT SELECT, INSERT, UPDATE, DELETE ON SCHEMA::dbo TO PartitionAdmin

-- Grant alter permissions for partitions
GRANT ALTER ON SCHEMA::dbo TO PartitionAdmin

PRINT '✅ Permissions granted on target database: YourTargetDatabase'
*/

PRINT ''
PRINT '===================================================='
PRINT '✅ User, Role, and Permission setup completed!'
PRINT '===================================================='
PRINT ''
PRINT '📋 Summary:'
PRINT '   - Login: PartitionAdmin'
PRINT '   - Roles: PartitionAdminRole, PartitionMonitorRole'
PRINT '   - Permissions granted as configured'
PRINT ''
PRINT '⚠️ Important Notes:'
PRINT '   1. Change the default password in a production environment'
PRINT '   2. Grant permissions on target databases as needed'
PRINT '   3. Review the security model for your organization'
PRINT '===================================================='
GO