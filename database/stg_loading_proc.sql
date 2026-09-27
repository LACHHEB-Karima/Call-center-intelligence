/*
================================================================
CALL CENTER INTELLIGENCE
STAGING / SILVER LAYER
MASTER STAGING LOAD PROCEDURE
================================================================

Pipeline:
dbo -> STG

Execution:
EXEC etl.usp_load_stg;

Notes:
- Full refresh of STG
- Transactional load
- Uses dbo.reviews and stg.reviews
- SQL Server / SSMS 2022
================================================================
*/

USE CallCenter;
GO

IF NOT EXISTS
(
SELECT 1
FROM sys.schemas
WHERE name = 'etl'
)
BEGIN
EXEC('CREATE SCHEMA etl');
END;
GO

IF OBJECT_ID('etl.load_log', 'U') IS NULL
BEGIN
CREATE TABLE etl.load_log
(
    load_id             BIGINT IDENTITY(1,1) PRIMARY KEY,
    pipeline_name       VARCHAR(100) NOT NULL,
    start_time          DATETIME2(0) NOT NULL,
    end_time            DATETIME2(0) NULL,
    status              VARCHAR(20) NOT NULL,
    rows_employee       INT NULL,
    rows_employee_skill INT NULL,
    rows_requestor      INT NULL,
    rows_session        INT NULL,
    rows_state_event    INT NULL,
    rows_interaction    INT NULL,
    rows_review         INT NULL,
    error_number        INT NULL,
    error_message       NVARCHAR(4000) NULL,
    created_at          DATETIME2(0) NOT NULL DEFAULT SYSDATETIME()
);
END;
GO

CREATE OR ALTER PROCEDURE etl.usp_load_stg
AS
BEGIN
SET NOCOUNT ON;
SET XACT_ABORT ON;

DECLARE
    @LoadID BIGINT,
    @StartTime DATETIME2(0) = SYSDATETIME(),
    @EndTime DATETIME2(0),
    @RowsEmployee INT = 0,
    @RowsEmployeeSkill INT = 0,
    @RowsRequestor INT = 0,
    @RowsSession INT = 0,
    @RowsStateEvent INT = 0,
    @RowsInteraction INT = 0,
    @RowsReview INT = 0,
    @ErrorNumber INT,
    @ErrorMessage NVARCHAR(4000);

INSERT INTO etl.load_log
(
    pipeline_name,
    start_time,
    status
)
VALUES
(
    'STG_FULL_LOAD',
    @StartTime,
    'RUNNING'
);

SET @LoadID = CONVERT(BIGINT, SCOPE_IDENTITY());

BEGIN TRY
    BEGIN TRANSACTION;

    PRINT '-----------------------------------------------';
    PRINT 'STG LOAD STARTED';
    PRINT 'Load ID: ' + CAST(@LoadID AS VARCHAR(30));
    PRINT '-----------------------------------------------';

    /*======================================================
        1. CLEAR STAGING
    ======================================================*/
    PRINT 'Clearing staging tables...';

    TRUNCATE TABLE stg.reviews;
    TRUNCATE TABLE stg.interaction;
    TRUNCATE TABLE stg.agent_state_event;
    TRUNCATE TABLE stg.agent_session;
    TRUNCATE TABLE stg.employee_skill;
    TRUNCATE TABLE stg.requestor;
    TRUNCATE TABLE stg.employee;
    TRUNCATE TABLE stg.aux_state;
    TRUNCATE TABLE stg.issue;
    TRUNCATE TABLE stg.campaign;
    TRUNCATE TABLE stg.channel;

    /*======================================================
        2. AUX STATES
    ======================================================*/
    PRINT 'Loading AUX states...';

    INSERT INTO stg.aux_state
    (
        aux_state_id,
        state_name,
        state_category,
        load_datetime
    )
    SELECT
        aux_state_id,
        NULLIF(LTRIM(RTRIM(aux_state_name)), ''),
        NULLIF(LTRIM(RTRIM(category)), ''),
        SYSDATETIME()
    FROM dbo.aux_state;

    /*======================================================
        3. CHANNELS
    ======================================================*/
    PRINT 'Loading channels...';

    INSERT INTO stg.channel
    (
        channel_id,
        channel_name,
        load_datetime
    )
    SELECT
        channel_id,
        NULLIF(LTRIM(RTRIM(channel_name)), ''),
        SYSDATETIME()
    FROM dbo.channel;

    /*======================================================
        4. CAMPAIGNS
    ======================================================*/
    PRINT 'Loading campaigns...';

    INSERT INTO stg.campaign
    (
        campaign_id,
        campaign_name,
        description,
        load_datetime
    )
    SELECT
        campaign_id,
        NULLIF(LTRIM(RTRIM(campaign_name)), ''),
        NULLIF(LTRIM(RTRIM(description)), ''),
        SYSDATETIME()
    FROM dbo.campaign;

    /*======================================================
        5. ISSUES
    ======================================================*/
    PRINT 'Loading issues...';

    INSERT INTO stg.issue
    (
        issue_id,
        issue_name,
        description,
        load_datetime
    )
    SELECT
        issue_id,
        NULLIF(LTRIM(RTRIM(issue_name)), ''),
        NULLIF(LTRIM(RTRIM(description)), ''),
        SYSDATETIME()
    FROM dbo.issue;

    /*======================================================
        6. EMPLOYEES
    ======================================================*/
    PRINT 'Loading employees...';

    INSERT INTO stg.employee
    (
        employee_id,
        first_name,
        last_name,
        full_name,
        birthdate,
        gender,
        role_id,
        role_name,
        location_id,
        location_name,
        is_agent,
        agent_channel,
        load_datetime
    )
    SELECT
        e.employee_id,
        NULLIF(LTRIM(RTRIM(e.first_name)), ''),
        NULLIF(LTRIM(RTRIM(e.last_name)), ''),
        NULLIF(
            LTRIM(RTRIM(e.first_name)) + ' ' + LTRIM(RTRIM(e.last_name)),
            ''
        ),
        e.birthdate,
        UPPER(NULLIF(LTRIM(RTRIM(e.gender)), '')),
        e.role_id,
        NULLIF(LTRIM(RTRIM(r.role_name)), ''),
        e.location_id,
        NULLIF(LTRIM(RTRIM(l.location_name)), ''),
        CASE
            WHEN r.role_name IN ('Voice Agent', 'Email Agent', 'Trace Agent')
                THEN 1
            ELSE 0
        END,
        CASE
            WHEN r.role_name = 'Voice Agent' THEN 'Voice'
            WHEN r.role_name = 'Email Agent' THEN 'Email'
            WHEN r.role_name = 'Trace Agent' THEN 'Trace'
            ELSE NULL
        END,
        SYSDATETIME()
    FROM dbo.employee e
    INNER JOIN dbo.role r
        ON e.role_id = r.role_id
    INNER JOIN dbo.location l
        ON e.location_id = l.location_id;

    SET @RowsEmployee = @@ROWCOUNT;

    /*======================================================
        7. EMPLOYEE SKILLS
    ======================================================*/
    PRINT 'Loading employee skills...';

    INSERT INTO stg.employee_skill
    (
        employee_id,
        skill_id,
        skill_name,
        load_datetime
    )
    SELECT
        es.employee_id,
        es.skill_id,
        NULLIF(LTRIM(RTRIM(s.skill_name)), ''),
        SYSDATETIME()
    FROM dbo.employee_skill es
    INNER JOIN dbo.skill s
        ON es.skill_id = s.skill_id;

    SET @RowsEmployeeSkill = @@ROWCOUNT;

    /*======================================================
        8. REQUESTORS
    ======================================================*/
    PRINT 'Loading requestors...';

    INSERT INTO stg.requestor
    (
        requestor_id,
        phone_number,
        email,
        location_id,
        location_name,
        load_datetime
    )
    SELECT
        r.requestor_id,
        NULLIF(LTRIM(RTRIM(r.phone_number)), ''),
        NULLIF(LOWER(LTRIM(RTRIM(r.email))), ''),
        r.location_id,
        NULLIF(LTRIM(RTRIM(l.location_name)), ''),
        SYSDATETIME()
    FROM dbo.requestor r
    INNER JOIN dbo.location l
        ON r.location_id = l.location_id;

    SET @RowsRequestor = @@ROWCOUNT;

    /*======================================================
        9. AGENT SESSIONS
    ======================================================*/
    PRINT 'Loading agent sessions...';

    INSERT INTO stg.agent_session
    (
        session_id,
        employee_id,
        login_datetime,
        logout_datetime,
        session_date,
        login_time,
        logout_time,
        worked_seconds,
        worked_hours,
        late_minutes,
        early_departure_minutes,
        is_present,
        load_datetime
    )
    SELECT
        s.session_id,
        s.employee_id,
        s.login_datetime,
        s.logout_datetime,
        CAST(s.login_datetime AS DATE),
        CAST(s.login_datetime AS TIME(0)),
        CASE
            WHEN s.logout_datetime IS NOT NULL
                THEN CAST(s.logout_datetime AS TIME(0))
            ELSE NULL
        END,
        CASE
            WHEN s.logout_datetime IS NOT NULL
                THEN DATEDIFF(SECOND, s.login_datetime, s.logout_datetime)
            ELSE NULL
        END,
        CASE
            WHEN s.logout_datetime IS NOT NULL
                THEN CAST(
                    DATEDIFF(SECOND, s.login_datetime, s.logout_datetime) / 3600.0
                    AS DECIMAL(10,2)
                )
            ELSE NULL
        END,
        CASE
            WHEN CAST(s.login_datetime AS TIME) > CAST('08:00:00' AS TIME)
                THEN DATEDIFF(
                    MINUTE,
                    CAST('08:00:00' AS TIME),
                    CAST(s.login_datetime AS TIME)
                )
            ELSE 0
        END,
        CASE
            WHEN s.logout_datetime IS NOT NULL
                AND CAST(s.logout_datetime AS TIME) < CAST('17:00:00' AS TIME)
                THEN DATEDIFF(
                    MINUTE,
                    CAST(s.logout_datetime AS TIME),
                    CAST('17:00:00' AS TIME)
                )
            ELSE 0
        END,
        CASE
            WHEN s.login_datetime IS NOT NULL THEN 1
            ELSE 0
        END,
        SYSDATETIME()
    FROM dbo.agent_session s;

    SET @RowsSession = @@ROWCOUNT;

    /*======================================================
        10. AGENT STATE EVENTS
    ======================================================*/
    PRINT 'Loading agent state events...';

    INSERT INTO stg.agent_state_event
    (
        state_event_id,
        session_id,
        employee_id,
        aux_state_id,
        state_name,
        state_category,
        start_datetime,
        end_datetime,
        event_date,
        duration_seconds,
        duration_minutes,
        load_datetime
    )
    SELECT
        ase.state_event_id,
        ase.session_id,
        s.employee_id,
        ase.aux_state_id,
        NULLIF(LTRIM(RTRIM(a.state_name)), ''),
        NULLIF(LTRIM(RTRIM(a.state_category)), ''),
        ase.start_datetime,
        ase.end_datetime,
        CAST(ase.start_datetime AS DATE),
        CASE
            WHEN ase.end_datetime IS NOT NULL
                THEN DATEDIFF(SECOND, ase.start_datetime, ase.end_datetime)
            ELSE NULL
        END,
        CASE
            WHEN ase.end_datetime IS NOT NULL
                THEN DATEDIFF(SECOND, ase.start_datetime, ase.end_datetime) / 60.0
            ELSE NULL
        END,
        SYSDATETIME()
    FROM dbo.agent_state_event ase
    INNER JOIN dbo.agent_session s
        ON ase.session_id = s.session_id
    INNER JOIN stg.aux_state a
        ON ase.aux_state_id = a.aux_state_id;

    SET @RowsStateEvent = @@ROWCOUNT;

    /*======================================================
        11. INTERACTIONS
    ======================================================*/
    PRINT 'Loading interactions...';

    INSERT INTO stg.interaction
    (
        interaction_id,
        requestor_id,
        employee_id,
        campaign_id,
        channel_id,
        issue_id,
        start_datetime,
        end_datetime,
        interaction_date,
        interaction_hour,
        day_of_week,
        month_number,
        year_number,
        wait_time_seconds,
        answer_speed_seconds,
        handling_duration_seconds,
        email_subject,
        external_reference,
        answered,
        abandoned,
        end_interaction,
        interaction_status,
        temporal_valid,
        business_rule_valid,
        load_datetime
    )
    SELECT
        i.interaction_id,
        i.requestor_id,
        i.employee_id,
        i.campaign_id,
        i.channel_id,
        i.issue_id,
        i.start_datetime,
        i.end_datetime,
        CAST(i.start_datetime AS DATE),
        DATEPART(HOUR, i.start_datetime),
        DATENAME(WEEKDAY, i.start_datetime),
        DATEPART(MONTH, i.start_datetime),
        DATEPART(YEAR, i.start_datetime),
        i.wait_time,
        i.answer_speed,
        i.handling_duration,
        CASE
            WHEN i.channel_id = 2
                THEN NULLIF(LTRIM(RTRIM(i.email_subject)), '')
            ELSE NULL
        END,
        NULLIF(LTRIM(RTRIM(i.external_reference)), ''),
        i.answered,
        i.abandoned,
        i.end_interaction,
        CASE
            WHEN i.abandoned = 1 THEN 'Abandoned'
            WHEN i.answered = 1 AND i.end_interaction = 1 THEN 'Completed'
            WHEN i.end_interaction = 0 THEN 'In Progress'
            ELSE 'Unknown'
        END,
        CASE
            WHEN i.end_datetime IS NULL THEN 0
            WHEN i.end_datetime >= i.start_datetime THEN 1
            ELSE 0
        END,
        CASE
            WHEN i.answered = 1 AND i.abandoned = 1 THEN 0
            WHEN i.abandoned = 1 AND i.employee_id IS NOT NULL THEN 0
            WHEN i.answered = 1 AND i.employee_id IS NULL THEN 0
            WHEN i.end_datetime IS NOT NULL AND i.end_datetime < i.start_datetime THEN 0
            ELSE 1
        END,
        SYSDATETIME()
    FROM dbo.interaction i;

    SET @RowsInteraction = @@ROWCOUNT;

    /*======================================================
        12. REVIEWS

        IMPORTANT:
        Source table = dbo.reviews
        STG table    = stg.reviews

        LEFT JOIN is intentional because a review may exist
        without an interaction_id (for example an email-link
        review). Such reviews must not disappear from STG.
    ======================================================*/
    PRINT 'Loading reviews...';

    INSERT INTO stg.reviews
    (
        review_id,
        interaction_id,
        employee_id,
        channel_id,
        review_channel_id,
        review_channel_name,
        review_date,
        csat,
        hero,
        ease_of_use,
        satisfaction_with_response,
        resolution,
        comment,
        is_positive_csat,
        is_resolved,
        load_datetime
    )
    SELECT
        r.review_id,
        r.interaction_id,
        i.employee_id,
        i.channel_id,
        r.review_channel_id,
        NULLIF(LTRIM(RTRIM(rc.review_channel_name)), ''),
        CAST(i.end_datetime AS DATE),
        r.csat,
        r.hero,
        r.ease_of_use,
        r.satisfaction_with_response,
        r.resolution,
        NULLIF(LTRIM(RTRIM(r.comment)), ''),
        CASE
            WHEN r.csat >= 4 THEN 1
            ELSE 0
        END,
        CASE
            WHEN r.resolution >= 4 THEN 1
            ELSE 0
        END,
        SYSDATETIME()
    FROM dbo.reviews r
    LEFT JOIN dbo.interaction i
        ON r.interaction_id = i.interaction_id
    LEFT JOIN dbo.review_channel rc
        ON r.review_channel_id = rc.review_channel_id;

    SET @RowsReview = @@ROWCOUNT;

    /*======================================================
        13. ROW COUNT VALIDATION
    ======================================================*/
    PRINT '-----------------------------------------------';
    PRINT 'RUNNING STAGING VALIDATIONS';
    PRINT '-----------------------------------------------';

    IF @RowsEmployee <> (SELECT COUNT(*) FROM dbo.employee)
    BEGIN
        THROW 50001, 'STG validation failed: employee row count mismatch.', 1;
    END;

    IF @RowsEmployeeSkill <> (SELECT COUNT(*) FROM dbo.employee_skill)
    BEGIN
        THROW 50002, 'STG validation failed: employee_skill row count mismatch.', 1;
    END;

    IF @RowsRequestor <> (SELECT COUNT(*) FROM dbo.requestor)
    BEGIN
        THROW 50003, 'STG validation failed: requestor row count mismatch.', 1;
    END;

    IF @RowsSession <> (SELECT COUNT(*) FROM dbo.agent_session)
    BEGIN
        THROW 50004, 'STG validation failed: agent_session row count mismatch.', 1;
    END;

    IF @RowsStateEvent <> (SELECT COUNT(*) FROM dbo.agent_state_event)
    BEGIN
        THROW 50005, 'STG validation failed: agent_state_event row count mismatch.', 1;
    END;

    IF @RowsInteraction <> (SELECT COUNT(*) FROM dbo.interaction)
    BEGIN
        THROW 50006, 'STG validation failed: interaction row count mismatch.', 1;
    END;

    IF @RowsReview <> (SELECT COUNT(*) FROM dbo.reviews)
    BEGIN
        THROW 50007, 'STG validation failed: reviews row count mismatch.', 1;
    END;

    /*======================================================
        14. DUPLICATE VALIDATION
    ======================================================*/
    IF EXISTS
    (
        SELECT employee_id
        FROM stg.employee
        GROUP BY employee_id
        HAVING COUNT(*) > 1
    )
    BEGIN
        THROW 50008, 'STG validation failed: duplicate employee_id.', 1;
    END;

    IF EXISTS
    (
        SELECT interaction_id
        FROM stg.interaction
        GROUP BY interaction_id
        HAVING COUNT(*) > 1
    )
    BEGIN
        THROW 50009, 'STG validation failed: duplicate interaction_id.', 1;
    END;

    IF EXISTS
    (
        SELECT review_id
        FROM stg.reviews
        GROUP BY review_id
        HAVING COUNT(*) > 1
    )
    BEGIN
        THROW 50010, 'STG validation failed: duplicate review_id.', 1;
    END;

    IF EXISTS
    (
        SELECT session_id
        FROM stg.agent_session
        GROUP BY session_id
        HAVING COUNT(*) > 1
    )
    BEGIN
        THROW 50011, 'STG validation failed: duplicate session_id.', 1;
    END;

    /*======================================================
        15. INTERACTION VALIDATION
    ======================================================*/
    IF EXISTS
    (
        SELECT 1
        FROM stg.interaction
        WHERE answered = 1
            AND abandoned = 1
    )
    BEGIN
        THROW 50012, 'STG validation failed: interaction cannot be both answered and abandoned.', 1;
    END;

    IF EXISTS
    (
        SELECT 1
        FROM stg.interaction
        WHERE abandoned = 1
            AND employee_id IS NOT NULL
    )
    BEGIN
        THROW 50013, 'STG validation failed: abandoned interaction has an employee.', 1;
    END;

    IF EXISTS
    (
        SELECT 1
        FROM stg.interaction
        WHERE answered = 1
            AND employee_id IS NULL
    )
    BEGIN
        THROW 50014, 'STG validation failed: answered interaction has no employee.', 1;
    END;

    IF EXISTS
    (
        SELECT 1
        FROM stg.interaction
        WHERE end_datetime IS NOT NULL
            AND end_datetime < start_datetime
    )
    BEGIN
        THROW 50015, 'STG validation failed: interaction ends before it starts.', 1;
    END;

    /*======================================================
        16. SESSION VALIDATION
    ======================================================*/
    IF EXISTS
    (
        SELECT 1
        FROM stg.agent_session
        WHERE logout_datetime IS NOT NULL
            AND logout_datetime < login_datetime
    )
    BEGIN
        THROW 50016, 'STG validation failed: session logout occurs before login.', 1;
    END;

    IF EXISTS
    (
        SELECT 1
        FROM stg.agent_session
        WHERE worked_seconds < 0
    )
    BEGIN
        THROW 50017, 'STG validation failed: negative worked duration.', 1;
    END;

    /*======================================================
        17. STATE EVENT VALIDATION
    ======================================================*/
    IF EXISTS
    (
        SELECT 1
        FROM stg.agent_state_event
        WHERE end_datetime IS NOT NULL
            AND end_datetime < start_datetime
    )
    BEGIN
        THROW 50018, 'STG validation failed: state event ends before it starts.', 1;
    END;

    IF EXISTS
    (
        SELECT 1
        FROM stg.agent_state_event
        WHERE duration_seconds < 0
    )
    BEGIN
        THROW 50019, 'STG validation failed: negative state event duration.', 1;
    END;

    /*======================================================
        18. REVIEW VALIDATION
    ======================================================*/
    IF EXISTS
    (
        SELECT 1
        FROM stg.reviews
        WHERE csat IS NOT NULL
            AND (csat < 1 OR csat > 5)
    )
    BEGIN
        THROW 50020, 'STG validation failed: CSAT outside 1-5 range.', 1;
    END;

    IF EXISTS
    (
        SELECT 1
        FROM stg.reviews
        WHERE ease_of_use IS NOT NULL
            AND (ease_of_use < 1 OR ease_of_use > 5)
    )
    BEGIN
        THROW 50021, 'STG validation failed: ease_of_use outside 1-5 range.', 1;
    END;

    IF EXISTS
    (
        SELECT 1
        FROM stg.reviews
        WHERE satisfaction_with_response IS NOT NULL
            AND (satisfaction_with_response < 1 OR satisfaction_with_response > 5)
    )
    BEGIN
        THROW 50022, 'STG validation failed: satisfaction_with_response outside 1-5 range.', 1;
    END;

    IF EXISTS
    (
        SELECT 1
        FROM stg.reviews
        WHERE resolution IS NOT NULL
            AND (resolution < 1 OR resolution > 5)
    )
    BEGIN
        THROW 50023, 'STG validation failed: resolution outside 1-5 range.', 1;
    END;

    /*
        Reviews with interaction_id NULL are allowed.
        For linked interactions, validate the business rules.
    */
    IF EXISTS
    (
        SELECT 1
        FROM stg.reviews r
        INNER JOIN stg.interaction i
            ON r.interaction_id = i.interaction_id
        WHERE i.abandoned = 1
    )
    BEGIN
        THROW 50024, 'STG validation failed: abandoned interaction has a review.', 1;
    END;

    IF EXISTS
    (
        SELECT 1
        FROM stg.reviews r
        INNER JOIN stg.interaction i
            ON r.interaction_id = i.interaction_id
        WHERE i.channel_id = 3
    )
    BEGIN
        THROW 50025, 'STG validation failed: Trace interaction has a review.', 1;
    END;

    /*======================================================
        19. COMMIT
    ======================================================*/
    COMMIT TRANSACTION;

    /*======================================================
        20. SUCCESS LOG
    ======================================================*/
    SET @EndTime = SYSDATETIME();

    UPDATE etl.load_log
    SET
        end_time = @EndTime,
        status = 'SUCCESS',
        rows_employee = @RowsEmployee,
        rows_employee_skill = @RowsEmployeeSkill,
        rows_requestor = @RowsRequestor,
        rows_session = @RowsSession,
        rows_state_event = @RowsStateEvent,
        rows_interaction = @RowsInteraction,
        rows_review = @RowsReview
    WHERE load_id = @LoadID;

    SELECT
        @LoadID AS load_id,
        'STG_FULL_LOAD' AS pipeline_name,
        @StartTime AS start_time,
        @EndTime AS end_time,
        DATEDIFF(SECOND, @StartTime, @EndTime) AS duration_seconds,
        'SUCCESS' AS status,
        @RowsEmployee AS employees_loaded,
        @RowsEmployeeSkill AS employee_skills_loaded,
        @RowsRequestor AS requestors_loaded,
        @RowsSession AS sessions_loaded,
        @RowsStateEvent AS state_events_loaded,
        @RowsInteraction AS interactions_loaded,
        @RowsReview AS reviews_loaded;
END TRY
BEGIN CATCH
    IF XACT_STATE() <> 0
    BEGIN
        ROLLBACK TRANSACTION;
    END;

    SET @ErrorNumber = ERROR_NUMBER();
    SET @ErrorMessage = ERROR_MESSAGE();
    SET @EndTime = SYSDATETIME();

    UPDATE etl.load_log
    SET
        end_time = @EndTime,
        status = 'FAILED',
        rows_employee = @RowsEmployee,
        rows_employee_skill = @RowsEmployeeSkill,
        rows_requestor = @RowsRequestor,
        rows_session = @RowsSession,
        rows_state_event = @RowsStateEvent,
        rows_interaction = @RowsInteraction,
        rows_review = @RowsReview,
        error_number = @ErrorNumber,
        error_message = @ErrorMessage
    WHERE load_id = @LoadID;

    SELECT
        @LoadID AS load_id,
        'STG_FULL_LOAD' AS pipeline_name,
        @StartTime AS start_time,
        @EndTime AS end_time,
        DATEDIFF(SECOND, @StartTime, @EndTime) AS duration_seconds,
        'FAILED' AS status,
        @ErrorNumber AS error_number,
        @ErrorMessage AS error_message;

    THROW;
END CATCH;
END;
GO

/* Test the procedure */
EXEC etl.usp_load_stg;
GO
