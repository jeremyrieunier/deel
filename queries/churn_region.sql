WITH customer_monthly_activity AS (
  SELECT
    month,
    customer_id,
    SUM(contracts) AS total_contracts
  FROM cs.customer_monthly_revenue
  GROUP BY month, customer_id
),

customer_activity_service_with_lag AS (
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
    customer_id,
    was_active_previous_month,
    CASE WHEN was_active_previous_month = 1 AND is_active = 0 THEN 1 ELSE 0 END as churned
  FROM customer_activity_service_with_lag 
  WHERE was_active_previous_month IS NOT NULL 
    AND month >= '2023-08-01'
)

SELECT
  m.month,
  c.region,
  SUM(m.was_active_previous_month) AS active_customers_previous_month,
  SUM(m.churned) AS churned_customers,
  SUM(m.churned) / SUM(m.was_active_previous_month) AS churn_rate
FROM monthly_churn_data m
LEFT JOIN cs.dim_customer c
  ON m.customer_id = c.customer_id
GROUP BY m.month, c.region
HAVING active_customers_previous_month > 0
ORDER BY m.month, c.region