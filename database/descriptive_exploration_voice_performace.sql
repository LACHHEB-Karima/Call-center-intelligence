/* ============================================================
   CALL CENTER INTELLIGENCE
   DESCRIPTIVE EXPLORATION - 07 VOICE PERFORMANCE

   Period: January 1, 2026 - Mars 31, 2026

   Voice KPI:
   Talk + ACW = Combined Handling Time

   Target:
   300 seconds

   ============================================================ */

DECLARE @StartDate DATE = '2026-01-01';
DECLARE @EndDate   DATE = '2026-03-31';
DECLARE @TargetHandlingTime INT = 300;


/* ============================================================
   1. TOTAL VOICE CALLS
   ============================================================ */

SELECT
    COUNT(*) AS total_voice_calls
FROM interaction i
INNER JOIN employee e
    ON i.employee_id = e.employee_id
INNER JOIN role r
    ON e.role_id = r.role_id
WHERE r.role_name = 'Voice Agent'
  AND i.channel_id = 1
  AND CAST(i.start_datetime AS DATE)
      BETWEEN @StartDate AND @EndDate;


/* ============================================================
   2. CALLS PER AGENT
   ============================================================ */

SELECT
    e.employee_id,
    e.first_name,
    e.last_name,

    COUNT(i.interaction_id) AS total_calls

FROM employee e

INNER JOIN role r
    ON e.role_id = r.role_id

LEFT JOIN interaction i
    ON e.employee_id = i.employee_id
    AND i.channel_id = 1
    AND CAST(i.start_datetime AS DATE)
        BETWEEN @StartDate AND @EndDate

WHERE r.role_name = 'Voice Agent'

GROUP BY
    e.employee_id,
    e.first_name,
    e.last_name

ORDER BY total_calls DESC;


/* ============================================================
   3. CALLS PER DAY
   ============================================================ */

SELECT
    CAST(i.start_datetime AS DATE) AS call_date,
    COUNT(*) AS total_calls
FROM interaction i
INNER JOIN employee e
    ON i.employee_id = e.employee_id
INNER JOIN role r
    ON e.role_id = r.role_id
WHERE r.role_name = 'Voice Agent'
  AND i.channel_id = 1
  AND CAST(i.start_datetime AS DATE)
      BETWEEN @StartDate AND @EndDate
GROUP BY
    CAST(i.start_datetime AS DATE)
ORDER BY
    call_date;


/* ============================================================
   4. AVERAGE HANDLING TIME
      Talk + ACW combined
   ============================================================ */

SELECT
    COUNT(handling_duration) AS calls_with_handling_time,

    CAST(
        AVG(CAST(handling_duration AS DECIMAL(10,2)))
        AS DECIMAL(10,2)
    ) AS average_handling_time_seconds,

    CAST(
        AVG(CAST(handling_duration AS DECIMAL(10,2))) / 60.0
        AS DECIMAL(10,2)
    ) AS average_handling_time_minutes

FROM interaction i

INNER JOIN employee e
    ON i.employee_id = e.employee_id

INNER JOIN role r
    ON e.role_id = r.role_id

WHERE r.role_name = 'Voice Agent'
  AND i.channel_id = 1
  AND i.answered = 1
  AND i.handling_duration IS NOT NULL
  AND CAST(i.start_datetime AS DATE)
      BETWEEN @StartDate AND @EndDate;


/* ============================================================
   5. MEDIAN HANDLING TIME
   ============================================================ */

SELECT DISTINCT

    PERCENTILE_CONT(0.50)
    WITHIN GROUP (
        ORDER BY i.handling_duration
    )
    OVER () AS median_handling_time_seconds

FROM interaction i

INNER JOIN employee e
    ON i.employee_id = e.employee_id

INNER JOIN role r
    ON e.role_id = r.role_id

WHERE r.role_name = 'Voice Agent'
  AND i.channel_id = 1
  AND i.answered = 1
  AND i.handling_duration IS NOT NULL
  AND CAST(i.start_datetime AS DATE)
      BETWEEN @StartDate AND @EndDate;


/* ============================================================
   6. P25 AND P75 HANDLING TIME
   ============================================================ */

SELECT DISTINCT

    PERCENTILE_CONT(0.25)
    WITHIN GROUP (
        ORDER BY i.handling_duration
    )
    OVER () AS p25_handling_time_seconds,

    PERCENTILE_CONT(0.50)
    WITHIN GROUP (
        ORDER BY i.handling_duration
    )
    OVER () AS median_handling_time_seconds,

    PERCENTILE_CONT(0.75)
    WITHIN GROUP (
        ORDER BY i.handling_duration
    )
    OVER () AS p75_handling_time_seconds

FROM interaction i

INNER JOIN employee e
    ON i.employee_id = e.employee_id

INNER JOIN role r
    ON e.role_id = r.role_id

WHERE r.role_name = 'Voice Agent'
  AND i.channel_id = 1
  AND i.answered = 1
  AND i.handling_duration IS NOT NULL
  AND CAST(i.start_datetime AS DATE)
      BETWEEN @StartDate AND @EndDate;


/* ============================================================
   7. WAIT TIME
   ============================================================ */

SELECT

    CAST(
        AVG(CAST(i.wait_time AS DECIMAL(10,2)))
        AS DECIMAL(10,2)
    ) AS average_wait_time_seconds,

    CAST(
        AVG(CAST(i.wait_time AS DECIMAL(10,2))) / 60.0
        AS DECIMAL(10,2)
    ) AS average_wait_time_minutes,

    MAX(i.wait_time) AS maximum_wait_time_seconds

FROM interaction i

INNER JOIN employee e
    ON i.employee_id = e.employee_id

INNER JOIN role r
    ON e.role_id = r.role_id

WHERE r.role_name = 'Voice Agent'
  AND i.channel_id = 1
  AND i.wait_time IS NOT NULL
  AND CAST(i.start_datetime AS DATE)
      BETWEEN @StartDate AND @EndDate;


/* ============================================================
   8. ANSWER SPEED
   ============================================================ */

SELECT

    CAST(
        AVG(CAST(i.answer_speed AS DECIMAL(10,2)))
        AS DECIMAL(10,2)
    ) AS average_answer_speed_seconds,

    CAST(
        AVG(CAST(i.answer_speed AS DECIMAL(10,2))) / 60.0
        AS DECIMAL(10,2)
    ) AS average_answer_speed_minutes,

    MAX(i.answer_speed) AS maximum_answer_speed_seconds

FROM interaction i

INNER JOIN employee e
    ON i.employee_id = e.employee_id

INNER JOIN role r
    ON e.role_id = r.role_id

WHERE r.role_name = 'Voice Agent'
  AND i.channel_id = 1
  AND i.answer_speed IS NOT NULL
  AND CAST(i.start_datetime AS DATE)
      BETWEEN @StartDate AND @EndDate;


/* ============================================================
   9. ANSWERED VS ABANDONED
   ============================================================ */

SELECT

    CASE
        WHEN i.answered = 1 THEN 'Answered'
        WHEN i.abandoned = 1 THEN 'Abandoned'
        ELSE 'Other'
    END AS call_status,

    COUNT(*) AS total_calls,

    CAST(
        COUNT(*) * 100.0 /
        SUM(COUNT(*)) OVER ()
        AS DECIMAL(5,2)
    ) AS percentage_of_calls

FROM interaction i

WHERE i.channel_id = 1
  AND CAST(i.start_datetime AS DATE)
      BETWEEN @StartDate AND @EndDate

GROUP BY
    CASE
        WHEN i.answered = 1 THEN 'Answered'
        WHEN i.abandoned = 1 THEN 'Abandoned'
        ELSE 'Other'
    END

ORDER BY total_calls DESC;


/* ============================================================
   10. ABANDONMENT RATE
   ============================================================ */

SELECT

    COUNT(*) AS total_calls,

    SUM(
        CASE
            WHEN abandoned = 1 THEN 1
            ELSE 0
        END
    ) AS abandoned_calls,

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

WHERE channel_id = 1
  AND CAST(start_datetime AS DATE)
      BETWEEN @StartDate AND @EndDate;


/* ============================================================
   11. HANDLING TIME BY ISSUE
   ============================================================ */

SELECT

    iss.issue_name,

    COUNT(*) AS total_calls,

    CAST(
        AVG(
            CAST(i.handling_duration AS DECIMAL(10,2))
        )
        AS DECIMAL(10,2)
    ) AS average_handling_time_seconds,

    CAST(
        AVG(
            CAST(i.handling_duration AS DECIMAL(10,2))
        ) / 60.0
        AS DECIMAL(10,2)
    ) AS average_handling_time_minutes

FROM interaction i

INNER JOIN employee e
    ON i.employee_id = e.employee_id

INNER JOIN role r
    ON e.role_id = r.role_id

INNER JOIN issue iss
    ON i.issue_id = iss.issue_id

WHERE r.role_name = 'Voice Agent'
  AND i.channel_id = 1
  AND i.answered = 1
  AND i.handling_duration IS NOT NULL
  AND CAST(i.start_datetime AS DATE)
      BETWEEN @StartDate AND @EndDate

GROUP BY
    iss.issue_name

ORDER BY
    average_handling_time_seconds DESC;


/* ============================================================
   12. HANDLING TIME BY CAMPAIGN
   ============================================================ */

SELECT

    ca.campaign_name,

    COUNT(*) AS total_calls,

    CAST(
        AVG(
            CAST(i.handling_duration AS DECIMAL(10,2))
        )
        AS DECIMAL(10,2)
    ) AS average_handling_time_seconds,

    CAST(
        AVG(
            CAST(i.handling_duration AS DECIMAL(10,2))
        ) / 60.0
        AS DECIMAL(10,2)
    ) AS average_handling_time_minutes

FROM interaction i

INNER JOIN employee e
    ON i.employee_id = e.employee_id

INNER JOIN role r
    ON e.role_id = r.role_id

INNER JOIN campaign ca
    ON i.campaign_id = ca.campaign_id

WHERE r.role_name = 'Voice Agent'
  AND i.channel_id = 1
  AND i.answered = 1
  AND i.handling_duration IS NOT NULL
  AND CAST(i.start_datetime AS DATE)
      BETWEEN @StartDate AND @EndDate

GROUP BY
    ca.campaign_name

ORDER BY
    average_handling_time_seconds DESC;


/* ============================================================
   13. HANDLING TIME BY AGENT
   ============================================================ */

SELECT

    e.employee_id,
    e.first_name,
    e.last_name,

    COUNT(i.interaction_id) AS total_calls,

    CAST(
        AVG(
            CAST(i.handling_duration AS DECIMAL(10,2))
        )
        AS DECIMAL(10,2)
    ) AS average_handling_time_seconds,

    CAST(
        AVG(
            CAST(i.handling_duration AS DECIMAL(10,2))
        ) / 60.0
        AS DECIMAL(10,2)
    ) AS average_handling_time_minutes

FROM employee e

INNER JOIN role r
    ON e.role_id = r.role_id

LEFT JOIN interaction i
    ON e.employee_id = i.employee_id
    AND i.channel_id = 1
    AND i.answered = 1
    AND i.handling_duration IS NOT NULL
    AND CAST(i.start_datetime AS DATE)
        BETWEEN @StartDate AND @EndDate

WHERE r.role_name = 'Voice Agent'

GROUP BY
    e.employee_id,
    e.first_name,
    e.last_name

ORDER BY
    average_handling_time_seconds DESC;


/* ============================================================
   14. DAILY HANDLING TIME EVOLUTION
   ============================================================ */

SELECT

    CAST(i.start_datetime AS DATE) AS call_date,

    COUNT(*) AS total_calls,

    CAST(
        AVG(
            CAST(i.handling_duration AS DECIMAL(10,2))
        )
        AS DECIMAL(10,2)
    ) AS average_handling_time_seconds

FROM interaction i

INNER JOIN employee e
    ON i.employee_id = e.employee_id

INNER JOIN role r
    ON e.role_id = r.role_id

WHERE r.role_name = 'Voice Agent'
  AND i.channel_id = 1
  AND i.answered = 1
  AND i.handling_duration IS NOT NULL
  AND CAST(i.start_datetime AS DATE)
      BETWEEN @StartDate AND @EndDate

GROUP BY
    CAST(i.start_datetime AS DATE)

ORDER BY
    call_date;


/* ============================================================
   15. WEEKLY HANDLING TIME EVOLUTION
   ============================================================ */

SELECT

    DATEPART(YEAR, i.start_datetime) AS interaction_year,

    DATEPART(ISO_WEEK, i.start_datetime) AS week_number,

    COUNT(*) AS total_calls,

    CAST(
        AVG(
            CAST(i.handling_duration AS DECIMAL(10,2))
        )
        AS DECIMAL(10,2)
    ) AS average_handling_time_seconds

FROM interaction i

INNER JOIN employee e
    ON i.employee_id = e.employee_id

INNER JOIN role r
    ON e.role_id = r.role_id

WHERE r.role_name = 'Voice Agent'
  AND i.channel_id = 1
  AND i.answered = 1
  AND i.handling_duration IS NOT NULL
  AND CAST(i.start_datetime AS DATE)
      BETWEEN @StartDate AND @EndDate

GROUP BY
    DATEPART(YEAR, i.start_datetime),
    DATEPART(ISO_WEEK, i.start_datetime)

ORDER BY
    interaction_year,
    week_number;


/* ============================================================
   16. MONTHLY HANDLING TIME EVOLUTION
   ============================================================ */

SELECT

    YEAR(i.start_datetime) AS interaction_year,

    MONTH(i.start_datetime) AS interaction_month,

    DATENAME(MONTH, i.start_datetime) AS month_name,

    COUNT(*) AS total_calls,

    CAST(
        AVG(
            CAST(i.handling_duration AS DECIMAL(10,2))
        )
        AS DECIMAL(10,2)
    ) AS average_handling_time_seconds

FROM interaction i

INNER JOIN employee e
    ON i.employee_id = e.employee_id

INNER JOIN role r
    ON e.role_id = r.role_id

WHERE r.role_name = 'Voice Agent'
  AND i.channel_id = 1
  AND i.answered = 1
  AND i.handling_duration IS NOT NULL
  AND CAST(i.start_datetime AS DATE)
      BETWEEN @StartDate AND @EndDate

GROUP BY
    YEAR(i.start_datetime),
    MONTH(i.start_datetime),
    DATENAME(MONTH, i.start_datetime)

ORDER BY
    interaction_year,
    interaction_month;


/* ============================================================
   17. AGENTS ABOVE / BELOW TARGET

   Target = 300 seconds

   Below target:
       Average handling time < 300

   At target:
       Average handling time = 300

   Above target:
       Average handling time > 300
   ============================================================ */

SELECT

    e.employee_id,
    e.first_name,
    e.last_name,

    COUNT(i.interaction_id) AS total_calls,

    CAST(
        AVG(
            CAST(i.handling_duration AS DECIMAL(10,2))
        )
        AS DECIMAL(10,2)
    ) AS average_handling_time_seconds,

    @TargetHandlingTime AS target_handling_time_seconds,

    CAST(
        AVG(
            CAST(i.handling_duration AS DECIMAL(10,2))
        ) - @TargetHandlingTime
        AS DECIMAL(10,2)
    ) AS difference_from_target_seconds,

    CASE
        WHEN AVG(i.handling_duration) < @TargetHandlingTime
            THEN 'Below Target'

        WHEN AVG(i.handling_duration) = @TargetHandlingTime
            THEN 'At Target'

        WHEN AVG(i.handling_duration) > @TargetHandlingTime
            THEN 'Above Target'
    END AS target_status

FROM employee e

INNER JOIN role r
    ON e.role_id = r.role_id

LEFT JOIN interaction i
    ON e.employee_id = i.employee_id
    AND i.channel_id = 1
    AND i.answered = 1
    AND i.handling_duration IS NOT NULL
    AND CAST(i.start_datetime AS DATE)
        BETWEEN @StartDate AND @EndDate

WHERE r.role_name = 'Voice Agent'

GROUP BY
    e.employee_id,
    e.first_name,
    e.last_name

ORDER BY
    average_handling_time_seconds DESC;


/* ============================================================
   18. TARGET DISTRIBUTION
   ============================================================ */

WITH AgentPerformance AS
(
    SELECT

        e.employee_id,

        AVG(
            CAST(i.handling_duration AS DECIMAL(10,2))
        ) AS average_handling_time

    FROM employee e

    INNER JOIN role r
        ON e.role_id = r.role_id

    INNER JOIN interaction i
        ON e.employee_id = i.employee_id

    WHERE r.role_name = 'Voice Agent'
      AND i.channel_id = 1
      AND i.answered = 1
      AND i.handling_duration IS NOT NULL
      AND CAST(i.start_datetime AS DATE)
          BETWEEN @StartDate AND @EndDate

    GROUP BY
        e.employee_id
)

SELECT

    CASE
        WHEN average_handling_time < @TargetHandlingTime
            THEN 'Below Target'

        WHEN average_handling_time = @TargetHandlingTime
            THEN 'At Target'

        ELSE 'Above Target'
    END AS target_status,

    COUNT(*) AS number_of_agents,

    CAST(
        COUNT(*) * 100.0 /
        SUM(COUNT(*)) OVER ()
        AS DECIMAL(5,2)
    ) AS percentage_of_agents

FROM AgentPerformance

GROUP BY
    CASE
        WHEN average_handling_time < @TargetHandlingTime
            THEN 'Below Target'

        WHEN average_handling_time = @TargetHandlingTime
            THEN 'At Target'

        ELSE 'Above Target'
    END

ORDER BY
    target_status;


/* ============================================================
   19. AGENTS FAR ABOVE TARGET

   Useful for identifying agents whose average handling
   time is more than 60 seconds above target.

   Target = 300
   Priority threshold = 360 seconds
   ============================================================ */

SELECT

    e.employee_id,
    e.first_name,
    e.last_name,

    COUNT(i.interaction_id) AS total_calls,

    CAST(
        AVG(
            CAST(i.handling_duration AS DECIMAL(10,2))
        )
        AS DECIMAL(10,2)
    ) AS average_handling_time_seconds,

    CAST(
        AVG(
            CAST(i.handling_duration AS DECIMAL(10,2))
        ) - @TargetHandlingTime
        AS DECIMAL(10,2)
    ) AS seconds_above_target

FROM employee e

INNER JOIN role r
    ON e.role_id = r.role_id

INNER JOIN interaction i
    ON e.employee_id = i.employee_id

WHERE r.role_name = 'Voice Agent'
  AND i.channel_id = 1
  AND i.answered = 1
  AND i.handling_duration IS NOT NULL
  AND CAST(i.start_datetime AS DATE)
      BETWEEN @StartDate AND @EndDate

GROUP BY
    e.employee_id,
    e.first_name,
    e.last_name

HAVING
    AVG(i.handling_duration) > @TargetHandlingTime + 60

ORDER BY
    average_handling_time_seconds DESC;