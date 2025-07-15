--========================================
-- ADVANCED DATA ANALYTICS PROJECT
--========================================
-- This file contains my own notes from a ADVANCED DATA ANALYTICS PROJECT by Data with Baraa
-- Complex queries
-- Window Functions
-- CTE
-- Subqueries
-- Reports

--========================================
-- Changes Over Time Analysis
--========================================

-- [Measure]   BY [Date Dimension]
-- total_sales BY Year
-- avg_cost	   BY Month

SELECT 
DATETRUNC(month,order_date) AS order_year,
SUM(sales_amount) AS total_sales,
COUNT(DISTINCT customer_key) AS total_customers,
SUM(quantity) AS total_quantity
FROM gold.fact_sales
WHERE order_date IS NOT NULL
GROUP BY DATETRUNC(month,order_date)
ORDER BY DATETRUNC(month,order_date)


SELECT 
FORMAT(order_date, 'yyyy-MMM') AS order_year,
SUM(sales_amount) AS total_sales,
COUNT(DISTINCT customer_key) AS total_customers,
SUM(quantity) AS total_quantity
FROM gold.fact_sales
WHERE order_date IS NOT NULL
GROUP BY FORMAT(order_date, 'yyyy-MMM')
ORDER BY FORMAT(order_date, 'yyyy-MMM')


--========================================
-- Cumulative Analysis
--========================================
-- Aggregate the data progressively over time.
-- Helps to understand whether our business is growing or declining

-- [Cumulative Measure] BY [Date Dimension]
-- Running total_sales  BY Year
-- Moving average of sales BY Month

-- Calculate the total sales per month
-- and the running total of sales over time
SELECT
order_date,
total_sales,
SUM(total_sales) OVER ( ORDER BY order_date ) AS running_total_sales,
AVG(avg_price) OVER (ORDER BY order_date) AS moving_avg_price
FROM(
	SELECT 
	DATETRUNC(YEAR, order_date) AS order_date,
	SUM(sales_amount) AS total_sales,
	AVG(price) AS avg_price
	FROM gold.fact_sales
	WHERE order_date IS NOT NULL
	GROUP BY DATETRUNC(YEAR, order_date)
) t


--========================================
-- Performance Analysis
--========================================
-- Comparing the current value to a target value.
-- Helps measure success and compare performance.
-- substracting, using WINDOW FUNCTIONS 

-- Current [Measure]  - Target[Measure]
-- Current Sales	  - Average Sales
-- Current year Sales - Previous year Sales  <-- yoy Analysis
-- Current Sales	  - Lowest Sales

-- Analyze the yearly performance of products by comparing each product's sales 
-- to both its average sales performance and the previous year's sales.

WITH yearly_product_sales AS (
	SELECT
	YEAR(f.order_date) order_year,
	p.product_name,
	SUM(f.sales_amount) AS current_sales
	FROM gold.fact_sales f
	LEFT JOIN gold.dim_products p
	ON f.product_key = p.product_key
	WHERE f.order_date IS NOT NULL
	GROUP BY YEAR(f.order_date), p.product_name
)

SELECT
order_year,
product_name,
current_sales,
AVG(current_sales) OVER (PARTITION BY product_name) avg_sales,
current_sales - AVG(current_sales) OVER (PARTITION BY product_name) AS diff_avg,
CASE 
	WHEN current_sales - AVG(current_sales) OVER (PARTITION BY product_name) > 0 THEN 'Above Avg'
	WHEN current_sales - AVG(current_sales) OVER (PARTITION BY product_name) < 0 THEN 'Below Avg'
	ELSE 'Avg'
END AS avg_change,
-- Year-over-year Analysis
LAG(current_sales) OVER (PARTITION BY product_name ORDER BY order_year) AS py_sales,
current_sales - LAG(current_sales) OVER (PARTITION BY product_name ORDER BY order_year) AS diff_py,
CASE 
	WHEN current_sales - LAG(current_sales) OVER (PARTITION BY product_name ORDER BY order_year) > 0 THEN 'Increase'
	WHEN current_sales - LAG(current_sales) OVER (PARTITION BY product_name ORDER BY order_year) < 0 THEN 'Decrease'
	ELSE 'No Change'
END AS py_change
FROM yearly_product_sales
ORDER BY product_name, order_year


--================================================
-- Part-To-Whole Analysis | Proportional Analysis
--================================================

-- Analyze how an individual part is performing compared to the overall,
-- allowing us to understand which category has the greatest impact on the business

-- ([Measure] / Total[Measure] ) * 100 BY [Dimension]
-- (   Sales  / Total Sales )    * 100 BY Category
-- ( Quantity / Total Quantity)  * 100 BY Country

-- Which categories contribute the most to averall sales?
-- To display aggregations at multiple levels in the results, 
WITH category_sales AS(
SELECT
p.category,
SUM(f.sales_amount) AS total_sales
FROM gold.fact_sales f
LEFT JOIN gold.dim_products AS p
ON f.product_key = p.product_key
GROUP BY p.category
)

SELECT 
category,
total_sales,
SUM(total_sales) OVER() AS overall_sales,
CONCAT(ROUND((CAST(total_sales AS FLOAT) / SUM(total_sales) OVER()) * 100, 2),'%') AS percentage_of_total
FROM category_sales
ORDER BY total_sales DESC -- Over-relying sales onto 1 category is a bad plan.


--=========================================
-- Data Segmentation
--=========================================

-- Group the data based on a specific range.
-- Helps understand the correlation between two measures.

-- [Measure] BY [Measure]
-- Total Products BY Sales Range
-- Total Customers BY Age

-- Using CASE WHEN STATEMENT in order to convert the dimension into category


-- Segment products into cost ranges and count how many products fall into each segment
WITH product_segments AS (
SELECT 
product_key,
product_name,
cost,
CASE 
	WHEN cost < 100 THEN 'Below 100'
	WHEN cost BETWEEN 100 AND 500 THEN '100-500'
	WHEN cost BETWEEN 500 AND 1000 THEN '500-1000'
	ELSE 'Above 1000'
END AS cost_range
FROM gold.dim_products
)

SELECT 
cost_range,
COUNT(product_key) AS total_products
FROM product_segments
GROUP BY cost_range
ORDER BY total_products DESC




/* Group customers into three segments based on their spending behavior:
   -- VIP: Customers with at least 12 months of history and spending more than €5,000.
   -- Regular: Customers with at least 12 months of history but spending €5,000 or less.
   -- New: Customers with a lifespan less than 12 months.
  And find the total number of customers by each group
*/
WITH customer_spending AS (
SELECT 
c.customer_key,
SUM(f.sales_amount) AS total_spending,
MIN(f.order_date) AS first_order,
MAX(f.order_date) AS last_order,
DATEDIFF(month, MIN(order_date), MAX(order_date)) AS lifespan
FROM gold.fact_sales f
LEFT JOIN gold.dim_customers c
ON f.customer_key = c.customer_key
GROUP BY c.customer_key )

SELECT
customer_segment,
COUNT(customer_key) AS total_customers
FROM(
SELECT
customer_key,
--total_spending,
--lifespan,
CASE WHEN lifespan >= 12 AND total_spending > 5000 THEN 'VIP'
	 WHEN lifespan >= 12 AND total_spending <= 5000 THEN 'Regular'
	 ELSE 'New'
END AS customer_segment
FROM customer_spending ) t
GROUP BY customer_segment
ORDER BY total_customers DESC


