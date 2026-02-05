-- 02_data_exploration.sql
-- Revenue & Sales Performance Analysis
-- =====================================
-- This file contains SQL queries analyzing revenue trends, product performance,
-- and customer purchasing behavior for the Olist e-commerce marketplace.


-- =============================================================================
-- QUERY 1: Monthly Revenue Trend with Month-over-Month Growth Rate
-- =============================================================================
-- Business Context: Understanding monthly revenue patterns helps identify
-- seasonality, growth trends, and potential anomalies. The MoM growth rate
-- highlights acceleration or deceleration in business performance.
-- Techniques: CTE, Window Function (LAG), Date extraction, Aggregate functions

WITH monthly_revenue AS (
    SELECT
        strftime('%Y-%m', o.order_purchase_timestamp) AS month,
        SUM(op.payment_value) AS total_revenue,
        COUNT(DISTINCT o.order_id) AS total_orders
    FROM orders o
    JOIN order_payments op ON o.order_id = op.order_id
    WHERE o.order_status = 'delivered'
    GROUP BY strftime('%Y-%m', o.order_purchase_timestamp)
)
SELECT
    month,
    total_revenue,
    total_orders,
    LAG(total_revenue) OVER (ORDER BY month) AS prev_month_revenue,
    ROUND(
        (total_revenue - LAG(total_revenue) OVER (ORDER BY month))
        / LAG(total_revenue) OVER (ORDER BY month) * 100,
        2
    ) AS mom_growth_pct
FROM monthly_revenue
ORDER BY month;


-- =============================================================================
-- QUERY 2: Top 10 Product Categories by Total Revenue
-- =============================================================================
-- Business Context: Identifies the highest-grossing product categories to inform
-- inventory decisions, marketing investment, and supplier negotiations.
-- Techniques: Multi-table JOINs, Aggregate functions, COALESCE for null handling

SELECT
    COALESCE(pct.product_category_name_english, 'Uncategorized') AS category_english,
    COUNT(DISTINCT oi.order_id) AS total_orders,
    COUNT(oi.order_item_id) AS items_sold,
    ROUND(SUM(op.payment_value), 2) AS total_revenue,
    ROUND(AVG(oi.price), 2) AS avg_item_price
FROM order_items oi
JOIN orders o ON oi.order_id = o.order_id
JOIN order_payments op ON o.order_id = op.order_id
LEFT JOIN products p ON oi.product_id = p.product_id
LEFT JOIN product_category_translation pct ON p.product_category_name = pct.product_category_name
WHERE o.order_status = 'delivered'
GROUP BY COALESCE(pct.product_category_name_english, 'Uncategorized')
ORDER BY total_revenue DESC
LIMIT 10;


-- =============================================================================
-- QUERY 3: Average Order Value (AOV) by Product Category
-- =============================================================================
-- Business Context: AOV by category reveals which product types drive higher
-- transaction values, guiding cross-sell strategies and category-specific promotions.
-- AOV = Total Revenue / Number of Distinct Orders per Category
-- Techniques: CTE, Multi-table JOINs, Aggregate functions, Window function for ranking

WITH category_metrics AS (
    SELECT
        COALESCE(pct.product_category_name_english, 'Uncategorized') AS category_english,
        COUNT(DISTINCT o.order_id) AS order_count,
        SUM(op.payment_value) AS total_revenue
    FROM order_items oi
    JOIN orders o ON oi.order_id = o.order_id
    JOIN order_payments op ON o.order_id = op.order_id
    LEFT JOIN products p ON oi.product_id = p.product_id
    LEFT JOIN product_category_translation pct ON p.product_category_name = pct.product_category_name
    WHERE o.order_status = 'delivered'
    GROUP BY COALESCE(pct.product_category_name_english, 'Uncategorized')
    HAVING order_count >= 10  -- Filter categories with meaningful sample size
)
SELECT
    category_english,
    order_count,
    ROUND(total_revenue, 2) AS total_revenue,
    ROUND(total_revenue / order_count, 2) AS aov,
    RANK() OVER (ORDER BY total_revenue / order_count DESC) AS aov_rank
FROM category_metrics
ORDER BY aov DESC;


-- =============================================================================
-- QUERY 4: Revenue Breakdown by Payment Method
-- =============================================================================
-- Business Context: Understanding payment preferences helps optimize checkout
-- experience, negotiate better payment processor rates, and identify potential
-- fraud patterns by payment type.
-- Techniques: CTE, Window function (SUM OVER), CASE WHEN, Percentage calculation

WITH payment_totals AS (
    SELECT
        op.payment_type,
        COUNT(DISTINCT op.order_id) AS order_count,
        SUM(op.payment_value) AS revenue
    FROM order_payments op
    JOIN orders o ON op.order_id = o.order_id
    WHERE o.order_status = 'delivered'
    GROUP BY op.payment_type
),
grand_total AS (
    SELECT SUM(revenue) AS total_revenue FROM payment_totals
)
SELECT
    pt.payment_type,
    pt.order_count,
    ROUND(pt.revenue, 2) AS total_revenue,
    ROUND(pt.revenue / gt.total_revenue * 100, 2) AS revenue_pct,
    CASE
        WHEN pt.payment_type = 'credit_card' THEN 'Primary - Installment capable'
        WHEN pt.payment_type = 'boleto' THEN 'Cash equivalent - Bank slip'
        WHEN pt.payment_type = 'voucher' THEN 'Promotional/Gift cards'
        WHEN pt.payment_type = 'debit_card' THEN 'Instant payment'
        ELSE 'Other'
    END AS payment_description
FROM payment_totals pt
CROSS JOIN grand_total gt
ORDER BY pt.revenue DESC;


-- =============================================================================
-- QUERY 5: Revenue Percentage from Repeat vs First-Time Customers
-- =============================================================================
-- Business Context: Repeat customer revenue is a key indicator of customer
-- satisfaction and business sustainability. High repeat revenue suggests strong
-- product-market fit and customer loyalty. First-time vs repeat split informs
-- acquisition vs retention marketing budget allocation.
-- Techniques: Multiple CTEs, CASE WHEN, Window function (SUM OVER), Subquery

WITH customer_orders AS (
    -- Aggregate order data by unique customer
    -- This combines customer info, order count, and total revenue per customer
    SELECT
        c.customer_unique_id,
        COUNT(DISTINCT o.order_id) AS order_count,
        SUM(op.payment_value) AS customer_revenue
    FROM customers c
    JOIN orders o ON c.customer_id = o.customer_id
    JOIN order_payments op ON o.order_id = op.order_id
    WHERE o.order_status = 'delivered'
    GROUP BY c.customer_unique_id
),
customer_segments AS (
    -- Classify customers and their revenue
    SELECT
        customer_unique_id,
        CASE
            WHEN order_count = 1 THEN 'First-Time'
            ELSE 'Repeat'
        END AS customer_segment,
        order_count,
        customer_revenue
    FROM customer_orders
)
SELECT
    customer_segment,
    COUNT(*) AS customer_count,
    SUM(order_count) AS order_count,
    ROUND(SUM(customer_revenue), 2) AS total_revenue,
    ROUND(
        SUM(customer_revenue) / SUM(SUM(customer_revenue)) OVER () * 100,
        2
    ) AS revenue_pct,
    ROUND(SUM(customer_revenue) / COUNT(*), 2) AS revenue_per_customer,
    ROUND(AVG(order_count), 2) AS avg_orders_per_customer
FROM customer_segments
GROUP BY customer_segment
ORDER BY total_revenue DESC;
