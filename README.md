# Call Center Intelligence — Power BI Operations Dashboard

> **Power BI analytics solution for monitoring call center operations, workforce performance, and customer satisfaction.**

**Status:** 🚧 Under Development
**Reporting Period:** Q1 2026
**Primary Tools:** Power BI · DAX · SQL Server · Data Warehouse
**Audience:** Operations Managers · Team Managers

---

## 📌 Project Overview

**Call Center Intelligence** is an end-to-end data analytics and business intelligence project designed to transform operational call center data into actionable insights for management.

The Power BI reporting layer provides a centralized view of operational performance, agent productivity, customer satisfaction, and workforce activity.

The objective is not simply to display KPIs, but to help managers quickly answer questions such as:

* How is the operation performing overall?
* Where are operational issues occurring?
* Which teams or agents are performing differently from the overall operation?
* Where are the main areas of development?
* Which agents may require coaching or additional support?
* What is happening with customer satisfaction?
* Which campaigns, channels, or issue types are associated with performance variations?

The dashboard is designed to give managers **immediate access to the information needed for operational monitoring and performance management.**

---

# 🎯 Business Objectives

The reporting solution focuses on four main objectives:

### 1. Monitor overall operational performance

Provide management with an immediate overview of:

* Interaction volume
* Answered rate
* Handling time
* Customer satisfaction
* Review volume
* Active workforce

### 2. Identify operational areas of development

Analyze performance by:

* Country
* Channel
* Issue
* Date
* Hour
* Agent

This allows managers to identify workload patterns and areas where service performance may require attention.

### 3. Identify performance outliers

The dashboard goes beyond overall averages by analyzing individual agent performance.

Examples include:

* High handling time
* Low customer satisfaction
* Low productivity
* Low occupancy
* Unusual AUX patterns
* Performance significantly different from the team or operational average

### 4. Support coaching and improvement

The analysis is intended to help Team Managers identify agents who may benefit from:

* Coaching
* Additional support
* Performance follow-up
* Process clarification
* Targeted development

The dashboard is therefore designed as a **decision-support tool**, rather than simply a reporting interface.

---

# 📊 Power BI Report Structure

The current report is organized into five main analytical areas:

1. **Overview**
2. **Operations**
3. **Customer Satisfaction**
4. **Voice Agents Performance**
5. **Email Agents Performance**


---

# 1. Executive Overview

### Business question

> **How is the operation performing overall?**

The Overview page provides management with a high-level snapshot of the operation.

### Main KPIs

* Total Interactions
* Answered Rate %
* Average Handling Time
* CSAT %
* Reviews Collected
* Active Agents

These KPIs are designed to respond dynamically to the selected filters.

### Main analysis

The page provides visibility into:

* Interaction volume trends
* Volume by campaign
* Handling time versus target
* Customer satisfaction trends
* Overall operational performance

The objective is to allow a manager to understand the current situation **within seconds**, before moving into more detailed analysis.

---

# 2. Operations

### Business question

> **Where are we experiencing workload or service-level issues?**

The Operations page focuses on workload and service performance.

### Key indicators

* Total Interactions
* Answered Rate %
* Abandonment Rate %
* Average Wait Time
* Average Handling Time

### Main analyses

#### Interaction volume by hour

Identifies periods of high workload throughout the working day.

#### Interaction volume by day

Highlights recurring daily workload patterns.

#### Channel distribution

Provides visibility into the relative contribution of:

* Voice
* Email

#### Volume by country

Allows managers to understand where operational workload is concentrated.

#### Abandonment / unanswered trend

Highlights changes in accessibility and service performance over time.

#### AHT distribution

Instead of relying only on average handling time, the report analyzes the distribution of handling times around the defined operational target.

This helps identify whether high AHT is:

* isolated to a small number of interactions,
* concentrated within specific periods,
* or representative of a broader operational pattern.

---

# 3. Customer Satisfaction

### Business question

> **What are customers experiencing, and where are satisfaction problems occurring?**

Customer satisfaction is a major focus of the project.

During the Q1 2026 analysis, overall CSAT is approximately **57%–60%**, indicating a significant area of development for the operation.

The dashboard therefore does not only present the overall CSAT value. It investigates **where and how customer satisfaction varies**.

### Main KPIs

* Review Count
* CSAT %
* Average Rating
* 5-Star %
* 1–2 Star %
* Review Rate %

### Analysis dimensions

Customer satisfaction can be analyzed by:

* Country
* Channel
* Issue
* Date
* Review channel
* Agent

### Rating distribution

The report displays the distribution of ratings from:

**1★ → 5★**

This provides more context than an average score alone.

For example, management can distinguish between:

* a broad deterioration in satisfaction,
* a concentration of highly negative reviews,
* or a relatively small number of negative reviews affecting the average.

### CSAT by issue

This analysis helps answer:

> **Which customer issues are associated with lower satisfaction?**

Examples include operational categories such as:

* Delivery
* Tracking
* Customs
* Invoice
* Technical issues
* Transit

This provides a bridge between customer feedback and operational root-cause analysis.

### Customer comments

A detailed review table allows managers to inspect individual feedback and connect ratings with:

* Country
* Channel
* Issue
* Date
* Agent
* Customer comment

---

# 4. Voice Agents Performance

### Business question

> **How are voice agents performing, and which agents may require development or coaching?**

This page focuses on individual agent performance and workforce behavior.

### Main KPIs

* Active Agents
* Average Handling Time
* Productivity %
* Occupancy %
* CSAT %
* Resolution %

### Agent performance analysis

Agents can be analyzed using several complementary dimensions rather than a single overall performance score.

Key indicators include:

* Handling time
* Customer satisfaction
* Interaction volume
* Productivity
* Occupancy

This allows managers to distinguish between different performance situations.

For example:

> An agent with high AHT and low CSAT represents a different development case from an agent with high AHT but strong customer satisfaction.

---

## AUX Analysis

Agent state data is used to analyze how working time is distributed across AUX states.

Examples include:

* Ready
* After Contact Work
* Administrative Work
* Break
* Lunch
* Personal Break
* Coaching
* Meeting
* Training

This provides visibility into how agents spend their working time.

---

## Productivity

Productivity is calculated using productive AUX time relative to working time.

This provides a workforce-oriented view of how much logged working time is classified as productive.

---

## Occupancy

Occupancy is calculated using handling time relative to Ready time.

This provides a view of how much available voice-agent time is spent handling interactions.

> The project documents this definition explicitly because occupancy can have different definitions across contact-center environments.

---

## Coaching Identification

The dashboard includes a **Coaching Priority** concept designed to help Team Managers identify agents who may require additional attention.

The analysis considers combinations such as:

* Higher-than-target handling time
* Lower customer satisfaction
* Sufficient interaction volume

The objective is not to label agents as "good" or "bad", but to provide managers with a **data-driven starting point for coaching and investigation**.

---

# 5. Email Agents Performance

### Business question

> **How are email agents performing against their operational objectives?**

Email operations require different performance indicators from voice.

The dashboard therefore separates email performance from voice performance rather than applying exactly the same KPIs to both channels.

### Main indicators

* Email interaction volume
* Daily productivity
* Target achievement
* Customer satisfaction
* Review rate
* Agent-level performance

The analysis allows Team Managers to investigate performance at both operational and individual-agent levels.

---

# 🎛️ Interactive Analysis

The report includes interactive slicers allowing managers to analyze performance dynamically.

### Country

Filter the report by country, including the operational markets covered by the project.

### Channel

Analyze performance by:

* Voice
* Email

### Issue

Investigate how different customer/contact reasons affect:

* Workload
* Handling time
* Customer satisfaction
* Agent performance

### Time

The report focuses on **Q1 2026**, with date-based analysis available throughout the reporting period.

Because the underlying model uses a dedicated date dimension, the report can be analyzed at different time granularities such as:

* Day
* Week
* Month

---

# 🏗️ Data Architecture

The Power BI dashboard is built on top of a structured SQL Server data warehouse.

The overall architecture follows a layered approach:

```text
Operational Database
        │
        ▼
     STG / Silver
        │
        │ Cleaning
        │ Standardization
        │ Validation
        │ Enrichment
        ▼
      Gold Layer
        │
        │ Star Schema
        ▼
     Power BI
```

The Gold layer follows a **Kimball-style star schema**.

The main fact tables include:

* `fact_interaction`
* `fact_review`
* `fact_agent_session`
* `fact_agent_state_event`

The dimensions include:

* `dim_date`
* `dim_employee`
* `dim_campaign`
* `dim_channel`
* `dim_issue`
* `dim_requestor`
* `dim_aux_state`
* `dim_review_channel`
* `dim_location`
* `dim_skill`

The Gold model is designed around clear analytical grains, including one row per interaction, review, agent session, and AUX-state event.

---

# 🧮 Power BI & DAX

The reporting layer uses DAX measures for dynamic KPI calculations.

Examples include:

* Total Interactions
* Total Reviews
* Answered Rate %
* Average Handling Time
* CSAT %
* Productivity %
* Occupancy %
* Working Time
* Productive Time
* Ready Time

Measures are designed to respond dynamically to the report's filter context.

For example, selecting:

```text
Country → France
Channel  → Voice
Issue    → Delivery
Period   → Q1 2026
```

updates the relevant KPIs and visuals to that specific analytical context.

---

# 🔎 Key Business Insight

One of the most important observations from the current Q1 2026 analysis is the relatively low customer satisfaction level.

CSAT remains around:

> **57%–60%**

This makes customer experience one of the main areas requiring further investigation.

However, the dashboard does not stop at identifying the low CSAT.

The next analytical questions are:

* Which countries are contributing most to the issue?
* Which customer issues have the lowest satisfaction?
* Is the problem concentrated in specific channels?
* Are certain agents significant outliers?
* Is high handling time associated with lower satisfaction?
* Are there specific operational patterns behind negative customer feedback?

This is the purpose of the analytical model: **move from KPI monitoring toward identifying actionable areas of development.**

---

# 🚧 Current Project Status

**This project is currently under development.**

The current Power BI report represents an evolving version of the final solution.

### Currently implemented

* SQL Server operational data model
* STG / Silver transformation layer
* Gold analytical star schema
* Power BI data model
* DAX KPI measures
* Executive overview
* Operations analysis
* Customer satisfaction analysis
* Voice agent performance analysis
* Email agent performance analysis
* Interactive campaign, channel, issue and time filtering
* Initial outlier analysis

### Currently being developed

* Further refinement of agent-performance KPIs
* Additional validation of business rules
* Dashboard UX and visual refinement
* Additional drill-through capabilities
* Performance optimization
* Further operational insights

The objective is to progressively transform the current analytical prototype into a robust **operations performance and workforce intelligence solution**.

---

# 🛠️ Technology Stack

| Technology       | Purpose                                         |
| ---------------- | ----------------------------------------------- |
| **SQL Server**   | Operational and analytical database             |
| **SQL**          | Data preparation, validation and transformation |
| **Power BI**     | Interactive reporting and visualization         |
| **DAX**          | KPI and analytical measure development          |
| **Star Schema**  | Analytical data modeling                        |
| **Git / GitHub** | Version control and project documentation       |

---

# 📈 Project Vision

The long-term objective of **Call Center Intelligence** is to provide a reliable analytical layer between operational data and management decision-making.

The solution is designed around a simple principle:

> **Turn operational data into information that managers can act on.**

Instead of forcing managers to manually interpret large volumes of operational records, the dashboard provides a structured view of:

**What is happening?**

↓

**Where is it happening?**

↓

**Who or what is driving the difference?**

↓

**What should be investigated or developed?**

The project will continue evolving as additional business rules, validation logic and analytical requirements are incorporated.

---

## 👤 Author

**Karima Lachheb**



