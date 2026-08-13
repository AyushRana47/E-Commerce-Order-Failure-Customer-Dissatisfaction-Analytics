/*
===============================================================================
03_load_data.sql
E-Commerce Order Failure Analysis - Olist Dataset
SQL Server / SSMS
===============================================================================

PURPOSE
Loads the Olist source datasets into staging tables, cleans/converts them,
and inserts them into the typed RAW layer.

SOURCE FILES
- olist_customers_dataset.csv
- olist_orders_dataset.csv
- olist_order_reviews_CLEAN.txt
- olist_products_dataset.csv
- olist_geolocation_dataset.csv

SETUP
1. Enable "SQLCMD Mode" in SSMS.
2. Change DATASET_PATH below to your local dataset folder.
3. Run after 01_database_setup.sql and 02_create_raw_tables.sql.

IMPORTANT
SQL Server BULK INSERT reads files from the SQL Server machine/service
account, so that account must have read access to DATASET_PATH.

The original Olist review CSV caused BULK INSERT parsing errors in this
project. The cleaned pipe-delimited review file is therefore used.
===============================================================================
*/

:setvar DATASET_PATH "D:\New folder\Desktop\ECOM Project\DATASET"

USE ecommerce_order_failure;
GO

USE ecommerce_order_failure;
GO

-- ---------------------------------------------------------------------
-- customers
-- ---------------------------------------------------------------------
IF OBJECT_ID('dbo.stg_customers', 'U') IS NOT NULL DROP TABLE dbo.stg_customers;
-- Clear existing raw data safely, regardless of FK dependency order.
DECLARE @sql NVARCHAR(MAX) = N'';

SELECT @sql = @sql +
    N'ALTER TABLE ' + QUOTENAME(SCHEMA_NAME(t.schema_id)) + N'.' + QUOTENAME(t.name) +
    N' NOCHECK CONSTRAINT ALL;' + CHAR(13)
FROM sys.tables t
WHERE SCHEMA_NAME(t.schema_id) = N'dbo'
  AND t.name LIKE N'raw[_]%';

EXEC sys.sp_executesql @sql;

SET @sql = N'';

SELECT @sql = @sql +
    N'DELETE FROM ' + QUOTENAME(SCHEMA_NAME(t.schema_id)) + N'.' + QUOTENAME(t.name) + N';' + CHAR(13)
FROM sys.tables t
WHERE SCHEMA_NAME(t.schema_id) = N'dbo'
  AND t.name LIKE N'raw[_]%';

EXEC sys.sp_executesql @sql;

SET @sql = N'';

SELECT @sql = @sql +
    N'ALTER TABLE ' + QUOTENAME(SCHEMA_NAME(t.schema_id)) + N'.' + QUOTENAME(t.name) +
    N' WITH CHECK CHECK CONSTRAINT ALL;' + CHAR(13)
FROM sys.tables t
WHERE SCHEMA_NAME(t.schema_id) = N'dbo'
  AND t.name LIKE N'raw[_]%';

EXEC sys.sp_executesql @sql;

CREATE TABLE dbo.stg_customers (
    customer_id NVARCHAR(MAX),
    customer_unique_id NVARCHAR(MAX),
    customer_zip_code_prefix NVARCHAR(MAX),
    customer_city NVARCHAR(MAX),
    customer_state NVARCHAR(MAX)
);
GO

BULK INSERT dbo.stg_customers
FROM '$(DATASET_PATH)\olist_customers_dataset.csv'
WITH (
    FORMAT = 'CSV',
    FIRSTROW = 2,
    FIELDQUOTE = '"',
    FIELDTERMINATOR = ',',
    ROWTERMINATOR = '0x0a',
    CODEPAGE = '65001',
    TABLOCK
);
GO

INSERT INTO dbo.raw_customers
    (customer_id, customer_unique_id, customer_zip_code_prefix, customer_city, customer_state)
SELECT
    NULLIF(TRIM(customer_id), ''),
    NULLIF(TRIM(customer_unique_id), ''),
    TRY_CONVERT(INT, NULLIF(TRIM(customer_zip_code_prefix), '')),
    NULLIF(TRIM(customer_city), ''),
    NULLIF(TRIM(customer_state), '')
FROM dbo.stg_customers;
GO

-- ---------------------------------------------------------------------
-- orders  (nullable timestamps: empty string -> NULL, not '')
-- ---------------------------------------------------------------------
IF OBJECT_ID('dbo.stg_orders', 'U') IS NOT NULL DROP TABLE dbo.stg_orders;
CREATE TABLE dbo.stg_orders (
    order_id NVARCHAR(MAX),
    customer_id NVARCHAR(MAX),
    order_status NVARCHAR(MAX),
    order_purchase_timestamp NVARCHAR(MAX),
    order_approved_at NVARCHAR(MAX),
    order_delivered_carrier_date NVARCHAR(MAX),
    order_delivered_customer_date NVARCHAR(MAX),
    order_estimated_delivery_date NVARCHAR(MAX)
);
GO

BULK INSERT dbo.stg_orders
FROM '$(DATASET_PATH)\olist_orders_dataset.csv'
WITH (
    FORMAT = 'CSV',
    FIRSTROW = 2,
    FIELDQUOTE = '"',
    FIELDTERMINATOR = ',',
    ROWTERMINATOR = '0x0a',
    CODEPAGE = '65001',
    TABLOCK
);
GO

INSERT INTO dbo.raw_orders
    (order_id, customer_id, order_status, order_purchase_timestamp,
     order_approved_at, order_delivered_carrier_date,
     order_delivered_customer_date, order_estimated_delivery_date)
SELECT
    NULLIF(TRIM(order_id), ''),
    NULLIF(TRIM(customer_id), ''),
    NULLIF(TRIM(order_status), ''),
    TRY_CONVERT(DATETIME2, NULLIF(TRIM(order_purchase_timestamp), '')),
    TRY_CONVERT(DATETIME2, NULLIF(TRIM(order_approved_at), '')),
    TRY_CONVERT(DATETIME2, NULLIF(TRIM(order_delivered_carrier_date), '')),
    TRY_CONVERT(DATETIME2, NULLIF(TRIM(order_delivered_customer_date), '')),
    TRY_CONVERT(DATETIME2, NULLIF(TRIM(order_estimated_delivery_date), ''))
FROM dbo.stg_orders;
GO

-- ---------------------------------------------------------------------
-- order reviews  (title / message frequently blank)
-- ---------------------------------------------------------------------
IF OBJECT_ID('dbo.stg_order_reviews', 'U') IS NOT NULL DROP TABLE dbo.stg_order_reviews;
CREATE TABLE dbo.stg_order_reviews (
    review_id NVARCHAR(MAX),
    order_id NVARCHAR(MAX),
    review_score NVARCHAR(MAX),
    review_comment_title NVARCHAR(MAX),
    review_comment_message NVARCHAR(MAX),
    review_creation_date NVARCHAR(MAX),
    review_answer_timestamp NVARCHAR(MAX)
);
GO

BULK INSERT dbo.stg_order_reviews
FROM '$(DATASET_PATH)\olist_order_reviews_CLEAN.txt'
WITH (
    DATAFILETYPE = 'char',
    FIELDTERMINATOR = '|',
    ROWTERMINATOR = '0x0a',
    FIRSTROW = 2,
    CODEPAGE = '65001',
    TABLOCK
);
GO

INSERT INTO dbo.raw_order_reviews
    (review_id, order_id, review_score, review_comment_title,
     review_comment_message, review_creation_date, review_answer_timestamp)
SELECT
    NULLIF(TRIM(review_id), ''),
    NULLIF(TRIM(order_id), ''),
    TRY_CONVERT(TINYINT, NULLIF(TRIM(review_score), '')),
    NULLIF(TRIM(review_comment_title), ''),
    NULLIF(TRIM(review_comment_message), ''),
    TRY_CONVERT(DATETIME2, NULLIF(TRIM(review_creation_date), '')),
    TRY_CONVERT(DATETIME2, NULLIF(TRIM(review_answer_timestamp), ''))
FROM dbo.stg_order_reviews;
GO

-- ---------------------------------------------------------------------
-- products  (several numeric columns blank when category is blank)
-- ---------------------------------------------------------------------
IF OBJECT_ID('dbo.stg_products', 'U') IS NOT NULL DROP TABLE dbo.stg_products;
CREATE TABLE dbo.stg_products (
    product_id NVARCHAR(MAX),
    product_category_name NVARCHAR(MAX),
    product_name_lenght NVARCHAR(MAX),
    product_description_lenght NVARCHAR(MAX),
    product_photos_qty NVARCHAR(MAX),
    product_weight_g NVARCHAR(MAX),
    product_length_cm NVARCHAR(MAX),
    product_height_cm NVARCHAR(MAX),
    product_width_cm NVARCHAR(MAX)
);
GO

BULK INSERT dbo.stg_products
FROM '$(DATASET_PATH)\olist_products_dataset.csv'
WITH (
    FORMAT = 'CSV',
    FIRSTROW = 2,
    FIELDQUOTE = '"',
    FIELDTERMINATOR = ',',
    ROWTERMINATOR = '0x0a',
    CODEPAGE = '65001',
    TABLOCK
);
GO

INSERT INTO dbo.raw_products
    (product_id, product_category_name, product_name_lenght,
     product_description_lenght, product_photos_qty, product_weight_g,
     product_length_cm, product_height_cm, product_width_cm)
SELECT
    NULLIF(TRIM(product_id), ''),
    NULLIF(TRIM(product_category_name), ''),
    TRY_CONVERT(SMALLINT, NULLIF(TRIM(product_name_lenght), '')),
    TRY_CONVERT(SMALLINT, NULLIF(TRIM(product_description_lenght), '')),
    TRY_CONVERT(SMALLINT, NULLIF(TRIM(product_photos_qty), '')),
    TRY_CONVERT(INT, NULLIF(TRIM(product_weight_g), '')),
    TRY_CONVERT(INT, NULLIF(TRIM(product_length_cm), '')),
    TRY_CONVERT(INT, NULLIF(TRIM(product_height_cm), '')),
    TRY_CONVERT(INT, NULLIF(TRIM(product_width_cm), ''))
FROM dbo.stg_products;
GO

-- ---------------------------------------------------------------------
-- geolocation  (large file — ~1M rows, load may take a while)
-- ---------------------------------------------------------------------
IF OBJECT_ID('dbo.stg_geolocation', 'U') IS NOT NULL DROP TABLE dbo.stg_geolocation;
CREATE TABLE dbo.stg_geolocation (
    geolocation_zip_code_prefix NVARCHAR(MAX),
    geolocation_lat NVARCHAR(MAX),
    geolocation_lng NVARCHAR(MAX),
    geolocation_city NVARCHAR(MAX),
    geolocation_state NVARCHAR(MAX)
);
GO

BULK INSERT dbo.stg_geolocation
FROM '$(DATASET_PATH)\olist_geolocation_dataset.csv'
WITH (
    FORMAT = 'CSV',
    FIRSTROW = 2,
    FIELDQUOTE = '"',
    FIELDTERMINATOR = ',',
    ROWTERMINATOR = '0x0a',
    CODEPAGE = '65001',
    TABLOCK
);
GO

INSERT INTO dbo.raw_geolocation
    (geolocation_zip_code_prefix, geolocation_lat, geolocation_lng,
     geolocation_city, geolocation_state)
SELECT
    TRY_CONVERT(INT, NULLIF(TRIM(geolocation_zip_code_prefix), '')),
    TRY_CONVERT(DECIMAL(9,6), NULLIF(TRIM(geolocation_lat), '')),
    TRY_CONVERT(DECIMAL(9,6), NULLIF(TRIM(geolocation_lng), '')),
    NULLIF(TRIM(geolocation_city), ''),
    NULLIF(TRIM(geolocation_state), '')
FROM dbo.stg_geolocation;
GO

-- ---------------------------------------------------------------------
-- Final row-count validation
-- ---------------------------------------------------------------------
SELECT 'raw_customers' AS table_name, COUNT(*) AS row_count FROM dbo.raw_customers
UNION ALL
SELECT 'raw_orders', COUNT(*) FROM dbo.raw_orders
UNION ALL
SELECT 'raw_order_reviews', COUNT(*) FROM dbo.raw_order_reviews
UNION ALL
SELECT 'raw_products', COUNT(*) FROM dbo.raw_products
UNION ALL
SELECT 'raw_geolocation', COUNT(*) FROM dbo.raw_geolocation;
GO

-- ---------------------------------------------------------------------
-- Clean up staging tables
-- ---------------------------------------------------------------------
DROP TABLE IF EXISTS dbo.stg_customers;
DROP TABLE IF EXISTS dbo.stg_orders;
DROP TABLE IF EXISTS dbo.stg_order_reviews;
DROP TABLE IF EXISTS dbo.stg_products;
DROP TABLE IF EXISTS dbo.stg_geolocation;
GO
