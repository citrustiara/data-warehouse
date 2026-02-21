USE master;
GO

-- =========================================================
-- 1. NAPRAWA STRUKTURY STAGINGU (musi pasowaæ do pliku!)
-- =========================================================
IF OBJECT_ID('stg.Routes', 'U') IS NOT NULL DROP TABLE stg.Routes;

-- Tworzymy tabelê z 8 kolumnami (bez route_url), tak jak w Twoim pliku routes.txt
CREATE TABLE stg.Routes (
    route_id VARCHAR(50),
    agency_id VARCHAR(50),
    route_short_name VARCHAR(50),
    route_long_name VARCHAR(255),
    route_desc VARCHAR(MAX),
    route_type VARCHAR(50),
    -- route_url VARCHAR(255),  <-- USUNIÊTE, BO NIE MA TEGO W PLIKU
    route_color VARCHAR(50),
    route_text_color VARCHAR(50)
);

-- =========================================================
-- 2. BULK INSERT (Windows style 0x0d0a)
-- =========================================================
TRUNCATE TABLE stg.Routes;

BULK INSERT stg.Routes 
FROM 'C:\Dane\routes.txt' 
WITH (
    FIRSTROW = 2, 
    FIELDTERMINATOR = ',', 
    ROWTERMINATOR = '0x0d0a', -- Standard Windows (CR+LF)
    CODEPAGE = '65001'
);

-- Sprawdzenie (teraz powinno byæ 11 wierszy)
SELECT COUNT(*) AS LiczbaTras FROM stg.Routes;

-- =========================================================
-- 3. MERGE DO WYMIARU
-- =========================================================
MERGE INTO ROUTE_DIM AS target
USING stg.Routes AS source
ON target.ID_Route = CAST(source.route_id AS INT)
WHEN MATCHED THEN
    UPDATE SET
        route_short_name = source.route_short_name,
        route_long_name = ISNULL(source.route_long_name, 'Brak'), 
        route_color = CASE WHEN source.route_color IS NULL THEN '#FFFFFF' ELSE CONCAT('#', REPLACE(source.route_color, CHAR(13), '')) END
WHEN NOT MATCHED BY TARGET THEN
    INSERT (ID_Route, route_short_name, route_long_name, route_color)
    VALUES (CAST(source.route_id AS INT), source.route_short_name, ISNULL(source.route_long_name, 'Brak'), 
            CASE WHEN source.route_color IS NULL THEN '#FFFFFF' ELSE CONCAT('#', REPLACE(source.route_color, CHAR(13), '')) END);

PRINT 'Gotowe.';