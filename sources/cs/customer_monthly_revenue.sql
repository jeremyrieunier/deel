SELECT
    DATE_ADD(MONTH, INTERVAL 1 DAY) AS month,
    CUSTOMER_ID AS customer_id,
    SERVICE_ID AS service_id,
    CONTRACTS AS contracts,
    TOTAL_SAAS_REVENUE_USD AS total_saas_revenue_usd
FROM cs.customer_monthly_revenue
