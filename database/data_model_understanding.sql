/*-------------------------------------------
       UNDERSTANDING THE DATA MODEL
-------------------------------------------*/


-- Agent sessions: login and logout periods for employees
SELECT TOP 3 *
FROM agent_session;


-- Agent state events: periods spent in different AUX states
SELECT TOP 3 *
FROM agent_state_event;


-- AUX states available to employees, categorized by business activity
SELECT *
FROM aux_state;


-- Customer-service campaigns / markets
SELECT *
FROM campaign;


-- Interaction channels: Phone, Email, Trace
SELECT *
FROM channel;


-- Employee-to-skill mapping
SELECT TOP 3 *
FROM employee_skill;


-- Employee master data including role and location
SELECT TOP 3 *
FROM employee;


-- Central operational table containing customer interactions, our main fact
SELECT TOP 3 *
FROM interaction;


-- Customer-service issues
SELECT TOP 3 *
FROM issue;


-- Employee work locations
SELECT *
FROM location;


-- Requestor/customer contact information
SELECT TOP 3 *
FROM requestor;


-- Sources through which customers submit reviews
SELECT *
FROM review_channel;


-- Customer reviews associated with interactions
SELECT TOP 3 *
FROM review;


-- Organizational roles
SELECT *
FROM role;


-- States/AUX activities authorized for each role
SELECT *
FROM role_state;


-- Skills/queues assigned to employees
SELECT *
FROM skill;


