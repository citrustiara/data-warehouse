-- =========================================================
-- PLIK: load_stops.sql
-- ZMIANA: Brak konwersji na DECIMAL (traktujemy jako tekst)
-- =========================================================

TRUNCATE TABLE stg.Stops;

-- Pozostawiamy 0x0d0a, bo zazwyczaj przy stops.txt to dzia³a³o
BULK INSERT stg.Stops 
FROM 'C:\Dane\stops.txt' 
WITH (
    FIRSTROW = 2, 
    FIELDTERMINATOR = ',', 
    ROWTERMINATOR = '0x0d0a', 
    CODEPAGE = '65001'
);

MERGE INTO STOP_DIM AS target
USING stg.Stops AS source
ON target.ID_Stop = TRY_CAST(source.stop_id AS INT)
WHEN MATCHED THEN
    UPDATE SET
        stop_name = LEFT(source.stop_name, 100),
        -- Bez TRY_CAST, po prostu tekst
        stop_lat = LEFT(source.stop_lat, 50),
        stop_lon = LEFT(source.stop_lon, 50),
        stop_code = LEFT(REPLACE(source.stop_code, CHAR(13), ''), 50), 
        district = 'Gdañsk'
WHEN NOT MATCHED BY TARGET AND TRY_CAST(source.stop_id AS INT) IS NOT NULL THEN
    INSERT (ID_Stop, stop_name, stop_lat, stop_lon, stop_code, district)
    VALUES (
        TRY_CAST(source.stop_id AS INT), 
        LEFT(source.stop_name, 100), 
        LEFT(source.stop_lat, 50),  -- Tekst
        LEFT(source.stop_lon, 50),  -- Tekst
        LEFT(REPLACE(source.stop_code, CHAR(13), ''), 50), 
        'Gdañsk'
    );