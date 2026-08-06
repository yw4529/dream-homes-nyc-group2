# Dream Homes NYC — Neighborhood Quality & Property Value Analysis

Columbia University APAN 5310 — Group 2
Olivia Wu (yw4529) | Jialu Huang (jh5100) | Shuyan Ren (sr4373) | Chengyi Shi (cs4649)

## Project Overview
A 15-table PostgreSQL database analyzing how neighborhood quality factors
(housing violations, 311 complaints, school performance) correlate with
residential property sale prices across NYC and Connecticut.

## Repository Contents
- schema.sql — Complete database schema (15 tables, 3NF)
- IDK.ipynb — ETL pipeline (Python)
- ct_sales.csv — Connecticut real estate sales
- school_quality.csv — NYC school quality reports
- final_er.pdf — ER diagram
- dream_homes_research.docx — Project research document

## Data Sources
Raw data files exceed GitHub file size limits and are sourced directly from:
- NYC Rolling Sales: https://data.cityofnewyork.us/resource/usep-8jbt.json
- HPD Housing Violations: https://data.cityofnewyork.us/resource/wvxf-dwi5.json
- 311 Service Requests: https://data.cityofnewyork.us/resource/erm2-nwe9.json
- CT Real Estate Sales: https://data.ct.gov/resource/5mzw-sjtu.json
- Zillow ZHVI by Zip Code: https://www.zillow.com/research/data/
- NYC School Quality Reports: https://data.cityofnewyork.us/Education

## Interactive Dashboard (Metabase)

We built a four-tab interactive dashboard in Metabase, connected live to our PostgreSQL `dreamhomes` database, giving non-technical stakeholders (the "executive/C-level" access tier) a point-and-click way to explore the same insights produced by our SQL analysis.

**Tabs:**
- **Market Overview** — sale price trends by borough and property type
- **Neighborhood Quality & Livability** — housing violations, 311 complaints, and quality scores vs. price
- **Schools & Value** — school attendance rate vs. property value
- **Market Trends & Appreciation** — Zillow home value growth, top-appreciating properties, CT assessment gaps

All 10 dashboard charts are built directly from the SQL in [`dashboard_queries.sql`](./dashboard_queries.sql), which mirrors the 10 analytical procedures in [`analytics.py`](./analytics.py). Metabase was deployed via Docker (`docker run -d -p 3000:3000 --name metabase --restart always metabase/metabase`) and connected to our existing Dockerized PostgreSQL instance over Docker's internal network.
