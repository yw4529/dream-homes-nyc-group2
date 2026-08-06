-- ============================================================
-- Dream Homes NYC — Metabase Dashboard Queries
-- Database: dreamhomes (PostgreSQL)
-- These 10 queries power the 4-tab Metabase executive dashboard.
-- Each is also one of the assignment's required analytical procedures.
-- ============================================================


-- ── TAB 1: MARKET OVERVIEW ──────────────────────────────────

-- 1. Avg Sale Price by Borough
SELECT b.borough_name,
       ROUND(AVG(st.sale_price)) AS avg_sale_price,
       COUNT(*) AS num_sales
FROM borough b
JOIN property p ON p.borough_id = b.borough_id
JOIN sales_transaction st ON st.property_id = p.property_id
GROUP BY b.borough_name
ORDER BY avg_sale_price DESC;


-- 2. Avg Sale Price by Property Type
SELECT p.property_type,
       COUNT(*) AS num_sales,
       ROUND(AVG(st.sale_price)) AS avg_price,
       ROUND(PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY st.sale_price)) AS median_price
FROM property p
JOIN sales_transaction st ON st.property_id = p.property_id
WHERE p.property_type IS NOT NULL
GROUP BY p.property_type
ORDER BY avg_price DESC;


-- 3. Avg Price by Borough: 2025 vs 2026
-- Note: NYC sales data covers 2025-2026 only; Connecticut sales data covers
-- 2001-2020 separately (non-overlapping source date ranges — see report
-- limitations section). This query isolates the five NYC boroughs so the
-- year-over-year comparison is meaningful.
SELECT b.borough_name,
       EXTRACT(YEAR FROM st.sale_date)::int AS year,
       COUNT(*) AS num_sales,
       ROUND(AVG(st.sale_price)) AS avg_price
FROM sales_transaction st
JOIN property p ON p.property_id = st.property_id
JOIN borough b ON b.borough_id = p.borough_id
WHERE st.sale_date IS NOT NULL
  AND b.borough_name != 'CONNECTICUT'
GROUP BY b.borough_name, year
ORDER BY b.borough_name, year;


-- ── TAB 2: NEIGHBORHOOD QUALITY & LIVABILITY ────────────────

-- 4. Top 10 Zip Codes by Quality Score
SELECT zip_code,
       ROUND(quality_score::numeric, 1) AS quality_score,
       ROUND(median_sale_price) AS median_sale_price,
       violation_count, complaint_count
FROM neighborhood_quality_score
ORDER BY quality_score DESC
LIMIT 10;


-- 5. Quality Tier vs Avg Sale Price
SELECT
    CASE
        WHEN quality_score >= 80 THEN 'High (80-100)'
        WHEN quality_score >= 60 THEN 'Medium (60-79)'
        ELSE 'Low (<60)'
    END AS quality_tier,
    COUNT(*) AS zip_count,
    ROUND(AVG(median_sale_price)) AS avg_sale_price,
    ROUND(AVG(violation_count)::numeric, 1) AS avg_violations,
    ROUND(AVG(complaint_count)::numeric, 1) AS avg_complaints
FROM neighborhood_quality_score
WHERE median_sale_price IS NOT NULL
GROUP BY quality_tier
ORDER BY avg_sale_price DESC;


-- 6. Top 311 Complaint Types by Zip Code
SELECT zip_code, complaint_type, COUNT(*) AS cnt,
       ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (PARTITION BY zip_code), 1) AS pct
FROM service_request_311
WHERE zip_code IS NOT NULL
GROUP BY zip_code, complaint_type
HAVING COUNT(*) > 100
ORDER BY zip_code, cnt DESC
LIMIT 30;


-- ── TAB 3: SCHOOLS & VALUE ───────────────────────────────────

-- 7. School Attendance Rate vs Avg Sale Price
WITH district_stats AS (
    SELECT sd.district_id, b.borough_name,
           AVG(s.attendance_rate) AS avg_attendance,
           AVG(st.sale_price)     AS avg_price
    FROM school_district sd
    JOIN borough b ON b.borough_id = sd.borough_id
    JOIN school s ON s.district_id = sd.district_id
    JOIN property_school ps ON ps.dbn = s.dbn
    JOIN property p ON p.property_id = ps.property_id
    JOIN sales_transaction st ON st.property_id = p.property_id
    GROUP BY sd.district_id, b.borough_name
)
SELECT borough_name,
       ROUND(avg_attendance::numeric, 2) AS avg_attendance_rate,
       ROUND(avg_price) AS avg_sale_price,
       CASE WHEN avg_attendance > 0.9 THEN 'High' ELSE 'Low' END AS tier
FROM district_stats
ORDER BY avg_attendance DESC;


-- ── TAB 4: MARKET TRENDS & APPRECIATION ─────────────────────

-- 8. Zillow Price Change Since 2020
WITH first_last AS (
    SELECT zip_code,
           FIRST_VALUE(median_home_value) OVER (
               PARTITION BY zip_code ORDER BY stat_month) AS price_start,
           LAST_VALUE(median_home_value) OVER (
               PARTITION BY zip_code ORDER BY stat_month
               ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING) AS price_end
    FROM neighborhood_market_stat
)
SELECT zip_code,
       ROUND(price_start) AS price_2020,
       ROUND(price_end)   AS price_latest,
       ROUND(100.0 * (price_end - price_start) / NULLIF(price_start,0), 1) AS pct_change
FROM first_last
GROUP BY zip_code, price_start, price_end
ORDER BY pct_change DESC
LIMIT 20;


-- 9. Top 20 Properties by Price Appreciation
-- Note: price_history contained exact-duplicate rows (same property_id,
-- sale_price, sale_date) which we identified during dashboard QA. This
-- version dedupes before ranking. See report limitations section — a
-- small number of the largest gains (e.g. $100K -> $6.1M) likely reflect
-- data entry anomalies rather than genuine appreciation and were not
-- individually corrected before submission.
WITH multi_sale AS (
    SELECT property_id,
           MIN(sale_price) AS first_price,
           MAX(sale_price) AS last_price,
           COUNT(DISTINCT sale_date) AS num_sales
    FROM price_history
    GROUP BY property_id
    HAVING COUNT(DISTINCT sale_date) >= 2
),
deduped AS (
    SELECT DISTINCT ON (p.address, p.zip_code)
           p.address, p.zip_code, b.borough_name,
           ms.first_price, ms.last_price,
           ROUND(ms.last_price - ms.first_price) AS price_gain,
           ROUND(100.0*(ms.last_price-ms.first_price)/NULLIF(ms.first_price,0),1) AS pct_gain
    FROM multi_sale ms
    JOIN property p ON p.property_id = ms.property_id
    JOIN borough b ON b.borough_id = p.borough_id
    ORDER BY p.address, p.zip_code, ms.last_price DESC
)
SELECT * FROM deduped
ORDER BY pct_gain DESC
LIMIT 20;


-- 10. CT Towns: % Sold Below Assessment
SELECT m.town_name,
       COUNT(*) AS total_sales,
       SUM(CASE WHEN st.sold_below_assessment THEN 1 ELSE 0 END) AS below_assessment,
       ROUND(100.0 * SUM(CASE WHEN st.sold_below_assessment THEN 1 ELSE 0 END)
             / COUNT(*), 2) AS pct_below
FROM municipality m
JOIN property p ON p.municipality_id = m.municipality_id
JOIN sales_transaction st ON st.property_id = p.property_id
WHERE p.region = 'CT'
GROUP BY m.town_name
HAVING COUNT(*) > 10
ORDER BY pct_below DESC
LIMIT 15;
