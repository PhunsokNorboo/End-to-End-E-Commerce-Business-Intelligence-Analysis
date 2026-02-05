-- 03_business_queries.sql
-- Business intelligence queries and analytics

-- =============================================================================
-- OPERATIONAL EFFICIENCY QUERIES
-- =============================================================================

-- -----------------------------------------------------------------------------
-- Query 1: Average Actual vs Estimated Delivery Time + Late Delivery Percentage
-- -----------------------------------------------------------------------------
-- Calculates delivery performance metrics for delivered orders:
-- - Average actual delivery days (from purchase to delivery)
-- - Average estimated delivery days
-- - Late delivery percentage (orders delivered after estimated date)
-- -----------------------------------------------------------------------------

SELECT
    COUNT(*) AS total_delivered_orders,
    ROUND(AVG(delivery_days), 2) AS avg_actual_delivery_days,
    ROUND(AVG(estimated_days), 2) AS avg_estimated_delivery_days,
    ROUND(AVG(delivery_delta), 2) AS avg_delivery_delta_days,
    ROUND(100.0 * SUM(is_late) / COUNT(*), 2) AS late_delivery_percentage
FROM (
    SELECT
        order_id,
        julianday(order_delivered_customer_date) - julianday(order_purchase_timestamp) AS delivery_days,
        julianday(order_estimated_delivery_date) - julianday(order_purchase_timestamp) AS estimated_days,
        julianday(order_delivered_customer_date) - julianday(order_estimated_delivery_date) AS delivery_delta,
        CASE
            WHEN julianday(order_delivered_customer_date) > julianday(order_estimated_delivery_date) THEN 1
            ELSE 0
        END AS is_late
    FROM orders
    WHERE order_status = 'delivered'
      AND order_delivered_customer_date IS NOT NULL
      AND order_purchase_timestamp IS NOT NULL
      AND order_estimated_delivery_date IS NOT NULL
) delivery_metrics;


-- -----------------------------------------------------------------------------
-- Query 2: Freight-to-Price Ratio by Product Category
-- -----------------------------------------------------------------------------
-- Identifies categories with highest logistics cost burden by calculating
-- the average freight-to-price ratio. High ratios indicate categories where
-- shipping costs consume a larger portion of the product value.
-- -----------------------------------------------------------------------------

SELECT
    COALESCE(pct.product_category_name_english, p.product_category_name, 'Unknown') AS category,
    COUNT(*) AS total_items,
    ROUND(AVG(oi.price), 2) AS avg_price,
    ROUND(AVG(oi.freight_value), 2) AS avg_freight,
    ROUND(AVG(oi.freight_value / NULLIF(oi.price, 0)), 4) AS avg_freight_ratio,
    ROUND(100.0 * AVG(oi.freight_value / NULLIF(oi.price, 0)), 2) AS freight_as_pct_of_price
FROM order_items oi
JOIN products p ON oi.product_id = p.product_id
LEFT JOIN product_category_translation pct ON p.product_category_name = pct.product_category_name
WHERE oi.price > 0
GROUP BY COALESCE(pct.product_category_name_english, p.product_category_name, 'Unknown')
ORDER BY avg_freight_ratio DESC;


-- -----------------------------------------------------------------------------
-- Query 3: Delivery Performance by Customer State
-- -----------------------------------------------------------------------------
-- Analyzes delivery performance across Brazilian states to identify
-- geographic logistics challenges. North/Northeast Brazil typically shows
-- longer delivery times and higher late delivery rates due to infrastructure.
-- -----------------------------------------------------------------------------

SELECT
    c.customer_state,
    COUNT(*) AS total_orders,
    ROUND(AVG(julianday(o.order_delivered_customer_date) - julianday(o.order_purchase_timestamp)), 2) AS avg_delivery_days,
    ROUND(100.0 * SUM(
        CASE
            WHEN julianday(o.order_delivered_customer_date) > julianday(o.order_estimated_delivery_date) THEN 1
            ELSE 0
        END
    ) / COUNT(*), 2) AS late_delivery_percentage,
    ROUND(AVG(julianday(o.order_delivered_customer_date) - julianday(o.order_estimated_delivery_date)), 2) AS avg_delivery_delta_days
FROM orders o
JOIN customers c ON o.customer_id = c.customer_id
WHERE o.order_status = 'delivered'
  AND o.order_delivered_customer_date IS NOT NULL
  AND o.order_purchase_timestamp IS NOT NULL
  AND o.order_estimated_delivery_date IS NOT NULL
GROUP BY c.customer_state
ORDER BY late_delivery_percentage DESC;


-- =============================================================================
-- CUSTOMER SATISFACTION ANALYSIS
-- =============================================================================

-- -----------------------------------------------------------------------------
-- Query 4: Review Score Distribution
-- Shows count and percentage breakdown by review score (1-5)
-- Highlights the ratio of 1-star to 5-star reviews as a satisfaction indicator
-- -----------------------------------------------------------------------------
SELECT
    review_score,
    COUNT(*) AS review_count,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER(), 2) AS percentage,
    ROUND(COUNT(*) * 1.0 / (SELECT COUNT(*) FROM order_reviews WHERE review_score = 5), 2) AS ratio_to_5star
FROM order_reviews
WHERE review_score IS NOT NULL
GROUP BY review_score
ORDER BY review_score;

-- Overall satisfaction metrics
SELECT
    COUNT(*) AS total_reviews,
    ROUND(AVG(review_score), 2) AS avg_review_score,
    SUM(CASE WHEN review_score >= 4 THEN 1 ELSE 0 END) AS satisfied_count,
    ROUND(SUM(CASE WHEN review_score >= 4 THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 2) AS satisfaction_rate_pct,
    SUM(CASE WHEN review_score = 1 THEN 1 ELSE 0 END) AS one_star_count,
    SUM(CASE WHEN review_score = 5 THEN 1 ELSE 0 END) AS five_star_count,
    ROUND(SUM(CASE WHEN review_score = 5 THEN 1 ELSE 0 END) * 1.0 /
          NULLIF(SUM(CASE WHEN review_score = 1 THEN 1 ELSE 0 END), 0), 2) AS five_to_one_star_ratio
FROM order_reviews
WHERE review_score IS NOT NULL;


-- -----------------------------------------------------------------------------
-- Query 5: Product Categories with Lowest Average Review Scores
-- Identifies categories needing improvement based on customer feedback
-- Filtered to categories with >50 reviews for statistical significance
-- -----------------------------------------------------------------------------
SELECT
    COALESCE(pct.product_category_name_english, p.product_category_name, 'Unknown') AS category_english,
    COUNT(DISTINCT r.review_id) AS review_count,
    ROUND(AVG(r.review_score), 2) AS avg_review_score,
    ROUND(AVG(r.review_score) - (SELECT AVG(review_score) FROM order_reviews), 2) AS vs_overall_avg,
    SUM(CASE WHEN r.review_score <= 2 THEN 1 ELSE 0 END) AS low_score_count,
    ROUND(SUM(CASE WHEN r.review_score <= 2 THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 2) AS low_score_pct
FROM order_reviews r
JOIN orders o ON r.order_id = o.order_id
JOIN order_items oi ON o.order_id = oi.order_id
JOIN products p ON oi.product_id = p.product_id
LEFT JOIN product_category_translation pct ON p.product_category_name = pct.product_category_name
WHERE r.review_score IS NOT NULL
GROUP BY COALESCE(pct.product_category_name_english, p.product_category_name, 'Unknown')
HAVING COUNT(DISTINCT r.review_id) > 50
ORDER BY avg_review_score ASC
LIMIT 20;


-- -----------------------------------------------------------------------------
-- Query 6: Delivery Delay vs Review Score Analysis
-- Quantifies the impact of delivery performance on customer satisfaction
-- KEY INSIGHT: Late deliveries significantly reduce review scores
-- -----------------------------------------------------------------------------
WITH delivery_analysis AS (
    SELECT
        o.order_id,
        r.review_score,
        DATE(o.order_delivered_customer_date) AS delivered_date,
        DATE(o.order_estimated_delivery_date) AS estimated_date,
        JULIANDAY(o.order_delivered_customer_date) - JULIANDAY(o.order_estimated_delivery_date) AS delivery_delta_days
    FROM orders o
    JOIN order_reviews r ON o.order_id = r.order_id
    WHERE o.order_delivered_customer_date IS NOT NULL
      AND o.order_estimated_delivery_date IS NOT NULL
      AND r.review_score IS NOT NULL
      AND o.order_status = 'delivered'
)
SELECT
    CASE
        WHEN delivery_delta_days < -3 THEN '1. Early (>3 days early)'
        WHEN delivery_delta_days BETWEEN -3 AND 3 THEN '2. On-time (-3 to +3 days)'
        WHEN delivery_delta_days BETWEEN 4 AND 10 THEN '3. Late (4-10 days)'
        ELSE '4. Very Late (>10 days)'
    END AS delivery_bucket,
    COUNT(*) AS order_count,
    ROUND(AVG(review_score), 2) AS avg_review_score,
    ROUND(AVG(delivery_delta_days), 1) AS avg_delay_days,
    SUM(CASE WHEN review_score = 5 THEN 1 ELSE 0 END) AS five_star_count,
    SUM(CASE WHEN review_score = 1 THEN 1 ELSE 0 END) AS one_star_count,
    ROUND(SUM(CASE WHEN review_score <= 2 THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 2) AS low_score_pct
FROM delivery_analysis
GROUP BY delivery_bucket
ORDER BY delivery_bucket;

-- Detailed stats: Compare on-time vs very late directly
WITH delivery_analysis AS (
    SELECT
        o.order_id,
        r.review_score,
        JULIANDAY(o.order_delivered_customer_date) - JULIANDAY(o.order_estimated_delivery_date) AS delivery_delta_days
    FROM orders o
    JOIN order_reviews r ON o.order_id = r.order_id
    WHERE o.order_delivered_customer_date IS NOT NULL
      AND o.order_estimated_delivery_date IS NOT NULL
      AND r.review_score IS NOT NULL
      AND o.order_status = 'delivered'
)
SELECT
    'Business Impact Summary' AS metric,
    (SELECT ROUND(AVG(review_score), 2) FROM delivery_analysis WHERE delivery_delta_days BETWEEN -3 AND 3) AS ontime_avg_score,
    (SELECT ROUND(AVG(review_score), 2) FROM delivery_analysis WHERE delivery_delta_days > 10) AS very_late_avg_score,
    (SELECT ROUND(AVG(review_score), 2) FROM delivery_analysis WHERE delivery_delta_days BETWEEN -3 AND 3) -
    (SELECT ROUND(AVG(review_score), 2) FROM delivery_analysis WHERE delivery_delta_days > 10) AS score_difference,
    (SELECT COUNT(*) FROM delivery_analysis WHERE delivery_delta_days > 10) AS very_late_order_count;


-- =============================================================================
-- SELLER PERFORMANCE ANALYSIS
-- =============================================================================

-- -----------------------------------------------------------------------------
-- Query 7: Top 10 Sellers by Revenue and Order Count
-- -----------------------------------------------------------------------------
-- Joins order_items with sellers to calculate revenue metrics per seller.
-- Shows total revenue, order count, and average order value to identify
-- top-performing sellers on the marketplace.
-- -----------------------------------------------------------------------------

SELECT
    s.seller_id,
    s.seller_city,
    s.seller_state,
    COUNT(DISTINCT oi.order_id) AS order_count,
    ROUND(SUM(oi.price + oi.freight_value), 2) AS total_revenue,
    ROUND(AVG(oi.price + oi.freight_value), 2) AS avg_order_value
FROM order_items oi
JOIN sellers s ON oi.seller_id = s.seller_id
GROUP BY s.seller_id, s.seller_city, s.seller_state
ORDER BY total_revenue DESC
LIMIT 10;


-- -----------------------------------------------------------------------------
-- Query 8: Average Delivery Time by Seller + Late Delivery Flagging
-- -----------------------------------------------------------------------------
-- Calculates actual delivery time (order_delivered_customer_date - order_purchase_timestamp)
-- and flags sellers with >20% late deliveries (delivered after estimated date).
-- Uses HIGH RISK / MODERATE / GOOD performance categories.
-- -----------------------------------------------------------------------------

WITH seller_delivery_stats AS (
    SELECT
        oi.seller_id,
        o.order_id,
        JULIANDAY(o.order_delivered_customer_date) - JULIANDAY(o.order_purchase_timestamp) AS delivery_days,
        CASE
            WHEN o.order_delivered_customer_date > o.order_estimated_delivery_date THEN 1
            ELSE 0
        END AS is_late
    FROM orders o
    JOIN order_items oi ON o.order_id = oi.order_id
    WHERE o.order_status = 'delivered'
      AND o.order_delivered_customer_date IS NOT NULL
)
SELECT
    seller_id,
    COUNT(DISTINCT order_id) AS total_orders,
    ROUND(AVG(delivery_days), 2) AS avg_delivery_days,
    SUM(is_late) AS late_deliveries,
    ROUND(100.0 * SUM(is_late) / COUNT(*), 2) AS late_delivery_pct,
    CASE
        WHEN (100.0 * SUM(is_late) / COUNT(*)) > 20 THEN 'HIGH RISK - >20% Late'
        WHEN (100.0 * SUM(is_late) / COUNT(*)) > 10 THEN 'MODERATE - 10-20% Late'
        ELSE 'GOOD - <10% Late'
    END AS delivery_performance_flag
FROM seller_delivery_stats
GROUP BY seller_id
HAVING COUNT(DISTINCT order_id) >= 10  -- Only sellers with meaningful order volume
ORDER BY late_delivery_pct DESC;


-- -----------------------------------------------------------------------------
-- Query 9: Correlation - Seller Delivery Speed vs Review Scores
-- -----------------------------------------------------------------------------
-- Analyzes relationship between delivery performance and customer satisfaction.
-- Joins orders, order_items, and order_reviews to show avg delivery days
-- and avg review score per seller, ordered to reveal the relationship.
-- -----------------------------------------------------------------------------

WITH seller_metrics AS (
    SELECT
        oi.seller_id,
        ROUND(AVG(JULIANDAY(o.order_delivered_customer_date) - JULIANDAY(o.order_purchase_timestamp)), 2) AS avg_delivery_days,
        ROUND(AVG(r.review_score), 2) AS avg_review_score,
        COUNT(DISTINCT o.order_id) AS order_count
    FROM orders o
    JOIN order_items oi ON o.order_id = oi.order_id
    JOIN order_reviews r ON o.order_id = r.order_id
    WHERE o.order_status = 'delivered'
      AND o.order_delivered_customer_date IS NOT NULL
    GROUP BY oi.seller_id
    HAVING COUNT(DISTINCT o.order_id) >= 10  -- Minimum sample size for reliability
)
SELECT
    seller_id,
    avg_delivery_days,
    avg_review_score,
    order_count,
    -- Categorize sellers by delivery speed
    CASE
        WHEN avg_delivery_days <= 7 THEN 'Fast (<=7 days)'
        WHEN avg_delivery_days <= 14 THEN 'Medium (8-14 days)'
        WHEN avg_delivery_days <= 21 THEN 'Slow (15-21 days)'
        ELSE 'Very Slow (>21 days)'
    END AS delivery_tier
FROM seller_metrics
ORDER BY avg_delivery_days ASC;


-- Summary: Delivery Speed vs Review Score Correlation by Tier
-- Aggregates sellers into delivery tiers to show clear correlation pattern
SELECT
    delivery_tier,
    COUNT(*) AS seller_count,
    ROUND(AVG(avg_review_score), 2) AS tier_avg_review_score,
    ROUND(AVG(avg_delivery_days), 2) AS tier_avg_delivery_days
FROM (
    SELECT
        oi.seller_id,
        AVG(JULIANDAY(o.order_delivered_customer_date) - JULIANDAY(o.order_purchase_timestamp)) AS avg_delivery_days,
        AVG(r.review_score) AS avg_review_score,
        CASE
            WHEN AVG(JULIANDAY(o.order_delivered_customer_date) - JULIANDAY(o.order_purchase_timestamp)) <= 7 THEN 'Fast (<=7 days)'
            WHEN AVG(JULIANDAY(o.order_delivered_customer_date) - JULIANDAY(o.order_purchase_timestamp)) <= 14 THEN 'Medium (8-14 days)'
            WHEN AVG(JULIANDAY(o.order_delivered_customer_date) - JULIANDAY(o.order_purchase_timestamp)) <= 21 THEN 'Slow (15-21 days)'
            ELSE 'Very Slow (>21 days)'
        END AS delivery_tier
    FROM orders o
    JOIN order_items oi ON o.order_id = oi.order_id
    JOIN order_reviews r ON o.order_id = r.order_id
    WHERE o.order_status = 'delivered'
      AND o.order_delivered_customer_date IS NOT NULL
    GROUP BY oi.seller_id
    HAVING COUNT(DISTINCT o.order_id) >= 10
) seller_summary
GROUP BY delivery_tier
ORDER BY tier_avg_delivery_days ASC;


-- -----------------------------------------------------------------------------
-- Query 10: Revenue Concentration (Pareto Analysis)
-- -----------------------------------------------------------------------------
-- Analyzes if top 20% of sellers drive 80% of revenue (80/20 rule).
-- Uses PERCENT_RANK and SUM OVER (ORDER BY) window functions to calculate
-- cumulative revenue percentages for each seller ranked by revenue.
-- -----------------------------------------------------------------------------

WITH seller_revenue AS (
    SELECT
        oi.seller_id,
        SUM(oi.price + oi.freight_value) AS total_revenue
    FROM order_items oi
    GROUP BY oi.seller_id
),
ranked_sellers AS (
    SELECT
        seller_id,
        total_revenue,
        SUM(total_revenue) OVER (ORDER BY total_revenue DESC) AS cumulative_revenue,
        SUM(total_revenue) OVER () AS grand_total_revenue,
        ROW_NUMBER() OVER (ORDER BY total_revenue DESC) AS seller_rank,
        COUNT(*) OVER () AS total_sellers,
        PERCENT_RANK() OVER (ORDER BY total_revenue DESC) AS percentile_rank
    FROM seller_revenue
)
SELECT
    seller_id,
    ROUND(total_revenue, 2) AS total_revenue,
    seller_rank,
    ROUND(100.0 * seller_rank / total_sellers, 2) AS seller_percentile,
    ROUND(cumulative_revenue, 2) AS cumulative_revenue,
    ROUND(100.0 * cumulative_revenue / grand_total_revenue, 2) AS cumulative_revenue_pct,
    CASE
        WHEN (100.0 * seller_rank / total_sellers) <= 20 THEN 'Top 20%'
        WHEN (100.0 * seller_rank / total_sellers) <= 50 THEN 'Middle 30%'
        ELSE 'Bottom 50%'
    END AS seller_tier
FROM ranked_sellers
ORDER BY seller_rank;


-- Pareto Summary: Revenue concentration by seller tiers
-- Shows whether the 80/20 rule applies to this marketplace
WITH seller_revenue AS (
    SELECT
        oi.seller_id,
        SUM(oi.price + oi.freight_value) AS total_revenue
    FROM order_items oi
    GROUP BY oi.seller_id
),
ranked_sellers AS (
    SELECT
        seller_id,
        total_revenue,
        ROW_NUMBER() OVER (ORDER BY total_revenue DESC) AS seller_rank,
        COUNT(*) OVER () AS total_sellers
    FROM seller_revenue
),
tiered_sellers AS (
    SELECT
        seller_id,
        total_revenue,
        CASE
            WHEN (100.0 * seller_rank / total_sellers) <= 20 THEN 'Top 20%'
            WHEN (100.0 * seller_rank / total_sellers) <= 50 THEN 'Middle 30%'
            ELSE 'Bottom 50%'
        END AS seller_tier
    FROM ranked_sellers
)
SELECT
    seller_tier,
    COUNT(*) AS seller_count,
    ROUND(SUM(total_revenue), 2) AS tier_revenue,
    ROUND(100.0 * SUM(total_revenue) / (SELECT SUM(total_revenue) FROM seller_revenue), 2) AS revenue_share_pct
FROM tiered_sellers
GROUP BY seller_tier
ORDER BY
    CASE seller_tier
        WHEN 'Top 20%' THEN 1
        WHEN 'Middle 30%' THEN 2
        ELSE 3
    END;


-- =============================================================================
-- CUSTOMER BEHAVIOR QUERIES
-- =============================================================================

-- -----------------------------------------------------------------------------
-- Query 11: Monthly Unique Customers (Growth Tracking)
-- -----------------------------------------------------------------------------
-- Count distinct customer_unique_id per month and show month-over-month growth
-- Uses LAG window function to calculate MoM change
-- IMPORTANT: Uses customer_unique_id (not customer_id) for accurate unique counts
-- -----------------------------------------------------------------------------

WITH monthly_customers AS (
    SELECT
        strftime('%Y-%m', o.order_purchase_timestamp) AS order_month,
        COUNT(DISTINCT c.customer_unique_id) AS unique_customers
    FROM orders o
    JOIN customers c ON o.customer_id = c.customer_id
    WHERE o.order_status != 'canceled'
    GROUP BY strftime('%Y-%m', o.order_purchase_timestamp)
)
SELECT
    order_month,
    unique_customers,
    LAG(unique_customers) OVER (ORDER BY order_month) AS prev_month_customers,
    unique_customers - LAG(unique_customers) OVER (ORDER BY order_month) AS mom_change,
    ROUND(
        (unique_customers - LAG(unique_customers) OVER (ORDER BY order_month)) * 100.0
        / LAG(unique_customers) OVER (ORDER BY order_month),
        2
    ) AS mom_growth_pct
FROM monthly_customers
ORDER BY order_month;


-- -----------------------------------------------------------------------------
-- Query 12: Orders Per Customer Distribution (Frequency Analysis)
-- -----------------------------------------------------------------------------
-- Group customers by their total order count into frequency buckets
-- Shows how many customers fall into each bucket (1, 2, 3, 4, 5+ orders)
-- Useful for identifying repeat purchase behavior and loyalty segmentation
-- -----------------------------------------------------------------------------

WITH customer_order_counts AS (
    SELECT
        c.customer_unique_id,
        COUNT(DISTINCT o.order_id) AS order_count
    FROM customers c
    JOIN orders o ON c.customer_id = o.customer_id
    WHERE o.order_status != 'canceled'
    GROUP BY c.customer_unique_id
),
frequency_buckets AS (
    SELECT
        customer_unique_id,
        CASE
            WHEN order_count = 1 THEN '1 order'
            WHEN order_count = 2 THEN '2 orders'
            WHEN order_count = 3 THEN '3 orders'
            WHEN order_count = 4 THEN '4 orders'
            ELSE '5+ orders'
        END AS frequency_bucket,
        -- For ordering
        CASE
            WHEN order_count = 1 THEN 1
            WHEN order_count = 2 THEN 2
            WHEN order_count = 3 THEN 3
            WHEN order_count = 4 THEN 4
            ELSE 5
        END AS bucket_order
    FROM customer_order_counts
)
SELECT
    frequency_bucket,
    COUNT(*) AS customer_count,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 2) AS percentage
FROM frequency_buckets
GROUP BY frequency_bucket, bucket_order
ORDER BY bucket_order;


-- -----------------------------------------------------------------------------
-- Query 13: Average Time Between 1st and 2nd Order
-- -----------------------------------------------------------------------------
-- For customers with 2+ orders, calculate days between first and second purchase
-- Uses ROW_NUMBER to identify order sequence per customer
-- Key metric for understanding customer re-engagement timing
-- -----------------------------------------------------------------------------

WITH customer_orders AS (
    SELECT
        c.customer_unique_id,
        o.order_id,
        o.order_purchase_timestamp,
        ROW_NUMBER() OVER (
            PARTITION BY c.customer_unique_id
            ORDER BY o.order_purchase_timestamp
        ) AS order_sequence
    FROM customers c
    JOIN orders o ON c.customer_id = o.customer_id
    WHERE o.order_status != 'canceled'
),
first_second_orders AS (
    SELECT
        customer_unique_id,
        MAX(CASE WHEN order_sequence = 1 THEN order_purchase_timestamp END) AS first_order_date,
        MAX(CASE WHEN order_sequence = 2 THEN order_purchase_timestamp END) AS second_order_date
    FROM customer_orders
    WHERE order_sequence <= 2
    GROUP BY customer_unique_id
    HAVING MAX(CASE WHEN order_sequence = 2 THEN 1 ELSE 0 END) = 1
)
SELECT
    COUNT(*) AS customers_with_repeat_orders,
    ROUND(AVG(
        julianday(second_order_date) - julianday(first_order_date)
    ), 1) AS avg_days_between_orders,
    ROUND(MIN(
        julianday(second_order_date) - julianday(first_order_date)
    ), 1) AS min_days,
    ROUND(MAX(
        julianday(second_order_date) - julianday(first_order_date)
    ), 1) AS max_days,
    ROUND(AVG(
        julianday(second_order_date) - julianday(first_order_date)
    ) / 7, 1) AS avg_weeks_between_orders
FROM first_second_orders;


-- -----------------------------------------------------------------------------
-- Query 14: Customer Concentration by State + Revenue Per Capita
-- -----------------------------------------------------------------------------
-- Join customers with orders and payments
-- Group by customer_state, show customer count and average revenue per customer
-- Identifies high-value geographic markets for business strategy
-- -----------------------------------------------------------------------------

WITH customer_revenue AS (
    SELECT
        c.customer_unique_id,
        c.customer_state,
        SUM(p.payment_value) AS total_revenue
    FROM customers c
    JOIN orders o ON c.customer_id = o.customer_id
    JOIN order_payments p ON o.order_id = p.order_id
    WHERE o.order_status != 'canceled'
    GROUP BY c.customer_unique_id, c.customer_state
)
SELECT
    customer_state,
    COUNT(DISTINCT customer_unique_id) AS customer_count,
    ROUND(SUM(total_revenue), 2) AS total_state_revenue,
    ROUND(AVG(total_revenue), 2) AS avg_revenue_per_customer,
    ROUND(COUNT(DISTINCT customer_unique_id) * 100.0 / SUM(COUNT(DISTINCT customer_unique_id)) OVER (), 2) AS pct_of_total_customers,
    ROUND(SUM(total_revenue) * 100.0 / SUM(SUM(total_revenue)) OVER (), 2) AS pct_of_total_revenue
FROM customer_revenue
GROUP BY customer_state
ORDER BY customer_count DESC;


-- -----------------------------------------------------------------------------
-- Query 15: Monthly Cohort Retention Table (KEY QUERY)
-- -----------------------------------------------------------------------------
-- Group customers by first purchase month (cohort_month)
-- For each cohort, calculate % who returned in month 1, 2, 3...
-- Uses CTEs and window functions extensively
-- This is a critical metric for understanding customer lifetime value
-- -----------------------------------------------------------------------------

WITH customer_first_purchase AS (
    -- Identify each customer's cohort (first purchase month)
    SELECT
        c.customer_unique_id,
        MIN(strftime('%Y-%m', o.order_purchase_timestamp)) AS cohort_month
    FROM customers c
    JOIN orders o ON c.customer_id = o.customer_id
    WHERE o.order_status != 'canceled'
    GROUP BY c.customer_unique_id
),
customer_activity AS (
    -- Get all months each customer was active
    SELECT DISTINCT
        c.customer_unique_id,
        strftime('%Y-%m', o.order_purchase_timestamp) AS activity_month
    FROM customers c
    JOIN orders o ON c.customer_id = o.customer_id
    WHERE o.order_status != 'canceled'
),
cohort_activity AS (
    -- Join to get cohort + activity month + calculate months since cohort
    SELECT
        cfp.customer_unique_id,
        cfp.cohort_month,
        ca.activity_month,
        -- Calculate months difference: (year_diff * 12) + month_diff
        (CAST(strftime('%Y', ca.activity_month || '-01') AS INTEGER) -
         CAST(strftime('%Y', cfp.cohort_month || '-01') AS INTEGER)) * 12 +
        (CAST(strftime('%m', ca.activity_month || '-01') AS INTEGER) -
         CAST(strftime('%m', cfp.cohort_month || '-01') AS INTEGER)) AS months_since_cohort
    FROM customer_first_purchase cfp
    JOIN customer_activity ca ON cfp.customer_unique_id = ca.customer_unique_id
),
cohort_sizes AS (
    -- Count customers in each cohort (month 0)
    SELECT
        cohort_month,
        COUNT(DISTINCT customer_unique_id) AS cohort_size
    FROM customer_first_purchase
    GROUP BY cohort_month
),
retention_counts AS (
    -- Count active customers per cohort per month
    SELECT
        cohort_month,
        months_since_cohort,
        COUNT(DISTINCT customer_unique_id) AS active_customers
    FROM cohort_activity
    GROUP BY cohort_month, months_since_cohort
)
SELECT
    rc.cohort_month,
    cs.cohort_size,
    rc.months_since_cohort,
    rc.active_customers,
    ROUND(rc.active_customers * 100.0 / cs.cohort_size, 2) AS retention_pct
FROM retention_counts rc
JOIN cohort_sizes cs ON rc.cohort_month = cs.cohort_month
WHERE rc.months_since_cohort <= 12  -- Limit to first 12 months for readability
ORDER BY rc.cohort_month, rc.months_since_cohort;


-- -----------------------------------------------------------------------------
-- Query 15b: Cohort Retention Pivot Table (Alternative View)
-- -----------------------------------------------------------------------------
-- Same cohort retention data but pivoted for easier visualization
-- Shows retention % for months 0-6 in columns
-- Ideal for exporting to spreadsheet or dashboard
-- -----------------------------------------------------------------------------

WITH customer_first_purchase AS (
    SELECT
        c.customer_unique_id,
        MIN(strftime('%Y-%m', o.order_purchase_timestamp)) AS cohort_month
    FROM customers c
    JOIN orders o ON c.customer_id = o.customer_id
    WHERE o.order_status != 'canceled'
    GROUP BY c.customer_unique_id
),
customer_activity AS (
    SELECT DISTINCT
        c.customer_unique_id,
        strftime('%Y-%m', o.order_purchase_timestamp) AS activity_month
    FROM customers c
    JOIN orders o ON c.customer_id = o.customer_id
    WHERE o.order_status != 'canceled'
),
cohort_activity AS (
    SELECT
        cfp.customer_unique_id,
        cfp.cohort_month,
        ca.activity_month,
        (CAST(strftime('%Y', ca.activity_month || '-01') AS INTEGER) -
         CAST(strftime('%Y', cfp.cohort_month || '-01') AS INTEGER)) * 12 +
        (CAST(strftime('%m', ca.activity_month || '-01') AS INTEGER) -
         CAST(strftime('%m', cfp.cohort_month || '-01') AS INTEGER)) AS months_since_cohort
    FROM customer_first_purchase cfp
    JOIN customer_activity ca ON cfp.customer_unique_id = ca.customer_unique_id
),
cohort_sizes AS (
    SELECT
        cohort_month,
        COUNT(DISTINCT customer_unique_id) AS cohort_size
    FROM customer_first_purchase
    GROUP BY cohort_month
)
SELECT
    ca.cohort_month,
    cs.cohort_size,
    ROUND(COUNT(DISTINCT CASE WHEN months_since_cohort = 0 THEN ca.customer_unique_id END) * 100.0 / cs.cohort_size, 1) AS month_0,
    ROUND(COUNT(DISTINCT CASE WHEN months_since_cohort = 1 THEN ca.customer_unique_id END) * 100.0 / cs.cohort_size, 1) AS month_1,
    ROUND(COUNT(DISTINCT CASE WHEN months_since_cohort = 2 THEN ca.customer_unique_id END) * 100.0 / cs.cohort_size, 1) AS month_2,
    ROUND(COUNT(DISTINCT CASE WHEN months_since_cohort = 3 THEN ca.customer_unique_id END) * 100.0 / cs.cohort_size, 1) AS month_3,
    ROUND(COUNT(DISTINCT CASE WHEN months_since_cohort = 4 THEN ca.customer_unique_id END) * 100.0 / cs.cohort_size, 1) AS month_4,
    ROUND(COUNT(DISTINCT CASE WHEN months_since_cohort = 5 THEN ca.customer_unique_id END) * 100.0 / cs.cohort_size, 1) AS month_5,
    ROUND(COUNT(DISTINCT CASE WHEN months_since_cohort = 6 THEN ca.customer_unique_id END) * 100.0 / cs.cohort_size, 1) AS month_6
FROM cohort_activity ca
JOIN cohort_sizes cs ON ca.cohort_month = cs.cohort_month
GROUP BY ca.cohort_month, cs.cohort_size
ORDER BY ca.cohort_month;
