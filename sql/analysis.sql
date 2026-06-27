-- Which product categories generate the most revenue and profit?
SELECT 
    category AS Category,
    sub_category AS Sub_Category,
    ROUND(SUM(sales)::numeric, 2) AS Total_Sales,
    ROUND(SUM(profit)::numeric, 2) AS Total_Profit,
    ROUND(100.0 * SUM(profit) / SUM(sales), 2) AS Profit_Margin_Pct,
    COUNT(*) AS Total_Orders
FROM superstore
GROUP BY category, sub_category
ORDER BY Total_Sales DESC
LIMIT 20;

-- MoM: Sale's dynamic
WITH monthly AS (
    SELECT 
        DATE_TRUNC('month', order_date) AS month,
        SUM(sales) AS total_sales
    FROM superstore
    GROUP BY 1
),
with_lag AS (
    SELECT 
        month,
        total_sales,
        LAG(total_sales) OVER (ORDER BY month) AS prev_month
    FROM monthly
)
SELECT
    month,
    ROUND(total_sales::numeric, 2) AS total_sales,
    ROUND(prev_month::numeric, 2) AS prev_month,
    ROUND((total_sales - prev_month)::numeric, 2) AS delta,
    ROUND(100.0 * (total_sales - prev_month) / prev_month, 2) AS growth_pct
FROM with_lag
ORDER BY month;

-- Retention
WITH unique_orders AS (
    SELECT DISTINCT customer_id, order_id, order_date
    FROM superstore
),
numbered AS (
    SELECT 
        customer_id,
        order_date,
        ROW_NUMBER() OVER (
            PARTITION BY customer_id
            ORDER BY order_date
        ) AS order_num
    FROM unique_orders
)
SELECT 
    COUNT(DISTINCT CASE WHEN order_num >= 2 THEN customer_id END) AS returned,
    COUNT(DISTINCT customer_id) AS total,
    ROUND(100.0 * COUNT(DISTINCT CASE WHEN order_num >= 2 THEN customer_id END) 
          / COUNT(DISTINCT customer_id), 2) AS retention_pct
FROM numbered;

-- Churn
WITH max_date AS (
    SELECT MAX(order_date) AS dataset_end
    FROM superstore
),
last_purchase AS (
    SELECT
        customer_id,
        MAX(order_date) AS last_order_date,
        (SELECT dataset_end FROM max_date) - MAX(order_date) AS days_since_last_order
    FROM superstore
    GROUP BY customer_id
),
segmented AS (
    SELECT
        customer_id,
        last_order_date,
        days_since_last_order,
        CASE
            WHEN days_since_last_order > 90 THEN 'Churned'
            WHEN days_since_last_order > 30 THEN 'At Risk'
            ELSE 'Active'
        END AS status
    FROM last_purchase
)
SELECT
    status,
    COUNT(*) AS customers,
    ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 2) AS pct
FROM segmented
GROUP BY status
ORDER BY customers DESC;

--LTV segment
WITH customer_revenue AS (
    SELECT
        customer_id,
        segment,
        COUNT(DISTINCT order_id) AS total_orders,
        ROUND(SUM(sales)::numeric, 2) AS ltv
    FROM superstore
    GROUP BY customer_id, segment
),
segmented AS (
    SELECT
        customer_id,
        segment,
        total_orders,
        ltv,
        CASE
            WHEN ltv >= 1000 THEN 'High'
            WHEN ltv >= 500 THEN 'Medium'
            ELSE 'Low'
        END AS ltv_segment
    FROM customer_revenue
)
SELECT
    segment AS customer_segment,
    ltv_segment,
    COUNT(*) AS customers,
    ROUND(AVG(ltv)::numeric, 2) AS avg_ltv,
    ROUND(AVG(total_orders)::numeric, 1) AS avg_orders,
    ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 2) AS pct
FROM segmented
GROUP BY segment, ltv_segment
ORDER BY segment, avg_ltv DESC;