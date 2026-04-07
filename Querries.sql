/* ==========================================================================
CAPSTONE PROJECT: Inventory and Order Management System
STEP 3: Data Manipulation Language (DML) & Advanced SQL
==========================================================================
*/

-- -----------------------------------------------------------------------
-- 1. SAMPLE DATA POPULATION (SEEDING)
-- -----------------------------------------------------------------------
-- Note: We insert data in order of dependency (Parents first, then Children)
TRUNCATE TABLE inventory, orders, products, customers RESTART IDENTITY CASCADE;

-- 1. Insert customers
INSERT INTO customers (full_name, email, shipping_address) VALUES
('Alice Johnson', 'alice@example.com', '123 Maple St'),
('Bob Smith', 'bob@example.com', '456 Oak Ave'),
('Charlie Brown', 'charlie@example.com', '789 Pine Rd');

-- 2. Insert products
INSERT INTO products (product_name, category, price) VALUES
('Laptop', 'Electronics', 1000.00),
('Mouse', 'Electronics', 50.00),
('Hoodie', 'Apparel', 60.00),
('Jeans', 'Apparel', 80.00),
('SQL Book', 'Books', 40.00);

-- 3. Insert inventory 
INSERT INTO inventory (product_id, quantity_on_hand)
SELECT product_id,
       CASE product_name
           WHEN 'Laptop' THEN 10
           WHEN 'Mouse' THEN 100
           WHEN 'Hoodie' THEN 50
           WHEN 'Jeans' THEN 40
           WHEN 'SQL Book' THEN 30
       END
FROM products;

-- 4. Insert orders 

INSERT INTO orders (customer_id, order_date, total_amount, status)
SELECT customer_id, order_date, total_amount, status
FROM (
    VALUES
    ('Alice Johnson', TIMESTAMP '2026-01-15 00:00:00', 1050.00, 'Delivered'),
    ('Bob Smith', TIMESTAMP '2026-01-20 00:00:00', 60.00, 'Shipped'),
    ('Alice Johnson', TIMESTAMP '2026-02-10 00:00:00', 50.00, 'Delivered'),
    ('Charlie Brown', TIMESTAMP '2026-02-15 00:00:00', 140.00, 'Pending')
) AS temp(full_name, order_date, total_amount, status)
JOIN customers USING (full_name);

-- -----------------------------------------------------------------------
-- 2. BUSINESS KPIs
-- -----------------------------------------------------------------------

-- KPI: Total Revenue (Only from Shipped or Delivered orders)
SELECT SUM(total_amount) AS total_revenue
FROM orders
WHERE status IN ('Shipped', 'Delivered');

-- KPI: Top 10 Customers by Total Spending
SELECT c.full_name AS customer_name, SUM(o.total_amount) AS total_amount_spent
FROM customers c
JOIN orders o ON c.customer_id = o.customer_id
GROUP BY c.customer_id, c.full_name
ORDER BY total_amount_spent DESC
LIMIT 10;

-- KPI: Best-Selling Products (Top 5 by Quantity)
SELECT p.product_name, SUM(oi.quantity) AS total_quantity_sold
FROM products p
JOIN order_items oi ON p.product_id = oi.product_id
GROUP BY p.product_id, p.product_name
ORDER BY total_quantity_sold DESC
LIMIT 5;

-- KPI: Monthly Sales Trend
SELECT 
    TO_CHAR(order_date, 'YYYY-MM') AS sales_month, 
    SUM(total_amount) AS monthly_revenue
FROM orders
GROUP BY sales_month
ORDER BY sales_month;


-- -----------------------------------------------------------------------
-- 3. ANALYTICAL QUERIES (WINDOW FUNCTIONS)
-- -----------------------------------------------------------------------

-- Sales Rank by Category: Ranks products within their specific category by revenue
SELECT 
    category, 
    product_name, 
    SUM(oi.quantity * oi.price_at_purchase) AS total_revenue,
    RANK() OVER (PARTITION BY category ORDER BY SUM(oi.quantity * oi.price_at_purchase) DESC) AS category_rank
FROM products p
JOIN order_items oi ON p.product_id = oi.product_id
GROUP BY category, product_name;

-- Customer Order Frequency: Shows the time gap between a customer's orders
SELECT 
    customer_id,
    order_date AS current_order_date,
    LAG(order_date) OVER (PARTITION BY customer_id ORDER BY order_date) AS previous_order_date
FROM orders;


-- -----------------------------------------------------------------------
-- 4. PERFORMANCE OPTIMIZATION (VIEWS & STORED PROCEDURES)
-- -----------------------------------------------------------------------

-- VIEW: CustomerSalesSummary
-- Simplifies reporting by pre-calculating customer lifetime value (LTV)
CREATE OR REPLACE VIEW CustomerSalesSummary AS
SELECT c.customer_id, c.full_name, SUM(o.total_amount) AS total_spent
FROM customers c
LEFT JOIN orders o ON c.customer_id = o.customer_id
GROUP BY c.customer_id, c.full_name;

-- STORED PROCEDURE: ProcessNewOrder
-- Handles order creation logic, inventory updates, and transaction safety
CREATE OR REPLACE PROCEDURE ProcessNewOrder(
    p_customer_id INT,
    p_product_id INT,
    p_quantity INT
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_stock INT;
    v_price DECIMAL(10,2);
    v_new_order_id INT;
BEGIN
    -- Check if product exists and get price/stock
    SELECT quantity_on_hand INTO v_stock FROM inventory WHERE product_id = p_product_id;
    SELECT price INTO v_price FROM products WHERE product_id = p_product_id;

    -- Validation: Ensure stock is sufficient
    IF v_stock < p_quantity OR v_stock IS NULL THEN
        RAISE EXCEPTION 'Transaction Aborted: Insufficient stock for Product ID %', p_product_id;
    END IF;

    -- Update Inventory (Decrease stock)
    UPDATE inventory 
    SET quantity_on_hand = quantity_on_hand - p_quantity 
    WHERE product_id = p_product_id;

    -- Create Order Header
    INSERT INTO orders (customer_id, order_date, total_amount, status)
    VALUES (p_customer_id, CURRENT_TIMESTAMP, (v_price * p_quantity), 'Pending')
    RETURNING order_id INTO v_new_order_id;

    -- Create Order Line Item
    INSERT INTO order_items (order_id, product_id, quantity, price_at_purchase)
    VALUES (v_new_order_id, p_product_id, p_quantity, v_price);

    -- If all steps succeed, Postgres will commit the transaction automatically
    RAISE NOTICE 'Order % successfully processed.', v_new_order_id;
END;
$$;

/* -- TO TEST THE PROCEDURE:
-- CALL ProcessNewOrder(1, 1, 1); 
*/