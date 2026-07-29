-- ============================================================
-- File: 01_Create_DBADB_Database.sql
-- Description: Creates the DBADB database for partitioning system
-- ============================================================

PRINT '===================================================='
PRINT '🚀 Creating DBADB Database'
PRINT '===================================================='
PRINT ''

-- Check if database exists and create if not
IF NOT EXISTS (SELECT 1 FROM sys.databases WHERE name = 'DBADB')
BEGIN
    PRINT '📁 Creating DBADB database...'
    
    CREATE DATABASE DBADB
    ON PRIMARY (
        NAME = DBADB_Data,
        FILENAME = 'C:\Program Files\Microsoft SQL Server\MSSQL15.MSSQLSERVER\MSSQL\DATA\DBADB_Data.mdf',
        SIZE = 100MB,
        MAXSIZE = UNLIMITED,
        FILEGROWTH = 50MB
    )
    LOG ON (
        NAME = DBADB_Log,
        FILENAME = 'C:\Program Files\Microsoft SQL Server\MSSQL15.MSSQLSERVER\MSSQL\DATA\DBADB_Log.ldf',
        SIZE = 50MB,
        MAXSIZE = UNLIMITED,
        FILEGROWTH = 25MB
    )
    
    PRINT '✅ DBADB database created successfully!'
END
ELSE
BEGIN
    PRINT 'ℹ️ DBADB database already exists. Skipping creation.'
END

PRINT ''
PRINT '✅ Database setup completed!'
PRINT '===================================================='
GO

-- Set database compatibility
USE DBADB
GO

ALTER DATABASE DBADB SET COMPATIBILITY_LEVEL = 150
PRINT '📊 Database compatibility level set to SQL Server 2019'
GO