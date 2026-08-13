-- =====================================================================
-- 01. DATABASE SETUP
-- Project: Order Failure & Customer Dissatisfaction Root-Cause Analysis
-- Dataset : Olist Brazilian E-Commerce (partial — see notes in each file)
-- Engine  : SQL Server (SSMS) — T-SQL
-- =====================================================================

IF NOT EXISTS (SELECT 1 FROM sys.databases WHERE name = 'ecommerce_order_failure')
BEGIN
    CREATE DATABASE ecommerce_order_failure;
END
GO

USE ecommerce_order_failure;
GO
