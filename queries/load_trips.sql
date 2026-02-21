-- =========================================================
-- PLIK: load_trips.sql
-- OPIS: £adowanie pliku trips.txt o niestandardowej strukturze (10 kolumn)
-- =========================================================

USE master;
GO

-- 1. Usuwamy star¹ definicjê i tworzymy now¹, idealnie pasuj¹c¹ do pliku
IF OBJECT_ID('stg.Trips', 'U') IS NOT NULL DROP TABLE stg.Trips;

PRINT 'Tworzenie tabeli stg.Trips (10 kolumn)...';

-- Kolejnoœæ kolumn MUSI byæ taka sama jak w pliku CSV:
-- trip_id, driver_id, tram_id, route_id, date, trip_headsign, trip_short_name, direction_id, shape_id, wheelchair_accessible
CREATE TABLE stg.Trips (
    trip_id VARCHAR(255),
    driver_id VARCHAR(255),
    tram_id VARCHAR(255),
    route_id VARCHAR(255),
    trip_date VARCHAR(255), -- w pliku "date", zmieniam nazwê by nie kolidowa³a
    trip_headsign VARCHAR(255),
    trip_short_name VARCHAR(255),
    direction_id VARCHAR(255),
    shape_id VARCHAR(255),
    wheelchair_accessible VARCHAR(255)
);

-- 2. BULK INSERT
-- Zak³adam format Linux (LF = 0x0a), bo tak mia³eœ wczeœniej. 
-- Jeœli plik jest z Windowsa, zmieñ ROWTERMINATOR na '0x0d0a'.
BULK INSERT stg.Trips 
FROM 'C:\Dane\trips2.txt' 
WITH (
    FIRSTROW = 2, -- Pomijamy nag³ówek
    FIELDTERMINATOR = ',', 
    ROWTERMINATOR = '0x0a', 
    CODEPAGE = '65001'
);

PRINT 'Dane za³adowane do stg.Trips.';

-- 3. MERGE DO WYMIARU TRIP_DIM
-- Wymiar TRIP_DIM nie przechowuje driver_id/tram_id/date, te pola zostaj¹ w STG dla Faktu.
;WITH UniqueTrips AS (
    SELECT 
        trip_id, 
        trip_headsign, 
        trip_short_name, 
        direction_id, 
        wheelchair_accessible,
        ROW_NUMBER() OVER(PARTITION BY trip_id ORDER BY trip_id) as row_num
    FROM stg.Trips
)
MERGE INTO TRIP_DIM AS target
USING (SELECT * FROM UniqueTrips WHERE row_num = 1) AS source
ON target.ID_Trip = source.trip_id
WHEN MATCHED THEN
    UPDATE SET
        trip_headsign = LEFT(source.trip_headsign, 255),
        trip_short_name = LEFT(source.trip_short_name, 50),
        direction_id = TRY_CAST(REPLACE(REPLACE(source.direction_id, CHAR(13), ''), CHAR(10), '') AS BIT),
        wheelchair_accessible = TRY_CAST(REPLACE(REPLACE(source.wheelchair_accessible, CHAR(13), ''), CHAR(10), '') AS BIT)
WHEN NOT MATCHED BY TARGET THEN
    INSERT (ID_Trip, trip_headsign, trip_short_name, direction_id, wheelchair_accessible)
    VALUES (
        source.trip_id, 
        LEFT(source.trip_headsign, 255), 
        LEFT(source.trip_short_name, 50), 
        TRY_CAST(REPLACE(REPLACE(source.direction_id, CHAR(13), ''), CHAR(10), '') AS BIT), 
        TRY_CAST(REPLACE(REPLACE(source.wheelchair_accessible, CHAR(13), ''), CHAR(10), '') AS BIT)
    );

-- 4. REKORD TECHNICZNY
IF NOT EXISTS (SELECT 1 FROM TRIP_DIM WHERE ID_Trip = '-1')
    INSERT INTO TRIP_DIM VALUES ('-1', 'Unknown', 'UNK', 0, 0);

PRINT 'Gotowe. Tabela stg.Trips ma teraz poprawne kolumny driver_id i tram_id.';
GO