-- =====================================================================
-- 04. DATA QUALITY CHECKS
-- Read-only. No raw table is modified by anything in this file.
-- =====================================================================

USE ecommerce_order_failure;
GO

-- ---------------------------------------------------------------------
-- 4.1 COMPLETENESS — row counts
-- ---------------------------------------------------------------------
SELECT 'raw_customers'      AS table_name, COUNT(*) AS row_count FROM dbo.raw_customers
UNION ALL
SELECT 'raw_orders',                       COUNT(*) FROM dbo.raw_orders
UNION ALL
SELECT 'raw_order_reviews',                COUNT(*) FROM dbo.raw_order_reviews
UNION ALL
SELECT 'raw_products',                     COUNT(*) FROM dbo.raw_products
UNION ALL
SELECT 'raw_geolocation',                  COUNT(*) FROM dbo.raw_geolocation;
GO

-- ---------------------------------------------------------------------
-- 4.2 COMPLETENESS — NULL counts on fields expected to matter downstream
-- ---------------------------------------------------------------------
SELECT
    SUM(CASE WHEN order_approved_at IS NULL THEN 1 ELSE 0 END)             AS null_approved_at,
    SUM(CASE WHEN order_delivered_carrier_date IS NULL THEN 1 ELSE 0 END)  AS null_carrier_date,
    SUM(CASE WHEN order_delivered_customer_date IS NULL THEN 1 ELSE 0 END) AS null_delivered_date,
    SUM(CASE WHEN order_estimated_delivery_date IS NULL THEN 1 ELSE 0 END) AS null_estimated_date,
    SUM(CASE WHEN order_status IS NULL THEN 1 ELSE 0 END)                  AS null_status
FROM dbo.raw_orders;
GO

SELECT
    SUM(CASE WHEN review_score IS NULL THEN 1 ELSE 0 END)           AS null_review_score,
    SUM(CASE WHEN review_comment_title IS NULL THEN 1 ELSE 0 END)   AS null_title,
    SUM(CASE WHEN review_comment_message IS NULL THEN 1 ELSE 0 END) AS null_message
FROM dbo.raw_order_reviews;
GO

SELECT
    SUM(CASE WHEN product_category_name IS NULL THEN 1 ELSE 0 END) AS null_category,
    SUM(CASE WHEN product_weight_g IS NULL THEN 1 ELSE 0 END)      AS null_weight
FROM dbo.raw_products;
GO

-- ---------------------------------------------------------------------
-- 4.3 UNIQUENESS — duplicate primary/business keys
-- ---------------------------------------------------------------------

-- Duplicate order_id (should be zero — order_id is the orders PK)
SELECT order_id, COUNT(*) AS occurrences
FROM dbo.raw_orders
GROUP BY order_id
HAVING COUNT(*) > 1;

-- Duplicate customer_id (should be zero — customers PK)
SELECT customer_id, COUNT(*) AS occurrences
FROM dbo.raw_customers
GROUP BY customer_id
HAVING COUNT(*) > 1;

-- Duplicate product_id (should be zero — products PK)
SELECT product_id, COUNT(*) AS occurrences
FROM dbo.raw_products
GROUP BY product_id
HAVING COUNT(*) > 1;

-- Duplicate review_id — NOT assumed unique per the data model assessment.
-- This check tells us whether it actually is, empirically.
SELECT review_id, COUNT(*) AS occurrences
FROM dbo.raw_order_reviews
GROUP BY review_id
HAVING COUNT(*) > 1;

-- Orders with more than one review record — confirms/measures the
-- 1-to-many risk called out in the assessment.
SELECT order_id, COUNT(*) AS review_count
FROM dbo.raw_order_reviews
GROUP BY order_id
HAVING COUNT(*) > 1
ORDER BY review_count DESC;
GO

-- ---------------------------------------------------------------------
-- 4.4 REFERENTIAL INTEGRITY — orphan checks
-- (FKs already enforce orders->customers and reviews->orders at load
-- time, so these should return zero rows by construction; they are
-- included so the check is explicit and self-documenting.)
-- ---------------------------------------------------------------------

-- Orphaned orders (customer_id not found in customers)
SELECT o.order_id, o.customer_id
FROM dbo.raw_orders o
LEFT JOIN dbo.raw_customers c ON o.customer_id = c.customer_id
WHERE c.customer_id IS NULL;

-- Orphaned reviews (order_id not found in orders)
SELECT r.review_pk, r.review_id, r.order_id
FROM dbo.raw_order_reviews r
LEFT JOIN dbo.raw_orders o ON r.order_id = o.order_id
WHERE o.order_id IS NULL;

-- NOTE: orphan checks for order_items, sellers, payments, and products
-- (against orders) cannot be performed — order_items does not exist in
-- this dataset slice, so there is no join path from orders to products
-- or sellers to check.
GO

-- ---------------------------------------------------------------------
-- 4.5 DATE VALIDITY
-- ---------------------------------------------------------------------

-- Delivered before purchased (should never happen)
SELECT order_id, order_purchase_timestamp, order_delivered_customer_date
FROM dbo.raw_orders
WHERE order_delivered_customer_date IS NOT NULL
  AND order_delivered_customer_date < order_purchase_timestamp;

-- Estimated delivery before purchase date (should never happen)
SELECT order_id, order_purchase_timestamp, order_estimated_delivery_date
FROM dbo.raw_orders
WHERE order_estimated_delivery_date < order_purchase_timestamp;

-- Approved before purchased (should never happen)
SELECT order_id, order_purchase_timestamp, order_approved_at
FROM dbo.raw_orders
WHERE order_approved_at IS NOT NULL
  AND order_approved_at < order_purchase_timestamp;

-- Carrier handoff after customer delivery (should never happen)
SELECT order_id, order_delivered_carrier_date, order_delivered_customer_date
FROM dbo.raw_orders
WHERE order_delivered_carrier_date IS NOT NULL
  AND order_delivered_customer_date IS NOT NULL
  AND order_delivered_carrier_date > order_delivered_customer_date;

-- Orders marked 'delivered' but missing a delivered_customer_date
-- (data quality flag — status/timestamp inconsistency)
SELECT order_id, order_status, order_delivered_customer_date
FROM dbo.raw_orders
WHERE order_status = 'delivered'
  AND order_delivered_customer_date IS NULL;
GO

-- ---------------------------------------------------------------------
-- 4.6 MONETARY VALIDITY
-- Not applicable in this dataset slice — no price, freight, or payment
-- fields exist without order_items / order_payments. Skipped here
-- deliberately rather than checked against non-existent columns.
-- ---------------------------------------------------------------------

-- ---------------------------------------------------------------------
-- 4.7 DOMAIN VALIDITY — order_status and review_score ranges
-- ---------------------------------------------------------------------

-- Any order_status value outside the documented set
SELECT DISTINCT order_status
FROM dbo.raw_orders
WHERE order_status NOT IN
    ('delivered','shipped','canceled','unavailable',
     'invoiced','processing','created','approved');

-- Any review_score outside 1-5
SELECT DISTINCT review_score
FROM dbo.raw_order_reviews
WHERE review_score NOT BETWEEN 1 AND 5;
GO
