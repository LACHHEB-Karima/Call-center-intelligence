/*====================================================================
            CALL CENTER INTELLIGENCE
              DESCRIPTIVE EXPLORATION
             02 - ATTENDANCE & WORKING TIME
======================================================================

Purpose:
    Describe employee attendance, session patterns and working time
    based on login/logout sessions.

Business Rules:
    - Expected working day: 08:00 - 17:00
    - Attendance is based on agent_session.
    - Absence = no session for an expected working day.
    - Late arrival = login after 08:00.
    - Early departure = logout before 17:00.
    - Worked hours = logout - login.

====================================================================*/


/**********************************************************************
01. TOTAL SESSIONS
**********************************************************************/

SELECT
    COUNT(*) AS total_sessions
FROM agent_session;


/**********************************************************************
02. SESSIONS PER EMPLOYEE
**********************************************************************/

SELECT
    e.employee_id,
    e.first_name,
    e.last_name,
    r.role_name,
    COUNT(s.session_id) AS total_sessions
FROM agent_session s
JOIN employee e
    ON s.employee_id = e.employee_id
JOIN role r
    ON e.role_id = r.role_id
GROUP BY
    e.employee_id,
    e.first_name,
    e.last_name,
    r.role_name
ORDER BY total_sessions DESC;


/**********************************************************************
03. FIRST LOGIN / LAST LOGOUT
**********************************************************************/

SELECT
    e.employee_id,
    e.first_name,
    e.last_name,
    MIN(s.login_datetime) AS first_login,
    MAX(s.logout_datetime) AS last_logout
FROM agent_session s
JOIN employee e
    ON s.employee_id = e.employee_id
GROUP BY
    e.employee_id,
    e.first_name,
    e.last_name
ORDER BY first_login;


/**********************************************************************
04. AVERAGE WORKED HOURS
**********************************************************************/

SELECT
    AVG(
        CAST(
            DATEDIFF(
                MINUTE,
                login_datetime,
                logout_datetime
            ) AS DECIMAL(10,2)
        )
    ) / 60.0 AS average_worked_hours
FROM agent_session
WHERE logout_datetime IS NOT NULL;


/**********************************************************************
05. AVERAGE WORKED HOURS PER EMPLOYEE
**********************************************************************/

SELECT
    e.employee_id,
    e.first_name,
    e.last_name,
    AVG(
        CAST(
            DATEDIFF(
                MINUTE,
                s.login_datetime,
                s.logout_datetime
            ) AS DECIMAL(10,2)
        )
    ) / 60.0 AS average_worked_hours
FROM agent_session s
JOIN employee e
    ON s.employee_id = e.employee_id
WHERE s.logout_datetime IS NOT NULL
GROUP BY
    e.employee_id,
    e.first_name,
    e.last_name
ORDER BY average_worked_hours DESC;


/**********************************************************************
06. AVERAGE LOGIN TIME
**********************************************************************/

SELECT
    CAST(
        DATEADD(
            SECOND,
            AVG(
                DATEDIFF(
                    SECOND,
                    CAST(CAST(login_datetime AS DATE) AS DATETIME),
                    login_datetime
                )
            ),
            '00:00:00'
        ) AS TIME
    ) AS average_login_time
FROM agent_session;


/**********************************************************************
07. AVERAGE LOGOUT TIME
**********************************************************************/

SELECT
    CAST(
        DATEADD(
            SECOND,
            AVG(
                DATEDIFF(
                    SECOND,
                    CAST(CAST(logout_datetime AS DATE) AS DATETIME),
                    logout_datetime
                )
            ),
            '00:00:00'
        ) AS TIME
    ) AS average_logout_time
FROM agent_session
WHERE logout_datetime IS NOT NULL;


/**********************************************************************
08. LATE ARRIVALS
**********************************************************************/

SELECT
    COUNT(*) AS late_arrival_sessions
FROM agent_session
WHERE CAST(login_datetime AS TIME) > '08:00:00';


/**********************************************************************
09. LATE ARRIVALS PER EMPLOYEE
**********************************************************************/

SELECT
    e.employee_id,
    e.first_name,
    e.last_name,
    COUNT(*) AS late_arrival_sessions
FROM agent_session s
JOIN employee e
    ON s.employee_id = e.employee_id
WHERE CAST(s.login_datetime AS TIME) > '08:00:00'
GROUP BY
    e.employee_id,
    e.first_name,
    e.last_name
ORDER BY late_arrival_sessions DESC;


/**********************************************************************
10. AVERAGE LATE ARRIVAL MINUTES
**********************************************************************/

SELECT
    AVG(
        DATEDIFF(
            MINUTE,
            CAST(CAST(login_datetime AS DATE) AS DATETIME)
                + CAST('08:00:00' AS DATETIME),
            login_datetime
        )
    ) AS average_late_minutes
FROM agent_session
WHERE CAST(login_datetime AS TIME) > '08:00:00';


/**********************************************************************
11. EARLY DEPARTURES
**********************************************************************/

SELECT
    COUNT(*) AS early_departure_sessions
FROM agent_session
WHERE logout_datetime IS NOT NULL
  AND CAST(logout_datetime AS TIME) < '17:00:00';


/**********************************************************************
12. EARLY DEPARTURES PER EMPLOYEE
**********************************************************************/

SELECT
    e.employee_id,
    e.first_name,
    e.last_name,
    COUNT(*) AS early_departure_sessions
FROM agent_session s
JOIN employee e
    ON s.employee_id = e.employee_id
WHERE s.logout_datetime IS NOT NULL
  AND CAST(s.logout_datetime AS TIME) < '17:00:00'
GROUP BY
    e.employee_id,
    e.first_name,
    e.last_name
ORDER BY early_departure_sessions DESC;


/**********************************************************************
13. AVERAGE EARLY DEPARTURE MINUTES
**********************************************************************/

SELECT
    AVG(
        DATEDIFF(
            MINUTE,
            logout_datetime,
            CAST(CAST(logout_datetime AS DATE) AS DATETIME)
                + CAST('17:00:00' AS DATETIME)
        )
    ) AS average_early_departure_minutes
FROM agent_session
WHERE logout_datetime IS NOT NULL
  AND CAST(logout_datetime AS TIME) < '17:00:00';


/**********************************************************************
14. ABSENCE DAYS
**********************************************************************

    Absence is determined by:
    Expected working day + no agent_session.

    This analysis uses Monday-Friday as working days.
**********************************************************************/

WITH calendar AS
(
    SELECT
        MIN(CAST(login_datetime AS DATE)) AS start_date,
        MAX(CAST(login_datetime AS DATE)) AS end_date
    FROM agent_session
),
dates AS
(
    SELECT start_date AS work_date
    FROM calendar

    UNION ALL

    SELECT DATEADD(DAY, 1, work_date)
    FROM dates
    CROSS JOIN calendar
    WHERE work_date < calendar.end_date
),
working_days AS
(
    SELECT work_date
    FROM dates
    WHERE DATEDIFF(DAY, '19000101', work_date) % 7 NOT IN (5,6)
),
agents AS
(
    SELECT
        e.employee_id,
        e.first_name,
        e.last_name
    FROM employee e
    JOIN role r
        ON e.role_id = r.role_id
    WHERE r.role_name IN
    (
        'Voice Agent',
        'Email Agent',
        'Trace Agent'
    )
),
attendance AS
(
    SELECT
        a.employee_id,
        a.first_name,
        a.last_name,
        w.work_date
    FROM agents a
    CROSS JOIN working_days w
    LEFT JOIN agent_session s
        ON s.employee_id = a.employee_id
       AND CAST(s.login_datetime AS DATE) = w.work_date
    WHERE s.session_id IS NULL
)
SELECT
    employee_id,
    first_name,
    last_name,
    COUNT(*) AS absence_days
FROM attendance
GROUP BY
    employee_id,
    first_name,
    last_name
ORDER BY absence_days DESC
OPTION (MAXRECURSION 0);


/**********************************************************************
15. WORKED HOURS BY ROLE
**********************************************************************/

SELECT
    r.role_name,

    COUNT(s.session_id) AS total_sessions,

    SUM(
        DATEDIFF(
            MINUTE,
            s.login_datetime,
            s.logout_datetime
        )
    ) / 60.0 AS total_worked_hours,

    AVG(
        DATEDIFF(
            MINUTE,
            s.login_datetime,
            s.logout_datetime
        )
    ) / 60.0 AS average_worked_hours

FROM agent_session s
JOIN employee e
    ON s.employee_id = e.employee_id
JOIN role r
    ON e.role_id = r.role_id
WHERE s.logout_datetime IS NOT NULL
GROUP BY r.role_name
ORDER BY total_worked_hours DESC;


/**********************************************************************
16. WORKED HOURS BY AGENT CHANNEL
**********************************************************************/

SELECT
    CASE
        WHEN r.role_name = 'Voice Agent' THEN 'Voice'
        WHEN r.role_name = 'Email Agent' THEN 'Email'
        WHEN r.role_name = 'Trace Agent' THEN 'Trace'
        ELSE 'Other'
    END AS channel,

    COUNT(s.session_id) AS total_sessions,

    SUM(
        DATEDIFF(
            MINUTE,
            s.login_datetime,
            s.logout_datetime
        )
    ) / 60.0 AS total_worked_hours,

    AVG(
        DATEDIFF(
            MINUTE,
            s.login_datetime,
            s.logout_datetime
        )
    ) / 60.0 AS average_worked_hours

FROM agent_session s
JOIN employee e
    ON s.employee_id = e.employee_id
JOIN role r
    ON e.role_id = r.role_id

WHERE s.logout_datetime IS NOT NULL
  AND r.role_name IN
  (
      'Voice Agent',
      'Email Agent',
      'Trace Agent'
  )

GROUP BY
    CASE
        WHEN r.role_name = 'Voice Agent' THEN 'Voice'
        WHEN r.role_name = 'Email Agent' THEN 'Email'
        WHEN r.role_name = 'Trace Agent' THEN 'Trace'
        ELSE 'Other'
    END

ORDER BY total_worked_hours DESC;


/**********************************************************************
17. DAILY WORKFORCE AVAILABILITY
**********************************************************************/

SELECT
    CAST(login_datetime AS DATE) AS work_date,

    COUNT(DISTINCT employee_id) AS employees_present,

    COUNT(session_id) AS total_sessions,

    SUM(
        DATEDIFF(
            MINUTE,
            login_datetime,
            logout_datetime
        )
    ) / 60.0 AS total_worked_hours

FROM agent_session

WHERE logout_datetime IS NOT NULL

GROUP BY CAST(login_datetime AS DATE)

ORDER BY work_date;


/**********************************************************************
18. DAILY WORKFORCE BY CHANNEL
**********************************************************************/

SELECT
    CAST(s.login_datetime AS DATE) AS work_date,

    CASE
        WHEN r.role_name = 'Voice Agent' THEN 'Voice'
        WHEN r.role_name = 'Email Agent' THEN 'Email'
        WHEN r.role_name = 'Trace Agent' THEN 'Trace'
    END AS channel,

    COUNT(DISTINCT s.employee_id) AS employees_present,

    SUM(
        DATEDIFF(
            MINUTE,
            s.login_datetime,
            s.logout_datetime
        )
    ) / 60.0 AS worked_hours

FROM agent_session s

JOIN employee e
    ON s.employee_id = e.employee_id

JOIN role r
    ON e.role_id = r.role_id

WHERE r.role_name IN
(
    'Voice Agent',
    'Email Agent',
    'Trace Agent'
)

AND s.logout_datetime IS NOT NULL

GROUP BY
    CAST(s.login_datetime AS DATE),
    CASE
        WHEN r.role_name = 'Voice Agent' THEN 'Voice'
        WHEN r.role_name = 'Email Agent' THEN 'Email'
        WHEN r.role_name = 'Trace Agent' THEN 'Trace'
    END

ORDER BY
    work_date,
    channel;


/**********************************************************************
END OF ATTENDANCE & WORKING TIME
**********************************************************************/
