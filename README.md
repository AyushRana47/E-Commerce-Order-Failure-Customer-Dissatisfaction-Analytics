# E-Commerce-Order-Failure-Customer-Dissatisfaction-Analytics


An end-to-end **Business Analytics project** analyzing customer dissatisfaction and order-failure patterns in the Olist Brazilian E-Commerce dataset using **SQL, Python, GenAI, and Power BI**.

The project focuses on identifying **why customers are dissatisfied**, converting unstructured review text into structured root-cause data using GenAI, and transforming those insights into actionable operational analysis.

> **Important:** The Olist dataset does not contain a dedicated return/refund transaction field. Therefore, this project analyzes **order failures and customer dissatisfaction signals** rather than claiming to perform true returns analysis.

---

## Business Problem

E-commerce businesses receive large volumes of customer feedback, but the underlying reasons for dissatisfaction are often buried inside unstructured review text.

Simply looking at review scores can show **that** customers are unhappy, but not necessarily **why**.

This project addresses the problem by combining:

* Order and delivery analysis
* Customer dissatisfaction analysis
* Unstructured review analysis
* GenAI-based root-cause classification
* SQL-based analytical modeling
* Power BI visualization
* Business prioritization

### Business Objective

Identify the major operational factors driving customer dissatisfaction and provide a structured analytical framework for prioritizing improvement opportunities.

---

## Project Approach

```text
Olist Raw Dataset
       ↓
SQL Data Cleaning & Analysis
       ↓
Review / Dissatisfaction Analysis
       ↓
GenAI Classification of Review Text
       ↓
Structured Root-Cause Dataset
       ↓
Master Analytical Table
       ↓
Root-Cause & Operational Analysis
       ↓
Power BI Dashboard
       ↓
Business Recommendations
```

---

## Dataset

**Source:** Olist Brazilian E-Commerce Public Dataset

The dataset contains information related to:

* Customers
* Orders
* Order reviews
* Products
* Delivery timestamps
* Customer locations
* Review scores
* Customer review text

The review dataset provides both structured review scores and unstructured customer comments, making it suitable for combining traditional analytics with GenAI-based text classification.

---

## Key Business Definitions

### Customer Dissatisfaction

A review score of **1 or 2** is treated as a customer dissatisfaction indicator.

### Operational Failure

Operational failures are analyzed separately from dissatisfaction and include signals such as:

* Late delivery
* Delivery handling issues
* Product-related problems
* Missing items
* Incorrect products
* Damaged packaging
* Other customer-reported order issues

This distinction prevents the analysis from assuming that every operational issue automatically results in customer dissatisfaction.

---

# SQL Analytics Layer

SQL Server is used as the core analytical layer.

The SQL workflow includes:

* Data cleaning and preparation
* Order-level analysis
* Review-level analysis
* Delivery performance analysis
* Customer dissatisfaction identification
* Review text preparation
* GenAI classification data preparation
* Creation of a master analytical table

The final master table is driven by the **classified review dataset**, ensuring that the analytical dataset contains only reviews that were processed through the GenAI classification layer.

---

# GenAI Root-Cause Classification

Customer reviews contain unstructured text, including Portuguese-language feedback, making simple keyword-based classification unreliable for many cases.

GenAI is used to convert the review text into a structured root-cause category.

### Classification Taxonomy

Reviews are classified into controlled categories:

```text
LATE_DELIVERY
PRODUCT_QUALITY
PRODUCT_NOT_AS_DESCRIBED
WRONG_PRODUCT
MISSING_ITEM
SIZE_OR_FIT
DAMAGED_PRODUCT
DAMAGED_PACKAGING
SELLER_SERVICE
PAYMENT_ISSUE
DELIVERY_HANDLING
OTHER
NO_CLEAR_ISSUE
```

### Example

**Customer Review:**

> "Recebi o produto errado. Solicitei a troca."

**GenAI Classification:**

```text
Primary Cause: WRONG_PRODUCT
```

Another example:

**Customer Review:**

> "A embalagem chegou toda danificada."

**GenAI Classification:**

```text
Primary Cause: DAMAGED_PACKAGING
```

This transforms unstructured customer feedback into structured data that can be aggregated and analyzed using SQL and Power BI.

---

# Analytical Framework

The classified reviews are combined with order and customer information to create the master analytical dataset.

Key analytical dimensions include:

### Root Cause

* Which problems occur most frequently?
* Which causes contribute most to dissatisfaction?

### Delivery Performance

* How frequently are orders delivered late?
* How does delivery delay relate to customer dissatisfaction?
* Which root causes are associated with delivery problems?

### Customer Analysis

* Which customer segments or locations show higher dissatisfaction?
* Where are specific operational problems concentrated?

### Prioritization

The project moves beyond simply ranking problems by frequency.

The final analysis is designed to identify issues that should receive the greatest operational attention based on factors such as:

```text
Problem Frequency
        +
Customer Impact
        +
Operational Impact
        ↓
Priority
```

---

# Power BI Dashboard

The final Power BI dashboard will convert the analytical results into an interactive business-facing reporting layer.

### Planned Dashboard Structure

#### 1. Executive Overview

High-level KPIs covering:

* Total classified reviews
* Dissatisfaction rate
* Major root causes
* Delivery performance
* Key operational indicators

#### 2. Root-Cause Analysis

Interactive analysis of:

* Root-cause distribution
* Review scores
* Delivery performance
* Customer-level patterns
* Root cause trends and relationships

#### 3. Action Prioritization

A decision-support view highlighting:

* Highest-frequency problems
* Highest-impact problems
* Priority areas
* Operational improvement opportunities

The dashboard is designed for an **Operations Manager / Customer Experience stakeholder**, rather than being purely a technical visualization.

---

# Technology Stack

| Tool                   | Purpose                                               |
| ---------------------- | ----------------------------------------------------- |
| **SQL Server**         | Data cleaning, transformation and analytical modeling |
| **Python**             | EDA, data preparation and GenAI integration           |
| **GenAI / Gemini API** | Unstructured review root-cause classification         |
| **Pandas**             | Data manipulation and processing                      |
| **Power BI**           | Interactive dashboard and business reporting          |
| **Git / GitHub**       | Version control and project documentation             |

---

# Key Business Questions

The project is designed to answer questions such as:

1. What are the primary drivers of customer dissatisfaction?
2. How significant are delivery-related problems?
3. Which root causes occur most frequently?
4. Which operational problems have the greatest customer impact?
5. How does delivery performance relate to customer dissatisfaction?
6. Which problems should operations prioritize first?
7. What corrective actions could address the highest-priority issues?

---

# Business Value

The core value of this project is not simply the use of GenAI.

It demonstrates how a Business Analyst can take:

```text
Unstructured Customer Feedback
            ↓
Structured Business Categories
            ↓
Quantitative Analysis
            ↓
Problem Prioritization
            ↓
Operational Recommendations
```

The GenAI layer makes previously unstructured customer feedback analytically usable, while SQL and Power BI provide the framework for turning that information into business insights and decision support.

---

# Future Enhancements

Potential extensions include:

* Adding seller-level analysis when complete seller/order-item data is available
* Adding product-category analysis through the order-item relationship
* Expanding the GenAI taxonomy
* Adding severity and secondary-cause analysis
* Developing an impact-vs-frequency prioritization matrix
* Adding financial impact scenarios
* Connecting the dashboard to a refreshed analytical pipeline

---

