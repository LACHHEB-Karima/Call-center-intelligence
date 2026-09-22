/*====================================================================
                CALL CENTER INTELLIGENCE
                    DATA QUALITY CHECKS
======================================================================

Purpose:
    Validate the completeness, uniqueness, validity, integrity,
    consistency and business-rule compliance of the operational data
    before analytical processing / data warehouse loading.

Data Quality Dimensions:
    1. Completeness
    2. Uniqueness
    3. Validity
    4. Referential Integrity
    5. Temporal Integrity
    6. Cross-Field Consistency
    7. Business Rule Validation
    8. Relationship / Coverage Checks
====================================================================*/


/**********************************************************************
1. COMPLETENESS
**********************************************************************/

------------------------------------------------------------
-- 1.1 AGENT SESSION - NULL CHECK
------------------------------------------------------------

SELECT
    COUNT(*) AS total_rows,
    COUNT(DISTINCT session_id) AS unique_session_ids,

    SUM(CASE WHEN session_id IS NULL THEN 1 ELSE 0 END)
        AS session_id_nulls,

    SUM(CASE WHEN employee_id IS NULL THEN 1 ELSE 0 END)
        AS employee_id_nulls,

    SUM(CASE WHEN login_datetime IS NULL THEN 1 ELSE 0 END)
        AS login_datetime_nulls,

    SUM(CASE WHEN logout_datetime IS NULL THEN 1 ELSE 0 END)
        AS logout_datetime_nulls

FROM agent_session;


------------------------------------------------------------
-- 1.2 AGENT STATE EVENT - NULL CHECK
------------------------------------------------------------

SELECT
    COUNT(*) AS total_rows,
    COUNT(DISTINCT state_event_id) AS unique_state_event_ids,

    SUM(CASE WHEN state_event_id IS NULL THEN 1 ELSE 0 END)
        AS state_event_id_nulls,

    SUM(CASE WHEN session_id IS NULL THEN 1 ELSE 0 END)
        AS session_id_nulls,

    SUM(CASE WHEN aux_state_id IS NULL THEN 1 ELSE 0 END)
        AS state_id_nulls,

    SUM(CASE WHEN start_datetime IS NULL THEN 1 ELSE 0 END)
        AS start_datetime_nulls,

    SUM(CASE WHEN end_datetime IS NULL THEN 1 ELSE 0 END)
        AS end_datetime_nulls

FROM agent_state_event;


------------------------------------------------------------
-- 1.3 INTERACTION - NULL CHECK
------------------------------------------------------------

SELECT
    COUNT(*) AS total_rows,
    COUNT(DISTINCT interaction_id) AS unique_interaction_ids,

    SUM(CASE WHEN interaction_id IS NULL THEN 1 ELSE 0 END)
        AS interaction_id_nulls,

    SUM(CASE WHEN requestor_id IS NULL THEN 1 ELSE 0 END)
        AS requestor_id_nulls,

    SUM(CASE WHEN employee_id IS NULL THEN 1 ELSE 0 END)
        AS employee_id_nulls,

    SUM(CASE WHEN campaign_id IS NULL THEN 1 ELSE 0 END)
        AS campaign_id_nulls,

    SUM(CASE WHEN channel_id IS NULL THEN 1 ELSE 0 END)
        AS channel_id_nulls,

    SUM(CASE WHEN issue_id IS NULL THEN 1 ELSE 0 END)
        AS issue_id_nulls,

    SUM(CASE WHEN start_datetime IS NULL THEN 1 ELSE 0 END)
        AS start_datetime_nulls,

    SUM(CASE WHEN end_datetime IS NULL THEN 1 ELSE 0 END)
        AS end_datetime_nulls,

    SUM(CASE WHEN handling_duration IS NULL THEN 1 ELSE 0 END)
        AS handling_duration_nulls

FROM interaction;


------------------------------------------------------------
-- 1.4 REVIEW - NULL CHECK
------------------------------------------------------------

SELECT
    COUNT(*) AS total_rows,
    COUNT(DISTINCT review_id) AS unique_review_ids,

    SUM(CASE WHEN review_id IS NULL THEN 1 ELSE 0 END)
        AS review_id_nulls,

    SUM(CASE WHEN interaction_id IS NULL THEN 1 ELSE 0 END)
        AS interaction_id_nulls,

    SUM(CASE WHEN review_channel_id IS NULL THEN 1 ELSE 0 END)
        AS review_channel_id_nulls,

    SUM(CASE WHEN csat IS NULL THEN 1 ELSE 0 END)
        AS csat_nulls,

    SUM(CASE WHEN ease_of_use IS NULL THEN 1 ELSE 0 END)
        AS ease_of_use_nulls,

    SUM(CASE WHEN satisfaction_with_response IS NULL THEN 1 ELSE 0 END)
        AS satisfaction_response_nulls,

    SUM(CASE WHEN resolution IS NULL THEN 1 ELSE 0 END)
        AS resolution_nulls

FROM reviews;


/**********************************************************************
 2. UNIQUENESS
**********************************************************************/

------------------------------------------------------------
-- 2.1 AGENT SESSION - DUPLICATE PRIMARY KEYS
------------------------------------------------------------

WITH duplicates AS
(
    SELECT
        session_id,
        ROW_NUMBER() OVER
        (
            PARTITION BY session_id
            ORDER BY session_id
        ) AS rn
    FROM agent_session
)
SELECT
    COUNT(*) AS duplicate_rows
FROM duplicates
WHERE rn > 1;


------------------------------------------------------------
-- 2.2 AGENT SESSION - DUPLICATE BUSINESS RECORDS
------------------------------------------------------------

SELECT
    employee_id,
    login_datetime,
    logout_datetime,
    COUNT(*) AS duplicate_count
FROM agent_session
GROUP BY
    employee_id,
    login_datetime,
    logout_datetime
HAVING COUNT(*) > 1;


------------------------------------------------------------
-- 2.3 STATE EVENT - DUPLICATE PRIMARY KEYS
------------------------------------------------------------

WITH duplicates AS
(
    SELECT
        state_event_id,
        ROW_NUMBER() OVER
        (
            PARTITION BY state_event_id
            ORDER BY state_event_id
        ) AS rn
    FROM agent_state_event
)
SELECT
    COUNT(*) AS duplicate_rows
FROM duplicates
WHERE rn > 1;


------------------------------------------------------------
-- 2.4 INTERACTION - DUPLICATE PRIMARY KEYS
------------------------------------------------------------

WITH duplicates AS
(
    SELECT
        interaction_id,
        ROW_NUMBER() OVER
        (
            PARTITION BY interaction_id
            ORDER BY interaction_id
        ) AS rn
    FROM interaction
)
SELECT
    COUNT(*) AS duplicate_rows
FROM duplicates
WHERE rn > 1;


------------------------------------------------------------
-- 2.5 INTERACTION - DUPLICATE BUSINESS RECORDS
------------------------------------------------------------

SELECT
    requestor_id,
    employee_id,
    start_datetime,
    end_datetime,
    COUNT(*) AS duplicate_count
FROM interaction
GROUP BY
    requestor_id,
    employee_id,
    start_datetime,
    end_datetime
HAVING COUNT(*) > 1;


------------------------------------------------------------
-- 2.6 REVIEW - DUPLICATE PRIMARY KEYS
------------------------------------------------------------

WITH duplicates AS
(
    SELECT
        review_id,
        ROW_NUMBER() OVER
        (
            PARTITION BY review_id
            ORDER BY review_id
        ) AS rn
    FROM reviews
)
SELECT
    COUNT(*) AS duplicate_rows
FROM duplicates
WHERE rn > 1;


------------------------------------------------------------
-- 2.7 REVIEW - ONE REVIEW PER INTERACTION
------------------------------------------------------------

SELECT
    interaction_id,
    COUNT(*) AS review_count
FROM reviews
GROUP BY interaction_id
HAVING COUNT(*) > 1;


/**********************************************************************
 3. VALIDITY
**********************************************************************/

------------------------------------------------------------
-- 3.1 INVALID REVIEW RATINGS
------------------------------------------------------------

SELECT *
FROM reviews
WHERE
       csat NOT BETWEEN 1 AND 5
    OR ease_of_use NOT BETWEEN 1 AND 5
    OR satisfaction_with_response NOT BETWEEN 1 AND 5
    OR resolution NOT BETWEEN 1 AND 5;


------------------------------------------------------------
-- 3.2 INVALID INTERACTION DURATIONS
------------------------------------------------------------

SELECT *
FROM interaction
WHERE
       wait_time < 0
    OR answer_speed < 0
    OR handling_duration < 0;


------------------------------------------------------------
-- 3.3 INVALID EMPLOYEE BIRTHDATES
------------------------------------------------------------

SELECT *
FROM employee
WHERE birthdate > CAST(GETDATE() AS DATE);


------------------------------------------------------------
-- 3.4 INVALID GENDER VALUES
------------------------------------------------------------

SELECT *
FROM employee
WHERE gender NOT IN ('M', 'F');


------------------------------------------------------------
-- 3.5 INVALID CAMPAIGN REFERENCES
------------------------------------------------------------

SELECT *
FROM interaction
WHERE campaign_id NOT IN
(
    SELECT campaign_id
    FROM campaign
);


------------------------------------------------------------
-- 3.6 INVALID CHANNEL REFERENCES
------------------------------------------------------------

SELECT *
FROM interaction
WHERE channel_id NOT IN
(
    SELECT channel_id
    FROM channel
);


------------------------------------------------------------
-- 3.7 INVALID ISSUE REFERENCES
------------------------------------------------------------

SELECT *
FROM interaction
WHERE issue_id NOT IN
(
    SELECT issue_id
    FROM issue
);


------------------------------------------------------------
-- 3.8 INVALID REVIEW CHANNEL
------------------------------------------------------------

SELECT *
FROM reviews
WHERE review_channel_id NOT IN
(
    SELECT review_channel_id
    FROM review_channel
);


/**********************************************************************
 4. REFERENTIAL INTEGRITY
**********************************************************************/

------------------------------------------------------------
-- 4.1 INTERACTION -> EMPLOYEE
------------------------------------------------------------

SELECT i.*
FROM interaction i
LEFT JOIN employee e
    ON i.employee_id = e.employee_id
WHERE i.employee_id IS NOT NULL
  AND e.employee_id IS NULL;


------------------------------------------------------------
-- 4.2 INTERACTION -> REQUESTOR
------------------------------------------------------------

SELECT i.*
FROM interaction i
LEFT JOIN requestor r
    ON i.requestor_id = r.requestor_id
WHERE r.requestor_id IS NULL;


------------------------------------------------------------
-- 4.3 INTERACTION -> CAMPAIGN
------------------------------------------------------------

SELECT i.*
FROM interaction i
LEFT JOIN campaign c
    ON i.campaign_id = c.campaign_id
WHERE c.campaign_id IS NULL;


------------------------------------------------------------
-- 4.4 INTERACTION -> CHANNEL
------------------------------------------------------------

SELECT i.*
FROM interaction i
LEFT JOIN channel c
    ON i.channel_id = c.channel_id
WHERE c.channel_id IS NULL;


------------------------------------------------------------
-- 4.5 INTERACTION -> ISSUE
------------------------------------------------------------

SELECT i.*
FROM interaction i
LEFT JOIN issue x
    ON i.issue_id = x.issue_id
WHERE x.issue_id IS NULL;


------------------------------------------------------------
-- 4.6 STATE EVENT -> SESSION
------------------------------------------------------------

SELECT ase.*
FROM agent_state_event ase
LEFT JOIN agent_session s
    ON ase.session_id = s.session_id
WHERE s.session_id IS NULL;


------------------------------------------------------------
-- 4.7 STATE EVENT -> AUX STATE
------------------------------------------------------------

SELECT ase.*
FROM agent_state_event ase
LEFT JOIN aux_state a
    ON ase.state_event_id = a.aux_state_id
WHERE a.aux_state_id IS NULL;


------------------------------------------------------------
-- 4.8 REVIEW -> INTERACTION
------------------------------------------------------------

SELECT r.*
FROM reviews r
LEFT JOIN interaction i
    ON r.interaction_id = i.interaction_id
WHERE i.interaction_id IS NULL;


/**********************************************************************
 5. TEMPORAL INTEGRITY
**********************************************************************/

------------------------------------------------------------
-- 5.1 SESSION: LOGOUT BEFORE LOGIN
------------------------------------------------------------

SELECT *
FROM agent_session
WHERE logout_datetime IS NOT NULL
  AND logout_datetime < login_datetime;


------------------------------------------------------------
-- 5.2 STATE EVENT: END BEFORE START
------------------------------------------------------------

SELECT *
FROM agent_state_event
WHERE end_datetime IS NOT NULL
  AND end_datetime < start_datetime;


------------------------------------------------------------
-- 5.3 INTERACTION: END BEFORE START
------------------------------------------------------------

SELECT *
FROM interaction
WHERE end_datetime IS NOT NULL
  AND end_datetime < start_datetime;


------------------------------------------------------------
-- 5.4 INTERACTIONS BEFORE 08:00
------------------------------------------------------------

SELECT *
FROM interaction
WHERE CAST(start_datetime AS TIME) < '08:00:00';


------------------------------------------------------------
-- 5.5 INTERACTION OUTSIDE EMPLOYEE SESSION
------------------------------------------------------------

SELECT i.*
FROM interaction i
LEFT JOIN agent_session s
    ON i.employee_id = s.employee_id
   AND i.start_datetime >= s.login_datetime
   AND i.end_datetime <= s.logout_datetime
WHERE i.employee_id IS NOT NULL
  AND s.session_id IS NULL;


------------------------------------------------------------
-- 5.6 OVERLAPPING INTERACTIONS
------------------------------------------------------------

SELECT
    a.employee_id,
    a.interaction_id AS interaction_1,
    b.interaction_id AS interaction_2,
    a.start_datetime AS interaction_1_start,
    a.end_datetime AS interaction_1_end,
    b.start_datetime AS interaction_2_start,
    b.end_datetime AS interaction_2_end
FROM interaction a
JOIN interaction b
    ON a.employee_id = b.employee_id
   AND a.interaction_id < b.interaction_id
   AND a.start_datetime < b.end_datetime
   AND b.start_datetime < a.end_datetime;


------------------------------------------------------------
-- 5.7 OVERLAPPING STATE EVENTS
------------------------------------------------------------

SELECT
    a.session_id,
    a.state_event_id AS state_event_1,
    b.state_event_id AS state_event_2
FROM agent_state_event a
JOIN agent_state_event b
    ON a.session_id = b.session_id
   AND a.state_event_id < b.state_event_id
   AND a.start_datetime < b.end_datetime
   AND b.start_datetime < a.end_datetime;


/**********************************************************************
 6. CROSS-FIELD CONSISTENCY
**********************************************************************/

------------------------------------------------------------
-- 6.1 INTERACTION CANNOT BE ANSWERED AND ABANDONED
------------------------------------------------------------

SELECT *
FROM interaction
WHERE answered = 1
  AND abandoned = 1;


------------------------------------------------------------
-- 6.2 ABANDONED INTERACTION SHOULD NOT HAVE AN AGENT
------------------------------------------------------------

SELECT *
FROM interaction
WHERE abandoned = 1
  AND employee_id IS NOT NULL;


------------------------------------------------------------
-- 6.3 COMPLETED INTERACTION SHOULD HAVE END TIME
------------------------------------------------------------

SELECT *
FROM interaction
WHERE end_interaction = 1
  AND end_datetime IS NULL;


------------------------------------------------------------
-- 6.4 ENDED INTERACTION SHOULD HAVE END TIME
------------------------------------------------------------

SELECT *
FROM interaction
WHERE end_interaction = 1
  AND end_datetime IS NULL;


------------------------------------------------------------
-- 6.5 EMAIL SUBJECT ONLY FOR EMAIL
------------------------------------------------------------

SELECT *
FROM interaction
WHERE channel_id <> 2
  AND email_subject IS NOT NULL;


------------------------------------------------------------
-- 6.6 NON-EMAIL INTERACTION SHOULD NOT HAVE EMAIL SUBJECT
------------------------------------------------------------

SELECT *
FROM interaction
WHERE channel_id = 2
  AND email_subject IS NULL;


------------------------------------------------------------
-- 6.7 ABANDONED INTERACTION SHOULD NOT HAVE HANDLING TIME
------------------------------------------------------------

SELECT *
FROM interaction
WHERE abandoned = 1
  AND handling_duration IS NOT NULL;


------------------------------------------------------------
-- 6.8 ABANDONED INTERACTION SHOULD NOT HAVE ANSWER SPEED
------------------------------------------------------------

SELECT *
FROM interaction
WHERE abandoned = 1
  AND answer_speed IS NOT NULL;


------------------------------------------------------------
-- 6.9 ANSWERED INTERACTION SHOULD HAVE AN EMPLOYEE
------------------------------------------------------------

SELECT *
FROM interaction
WHERE answered = 1
  AND employee_id IS NULL;


/**********************************************************************
 7. BUSINESS RULE VALIDATION
**********************************************************************/

------------------------------------------------------------
-- 7.1 EMPLOYEE ROLE MUST MATCH INTERACTION CHANNEL
--
-- Phone  -> Voice Agent
-- Email  -> Email Agent
-- Trace  -> Trace Agent
------------------------------------------------------------

SELECT
    i.interaction_id,
    i.employee_id,
    c.channel_name,
    r.role_name
FROM interaction i
JOIN employee e
    ON i.employee_id = e.employee_id
JOIN role r
    ON e.role_id = r.role_id
JOIN channel c
    ON i.channel_id = c.channel_id
WHERE
       (c.channel_name = 'Phone'
        AND r.role_name <> 'Voice Agent')

    OR (c.channel_name = 'Email'
        AND r.role_name <> 'Email Agent')

    OR (c.channel_name = 'Trace'
        AND r.role_name <> 'Trace Agent');


------------------------------------------------------------
-- 7.2 REVIEWS SHOULD NOT EXIST FOR TRACE INTERACTIONS
------------------------------------------------------------

SELECT r.*
FROM reviews r
JOIN interaction i
    ON r.interaction_id = i.interaction_id
WHERE i.channel_id = 3;


------------------------------------------------------------
-- 7.3 REVIEWS SHOULD NOT EXIST FOR ABANDONED INTERACTIONS
------------------------------------------------------------

SELECT r.*
FROM reviews r
JOIN interaction i
    ON r.interaction_id = i.interaction_id
WHERE i.abandoned = 1;


------------------------------------------------------------
-- 7.4 REVIEW CHANNEL MUST MATCH INTERACTION CHANNEL
--
-- Phone interaction -> Phone review
-- Email interaction -> Email Link review
------------------------------------------------------------

SELECT
    r.review_id,
    r.interaction_id,
    i.channel_id,
    r.review_channel_id
FROM reviews r
JOIN interaction i
    ON r.interaction_id = i.interaction_id
WHERE
       (i.channel_id = 1 AND r.review_channel_id <> 1)
    OR (i.channel_id = 2 AND r.review_channel_id <> 2);


------------------------------------------------------------
-- 7.5 VOICE INTERACTIONS MUST BELONG TO VOICE AGENTS
------------------------------------------------------------

SELECT i.*
FROM interaction i
JOIN employee e
    ON i.employee_id = e.employee_id
JOIN role r
    ON e.role_id = r.role_id
WHERE i.channel_id = 1
  AND r.role_name <> 'Voice Agent';


------------------------------------------------------------
-- 7.6 EMAIL INTERACTIONS MUST BELONG TO EMAIL AGENTS
------------------------------------------------------------

SELECT i.*
FROM interaction i
JOIN employee e
    ON i.employee_id = e.employee_id
JOIN role r
    ON e.role_id = r.role_id
WHERE i.channel_id = 2
  AND r.role_name <> 'Email Agent';


------------------------------------------------------------
-- 7.7 TRACE INTERACTIONS MUST BELONG TO TRACE AGENTS
------------------------------------------------------------

SELECT i.*
FROM interaction i
JOIN employee e
    ON i.employee_id = e.employee_id
JOIN role r
    ON e.role_id = r.role_id
WHERE i.channel_id = 3
  AND r.role_name <> 'Trace Agent';


/**********************************************************************
 8. EMPLOYEE / SKILL CONSISTENCY
**********************************************************************/

------------------------------------------------------------
-- 8.1 INTERACTION EMPLOYEE DOES NOT HAVE ANY SKILL
--
-- This identifies employees who have no skill assignment.
------------------------------------------------------------

SELECT
    e.employee_id,
    e.first_name,
    e.last_name
FROM employee e
LEFT JOIN employee_skill es
    ON e.employee_id = es.employee_id
WHERE es.employee_id IS NULL;


------------------------------------------------------------
-- 8.2 DUPLICATE EMPLOYEE-SKILL ASSIGNMENTS
------------------------------------------------------------

SELECT
    employee_id,
    skill_id,
    COUNT(*) AS duplicate_count
FROM employee_skill
GROUP BY
    employee_id,
    skill_id
HAVING COUNT(*) > 1;


/**********************************************************************
 9. ROLE / AUX STATE CONSISTENCY
**********************************************************************/

------------------------------------------------------------
-- 9.1 STATE EVENT NOT AUTHORIZED FOR EMPLOYEE ROLE
------------------------------------------------------------

SELECT
    ase.state_event_id,
    s.session_id,
    s.employee_id,
    e.role_id,
    ase.state_id
FROM agent_state_event ase
JOIN agent_session s
    ON ase.session_id = s.session_id
JOIN employee e
    ON s.employee_id = e.employee_id
LEFT JOIN role_state rs
    ON e.role_id = rs.role_id
   AND ase.state_id = rs.state_id
WHERE rs.role_id IS NULL;


/**********************************************************************
10. ACTIVITY / SESSION CONSISTENCY
**********************************************************************/

------------------------------------------------------------
-- 10.1 STATE EVENT MUST BE INSIDE SESSION
------------------------------------------------------------

SELECT ase.*
FROM agent_state_event ase
JOIN agent_session s
    ON ase.session_id = s.session_id
WHERE
       ase.start_datetime < s.login_datetime
    OR ase.end_datetime > s.logout_datetime;


------------------------------------------------------------
-- 10.2 STATE EVENT SHOULD BELONG TO THE SESSION EMPLOYEE
--
-- This is structurally guaranteed through session_id,
-- but the check confirms the relationship.
------------------------------------------------------------

SELECT
    ase.state_event_id,
    ase.session_id,
    s.employee_id
FROM agent_state_event ase
LEFT JOIN agent_session s
    ON ase.session_id = s.session_id
WHERE s.session_id IS NULL;


/**********************************************************************
11. DATASET COVERAGE / EXPECTED PERIOD
**********************************************************************/

------------------------------------------------------------
-- 11.1 INTERACTION DATE RANGE
------------------------------------------------------------

SELECT
    MIN(start_datetime) AS first_interaction,
    MAX(start_datetime) AS last_interaction
FROM interaction;


------------------------------------------------------------
-- 11.2 SESSION DATE RANGE
------------------------------------------------------------

SELECT
    MIN(login_datetime) AS first_login,
    MAX(login_datetime) AS last_login
FROM agent_session;


------------------------------------------------------------
-- 11.3 REVIEW DATE RANGE THROUGH INTERACTION
------------------------------------------------------------

SELECT
    MIN(i.start_datetime) AS first_reviewed_interaction,
    MAX(i.start_datetime) AS last_reviewed_interaction
FROM reviews r
JOIN interaction i
    ON r.interaction_id = i.interaction_id;


/**********************************************************************
12. QUICK QUALITY SUMMARY
**********************************************************************/

------------------------------------------------------------
-- OVERALL INTERACTION QUALITY SUMMARY
------------------------------------------------------------

SELECT
    COUNT(*) AS total_interactions,

    SUM(CASE
        WHEN interaction_id IS NULL
          OR requestor_id IS NULL
          OR campaign_id IS NULL
          OR channel_id IS NULL
          OR issue_id IS NULL
          OR start_datetime IS NULL
        THEN 1 ELSE 0
    END) AS incomplete_records,

    SUM(CASE
        WHEN end_datetime < start_datetime
        THEN 1 ELSE 0
    END) AS temporal_errors,

    SUM(CASE
        WHEN answered = 1 AND abandoned = 1
        THEN 1 ELSE 0
    END) AS logical_errors,

    SUM(CASE
        WHEN abandoned = 1 AND employee_id IS NOT NULL
        THEN 1 ELSE 0
    END) AS abandoned_with_agent

FROM interaction;


/**********************************************************************
END OF DATA QUALITY CHECKS
**********************************************************************/