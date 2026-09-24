/* ============================================================
   CALL CENTER INTELLIGENCE
   DESCRIPTIVE EXPLORATION - 03 INTERACTION VOLUME

   Period: January 1, 2026 - Mars 31, 2026
   Central business event: interaction
   ============================================================ */

DECLARE @StartDate DATE = '2026-01-01';
DECLARE @EndDate   DATE = '2026-03-31';


/* ============================================================
   1. TOTAL INTERACTIONS
   ============================================================ */

SELECT
    COUNT(*) AS total_interactions
FROM interaction
WHERE CAST(start_datetime AS DATE) BETWEEN @StartDate AND @EndDate;


/* ============================================================
   2. INTERACTIONS PER DAY
   ============================================================ */

SELECT
    CAST(start_datetime AS DATE) AS interaction_date,
    COUNT(*) AS total_interactions
FROM interaction
WHERE CAST(start_datetime AS DATE) BETWEEN @StartDate AND @EndDate
GROUP BY CAST(start_datetime AS DATE)
ORDER BY interaction_date;


/* ============================================================
   3. INTERACTIONS PER MONTH
   ============================================================ */

SELECT
    YEAR(start_datetime) AS interaction_year,
    MONTH(start_datetime) AS interaction_month,
    DATENAME(MONTH, start_datetime) AS month_name,
    COUNT(*) AS total_interactions
FROM interaction
WHERE CAST(start_datetime AS DATE) BETWEEN @StartDate AND @EndDate
GROUP BY
    YEAR(start_datetime),
    MONTH(start_datetime),
    DATENAME(MONTH, start_datetime)
ORDER BY
    interaction_year,
    interaction_month;


/* ============================================================
   4. INTERACTIONS BY CHANNEL
   ============================================================ */

SELECT
    c.channel_id,
    c.channel_name,
    COUNT(*) AS total_interactions,
    CAST(
        COUNT(*) * 100.0 /
        SUM(COUNT(*)) OVER ()
        AS DECIMAL(5,2)
    ) AS interaction_percentage
FROM interaction i
INNER JOIN channel c
    ON i.channel_id = c.channel_id
WHERE CAST(i.start_datetime AS DATE) BETWEEN @StartDate AND @EndDate
GROUP BY
    c.channel_id,
    c.channel_name
ORDER BY total_interactions DESC;


/* ============================================================
   5. INTERACTIONS BY CAMPAIGN
   ============================================================ */

SELECT
    ca.campaign_id,
    ca.campaign_name,
    COUNT(*) AS total_interactions,
    CAST(
        COUNT(*) * 100.0 /
        SUM(COUNT(*)) OVER ()
        AS DECIMAL(5,2)
    ) AS interaction_percentage
FROM interaction i
INNER JOIN campaign ca
    ON i.campaign_id = ca.campaign_id
WHERE CAST(i.start_datetime AS DATE) BETWEEN @StartDate AND @EndDate
GROUP BY
    ca.campaign_id,
    ca.campaign_name
ORDER BY total_interactions DESC;


/* ============================================================
   6. INTERACTIONS BY ISSUE
   ============================================================ */

SELECT
    iss.issue_id,
    iss.issue_name,
    COUNT(*) AS total_interactions,
    CAST(
        COUNT(*) * 100.0 /
        SUM(COUNT(*)) OVER ()
        AS DECIMAL(5,2)
    ) AS interaction_percentage
FROM interaction i
INNER JOIN issue iss
    ON i.issue_id = iss.issue_id
WHERE CAST(i.start_datetime AS DATE) BETWEEN @StartDate AND @EndDate
GROUP BY
    iss.issue_id,
    iss.issue_name
ORDER BY total_interactions DESC;


/* ============================================================
   7. INTERACTIONS BY EMPLOYEE
   ============================================================ */

SELECT
    e.employee_id,
    e.first_name,
    e.last_name,
    r.role_name,
    COUNT(i.interaction_id) AS total_interactions
FROM employee e
INNER JOIN role r
    ON e.role_id = r.role_id
LEFT JOIN interaction i
    ON e.employee_id = i.employee_id
    AND CAST(i.start_datetime AS DATE)
        BETWEEN @StartDate AND @EndDate
WHERE r.role_name IN (
    'Voice Agent',
    'Email Agent',
    'Trace Agent'
)
GROUP BY
    e.employee_id,
    e.first_name,
    e.last_name,
    r.role_name
ORDER BY total_interactions DESC;


/* ============================================================
   8. INTERACTIONS BY WEEKDAY
   ============================================================ */

SELECT
    DATEPART(WEEKDAY, start_datetime) AS weekday_number,
    DATENAME(WEEKDAY, start_datetime) AS weekday_name,
    COUNT(*) AS total_interactions
FROM interaction
WHERE CAST(start_datetime AS DATE) BETWEEN @StartDate AND @EndDate
GROUP BY
    DATEPART(WEEKDAY, start_datetime),
    DATENAME(WEEKDAY, start_datetime)
ORDER BY weekday_number;


/* ============================================================
   9. INTERACTIONS BY HOUR
   ============================================================ */

SELECT
    DATEPART(HOUR, start_datetime) AS interaction_hour,
    COUNT(*) AS total_interactions
FROM interaction
WHERE CAST(start_datetime AS DATE) BETWEEN @StartDate AND @EndDate
GROUP BY DATEPART(HOUR, start_datetime)
ORDER BY interaction_hour;


/* ============================================================
   10. ANSWERED VS ABANDONED
   ============================================================ */

SELECT
    CASE
        WHEN answered = 1 THEN 'Answered'
        WHEN abandoned = 1 THEN 'Abandoned'
        ELSE 'Other'
    END AS interaction_status,
    COUNT(*) AS total_interactions,
    CAST(
        COUNT(*) * 100.0 /
        SUM(COUNT(*)) OVER ()
        AS DECIMAL(5,2)
    ) AS interaction_percentage
FROM interaction
WHERE CAST(start_datetime AS DATE) BETWEEN @StartDate AND @EndDate
GROUP BY
    CASE
        WHEN answered = 1 THEN 'Answered'
        WHEN abandoned = 1 THEN 'Abandoned'
        ELSE 'Other'
    END
ORDER BY total_interactions DESC;


/* ============================================================
   11. ABANDONMENT RATE
   ============================================================ */

SELECT
    COUNT(*) AS total_interactions,

    SUM(
        CASE
            WHEN abandoned = 1 THEN 1
            ELSE 0
        END
    ) AS abandoned_interactions,

    CAST(
        SUM(
            CASE
                WHEN abandoned = 1 THEN 1
                ELSE 0
            END
        ) * 100.0 / NULLIF(COUNT(*), 0)
        AS DECIMAL(5,2)
    ) AS abandonment_rate_percentage

FROM interaction
WHERE CAST(start_datetime AS DATE) BETWEEN @StartDate AND @EndDate;


/* ============================================================
   12. AVERAGE HANDLING DURATION
   ============================================================ */

SELECT
    COUNT(handling_duration) AS interactions_with_handling_duration,

    CAST(
        AVG(CAST(handling_duration AS DECIMAL(10,2)))
        AS DECIMAL(10,2)
    ) AS average_handling_duration_seconds,

    CAST(
        AVG(CAST(handling_duration AS DECIMAL(10,2))) / 60.0
        AS DECIMAL(10,2)
    ) AS average_handling_duration_minutes

FROM interaction
WHERE CAST(start_datetime AS DATE) BETWEEN @StartDate AND @EndDate
  AND handling_duration IS NOT NULL;


/* ============================================================
   13. AVERAGE WAIT TIME
   ============================================================ */

SELECT
    COUNT(wait_time) AS interactions_with_wait_time,

    CAST(
        AVG(CAST(wait_time AS DECIMAL(10,2)))
        AS DECIMAL(10,2)
    ) AS average_wait_time_seconds,

    CAST(
        AVG(CAST(wait_time AS DECIMAL(10,2))) / 60.0
        AS DECIMAL(10,2)
    ) AS average_wait_time_minutes

FROM interaction
WHERE CAST(start_datetime AS DATE) BETWEEN @StartDate AND @EndDate
  AND wait_time IS NOT NULL;


/* ============================================================
   14. AVERAGE ANSWER SPEED
   ============================================================ */

SELECT
    COUNT(answer_speed) AS answered_interactions_with_answer_speed,

    CAST(
        AVG(CAST(answer_speed AS DECIMAL(10,2)))
        AS DECIMAL(10,2)
    ) AS average_answer_speed_seconds,

    CAST(
        AVG(CAST(answer_speed AS DECIMAL(10,2))) / 60.0
        AS DECIMAL(10,2)
    ) AS average_answer_speed_minutes

FROM interaction
WHERE CAST(start_datetime AS DATE) BETWEEN @StartDate AND @EndDate
  AND answer_speed IS NOT NULL;



