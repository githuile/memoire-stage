--SETUP-01-ModelUpdateEmpty

UPDATE BOWEN
SET
    Model = DLookUp (
        "[Model]",
        "BOWEN",
        "UHF100name='" & [UHF100name] & "' AND [Model] Is Not Null AND Trim([Model] & '')<>''"
    )
WHERE
    [Model] IS NULL
    OR Trim([Model] & '') = '';

--SETUP-02-ModelUpdateUHF100-V2

UPDATE BOWEN
SET
    Model = "UHF100 V2"
WHERE
    [Model] = "UHF100 2 GHz";

--SETUP-03-ModelNormalise-1

UPDATE bowen
SET
    ModelNormalise = IIf(
        Model = "UHF100",
        1,
        IIf(Model = "UHF100 V2", 2, 0)
    );

--SETUP-04-ModelNormalise-2

SELECT DISTINCT
    SerialNumberNormalise
INTO
    temp_model1_serials
FROM
    bowen
WHERE
    ModelNormalise = 1;

--SETUP-05-ModelNormalise-3

SELECT DISTINCT
    SerialNumberNormalise
INTO
    temp_model2_serials
FROM
    bowen
WHERE
    ModelNormalise = 2;

--SETUP-06-ModelNormalise-4

UPDATE bowen
SET
    ModelNormalise = IIf(
        Year(StartTime) >= 2025,
        2,
        IIf(
            Year(StartTime) <= 2020,
            1,
            IIf(
                DCount (
                    "*",
                    "temp_model1_serials",
                    "SerialNumberNormalise = '" & SerialNumberNormalise & "'"
                ) > 0,
                1,
                IIf(
                    DCount (
                        "*",
                        "temp_model2_serials",
                        "SerialNumberNormalise = '" & SerialNumberNormalise & "'"
                    ) > 0,
                    2,
                    ModelNormalise
                )
            )
        )
    )
WHERE
    ModelNormalise = 0
    OR ModelNormalise IS NULL;

--SETUP-07-SerialNumberNorlalise-1

UPDATE bowen
SET
    SerialNumber = IIf(
        Left(SerialNumber, 1) = " ",
        Trim(SerialNumber),
        IIf(
            Left(Trim(SerialNumber), 3) = "BF "
            OR Left(Trim(SerialNumber), 3) = "BF:",
            "BF-" & Mid (Trim(SerialNumber), 4),
            IIf(
                Left(Trim(SerialNumber), 5) = "BF : ",
                "BF-" & Mid (Trim(SerialNumber), 6),
                SerialNumber
            )
        )
    );

--SETUP-08-SerialNumberNormalise-2

UPDATE bowen
SET
    SerialNumberNormalise = UCase (
        IIf(
            InStr (SerialNumber, " ") > 0,
            Left(SerialNumber, InStr (SerialNumber, " ") -1),
            IIf(
                InStr (SerialNumber, "_") > 0,
                Left(SerialNumber, InStr (SerialNumber, "_") -1),
                SerialNumber
            )
        )
    );

--SETUP-09-SerialNumberNormalise-3

UPDATE bowen
SET
    SerialNumberNormalise = IIf(
        InStr (SerialNumberNormalise, ".") > 0,
        Left(
            SerialNumberNormalise,
            InStr (SerialNumberNormalise, ".") -1
        ) & "." & Right(
            "000" & Mid (
                SerialNumberNormalise,
                InStr (SerialNumberNormalise, ".") + 1
            ),
            3
        ),
        SerialNumberNormalise
    )
WHERE
    InStr (SerialNumberNormalise, ".") > 0;

--SETUP-10-Prod_HorsProd-1

UPDATE bowen
SET
    Prod = "HORS_PROD"
WHERE
    SerialNumber LIKE '*SAV*'
    OR SerialNumber LIKE '*Sav*'
    OR SerialNumber LIKE '*sav*'
    OR SerialNumber LIKE '*20min*'
    OR SerialNumber LIKE '*20 min*'
    OR SerialNumber LIKE '*maj v4.10*';

--SETUP-11-Prod_HorsProd-2

UPDATE bowen
SET
    Prod = "PROD"
WHERE
    NOT Prod = "HORS_PROD";

--SETUP-12-BowenReduit

SELECT
    StartTime,
    StationID,
    TotalTime,
    StepCount,
    UUTresult,
    ModelNormalise,
    SerialNumberNormalise,
    Prod
INTO
    BOWEN_REDUIT
FROM
    BOWEN
WHERE
    Year(StartTime) >= 2020
    AND StepCount <= 39
ORDER BY
    StartTime;