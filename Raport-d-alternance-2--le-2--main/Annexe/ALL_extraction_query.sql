--ALL-00-BowenProd

SELECT
    *
INTO
    BOWEN_PROD_ALL
FROM
    BOWEN_REDUIT
WHERE
    Prod = "PROD";

--ALl-01-TableEssaisStatuts

SELECT
    StartTime,
    SerialNumberNormalise,
    ModelNormalise,
    TotalTime,
    IIf(UUTresult = "Passed", True, False) AS Passed,
    IIf(UUTresult = "Failed", True, False) AS Failed,
    IIf(UUTresult = "Terminated", True, False) AS Terminated,
    IIf(UUTresult = "Error", True, False) AS Error
INTO
    ALL_table_essais_statut
FROM
    BOWEN_PROD_ALL
ORDER BY
    StartTime;

--ALL-02-TableFirstPass

SELECT
    SerialNumberNormalise,
    Min(StartTime) AS FirstPassTime
INTO
    ALL_table_first_pass
FROM
    ALL_table_essais_statut
WHERE
    Passed = True
GROUP BY
    SerialNumberNormalise;

--ALL-03-TempLastIsError

SELECT
    SerialNumberNormalise,
    Max(StartTime) AS LastTime,
    Max(IIf(Error = True, 1, 0)) AS LastIsError
INTO
    ALL_temp_LastIsError
FROM
    ALL_table_essais_statut AS bht1
WHERE
    NOT EXISTS (
        SELECT
            1
        FROM
            ALL_table_first_pass AS bht2
        WHERE
            bht2.SerialNumberNormalise = bht1.SerialNumberNormalise
    )
GROUP BY
    SerialNumberNormalise;

--ALL-04-TableAttemptCount

SELECT
    n.SerialNumberNormalise,
    IIf(
        EXISTS (
            SELECT
                1
            FROM
                ALL_table_first_pass
            WHERE
                SerialNumberNormalise = n.SerialNumberNormalise
        ),
        (
            SELECT
                Count(*)
            FROM
                ALL_table_essais_statut AS sub
            WHERE
                sub.SerialNumberNormalise = n.SerialNumberNormalise
                AND sub.StartTime <= (
                    SELECT
                        FirstPassTime
                    FROM
                        ALL_table_first_pass
                    WHERE
                        SerialNumberNormalise = n.SerialNumberNormalise
                )
        ),
        IIf(
            EXISTS (
                SELECT
                    1
                FROM
                    ALL_temp_LastIsError
                WHERE
                    SerialNumberNormalise = n.SerialNumberNormalise
                    AND LastIsError = 1
            ),
            -2,
            -1
        )
    ) AS AttemptCount,
    (
        SELECT
            Max(StartTime)
        FROM
            ALL_table_essais_statut AS t1
        WHERE
            t1.SerialNumberNormalise = n.SerialNumberNormalise
    ) AS EndDate,
    ModelNormalise
INTO
    ALL_table_AttemptCount
FROM
    (
        SELECT DISTINCT
            SerialNumberNormalise,
            ModelNormalise
        FROM
            ALL_table_essais_statut
    ) AS n;

--ALL-05-TableEssaisStatutTotal

SELECT
    Sum(IIf(Passed = True, 1, 0)) AS Essai_Passed,
    Sum(IIf(Failed = True, 1, 0)) AS Essai_Failed,
    Sum(IIf(Terminated = True, 1, 0)) AS Essai_Terminated,
    Sum(IIf(Error = True, 1, 0)) AS Essai_Error,
    Count(*) AS Total,
    Year(StartTime) AS Annee
INTO
    ALL_table_essais_statut_total
FROM
    ALL_table_essais_statut
GROUP BY
    Year(StartTime);

--ALL-06-TempNbProd_HorsProd

SELECT
    Year(Max(StartTime)) AS Annee,
    SerialNumberNormalise
INTO
    ALL_temp_Nb_HorsProd
FROM
    BOWEN_REDUIT
WHERE
    Prod = "HORS_PROD"
GROUP BY
    SerialNumberNormalise;

--ALL-07-TableNbModules

SELECT
    Year(FirstPass) AS Annee,
    Avg(TimeToFirstPassHours) AS TTFP_moyen,
    DMedian (
        "TimeToFirstPassHours",
        "ALL_temp_timediff",
        "FirstPass IS NOT NULL AND Year(FirstPass) = " & Year(FirstPass)
    ) AS TTFP_median
INTO
    ALL_TTFP
FROM
    ALL_temp_timediff
WHERE
    FirstPass IS NOT NULL
GROUP BY
    Year(FirstPass);

--ALL-08-TableEffortPassMoyenne

SELECT
    Year(FirstPass) AS Annee,
    Avg(TimeToFirstPassHours) AS TTFP_moyen,
    DMedian (
        "TimeToFirstPassHours",
        "ALL_temp_timediff",
        "FirstPass IS NOT NULL AND Year(FirstPass) = " & Year(FirstPass)
    ) AS TTFP_median
INTO
    ALL_TTFP
FROM
    ALL_temp_timediff
WHERE
    FirstPass IS NOT NULL
GROUP BY
    Year(FirstPass);

--ALL-09-TempSortedAttemptCount

SELECT
    Year(FirstPass) AS Annee,
    Avg(TimeToFirstPassHours) AS TTFP_moyen,
    DMedian (
        "TimeToFirstPassHours",
        "ALL_temp_timediff",
        "FirstPass IS NOT NULL AND Year(FirstPass) = " & Year(FirstPass)
    ) AS TTFP_median
INTO
    ALL_TTFP
FROM
    ALL_temp_timediff
WHERE
    FirstPass IS NOT NULL
GROUP BY
    Year(FirstPass);

--ALL-10-Table-EffortPassMediane

SELECT
    Year(FirstPass) AS Annee,
    Avg(TimeToFirstPassHours) AS TTFP_moyen,
    DMedian (
        "TimeToFirstPassHours",
        "ALL_temp_timediff",
        "FirstPass IS NOT NULL AND Year(FirstPass) = " & Year(FirstPass)
    ) AS TTFP_median
INTO
    ALL_TTFP
FROM
    ALL_temp_timediff
WHERE
    FirstPass IS NOT NULL
GROUP BY
    Year(FirstPass);

--ALL-11-TempTimestampEsssais

SELECT
    Year(FirstPass) AS Annee,
    Avg(TimeToFirstPassHours) AS TTFP_moyen,
    DMedian (
        "TimeToFirstPassHours",
        "ALL_temp_timediff",
        "FirstPass IS NOT NULL AND Year(FirstPass) = " & Year(FirstPass)
    ) AS TTFP_median
INTO
    ALL_TTFP
FROM
    ALL_temp_timediff
WHERE
    FirstPass IS NOT NULL
GROUP BY
    Year(FirstPass);

--ALL-12-TableErrorLundi

SELECT
    Year(FirstPass) AS Annee,
    Avg(TimeToFirstPassHours) AS TTFP_moyen,
    DMedian (
        "TimeToFirstPassHours",
        "ALL_temp_timediff",
        "FirstPass IS NOT NULL AND Year(FirstPass) = " & Year(FirstPass)
    ) AS TTFP_median
INTO
    ALL_TTFP
FROM
    ALL_temp_timediff
WHERE
    FirstPass IS NOT NULL
GROUP BY
    Year(FirstPass);

--ALL-13-tableErrorMMJV

SELECT
    Year(FirstPass) AS Annee,
    Avg(TimeToFirstPassHours) AS TTFP_moyen,
    DMedian (
        "TimeToFirstPassHours",
        "ALL_temp_timediff",
        "FirstPass IS NOT NULL AND Year(FirstPass) = " & Year(FirstPass)
    ) AS TTFP_median
INTO
    ALL_TTFP
FROM
    ALL_temp_timediff
WHERE
    FirstPass IS NOT NULL
GROUP BY
    Year(FirstPass);

--ALL-14-TableRatioV1V2

SELECT
    Year(FirstPass) AS Annee,
    Avg(TimeToFirstPassHours) AS TTFP_moyen,
    DMedian (
        "TimeToFirstPassHours",
        "ALL_temp_timediff",
        "FirstPass IS NOT NULL AND Year(FirstPass) = " & Year(FirstPass)
    ) AS TTFP_median
INTO
    ALL_TTFP
FROM
    ALL_temp_timediff
WHERE
    FirstPass IS NOT NULL
GROUP BY
    Year(FirstPass);

--ALL-15-TempTimediff

SELECT
    Year(FirstPass) AS Annee,
    Avg(TimeToFirstPassHours) AS TTFP_moyen,
    DMedian (
        "TimeToFirstPassHours",
        "ALL_temp_timediff",
        "FirstPass IS NOT NULL AND Year(FirstPass) = " & Year(FirstPass)
    ) AS TTFP_median
INTO
    ALL_TTFP
FROM
    ALL_temp_timediff
WHERE
    FirstPass IS NOT NULL
GROUP BY
    Year(FirstPass);

--ALL-16-TempSortedTimediff

SELECT
    Year(FirstPass) AS Annee,
    Avg(TimeToFirstPassHours) AS TTFP_moyen,
    DMedian (
        "TimeToFirstPassHours",
        "ALL_temp_timediff",
        "FirstPass IS NOT NULL AND Year(FirstPass) = " & Year(FirstPass)
    ) AS TTFP_median
INTO
    ALL_TTFP
FROM
    ALL_temp_timediff
WHERE
    FirstPass IS NOT NULL
GROUP BY
    Year(FirstPass);

--ALL-17-TableTtFP

SELECT
    Year(FirstPass) AS Annee,
    Avg(TimeToFirstPassHours) AS TTFP_moyen,
    DMedian (
        "TimeToFirstPassHours",
        "ALL_temp_timediff",
        "FirstPass IS NOT NULL AND Year(FirstPass) = " & Year(FirstPass)
    ) AS TTFP_median
INTO
    ALL_TTFP
FROM
    ALL_temp_timediff
WHERE
    FirstPass IS NOT NULL
GROUP BY
    Year(FirstPass);