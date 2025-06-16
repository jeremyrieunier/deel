WITH customer_monthly_activity AS (
  SELECT 
    month,
    customer_id,
    SUM(contracts) as total_contracts
  FROM cs.customer_monthly_revenue
  GROUP BY month, customer_id
),

customer_activity_with_lag AS (
  SELECT 
    month,
    customer_id,
    total_contracts,
    CASE WHEN total_contracts > 0 THEN 1 ELSE 0 END as is_active,
    LAG(CASE WHEN total_contracts > 0 THEN 1 ELSE 0 END) 
      OVER (PARTITION BY customer_id ORDER BY month) as was_active_previous_month
  FROM customer_monthly_activity
),

monthly_churn_data AS (
  SELECT 
    month,
    SUM(was_active_previous_month) as active_customers_previous_month,
    SUM(CASE WHEN was_active_previous_month = 1 AND is_active = 0 THEN 1 ELSE 0 END) as churned_customers
  FROM customer_activity_with_lag
  WHERE was_active_previous_month IS NOT NULL 
  GROUP BY month
)

SELECT
  month,
  active_customers_previous_month,
  churned_customers,
  churned_customers / active_customers_previous_month AS churn_rate
FROM monthly_churn_data
ORDER BY month