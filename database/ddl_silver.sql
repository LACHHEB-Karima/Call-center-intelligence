/*
================================================================
CALL CENTER INTELLIGENCE
STAGING / SILVER LAYER
TABLE DDL
================================================================

Pipeline:
dbo -> STG (schema definition)

Populated by:
EXEC etl.usp_load_stg;

Main analytical entities:
    employee, requestor, interaction, reviews,
    agent_session, agent_state_event

Design principle:
- STG is fully reloadable (TRUNCATE + INSERT) and holds
  cleaned, standardized data — no FOREIGN KEY constraints
  between STG tables, since the load procedure TRUNCATEs
  them on every run and cross-table FKs would block that.
- Referential integrity between STG tables is enforced in
  code (JOINs) inside etl.usp_load_stg, not by constraint.
================================================================
*/

USE CallCenter;
GO

IF NOT EXISTS
(
    SELECT 1
    FROM sys.schemas
    WHERE name = 'stg'
)
BEGIN
    EXEC('CREATE SCHEMA stg');
END;
GO

/*
================================================================
 DROP (idempotent re-deploy)
 No FKs exist between these tables, so order is not required
 for correctness, but child-like/transactional tables are
 dropped first for readability, mirroring the TRUNCATE order
 used in etl.usp_load_stg.
================================================================
*/
IF OBJECT_ID('stg.reviews', 'U')            IS NOT NULL DROP TABLE stg.reviews;
IF OBJECT_ID('stg.interaction', 'U')        IS NOT NULL DROP TABLE stg.interaction;
IF OBJECT_ID('stg.agent_state_event', 'U')  IS NOT NULL DROP TABLE stg.agent_state_event;
IF OBJECT_ID('stg.agent_session', 'U')      IS NOT NULL DROP TABLE stg.agent_session;
IF OBJECT_ID('stg.employee_skill', 'U')     IS NOT NULL DROP TABLE stg.employee_skill;
IF OBJECT_ID('stg.requestor', 'U')          IS NOT NULL DROP TABLE stg.requestor;
IF OBJECT_ID('stg.employee', 'U')           IS NOT NULL DROP TABLE stg.employee;
IF OBJECT_ID('stg.aux_state', 'U')          IS NOT NULL DROP TABLE stg.aux_state;
IF OBJECT_ID('stg.issue', 'U')              IS NOT NULL DROP TABLE stg.issue;
IF OBJECT_ID('stg.campaign', 'U')           IS NOT NULL DROP TABLE stg.campaign;
IF OBJECT_ID('stg.channel', 'U')            IS NOT NULL DROP TABLE stg.channel;
GO

/*
================================================================
 1. CHANNEL
================================================================
*/
CREATE TABLE stg.channel
(
    channel_id       INT             NOT NULL,
    channel_name     VARCHAR(50)     NOT NULL,

    load_datetime    DATETIME2(0)    NOT NULL DEFAULT SYSDATETIME(),

    CONSTRAINT PK_stg_channel PRIMARY KEY (channel_id)
);
GO

/*
================================================================
 2. CAMPAIGN
================================================================
*/
CREATE TABLE stg.campaign
(
    campaign_id      INT             NOT NULL,
    campaign_name    VARCHAR(100)    NOT NULL,
    description      VARCHAR(255)    NULL,

    load_datetime    DATETIME2(0)    NOT NULL DEFAULT SYSDATETIME(),

    CONSTRAINT PK_stg_campaign PRIMARY KEY (campaign_id)
);
GO

/*
================================================================
 3. ISSUE
================================================================
*/
CREATE TABLE stg.issue
(
    issue_id         INT             NOT NULL,
    issue_name       VARCHAR(100)    NOT NULL,
    description      VARCHAR(255)    NULL,

    load_datetime    DATETIME2(0)    NOT NULL DEFAULT SYSDATETIME(),

    CONSTRAINT PK_stg_issue PRIMARY KEY (issue_id)
);
GO

/*
================================================================
 4. AUX_STATE
================================================================
*/
CREATE TABLE stg.aux_state
(
    aux_state_id      INT             NOT NULL,
    state_name        VARCHAR(100)    NOT NULL,
    state_category    VARCHAR(50)     NOT NULL,

    load_datetime     DATETIME2(0)    NOT NULL DEFAULT SYSDATETIME(),

    CONSTRAINT PK_stg_aux_state PRIMARY KEY (aux_state_id)
);
GO

/*
================================================================
 5. EMPLOYEE
================================================================
*/
CREATE TABLE stg.employee
(
    employee_id      CHAR(6)         NOT NULL,
    first_name       VARCHAR(100)    NOT NULL,
    last_name        VARCHAR(100)    NOT NULL,
    full_name        VARCHAR(201)    NULL,

    birthdate        DATE            NOT NULL,
    gender           CHAR(1)         NOT NULL,

    role_id          INT             NOT NULL,
    role_name        VARCHAR(50)     NOT NULL,

    location_id      INT             NOT NULL,
    location_name    VARCHAR(100)    NOT NULL,

    is_agent         BIT             NOT NULL,
    agent_channel    VARCHAR(20)     NULL,

    load_datetime    DATETIME2(0)    NOT NULL DEFAULT SYSDATETIME(),

    CONSTRAINT PK_stg_employee PRIMARY KEY (employee_id)
);
GO

/*
================================================================
 6. EMPLOYEE_SKILL
================================================================
*/
CREATE TABLE stg.employee_skill
(
    employee_id      CHAR(6)         NOT NULL,
    skill_id         INT             NOT NULL,
    skill_name       VARCHAR(100)    NOT NULL,

    load_datetime    DATETIME2(0)    NOT NULL DEFAULT SYSDATETIME(),

    CONSTRAINT PK_stg_employee_skill PRIMARY KEY (employee_id, skill_id)
);
GO

/*
================================================================
 7. REQUESTOR
================================================================
*/
CREATE TABLE stg.requestor
(
    requestor_id     BIGINT          NOT NULL,
    phone_number     VARCHAR(30)     NULL,
    email            VARCHAR(255)    NULL,

    location_id      INT             NOT NULL,
    location_name    VARCHAR(100)    NOT NULL,

    load_datetime    DATETIME2(0)    NOT NULL DEFAULT SYSDATETIME(),

    CONSTRAINT PK_stg_requestor PRIMARY KEY (requestor_id)
);
GO

/*
================================================================
 8. AGENT_SESSION
================================================================
*/
CREATE TABLE stg.agent_session
(
    session_id                  BIGINT          NOT NULL,

    employee_id                 CHAR(6)         NOT NULL,

    login_datetime              DATETIME2(0)    NOT NULL,
    logout_datetime             DATETIME2(0)    NULL,

    session_date                DATE            NOT NULL,

    login_time                  TIME(0)         NOT NULL,
    logout_time                 TIME(0)         NULL,

    worked_seconds               INT            NULL,
    worked_hours                 DECIMAL(10,2)  NULL,

    late_minutes                 INT            NOT NULL,
    early_departure_minutes      INT            NOT NULL,

    is_present                   BIT            NOT NULL,

    load_datetime                DATETIME2(0)   NOT NULL DEFAULT SYSDATETIME(),

    CONSTRAINT PK_stg_agent_session PRIMARY KEY (session_id)
);
GO

/*
================================================================
 9. AGENT_STATE_EVENT
================================================================
*/
CREATE TABLE stg.agent_state_event
(
    state_event_id      BIGINT          NOT NULL,

    session_id           BIGINT         NOT NULL,
    employee_id          CHAR(6)        NOT NULL,

    aux_state_id         INT            NOT NULL,
    state_name           VARCHAR(100)   NOT NULL,
    state_category       VARCHAR(50)    NOT NULL,

    start_datetime       DATETIME2(0)   NOT NULL,
    end_datetime         DATETIME2(0)   NULL,

    event_date           DATE           NOT NULL,

    duration_seconds     INT            NULL,
    duration_minutes     DECIMAL(10,2)  NULL,

    load_datetime        DATETIME2(0)   NOT NULL DEFAULT SYSDATETIME(),

    CONSTRAINT PK_stg_agent_state_event PRIMARY KEY (state_event_id)
);
GO

/*
================================================================
 10. INTERACTION
================================================================
*/
CREATE TABLE stg.interaction
(
    interaction_id             BIGINT          NOT NULL,

    requestor_id               BIGINT          NOT NULL,
    employee_id                CHAR(6)         NULL,

    campaign_id                INT             NOT NULL,
    channel_id                 INT             NOT NULL,
    issue_id                   INT             NULL,      -- nullable: abandoned / in-progress interactions may have no issue tagged

    start_datetime             DATETIME2(0)    NOT NULL,
    end_datetime               DATETIME2(0)    NULL,

    interaction_date           DATE            NOT NULL,
    interaction_hour           TINYINT         NOT NULL,
    day_of_week                VARCHAR(15)     NOT NULL,
    month_number                TINYINT        NOT NULL,
    year_number                 SMALLINT       NOT NULL,

    wait_time_seconds           INT            NULL,
    answer_speed_seconds        INT            NULL,
    handling_duration_seconds   INT            NULL,

    email_subject               VARCHAR(500)   NULL,
    external_reference           VARCHAR(100)  NULL,

    answered                     BIT           NOT NULL,
    abandoned                    BIT           NOT NULL,
    end_interaction               BIT          NOT NULL,

    interaction_status            VARCHAR(30)  NOT NULL,

    skill_valid                    BIT         NULL,
    temporal_valid                 BIT         NULL,
    business_rule_valid            BIT         NULL,

    load_datetime                  DATETIME2(0) NOT NULL DEFAULT SYSDATETIME(),

    CONSTRAINT PK_stg_interaction PRIMARY KEY (interaction_id)
);
GO

/*
================================================================
 11. REVIEWS

     NOTE: employee_id and channel_id are nullable here (unlike
     the original draft, which had them NOT NULL). The load
     procedure populates both via a LEFT JOIN to dbo.interaction
     specifically to keep reviews with no matching interaction —
     so both columns must accept NULL or the load throws the
     same "Cannot insert NULL" error already hit on issue_id.
     interaction_id itself stays NOT NULL: the source value is
     never NULL, it may simply not resolve to a dbo.interaction
     row.
================================================================
*/
CREATE TABLE stg.reviews
(
    review_id                     BIGINT          NOT NULL,
    interaction_id                BIGINT          NOT NULL,

    employee_id                   CHAR(6)         NULL,
    channel_id                    INT             NULL,

    review_channel_id             INT             NOT NULL,
    review_channel_name           VARCHAR(50)     NOT NULL,

    review_date                   DATE            NULL,

    csat                           DECIMAL(5,2)   NULL,
    hero                           BIT            NULL,
    ease_of_use                    DECIMAL(5,2)   NULL,
    satisfaction_with_response     DECIMAL(5,2)   NULL,
    resolution                     DECIMAL(5,2)   NULL,

    comment                        NVARCHAR(MAX)  NULL,

    is_positive_csat                BIT           NULL,
    is_resolved                     BIT           NULL,

    load_datetime                   DATETIME2(0)  NOT NULL DEFAULT SYSDATETIME(),

    CONSTRAINT PK_stg_review PRIMARY KEY (review_id)
);
GO