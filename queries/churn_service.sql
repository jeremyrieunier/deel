WITH customer_monthly_activity_service AS (
  SELECT
    month,
    customer_id,
    service_id,
    contracts,
    CASE WHEN contracts > 0 THEN 1 ELSE 0 END AS is_active_service
  FROM cs.customer_monthly_revenue
),

customer_activity_service_with_lag AS (
  SELECT 
    month,
    customer_id,
    service_id,
    contracts,
    is_active_service,
    LAG(is_active_service) OVER (PARTITION BY customer_id, service_id ORDER BY month) AS was_active_previous_month
  FROM customer_monthly_activity_service
),

monthly_service_churn_data AS (
 SELECT 
   month,
   service_id,
   SUM(was_active_previous_month) AS active_customers_previous_month,
   SUM(CASE WHEN was_active_previous_month = 1 AND is_active_service = 0 THEN 1 ELSE 0 END) AS churned_customers
 FROM customer_activity_service_with_lag 
 WHERE was_active_previous_month IS NOT NULL 
  AND month >= '2023-08-01'
 GROUP BY month, service_id
)

SELECT
  m.month,
  m.service_id,
  s.name AS service_name,
  m.active_customers_previous_month,
  m.churned_customers,
  ROUND(m.churned_customers / m.active_customers_previous_month, 4) AS churn_rate
FROM monthly_service_churn_data m
LEFT JOIN cs.dim_service s
  ON m.service_id = s.id
ORDER BY month, service_id