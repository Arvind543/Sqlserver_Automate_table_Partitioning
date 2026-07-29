-- Enhanced Grant Script
USE [DBADB]
GO

-- Create role for partition management
CREATE ROLE PartitionAdminRole
GO

-- Grant permissions to role
GRANT EXECUTE ON dbo.sp_ConvertToPartitionedTable TO PartitionAdminRole
GRANT EXECUTE ON dbo.sp_AddFuturePartitions TO PartitionAdminRole
GRANT EXECUTE ON dbo.sp_CheckPartitionHealth TO PartitionAdminRole
GRANT EXECUTE ON dbo.sp_PartitionPerformanceReport TO PartitionAdminRole
GRANT EXECUTE ON dbo.sp_RestoreForeignKeys TO PartitionAdminRole
GRANT EXECUTE ON dbo.sp_ValidatePartitionSetup TO PartitionAdminRole
GRANT SELECT, INSERT, UPDATE ON dbo.PartitioningLog TO PartitionAdminRole

-- Create login and user
CREATE LOGIN PartitionAdmin WITH PASSWORD = 'StrongPassword123!', CHECK_POLICY = ON
GO
CREATE USER PartitionAdmin FOR LOGIN PartitionAdmin
GO
ALTER ROLE PartitionAdminRole ADD MEMBER PartitionAdmin
GO

-- Grant additional permissions in master
USE master
GO
GRANT VIEW SERVER STATE TO PartitionAdmin
GRANT VIEW ANY DATABASE TO PartitionAdmin
GO

-- Grant permissions in MSDB
USE msdb
GO
GRANT EXECUTE ON msdb.dbo.sp_add_job TO PartitionAdmin
GRANT EXECUTE ON msdb.dbo.sp_add_jobstep TO PartitionAdmin
GRANT EXECUTE ON msdb.dbo.sp_add_schedule TO PartitionAdmin
GRANT EXECUTE ON msdb.dbo.sp_attach_schedule TO PartitionAdmin
GRANT EXECUTE ON msdb.dbo.sp_add_jobserver TO PartitionAdmin
GRANT EXECUTE ON msdb.dbo.sp_delete_job TO PartitionAdmin
GRANT SELECT ON msdb.dbo.sysjobs TO PartitionAdmin
GO

-- Grant database-level permissions for target databases
-- Run this for each database where partitioning will occur
/*
USE [TargetDatabase]
GO
GRANT ALTER TO PartitionAdmin
GRANT CREATE TABLE TO PartitionAdmin
GRANT CREATE FUNCTION TO PartitionAdmin
GRANT CREATE SCHEMA TO PartitionAdmin
GRANT VIEW DEFINITION TO PartitionAdmin
GRANT REFERENCES TO PartitionAdmin
GRANT SELECT, INSERT, UPDATE, DELETE ON SCHEMA::dbo TO PartitionAdmin
GRANT ALTER ON SCHEMA::dbo TO PartitionAdmin
GO
*/
