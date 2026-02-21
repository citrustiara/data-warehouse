USE master;
GO

-- =========================================================
-- ZASILANIE WYMIARÓW STATYCZNYCH (Bezpieczne / Idempotentne)
-- =========================================================
-- Skrypt sprawdza czy dane istniej¹, zanim spróbuje je wstawiæ.
-- Nie wykonuje DELETE ani TRUNCATE, aby nie uszkodziæ tabeli faktów.

PRINT 'Rozpoczynam sprawdzanie i ³adowanie wymiarów statycznych...';

-- =========================================================
-- 1. ZASILANIE DATE_DIM (Kalendarz)
-- =========================================================
PRINT 'Weryfikacja DATE_DIM...';

SET LANGUAGE Polish;

DECLARE @StartDate DATE = '2024-01-01';
DECLARE @EndDate DATE = '2025-12-31';
DECLARE @CurrentDate DATE = @StartDate;
DECLARE @ID_Date INT;

WHILE @CurrentDate <= @EndDate
BEGIN
    SET @ID_Date = YEAR(@CurrentDate) * 10000 + MONTH(@CurrentDate) * 100 + DAY(@CurrentDate);

    -- Sprawdzamy czy dany dzieñ ju¿ istnieje. Jeœli tak - pomijamy.
    IF NOT EXISTS (SELECT 1 FROM DATE_DIM WHERE ID_Date = @ID_Date)
    BEGIN
        DECLARE @DayOfWeek INT = DATEPART(dw, @CurrentDate);
        DECLARE @IsWorkingDay BIT = CASE WHEN @DayOfWeek IN (6, 7) THEN 0 ELSE 1 END; 
        DECLARE @HolidayName VARCHAR(100) = NULL;
        
        -- Sta³e œwiêta
        IF MONTH(@CurrentDate) = 1 AND DAY(@CurrentDate) = 1 SET @HolidayName = 'Nowy Rok';
        IF MONTH(@CurrentDate) = 1 AND DAY(@CurrentDate) = 6 SET @HolidayName = 'Trzech Króli';
        IF MONTH(@CurrentDate) = 5 AND DAY(@CurrentDate) = 1 SET @HolidayName = 'Œwiêto Pracy';
        IF MONTH(@CurrentDate) = 5 AND DAY(@CurrentDate) = 3 SET @HolidayName = 'Œwiêto Konstytucji 3 Maja';
        IF MONTH(@CurrentDate) = 8 AND DAY(@CurrentDate) = 15 SET @HolidayName = 'Wniebowziêcie NMP';
        IF MONTH(@CurrentDate) = 11 AND DAY(@CurrentDate) = 1 SET @HolidayName = 'Wszystkich Œwiêtych';
        IF MONTH(@CurrentDate) = 11 AND DAY(@CurrentDate) = 11 SET @HolidayName = 'Œwiêto Niepodleg³oœci';
        IF MONTH(@CurrentDate) = 12 AND DAY(@CurrentDate) = 25 SET @HolidayName = 'Bo¿e Narodzenie (1)';
        IF MONTH(@CurrentDate) = 12 AND DAY(@CurrentDate) = 26 SET @HolidayName = 'Bo¿e Narodzenie (2)';

        IF @HolidayName IS NOT NULL SET @IsWorkingDay = 0;

        INSERT INTO DATE_DIM (
            ID_Date, full_date, day_of_month, month, month_name, year, 
            day_of_week, day_of_week_name, is_working_day, holiday_name
        )
        VALUES (
            @ID_Date, @CurrentDate, DAY(@CurrentDate), MONTH(@CurrentDate), DATENAME(month, @CurrentDate), 
            YEAR(@CurrentDate), DATEPART(dw, @CurrentDate), DATENAME(weekday, @CurrentDate), @IsWorkingDay, @HolidayName
        );
    END;

    SET @CurrentDate = DATEADD(day, 1, @CurrentDate);
END;
PRINT 'DATE_DIM: Zweryfikowano.';
GO

-- =========================================================
-- 2. ZASILANIE TIME_DIM (Godziny i Minuty)
-- =========================================================
PRINT 'Weryfikacja TIME_DIM...';

DECLARE @Hour INT = 0;
DECLARE @Minute INT = 0;
DECLARE @Time TIME;
DECLARE @Category VARCHAR(30);
DECLARE @ID_Time INT;

WHILE @Hour < 24
BEGIN
    SET @Minute = 0;
    WHILE @Minute < 60
    BEGIN
        SET @ID_Time = (@Hour * 100) + @Minute;

        -- Sprawdzamy czy dana minuta ju¿ istnieje
        IF NOT EXISTS (SELECT 1 FROM TIME_DIM WHERE ID_Time = @ID_Time)
        BEGIN
            SET @Time = TIMEFROMPARTS(@Hour, @Minute, 0, 0, 0);
            
            SET @Category = CASE 
                WHEN @Hour BETWEEN 0 AND 5 THEN 'Noc'
                WHEN @Hour BETWEEN 6 AND 9 THEN 'Poranne szczyty'
                WHEN @Hour BETWEEN 10 AND 12 THEN 'Przedpo³udnie'
                WHEN @Hour BETWEEN 13 AND 16 THEN 'Popo³udnie'
                WHEN @Hour BETWEEN 17 AND 20 THEN 'Popo³udniowe szczyty'
                WHEN @Hour BETWEEN 21 AND 23 THEN 'Wieczór'
                ELSE 'Inne'
            END;
            
            INSERT INTO TIME_DIM (ID_Time, full_time, hour, minute, time_of_day_category)
            VALUES (@ID_Time, @Time, @Hour, @Minute, @Category);
        END;

        SET @Minute = @Minute + 1;
    END
    SET @Hour = @Hour + 1;
END;
PRINT 'TIME_DIM: Zweryfikowano.';
GO

-- =========================================================
-- 3. ZASILANIE JUNK DIMENSIONS (BOARDING_DIM, REPAIR_DIM)
-- =========================================================
PRINT 'Weryfikacja Junk Dimensions...';

-- A. BOARDING_DIM 
-- 1. Wiersz techniczny (-1)
IF NOT EXISTS (SELECT 1 FROM BOARDING_DIM WHERE ID_Boarding = -1)
BEGIN
    SET IDENTITY_INSERT BOARDING_DIM ON;
    INSERT INTO BOARDING_DIM (ID_Boarding, pickup_type, drop_off_type, description)
    VALUES (-1, -1, -1, 'Unknown');
    SET IDENTITY_INSERT BOARDING_DIM OFF;
END;

-- 2. Kombinacje (0, 1, 3) x (0, 1, 3)
-- U¿ywamy MERGE lub INSERT SELECT z WHERE NOT EXISTS dla ka¿dej kombinacji
INSERT INTO BOARDING_DIM (pickup_type, drop_off_type, description)
SELECT src.p_val, src.d_val, CONCAT('Pickup: ', src.p_val, ', DropOff: ', src.d_val)
FROM (
    SELECT p.val AS p_val, d.val AS d_val
    FROM (SELECT 0 AS val UNION ALL SELECT 1 UNION ALL SELECT 3) p
    CROSS JOIN (SELECT 0 AS val UNION ALL SELECT 1 UNION ALL SELECT 3) d
) AS src
WHERE NOT EXISTS (
    SELECT 1 FROM BOARDING_DIM tgt 
    WHERE tgt.pickup_type = src.p_val AND tgt.drop_off_type = src.d_val
);


-- B. REPAIR_DIM
-- 1. Wiersz techniczny (-1)
IF NOT EXISTS (SELECT 1 FROM REPAIR_DIM WHERE ID_Repair = -1)
BEGIN
    SET IDENTITY_INSERT REPAIR_DIM ON;
    INSERT INTO REPAIR_DIM (ID_Repair, is_on_site_repair, on_site_repair_possible, description)
    VALUES (-1, 0, 0, 'Unknown');
    SET IDENTITY_INSERT REPAIR_DIM OFF;
END;

-- 2. Kombinacje (0, 1) x (0, 1)
INSERT INTO REPAIR_DIM (is_on_site_repair, on_site_repair_possible, description)
SELECT src.r_val, src.p_val, CONCAT('OnSite: ', src.r_val, ', Possible: ', src.p_val)
FROM (
    SELECT r.val AS r_val, p.val AS p_val
    FROM (SELECT 0 AS val UNION ALL SELECT 1) r
    CROSS JOIN (SELECT 0 AS val UNION ALL SELECT 1) p
) AS src
WHERE NOT EXISTS (
    SELECT 1 FROM REPAIR_DIM tgt 
    WHERE tgt.is_on_site_repair = src.r_val AND tgt.on_site_repair_possible = src.p_val
);

PRINT 'Junk Dimensions: Zweryfikowano.';
PRINT '===========================================';
PRINT 'GOTOWE. Baza wymiarów statycznych zaktualizowana bezpiecznie.';
GO