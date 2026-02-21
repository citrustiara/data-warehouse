-- =========================================================
-- PLIK: create_schema_final.sql
-- ZMIANA: STOP_DIM ma teraz lat/lon jako VARCHAR
-- =========================================================
USE master;
GO

-- 0. STAGING (Szerokie kolumny 255 znaków - bez zmian, bo to dobre zabezpieczenie)
IF NOT EXISTS (SELECT * FROM sys.schemas WHERE name = 'stg') EXEC('CREATE SCHEMA [stg]');
GO

IF OBJECT_ID('stg.Drivers', 'U') IS NOT NULL DROP TABLE stg.Drivers;
IF OBJECT_ID('stg.Malfunctions', 'U') IS NOT NULL DROP TABLE stg.Malfunctions;
IF OBJECT_ID('stg.Routes', 'U') IS NOT NULL DROP TABLE stg.Routes;
IF OBJECT_ID('stg.Stops', 'U') IS NOT NULL DROP TABLE stg.Stops;
IF OBJECT_ID('stg.StopTimes', 'U') IS NOT NULL DROP TABLE stg.StopTimes;
IF OBJECT_ID('stg.Trams', 'U') IS NOT NULL DROP TABLE stg.Trams;
IF OBJECT_ID('stg.Trips', 'U') IS NOT NULL DROP TABLE stg.Trips;

CREATE TABLE stg.Drivers (driver_id VARCHAR(255), PESEL VARCHAR(255), driver_name VARCHAR(255), driver_surname VARCHAR(255), experience_category VARCHAR(255));
CREATE TABLE stg.Malfunctions (malfunction_id VARCHAR(255), type VARCHAR(255), description VARCHAR(255));
CREATE TABLE stg.Routes (route_id VARCHAR(255), agency_id VARCHAR(255), route_short_name VARCHAR(255), route_long_name VARCHAR(255), route_desc VARCHAR(MAX), route_type VARCHAR(255), route_color VARCHAR(255), route_text_color VARCHAR(255));
CREATE TABLE stg.Stops (stop_id VARCHAR(255), stop_code VARCHAR(255), stop_name VARCHAR(255), stop_lat VARCHAR(255), stop_lon VARCHAR(255));
CREATE TABLE stg.StopTimes (trip_id VARCHAR(255), arrival_time VARCHAR(255), departure_time VARCHAR(255), stop_id VARCHAR(255), stop_sequence VARCHAR(255), stop_headsign VARCHAR(255), pickup_type VARCHAR(255), drop_off_type VARCHAR(255), shape_dist_traveled VARCHAR(255), malfunction_id VARCHAR(255), delay_minutes VARCHAR(255));
CREATE TABLE stg.Trams (tram_id VARCHAR(255), model VARCHAR(255), production_date VARCHAR(255), last_service_date VARCHAR(255));
CREATE TABLE stg.Trips (route_id VARCHAR(255), service_id VARCHAR(255), trip_id VARCHAR(255), trip_headsign VARCHAR(255), trip_short_name VARCHAR(255), direction_id VARCHAR(255), block_id VARCHAR(255), shape_id VARCHAR(255), wheelchair_accessible VARCHAR(255), driver_id VARCHAR(255), tram_id VARCHAR(255));

-- 1. CLEANUP MAIN TABLES
IF OBJECT_ID('TRIP_OPERATIONS_FACT', 'U') IS NOT NULL DROP TABLE TRIP_OPERATIONS_FACT;
IF OBJECT_ID('TRIP_DIM', 'U') IS NOT NULL DROP TABLE TRIP_DIM;
IF OBJECT_ID('DATE_DIM', 'U') IS NOT NULL DROP TABLE DATE_DIM;
IF OBJECT_ID('MALFUNCTION_DIM', 'U') IS NOT NULL DROP TABLE MALFUNCTION_DIM;
IF OBJECT_ID('ROUTE_DIM', 'U') IS NOT NULL DROP TABLE ROUTE_DIM;
IF OBJECT_ID('STOP_DIM', 'U') IS NOT NULL DROP TABLE STOP_DIM;
IF OBJECT_ID('DRIVER_DIM', 'U') IS NOT NULL DROP TABLE DRIVER_DIM;
IF OBJECT_ID('TRAM_DIM', 'U') IS NOT NULL DROP TABLE TRAM_DIM;
IF OBJECT_ID('TIME_DIM', 'U') IS NOT NULL DROP TABLE TIME_DIM;
IF OBJECT_ID('BOARDING_DIM', 'U') IS NOT NULL DROP TABLE BOARDING_DIM;
IF OBJECT_ID('REPAIR_DIM', 'U') IS NOT NULL DROP TABLE REPAIR_DIM;

-- 2. CREATE DIMENSIONS
CREATE TABLE DATE_DIM (ID_Date INT PRIMARY KEY, full_date DATE, day_of_month SMALLINT, month SMALLINT, month_name VARCHAR(20), year SMALLINT, day_of_week SMALLINT, day_of_week_name VARCHAR(20), is_working_day BIT, holiday_name VARCHAR(100));
CREATE TABLE TIME_DIM (ID_Time INT PRIMARY KEY, full_time TIME, hour SMALLINT, minute SMALLINT, time_of_day_category VARCHAR(50));
CREATE TABLE TRAM_DIM (ID_Tram INT PRIMARY KEY, model VARCHAR(100), production_year SMALLINT, last_service_date DATE);
CREATE TABLE MALFUNCTION_DIM (ID_Malfunction INT PRIMARY KEY, malfunction_type VARCHAR(100), malfunction_description VARCHAR(255));

-- !!! ZMIANA: stop_lat i stop_lon jako VARCHAR !!!
CREATE TABLE STOP_DIM (
    ID_Stop INT PRIMARY KEY, 
    stop_name VARCHAR(100), 
    stop_lat VARCHAR(50), -- Teraz tekst
    stop_lon VARCHAR(50), -- Teraz tekst
    stop_code VARCHAR(50), 
    district VARCHAR(100)
);

CREATE TABLE ROUTE_DIM (ID_Route INT PRIMARY KEY, route_short_name VARCHAR(20), route_long_name VARCHAR(255), route_color VARCHAR(50));
CREATE TABLE TRIP_DIM (ID_Trip VARCHAR(50) PRIMARY KEY, trip_headsign VARCHAR(255), trip_short_name VARCHAR(50), direction_id BIT, wheelchair_accessible BIT);
CREATE TABLE DRIVER_DIM (DriverKey INT IDENTITY(1,1) PRIMARY KEY, ID_Driver INT, driver_pesel VARCHAR(11), driver_name VARCHAR(50), driver_surname VARCHAR(50), experience_category VARCHAR(50), row_effective_date DATE, row_expiration_date DATE, IsCurrent BIT);
CREATE TABLE BOARDING_DIM (ID_Boarding INT IDENTITY(1,1) PRIMARY KEY, pickup_type SMALLINT, drop_off_type SMALLINT, description VARCHAR(100));
CREATE TABLE REPAIR_DIM (ID_Repair INT IDENTITY(1,1) PRIMARY KEY, is_on_site_repair BIT, on_site_repair_possible BIT, description VARCHAR(100));

-- 3. CREATE FACTS
CREATE TABLE TRIP_OPERATIONS_FACT (
    ID_Trip VARCHAR(50) NOT NULL, ID_Date INT NOT NULL, ID_Malfunction INT NOT NULL, ID_Route INT NOT NULL, ID_Stop INT NOT NULL, DriverKey INT NOT NULL, ID_Tram INT NOT NULL, ID_Time INT NOT NULL, ID_Boarding INT NOT NULL, ID_Repair INT NOT NULL,
    delay_minutes DECIMAL(5,2), stop_sequence SMALLINT NOT NULL, planned_travel_time_minutes DECIMAL(7,2), delay_caused_minutes DECIMAL(7,2), repair_duration_minutes SMALLINT,
    PRIMARY KEY (ID_Trip, ID_Date, ID_Time, ID_Stop, ID_Route, ID_Tram, DriverKey, ID_Malfunction, ID_Boarding, ID_Repair),
    FOREIGN KEY (ID_Trip) REFERENCES TRIP_DIM(ID_Trip), FOREIGN KEY (ID_Date) REFERENCES DATE_DIM(ID_Date), FOREIGN KEY (ID_Malfunction) REFERENCES MALFUNCTION_DIM(ID_Malfunction), FOREIGN KEY (ID_Route) REFERENCES ROUTE_DIM(ID_Route), FOREIGN KEY (ID_Stop) REFERENCES STOP_DIM(ID_Stop), FOREIGN KEY (DriverKey) REFERENCES DRIVER_DIM(DriverKey), FOREIGN KEY (ID_Tram) REFERENCES TRAM_DIM(ID_Tram), FOREIGN KEY (ID_Time) REFERENCES TIME_DIM(ID_Time), FOREIGN KEY (ID_Boarding) REFERENCES BOARDING_DIM(ID_Boarding), FOREIGN KEY (ID_Repair) REFERENCES REPAIR_DIM(ID_Repair)
);
PRINT 'Schema recreated. STOP_DIM lat/lon are now VARCHAR.';