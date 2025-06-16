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
    c.region,
    csr.current_month_service_revenue,
    csr.previous_month_service_revenue
  FROM customers_services_revenue csr
  INNER JOIN customers_total_revenue ctr
    ON csr.customer_id = ctr.customer_id
    AND csr.month = ctr.month
  LEFT JOIN cs.dim_customer c
    ON csr.customer_id = c.customer_id
  WHERE ctr.previous_month_total_revenue >= 0
    AND ctr.previous_month_total_revenue IS NOT NULL
)

SELECT
  month,
  region,
  SUM(previous_month_service_revenue) AS previous_month_total_revenue,
  SUM(current_month_service_revenue) AS current_month_total_revenue,
  SUM(current_month_service_revenue) /  SUM(previous_month_service_revenue) AS nrr
FROM active_customers_services
WHERE region IS NOT NULL
GROUP BY month, region
HAVING SUM(previous_month_service_revenue) > 0
ORDER BY month, region