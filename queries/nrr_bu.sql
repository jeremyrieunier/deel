WITH customers_services_revenue AS (
  SELECT
    month,
    customer_id,
    service_id,
    total_saas_revenue_usd AS current_month_service_revenue,
    LAG(total_saas_revenue_usd) OVER (PARTITION BY customer_id, service_id ORDER BY month) AS previous_month_service_revenue
  FROM cs.customer_monthly_revenue
),

customers_total_revenue AS (
  SELECT 
    month,
    customer_id,
    SUM(current_month_service_revenue) as current_month_total_revenue,
    SUM(previous_month_service_revenue) as previous_month_total_revenue
  FROM customers_services_revenue
  GROUP BY month, customer_id
),

active_customers_services AS (
  SELECT
    csr.month,
    csr.customer_id,
    csr.service_id,
    s.business_unit,
    csr.current_month_service_revenue,
    csr.previous_month_service_revenue
  FROM customers_services_revenue csr
  INNER JOIN customers_total_revenue ctr
    ON csr.customer_id = ctr.customer_id
    AND csr.month = ctr.month
  INNER JOIN cs.dim_service s
    ON csr.service_id = s.id 
  WHERE ctr.previous_month_total_revenue >= 0
    AND ctr.previous_month_total_revenue IS NOT NULL
)

SELECT
  month,
  business_unit,
  SUM(previous_month_service_revenue) AS previous_month_total_revenue,
  SUM(current_month_service_revenue) AS current_month_total_revenue,
  SUM(current_month_service_revenue) /  SUM(previous_month_service_revenue) AS nrr
FROM active_customers_services
GROUP BY month, business_unit
HAVING SUM(previous_month_service_revenue) > 0
ORDER BY month, business_unit