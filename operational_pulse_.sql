-- Step 1: Create Database
DROP DATABASE IF EXISTS operational_pulse;
CREATE DATABASE operational_pulse;
USE operational_pulse;

-- ========================================
-- Step 2: Create Raw Tables
-- ========================================

CREATE TABLE sales_raw (
    row_id INT PRIMARY KEY AUTO_INCREMENT,
    order_number VARCHAR(10),
    quantity_ordered INT,
    price_each DECIMAL(10,2),
    order_line_number INT,
    sales DECIMAL(10,2),
    order_date VARCHAR(50),
    status VARCHAR(20),
    qtr_id INT,
    month_id INT,
    year_id INT,
    product_line VARCHAR(50),
    msrp VARCHAR(10),
    product_code VARCHAR(20),
    customer_name VARCHAR(100),
    phone VARCHAR(50),
    address_line1 VARCHAR(100),
    address_line2 VARCHAR(100),
    city VARCHAR(50),
    state VARCHAR(50),
    postal_code VARCHAR(20),
    country VARCHAR(50),
    territory VARCHAR(50),
    contact_lastname VARCHAR(50),
    contact_firstname VARCHAR(50),
    deal_size VARCHAR(20),
    loaded_timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE support_raw (
    row_id INT PRIMARY KEY AUTO_INCREMENT,
    ticket_id VARCHAR(20),
    customer_name VARCHAR(100),
    customer_email VARCHAR(100),
    customer_age INT,
    customer_gender VARCHAR(10),
    product_purchased VARCHAR(100),
    date_of_purchase VARCHAR(50),
    ticket_type VARCHAR(50),
    ticket_subject VARCHAR(200),
    ticket_description TEXT,
    ticket_status VARCHAR(50),
    resolution VARCHAR(200),
    ticket_priority VARCHAR(20),
    ticket_channel VARCHAR(50),
    first_response_time INT,
    time_to_resolution INT,
    customer_satisfaction_rating INT,
    loaded_timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- ========================================
-- Step 3: Create Clean Tables
-- ========================================

CREATE TABLE sales_clean (
    sale_id INT PRIMARY KEY AUTO_INCREMENT,
    order_number VARCHAR(10) NOT NULL,
    quantity_ordered INT,
    price_each DECIMAL(10,2),
    sales DECIMAL(10,2),
    order_date DATE NOT NULL,
    status VARCHAR(20),
    qtr_id INT,
    month_id INT,
    year_id INT,
    product_line VARCHAR(50),
    product_code VARCHAR(20),
    customer_name VARCHAR(100),
    city VARCHAR(50),
    state VARCHAR(2),
    postal_code VARCHAR(20),
    country VARCHAR(50),
    deal_size VARCHAR(20),
    data_quality_score DECIMAL(5,2),
    created_timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE support_clean (
    support_id INT PRIMARY KEY AUTO_INCREMENT,
    ticket_id VARCHAR(20) NOT NULL UNIQUE,
    customer_name VARCHAR(100),
    customer_email VARCHAR(100),
    customer_age INT,
    product_purchased VARCHAR(100),
    date_of_purchase DATE,
    ticket_type VARCHAR(50),
    ticket_subject VARCHAR(200),
    ticket_status VARCHAR(50),
    ticket_priority ENUM('Low', 'Medium', 'High', 'Critical'),
    ticket_channel VARCHAR(50),
    first_response_time INT,
    time_to_resolution INT,
    customer_satisfaction_rating INT,
    data_quality_score DECIMAL(5,2),
    created_timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- ========================================
-- Step 4: Create Logging Tables
-- ========================================

CREATE TABLE data_quality_log (
    log_id INT PRIMARY KEY AUTO_INCREMENT,
    table_name VARCHAR(50) NOT NULL,
    column_name VARCHAR(50) NOT NULL,
    rule_name VARCHAR(100) NOT NULL,
    error_count INT DEFAULT 0,
    total_records INT DEFAULT 0,
    error_percentage DECIMAL(5,2),
    sample_values TEXT,
    severity ENUM('Low', 'Medium', 'High', 'Critical') DEFAULT 'Medium',
    log_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE data_quality_rules (
    rule_id INT PRIMARY KEY AUTO_INCREMENT,
    rule_name VARCHAR(100) NOT NULL UNIQUE,
    table_name VARCHAR(50) NOT NULL,
    column_name VARCHAR(50),
    rule_type VARCHAR(50) NOT NULL,
    rule_description TEXT,
    rule_logic TEXT,
    severity ENUM('Low', 'Medium', 'High', 'Critical') DEFAULT 'Medium',
    is_active BOOLEAN DEFAULT TRUE,
    created_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- ========================================
-- Step 5: Insert Quality Rules
-- ========================================

INSERT INTO data_quality_rules (rule_name, table_name, column_name, rule_type, rule_description, severity) VALUES
('DUPLICATE_ORDER_NUMBER', 'sales_raw', 'order_number', 'DUPLICATE_DETECTION', 'Detects duplicate order numbers', 'High'),
('DUPLICATE_TICKET_ID', 'support_raw', 'ticket_id', 'DUPLICATE_DETECTION', 'Detects duplicate ticket IDs', 'Critical'),
('MISSING_SALES_AMOUNT', 'sales_raw', 'sales', 'MISSING_VALUE', 'Flags NULL or zero sales', 'High'),
('MISSING_CUSTOMER_EMAIL', 'support_raw', 'customer_email', 'MISSING_VALUE', 'Flags missing emails', 'High'),
('INVALID_DATE_FORMAT', 'sales_raw', 'order_date', 'INVALID_FORMAT', 'Detects bad date formats', 'Medium'),
('FUTURE_ORDER_DATE', 'sales_raw', 'order_date', 'INVALID_RANGE', 'Detects future dates', 'Critical'),
('INCONSISTENT_PRIORITY', 'support_raw', 'ticket_priority', 'INCONSISTENT_CATEGORY', 'Non-standard priorities', 'Medium'),
('INCONSISTENT_DEAL_SIZE', 'sales_raw', 'deal_size', 'INCONSISTENT_CATEGORY', 'Non-standard deal sizes', 'Low'),
('MISSING_CUSTOMER_NAME', 'sales_raw', 'customer_name', 'MISSING_VALUE', 'Missing customer name', 'Medium'),
('NEGATIVE_QUANTITY', 'sales_raw', 'quantity_ordered', 'INVALID_RANGE', 'Negative quantities', 'High');

-- ========================================
-- Step 6: Create Stored Procedures
-- ========================================

DELIMITER $$

DROP PROCEDURE IF EXISTS sp_detect_sales_duplicates$$
CREATE PROCEDURE sp_detect_sales_duplicates()
BEGIN
    DECLARE duplicate_count INT DEFAULT 0;
    DECLARE total_count INT DEFAULT 0;
    DECLARE sample_text TEXT DEFAULT '';
    
    SELECT COUNT(*) INTO total_count FROM sales_raw;
    
    IF total_count > 0 THEN
        SELECT COUNT(*) - COUNT(DISTINCT order_number)
        INTO duplicate_count
        FROM sales_raw
        WHERE order_number IS NOT NULL;
        
        SELECT IFNULL(GROUP_CONCAT(order_number SEPARATOR ', '), '')
        INTO sample_text
        FROM (
            SELECT order_number
            FROM sales_raw
            GROUP BY order_number
            HAVING COUNT(*) > 1
            LIMIT 10
        ) dups;
        
        INSERT INTO data_quality_log (
            table_name, column_name, rule_name, 
            error_count, total_records, error_percentage, 
            sample_values, severity
        )
        VALUES (
            'sales_raw',
            'order_number',
            'DUPLICATE_ORDER_NUMBER',
            duplicate_count,
            total_count,
            CASE WHEN total_count > 0 THEN ROUND((duplicate_count / total_count) * 100, 2) ELSE 0 END,
            sample_text,
            'High'
        );
    END IF;
    
    SELECT CONCAT('Found ', duplicate_count, ' duplicates') as result;
END$$

DROP PROCEDURE IF EXISTS sp_detect_missing_values$$
CREATE PROCEDURE sp_detect_missing_values()
BEGIN
    DECLARE total_sales INT DEFAULT 0;
    DECLARE total_support INT DEFAULT 0;
    DECLARE missing_sales INT DEFAULT 0;
    DECLARE missing_names INT DEFAULT 0;
    DECLARE missing_emails INT DEFAULT 0;
    
    SELECT COUNT(*) INTO total_sales FROM sales_raw;
    SELECT COUNT(*) INTO total_support FROM support_raw;
    
    IF total_sales > 0 THEN
        SELECT COUNT(*) INTO missing_sales
        FROM sales_raw
        WHERE sales IS NULL OR sales <= 0;
        
        INSERT INTO data_quality_log (
            table_name, column_name, rule_name, 
            error_count, total_records, error_percentage, severity
        )
        VALUES (
            'sales_raw',
            'sales',
            'MISSING_SALES_AMOUNT',
            missing_sales,
            total_sales,
            ROUND((missing_sales / total_sales) * 100, 2),
            'High'
        );
        
        SELECT COUNT(*) INTO missing_names
        FROM sales_raw
        WHERE customer_name IS NULL OR TRIM(customer_name) = '';
        
        INSERT INTO data_quality_log (
            table_name, column_name, rule_name, 
            error_count, total_records, error_percentage, severity
        )
        VALUES (
            'sales_raw',
            'customer_name',
            'MISSING_CUSTOMER_NAME',
            missing_names,
            total_sales,
            ROUND((missing_names / total_sales) * 100, 2),
            'Medium'
        );
    END IF;
    
    IF total_support > 0 THEN
        SELECT COUNT(*) INTO missing_emails
        FROM support_raw
        WHERE customer_email IS NULL OR TRIM(customer_email) = '';
        
        INSERT INTO data_quality_log (
            table_name, column_name, rule_name, 
            error_count, total_records, error_percentage, 
            sample_values, severity
        )
        SELECT 
            'support_raw',
            'customer_email',
            'MISSING_CUSTOMER_EMAIL',
            missing_emails,
            total_support,
            ROUND((missing_emails / total_support) * 100, 2),
            IFNULL(GROUP_CONCAT(ticket_id SEPARATOR ', '), ''),
            'High'
        FROM support_raw
        WHERE customer_email IS NULL OR TRIM(customer_email) = ''
        LIMIT 1;
    END IF;
    
    SELECT 'Missing value checks completed' as result;
END$$

DROP PROCEDURE IF EXISTS sp_validate_dates$$
CREATE PROCEDURE sp_validate_dates()
BEGIN
    DECLARE total_sales INT DEFAULT 0;
    DECLARE future_dates INT DEFAULT 0;
    
    SELECT COUNT(*) INTO total_sales FROM sales_raw;
    
    IF total_sales > 0 THEN
        SELECT COUNT(*) INTO future_dates
        FROM sales_raw
        WHERE STR_TO_DATE(order_date, '%m/%d/%Y %H:%i') > CURDATE();
        
        INSERT INTO data_quality_log (
            table_name, column_name, rule_name, 
            error_count, total_records, error_percentage, severity
        )
        VALUES (
            'sales_raw',
            'order_date',
            'FUTURE_ORDER_DATE',
            future_dates,
            total_sales,
            ROUND((future_dates / total_sales) * 100, 2),
            'Critical'
        );
    END IF;
    
    SELECT 'Date validation completed' as result;
END$$

DROP PROCEDURE IF EXISTS sp_normalize_categories$$
CREATE PROCEDURE sp_normalize_categories()
BEGIN
    DECLARE total_support INT DEFAULT 0;
    DECLARE total_sales INT DEFAULT 0;
    
    SELECT COUNT(*) INTO total_support FROM support_raw;
    SELECT COUNT(*) INTO total_sales FROM sales_raw;
    
    IF total_support > 0 THEN
        INSERT INTO data_quality_log (
            table_name, column_name, rule_name, 
            error_count, total_records, error_percentage, severity
        )
        SELECT 
            'support_raw',
            'ticket_priority',
            'INCONSISTENT_PRIORITY',
            COUNT(*),
            total_support,
            ROUND((COUNT(*) / total_support) * 100, 2),
            'Medium'
        FROM support_raw
        WHERE ticket_priority IS NOT NULL
          AND UPPER(TRIM(ticket_priority)) NOT IN ('LOW', 'MEDIUM', 'HIGH', 'CRITICAL')
        LIMIT 1;
    END IF;
    
    IF total_sales > 0 THEN
        INSERT INTO data_quality_log (
            table_name, column_name, rule_name, 
            error_count, total_records, error_percentage, severity
        )
        SELECT 
            'sales_raw',
            'deal_size',
            'INCONSISTENT_DEAL_SIZE',
            COUNT(*),
            total_sales,
            ROUND((COUNT(*) / total_sales) * 100, 2),
            'Low'
        FROM sales_raw
        WHERE deal_size IS NOT NULL 
          AND deal_size NOT IN ('Small', 'Medium', 'Large')
        LIMIT 1;
    END IF;
    
    SELECT 'Category normalization completed' as result;
END$$

DROP PROCEDURE IF EXISTS sp_clean_and_transform_data$$
CREATE PROCEDURE sp_clean_and_transform_data()
BEGIN
    DECLARE v_sales_raw_count INT DEFAULT 0;
    DECLARE v_sales_clean_count INT DEFAULT 0;
    DECLARE v_support_raw_count INT DEFAULT 0;
    DECLARE v_support_clean_count INT DEFAULT 0;
    
    SELECT COUNT(*) INTO v_sales_raw_count FROM sales_raw;
    SELECT COUNT(*) INTO v_support_raw_count FROM support_raw;
    
    IF v_sales_raw_count = 0 AND v_support_raw_count = 0 THEN
        SELECT 'ERROR: No data in raw tables. Load data first!' as error_message;
    ELSE
        TRUNCATE TABLE sales_clean;
        TRUNCATE TABLE support_clean;
        TRUNCATE TABLE data_quality_log;
        
        SELECT 'Starting quality checks...' as step;
        
        CALL sp_detect_sales_duplicates();
        CALL sp_detect_missing_values();
        CALL sp_validate_dates();
        CALL sp_normalize_categories();
        
        SELECT 'Quality checks complete!' as step;
        
        IF v_sales_raw_count > 0 THEN
            INSERT INTO sales_clean (
                order_number, quantity_ordered, price_each, sales, order_date,
                status, qtr_id, month_id, year_id, product_line, product_code,
                customer_name, city, state, postal_code, country, deal_size,
                data_quality_score
            )
            SELECT 
                order_number,
                COALESCE(quantity_ordered, 1),
                COALESCE(price_each, 0),
                COALESCE(sales, 0),
                STR_TO_DATE(order_date, '%m/%d/%Y %H:%i'),
                status,
                qtr_id,
                month_id,
                year_id,
                product_line,
                product_code,
                TRIM(customer_name),
                TRIM(city),
                UPPER(LEFT(TRIM(COALESCE(state, 'XX')), 2)),
                postal_code,
                country,
                CASE 
                    WHEN deal_size IN ('Small', 'Medium', 'Large') THEN deal_size
                    ELSE 'Unknown'
                END,
                100 - (
                    (CASE WHEN sales IS NULL OR sales <= 0 THEN 20 ELSE 0 END) +
                    (CASE WHEN customer_name IS NULL THEN 20 ELSE 0 END) +
                    (CASE WHEN city IS NULL THEN 10 ELSE 0 END) +
                    (CASE WHEN state IS NULL THEN 10 ELSE 0 END) +
                    (CASE WHEN STR_TO_DATE(order_date, '%m/%d/%Y %H:%i') IS NULL THEN 40 ELSE 0 END)
                )
            FROM sales_raw
            WHERE order_number IS NOT NULL
              AND STR_TO_DATE(order_date, '%m/%d/%Y %H:%i') IS NOT NULL
              AND STR_TO_DATE(order_date, '%m/%d/%Y %H:%i') <= CURDATE();
            
            SELECT 'Sales data cleaned!' as step;
        END IF;
        
        IF v_support_raw_count > 0 THEN
            INSERT INTO support_clean (
                ticket_id, customer_name, customer_email, customer_age,
                product_purchased, date_of_purchase, ticket_type, 
                ticket_subject, ticket_status, ticket_priority,
                ticket_channel, first_response_time, time_to_resolution, 
                customer_satisfaction_rating, data_quality_score
            )
            SELECT 
                ticket_id,
                TRIM(customer_name),
                LOWER(TRIM(COALESCE(customer_email, 'unknown@example.com'))),
                customer_age,
                product_purchased,
                STR_TO_DATE(date_of_purchase, '%Y-%m-%d'),
                ticket_type,
                ticket_subject,
                ticket_status,
                CASE 
                    WHEN UPPER(TRIM(ticket_priority)) IN ('HIGH', 'H', 'CRITICAL') THEN 'High'
                    WHEN UPPER(TRIM(ticket_priority)) IN ('MEDIUM', 'M', 'MED') THEN 'Medium'
                    WHEN UPPER(TRIM(ticket_priority)) IN ('LOW', 'L') THEN 'Low'
                    ELSE 'Medium'
                END,
                ticket_channel,
                first_response_time,
                time_to_resolution,
                customer_satisfaction_rating,
                100 - (
                    (CASE WHEN customer_email IS NULL THEN 25 ELSE 0 END) +
                    (CASE WHEN ticket_status IS NULL THEN 20 ELSE 0 END) +
                    (CASE WHEN time_to_resolution IS NULL THEN 15 ELSE 0 END) +
                    (CASE WHEN customer_satisfaction_rating IS NULL THEN 15 ELSE 0 END) +
                    (CASE WHEN STR_TO_DATE(date_of_purchase, '%Y-%m-%d') IS NULL THEN 25 ELSE 0 END)
                )
            FROM support_raw
            WHERE ticket_id IS NOT NULL;
            
            SELECT 'Support data cleaned!' as step;
        END IF;
        
        SELECT COUNT(*) INTO v_sales_clean_count FROM sales_clean;
        SELECT COUNT(*) INTO v_support_clean_count FROM support_clean;
        
        SELECT 
            'CLEANING COMPLETE' as status,
            v_sales_raw_count as sales_raw,
            v_sales_clean_count as sales_clean,
            v_support_raw_count as support_raw,
            v_support_clean_count as support_clean;
    END IF;
END$$

DELIMITER ;

-- ========================================
-- Verification Queries
-- ========================================

SELECT 'Database setup complete!' as message;
SHOW TABLES;
SELECT COUNT(*) as quality_rules_loaded FROM data_quality_rules;
