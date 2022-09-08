CREATE SCHEMA dannys_diner;
USE dannys_diner;

CREATE TABLE sales(
customer_id VARCHAR(1),
order_date DATE,
product_id INT
);

INSERT INTO sales
  (customer_id, order_date, product_id)
VALUES
  ('A', '2021-01-01', 1),
  ('A', '2021-01-01', 2),
  ('A', '2021-01-07', 2),
  ('A', '2021-01-10', 3),
  ('A', '2021-01-11', 3),
  ('A', '2021-01-11', 3),
  ('B', '2021-01-01', 2),
  ('B', '2021-01-02', 2),
  ('B', '2021-01-04', 1),
  ('B', '2021-01-11', 1),
  ('B', '2021-01-16', 3),
  ('B', '2021-02-01', 3),
  ('C', '2021-01-01', 3),
  ('C', '2021-01-01', 3),
  ('C', '2021-01-07', 3);
 

CREATE TABLE menu (
product_id INT,
product_name VARCHAR(5),
price INT
);

INSERT INTO menu
  (product_id, product_name, price)
VALUES
  (1, 'sushi', 10),
  (2, 'curry', 15),
  (3, 'ramen', 12);
  

CREATE TABLE members (
customer_id VARCHAR(1),
join_date DATE
);

INSERT INTO members
  (customer_id, join_date)
VALUES
  ('A', '2021-01-07'),
  ('B', '2021-01-09');
  
  
###################################################################

-- 1. What is the total amount each customer spent at the restaurant?
SELECT customer_id, SUM(price) AS 'amount spent'
FROM sales
LEFT JOIN menu
ON
	sales.product_id = menu.product_id
GROUP BY customer_id;

-- 2. How many days has each customer visited the restaurant?
SELECT customer_id, COUNT(DISTINCT order_date) AS days
FROM sales
GROUP BY customer_id;

-- 3. What was the first item from the menu purchased by each customer?
SELECT customer_id, product_id AS first_item
FROM sales
WHERE order_date IN (SELECT MIN(DATE(order_date)) FROM sales GROUP BY customer_id)
GROUP BY customer_id;

-- 4. What is the most purchased item on the menu and how many times 
--    was it purchased by all customers?
WITH cte1 AS
		(SELECT product_id, COUNT(product_id) AS total_purchased
		FROM sales
		GROUP BY product_id)
SELECT product_id
FROM cte1
WHERE total_purchased = (SELECT MAX(total_purchased) FROM cte1);

-- 5. Which item was the most popular for each customer?
WITH count_cte AS
		(SELECT customer_id, product_id ,COUNT(product_id) AS purchased_times
		FROM sales
		GROUP BY customer_id, product_id),
	rank_cte AS
		(SELECT customer_id, product_id,
				RANK() OVER(PARTITION BY customer_id ORDER BY purchased_times DESC) AS most_ordered
		FROM count_cte)
SELECT customer_id, product_id AS popular_product 
FROM rank_cte
WHERE most_ordered = 1;

-- 6. Which item was purchased first by the customer after they became 
-- 	  a member?
SELECT sales.customer_id, product_id, MIN(DATE(sales.order_date)) AS date
FROM sales
JOIN members
ON 
	sales.customer_id = members.customer_id
    AND sales.order_date >= members.join_date
GROUP BY sales.customer_id
HAVING MIN(DATE(sales.order_date));

WITH cte AS
	(SELECT sales.*, 
		RANK() OVER(PARTITION BY customer_id ORDER BY order_date ) AS first_date
	FROM sales
	JOIN members
	ON 
		sales.customer_id = members.customer_id
		AND sales.order_date >= members.join_date)
SELECT customer_id, order_date, product_id
FROM cte
WHERE first_date = 1;

-- 7. Which item was purchased just before the customer became a member?
WITH cte AS
	(SELECT sales.*, 
		RANK() OVER(PARTITION BY customer_id ORDER BY order_date DESC) AS last_date
	FROM sales
	JOIN members
	ON 
		sales.customer_id = members.customer_id
		AND sales.order_date < members.join_date)
SELECT customer_id, order_date, product_id
FROM cte
WHERE last_date = 1;

-- 8. What is the total items and amount spent for each member before 
--    they became a member?
SELECT sales.customer_id, COUNT(sales.product_id) AS 'total items',
		SUM(price) AS 'amount spent'
FROM sales
JOIN members
ON 
	sales.customer_id = members.customer_id
	AND sales.order_date < members.join_date
JOIN menu
ON
	sales.product_id = menu.product_id
GROUP BY sales.customer_id;
    
-- 9. If each $1 spent equates to 10 points and sushi has a 2x points 
--    multiplier - how many points would each customer have?
WITH point_cte AS 
		(SELECT *,
				CASE WHEN product_name = 'sushi' THEN 20*price 
				ELSE 10*price END AS points
		FROM menu)
SELECT customer_id, SUM(points) AS total_points
FROM sales 
JOIN point_cte
ON
	sales.product_id = point_cte.product_id
GROUP BY customer_id;

-- 10. In the first week after a customer joins the program 
--     (including their join date) they earn 2x points on all items, 
--     not just sushi - how many points do customer A and B have at the 
--     end of January?
WITH points_cte AS
		(SELECT sales.*,price, 
				CASE WHEN sales.order_date BETWEEN members.join_date AND DATE_ADD(members.join_date, INTERVAL 1 WEEK)
				 THEN price*20 
				 ELSE CASE WHEN menu.product_name = 'sushi' THEN 20*price ELSE 10*price END  
				 END AS points
		FROM sales
		JOIN members
		ON 
			sales.customer_id = members.customer_id
			AND sales.order_date >= members.join_date
		JOIN menu
		ON
			sales.product_id = menu.product_id)
SELECT customer_id, SUM(points) AS total_points
FROM points_cte
WHERE MONTH(order_date) = 1
GROUP BY customer_id;


-- BONUS QUESTIONS
-- 1. Join All The Things
SELECT sales.customer_id, 
		order_date,
        product_name,
        price,
        CASE WHEN sales.order_date >= members.join_date THEN 'Y' ELSE 'N' END AS member
FROM sales
LEFT JOIN members
ON
	sales.customer_id = members.customer_id
JOIN menu
ON 
	sales.product_id = menu.product_id;
    
-- 2. Rank All The Things
WITH cte AS
	(SELECT sales.customer_id, 
			order_date,
			product_name,
			price,
			CASE 
				WHEN sales.order_date >= members.join_date THEN 'Y' ELSE 'N' 
			END AS member
	FROM sales
	LEFT JOIN members
	ON
		sales.customer_id = members.customer_id
	JOIN menu
	ON 
		sales.product_id = menu.product_id)
SELECT 
	customer_id, 
	order_date,
	product_name,
	price,
    member,
	CASE 
		WHEN member = 'Y' 
		THEN RANK() OVER(PARTITION BY customer_id,member ORDER BY order_date) 
		ELSE NULL 
	END AS ranking
FROM cte;





