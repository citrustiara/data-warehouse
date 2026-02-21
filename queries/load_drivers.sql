USE master;
SET NOCOUNT ON;

-- 1. STAGING
TRUNCATE TABLE stg.Drivers;
BULK INSERT stg.Drivers 
FROM 'C:\Dane\drivers.csv' 
WITH (FIRSTROW = 2, FIELDTERMINATOR = ',', ROWTERMINATOR = '0x0a', CODEPAGE = '65001');

-- =============================================================
-- LOGIKA SCD TYPE 2
-- =============================================================

-- A. Wstawiamy ZUPE£NIE NOWYCH kierowców
-- ZMIANA: Ustawiamy datê startow¹ na '2020-01-01' zamiast GETDATE(),
-- aby pokryæ historyczne dane w tabeli faktów.
INSERT INTO DRIVER_DIM (ID_Driver, driver_pesel, driver_name, driver_surname, experience_category, row_effective_date, row_expiration_date, IsCurrent)
SELECT 
    CAST(s.driver_id AS INT), 
    s.PESEL, 
    TRIM(s.driver_name), 
    TRIM(s.driver_surname), 
    TRIM(REPLACE(s.experience_category, CHAR(13), '')), 
    '2020-01-01', -- <--- TU ZMIANA (Sztywna data przesz³a dla Initial Load)
    NULL,      
    1          
FROM stg.Drivers s
WHERE NOT EXISTS (SELECT 1 FROM DRIVER_DIM d WHERE d.ID_Driver = CAST(s.driver_id AS INT));

-- B. Wykrywamy ZMIANY u istniej¹cych kierowców
-- (Tylko dla tych, którzy s¹ obecnie oznaczeni jako IsCurrent=1)
IF OBJECT_ID('tempdb..#DriversChanges') IS NOT NULL DROP TABLE #DriversChanges;

SELECT 
    d.ID_Driver, -- Klucz biznesowy
    s.PESEL,
    TRIM(s.driver_name) as driver_name,
    TRIM(s.driver_surname) as driver_surname,
    TRIM(REPLACE(s.experience_category, CHAR(13), '')) as experience_category
INTO #DriversChanges
FROM stg.Drivers s 
JOIN DRIVER_DIM d ON d.ID_Driver = CAST(s.driver_id AS INT)
WHERE d.IsCurrent = 1 -- Porównujemy tylko z aktualn¹ wersj¹ w bazie
  AND (
      ISNULL(d.experience_category, '') <> ISNULL(TRIM(REPLACE(s.experience_category, CHAR(13), '')), '') OR 
      ISNULL(d.driver_surname, '') <> ISNULL(TRIM(s.driver_surname), '') OR
      ISNULL(d.driver_name, '') <> ISNULL(TRIM(s.driver_name), '')
  );

-- C. "Zamykamy" STARE rekordy (Expire)
-- Tutaj zostaje GETDATE(), bo to bie¿¹ca zmiana
UPDATE d
SET 
    row_expiration_date = GETDATE(),
    IsCurrent = 0
FROM DRIVER_DIM d 
JOIN #DriversChanges c ON d.ID_Driver = c.ID_Driver
WHERE d.IsCurrent = 1;

-- D. Wstawiamy NOWE wersje rekordów (Insert New Version)
-- Tutaj te¿ zostaje GETDATE() dla nowych zmian
INSERT INTO DRIVER_DIM (ID_Driver, driver_pesel, driver_name, driver_surname, experience_category, row_effective_date, row_expiration_date, IsCurrent)
SELECT 
    ID_Driver, 
    PESEL, 
    driver_name, 
    driver_surname, 
    experience_category, 
    GETDATE(), -- Nowa wersja wa¿na od momentu uruchomienia skryptu
    NULL, 
    1
FROM #DriversChanges;

-- Sprz¹tanie
DROP TABLE #DriversChanges;

-- E. Obs³uga wiersza "Nieznany" (-1)
IF NOT EXISTS (SELECT 1 FROM DRIVER_DIM WHERE ID_Driver = -1)
BEGIN
    -- W³¹czamy wstawianie do kolumny IDENTITY (DriverKey)
    SET IDENTITY_INSERT DRIVER_DIM ON; 
    
    INSERT INTO DRIVER_DIM (DriverKey, ID_Driver, driver_pesel, driver_name, driver_surname, experience_category, row_effective_date, row_expiration_date, IsCurrent)
    VALUES (-1, -1, '00000000000', 'Nieznany', 'Kierowca', 'Brak', '1900-01-01', NULL, 1);
    
    SET IDENTITY_INSERT DRIVER_DIM OFF;
END;

PRINT 'SCD2 dla Kierowców zakoñczone (Nowi kierowcy z dat¹ 2020-01-01).';
GO