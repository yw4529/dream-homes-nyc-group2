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
