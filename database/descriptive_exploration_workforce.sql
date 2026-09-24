/*====================================================================
            CALL CENTER INTELLIGENCE
              DESCRIPTIVE EXPLORATION
======================================================================
01 - WORKFORCE PROFILE
     Purpose:
           Understand the composition of the workforce before analyzing
           attendance, productivity and operational performance.
======================================================================*/


/**********************************************************************
1. TOTAL EMPLOYEES
**********************************************************************/

SELECT
    COUNT(*) AS total_employees
FROM employee;


/**********************************************************************
2. EMPLOYEES BY ROLE
**********************************************************************/

SELECT
    r.role_name,
    COUNT(*) AS employee_count,
    CAST(
        COUNT(*) * 100.0 / SUM(COUNT(*)) OVER()
        AS DECIMAL(5,2)
    ) AS employee_percentage
FROM employee e
JOIN role r
    ON e.role_id = r.role_id
GROUP BY r.role_name
ORDER BY employee_count DESC;


/**********************************************************************
3. AGENTS BY CHANNEL
**********************************************************************/

SELECT
    CASE
        WHEN r.role_name = 'Voice Agent' THEN 'Voice'
        WHEN r.role_name = 'Email Agent' THEN 'Email'
        WHEN r.role_name = 'Trace Agent' THEN 'Trace'
    END AS channel,
    COUNT(*) AS agent_count,
    CAST(
        COUNT(*) * 100.0 /
        SUM(COUNT(*)) OVER()
        AS DECIMAL(5,2)
    ) AS agent_percentage
FROM employee e
JOIN role r
    ON e.role_id = r.role_id
WHERE r.role_name IN
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
    END
ORDER BY agent_count DESC;


/**********************************************************************
4. AGENTS BY LOCATION
**********************************************************************/

SELECT
    l.location_name,
    COUNT(*) AS agent_count,
    CAST(
        COUNT(*) * 100.0 /
        SUM(COUNT(*)) OVER()
        AS DECIMAL(5,2)
    ) AS agent_percentage
FROM employee e
JOIN role r
    ON e.role_id = r.role_id
JOIN location l
    ON e.location_id = l.location_id
WHERE r.role_name IN
(
    'Voice Agent',
    'Email Agent',
    'Trace Agent'
)
GROUP BY l.location_name
ORDER BY agent_count DESC;


/**********************************************************************
5. AGENTS BY SKILL
**********************************************************************/

SELECT
    s.skill_name,
    COUNT(DISTINCT es.employee_id) AS agent_count,
    CAST(
        COUNT(DISTINCT es.employee_id) * 100.0 /
        (
            SELECT COUNT(*)
            FROM employee e
            JOIN role r
                ON e.role_id = r.role_id
            WHERE r.role_name IN
            (
                'Voice Agent',
                'Email Agent',
                'Trace Agent'
            )
        )
        AS DECIMAL(5,2)
    ) AS agent_percentage
FROM employee_skill es
JOIN employee e
    ON es.employee_id = e.employee_id
JOIN role r
    ON e.role_id = r.role_id
JOIN skill s
    ON es.skill_id = s.skill_id
WHERE r.role_name IN
(
    'Voice Agent',
    'Email Agent',
    'Trace Agent'
)
GROUP BY s.skill_name
ORDER BY agent_count DESC;


/**********************************************************************
6. EMPLOYEES BY GENDER
**********************************************************************/

SELECT
    gender,
    COUNT(*) AS employee_count,
    CAST(
        COUNT(*) * 100.0 / SUM(COUNT(*)) OVER()
        AS DECIMAL(5,2)
    ) AS employee_percentage
FROM employee
GROUP BY gender
ORDER BY employee_count DESC;


/**********************************************************************
7. AGE DISTRIBUTION
**********************************************************************/

SELECT
    CASE
        WHEN DATEDIFF(YEAR, birthdate, GETDATE()) < 25
            THEN 'Under 25'

        WHEN DATEDIFF(YEAR, birthdate, GETDATE()) BETWEEN 25 AND 29
            THEN '25-29'

        WHEN DATEDIFF(YEAR, birthdate, GETDATE()) BETWEEN 30 AND 34
            THEN '30-34'

        WHEN DATEDIFF(YEAR, birthdate, GETDATE()) BETWEEN 35 AND 39
            THEN '35-39'

        ELSE '40+'
    END AS age_group,

    COUNT(*) AS employee_count,

    CAST(
        COUNT(*) * 100.0 / SUM(COUNT(*)) OVER()
        AS DECIMAL(5,2)
    ) AS employee_percentage

FROM employee
GROUP BY
    CASE
        WHEN DATEDIFF(YEAR, birthdate, GETDATE()) < 25
            THEN 'Under 25'

        WHEN DATEDIFF(YEAR, birthdate, GETDATE()) BETWEEN 25 AND 29
            THEN '25-29'

        WHEN DATEDIFF(YEAR, birthdate, GETDATE()) BETWEEN 30 AND 34
            THEN '30-34'

        WHEN DATEDIFF(YEAR, birthdate, GETDATE()) BETWEEN 35 AND 39
            THEN '35-39'

        ELSE '40+'
    END
ORDER BY age_group;


/**********************************************************************
8. AVERAGE AGE BY ROLE
**********************************************************************/

SELECT
    r.role_name,

    COUNT(*) AS employee_count,

    CAST(
        AVG(
            CAST(
                DATEDIFF(YEAR, e.birthdate, GETDATE())
                AS DECIMAL(5,2)
            )
        )
        AS DECIMAL(5,2)
    ) AS average_age

FROM employee e
JOIN role r
    ON e.role_id = r.role_id
GROUP BY r.role_name
ORDER BY average_age;


/**********************************************************************
9. SKILL DISTRIBUTION
**********************************************************************/

SELECT
    s.skill_name,
    COUNT(*) AS employee_skill_assignments
FROM employee_skill es
JOIN skill s
    ON es.skill_id = s.skill_id
GROUP BY s.skill_name
ORDER BY employee_skill_assignments DESC;


/**********************************************************************
10. SKILL DISTRIBUTION BY AGENT CHANNEL
**********************************************************************/

SELECT
    CASE
        WHEN r.role_name = 'Voice Agent' THEN 'Voice'
        WHEN r.role_name = 'Email Agent' THEN 'Email'
        WHEN r.role_name = 'Trace Agent' THEN 'Trace'
    END AS channel,

    s.skill_name,

    COUNT(DISTINCT es.employee_id) AS agent_count

FROM employee_skill es

JOIN employee e
    ON es.employee_id = e.employee_id

JOIN role r
    ON e.role_id = r.role_id

JOIN skill s
    ON es.skill_id = s.skill_id

WHERE r.role_name IN
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
    END,
    s.skill_name

ORDER BY
    channel,
    agent_count DESC;


/**********************************************************************
11. AVERAGE NUMBER OF SKILLS PER AGENT
**********************************************************************/

SELECT
    AVG(CAST(skill_count AS DECIMAL(10,2))) AS avg_skills_per_agent
FROM
(
    SELECT
        e.employee_id,
        COUNT(es.skill_id) AS skill_count
    FROM employee e
    JOIN role r
        ON e.role_id = r.role_id
    LEFT JOIN employee_skill es
        ON e.employee_id = es.employee_id
    WHERE r.role_name IN
    (
        'Voice Agent',
        'Email Agent',
        'Trace Agent'
    )
    GROUP BY e.employee_id
) AS agent_skills;


/**********************************************************************
12. AGENTS WITHOUT ANY SKILL
**********************************************************************/

SELECT
    e.employee_id,
    e.first_name,
    e.last_name,
    r.role_name
FROM employee e
JOIN role r
    ON e.role_id = r.role_id
LEFT JOIN employee_skill es
    ON e.employee_id = es.employee_id
WHERE r.role_name IN
(
    'Voice Agent',
    'Email Agent',
    'Trace Agent'
)
AND es.employee_id IS NULL;


/**********************************************************************
END OF WORKFORCE PROFILE
**********************************************************************/
