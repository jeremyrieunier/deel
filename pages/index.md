---
title: Welcome to Evidence
queries:
  - churn.sql
  - churn_service.sql
  - nrr.sql
  - nrr_bu.sql
  - nrr_region.sql
---

# Monthly Churn Rate Analysis
## Overall Churn Trends

Deel's monthly churn rate has steadily increased from August to December 2023, doubling from 0.13% to 0.27%:

<LineChart 
    data={churn}
    x=month
    y=churn_rate
    yFmt=pct2
/>

<DataTable data={churn} >
  <Column id=month />
  <Column id=active_customers_previous_month />
  <Column id=churned_customers />  
  <Column id=churn_rate fmt=pct2 />
</DataTable>

While absolute churn rates remain low (less than 0.3%), the consistent month-over-month increase is concerning. However, strong customer acquisition (From 12K to 13.7K customers) is offsetting churn impact.

## Service-Level Churn Analysis
Individual Contributor (IC) service represents +93% of total churned customers:
```sql total_churn
SELECT
  service_name,
  SUM(churned_customers) AS total_churned_customers,
  ROUND(SUM(churned_customers) / SUM(SUM(churned_customers)) OVER (), 4) AS percentage_of_total
FROM ${churn_service} 
GROUP BY service_name
ORDER BY total_churned_customers DESC
```

<BarChart 
    data={total_churn}
    x=service_name
    y=total_churned_customers
    chartAreaHeight=350
/>

```sql ic_churn
SELECT *
FROM ${churn_service}
WHERE service_name = 'IC'
```
IC (Individual Contributor) churn rate increased every month except November (slight plateau):

<LineChart 
    data={ic_churn}
    x=month
    y=churn_rate
    yFmt=pct2
/>

- August to September: +30% increase (0.33% to 0.43%)
- September to October: +28% increase (0.43% to 0.55%)
- November to December: +11% increase (0.57% to 0.63%)

In term of impact:

- Total IC customers churned: 206 over 5 months
- December alone: 52 customers (highest monthly loss)
- Customer base growth: Despite churn, IC customer base grew from 7,885 to 8,251

<Details title="SQL query used for the churn analysis">

```sql
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
```

</Details>


# Net Revenue Retention Analysis
## Overall NRR Performance

Deel maintains healthy revenue expansion from existing customers (>100% NRR) but shows a concerning downward trend throughout Q4 2023:
<LineChart 
    data={nrr}
    x=month
    y=nrr
    yFmt=pct2
    yMax=1.04
    yMin=0.96
    chartAreaHeight=350
/>


<Details title="SQL query used for the overall NRR analysis">

```sql
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
```

</Details>

## Business Unit NRR

Both major business units (Contractor and EOR) show expansion, but with different patterns and downward trends:
<LineChart 
    data={nrr_bu}
    x=month
    y=nrr
    yFmt=pct2
    yMax=1.08
    yMin=0.96
    series=business_unit
    chartAreaHeight=350
/>

- The Contractor business unit is volatile. Exceptional August (107%), near-flat September (100.84%), then stabilized around 102.5%:
- On the other hand the EOR business units has a steady decline from 102.40% to 101.57%. It is more predictable but consistently weakening.

<Details title="SQL query used for the Business Unit NRR analysis">

```sql
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
```

</Details>

## Regional NRR Patterns
Despite being the largest region, AMS (Americas) performances are on the decline with a barely positive expansion:

```sql nrr_ams
SELECT *
FROM ${nrr_region}
WHERE region = 'AMS'
```
<LineChart 
    data={nrr_ams}
    x=month
    y=nrr
    yFmt=pct2
    yMax=1.06
    yMin=0.96
    chartAreaHeight=350
/>

This trend is also presents in the EMEA region, with a gradual decline:

```sql nrr_emea
SELECT *
FROM ${nrr_region}
WHERE region = 'EMEA'
```
<LineChart 
    data={nrr_emea}
    x=month
    y=nrr
    yFmt=pct2
    yMax=1.06
    yMin=0.96
    chartAreaHeight=350
/>

On the other hand, APAC is the only region with accelerating expansion:

```sql nrr_apac
SELECT *
FROM ${nrr_region}
WHERE region = 'APAC'
```
<LineChart 
    data={nrr_apac}
    x=month
    y=nrr
    yFmt=pct2
    yMax=1.06
    yMin=0.96
    chartAreaHeight=350
/>

<Details title="SQL query used for the Region NRR analysis">

```sql
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
```

</Details>

# Strategic Implications
Deel faces retention pressure across all dimensions:

- Customer Churn: IC service losing customers
- Revenue Expansion: Slowing growth from existing customers
- Geographic Concentration: AMS (primary market) driving both issues

APAC resilient performance suggests the retention issues are market-specific rather than product-wide, pointing to economic or competitive factors in the US/Americas market.

# Hypothesis Proposal
Economic conditions in Q4 2023 (rising interest rates, budget tightening, hiring freezes) caused US companies to reduce contractor spending, leading to increased churn in Deel IC (Individual Contractor) service while EOR (Employer of Record) remained stable due to the nature of full-time employee payroll.

## Supporting Evidence
### Geographic Concentration:
- US market drives 80% of AMS region churn
- AMS region shows highest churn rates and declining NRR
- Other regions (APAC, EMEA) remain relatively stable

### Service-Specific Impact:
- IC service: Churn doubled from 0.33% to 0.63%
- EOR service: Perfect 0% churn across all months
- Suggests economic pressure affects contractor spend vs. full-time employee payroll
