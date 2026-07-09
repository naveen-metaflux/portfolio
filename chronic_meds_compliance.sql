/* 1. Identify active patients on chronic medications   */

WITH ActivePatients AS (
    SELECT
        p.PatientID,
        p.Age,
        p.Gender,
        m.MedicationName,
        m.StartDate,
        m.EndDate,
        CASE 
            WHEN m.EndDate IS NULL OR m.EndDate >= GETDATE() THEN 1
            ELSE 0
        END AS IsActiveMedication
    FROM dbo.PatientMedication m
    INNER JOIN dbo.Patients p
        ON m.PatientID = p.PatientID
    WHERE m.MedicationName IN ('Metformin', 'Lisinopril', 'Atorvastatin')
),


/* 2. Pull most recent lab results for each patient   */

RecentLabs AS (
    SELECT
        l.PatientID,
        l.LabName,
        l.LabValue,
        l.LabDate,
        ROW_NUMBER() OVER (PARTITION BY l.PatientID, l.LabName ORDER BY l.LabDate DESC) AS rn
    FROM dbo.LabResults l
    WHERE l.LabName IN ('A1C', 'Creatinine', 'Lipid Panel')
),

LatestLabs AS (
    SELECT
        PatientID,
        LabName,
        LabValue,
        LabDate
    FROM RecentLabs
    WHERE rn = 1
),


/* 3. Clinical compliance logic using CASE statements   */

Compliance AS (
    SELECT
        a.PatientID,
        a.Age,
        a.Gender,
        a.MedicationName,
        a.IsActiveMedication,
        l.LabName,
        l.LabValue,
        l.LabDate,

        CASE 
            WHEN a.MedicationName = 'Metformin' 
                 AND l.LabName = 'A1C'
                 AND l.LabDate >= DATEADD(MONTH, -6, GETDATE())
                THEN 'Compliant'
            WHEN a.MedicationName = 'Lisinopril'
                 AND l.LabName = 'Creatinine'
                 AND l.LabDate >= DATEADD(YEAR, -1, GETDATE())
                THEN 'Compliant'
            WHEN a.MedicationName = 'Atorvastatin'
                 AND l.LabName = 'Lipid Panel'
                 AND l.LabDate >= DATEADD(YEAR, -1, GETDATE())
                THEN 'Compliant'
            ELSE 'Non-Compliant'
        END AS ComplianceStatus
    FROM ActivePatients a
    LEFT JOIN LatestLabs l
        ON a.PatientID = l.PatientID
),


/* 4. Aggregate compliance rates by medication     */

MedicationAgg AS (
    SELECT
        MedicationName,
        COUNT(*) AS TotalPatients,
        SUM(CASE WHEN ComplianceStatus = 'Compliant' THEN 1 ELSE 0 END) AS CompliantPatients,
        CAST(SUM(CASE WHEN ComplianceStatus = 'Compliant' THEN 1 ELSE 0 END) AS FLOAT)/ NULLIF(COUNT(*), 0) AS ComplianceRate
    FROM Compliance
    WHERE IsActiveMedication = 1
    GROUP BY MedicationName
)


/* 5. Final BI-ready view    */

CREATE OR ALTER VIEW dbo.vw_Clinical_Medication_Compliance AS
SELECT
    MedicationName,
    TotalPatients,
    CompliantPatients,
    ComplianceRate
FROM MedicationAgg;
