CREATE TABLE transactions (       
    buyer_id INT NOT NULL,                     -- Buyer ID
    purchase_time DATETIME NOT NULL,           -- Purchase time
    refund_item DATETIME DEFAULT NULL,         -- Refund time (nullable)
    store_id CHAR(1) NOT NULL,                 -- Store ID
    item_id VARCHAR(10) NOT NULL PRIMARY KEY,           -- Item ID PRIMAARY KEY
    gross_transaction_value DECIMAL(10, 2) NOT NULL -- Transaction value
);



CREATE TABLE items (
    store_id CHAR(1),
    item_id VARCHAR(10),
    item_category VARCHAR(50),
    item_name VARCHAR(100)
);


INSERT INTO transactions (buyer_id, purchase_time, refund_item, store_id, item_id, gross_transaction_value) VALUES
(3, '2019-09-19 21:19:06', NULL, 'a', 'a1', 58),
(12, '2019-12-10 20:10:14', '2019-12-15 23:19:06', 'b', 'b2', 475),
(3, '2020-09-01 23:59:46', '2020-09-02 21:22:06', 'f', 'f9', 33),
(2, '2020-04-30 21:19:06', NULL, 'd', 'd3', 250),
(1, '2020-10-22 22:20:06', NULL, 'f', 'f2', 91),
(8, '2020-04-16 21:10:22', NULL, 'e', 'e7', 24),
(5, '2019-09-23 12:09:35', '2019-09-27 02:55:02', 'g', 'g6', 61);


INSERT INTO items (store_id, item_id, item_category, item_name) VALUES
('a', 'a1', 'pants', 'denim pants'),
('a', 'a2', 'tops', 'blouse'),
('f', 'f1', 'table', 'coffee table'),
('f', 'f5', 'chair', 'lounge chair'),
('f', 'f6', 'chair', 'armchair'),
('d', 'd2', 'jewelry', 'bracelet'),
('b', 'b4', 'earphone', 'airpods');



-- Q-1 Count of purchases per month, excluding refunded transactions
SELECT 
    STRFTIME('%Y-%m', purchase_time) AS purchase_month,
    COUNT(*) AS purchase_count
FROM 
    transactions
WHERE 
    refund_item IS NULL  -- Exclude refunded purchases
GROUP BY 
    STRFTIME('%Y-%m', purchase_time)
ORDER BY 
    purchase_month;

-- Explanation:
-- 1. STRFTIME('%Y-%m', purchase_time) extracts the year and month from the purchase_time.
-- 2. Filtered for transactions without a refund (refund_item IS NULL).
-- 3. Grouped by month and counted the number of purchases.
-- Insights:
-- This query helps understand monthly purchasing trends and seasonality.
-- Excluding refunded transactions provides a more accurate count of completed purchases.




-- Q-2 Count stores with at least 5 transactions in October 2020
SELECT 
    store_id,
    COUNT(*) AS transaction_count
FROM 
    transactions
WHERE 
    STRFTIME('%Y-%m', purchase_time) = '2020-10'  -- Filter for October 2020
GROUP BY 
    store_id
HAVING 
    COUNT(*) >= 5;  -- Stores with at least 5 transactions

-- Explanation:
-- 1. Filtered transactions for October 2020 using STRFTIME to extract the year and month.
-- 2. Grouped by store_id and counted transactions.
-- 3. Filtered stores with at least 5 transactions using HAVING.
-- Insights:
-- Identifying stores with high activity in a specific month can aid in analyzing peak-performance locations.
-- Stores meeting the threshold could be targeted for promotions or further analysis.




-- Q-3 Shortest interval from purchase to refund for each store
SELECT 
    store_id,
    MIN(JULIANDAY(refund_item) - JULIANDAY(purchase_time)) * 1440 AS min_refund_interval_minutes
FROM 
    transactions
WHERE 
    refund_item IS NOT NULL  -- Only consider refunded transactions
GROUP BY 
    store_id;

-- Explanation:
-- 1. Used JULIANDAY to calculate the difference between refund_item and purchase_time in days.
-- 2. Converted days to minutes by multiplying by 1440 (minutes in a day).
-- 3. Filtered for refunded transactions and grouped by store_id.
--Insights:
-- This metric helps assess refund efficiency and the potential speed of resolving customer issues.
-- Stores with shorter refund intervals may indicate better customer service processes.





-- Q-4 Gross transaction value of the first order for each store
WITH RankedTransactions AS (
    SELECT 
        store_id,
        purchase_time,
        gross_transaction_value,
        ROW_NUMBER() OVER (PARTITION BY store_id ORDER BY purchase_time) AS rank
    FROM 
        transactions
)
SELECT 
    store_id,
    gross_transaction_value AS first_order_value
FROM 
    RankedTransactions
WHERE 
    rank = 1;

-- Explanation:
-- 1. Used ROW_NUMBER to rank transactions per store by purchase_time.
-- 2. Filtered for the first order (rank = 1).
-- Insights:
-- This query highlights the initial transaction value for each store.
-- The first transaction can offer insights into initial customer engagement and purchasing trends.





-- Q-5 Most popular item in buyers' first purchase
WITH RankedPurchases AS (
    SELECT 
        buyer_id,
        item_id,
        ROW_NUMBER() OVER (PARTITION BY buyer_id ORDER BY purchase_time) AS rank
    FROM 
        transactions
),
ItemPopularity AS (
    SELECT 
        RP.item_id,
        I.item_name,
        COUNT(*) AS popularity
    FROM 
        RankedPurchases RP
    JOIN 
        items I ON RP.item_id = I.item_id
    WHERE 
        rank = 1  -- Only consider first purchases
    GROUP BY 
        RP.item_id, I.item_name
)
SELECT 
    item_name,
    MAX(popularity) AS most_popular
FROM 
    ItemPopularity;

-- Explanation:
-- 1. Ranked transactions per buyer by purchase_time.
-- 2. Filtered for first purchases and joined with items table to get item_name.
-- 3. Grouped by item_name and counted occurrences to determine popularity.
-- 4. Selected the most popular item based on the highest count.
-- Insights:
-- Understanding popular items in buyers' first purchases helps with inventory and marketing strategies.
-- Targeting popular items for first-time buyers could boost conversions.






--Q-6 Create a flag for refund eligibility
SELECT 
    *,
    CASE 
        WHEN JULIANDAY(refund_item) - JULIANDAY(purchase_time) <= (72 / 24.0) THEN 'Eligible'
        ELSE 'Not Eligible'
    END AS refund_eligibility
FROM 
    transactions;

-- Explanation:
-- 1. Calculated the difference in days between refund_item and purchase_time.
-- 2. Checked if the difference is less than or equal to 72 hours (72 / 24.0 days).
-- 3. Added a flag (Eligible or Not Eligible) based on the condition.
-- Insights:
-- This flag provides a quick view of whether a transaction meets the refund policy.
-- Can help in designing automated refund workflows and alerts.







-- Q-7 Rank purchases per buyer and show only the second purchase
WITH RankedPurchases AS (
    SELECT 
        buyer_id,
        item_id,
        purchase_time,
        ROW_NUMBER() OVER (PARTITION BY buyer_id ORDER BY purchase_time) AS rank
    FROM 
        transactions
)
SELECT 
    buyer_id,
    item_id,
    purchase_time
FROM 
    RankedPurchases
WHERE 
    rank = 2;

-- Explanation:
-- 1. Ranked transactions per buyer by purchase_time.
-- 2. Filtered for the second purchase (rank = 2).
-- Insights:
-- Analyzing second purchases provides insights into buyer retention and behavior.
-- Patterns in subsequent purchases can inform loyalty programs or marketing campaigns.







-- Q-8 Second transaction time per buyer without using MIN/MAX
WITH RankedTransactions AS (
    SELECT 
        buyer_id,
        purchase_time,
        ROW_NUMBER() OVER (PARTITION BY buyer_id ORDER BY purchase_time) AS rank
    FROM 
        transactions
)
SELECT 
    buyer_id,
    purchase_time AS second_transaction_time
FROM 
    RankedTransactions
WHERE 
    rank = 2;

-- Explanation:
-- 1. Ranked transactions per buyer by purchase_time using ROW_NUMBER.
-- 2. Filtered for the second transaction (rank = 2).
-- Insights:
-- Similar to the previous query, this provides a simplified way to check second transaction times.
-- Could be extended to study time gaps between transactions.





