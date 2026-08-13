-- =====================================================================
-- 02. TABLE CREATION — RAW LAYER
-- Only tables for the 5 CSVs actually provided are created.
-- order_items, sellers, order_payments, category_translation are NOT
-- created here — they do not exist in the provided dataset. Creating
-- them now would invent a schema we have not inspected.
-- =====================================================================

USE ecommerce_order_failure;
GO

-- ---------------------------------------------------------------------
-- customers  |  grain: 1 row per customer_id
-- customer_id is the order-scoped identifier and is the PK here.
-- customer_unique_id is NOT unique in this table (per spec) and is
-- therefore only indexed, not constrained as unique.
-- ---------------------------------------------------------------------
IF OBJECT_ID('dbo.raw_customers', 'U') IS NOT NULL DROP TABLE dbo.raw_customers;
GO
CREATE TABLE dbo.raw_customers (
    customer_id              VARCHAR(32)   NOT NULL,
    customer_unique_id       VARCHAR(32)   NOT NULL,
    customer_zip_code_prefix INT           NOT NULL,
    customer_city            NVARCHAR(100) NOT NULL,
    customer_state           CHAR(2)       NOT NULL,
    CONSTRAINT pk_customers PRIMARY KEY (customer_id),
    INDEX idx_customers_unique_id NONCLUSTERED (customer_unique_id),
    INDEX idx_customers_zip NONCLUSTERED (customer_zip_code_prefix)
);
GO

-- ---------------------------------------------------------------------
-- orders  |  grain: 1 row per order_id
-- FK to customers is valid because customer_id is the orders.customer_id
-- join key confirmed in the spec.
-- ---------------------------------------------------------------------
IF OBJECT_ID('dbo.raw_orders', 'U') IS NOT NULL DROP TABLE dbo.raw_orders;
GO
CREATE TABLE dbo.raw_orders (
    order_id                       VARCHAR(32) NOT NULL,
    customer_id                    VARCHAR(32) NOT NULL,
    order_status                   VARCHAR(20) NOT NULL,
    order_purchase_timestamp       DATETIME2   NOT NULL,
    order_approved_at              DATETIME2   NULL,
    order_delivered_carrier_date   DATETIME2   NULL,
    order_delivered_customer_date  DATETIME2   NULL,
    order_estimated_delivery_date  DATETIME2   NOT NULL,
    CONSTRAINT pk_orders PRIMARY KEY (order_id),
    INDEX idx_orders_customer_id NONCLUSTERED (customer_id),
    INDEX idx_orders_status NONCLUSTERED (order_status),
    INDEX idx_orders_purchase_ts NONCLUSTERED (order_purchase_timestamp),
    CONSTRAINT fk_orders_customer
        FOREIGN KEY (customer_id) REFERENCES dbo.raw_customers (customer_id)
);
GO

-- ---------------------------------------------------------------------
-- order_reviews  |  grain: 1 row per review record (NOT guaranteed 1:1
-- with order_id — spec confirms multiple reviews can share an order_id).
-- review_id is NOT assumed unique; we do not enforce it as a PK.
-- A surrogate key is used instead, and duplicate review_id / multi-review
-- orders are checked explicitly in 04_data_quality_checks.sql.
-- ---------------------------------------------------------------------
IF OBJECT_ID('dbo.raw_order_reviews', 'U') IS NOT NULL DROP TABLE dbo.raw_order_reviews;
GO
CREATE TABLE dbo.raw_order_reviews (
    review_pk                INT IDENTITY(1,1) NOT NULL,
    review_id                VARCHAR(32)   NOT NULL,
    order_id                 VARCHAR(32)   NOT NULL,
    review_score             TINYINT       NOT NULL,
    review_comment_title     NVARCHAR(255) NULL,
    review_comment_message   NVARCHAR(MAX) NULL,
    review_creation_date     DATETIME2     NOT NULL,
    review_answer_timestamp  DATETIME2     NOT NULL,
    CONSTRAINT pk_reviews PRIMARY KEY (review_pk),
    INDEX idx_reviews_review_id NONCLUSTERED (review_id),
    INDEX idx_reviews_order_id NONCLUSTERED (order_id),
    INDEX idx_reviews_score NONCLUSTERED (review_score),
    INDEX idx_reviews_creation_date NONCLUSTERED (review_creation_date),
    CONSTRAINT fk_reviews_order
        FOREIGN KEY (order_id) REFERENCES dbo.raw_orders (order_id)
);
GO

-- ---------------------------------------------------------------------
-- products  |  grain: 1 row per product_id
-- NOT joinable to orders in this dataset slice — no order_items table.
-- Kept as a standalone reference table for when order_items arrives.
-- ---------------------------------------------------------------------
IF OBJECT_ID('dbo.raw_products', 'U') IS NOT NULL DROP TABLE dbo.raw_products;
GO
CREATE TABLE dbo.raw_products (
    product_id                  VARCHAR(32)   NOT NULL,
    product_category_name       NVARCHAR(100) NULL,
    product_name_lenght         SMALLINT      NULL,
    product_description_lenght  SMALLINT      NULL,
    product_photos_qty          SMALLINT      NULL,
    product_weight_g            INT           NULL,
    product_length_cm           INT           NULL,
    product_height_cm           INT           NULL,
    product_width_cm            INT           NULL,
    CONSTRAINT pk_products PRIMARY KEY (product_id),
    INDEX idx_products_category NONCLUSTERED (product_category_name)
);
GO

-- ---------------------------------------------------------------------
-- geolocation  |  grain: many rows per zip prefix, no natural PK.
-- Not joined to anything downstream in this phase (customers already
-- carry city/state directly); kept for future geo-enrichment only.
-- ---------------------------------------------------------------------
IF OBJECT_ID('dbo.raw_geolocation', 'U') IS NOT NULL DROP TABLE dbo.raw_geolocation;
GO
CREATE TABLE dbo.raw_geolocation (
    geolocation_pk               INT IDENTITY(1,1) NOT NULL,
    geolocation_zip_code_prefix  INT           NOT NULL,
    geolocation_lat              DECIMAL(9,6)  NOT NULL,
    geolocation_lng              DECIMAL(9,6)  NOT NULL,
    geolocation_city             NVARCHAR(100) NOT NULL,
    geolocation_state            CHAR(2)       NOT NULL,
    CONSTRAINT pk_geolocation PRIMARY KEY (geolocation_pk),
    INDEX idx_geo_zip NONCLUSTERED (geolocation_zip_code_prefix)
);
GO

-- ---------------------------------------------------------------------
-- Supplemental composite index
-- Covers the PARTITION BY order_id / ORDER BY review_creation_date,
-- review_answer_timestamp window function used in 05_order_analysis.sql
-- to pick each order's "latest" review — the single-column indexes
-- above don't fully cover that combination.
-- ---------------------------------------------------------------------
CREATE INDEX idx_reviews_order_created
    ON dbo.raw_order_reviews (order_id, review_creation_date, review_answer_timestamp);
GO

-- ---------------------------------------------------------------------
-- NOT CREATED (do not add without inspecting the real files first):
--   raw_order_items
--   raw_sellers
--   raw_order_payments
--   raw_product_category_translation
-- ---------------------------------------------------------------------
