/*
================================================================
CALL CENTER INTELLIGENCE
GOLD LAYER
MASTER GOLD LOAD PROCEDURE
================================================================

Pipeline:
STG -> GOLD

Execution:
EXEC etl.usp_load_gold;

Notes:
- Full refresh of GOLD (dims + facts), dim_date is NOT reloaded
  (static calendar dimension, seeded once from the DDL script).
- Transactional load.
- Delete order = children first (facts/bridge), then dims,
  to respect FOREIGN KEY constraints (TRUNCATE is not usable
  here since dims are referenced by FKs).
- Insert order = parents first (dims), then bridge, then facts,
  so surrogate-key lookups always have something to join to.
- Run etl.usp_load_stg BEFORE this procedure.
================================================================
*/

USE CallCenter;
GO

IF OBJECT_ID('etl.load_log_gold', 'U') IS NULL
BEGIN
CREATE TABLE etl.load_log_gold
(
    load_id                      BIGINT IDENTITY(1,1) PRIMARY KEY,
    pipeline_name                VARCHAR(100) NOT NULL,
    start_time                   DATETIME2(0) NOT NULL,
    end_time                     DATETIME2(0) NULL,
    status                       VARCHAR(20) NOT NULL,
    rows_dim_location            INT NULL,
    rows_dim_employee            INT NULL,
    rows_dim_requestor           INT NULL,
    rows_dim_channel             INT NULL,
    rows_dim_campaign            INT NULL,
    rows_dim_issue               INT NULL,
    rows_dim_aux_state           INT NULL,
    rows_dim_skill               INT NULL,
    rows_dim_review_channel      INT NULL,
    rows_bridge_employee_skill   INT NULL,
    rows_fact_interaction        INT NULL,
    rows_fact_review             INT NULL,
    rows_fact_agent_session      INT NULL,
    rows_fact_agent_state_event  INT NULL,
    error_number                 INT NULL,
    error_message                NVARCHAR(4000) NULL,
    created_at                   DATETIME2(0) NOT NULL DEFAULT SYSDATETIME()
);
END;
GO

CREATE OR ALTER PROCEDURE etl.usp_load_gold
AS
BEGIN
SET NOCOUNT ON;
SET XACT_ABORT ON;

DECLARE
    @LoadID BIGINT,
    @StartTime DATETIME2(0) = SYSDATETIME(),
    @EndTime DATETIME2(0),
    @RowsDimLocation INT = 0,
    @RowsDimEmployee INT = 0,
    @RowsDimRequestor INT = 0,
    @RowsDimChannel INT = 0,
    @RowsDimCampaign INT = 0,
    @RowsDimIssue INT = 0,
    @RowsDimAuxState INT = 0,
    @RowsDimSkill INT = 0,
    @RowsDimReviewChannel INT = 0,
    @RowsBridgeEmployeeSkill INT = 0,
    @RowsFactInteraction INT = 0,
    @RowsFactReview INT = 0,
    @RowsFactAgentSession INT = 0,
    @RowsFactAgentStateEvent INT = 0,
    @ErrorNumber INT,
    @ErrorMessage NVARCHAR(4000);

INSERT INTO etl.load_log_gold
(
    pipeline_name,
    start_time,
    status
)
VALUES
(
    'GOLD_FULL_LOAD',
    @StartTime,
    'RUNNING'
);

SET @LoadID = CONVERT(BIGINT, SCOPE_IDENTITY());

BEGIN TRY
    BEGIN TRANSACTION;

    PRINT '-----------------------------------------------';
    PRINT 'GOLD LOAD STARTED';
    PRINT 'Load ID: ' + CAST(@LoadID AS VARCHAR(30));
    PRINT '-----------------------------------------------';

    /*======================================================
        1. CLEAR GOLD — CHILDREN FIRST (FK dependency order)
           dim_date is intentionally NOT touched.
    ======================================================*/
    PRINT 'Clearing gold fact/bridge tables...';

    DELETE FROM gold.fact_agent_state_event;
    DELETE FROM gold.fact_agent_session;
    DELETE FROM gold.fact_review;
    DELETE FROM gold.fact_interaction;
    DELETE FROM gold.bridge_employee_skill;

    PRINT 'Clearing gold dimension tables...';

    DELETE FROM gold.dim_skill;
    DELETE FROM gold.dim_review_channel;
    DELETE FROM gold.dim_aux_state;
    DELETE FROM gold.dim_issue;
    DELETE FROM gold.dim_campaign;
    DELETE FROM gold.dim_channel;
    DELETE FROM gold.dim_requestor;
    DELETE FROM gold.dim_employee;
    DELETE FROM gold.dim_location;

    /*======================================================
        2. DIM_LOCATION
           Conformed — union of distinct locations referenced
           by employees and requestors.
    ======================================================*/
    PRINT 'Loading dim_location...';

    INSERT INTO gold.dim_location
    (
        location_id,
        location_name
    )
    SELECT DISTINCT
        location_id,
        location_name
    FROM
    (
        SELECT location_id, location_name FROM stg.employee
        UNION
        SELECT location_id, location_name FROM stg.requestor
    ) loc;

    SET @RowsDimLocation = @@ROWCOUNT;

    SET IDENTITY_INSERT gold.dim_location ON;
    INSERT INTO gold.dim_location (location_key, location_id, location_name)
    VALUES (-1, -1, 'Unknown');
    SET IDENTITY_INSERT gold.dim_location OFF;

    /*======================================================
        3. DIM_EMPLOYEE
    ======================================================*/
    PRINT 'Loading dim_employee...';

    INSERT INTO gold.dim_employee
    (
        employee_id,
        first_name,
        last_name,
        full_name,
        birthdate,
        gender,
        role_id,
        role_name,
        location_key,
        is_agent,
        agent_channel
    )
    SELECT
        e.employee_id,
        e.first_name,
        e.last_name,
        e.full_name,
        e.birthdate,
        e.gender,
        e.role_id,
        e.role_name,
        loc.location_key,
        e.is_agent,
        e.agent_channel
    FROM stg.employee e
    INNER JOIN gold.dim_location loc
        ON e.location_id = loc.location_id;

    SET @RowsDimEmployee = @@ROWCOUNT;

    SET IDENTITY_INSERT gold.dim_employee ON;
    INSERT INTO gold.dim_employee
        (employee_key, employee_id, first_name, last_name, full_name, birthdate,
         gender, role_id, role_name, location_key, is_agent, agent_channel)
    VALUES
        (-1, 'UNK000', 'Unknown', 'Unknown', 'Unknown', NULL, NULL, NULL, 'Unknown', -1, 0, NULL);
    SET IDENTITY_INSERT gold.dim_employee OFF;

    /*======================================================
        4. DIM_REQUESTOR
    ======================================================*/
    PRINT 'Loading dim_requestor...';

    INSERT INTO gold.dim_requestor
    (
        requestor_id,
        phone_number,
        email,
        location_key
    )
    SELECT
        r.requestor_id,
        r.phone_number,
        r.email,
        loc.location_key
    FROM stg.requestor r
    INNER JOIN gold.dim_location loc
        ON r.location_id = loc.location_id;

    SET @RowsDimRequestor = @@ROWCOUNT;

    SET IDENTITY_INSERT gold.dim_requestor ON;
    INSERT INTO gold.dim_requestor (requestor_key, requestor_id, phone_number, email, location_key)
    VALUES (-1, -1, NULL, NULL, -1);
    SET IDENTITY_INSERT gold.dim_requestor OFF;

    /*======================================================
        5. DIM_CHANNEL
    ======================================================*/
    PRINT 'Loading dim_channel...';

    INSERT INTO gold.dim_channel
    (
        channel_id,
        channel_name
    )
    SELECT
        channel_id,
        channel_name
    FROM stg.channel;

    SET @RowsDimChannel = @@ROWCOUNT;

    SET IDENTITY_INSERT gold.dim_channel ON;
    INSERT INTO gold.dim_channel (channel_key, channel_id, channel_name)
    VALUES (-1, -1, 'Unknown');
    SET IDENTITY_INSERT gold.dim_channel OFF;

    /*======================================================
        6. DIM_CAMPAIGN
    ======================================================*/
    PRINT 'Loading dim_campaign...';

    INSERT INTO gold.dim_campaign
    (
        campaign_id,
        campaign_name,
        description
    )
    SELECT
        campaign_id,
        campaign_name,
        description
    FROM stg.campaign;

    SET @RowsDimCampaign = @@ROWCOUNT;

    SET IDENTITY_INSERT gold.dim_campaign ON;
    INSERT INTO gold.dim_campaign (campaign_key, campaign_id, campaign_name, description)
    VALUES (-1, -1, 'Unknown', NULL);
    SET IDENTITY_INSERT gold.dim_campaign OFF;

    /*======================================================
        7. DIM_ISSUE
    ======================================================*/
    PRINT 'Loading dim_issue...';

    INSERT INTO gold.dim_issue
    (
        issue_id,
        issue_name,
        description
    )
    SELECT
        issue_id,
        issue_name,
        description
    FROM stg.issue;

    SET @RowsDimIssue = @@ROWCOUNT;

    SET IDENTITY_INSERT gold.dim_issue ON;
    INSERT INTO gold.dim_issue (issue_key, issue_id, issue_name, description)
    VALUES (-1, -1, 'Unassigned', NULL);
    SET IDENTITY_INSERT gold.dim_issue OFF;

    /*======================================================
        8. DIM_AUX_STATE
    ======================================================*/
    PRINT 'Loading dim_aux_state...';

    INSERT INTO gold.dim_aux_state
    (
        aux_state_id,
        state_name,
        state_category
    )
    SELECT
        aux_state_id,
        state_name,
        state_category
    FROM stg.aux_state;

    SET @RowsDimAuxState = @@ROWCOUNT;

    SET IDENTITY_INSERT gold.dim_aux_state ON;
    INSERT INTO gold.dim_aux_state (aux_state_key, aux_state_id, state_name, state_category)
    VALUES (-1, -1, 'Unknown', 'Unknown');
    SET IDENTITY_INSERT gold.dim_aux_state OFF;

    /*======================================================
        9. DIM_SKILL
           No dedicated STG source table — derived from
           distinct values on stg.employee_skill.
    ======================================================*/
    PRINT 'Loading dim_skill...';

    INSERT INTO gold.dim_skill
    (
        skill_id,
        skill_name
    )
    SELECT DISTINCT
        skill_id,
        skill_name
    FROM stg.employee_skill;

    SET @RowsDimSkill = @@ROWCOUNT;

    SET IDENTITY_INSERT gold.dim_skill ON;
    INSERT INTO gold.dim_skill (skill_key, skill_id, skill_name)
    VALUES (-1, -1, 'Unknown');
    SET IDENTITY_INSERT gold.dim_skill OFF;

    /*======================================================
        10. DIM_REVIEW_CHANNEL
            No dedicated STG source table — derived from
            distinct values on stg.reviews.
    ======================================================*/
    PRINT 'Loading dim_review_channel...';

    INSERT INTO gold.dim_review_channel
    (
        review_channel_id,
        review_channel_name
    )
    SELECT DISTINCT
        review_channel_id,
        review_channel_name
    FROM stg.reviews
    WHERE review_channel_id IS NOT NULL;

    SET @RowsDimReviewChannel = @@ROWCOUNT;

    SET IDENTITY_INSERT gold.dim_review_channel ON;
    INSERT INTO gold.dim_review_channel (review_channel_key, review_channel_id, review_channel_name)
    VALUES (-1, -1, 'Unknown');
    SET IDENTITY_INSERT gold.dim_review_channel OFF;

    /*======================================================
        11. BRIDGE_EMPLOYEE_SKILL
    ======================================================*/
    PRINT 'Loading bridge_employee_skill...';

    INSERT INTO gold.bridge_employee_skill
    (
        employee_key,
        skill_key
    )
    SELECT
        emp.employee_key,
        sk.skill_key
    FROM stg.employee_skill es
    INNER JOIN gold.dim_employee emp
        ON es.employee_id = emp.employee_id
    INNER JOIN gold.dim_skill sk
        ON es.skill_id = sk.skill_id;

    SET @RowsBridgeEmployeeSkill = @@ROWCOUNT;

    /*======================================================
        12. FACT_INTERACTION
            employee_key / issue_key are nullable — LEFT JOIN.
            requestor_key / campaign_key / channel_key are
            required — INNER JOIN (row-count check below will
            catch any unresolved lookups).
    ======================================================*/
    PRINT 'Loading fact_interaction...';

    INSERT INTO gold.fact_interaction
    (
        interaction_id,
        date_key,
        requestor_key,
        employee_key,
        campaign_key,
        channel_key,
        issue_key,
        start_datetime,
        end_datetime,
        interaction_hour,
        day_of_week,
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
        business_rule_valid
    )
    SELECT
        i.interaction_id,
        d.date_key,
        req.requestor_key,
        emp.employee_key,
        camp.campaign_key,
        chan.channel_key,
        iss.issue_key,
        i.start_datetime,
        i.end_datetime,
        i.interaction_hour,
        i.day_of_week,
        i.wait_time_seconds,
        i.answer_speed_seconds,
        i.handling_duration_seconds,
        i.email_subject,
        i.external_reference,
        i.answered,
        i.abandoned,
        i.end_interaction,
        i.interaction_status,
        i.temporal_valid,
        i.business_rule_valid
    FROM stg.interaction i
    INNER JOIN gold.dim_date d
        ON i.interaction_date = d.full_date
    INNER JOIN gold.dim_requestor req
        ON i.requestor_id = req.requestor_id
    LEFT JOIN gold.dim_employee emp
        ON i.employee_id = emp.employee_id
    INNER JOIN gold.dim_campaign camp
        ON i.campaign_id = camp.campaign_id
    INNER JOIN gold.dim_channel chan
        ON i.channel_id = chan.channel_id
    LEFT JOIN gold.dim_issue iss
        ON i.issue_id = iss.issue_id;

    SET @RowsFactInteraction = @@ROWCOUNT;

    /*======================================================
        13. FACT_REVIEW
            interaction_id only carried over if it actually
            resolves to a row in fact_interaction, to protect
            the FK (STG's LEFT JOIN can leave a review with an
            interaction_id that never matched dbo.interaction).
            date_key / employee_key / channel_key nullable for
            the same reason unlinked reviews are allowed.
    ======================================================*/
    PRINT 'Loading fact_review...';

    INSERT INTO gold.fact_review
    (
        review_id,
        interaction_id,
        date_key,
        employee_key,
        channel_key,
        review_channel_key,
        csat,
        hero,
        ease_of_use,
        satisfaction_with_response,
        resolution,
        comment,
        is_positive_csat,
        is_resolved
    )
    SELECT
        r.review_id,
        fi.interaction_id,
        d.date_key,
        emp.employee_key,
        chan.channel_key,
        ISNULL(rc.review_channel_key, -1),
        r.csat,
        r.hero,
        r.ease_of_use,
        r.satisfaction_with_response,
        r.resolution,
        r.comment,
        r.is_positive_csat,
        r.is_resolved
    FROM stg.reviews r
    LEFT JOIN gold.fact_interaction fi
        ON r.interaction_id = fi.interaction_id
    LEFT JOIN gold.dim_date d
        ON r.review_date = d.full_date
    LEFT JOIN gold.dim_employee emp
        ON r.employee_id = emp.employee_id
    LEFT JOIN gold.dim_channel chan
        ON r.channel_id = chan.channel_id
    LEFT JOIN gold.dim_review_channel rc
        ON r.review_channel_id = rc.review_channel_id;

    SET @RowsFactReview = @@ROWCOUNT;

    /*======================================================
        14. FACT_AGENT_SESSION
    ======================================================*/
    PRINT 'Loading fact_agent_session...';

    INSERT INTO gold.fact_agent_session
    (
        session_id,
        employee_key,
        login_date_key,
        login_datetime,
        logout_datetime,
        login_time,
        logout_time,
        worked_seconds,
        worked_hours,
        late_minutes,
        early_departure_minutes,
        is_present
    )
    SELECT
        s.session_id,
        emp.employee_key,
        d.date_key,
        s.login_datetime,
        s.logout_datetime,
        s.login_time,
        s.logout_time,
        s.worked_seconds,
        s.worked_hours,
        s.late_minutes,
        s.early_departure_minutes,
        s.is_present
    FROM stg.agent_session s
    INNER JOIN gold.dim_employee emp
        ON s.employee_id = emp.employee_id
    INNER JOIN gold.dim_date d
        ON s.session_date = d.full_date;

    SET @RowsFactAgentSession = @@ROWCOUNT;

    /*======================================================
        15. FACT_AGENT_STATE_EVENT
    ======================================================*/
    PRINT 'Loading fact_agent_state_event...';

    INSERT INTO gold.fact_agent_state_event
    (
        state_event_id,
        session_id,
        employee_key,
        aux_state_key,
        event_date_key,
        start_datetime,
        end_datetime,
        duration_seconds,
        duration_minutes
    )
    SELECT
        ase.state_event_id,
        ase.session_id,
        emp.employee_key,
        aux.aux_state_key,
        d.date_key,
        ase.start_datetime,
        ase.end_datetime,
        ase.duration_seconds,
        CAST(ase.duration_minutes AS DECIMAL(10,2))
    FROM stg.agent_state_event ase
    INNER JOIN gold.dim_employee emp
        ON ase.employee_id = emp.employee_id
    INNER JOIN gold.dim_aux_state aux
        ON ase.aux_state_id = aux.aux_state_id
    INNER JOIN gold.dim_date d
        ON ase.event_date = d.full_date
    INNER JOIN gold.fact_agent_session fs
        ON ase.session_id = fs.session_id;

    SET @RowsFactAgentStateEvent = @@ROWCOUNT;

    /*======================================================
        16. VALIDATION — dims should match STG source counts
    ======================================================*/
    PRINT '-----------------------------------------------';
    PRINT 'RUNNING GOLD VALIDATIONS';
    PRINT '-----------------------------------------------';

    IF @RowsDimEmployee <> (SELECT COUNT(*) FROM stg.employee)
    BEGIN
        THROW 51001, 'GOLD validation failed: dim_employee row count mismatch vs stg.employee.', 1;
    END;

    IF @RowsDimRequestor <> (SELECT COUNT(*) FROM stg.requestor)
    BEGIN
        THROW 51002, 'GOLD validation failed: dim_requestor row count mismatch vs stg.requestor.', 1;
    END;

    IF @RowsDimChannel <> (SELECT COUNT(*) FROM stg.channel)
    BEGIN
        THROW 51003, 'GOLD validation failed: dim_channel row count mismatch vs stg.channel.', 1;
    END;

    IF @RowsDimCampaign <> (SELECT COUNT(*) FROM stg.campaign)
    BEGIN
        THROW 51004, 'GOLD validation failed: dim_campaign row count mismatch vs stg.campaign.', 1;
    END;

    IF @RowsDimIssue <> (SELECT COUNT(*) FROM stg.issue)
    BEGIN
        THROW 51005, 'GOLD validation failed: dim_issue row count mismatch vs stg.issue.', 1;
    END;

    IF @RowsDimAuxState <> (SELECT COUNT(*) FROM stg.aux_state)
    BEGIN
        THROW 51006, 'GOLD validation failed: dim_aux_state row count mismatch vs stg.aux_state.', 1;
    END;

    /*======================================================
        17. VALIDATION — facts must be 1:1 with STG
            (catches any INNER JOIN lookup silently dropping
            rows due to an unresolved required dimension key)
    ======================================================*/
    IF @RowsFactInteraction <> (SELECT COUNT(*) FROM stg.interaction)
    BEGIN
        THROW 51010, 'GOLD validation failed: fact_interaction row count mismatch vs stg.interaction.', 1;
    END;

    IF @RowsFactReview <> (SELECT COUNT(*) FROM stg.reviews)
    BEGIN
        THROW 51011, 'GOLD validation failed: fact_review row count mismatch vs stg.reviews.', 1;
    END;

    IF @RowsFactAgentSession <> (SELECT COUNT(*) FROM stg.agent_session)
    BEGIN
        THROW 51012, 'GOLD validation failed: fact_agent_session row count mismatch vs stg.agent_session.', 1;
    END;

    IF @RowsFactAgentStateEvent <> (SELECT COUNT(*) FROM stg.agent_state_event)
    BEGIN
        THROW 51013, 'GOLD validation failed: fact_agent_state_event row count mismatch vs stg.agent_state_event.', 1;
    END;

    /*======================================================
        18. VALIDATION — no NULL on NOT NULL surrogate FKs
            (belt-and-braces; the INNER JOINs above should
            already guarantee this via the count checks)
    ======================================================*/
    IF EXISTS (SELECT 1 FROM gold.fact_interaction WHERE requestor_key IS NULL OR campaign_key IS NULL OR channel_key IS NULL)
    BEGIN
        THROW 51020, 'GOLD validation failed: fact_interaction has a NULL required surrogate key.', 1;
    END;

    IF EXISTS (SELECT 1 FROM gold.fact_agent_session WHERE employee_key IS NULL OR login_date_key IS NULL)
    BEGIN
        THROW 51021, 'GOLD validation failed: fact_agent_session has a NULL required surrogate key.', 1;
    END;

    IF EXISTS (SELECT 1 FROM gold.fact_agent_state_event WHERE employee_key IS NULL OR aux_state_key IS NULL OR event_date_key IS NULL)
    BEGIN
        THROW 51022, 'GOLD validation failed: fact_agent_state_event has a NULL required surrogate key.', 1;
    END;

    /*======================================================
        19. COMMIT
    ======================================================*/
    COMMIT TRANSACTION;

    /*======================================================
        20. SUCCESS LOG
    ======================================================*/
    SET @EndTime = SYSDATETIME();

    UPDATE etl.load_log_gold
    SET
        end_time = @EndTime,
        status = 'SUCCESS',
        rows_dim_location = @RowsDimLocation,
        rows_dim_employee = @RowsDimEmployee,
        rows_dim_requestor = @RowsDimRequestor,
        rows_dim_channel = @RowsDimChannel,
        rows_dim_campaign = @RowsDimCampaign,
        rows_dim_issue = @RowsDimIssue,
        rows_dim_aux_state = @RowsDimAuxState,
        rows_dim_skill = @RowsDimSkill,
        rows_dim_review_channel = @RowsDimReviewChannel,
        rows_bridge_employee_skill = @RowsBridgeEmployeeSkill,
        rows_fact_interaction = @RowsFactInteraction,
        rows_fact_review = @RowsFactReview,
        rows_fact_agent_session = @RowsFactAgentSession,
        rows_fact_agent_state_event = @RowsFactAgentStateEvent
    WHERE load_id = @LoadID;

    SELECT
        @LoadID AS load_id,
        'GOLD_FULL_LOAD' AS pipeline_name,
        @StartTime AS start_time,
        @EndTime AS end_time,
        DATEDIFF(SECOND, @StartTime, @EndTime) AS duration_seconds,
        'SUCCESS' AS status,
        @RowsDimLocation AS dim_location_loaded,
        @RowsDimEmployee AS dim_employee_loaded,
        @RowsDimRequestor AS dim_requestor_loaded,
        @RowsDimChannel AS dim_channel_loaded,
        @RowsDimCampaign AS dim_campaign_loaded,
        @RowsDimIssue AS dim_issue_loaded,
        @RowsDimAuxState AS dim_aux_state_loaded,
        @RowsDimSkill AS dim_skill_loaded,
        @RowsDimReviewChannel AS dim_review_channel_loaded,
        @RowsBridgeEmployeeSkill AS bridge_employee_skill_loaded,
        @RowsFactInteraction AS fact_interaction_loaded,
        @RowsFactReview AS fact_review_loaded,
        @RowsFactAgentSession AS fact_agent_session_loaded,
        @RowsFactAgentStateEvent AS fact_agent_state_event_loaded;
END TRY
BEGIN CATCH
    IF XACT_STATE() <> 0
    BEGIN
        ROLLBACK TRANSACTION;
    END;

    SET @ErrorNumber = ERROR_NUMBER();
    SET @ErrorMessage = ERROR_MESSAGE();
    SET @EndTime = SYSDATETIME();

    UPDATE etl.load_log_gold
    SET
        end_time = @EndTime,
        status = 'FAILED',
        rows_dim_location = @RowsDimLocation,
        rows_dim_employee = @RowsDimEmployee,
        rows_dim_requestor = @RowsDimRequestor,
        rows_dim_channel = @RowsDimChannel,
        rows_dim_campaign = @RowsDimCampaign,
        rows_dim_issue = @RowsDimIssue,
        rows_dim_aux_state = @RowsDimAuxState,
        rows_dim_skill = @RowsDimSkill,
        rows_dim_review_channel = @RowsDimReviewChannel,
        rows_bridge_employee_skill = @RowsBridgeEmployeeSkill,
        rows_fact_interaction = @RowsFactInteraction,
        rows_fact_review = @RowsFactReview,
        rows_fact_agent_session = @RowsFactAgentSession,
        rows_fact_agent_state_event = @RowsFactAgentStateEvent,
        error_number = @ErrorNumber,
        error_message = @ErrorMessage
    WHERE load_id = @LoadID;

    SELECT
        @LoadID AS load_id,
        'GOLD_FULL_LOAD' AS pipeline_name,
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
EXEC etl.usp_load_gold;
GO