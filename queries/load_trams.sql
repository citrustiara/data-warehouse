TRUNCATE TABLE stg.Trams;
BULK INSERT stg.Trams FROM 'C:\Dane\trams.csv' WITH (FIRSTROW = 2, FIELDTERMINATOR = ',', ROWTERMINATOR = '0x0a', CODEPAGE = '65001');

MERGE INTO TRAM_DIM AS target
USING stg.Trams AS source
ON target.ID_Tram = CAST(source.tram_id AS INT)
WHEN MATCHED THEN
    UPDATE SET 
        model = source.model,
        production_year = YEAR(CAST(TRIM(source.production_date) AS DATE)),
        last_service_date = CAST(REPLACE(source.last_service_date, CHAR(13), '') AS DATE)
WHEN NOT MATCHED BY TARGET THEN
    INSERT (ID_Tram, model, production_year, last_service_date)
    VALUES (CAST(source.tram_id AS INT), source.model, YEAR(CAST(TRIM(source.production_date) AS DATE)), CAST(REPLACE(source.last_service_date, CHAR(13), '') AS DATE));