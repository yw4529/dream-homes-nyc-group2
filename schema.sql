-- Dream Homes NYC — Database Schema (15 tables)
-- Run this file first in pgAdmin before running etl.py

DROP TABLE IF EXISTS neighborhood_quality_score CASCADE;
DROP TABLE IF EXISTS property_school CASCADE;
DROP TABLE IF EXISTS school CASCADE;
DROP TABLE IF EXISTS school_district CASCADE;
DROP TABLE IF EXISTS neighborhood_market_stat CASCADE;
DROP TABLE IF EXISTS service_request_311 CASCADE;
DROP TABLE IF EXISTS housing_violation CASCADE;
DROP TABLE IF EXISTS deed_mortgage_record CASCADE;
DROP TABLE IF EXISTS assessment_history CASCADE;
DROP TABLE IF EXISTS price_history CASCADE;
DROP TABLE IF EXISTS sales_transaction CASCADE;
DROP TABLE IF EXISTS property CASCADE;
DROP TABLE IF EXISTS municipality CASCADE;
DROP TABLE IF EXISTS neighborhood CASCADE;
DROP TABLE IF EXISTS borough CASCADE;

-- ── 1. borough ────────────────────────────────────────────────────
CREATE TABLE borough (
    borough_id   SERIAL      PRIMARY KEY,
    borough_name VARCHAR(50) UNIQUE NOT NULL,
    state        VARCHAR(5)  NOT NULL   -- NY or CT
);

-- ── 2. neighborhood ───────────────────────────────────────────────
CREATE TABLE neighborhood (
    zip_code         VARCHAR(10) PRIMARY KEY,
    neighborhood_name VARCHAR(100),
    borough_id       INTEGER     REFERENCES borough(borough_id)
);

-- ── 3. municipality (CT towns) ────────────────────────────────────
-- Renamed from town_grand_list; covers CT municipal tax assessments
CREATE TABLE municipality (
    municipality_id  SERIAL      PRIMARY KEY,
    town_name        VARCHAR(100) NOT NULL,
    state            VARCHAR(5)  DEFAULT 'CT',
    UNIQUE(town_name, state)
);

-- ── 4. property ───────────────────────────────────────────────────
-- NOTE: No last_sale_date or last_sale_price (3NF violation removed)
-- Use a subquery on sales_transaction to get latest sale
CREATE TABLE property (
    property_id      SERIAL      PRIMARY KEY,
    address          VARCHAR(200),
    zip_code         VARCHAR(10) REFERENCES neighborhood(zip_code),
    municipality_id  INTEGER     REFERENCES municipality(municipality_id),
    borough_id       INTEGER     REFERENCES borough(borough_id),
    property_type    VARCHAR(50),
    building_class   VARCHAR(100),
    gross_sqft       INTEGER,
    land_sqft        INTEGER,
    year_built       INTEGER,
    residential_units INTEGER,
    region           VARCHAR(5)  -- NY or CT
);

-- ── 5. sales_transaction ─────────────────────────────────────────
CREATE TABLE sales_transaction (
    transaction_id       SERIAL        PRIMARY KEY,
    property_id          INTEGER       REFERENCES property(property_id),
    sale_price           NUMERIC(15,2),
    sale_date            DATE,
    price_per_sqft       NUMERIC(10,2),
    assessed_value_at_sale NUMERIC(15,2),  -- from CT data or ACRIS
    sold_below_assessment BOOLEAN DEFAULT FALSE  -- set by trigger
);

-- ── TRIGGER: auto-flag sold_below_assessment ──────────────────────
CREATE OR REPLACE FUNCTION fn_flag_below_assessment()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.assessed_value_at_sale IS NOT NULL
       AND NEW.sale_price < NEW.assessed_value_at_sale THEN
        NEW.sold_below_assessment := TRUE;
    ELSE
        NEW.sold_below_assessment := FALSE;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_flag_below_assessment
    BEFORE INSERT OR UPDATE ON sales_transaction
    FOR EACH ROW
    EXECUTE FUNCTION fn_flag_below_assessment();

-- ── 6. price_history ─────────────────────────────────────────────
-- Tracks the same property selling multiple times over the years
CREATE TABLE price_history (
    history_id    SERIAL        PRIMARY KEY,
    property_id   INTEGER       REFERENCES property(property_id),
    sale_price    NUMERIC(15,2),
    sale_date     DATE,
    source_year   INTEGER       -- which Rolling Sales file year this came from
);

-- ── 7. assessment_history ─────────────────────────────────────────
-- Assessed value vs actual sale price (CT: from CT data; NYC: from ACRIS)
CREATE TABLE assessment_history (
    assessment_id    SERIAL        PRIMARY KEY,
    property_id      INTEGER       REFERENCES property(property_id),
    assessed_value   NUMERIC(15,2),
    sale_price       NUMERIC(15,2),
    sales_ratio      NUMERIC(8,4), -- assessed / sale (CT provides this directly)
    assessment_year  INTEGER,
    region           VARCHAR(5)
);

-- ── 8. deed_mortgage_record ───────────────────────────────────────
-- From ACRIS: real property deed and mortgage filings
CREATE TABLE deed_mortgage_record (
    doc_id          VARCHAR(30)  PRIMARY KEY,
    property_id     INTEGER      REFERENCES property(property_id),
    doc_type        VARCHAR(20),  -- DEED, MTGE, etc.
    doc_date        DATE,
    doc_amount      NUMERIC(15,2),
    borough_id      INTEGER      REFERENCES borough(borough_id)
);

-- ── 9. housing_violation ─────────────────────────────────────────
CREATE TABLE housing_violation (
    violation_id     VARCHAR(20)  PRIMARY KEY,
    zip_code         VARCHAR(10),
    borough_id       INTEGER      REFERENCES borough(borough_id),
    house_number     VARCHAR(20),
    street_name      VARCHAR(100),
    violation_class  CHAR(1),     -- A=non-hazardous, B=hazardous, C=immediately hazardous
    inspection_date  DATE,
    current_status   VARCHAR(50),
    violation_status VARCHAR(20),
    description      TEXT,
    latitude         NUMERIC(10,6),
    longitude        NUMERIC(10,6)
);

-- ── 10. service_request_311 ───────────────────────────────────────
CREATE TABLE service_request_311 (
    request_id       VARCHAR(20)  PRIMARY KEY,
    created_date     TIMESTAMP,
    complaint_type   VARCHAR(100),
    descriptor       VARCHAR(200),
    zip_code         VARCHAR(10),
    borough_id       INTEGER      REFERENCES borough(borough_id),
    status           VARCHAR(50),
    latitude         NUMERIC(10,6),
    longitude        NUMERIC(10,6)
);

-- ── 11. neighborhood_market_stat ─────────────────────────────────
-- Zillow ZHVI monthly median home value by zip code
CREATE TABLE neighborhood_market_stat (
    stat_id           SERIAL       PRIMARY KEY,
    zip_code          VARCHAR(10)  REFERENCES neighborhood(zip_code),
    stat_month        DATE,
    median_home_value NUMERIC(15,2)
);

-- ── 12. school_district ───────────────────────────────────────────
-- Derived from first 2 digits of school DBN
CREATE TABLE school_district (
    district_id   INTEGER     PRIMARY KEY,  -- 1-32
    borough_id    INTEGER     REFERENCES borough(borough_id)
);

-- ── 13. school ────────────────────────────────────────────────────
CREATE TABLE school (
    dbn              VARCHAR(10)  PRIMARY KEY,
    school_name      VARCHAR(200),
    school_type      VARCHAR(50),
    district_id      INTEGER      REFERENCES school_district(district_id),
    attendance_rate  NUMERIC(5,3),
    chronic_absent   NUMERIC(5,3)
);

-- ── 14. property_school ───────────────────────────────────────────
-- Junction: links a property to nearby schools via zip code match
CREATE TABLE property_school (
    property_id  INTEGER REFERENCES property(property_id),
    dbn          VARCHAR(10) REFERENCES school(dbn),
    PRIMARY KEY (property_id, dbn)
);

-- ── 15. neighborhood_quality_score ───────────────────────────────
-- Derived aggregate: one row per zip per month summarizing all quality factors
CREATE TABLE neighborhood_quality_score (
    score_id           SERIAL      PRIMARY KEY,
    zip_code           VARCHAR(10) REFERENCES neighborhood(zip_code),
    score_month        DATE,
    violation_count    INTEGER DEFAULT 0,
    complaint_count    INTEGER DEFAULT 0,
    avg_school_attendance NUMERIC(5,3),
    median_sale_price  NUMERIC(15,2),
    pct_sold_below_assessment NUMERIC(5,2),
    quality_score      NUMERIC(5,2)  -- composite 0-100 (higher = better neighborhood)
);
