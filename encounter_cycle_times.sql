/* 1. Join encounters with provider, clinic, and scheduling data */

WITH BaseData AS (
    SELECT
        e.EncounterID,
        e.PatientID,
        e.ProviderID,
        e.ClinicID,
        e.ArrivalTime,
        e.TriageStartTime,
        e.RoomedTime,
        e.ProviderStartTime,
        e.DischargeTime,
        p.ProviderName,
        c.ClinicName,
        s.ScheduledStartTime,
        s.VisitType
    FROM dbo.EncounterEvents e
    INNER JOIN dbo.Providers p
        ON e.ProviderID = p.ProviderID
    LEFT JOIN dbo.Clinics c
        ON e.ClinicID = c.ClinicID
    LEFT JOIN dbo.ProviderSchedule s
        ON e.ProviderID = s.ProviderID
        AND CAST(e.ArrivalTime AS DATE) = CAST(s.ScheduledStartTime AS DATE)
),


/* 2. Data quality validation using CASE logic    */

Validated AS (
    SELECT
        *,
        CASE 
            WHEN ArrivalTime IS NULL THEN 'Missing Arrival'
            WHEN TriageStartTime < ArrivalTime THEN 'Invalid Triage Time'
            WHEN RoomedTime < TriageStartTime THEN 'Invalid Room Time'
            WHEN ProviderStartTime < RoomedTime THEN 'Invalid Provider Time'
            WHEN DischargeTime < ProviderStartTime THEN 'Invalid Discharge Time'
            ELSE 'Valid'
        END AS DataQualityStatus
    FROM BaseData
),


/* 3. Calculate cycle times and LOS   */

CycleTimes AS (
    SELECT
        *,
        CASE WHEN DataQualityStatus = 'Valid'
            THEN DATEDIFF(MINUTE, ArrivalTime, TriageStartTime)
        END AS ArrivalToTriage_Min,

        CASE WHEN DataQualityStatus = 'Valid'
            THEN DATEDIFF(MINUTE, TriageStartTime, RoomedTime)
        END AS TriageToRoom_Min,

        CASE WHEN DataQualityStatus = 'Valid'
            THEN DATEDIFF(MINUTE, RoomedTime, ProviderStartTime)
        END AS RoomToProvider_Min,

        CASE WHEN DataQualityStatus = 'Valid'
            THEN DATEDIFF(MINUTE, ProviderStartTime, DischargeTime)
        END AS ProviderToDischarge_Min,

        CASE WHEN DataQualityStatus = 'Valid'
            THEN DATEDIFF(MINUTE, ArrivalTime, DischargeTime)
        END AS TotalLOS_Min
    FROM Validated
),


/* 4. Rank encounters and providers using window functions   */

Ranked AS (
    SELECT
        *,
        ROW_NUMBER() OVER (PARTITION BY ProviderID ORDER BY TotalLOS_Min DESC) AS EncounterLOS_RowNum,
        RANK() OVER (PARTITION BY ClinicID ORDER BY TotalLOS_Min ASC) AS ClinicThroughputRank
    FROM CycleTimes
    WHERE DataQualityStatus = 'Valid'
),


/* 5. Aggregate provider-level KPIs        */

ProviderAgg AS (
    SELECT
        ProviderID,
        ProviderName,
        ClinicID,
        ClinicName,
        COUNT(*) AS TotalEncounters,
        AVG(TotalLOS_Min) AS AvgLOS_Min,
        AVG(ArrivalToTriage_Min) AS AvgArrivalToTriage_Min,
        AVG(RoomToProvider_Min) AS AvgRoomToProvider_Min,
        AVG(ProviderToDischarge_Min) AS AvgProviderToDischarge_Min,
    RANK() OVER (ORDER BY AVG(TotalLOS_Min)) AS ProviderPerformanceRank
    FROM Ranked
    GROUP BY ProviderID, ProviderName, ClinicID, ClinicName
)

/* 6. Final BI-ready view    */

CREATE OR ALTER VIEW dbo.vw_Provider_Operational_KPIs AS
SELECT
    ProviderID,
    ProviderName,
    ClinicID,
    ClinicName,
    TotalEncounters,
    AvgLOS_Min,
    AvgArrivalToTriage_Min,
    AvgRoomToProvider_Min,
    AvgProviderToDischarge_Min,
    ProviderPerformanceRank
FROM ProviderAgg;
