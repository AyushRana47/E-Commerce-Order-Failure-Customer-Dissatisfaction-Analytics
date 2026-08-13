-- =====================================================================
-- 05. ORDER ANALYSIS
-- Grain: vw_order_reviews_agg = 1 row per order_id
--        vw_order_base        = 1 row per order_id
--        vw_order_operational_failure = 1 row per order_id
--        vw_kpi_* views        = 1 summary row each
-- =====================================================================

USE ecommerce_order_failure;
GO

-- =====================================================================
-- 5.1 REVIEW-TO-ORDER COLLAPSE
-- Fixes the orders->reviews 1-to-many risk: an order_id can have
-- multiple review records. We collapse to one row per order BEFORE
-- joining to orders, so vw_order_base cannot multiply order rows.
--
-- Design decision (documented, not hidden):
--   - "representative" review per order = the one with the latest
--     review_creation_date (tie-broken by review_answer_timestamp),
--     since a later review is more likely to reflect the customer's
--     final/settled opinion after any interaction with the seller.
--   - review_count_for_order and min/max score are also exposed so
--     downstream users can see when an order had multiple reviews and
--     apply a different rule (e.g. worst-case = MIN score) if they
--     prefer, rather than silently picking one interpretation.
-- =====================================================================
CREATE OR ALTER VIEW dbo.vw_order_reviews_agg AS
WITH ranked_reviews AS (
    SELECT
        r.*,
        ROW_NUMBER() OVER (
            PARTITION BY r.order_id
            ORDER BY r.review_creation_date DESC,
                     r.review_answer_timestamp DESC,
                     r.review_pk DESC
        ) AS rn
    FROM dbo.raw_order_reviews r
),
review_stats AS (
    SELECT
        order_id,
        COUNT(*)              AS review_count_for_order,
        MIN(review_score)     AS min_review_score,
        MAX(review_score)     AS max_review_score,
        AVG(CAST(review_score AS DECIMAL(4,2))) AS avg_review_score
    FROM dbo.raw_order_reviews
    GROUP BY order_id
)
SELECT
    rr.order_id,
    rr.review_id                AS latest_review_id,
    rr.review_score              AS latest_review_score,
    rr.review_comment_title      AS latest_review_comment_title,
    rr.review_comment_message    AS latest_review_comment_message,
    rr.review_creation_date      AS latest_review_creation_date,
    rr.review_answer_timestamp   AS latest_review_answer_timestamp,
    rs.review_count_for_order,
    rs.min_review_score,
    rs.max_review_score,
    rs.avg_review_score
FROM ranked_reviews rr
JOIN review_stats rs ON rs.order_id = rr.order_id
WHERE rr.rn = 1;
GO

-- =====================================================================
-- 5.2 ORDER BASE VIEW — 1 row per order
--
-- customer_dissatisfaction  : latest_review_score <= 2 (project
--                              definition). NULL when the order has no
--                              review at all.
--
-- late_delivery               : order_delivered_customer_date >
--                              order_estimated_delivery_date.
--                              NULL when not yet delivered (lateness of
--                              a delivery that hasn't happened can't be
--                              evaluated).
--
-- delivery_failure           : order_status IN ('canceled','unavailable').
--                              The only two documented statuses that
--                              represent a delivery that will never
--                              complete. Orders sitting in 'shipped' /
--                              'invoiced' with no delivered date are
--                              NOT flagged — that would require an
--                              "as of" reference date decision not
--                              currently specified, and flagging them
--                              would be an invented assumption.
--
-- operational_failure        : late_delivery OR delivery_failure.
--                              A third signal (payment_issue) is part
--                              of the project's definition but CANNOT
--                              be computed — no order_payments table is
--                              available. Exposed here as an explicit
--                              NULL column, not silently omitted.
--
-- NOTE: T-SQL's DATEDIFF(datepart, startdate, enddate) takes a datepart
-- and the arguments in the opposite order to MySQL's DATEDIFF(a, b).
-- =====================================================================
CREATE OR ALTER VIEW dbo.vw_order_base AS
SELECT
    o.order_id,
    o.customer_id,
    o.order_status,
    o.order_purchase_timestamp,
    o.order_approved_at,
    o.order_delivered_carrier_date,
    o.order_delivered_customer_date,
    o.order_estimated_delivery_date,

    ra.latest_review_id                AS review_id,
    ra.latest_review_score             AS review_score,
    ra.latest_review_comment_title     AS review_title,
    ra.latest_review_comment_message   AS review_comment,
    ra.latest_review_creation_date     AS review_creation_date,
    ra.review_count_for_order,
    ra.min_review_score,
    ra.max_review_score,
    ra.avg_review_score,

    -- Delivery timing metrics
    DATEDIFF(day, o.order_estimated_delivery_date, o.order_delivered_customer_date)
        AS delivery_delay_days,          -- positive = late, negative = early, NULL = not delivered
    DATEDIFF(day, o.order_purchase_timestamp, o.order_delivered_customer_date)
        AS delivery_duration_days,       -- NULL = not delivered

    -- Flags
    CASE
        WHEN o.order_delivered_customer_date IS NULL THEN NULL
        WHEN o.order_delivered_customer_date > o.order_estimated_delivery_date THEN 1
        ELSE 0
    END AS late_delivery_flag,

    CASE
        WHEN o.order_status IN ('canceled', 'unavailable') THEN 1
        ELSE 0
    END AS delivery_failure_flag,

    CASE
        WHEN ra.latest_review_score IS NULL THEN NULL
        WHEN ra.latest_review_score <= 2 THEN 1
        ELSE 0
    END AS customer_dissatisfaction_flag

FROM dbo.raw_orders o
LEFT JOIN dbo.vw_order_reviews_agg ra ON ra.order_id = o.order_id;
GO

-- =====================================================================
-- 5.3 OPERATIONAL FAILURE VIEW
-- Kept separate from vw_order_base so the "payment_issue not
-- available" gap is explicit and not buried inside a wide table.
-- =====================================================================
CREATE OR ALTER VIEW dbo.vw_order_operational_failure AS
SELECT
    order_id,
    late_delivery_flag,
    delivery_failure_flag,
    CAST(NULL AS INT) AS payment_issue_flag,   -- NOT COMPUTABLE: no order_payments table provided
    CASE
        WHEN late_delivery_flag = 1 OR delivery_failure_flag = 1 THEN 1
        ELSE 0
    END AS operational_failure_flag_partial   -- "partial" = excludes payment_issue by necessity
FROM dbo.vw_order_base;
GO

-- =====================================================================
-- 5.4 BUSINESS KPI VIEWS
-- Each returns a single summary row with numerator/denominator exposed
-- alongside the rate, so the definition is auditable.
-- =====================================================================

-- Dissatisfaction Rate
-- Numerator   : orders whose representative review_score <= 2
-- Denominator : orders that have a review at all (review_score IS NOT NULL)
CREATE OR ALTER VIEW dbo.vw_kpi_dissatisfaction_rate AS
SELECT
    SUM(CASE WHEN customer_dissatisfaction_flag = 1 THEN 1 ELSE 0 END) AS dissatisfied_orders,
    SUM(CASE WHEN review_score IS NOT NULL THEN 1 ELSE 0 END)          AS orders_with_valid_review,
    ROUND(
        CAST(SUM(CASE WHEN customer_dissatisfaction_flag = 1 THEN 1 ELSE 0 END) AS DECIMAL(10,4)) /
        NULLIF(SUM(CASE WHEN review_score IS NOT NULL THEN 1 ELSE 0 END), 0), 4
    ) AS dissatisfaction_rate
FROM dbo.vw_order_base;
GO

-- Operational Failure Rate (PARTIAL — payment_issue not available)
-- Numerator   : orders with late_delivery_flag=1 OR delivery_failure_flag=1
-- Denominator : all orders
CREATE OR ALTER VIEW dbo.vw_kpi_operational_failure_rate_partial AS
SELECT
    SUM(CASE WHEN operational_failure_flag_partial = 1 THEN 1 ELSE 0 END) AS operational_failures,
    COUNT(*)                                                              AS total_orders,
    ROUND(
        CAST(SUM(CASE WHEN operational_failure_flag_partial = 1 THEN 1 ELSE 0 END) AS DECIMAL(10,4)) /
        COUNT(*), 4
    ) AS operational_failure_rate_partial
FROM dbo.vw_order_operational_failure;
GO

-- Delivery Delay Rate
-- Numerator   : delivered orders where late_delivery_flag = 1
-- Denominator : delivered orders with a non-null delivered_customer_date
CREATE OR ALTER VIEW dbo.vw_kpi_delivery_delay_rate AS
SELECT
    SUM(CASE WHEN late_delivery_flag = 1 THEN 1 ELSE 0 END)                        AS late_delivered_orders,
    SUM(CASE WHEN order_delivered_customer_date IS NOT NULL THEN 1 ELSE 0 END)     AS delivered_orders_valid_dates,
    ROUND(
        CAST(SUM(CASE WHEN late_delivery_flag = 1 THEN 1 ELSE 0 END) AS DECIMAL(10,4)) /
        NULLIF(SUM(CASE WHEN order_delivered_customer_date IS NOT NULL THEN 1 ELSE 0 END), 0), 4
    ) AS delivery_delay_rate
FROM dbo.vw_order_base;
GO

-- Delivery Failure Rate
-- Numerator   : orders with delivery_failure_flag = 1
-- Denominator : all orders
CREATE OR ALTER VIEW dbo.vw_kpi_delivery_failure_rate AS
SELECT
    SUM(CASE WHEN delivery_failure_flag = 1 THEN 1 ELSE 0 END) AS failed_orders,
    COUNT(*)                                                   AS total_orders,
    ROUND(
        CAST(SUM(CASE WHEN delivery_failure_flag = 1 THEN 1 ELSE 0 END) AS DECIMAL(10,4)) /
        COUNT(*), 4
    ) AS delivery_failure_rate
FROM dbo.vw_order_base;
GO

-- Seller Dissatisfaction Rate — NOT COMPUTABLE.
-- Requires order_items (order_id -> seller_id) and raw_sellers, neither
-- of which is provided. No view is created for it; add it here once
-- those two tables are loaded, following the same aggregate-before-join
-- pattern used in 5.1 (aggregate order_items to (order_id, seller_id)
-- grain first, join to vw_order_base, then aggregate up to seller_id —
-- otherwise sellers with multiple items per order get double-counted).

-- =====================================================================
-- 5.5 VALIDATION QUERIES
-- Sanity checks on this analytical layer. Read-only.
-- =====================================================================

-- vw_order_base row count should exactly equal raw_orders row count —
-- confirms the LEFT JOIN to the review aggregate did not multiply or
-- drop any order rows.
SELECT
    (SELECT COUNT(*) FROM dbo.raw_orders)    AS raw_orders_count,
    (SELECT COUNT(*) FROM dbo.vw_order_base) AS order_base_count;

-- vw_order_reviews_agg row count should equal the number of DISTINCT
-- order_id values in raw_order_reviews — confirms one row per order
-- after the ROW_NUMBER() collapse, even where multiple reviews existed.
SELECT
    (SELECT COUNT(DISTINCT order_id) FROM dbo.raw_order_reviews) AS distinct_reviewed_orders,
    (SELECT COUNT(*) FROM dbo.vw_order_reviews_agg)               AS review_agg_count;

-- Spot-check: orders with multiple reviews should have
-- review_count_for_order > 1 reflected correctly in vw_order_base.
SELECT TOP 20 order_id, review_count_for_order, review_score, min_review_score, max_review_score
FROM dbo.vw_order_base
WHERE review_count_for_order > 1
ORDER BY review_count_for_order DESC;

-- Flag distribution sanity checks — eyeball that flags are in {0,1,NULL}
-- and roughly plausible in proportion.
SELECT late_delivery_flag, COUNT(*) AS cnt FROM dbo.vw_order_base GROUP BY late_delivery_flag;
SELECT delivery_failure_flag, COUNT(*) AS cnt FROM dbo.vw_order_base GROUP BY delivery_failure_flag;
SELECT customer_dissatisfaction_flag, COUNT(*) AS cnt FROM dbo.vw_order_base GROUP BY customer_dissatisfaction_flag;

-- KPI views should each return exactly one row.
SELECT * FROM dbo.vw_kpi_dissatisfaction_rate;
SELECT * FROM dbo.vw_kpi_operational_failure_rate_partial;
SELECT * FROM dbo.vw_kpi_delivery_delay_rate;
SELECT * FROM dbo.vw_kpi_delivery_failure_rate;
GO
