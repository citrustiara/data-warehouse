USE master;
GO

-- =========================================================
-- 0. ZABEZPIECZENIE WSZYSTKICH WYMIARÓW (Critical Safety Check)
-- =========================================================
-- Upewniamy siê, ¿e rekordy techniczne (-1) istniej¹ we WSZYSTKICH wymiarach.
-- Zapobiegnie to b³êdom Foreign Key, gdy w plikach transakcyjnych pojawi¹ siê ID spoza s³owników.

-- 1. Malfunctions
IF NOT EXISTS (SELECT 1 FROM MALFUNCTION_DIM WHERE ID_Malfunction = -1)
    INSERT INTO MALFUNCTION_DIM (ID_Malfunction, malfunction_type, malfunction_description) 
    VALUES (-1, 'Brak', 'Brak awarii');

-- 2. Trams (TU BY£ B£¥D)
IF NOT EXISTS (SELECT 1 FROM TRAM_DIM WHERE ID_Tram = -1)
    INSERT INTO TRAM_DIM (ID_Tram, model, production_year, last_service_date) 
    VALUES (-1, 'Unknown', 1900, '1900-01-01');

-- 3. Routes
IF NOT EXISTS (SELECT 1 FROM ROUTE_DIM WHERE ID_Route = -1)
    INSERT INTO ROUTE_DIM (ID_Route, route_short_name, route_long_name, route_color) 
    VALUES (-1, 'UNK', 'Unknown Route', '#000000');

-- 4. Stops
IF NOT EXISTS (SELECT 1 FROM STOP_DIM WHERE ID_Stop = -1)
    INSERT INTO STOP_DIM (ID_Stop, stop_name, stop_lat, stop_lon, stop_code, district) 
    VALUES (-1, 'Unknown Stop', 0, 0, 'UNK', 'Unknown');

-- 5. Time
IF NOT EXISTS (SELECT 1 FROM TIME_DIM WHERE ID_Time = -1)
    INSERT INTO TIME_DIM (ID_Time, full_time, hour, minute, time_of_day_category)
    VALUES (-1, '00:00:00', -1, -1, 'Unknown');

-- 6. Date (Techniczna data b³êdu 19000101)
IF NOT EXISTS (SELECT 1 FROM DATE_DIM WHERE ID_Date = 19000101)
    INSERT INTO DATE_DIM (ID_Date, full_date, day_of_month, month, month_name, year, day_of_week, day_of_week_name, is_working_day, holiday_name)
    VALUES (19000101, '1900-01-01', 1, 1, 'January', 1900, 1, 'Monday', 1, 'Technical Date');

-- 7. Repairs
IF NOT EXISTS (SELECT 1 FROM REPAIR_DIM WHERE ID_Repair = -1)
    BEGIN
        SET IDENTITY_INSERT REPAIR_DIM ON;
        INSERT INTO REPAIR_DIM (ID_Repair, is_on_site_repair, on_site_repair_possible, description) 
        VALUES (-1, 0, 0, 'Unknown');
        SET IDENTITY_INSERT REPAIR_DIM OFF;
    END

-- 8. Boarding
IF NOT EXISTS (SELECT 1 FROM BOARDING_DIM WHERE ID_Boarding = -1)
    BEGIN
        SET IDENTITY_INSERT BOARDING_DIM ON;
        INSERT INTO BOARDING_DIM (ID_Boarding, pickup_type, drop_off_type, description) 
        VALUES (-1, -1, -1, 'Unknown');
        SET IDENTITY_INSERT BOARDING_DIM OFF;
    END

-- 9. Drivers
IF NOT EXISTS (SELECT 1 FROM DRIVER_DIM WHERE ID_Driver = -1)
    BEGIN
        SET IDENTITY_INSERT DRIVER_DIM ON;
        INSERT INTO DRIVER_DIM (DriverKey, ID_Driver, driver_pesel, driver_name, driver_surname, experience_category, row_effective_date, row_expiration_date, IsCurrent)
        VALUES (-1, -1, '00000000000', 'Nieznany', 'Kierowca', 'Brak', '1900-01-01', NULL, 1);
        SET IDENTITY_INSERT DRIVER_DIM OFF;
    END

PRINT 'Wymiary zabezpieczone rekordami technicznymi.';

-- =========================================================
-- 1. STAGING (StopTimes)
-- =========================================================
IF OBJECT_ID('stg.StopTimes', 'U') IS NOT NULL DROP TABLE stg.StopTimes;

CREATE TABLE stg.StopTimes (
    id VARCHAR(255),
    trip_id VARCHAR(255),
    arrival_time VARCHAR(255),
    departure_time VARCHAR(255),
    stop_id VARCHAR(255),
    stop_sequence VARCHAR(255),
    pickup_type VARCHAR(255),
    drop_off_type VARCHAR(255),
    stop_headsign VARCHAR(255),
    delay_minutes VARCHAR(255),
    malfunction_id VARCHAR(255)
);

TRUNCATE TABLE stg.StopTimes;

BULK INSERT stg.StopTimes 
FROM 'C:\Dane\stop_times2.txt' 
WITH (FIRSTROW = 2, FIELDTERMINATOR = ',', ROWTERMINATOR = '0x0a', CODEPAGE = '65001');

PRINT 'Staging za³adowany.';

-- =========================================================
-- 2. CZYSZCZENIE FAKTÓW
-- =========================================================
IF OBJECT_ID('TRIP_OPERATIONS_FACT', 'U') IS NOT NULL 
    DELETE FROM TRIP_OPERATIONS_FACT;

PRINT 'Fakty wyczyszczone. Start przetwarzania...';

-- =========================================================
-- 3. LOGIKA + INSERT
-- =========================================================
;WITH PreCalculatedData AS (
    SELECT 
        st.trip_id,
        st.stop_id,
        st.stop_sequence,
        REPLACE(REPLACE(st.malfunction_id, CHAR(13), ''), CHAR(10), '') AS malfunction_id,
        st.pickup_type,
        st.drop_off_type,
        TRY_CAST(NULLIF(st.delay_minutes, '') AS DECIMAL(5,2)) AS delay_minutes,
        TRY_CAST(SUBSTRING(st.trip_id, 2, 8) AS DATE) AS TripDate,
        (TRY_CAST(LEFT(st.arrival_time, 2) AS INT) * 60) + TRY_CAST(SUBSTRING(st.arrival_time, 4, 2) AS INT) AS TimeInMinutes,
        CASE 
            WHEN TRY_CAST(LEFT(st.arrival_time, 2) AS INT) >= 24 THEN -1 
            ELSE (TRY_CAST(LEFT(st.arrival_time, 2) AS INT) * 100) + TRY_CAST(SUBSTRING(st.arrival_time, 4, 2) AS INT)
        END AS ID_Time
    FROM stg.StopTimes st
)
, CalculatedMeasures AS (
    SELECT 
        pc.*,
        ISNULL(pc.TimeInMinutes - LAG(pc.TimeInMinutes) OVER (PARTITION BY pc.trip_id ORDER BY TRY_CAST(pc.stop_sequence AS INT)), 0) AS planned_travel_time_minutes,
        pc.delay_minutes - ISNULL(LAG(pc.delay_minutes) OVER (PARTITION BY pc.trip_id ORDER BY TRY_CAST(pc.stop_sequence AS INT)), 0) AS delay_caused_minutes
    FROM PreCalculatedData pc
)
, EnrichedData AS (
    SELECT 
        cm.trip_id,
        ISNULL((YEAR(cm.TripDate) * 10000) + (MONTH(cm.TripDate) * 100) + DAY(cm.TripDate), 19000101) AS ID_Date,
        ISNULL(cm.ID_Time, -1) AS ID_Time,
        
        -- BEZPIECZNE MAPOWANIE NA WYMIARY (Mapowanie na -1 jeœli brak w s³owniku)
        ISNULL(r.ID_Route, -1) AS ID_Route,
        ISNULL(s.ID_Stop, -1) AS ID_Stop,
        ISNULL(tr.ID_Tram, -1) AS ID_Tram, -- Tu by³ problem: teraz mapuje na -1 (Unknown) jeœli brak tramwaju
        
        ISNULL(d.DriverKey, (SELECT TOP 1 DriverKey FROM DRIVER_DIM WHERE ID_Driver = -1)) AS DriverKey,
        ISNULL(m.ID_Malfunction, -1) AS ID_Malfunction,
        ISNULL(b.ID_Boarding, -1) AS ID_Boarding,
        ISNULL((SELECT TOP 1 ID_Repair FROM REPAIR_DIM WHERE description LIKE 'Brak%'), -1) AS ID_Repair,
        
        cm.delay_minutes,
        TRY_CAST(cm.stop_sequence AS SMALLINT) AS stop_sequence,
        CAST(cm.planned_travel_time_minutes AS DECIMAL(7,2)) AS planned_travel_time_minutes,
        CAST(cm.delay_caused_minutes AS DECIMAL(7,2)) AS delay_caused_minutes,
        
        CASE WHEN TRY_CAST(cm.malfunction_id AS INT) > 0 THEN CAST(cm.delay_minutes AS SMALLINT) ELSE NULL END AS repair_duration_minutes

    FROM CalculatedMeasures cm
    INNER JOIN stg.Trips t ON cm.trip_id = t.trip_id
    
    -- LEFT JOINY (Bezpieczne - jeœli brak, wstawi siê -1 z ISNULL powy¿ej)
    LEFT JOIN ROUTE_DIM r ON r.ID_Route = TRY_CAST(t.route_id AS INT)
    LEFT JOIN STOP_DIM s  ON s.ID_Stop  = TRY_CAST(cm.stop_id AS INT)
    LEFT JOIN TRAM_DIM tr ON tr.ID_Tram = TRY_CAST(t.tram_id AS INT)
    LEFT JOIN MALFUNCTION_DIM m ON m.ID_Malfunction = TRY_CAST(cm.malfunction_id AS INT)
    LEFT JOIN BOARDING_DIM b ON b.pickup_type = TRY_CAST(cm.pickup_type AS INT) AND b.drop_off_type = TRY_CAST(cm.drop_off_type AS INT)
    LEFT JOIN DRIVER_DIM d ON d.ID_Driver = TRY_CAST(t.driver_id AS INT) 
        AND cm.TripDate >= d.row_effective_date 
        AND (d.row_expiration_date IS NULL OR cm.TripDate < d.row_expiration_date)
    WHERE cm.TripDate IS NOT NULL
)
, DeduplicatedData AS (
    SELECT 
        *,
        ROW_NUMBER() OVER(
            PARTITION BY 
                trip_id, ID_Date, ID_Time, ID_Stop, ID_Route, ID_Tram, 
                DriverKey, ID_Malfunction, ID_Boarding, ID_Repair
            ORDER BY stop_sequence
        ) as rn
    FROM EnrichedData
)
INSERT INTO TRIP_OPERATIONS_FACT (
    ID_Trip, ID_Date, ID_Time, ID_Route, ID_Stop, ID_Tram, DriverKey, ID_Malfunction, ID_Boarding, ID_Repair, 
    delay_minutes, stop_sequence, planned_travel_time_minutes, delay_caused_minutes, repair_duration_minutes
)
SELECT 
    trip_id, ID_Date, ID_Time, ID_Route, ID_Stop, ID_Tram, DriverKey, ID_Malfunction, ID_Boarding, ID_Repair, 
    delay_minutes, stop_sequence, planned_travel_time_minutes, delay_caused_minutes, repair_duration_minutes
FROM DeduplicatedData
WHERE rn = 1;

PRINT 'SUKCES: Fakty za³adowane poprawnie (wszystkie braki zmapowane na -1).';
GO