
#                                                           Purchase Frequency:
/*
Question 1: Identify trends in order frequency over time. Are there customers whose purchase frequency sharply declines before churn?

We can analyze the order frequency for each customer over time and identify any patterns where the purchase frequency sharply 
declines before churn. This can be done by calculating the time gap between consecutive orders for each customer and observing 
any significant changes in this gap before they stop making purchases.
*/
WITH OrderFrequency AS (
    SELECT 
        customer_id,
        order_date,
        LAG(order_date) OVER (PARTITION BY customer_id ORDER BY order_date) AS prev_order_date,
        DATEDIFF(order_date, LAG(order_date) OVER (PARTITION BY customer_id ORDER BY order_date)) AS time_gap
    FROM Orders
)
SELECT 
    customer_id,
    AVG(time_gap) AS average_time_gap
FROM OrderFrequency
GROUP BY customer_id
order by average_time_gap desc;

/*
This query calculates the average time gap between consecutive orders for each customer. We can then analyze this data to identify 
customers whose purchase frequency sharply declines before churn.
*/


/*
Question 2: Calculate metrics like average time between orders for different customer segments (e.g., frequent vs. infrequent buyers).

To calculate metrics like the average time between orders for different customer segments, we can classify customers into segments 
based on their order frequency (e.g., frequent buyers, infrequent buyers) and then calculate the average time between orders for 
each segment.

*/

WITH OrderFrequency AS (
    SELECT 
        customer_id,
        order_date,
        LAG(order_date) OVER (PARTITION BY customer_id ORDER BY order_date) AS prev_order_date,
        DATEDIFF(order_date, LAG(order_date) OVER (PARTITION BY customer_id ORDER BY order_date)) AS time_gap
    FROM Orders
),
CustomerSegments AS (
    SELECT 
        customer_id,
        CASE 
            WHEN AVG(time_gap) <= 30 THEN 'Frequent Buyer'
            WHEN AVG(time_gap) <= 90 THEN 'Regular Buyer'
            ELSE 'Infrequent Buyer'
        END AS segment
    FROM OrderFrequency
    GROUP BY customer_id
)
SELECT 
    segment,
    AVG(time_gap) AS average_time_gap
FROM OrderFrequency o
JOIN CustomerSegments cs ON o.customer_id = cs.customer_id
GROUP BY segment;

/*
This query classifies customers into segments based on their average time gap between orders and calculates the average time gap
 for each segment. It categorizes customers as frequent, regular, or infrequent buyers based on their purchase frequency.
*/

#                                                               Order Size:

/*
Question 3: Analyze average order value for churning and non-churning customers. Do customers typically reduce their order 
size before churning?

We'll compare the average order value between churning and non-churning customers to see if there's a noticeable difference 
and whether customers tend to reduce their order size before churning.
*/

WITH ChurnStatus AS (
    SELECT
        c.id,
        CASE
            WHEN o.customer_id IS NOT NULL THEN 'Non-Churning'
            ELSE 'Churning'
        END AS churn_status
    FROM Customers c
    LEFT JOIN Orders o ON c.id = o.customer_id
),
OrderValue AS (
    SELECT
        o.customer_id,
        SUM(od.quantity * od.unit_price) AS order_value
    FROM Orders o
    JOIN Order_Details od ON o.id = od.order_id
    GROUP BY o.customer_id
)
SELECT
    cs.churn_status,
    AVG(ov.order_value) AS avg_order_value
FROM ChurnStatus cs
JOIN OrderValue ov ON cs.id = ov.customer_id
GROUP BY cs.churn_status;


/*
This query compares the average order value between churning and non-churning customers. By analyzing the results, we can determine 
if there's a noticeable difference in order size before churning.
*/




/*
Question 4: Explore the distribution of order value. Are there customer groups consistently placing smaller orders, potentially 
indicating a higher churn risk?

/*
We'll explore the distribution of order values across different customer groups to identify if there are consistent patterns of 
smaller orders, which could indicate a higher churn risk.
*/

WITH OrderValueDistribution AS (
    SELECT
        c.id,
        SUM(od.quantity * od.unit_price) AS order_value
    FROM Customers c
    LEFT JOIN Orders o ON c.id = o.customer_id
    LEFT JOIN Order_Details od ON o.id = od.order_id
    GROUP BY c.id
)
SELECT
    CASE
        WHEN order_value <= 1000 THEN 'Low Order Value'
        WHEN order_value <= 5000 THEN 'Medium Order Value'
        ELSE 'High Order Value'
    END AS order_value_category,
    COUNT(id) AS customer_count
FROM OrderValueDistribution
GROUP BY order_value_category;



#                                                          Product Categories:

/*
This query categorizes customers based on the total value of their orders and counts the number of customers falling into different 
order value categories. By analyzing the distribution, we can identify if there are consistent groups of customers placing smaller 
orders, indicating a potentially higher churn risk.
*/


/*
Question 5: Identify changes in product category preferences for customers who churn. Do they stop buying specific categories altogether?
*/

/*
We'll examine the product categories purchased by customers before and after they churn to identify if there are any categories they
stop buying altogether.
*/

SELECT DISTINCT c.id AS customer_id,
       c.company AS customer_name,
       p.category AS churned_category,
       CASE WHEN o.id IS NULL THEN 'Churned' ELSE 'Active' END AS churn_status
FROM customers c
LEFT JOIN orders o ON c.id = o.customer_id
LEFT JOIN order_details od ON o.id = od.order_id
LEFT JOIN products p ON od.product_id = p.id
WHERE c.id IN (SELECT customer_id FROM orders WHERE status_id = 3) -- Churned customers
AND p.category NOT IN (
    SELECT DISTINCT p.category
    FROM customers c
    JOIN orders o ON c.id = o.customer_id
    JOIN order_details od ON o.id = od.order_id
    JOIN products p ON od.product_id = p.id
    WHERE c.id NOT IN (SELECT customer_id FROM orders WHERE status_id = 3) -- Active customers
);





/*
This query compares the product categories purchased by churning and non-churning customers, counting the number of distinct products 
in each category. By analyzing the results, we can identify if there are any categories that churning customers stop buying altogether.
*/


/*
Question 6: Analyze the most frequently purchased categories before and after churn events. Did their buying habits shift towards 
different product lines?
*/

/*
To analyze the most frequently purchased categories before and after churn events and determine if there's a shift in buying habits 
towards different product lines, we need to compare the frequency of purchases in each category for churned customers and 
active customers.
*/

WITH churned_customers AS (
    SELECT DISTINCT customer_id
    FROM orders
    WHERE status_id = 3
)
SELECT p.category,
       COUNT(CASE WHEN o.customer_id IN (SELECT customer_id FROM churned_customers) THEN o.id END) AS churned_count,
       COUNT(CASE WHEN o.customer_id NOT IN (SELECT customer_id FROM churned_customers) THEN o.id END) AS active_count
FROM orders o
JOIN order_details od ON o.id = od.order_id
JOIN products p ON od.product_id = p.id
GROUP BY p.category
ORDER BY churned_count DESC;


# Solution 2 


WITH churned_customers AS (
    SELECT DISTINCT customer_id
    FROM orders
    WHERE status_id = 3
),
churned_category_counts AS (
    SELECT p.category,
           COUNT(*) AS churned_count
    FROM orders o
    JOIN order_details od ON o.id = od.order_id
    JOIN products p ON od.product_id = p.id
    WHERE o.customer_id IN (SELECT customer_id FROM churned_customers)
    GROUP BY p.category
),
active_category_counts AS (
    SELECT p.category,
           COUNT(*) AS active_count
    FROM orders o
    JOIN order_details od ON o.id = od.order_id
    JOIN products p ON od.product_id = p.id
    WHERE o.customer_id NOT IN (SELECT customer_id FROM churned_customers)
    GROUP BY p.category
)
SELECT cc.category,
       cc.churned_count,
       ac.active_count
FROM churned_category_counts cc
JOIN active_category_counts ac ON cc.category = ac.category
ORDER BY cc.churned_count DESC, ac.active_count DESC;


/*This query calculates the count of orders in each product category for churned customers and active customers separately. It then 
combines the counts for each category using a full outer join to compare the frequencies before and after churn events.
*/

#                                                     Geographical Insights:

/*
Question 7: Leverage customer location data (if available) to investigate churn rates by region. Are there specific locations with 
higher churn?
*/

# To investigate churn rates by region and explore correlations between location and purchase behavior, we can use SQL to analyze 
# customer data based on their geographical information.


WITH churned_customers AS (
    SELECT DISTINCT customer_id
    FROM orders
    WHERE status_id IN (
        SELECT id FROM orders_status WHERE status_name = 'Closed' OR status_name = 'Shipped'
    )
),
customer_locations AS (
    SELECT c.id,
           c.company,
           c.city,
           c.state_province,
           c.country_region,
           CASE WHEN cc.customer_id IS NOT NULL THEN 'Churned' ELSE 'Active' END AS customer_status
    FROM customers c
    LEFT JOIN churned_customers cc ON c.id = cc.customer_id
)
SELECT country_region,
       state_province,
       city,
       COUNT(CASE WHEN customer_status = 'Churned' THEN 1 END) AS churned_count,
       COUNT(CASE WHEN customer_status = 'Active' THEN 1 END) AS active_count,
       ROUND((COUNT(CASE WHEN customer_status = 'Churned' THEN 1 END) * 100.0) / COUNT(*), 2) AS churn_rate
FROM customer_locations
GROUP BY country_region, state_province, city
ORDER BY churn_rate DESC;

/*
The churned customers are identified based on the closed or shipped status of their orders, as these could indicate that the customer 
has churned.This query calculates the churn rates by region (country, state/province, city) based on the number of churned and active 
customers.
*/


/*
Question 8: Explore correlations between location and purchase behavior. Do buying patterns differ significantly across regions?
*/

SELECT 
    c.country_region,
    c.state_province,
    c.city,
    COUNT(o.id) AS total_orders,
    SUM(od.quantity) AS total_quantity,
    SUM(od.quantity * od.unit_price) AS total_revenue
FROM 
    customers c
JOIN 
    orders o ON c.id = o.customer_id
JOIN 
    order_details od ON o.id = od.order_id
GROUP BY 
    c.country_region, c.state_province, c.city
ORDER BY 
    c.country_region, c.state_province, c.city;
    
/*
This query retrieves the total number of orders, total quantity purchased, and total revenue generated for each region 
(country, state, city). It joins the customers, orders, and order_details tables to gather this information. By analyzing the 
output of this query, you can identify any significant differences in buying patterns across different regions.
*/


#                                                        Predicting Churn:


/*
Question 9: Assign a "risk score" to each customer based on factors like purchase frequency decline, reduced order value, or specific 
product category abandonment.
*/


SELECT 
    c.id AS customer_id,
    c.company AS company_name,
    COUNT(o.id) AS total_orders,
    SUM(od.quantity * od.unit_price) AS total_spent,
    CASE 
        WHEN COUNT(o.id) >= 7 AND SUM(od.quantity * od.unit_price) >= 1000 THEN 'Low Risk'
        WHEN COUNT(o.id) BETWEEN 4 AND 7 AND SUM(od.quantity * od.unit_price) BETWEEN 500 AND 999 THEN 'Medium Risk'
        ELSE 'High Risk'
    END AS risk_category
FROM 
    customers c
LEFT JOIN 
    orders o ON c.id = o.customer_id
LEFT JOIN 
    order_details od ON o.id = od.order_id
GROUP BY 
    c.id, c.company
ORDER BY 
    total_orders DESC, total_spent DESC;


/*
We segmented customers based on their order frequency and total spending. Customers were categorized into "Low Risk," "Medium Risk," 
or "High Risk" based on predefined thresholds for order count and total spending.
By segmenting customers based on their order behavior and spending patterns and assigning risk categories, we can develop a 
churn prediction model that helps prioritize retention efforts and reduce customer churn.
*/



/*
Question 10: Utilize customer lifetime value (CLTV) calculations to prioritize retention efforts. Customers with high CLTV who 
exhibit concerning behavior patterns might require immediate intervention.
*/


-- Step 1: Calculate customer order frequency over the last 6 months
SELECT
    c.id AS customer_id,
    COUNT(DISTINCT o.id) AS total_orders_last_6_months
FROM
    customers c
LEFT JOIN
    orders o ON c.id = o.customer_id
WHERE
    o.order_date >= DATE_SUB((SELECT MAX(order_date) FROM orders), INTERVAL 6 MONTH)
GROUP BY
    c.id;



-- Step 2: Identify customers with a decrease in order frequency
SELECT
    c.id AS customer_id,
    c.company,
    COUNT(DISTINCT o.id) AS total_orders
FROM
    customers c
JOIN
    orders o ON c.id = o.customer_id
WHERE
    o.order_date >= DATE_SUB((SELECT MAX(order_date) FROM orders), INTERVAL 6 MONTH)
GROUP BY
    c.id, c.company
HAVING
    COUNT(DISTINCT o.id) < (SELECT AVG(order_count) FROM (
                                SELECT
                                    c.id AS customer_id,
                                    COUNT(DISTINCT o.id) AS order_count
                                FROM
                                    customers c
                                JOIN
                                    orders o ON c.id = o.customer_id
                                WHERE
                                    o.order_date >= DATE_SUB((SELECT MAX(order_date) FROM orders), INTERVAL 6 MONTH)
                                GROUP BY
                                    c.id
                            ) AS order_counts);


-- Step 3: Calculate Customer Lifetime Value (CLTV)

SELECT
    c.id AS customer_id,
    ROUND(SUM(od.quantity * od.unit_price * (1 - od.discount)) - SUM(o.shipping_fee + o.taxes), 2) AS cltv
FROM
    customers c
JOIN
    orders o ON c.id = o.customer_id
JOIN
    order_details od ON o.id = od.order_id
GROUP BY
    c.id;
    

/*
To predict churn and prioritize retention efforts , we followed a three-step approach:

Step 1: Calculate customer order frequency over the last 6 months:
We retrieved the count of distinct orders for each customer within the last 6 months. This step helps us understand how frequently 
customers are making purchases recently.

Step 2: Identify customers with a decrease in order frequency:
By comparing the current order frequency of each customer with the average order frequency of all customers, we identified 
those who show a decrease in order frequency. This decrease might indicate a concerning behavior pattern and a potential churn risk.

Step 3: Calculate Customer Lifetime Value (CLTV):
CLTV is a crucial metric for identifying high-value customers. We calculated CLTV by summing the total revenue generated from each 
customer's orders and subtracting the associated costs (shipping fees and taxes). Customers with a high CLTV are valuable to the 
business and might require special attention to retain them.


These steps provides a comprehensive churn prediction model, incorporating customer order frequency, identifying customers with a decrease 
in order frequency, and calculating Customer Lifetime Value (CLTV). 
*/
