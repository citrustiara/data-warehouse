TRUNCATE TABLE stg.Malfunctions;
BULK INSERT stg.Malfunctions FROM 'C:\Dane\malfunctions.csv' WITH (FIRSTROW = 2, FIELDTERMINATOR = ',', ROWTERMINATOR = '0x0a', CODEPAGE = '65001');

MERGE INTO MALFUNCTION_DIM AS target
USING stg.Malfunctions AS source
ON target.ID_Malfunction = CAST(source.malfunction_id AS INT)
WHEN MATCHED THEN
    UPDATE SET
        malfunction_type = source.type,
        malfunction_description = REPLACE(source.description, CHAR(13), '')
WHEN NOT MATCHED BY TARGET THEN
    INSERT (ID_Malfunction, malfunction_type, malfunction_description)
    VALUES (CAST(source.malfunction_id AS INT), source.type, REPLACE(source.description, CHAR(13), ''));

IF NOT EXISTS (SELECT 1 FROM MALFUNCTION_DIM WHERE ID_Malfunction = -1)
    INSERT INTO MALFUNCTION_DIM VALUES (-1, 'Brak', 'Brak awarii');