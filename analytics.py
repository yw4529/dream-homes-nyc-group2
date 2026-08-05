import pandas as pd
from sqlalchemy import create_engine

engine = create_engine("postgresql://postgres:123@localhost:5432/dreamhomes")

def run(title, sql):
    print(f"\n{'='*60}")
    print(f"  {title}")
    print('='*60)
    with engine.connect() as c:
        df = pd.read_sql(sql, c)
    print(df.to_string(index=False))
    return df

# ── Q1: Average sale price by borough ──────────

run("Q1: Avg Sale Price by Borough", """
    SELECT b.borough_name,
           ROUND(AVG(st.sale_price)) AS avg_sale_price,
           COUNT(*) AS num_sales
    FROM borough b
    JOIN property p ON p.borough_id = b.borough_id
    JOIN sales_transaction st ON st.property_id = p.property_id
    GROUP BY b.borough_name
    ORDER BY avg_sale_price DESC
""")

# ── Q2: Top 10 zip codes by quality score ─────────────────────────
run("Q2: Top 10 Zip Codes by Quality Score", """
    SELECT zip_code,
           ROUND(quality_score::numeric, 1) AS quality_score,
           ROUND(median_sale_price) AS median_sale_price,
           violation_count, complaint_count
    FROM neighborhood_quality_score
    ORDER BY quality_score DESC
    LIMIT 10
""")

# ── Q3: CT towns with highest % sold below assessment ─────────────
run("Q3: CT Towns — % Sold Below Assessment", """
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
    LIMIT 15
""")

# ── Q4: School attendance rate vs avg sale price by district ──────
run("Q4: School Attendance Rate vs Avg Sale Price", """
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
    ORDER BY avg_attendance DESC
""")

# ── Q5: Top 311 complaint types in high-complaint zip codes ───────
run("Q5: Top 311 Complaint Types by Zip Code", """
    SELECT zip_code, complaint_type, COUNT(*) AS cnt,
           ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (PARTITION BY zip_code), 1) AS pct
    FROM service_request_311
    WHERE zip_code IS NOT NULL
    GROUP BY zip_code, complaint_type
    HAVING COUNT(*) > 100
    ORDER BY zip_code, cnt DESC
    LIMIT 30
""")

# ── Q6: Zillow price change 2020 to latest ────────────────────────
run("Q6: Zillow Home Value Change Since 2020 (Top 20)", """
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
    LIMIT 20
""")

# ── Q7: Avg price by property type ────────────────────────────────
run("Q7: Avg Sale Price by Property Type", """
    SELECT p.property_type,
           COUNT(*) AS num_sales,
           ROUND(AVG(st.sale_price)) AS avg_price,
           ROUND(PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY st.sale_price)) AS median_price,
           ROUND(AVG(st.price_per_sqft)::numeric, 2) AS avg_price_per_sqft
    FROM property p
    JOIN sales_transaction st ON st.property_id = p.property_id
    WHERE p.property_type IS NOT NULL
    GROUP BY p.property_type
    ORDER BY avg_price DESC
""")

# ── Q8: Top 20 properties with biggest price appreciation ─────────
run("Q8: Top 20 Properties by Price Appreciation", """
    WITH multi_sale AS (
        SELECT property_id,
               MIN(sale_price) AS first_price,
               MAX(sale_price) AS last_price,
               COUNT(*)        AS num_sales
        FROM price_history
        GROUP BY property_id
        HAVING COUNT(*) >= 2
    )
    SELECT p.address, p.zip_code, b.borough_name,
           ms.first_price, ms.last_price,
           ROUND(ms.last_price - ms.first_price) AS price_gain,
           ROUND(100.0*(ms.last_price-ms.first_price)/NULLIF(ms.first_price,0),1) AS pct_gain
    FROM multi_sale ms
    JOIN property p ON p.property_id = ms.property_id
    JOIN borough b ON b.borough_id = p.borough_id
    ORDER BY pct_gain DESC
    LIMIT 20
""")

# ── Q9: Quality score tier vs avg sale price ──────────────────────
run("Q9: Neighborhood Quality Tier vs Avg Sale Price", """
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
    ORDER BY avg_sale_price DESC
""")

# ── Q10: Annual sales volume and avg price by borough ─────────────
run("Q10: Annual Sales Trends by Borough (2020+)", """
    SELECT b.borough_name,
           EXTRACT(YEAR FROM st.sale_date)::int AS year,
           COUNT(*) AS num_sales,
           ROUND(AVG(st.sale_price)) AS avg_price
    FROM sales_transaction st
    JOIN property p ON p.property_id = st.property_id
    JOIN borough b ON b.borough_id = p.borough_id
    WHERE st.sale_date IS NOT NULL
      AND EXTRACT(YEAR FROM st.sale_date) >= 2020
    GROUP BY b.borough_name, year
    ORDER BY b.borough_name, year
""")

print("\n" + "="*60)
print("  All 10 analytical queries complete.")
print("="*60)
