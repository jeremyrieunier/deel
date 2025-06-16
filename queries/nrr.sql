WITH monthly_revenue AS (
  SELECT
    month,
    customer_id,
    SUM(total_saas_revenue_usd) AS total_revenue
  FROM cs.customer_monthly_revenue
  GROUP BY month, customer_id
),

monthly_revenue_previous AS (
  SELECT
    month,
    customer_id,
    total_revenue,
    LAG(total_revenue) OVER (PARTITION BY customer_id ORDER BY month) AS previous_month_revenue
  FROM monthly_revenue
),

active_customers AS (
  SELECT
    month,
    customer_id,
    total_revenue AS current_month_revenue,
    previous_month_revenue
  FROM monthly_revenue_previous
  WHERE previous_month_revenue >= 0
    AND previous_month_revenue IS NOT NULL
)

SELECT
  month,
  SUM(previous_month_revenue) AS previous_month_total_revenue,
  SUM(current_month_revenue) AS current_month_total_revenue,
  ROUND(SUM(current_month_revenue) / SUM(previous_month_revenue), 4) AS nrr
FROM active_customers
GROUP BY month
ORDER BY month