--BC-MOD-00-TEST_DATAProd
SELECT
    *
INTO
    TEST_DATA_PROD_B1
FROM
    TEST_DATA_REDUIT
WHERE
    Prod = "PROD"
    AND StationID = "VM_T-D14"
    AND ModelNormalise = 2;

--BC-MOD-01-TableEssaisStatut
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
    B1_table_essais_statut
FROM
    TEST_DATA_PROD_B1
ORDER BY
    StartTime;

--BC-MOD-02-TableFirstPass
SELECT
    SerialNumberNormalise,
    Min(StartTime) AS FirstPassTime
INTO
    B1_table_first_pass
FROM
    B1_table_essais_statut
WHERE
    Passed = True
GROUP BY
    SerialNumberNormalise;

--BC-MOD-03-TempLastIsError
SELECT
    SerialNumberNormalise,
    Max(StartTime) AS LastTime,
    Max(IIf(Error = True, 1, 0)) AS LastIsError
INTO
    B1_temp_LastIsError
FROM
    B1_table_essais_statut AS bht1
WHERE
    NOT EXISTS (
        SELECT
            1
        FROM
            B1_table_first_pass AS bht2
        WHERE
            bht2.SerialNumberNormalise = bht1.SerialNumberNormalise
    )
GROUP BY
    SerialNumberNormalise;

--BC-MOD-04-TableAttemptCount
SELECT
    n.SerialNumberNormalise,
    IIf(
        EXISTS (
            SELECT
                1
            FROM
                B1_table_first_pass
            WHERE
                SerialNumberNormalise = n.SerialNumberNormalise
        ),
        (
            SELECT
                Count(*)
            FROM
                B1_table_essais_statut AS sub
            WHERE
                sub.SerialNumberNormalise = n.SerialNumberNormalise
                AND sub.StartTime <= (
                    SELECT
                        FirstPassTime
                    FROM
                        B1_table_first_pass
                    WHERE
                        SerialNumberNormalise = n.SerialNumberNormalise
                )
        ),
        IIf(
            EXISTS (
                SELECT
                    1
                FROM
                    B1_temp_LastIsError
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
            B1_table_essais_statut AS t1
        WHERE
            t1.SerialNumberNormalise = n.SerialNumberNormalise
    ) AS EndDate,
    ModelNormalise
INTO
    B1_table_AttemptCount
FROM
    (
        SELECT DISTINCT
            SerialNumberNormalise,
            ModelNormalise
        FROM
            B1_table_essais_statut
    ) AS n;

--BC-MOD-05-TableEssaisStatutTotal
SELECT
    Sum(IIf(Passed = True, 1, 0)) AS Essai_Passed,
    Sum(IIf(Failed = True, 1, 0)) AS Essai_Failed,
    Sum(IIf(Terminated = True, 1, 0)) AS Essai_Terminated,
    Sum(IIf(Error = True, 1, 0)) AS Essai_Error,
    Count(*) AS Total,
    Year(StartTime) AS Annee
INTO
    B1_table_essais_statut_total
FROM
    B1_table_essais_statut
GROUP BY
    Year(StartTime);

--BC-MOD-06-TempNbProd_HorsProd
SELECT
    Year(Max(StartTime)) AS Annee,
    SerialNumberNormalise
INTO
    B1_temp_Nb_HorsProd
FROM
    TEST_DATA_REDUIT
WHERE
    StationID = "VM_T-D14"
    AND Prod = "HORS_PROD"
    AND ModelNormalise = 2
GROUP BY
    SerialNumberNormalise;

--BC-MOD-07-TableNbModules
SELECT
    Year(t1.EndDate) AS Annee,
    (
        SELECT
            COUNT(*)
        FROM
            B1_table_AttemptCount AS t2
        WHERE
            t2.AttemptCount > 0
            AND Year(t2.EndDate) = Year(t1.EndDate)
    ) AS Valides,
    COUNT(*) AS TesteProd,
    (
        (
            SELECT
                count(*)
            FROM
                B1_temp_Nb_HorsProd AS b2
            WHERE
                b2.Annee = Year(t1.EndDate)
        ) + Count(*)
    ) AS TesteTotal
INTO
    B1_Nb_Module_Prod
FROM
    B1_table_AttemptCount AS t1
GROUP BY
    Year(t1.EndDate);

--BC-MOD-08-TableEffortPassMoyenne
SELECT
    Avg(AttemptCount) AS Moyenne,
    Year(EndDate) AS Annee
INTO
    B1_table_EffortPass_moyenne
FROM
    B1_table_AttemptCount
WHERE
    AttemptCount > 0
GROUP BY
    Year(EndDate);

--BC-MOD-09-TempSortedAttemptCount
SELECT DISTINCT
    SerialNumberNormalise,
    AttemptCount,
    Year(EndDate) AS Annee
INTO
    B1_temp_sorted_AttempCount
FROM
    B1_table_AttemptCount
WHERE
    AttemptCount > 0
ORDER BY
    Year(EndDate),
    AttemptCount;

--BC-MOD-10-TableEffortPassMediane
SELECT
    TOP 1 (
        SELECT
            Max(t1bis.AttemptCount)
        FROM
            (
                SELECT
                    TOP 50 PERCENT t1.AttemptCount
                FROM
                    B1_temp_sorted_AttempCount AS t1
                WHERE
                    t1.Annee = 2020
            ) AS t1bis
    ) AS med2020,
    (
        SELECT
            Max(t2bis.AttemptCount)
        FROM
            (
                SELECT
                    TOP 50 PERCENT t2.AttemptCount
                FROM
                    B1_temp_sorted_AttempCount AS t2
                WHERE
                    t2.Annee = 2021
            ) AS t2bis
    ) AS med2021,
    (
        SELECT
            Max(t3bis.AttemptCount)
        FROM
            (
                SELECT
                    TOP 50 PERCENT t3.AttemptCount
                FROM
                    B1_temp_sorted_AttempCount AS t3
                WHERE
                    t3.Annee = 2022
            ) AS t3bis
    ) AS med2022,
    (
        SELECT
            Max(t4bis.AttemptCount)
        FROM
            (
                SELECT
                    TOP 50 PERCENT t4.AttemptCount
                FROM
                    B1_temp_sorted_AttempCount AS t4
                WHERE
                    t4.Annee = 2023
            ) AS t4bis
    ) AS med2023,
    (
        SELECT
            Max(t5bis.AttemptCount)
        FROM
            (
                SELECT
                    TOP 50 PERCENT t5.AttemptCount
                FROM
                    B1_temp_sorted_AttempCount AS t5
                WHERE
                    t5.Annee = 2024
            ) AS t5bis
    ) AS med2024,
    (
        SELECT
            Max(t6bis.AttemptCount)
        FROM
            (
                SELECT
                    TOP 50 PERCENT t6.AttemptCount
                FROM
                    B1_temp_sorted_AttempCount AS t6
                WHERE
                    t6.Annee = 2025
            ) AS t6bis
    ) AS med2025,
    (
        SELECT
            Max(t7bis.AttemptCount)
        FROM
            (
                SELECT
                    TOP 50 PERCENT t7.AttemptCount
                FROM
                    B1_temp_sorted_AttempCount AS t7
                WHERE
                    t7.Annee = 2026
            ) AS t7bis
    ) AS med2026
INTO
    B1_table_EffortPass_mediane
FROM
    B1_temp_sorted_AttempCount AS t8;

--BC-MOD-11-TempTimestampEssais
SELECT
    Hour (StartTime) AS HeureDeDebut,
    Weekday (StartTime) AS Jour,
    Year(StartTime) AS Annee,
    Sum(IIf(UUTresult = "Passed", 1, 0)) AS Essai_Passed,
    Sum(IIf(UUTresult = "Failed", 1, 0)) AS Essai_Failed,
    Sum(IIf(UUTresult = "Terminated", 1, 0)) AS Essai_Terminated,
    Sum(IIf(UUTresult = "Error", 1, 0)) AS Essai_Error,
    count(*) AS Total
INTO
    B1_temp_timestamp_essais
FROM
    TEST_DATA_PROD_B1
GROUP BY
    Year(StartTime),
    Weekday (StartTime),
    Hour (StartTime);

--BC-MOD-12-TableErrorLundi
SELECT
    Sum(t1.Essai_Error) AS Nb_error,
    (
        SELECT
            (Sum(t2.Essai_Error) / Sum(t2.Total))
        FROM
            B1_temp_timestamp_essais AS t2
        WHERE
            t2.Jour = 2
            AND t2.HeureDeDebut BETWEEN 6 AND 10
            AND t1.Annee = t2.Annee
    ) AS Ratio_error,
    t1.Annee
INTO
    B1_table_error_lundi
FROM
    B1_temp_timestamp_essais AS t1
WHERE
    Jour = 2
    AND HeureDeDebut BETWEEN 6 AND 10
GROUP BY
    Annee;

--BC-MOD-13-TableErrorMMJV
SELECT
    (Sum(t1.Essai_Error) / 4) AS Nb_error,
    (
        SELECT
            (Sum(t2.Essai_Error) / Sum(t2.Total))
        FROM
            B1_temp_timestamp_essais AS t2
        WHERE
            t2.Jour BETWEEN 3 AND 6
            AND t2.HeureDeDebut BETWEEN 6 AND 10
            AND t1.Annee = t2.Annee
    ) AS Ratio_error,
    t1.Annee
INTO
    B1_table_error_MMJV
FROM
    B1_temp_timestamp_essais AS t1
WHERE
    Jour BETWEEN 3 AND 6
    AND HeureDeDebut BETWEEN 6 AND 10
GROUP BY
    Annee;

--BC-MOD-14-TableRatioV1V2
SELECT
    Sum(IIf(ModelNormalise = 1, 1, 0)) AS V1,
    Sum(IIf(ModelNormalise = 2, 1, 0)) AS V2,
    (
        (
            (Sum(IIf(ModelNormalise = 2, 1, 0))) / (Count(*) / 100)
        )
    ) AS Ratio_V2_Total,
    Year(EndDate) AS Annee
INTO
    B1_table_ratio_v1v2
FROM
    B1_table_AttemptCount
GROUP BY
    Year(EndDate);

--BC-MOD-15-TempTimediff
SELECT
    SerialNumberNormalise,
    Min(StartTime) AS FirstStart,
    Min(IIf(Passed = True, StartTime, NULL)) AS FirstPass,
    IIf(
        Min(IIf(Passed = True, StartTime, NULL)) IS NULL,
        NULL,
        DateDiff(
            "s",
            Min(StartTime),
            Min(IIf(Passed = True, StartTime, NULL))
        )
    ) AS DiffSeconds,
    Min(IIf(Passed = True, TotalTime, NULL)) AS TestTimeSeconds,
    Round(
        (
            (
                IIf(
                    Min(IIf(Passed = True, StartTime, NULL)) IS NULL,
                    NULL,
                    DateDiff(
                        "s",
                        Min(StartTime),
                        Min(IIf(Passed = True, StartTime, NULL))
                    )
                ) + Min(IIf(Passed = True, TotalTime, NULL))
            ) / 3600
        ),
        3
    ) AS TimeToFIrstPassHours
INTO
    B1_temp_timediff
FROM
    B1_table_essais_statut
GROUP BY
    SerialNumberNormalise;

--BC-MOD-16-TempSortedTimediff
SELECT DISTINCT
    SerialNumberNormalise,
    TimeToFIrstPassHours,
    Year(FirstPass) AS Annee
INTO
    B1_temp_sorted_TimeDiff
FROM
    B1_temp_timediff
WHERE
    TimeToFIrstPassHours IS NOT NULL
ORDER BY
    Year(FirstPass),
    TimeToFIrstPassHours;

--BC-MOD-17-TableTtFP
SELECT
    Year(FirstPass) AS Annee,
    Avg(TimeToFirstPassHours) AS TTFP_moyen,
    DMedian (
        "TimeToFirstPassHours",
        "B1_temp_timediff",
        "FirstPass IS NOT NULL AND Year(FirstPass) = " & Year(FirstPass)
    ) AS TTFP_median
INTO
    B1_TTFP
FROM
    B1_temp_timediff
WHERE
    FirstPass IS NOT NULL
GROUP BY
    Year(FirstPass);