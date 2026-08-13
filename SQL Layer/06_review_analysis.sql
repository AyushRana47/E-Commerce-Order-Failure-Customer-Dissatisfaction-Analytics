-- =====================================================================
-- 06. REVIEW ANALYSIS
-- Grain: 1 row per review record (raw grain, NOT collapsed to order —
-- the downstream GenAI classification step works on individual review
-- text, so it needs every review, not just one representative row per
-- order the way 05_order_analysis.sql does for order-level metrics).
-- No text classification happens here — selection/prep only, per the
-- project rule that GenAI classification runs in Python, not SQL.
-- =====================================================================

USE ecommerce_order_failure;
GO

-- =====================================================================
-- 6.1 CLEAN REVIEW DATASET
-- =====================================================================
CREATE OR ALTER VIEW dbo.vw_review_dataset AS
SELECT
    r.review_pk,
    r.review_id,
    r.order_id,
    o.customer_id,
    r.review_score,
    r.review_comment_title,
    r.review_comment_message,
    r.review_creation_date,
    r.review_answer_timestamp,
    o.order_status,
    o.order_purchase_timestamp,
    o.order_delivered_customer_date,
    o.order_estimated_delivery_date
    -- product_category / seller_id intentionally NOT included:
    -- no join path exists from order_id to product or seller without
    -- order_items. Add these columns once order_items is loaded.
FROM dbo.raw_order_reviews r
JOIN dbo.raw_orders o ON o.order_id = r.order_id;
GO

-- =====================================================================
-- 6.2 NEGATIVE-REVIEW SUBSET
-- This is the population the project's dissatisfaction analysis and
-- GenAI classification taxonomy (LATE_DELIVERY, PRODUCT_QUALITY,
-- PRODUCT_NOT_AS_DESCRIBED, WRONG_PRODUCT, SIZE_OR_FIT, DAMAGED_PRODUCT,
-- DAMAGED_PACKAGING, SELLER_SERVICE, PAYMENT_ISSUE, DELIVERY_HANDLING,
-- OTHER, NO_CLEAR_ISSUE) will run against.
-- =====================================================================
CREATE OR ALTER VIEW dbo.vw_review_dataset_negative AS
SELECT *
FROM dbo.vw_review_dataset
WHERE review_score <= 2;
GO

-- =====================================================================
-- 6.3 VALIDATION QUERIES
-- =====================================================================

-- vw_review_dataset row count should equal raw_order_reviews row count —
-- confirms the JOIN to orders (all reviews have a valid order_id via
-- FK) did not drop or multiply any review rows.
SELECT
    (SELECT COUNT(*) FROM dbo.raw_order_reviews) AS raw_reviews_count,
    (SELECT COUNT(*) FROM dbo.vw_review_dataset)  AS review_dataset_count;

-- Negative review subset should only ever contain review_score 1 or 2.
SELECT DISTINCT review_score FROM dbo.vw_review_dataset_negative;

-- How much review text is actually usable for GenAI classification —
-- title and message are both frequently blank in this dataset (per the
-- data model assessment), so this matters for scoping that step.
SELECT
    COUNT(*)                                                                            AS total_negative_reviews,
    SUM(CASE WHEN review_comment_message IS NOT NULL THEN 1 ELSE 0 END)                  AS have_message,
    SUM(CASE WHEN review_comment_title IS NOT NULL THEN 1 ELSE 0 END)                    AS have_title,
    SUM(CASE WHEN review_comment_message IS NULL AND review_comment_title IS NULL THEN 1 ELSE 0 END)
        AS have_no_text_at_all
FROM dbo.vw_review_dataset_negative;
GO
