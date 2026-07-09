/* 1. Pull patient demographics and diagnoses   */

WITH PatientBase AS (
    SELECT
        p.PatientID,
        p.Age,
        p.Gender,
        d.DiagnosisCode,
        d.DiagnosisDescription,
        CASE 
            WHEN d.DiagnosisCode LIKE 'I1%' THEN 'Hypertension'
            WHEN d.DiagnosisCode LIKE 'E11%' THEN 'Diabetes'
            WHEN d.DiagnosisCode LIKE 'J4%' THEN 'COPD'
            ELSE 'Other'
        END AS ConditionGroup
    FROM dbo.Patients p
    LEFT JOIN dbo.PatientDiagnoses d
        ON p.PatientID = d.PatientID
),


/* 2. Most recent vitals per patient (BP, HR)    */

Vitals AS (
    SELECT
        v.PatientID,
        v.VitalType,
        v.VitalValue,
        v.VitalDate,
        ROW_NUMBER() OVER (PARTITION BY v.PatientID, v.VitalType ORDER BY v.VitalDate DESC) AS rn
    FROM dbo.Vitals v
    WHERE v.VitalType IN ('SystolicBP', 'DiastolicBP', 'HeartRate')
),

LatestVitals AS (
    SELECT
        PatientID,
        VitalType,
        VitalValue
    FROM Vitals
    WHERE rn = 1
),


/* 3. Recent ED visits (utilization risk)    */

EDVisits AS (
    SELECT
        PatientID,
        COUNT(*) AS EDVisitCount_Last90Days
    FROM dbo.Encounters
    WHERE EncounterType = 'ED'
      AND VisitDate >= DATEADD(DAY, -90, GETDATE())
    GROUP BY PatientID
),


/* 4. Combine vitals into pivoted structure    */

VitalsPivot AS (
    SELECT
        PatientID,
        MAX(CASE WHEN VitalType = 'SystolicBP' THEN VitalValue END) AS SystolicBP,
        MAX(CASE WHEN VitalType = 'DiastolicBP' THEN VitalValue END) AS DiastolicBP,
        MAX(CASE WHEN VitalType = 'HeartRate' THEN VitalValue END) AS HeartRate
    FROM LatestVitals
    GROUP BY PatientID
),


/* 5. Risk scoring logic using CASE statements    */

RiskScores AS (
    SELECT
        b.PatientID,
        b.Age,
        b.Gender,
        b.ConditionGroup,
        v.SystolicBP,
        v.DiastolicBP,
        v.HeartRate,
        ISNULL(e.EDVisitCount_Last90Days, 0) AS EDVisitCount_Last90Days,

        CASE 
            WHEN v.SystolicBP > 160 OR v.DiastolicBP > 100 THEN 2
            WHEN v.SystolicBP BETWEEN 140 AND 160 THEN 1
            ELSE 0
        END AS BloodPressureRisk,

        CASE 
            WHEN v.HeartRate > 110 THEN 2
            WHEN v.HeartRate BETWEEN 90 AND 110 THEN 1
            ELSE 0
        END AS HeartRateRisk,

        CASE 
            WHEN ISNULL(e.EDVisitCount_Last90Days, 0) >= 3 THEN 2
            WHEN ISNULL(e.EDVisitCount_Last90Days, 0) = 2 THEN 1
            ELSE 0
        END AS UtilizationRisk
    FROM PatientBase b
    LEFT JOIN VitalsPivot v
        ON b.PatientID = v.PatientID
    LEFT JOIN EDVisits e
        ON b.PatientID = e.PatientID
),


/* 6. Final risk category    */    

FinalRisk AS (
    SELECT
        *,
        (BloodPressureRisk + HeartRateRisk + UtilizationRisk) AS TotalRiskScore,

        CASE 
            WHEN (BloodPressureRisk + HeartRateRisk + UtilizationRisk) >= 4 THEN 'High Risk'
            WHEN (BloodPressureRisk + HeartRateRisk + UtilizationRisk) BETWEEN 2 AND 3 THEN 'Moderate Risk'
            ELSE 'Low Risk'
        END AS RiskCategory
    FROM RiskScores
)


/* 7. Final BI-ready view   */

CREATE OR ALTER VIEW dbo.vw_Clinical_RiskStratification AS
SELECT
    PatientID,
    Age,
    Gender,
    ConditionGroup,
    SystolicBP,
    DiastolicBP,
    HeartRate,
    EDVisitCount_Last90Days,
    TotalRiskScore,
    RiskCategory
FROM FinalRisk;
