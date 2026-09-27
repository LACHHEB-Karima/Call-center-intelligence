/*
================================================================
CALL CENTER INTELLIGENCE
GOLD LAYER (STAR SCHEMA)
DIMENSION & FACT TABLE DDL
================================================================

Pipeline:
STG -> GOLD

Model style : Kimball star schema
Grain       :
  fact_interaction        -> 1 row per interaction
  fact_review             -> 1 row per review
  fact_agent_session      -> 1 row per agent login/logout session
  fact_agent_state_event  -> 1 row per aux-state event within a session

Conventions:
  - Surrogate keys      : <table>_key, INT IDENTITY(1,1)
  - Natural/source keys : <table>_id (kept for traceability + reload idempotency)
  - Dimensions          : SCD Type 1 (overwrite). Flag left in table comments
                          if you want to upgrade a given dim to SCD Type 2 later.
  - Unknown members     : each dimension seeds a -1 "Unknown/Unassigned" row so
                          fact loads can ISNULL(..., -1) instead of leaving a
                          NULL FK, if you prefer that over a nullable FK.
                          Nullable FK columns are still allowed on the facts
                          where STG already proved NULL is a valid business
                          state (e.g. issue_id on abandoned interactions).
================================================================
*/

USE CallCenter;
GO

IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = 'gold')
BEGIN
    EXEC('CREATE SCHEMA gold');
END;
GO

/*
================================================================
 DROP (idempotent re-deploy) — facts first, then dims/bridge
================================================================
*/
IF OBJECT_ID('gold.fact_agent_state_event', 'U') IS NOT NULL DROP TABLE gold.fact_agent_state_event;
IF OBJECT_ID('gold.fact_agent_session', 'U')     IS NOT NULL DROP TABLE gold.fact_agent_session;
IF OBJECT_ID('gold.fact_review', 'U')            IS NOT NULL DROP TABLE gold.fact_review;
IF OBJECT_ID('gold.fact_interaction', 'U')        IS NOT NULL DROP TABLE gold.fact_interaction;
IF OBJECT_ID('gold.bridge_employee_skill', 'U')   IS NOT NULL DROP TABLE gold.bridge_employee_skill;
IF OBJECT_ID('gold.dim_skill', 'U')               IS NOT NULL DROP TABLE gold.dim_skill;
IF OBJECT_ID('gold.dim_review_channel', 'U')      IS NOT NULL DROP TABLE gold.dim_review_channel;
IF OBJECT_ID('gold.dim_aux_state', 'U')           IS NOT NULL DROP TABLE gold.dim_aux_state;
IF OBJECT_ID('gold.dim_issue', 'U')               IS NOT NULL DROP TABLE gold.dim_issue;
IF OBJECT_ID('gold.dim_campaign', 'U')            IS NOT NULL DROP TABLE gold.dim_campaign;
IF OBJECT_ID('gold.dim_channel', 'U')             IS NOT NULL DROP TABLE gold.dim_channel;
IF OBJECT_ID('gold.dim_requestor', 'U')           IS NOT NULL DROP TABLE gold.dim_requestor;
IF OBJECT_ID('gold.dim_employee', 'U')            IS NOT NULL DROP TABLE gold.dim_employee;
IF OBJECT_ID('gold.dim_location', 'U')            IS NOT NULL DROP TABLE gold.dim_location;
IF OBJECT_ID('gold.dim_date', 'U')                IS NOT NULL DROP TABLE gold.dim_date;
GO

/*
================================================================
 1. DIM_DATE
    Conformed date dimension shared by every fact.
    date_key = YYYYMMDD (INT), not an identity — deterministic
    so multiple ETL runs can join to it deterministically.
================================================================
*/
CREATE TABLE gold.dim_date
(
    date_key            INT          NOT NULL PRIMARY KEY,   -- 20260927
    full_date            DATE         NOT NULL,
    day_of_month         TINYINT      NOT NULL,
    day_name             VARCHAR(10)  NOT NULL,
    day_of_week_number   TINYINT      NOT NULL,               -- 1=Sunday ... 7=Saturday (SQL Server default)
    week_of_year         TINYINT      NOT NULL,
    month_number         TINYINT      NOT NULL,
    month_name           VARCHAR(10)  NOT NULL,
    quarter_number       TINYINT      NOT NULL,
    year_number          SMALLINT     NOT NULL,
    is_weekend           BIT          NOT NULL,
    load_datetime        DATETIME2(0) NOT NULL DEFAULT SYSDATETIME(),

    CONSTRAINT uq_dim_date_full_date UNIQUE (full_date)
);
GO

/*
================================================================
 2. DIM_LOCATION
    Conformed — shared by dim_employee and dim_requestor.
================================================================
*/
CREATE TABLE gold.dim_location
(
    location_key    INT IDENTITY(1,1) NOT NULL PRIMARY KEY,
    location_id     INT          NOT NULL,
    location_name   VARCHAR(200) NULL,
    load_datetime   DATETIME2(0) NOT NULL DEFAULT SYSDATETIME(),
    CONSTRAINT uq_dim_location_id UNIQUE (location_id)
);
GO

/*
================================================================
 3. DIM_EMPLOYEE   (SCD Type 1)
================================================================
*/
CREATE TABLE gold.dim_employee
(
    employee_key    INT IDENTITY(1,1) NOT NULL PRIMARY KEY,
    employee_id     CHAR(6)      NOT NULL,
    first_name      VARCHAR(100) NULL,
    last_name       VARCHAR(100) NULL,
    full_name       VARCHAR(200) NULL,
    birthdate       DATE         NULL,
    gender          VARCHAR(20)  NULL,
    role_id         INT          NULL,
    role_name       VARCHAR(100) NULL,
    location_key    INT          NOT NULL,
    is_agent        BIT          NOT NULL,
    agent_channel   VARCHAR(20)  NULL,
    load_datetime   DATETIME2(0) NOT NULL DEFAULT SYSDATETIME(),
    CONSTRAINT uq_dim_employee_id UNIQUE (employee_id),
    CONSTRAINT fk_dim_employee_location
        FOREIGN KEY (location_key) REFERENCES gold.dim_location (location_key)
);
GO

CREATE INDEX ix_dim_employee_location_key ON gold.dim_employee (location_key);
GO

/*
================================================================
 4. DIM_REQUESTOR   (SCD Type 1)
================================================================
*/
CREATE TABLE gold.dim_requestor
(
    requestor_key   INT IDENTITY(1,1) NOT NULL PRIMARY KEY,
    requestor_id    BIGINT       NOT NULL,
    phone_number    VARCHAR(30)  NULL,
    email           VARCHAR(200) NULL,
    location_key    INT          NOT NULL,
    load_datetime   DATETIME2(0) NOT NULL DEFAULT SYSDATETIME(),
    CONSTRAINT uq_dim_requestor_id UNIQUE (requestor_id),
    CONSTRAINT fk_dim_requestor_location
        FOREIGN KEY (location_key) REFERENCES gold.dim_location (location_key)
);
GO

CREATE INDEX ix_dim_requestor_location_key ON gold.dim_requestor (location_key);
GO

/*
================================================================
 5. DIM_CHANNEL
================================================================
*/
CREATE TABLE gold.dim_channel
(
    channel_key     INT IDENTITY(1,1) NOT NULL PRIMARY KEY,
    channel_id      INT          NOT NULL,
    channel_name    VARCHAR(50)  NULL,
    load_datetime   DATETIME2(0) NOT NULL DEFAULT SYSDATETIME(),
    CONSTRAINT uq_dim_channel_id UNIQUE (channel_id)
);
GO

/*
================================================================
 6. DIM_CAMPAIGN
================================================================
*/
CREATE TABLE gold.dim_campaign
(
    campaign_key    INT IDENTITY(1,1) NOT NULL PRIMARY KEY,
    campaign_id     INT          NOT NULL,
    campaign_name   VARCHAR(150) NULL,
    description     VARCHAR(500) NULL,
    load_datetime   DATETIME2(0) NOT NULL DEFAULT SYSDATETIME(),
    CONSTRAINT uq_dim_campaign_id UNIQUE (campaign_id)
);
GO

/*
================================================================
 7. DIM_ISSUE
================================================================
*/
CREATE TABLE gold.dim_issue
(
    issue_key       INT IDENTITY(1,1) NOT NULL PRIMARY KEY,
    issue_id        INT          NOT NULL,
    issue_name      VARCHAR(150) NULL,
    description     VARCHAR(500) NULL,
    load_datetime   DATETIME2(0) NOT NULL DEFAULT SYSDATETIME(),
    CONSTRAINT uq_dim_issue_id UNIQUE (issue_id)
);
GO

/*
================================================================
 8. DIM_AUX_STATE
================================================================
*/
CREATE TABLE gold.dim_aux_state
(
    aux_state_key   INT IDENTITY(1,1) NOT NULL PRIMARY KEY,
    aux_state_id    INT          NOT NULL,
    state_name      VARCHAR(100) NULL,
    state_category  VARCHAR(100) NULL,
    load_datetime   DATETIME2(0) NOT NULL DEFAULT SYSDATETIME(),
    CONSTRAINT uq_dim_aux_state_id UNIQUE (aux_state_id)
);
GO

/*
================================================================
 9. DIM_SKILL
================================================================
*/
CREATE TABLE gold.dim_skill
(
    skill_key       INT IDENTITY(1,1) NOT NULL PRIMARY KEY,
    skill_id        INT          NOT NULL,
    skill_name      VARCHAR(100) NULL,
    load_datetime   DATETIME2(0) NOT NULL DEFAULT SYSDATETIME(),
    CONSTRAINT uq_dim_skill_id UNIQUE (skill_id)
);
GO

/*
================================================================
 10. DIM_REVIEW_CHANNEL
================================================================
*/
CREATE TABLE gold.dim_review_channel
(
    review_channel_key    INT IDENTITY(1,1) NOT NULL PRIMARY KEY,
    review_channel_id     INT          NOT NULL,
    review_channel_name   VARCHAR(100) NULL,
    load_datetime         DATETIME2(0) NOT NULL DEFAULT SYSDATETIME(),
    CONSTRAINT uq_dim_review_channel_id UNIQUE (review_channel_id)
);
GO

/*
================================================================
 11. BRIDGE_EMPLOYEE_SKILL
     Many-to-many between employee and skill.
================================================================
*/
CREATE TABLE gold.bridge_employee_skill
(
    employee_key    INT          NOT NULL,
    skill_key       INT          NOT NULL,
    load_datetime   DATETIME2(0) NOT NULL DEFAULT SYSDATETIME(),
    CONSTRAINT pk_bridge_employee_skill PRIMARY KEY (employee_key, skill_key),
    CONSTRAINT fk_bridge_emp_skill_employee
        FOREIGN KEY (employee_key) REFERENCES gold.dim_employee (employee_key),
    CONSTRAINT fk_bridge_emp_skill_skill
        FOREIGN KEY (skill_key) REFERENCES gold.dim_skill (skill_key)
);
GO

/*
================================================================
 12. FACT_INTERACTION
     Grain: one row per interaction.
     employee_key / issue_key are NULLABLE — proven valid in STG
     (abandoned / in-progress interactions may have neither).
================================================================
*/
CREATE TABLE gold.fact_interaction
(
    fact_interaction_key    INT IDENTITY(1,1) NOT NULL PRIMARY KEY,
    interaction_id          BIGINT       NOT NULL,             -- degenerate natural key
    date_key                INT          NOT NULL,
    requestor_key           INT          NOT NULL,
    employee_key            INT          NULL,
    campaign_key            INT          NOT NULL,
    channel_key             INT          NOT NULL,
    issue_key               INT          NULL,

    start_datetime          DATETIME2(0) NOT NULL,
    end_datetime            DATETIME2(0) NULL,
    interaction_hour        TINYINT      NOT NULL,
    day_of_week             VARCHAR(10)  NOT NULL,

    wait_time_seconds           INT NULL,
    answer_speed_seconds        INT NULL,
    handling_duration_seconds   INT NULL,

    email_subject           VARCHAR(300) NULL,
    external_reference       VARCHAR(100) NULL,

    answered                BIT NOT NULL,
    abandoned               BIT NOT NULL,
    end_interaction         BIT NOT NULL,
    interaction_status      VARCHAR(20) NOT NULL,
    temporal_valid          BIT NOT NULL,
    business_rule_valid     BIT NOT NULL,

    load_datetime           DATETIME2(0) NOT NULL DEFAULT SYSDATETIME(),

    CONSTRAINT uq_fact_interaction_id UNIQUE (interaction_id),
    CONSTRAINT fk_fact_interaction_date
        FOREIGN KEY (date_key) REFERENCES gold.dim_date (date_key),
    CONSTRAINT fk_fact_interaction_requestor
        FOREIGN KEY (requestor_key) REFERENCES gold.dim_requestor (requestor_key),
    CONSTRAINT fk_fact_interaction_employee
        FOREIGN KEY (employee_key) REFERENCES gold.dim_employee (employee_key),
    CONSTRAINT fk_fact_interaction_campaign
        FOREIGN KEY (campaign_key) REFERENCES gold.dim_campaign (campaign_key),
    CONSTRAINT fk_fact_interaction_channel
        FOREIGN KEY (channel_key) REFERENCES gold.dim_channel (channel_key),
    CONSTRAINT fk_fact_interaction_issue
        FOREIGN KEY (issue_key) REFERENCES gold.dim_issue (issue_key)
);
GO

CREATE INDEX ix_fact_interaction_date_key       ON gold.fact_interaction (date_key);
CREATE INDEX ix_fact_interaction_requestor_key  ON gold.fact_interaction (requestor_key);
CREATE INDEX ix_fact_interaction_employee_key   ON gold.fact_interaction (employee_key);
CREATE INDEX ix_fact_interaction_campaign_key   ON gold.fact_interaction (campaign_key);
CREATE INDEX ix_fact_interaction_channel_key    ON gold.fact_interaction (channel_key);
CREATE INDEX ix_fact_interaction_issue_key      ON gold.fact_interaction (issue_key);
GO

/*
================================================================
 13. FACT_REVIEW
     Grain: one row per review.
     interaction_id kept as a degenerate reference (nullable —
     STG intentionally allows reviews with no linked interaction).
     employee_key / channel_key nullable for the same reason.
================================================================
*/
CREATE TABLE gold.fact_review
(
    fact_review_key         INT IDENTITY(1,1) NOT NULL PRIMARY KEY,
    review_id               BIGINT       NOT NULL,
    interaction_id           BIGINT      NULL,               -- degenerate ref to fact_interaction.interaction_id
    date_key                INT          NULL,                 -- review_date can be NULL if unlinked
    employee_key            INT          NULL,
    channel_key              INT          NULL,
    review_channel_key       INT          NOT NULL,

    csat                     TINYINT      NULL,
    hero                     BIT          NULL,
    ease_of_use              TINYINT      NULL,
    satisfaction_with_response TINYINT    NULL,
    resolution               TINYINT      NULL,
    comment                  VARCHAR(MAX) NULL,
    is_positive_csat          BIT          NOT NULL,
    is_resolved               BIT          NOT NULL,

    load_datetime            DATETIME2(0) NOT NULL DEFAULT SYSDATETIME(),

    CONSTRAINT uq_fact_review_id UNIQUE (review_id),
    CONSTRAINT fk_fact_review_date
        FOREIGN KEY (date_key) REFERENCES gold.dim_date (date_key),
    CONSTRAINT fk_fact_review_employee
        FOREIGN KEY (employee_key) REFERENCES gold.dim_employee (employee_key),
    CONSTRAINT fk_fact_review_channel
        FOREIGN KEY (channel_key) REFERENCES gold.dim_channel (channel_key),
    CONSTRAINT fk_fact_review_review_channel
        FOREIGN KEY (review_channel_key) REFERENCES gold.dim_review_channel (review_channel_key),
    CONSTRAINT fk_fact_review_interaction
        FOREIGN KEY (interaction_id) REFERENCES gold.fact_interaction (interaction_id)
);
GO

CREATE INDEX ix_fact_review_date_key           ON gold.fact_review (date_key);
CREATE INDEX ix_fact_review_employee_key       ON gold.fact_review (employee_key);
CREATE INDEX ix_fact_review_channel_key        ON gold.fact_review (channel_key);
CREATE INDEX ix_fact_review_review_channel_key ON gold.fact_review (review_channel_key);
CREATE INDEX ix_fact_review_interaction_id     ON gold.fact_review (interaction_id);
GO

/*
================================================================
 14. FACT_AGENT_SESSION
     Grain: one row per agent login/logout session.
================================================================
*/
CREATE TABLE gold.fact_agent_session
(
    fact_session_key        INT IDENTITY(1,1) NOT NULL PRIMARY KEY,
    session_id               BIGINT       NOT NULL,
    employee_key             INT          NOT NULL,
    login_date_key           INT          NOT NULL,

    login_datetime           DATETIME2(0) NOT NULL,
    logout_datetime          DATETIME2(0) NULL,
    login_time               TIME(0)      NOT NULL,
    logout_time              TIME(0)      NULL,

    worked_seconds           INT          NULL,
    worked_hours             DECIMAL(10,2) NULL,
    late_minutes             INT          NOT NULL,
    early_departure_minutes  INT          NOT NULL,
    is_present               BIT          NOT NULL,

    load_datetime            DATETIME2(0) NOT NULL DEFAULT SYSDATETIME(),

    CONSTRAINT uq_fact_session_id UNIQUE (session_id),
    CONSTRAINT fk_fact_session_employee
        FOREIGN KEY (employee_key) REFERENCES gold.dim_employee (employee_key),
    CONSTRAINT fk_fact_session_date
        FOREIGN KEY (login_date_key) REFERENCES gold.dim_date (date_key)
);
GO

CREATE INDEX ix_fact_session_employee_key ON gold.fact_agent_session (employee_key);
CREATE INDEX ix_fact_session_date_key     ON gold.fact_agent_session (login_date_key);
GO

/*
================================================================
 15. FACT_AGENT_STATE_EVENT
     Grain: one row per aux-state event within a session.
     session_id kept as a degenerate reference back to
     fact_agent_session.session_id.
================================================================
*/
CREATE TABLE gold.fact_agent_state_event
(
    fact_state_event_key    INT IDENTITY(1,1) NOT NULL PRIMARY KEY,
    state_event_id           BIGINT       NOT NULL,
    session_id                BIGINT      NOT NULL,           -- degenerate ref to fact_agent_session.session_id
    employee_key              INT          NOT NULL,
    aux_state_key             INT          NOT NULL,
    event_date_key             INT          NOT NULL,

    start_datetime             DATETIME2(0) NOT NULL,
    end_datetime               DATETIME2(0) NULL,
    duration_seconds           INT          NULL,
    duration_minutes           DECIMAL(10,2) NULL,

    load_datetime              DATETIME2(0) NOT NULL DEFAULT SYSDATETIME(),

    CONSTRAINT uq_fact_state_event_id UNIQUE (state_event_id),
    CONSTRAINT fk_fact_state_event_employee
        FOREIGN KEY (employee_key) REFERENCES gold.dim_employee (employee_key),
    CONSTRAINT fk_fact_state_event_aux_state
        FOREIGN KEY (aux_state_key) REFERENCES gold.dim_aux_state (aux_state_key),
    CONSTRAINT fk_fact_state_event_date
        FOREIGN KEY (event_date_key) REFERENCES gold.dim_date (date_key),
    CONSTRAINT fk_fact_state_event_session
        FOREIGN KEY (session_id) REFERENCES gold.fact_agent_session (session_id)
);
GO

CREATE INDEX ix_fact_state_event_employee_key  ON gold.fact_agent_state_event (employee_key);
CREATE INDEX ix_fact_state_event_aux_state_key  ON gold.fact_agent_state_event (aux_state_key);
CREATE INDEX ix_fact_state_event_date_key       ON gold.fact_agent_state_event (event_date_key);
CREATE INDEX ix_fact_state_event_session_id     ON gold.fact_agent_state_event (session_id);
GO

/*
================================================================
 16. SEED — UNKNOWN / -1 MEMBERS
     Optional convenience rows so a load can ISNULL(x, -1) into
     any dimension instead of leaving a NULL FK. Not required —
     fact_interaction.employee_key / issue_key etc. already
     accept NULL directly.
================================================================
*/
SET IDENTITY_INSERT gold.dim_location ON;
INSERT INTO gold.dim_location (location_key, location_id, location_name) VALUES (-1, -1, 'Unknown');
SET IDENTITY_INSERT gold.dim_location OFF;
GO

SET IDENTITY_INSERT gold.dim_channel ON;
INSERT INTO gold.dim_channel (channel_key, channel_id, channel_name) VALUES (-1, -1, 'Unknown');
SET IDENTITY_INSERT gold.dim_channel OFF;
GO

SET IDENTITY_INSERT gold.dim_campaign ON;
INSERT INTO gold.dim_campaign (campaign_key, campaign_id, campaign_name, description) VALUES (-1, -1, 'Unknown', NULL);
SET IDENTITY_INSERT gold.dim_campaign OFF;
GO

SET IDENTITY_INSERT gold.dim_issue ON;
INSERT INTO gold.dim_issue (issue_key, issue_id, issue_name, description) VALUES (-1, -1, 'Unassigned', NULL);
SET IDENTITY_INSERT gold.dim_issue OFF;
GO

SET IDENTITY_INSERT gold.dim_aux_state ON;
INSERT INTO gold.dim_aux_state (aux_state_key, aux_state_id, state_name, state_category) VALUES (-1, -1, 'Unknown', 'Unknown');
SET IDENTITY_INSERT gold.dim_aux_state OFF;
GO

SET IDENTITY_INSERT gold.dim_skill ON;
INSERT INTO gold.dim_skill (skill_key, skill_id, skill_name) VALUES (-1, -1, 'Unknown');
SET IDENTITY_INSERT gold.dim_skill OFF;
GO

SET IDENTITY_INSERT gold.dim_review_channel ON;
INSERT INTO gold.dim_review_channel (review_channel_key, review_channel_id, review_channel_name) VALUES (-1, -1, 'Unknown');
SET IDENTITY_INSERT gold.dim_review_channel OFF;
GO

/*
================================================================
 17. DIM_DATE POPULATION
     Generates one row per calendar day between @StartDate and
     @EndDate using a tally-table expansion (no loop).
     Adjust the range to comfortably cover your source data.
================================================================
*/
DECLARE @StartDate DATE = '2018-01-01';
DECLARE @EndDate   DATE = '2035-12-31';

;WITH tally AS
(
    SELECT TOP (DATEDIFF(DAY, @StartDate, @EndDate) + 1)
        ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) - 1 AS rn
    FROM sys.all_objects a
    CROSS JOIN sys.all_objects b
),
dates AS
(
    SELECT DATEADD(DAY, rn, @StartDate) AS full_date
    FROM tally
)
INSERT INTO gold.dim_date
(
    date_key,
    full_date,
    day_of_month,
    day_name,
    day_of_week_number,
    week_of_year,
    month_number,
    month_name,
    quarter_number,
    year_number,
    is_weekend
)
SELECT
    CAST(FORMAT(full_date, 'yyyyMMdd') AS INT),
    full_date,
    DAY(full_date),
    DATENAME(WEEKDAY, full_date),
    DATEPART(WEEKDAY, full_date),
    DATEPART(WEEK, full_date),
    MONTH(full_date),
    DATENAME(MONTH, full_date),
    DATEPART(QUARTER, full_date),
    YEAR(full_date),
    CASE WHEN DATEPART(WEEKDAY, full_date) IN (1, 7) THEN 1 ELSE 0 END
FROM dates;
GO

/*
================================================================
 DONE.
 Next step: an etl.usp_load_gold procedure to populate the
 dimensions/facts from STG (dedupe on natural key -> MERGE or
 truncate+insert, then load facts by looking up surrogate keys
 via the dims' natural-key unique constraints).
================================================================
*/