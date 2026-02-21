-- =========================================================
-- PLIK: dropHD.sql
-- =========================================================

-- 1. USUWANIE TABEL HURTOWNI (dbo)
IF OBJECT_ID('dbo.TRIP_OPERATIONS_FACT', 'U') IS NOT NULL 
    DROP TABLE dbo.TRIP_OPERATIONS_FACT;

IF OBJECT_ID('dbo.REPAIR_DIM', 'U') IS NOT NULL 
    DROP TABLE dbo.REPAIR_DIM;
IF OBJECT_ID('dbo.BOARDING_DIM', 'U') IS NOT NULL 
    DROP TABLE dbo.BOARDING_DIM;
IF OBJECT_ID('dbo.DRIVER_DIM', 'U') IS NOT NULL 
    DROP TABLE dbo.DRIVER_DIM;
IF OBJECT_ID('dbo.TRIP_DIM', 'U') IS NOT NULL 
    DROP TABLE dbo.TRIP_DIM;
IF OBJECT_ID('dbo.ROUTE_DIM', 'U') IS NOT NULL 
    DROP TABLE dbo.ROUTE_DIM;
IF OBJECT_ID('dbo.STOP_DIM', 'U') IS NOT NULL 
    DROP TABLE dbo.STOP_DIM;
IF OBJECT_ID('dbo.MALFUNCTION_DIM', 'U') IS NOT NULL 
    DROP TABLE dbo.MALFUNCTION_DIM;
IF OBJECT_ID('dbo.TRAM_DIM', 'U') IS NOT NULL 
    DROP TABLE dbo.TRAM_DIM;
IF OBJECT_ID('dbo.TIME_DIM', 'U') IS NOT NULL 
    DROP TABLE dbo.TIME_DIM;
IF OBJECT_ID('dbo.DATE_DIM', 'U') IS NOT NULL 
    DROP TABLE dbo.DATE_DIM;

-- 2. USUWANIE TABEL STAGING (stg)
IF OBJECT_ID('stg.Drivers', 'U') IS NOT NULL 
    DROP TABLE stg.Drivers;
IF OBJECT_ID('stg.Malfunctions', 'U') IS NOT NULL 
    DROP TABLE stg.Malfunctions;
IF OBJECT_ID('stg.Routes', 'U') IS NOT NULL 
    DROP TABLE stg.Routes;
IF OBJECT_ID('stg.Stops', 'U') IS NOT NULL 
    DROP TABLE stg.Stops;
IF OBJECT_ID('stg.StopTimes', 'U') IS NOT NULL 
    DROP TABLE stg.StopTimes;
IF OBJECT_ID('stg.Trams', 'U') IS NOT NULL 
    DROP TABLE stg.Trams;
IF OBJECT_ID('stg.Trips', 'U') IS NOT NULL 
    DROP TABLE stg.Trips;

PRINT 'Usuniêto tabele faktów, wymiarów oraz staging.';
GO