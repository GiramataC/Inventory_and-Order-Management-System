/* ========================================================================
DML & PROCEDURES: Inventory and Order Management System
======================================================================== */

-- =================
-- 1. DATA SEEDING 
-- =================

BEGIN TRANSACTION;

    TRUNCATE TABLE 
        "payments",
        "order_items",
        "orders",
        "inventory",
        "products",
        "customers"
    RESTART IDENTITY CASCADE;


    -- ========================================================================
    -- 1. CUSTOMERS (PARENT TABLE)
    -- ========================================================================
    INSERT INTO "customers" ("full_name", "email", "phone", "shipping_address")
    VALUES
    ('Alice Johnson', 'alice@example.com', '+1-555-0101', '123 Maple St, Springfield'),
    ('Bob Smith', 'bob@example.com', '+1-555-0102', '456 Oak Ave, Springfield'),
    ('Charlie Brown', 'charlie@example.com', '+1-555-0103', '789 Pine Rd, Springfield'),
    ('Diana Prince', 'diana@example.com', '+1-555-0104', '321 Elm St, Springfield'),
    ('Eve Wilson', 'eve@example.com', '+1-555-0105', '654 Birch Blvd, Springfield');


    -- ========================================================================
    -- 2. PRODUCTS (PARENT TABLE)
    -- ========================================================================
    INSERT INTO "products" ("product_name", "category", "price")
    VALUES
    ('Laptop Pro', 'Electronics', 1299.99),
    ('USB Mouse', 'Electronics', 49.99),
    ('Wireless Keyboard', 'Electronics', 89.99),
    ('Cotton Hoodie', 'Apparel', 59.99),
    ('Denim Jeans', 'Apparel', 79.99),
    ('SQL Mastery Book', 'Books', 39.99),
    ('Database Design Guide', 'Books', 49.99),
    ('Monitor Stand', 'Accessories', 34.99);


    -- ========================================================================
    -- 3. INVENTORY (DEPENDENT ON PRODUCTS)
    -- ========================================================================
    INSERT INTO "inventory" ("product_id", "quantity_on_hand", "reorder_level")
    SELECT 
        p.product_id,
        CASE p.product_name
            WHEN 'Laptop Pro' THEN 15
            WHEN 'USB Mouse' THEN 250
            WHEN 'Wireless Keyboard' THEN 120
            WHEN 'Cotton Hoodie' THEN 80
            WHEN 'Denim Jeans' THEN 100
            WHEN 'SQL Mastery Book' THEN 45
            WHEN 'Database Design Guide' THEN 30
            WHEN 'Monitor Stand' THEN 60
        END,
        CASE p.product_name
            WHEN 'Laptop Pro' THEN 5
            WHEN 'USB Mouse' THEN 50
            WHEN 'Wireless Keyboard' THEN 30
            WHEN 'Cotton Hoodie' THEN 20
            WHEN 'Denim Jeans' THEN 25
            WHEN 'SQL Mastery Book' THEN 10
            WHEN 'Database Design Guide' THEN 8
            WHEN 'Monitor Stand' THEN 15
        END
    FROM "products" p;


    -- ========================================================================
    -- 4. ORDERS (DEPEND ON CUSTOMERS)
    -- ========================================================================
    INSERT INTO "orders" ("customer_id", "order_date", "total_amount", "status")
    VALUES
    (1, '2026-01-15 10:30:00', 1349.97, 'Delivered'),
    (2, '2026-01-20 14:15:00', 139.97, 'Shipped'),
    (1, '2026-02-10 09:45:00', 69.99, 'Delivered'),
    (3, '2026-02-15 16:20:00', 229.95, 'Processing'),
    (4, '2026-03-05 11:00:00', 1389.96, 'Pending'),
    (2, '2026-03-10 13:30:00', 89.99, 'Delivered'),
    (5, '2026-03-15 15:45:00', 179.97, 'Shipped');


    -- ========================================================================
    -- 5. ORDER ITEMS (DEPEND ON ORDERS + PRODUCTS)
    -- ========================================================================
    INSERT INTO "order_items" ("order_id", "product_id", "quantity", "price_at_purchase")
    VALUES
    (1, 1, 1, 1299.99),
    (1, 2, 1, 49.99),

    (2, 3, 1, 89.99),
    (2, 2, 1, 49.99),

    (3, 4, 1, 59.99),

    (4, 5, 1, 79.99),
    (4, 6, 2, 39.99),

    (5, 1, 1, 1299.99),
    (5, 8, 1, 34.99),
    (5, 2, 1, 49.99),

    (6, 3, 1, 89.99),

    (7, 5, 1, 79.99),
    (7, 4, 1, 59.99),
    (7, 7, 1, 49.99);


    -- ========================================================================
    -- 6. PAYMENTS (DEPEND ON ORDERS)
    -- ========================================================================
    INSERT INTO "payments"
    ("order_id", "amount_paid", "payment_method", "payment_status", "payment_date")
    VALUES
    (1, 1349.97, 'Card', 'Completed', '2026-01-15 10:35:00'),
    (2, 139.97, 'Mobile Money', 'Completed', '2026-01-20 14:20:00'),
    (3, 69.99, 'Card', 'Completed', '2026-02-10 09:50:00'),
    (4, 100.00, 'Mobile Money', 'Partial', '2026-02-15 16:25:00'),
    (5, 0.00, 'Card', 'Pending', NULL),
    (6, 89.99, 'Card', 'Completed', '2026-03-10 13:35:00'),
    (7, 179.97, 'Mobile Money', 'Completed', '2026-03-15 15:50:00');

COMMIT;

-- ========================================================================
-- 2. STORED PROCEDURES
-- ========================================================================

-- ========================================================================
-- PROCEDURE: ProcessNewOrder (Complete version with error handling)
-- Purpose: Create a new order with inventory validation and transaction safety
-- Parameters: p_customer_id, p_product_id, p_quantity
-- Returns: p_order_id (success) or error
-- ========================================================================
CREATE OR REPLACE FUNCTION "ProcessNewOrder"(
    p_customer_id INT,
    p_product_id INT,
    p_quantity INT
)
RETURNS TABLE (
    result_order_id INT,
    result_error_message VARCHAR
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_stock INT;
    v_price DECIMAL(10,2);
    v_customer_exists BOOLEAN;
    v_product_active BOOLEAN;
    v_total_amount DECIMAL(10,2);
BEGIN
    result_order_id := NULL;
    result_error_message := NULL;

    -- Validate customer
    SELECT EXISTS (
        SELECT 1
        FROM "customers"
        WHERE "customer_id" = p_customer_id
          AND "is_active" = true
    ) INTO v_customer_exists;

    IF NOT v_customer_exists THEN
        result_error_message := 'ERR_INVALID_CUSTOMER';
        RETURN NEXT;
        RETURN;
    END IF;

    -- Validate product
    SELECT "is_active"
    INTO v_product_active
    FROM "products"
    WHERE "product_id" = p_product_id;

    IF v_product_active IS NULL THEN
        result_error_message := 'ERR_INVALID_PRODUCT';
        RETURN NEXT;
        RETURN;
    ELSIF NOT v_product_active THEN
        result_error_message := 'ERR_PRODUCT_INACTIVE';
        RETURN NEXT;
        RETURN;
    END IF;

    -- Validate quantity
    IF p_quantity <= 0 THEN
        result_error_message := 'ERR_INVALID_QUANTITY';
        RETURN NEXT;
        RETURN;
    END IF;

    -- Get price
    SELECT "price"
    INTO v_price
    FROM "products"
    WHERE "product_id" = p_product_id;

    -- Check stock
    SELECT "quantity_on_hand"
    INTO v_stock
    FROM "inventory"
    WHERE "product_id" = p_product_id
    FOR UPDATE;

    IF v_stock IS NULL THEN
        result_error_message := 'ERR_NO_INVENTORY';
        RETURN NEXT;
        RETURN;
    ELSIF v_stock < p_quantity THEN
        result_error_message := 'ERR_INSUFFICIENT_STOCK';
        RETURN NEXT;
        RETURN;
    END IF;

    v_total_amount := v_price * p_quantity;

    -- Create order
    INSERT INTO "orders" (
        "customer_id",
        "order_date",
        "total_amount",
        "status"
    )
    VALUES (
        p_customer_id,
        CURRENT_TIMESTAMP,
        v_total_amount,
        'Pending'
    )
    RETURNING "order_id" INTO result_order_id;

    -- Create order item
    INSERT INTO "order_items" (
        "order_id",
        "product_id",
        "quantity",
        "price_at_purchase"
    )
    VALUES (
        result_order_id,
        p_product_id,
        p_quantity,
        v_price
    );

    -- Update inventory
    UPDATE "inventory"
    SET "quantity_on_hand" = "quantity_on_hand" - p_quantity,
        "updated_at" = CURRENT_TIMESTAMP
    WHERE "product_id" = p_product_id;

    RETURN NEXT;
END;
$$;


-- ========================================================================
-- PROCEDURE: UpdateProductPrice (With audit logging)
-- Purpose: Update product price with audit trail
-- ========================================================================
CREATE OR REPLACE FUNCTION "UpdateProductPrice"(
    p_product_id INT,
    p_new_price DECIMAL(10,2)
)
RETURNS TABLE(success BOOLEAN, message VARCHAR)
LANGUAGE plpgsql
AS $$
DECLARE
    v_old_price DECIMAL(10,2);
BEGIN

    -- Check if product exists
    SELECT "price"
    INTO v_old_price
    FROM "products"
    WHERE "product_id" = p_product_id;

    IF v_old_price IS NULL THEN
        RETURN QUERY SELECT FALSE, 'Product not found'::VARCHAR;
        RETURN;
    END IF;

    -- Validate new price
    IF p_new_price <= 0 THEN
        RETURN QUERY SELECT FALSE, 'Invalid price (must be > 0)'::VARCHAR;
        RETURN;
    END IF;

    -- Update product price
    UPDATE "products"
    SET "price" = p_new_price,
        "updated_at" = CURRENT_TIMESTAMP
    WHERE "product_id" = p_product_id;

    -- Audit log
    INSERT INTO "audit_log" (
        "table_name",
        "operation",
        "record_id",
        "old_values",
        "new_values"
    )
    VALUES (
        'products',
        'UPDATE',
        p_product_id,
        jsonb_build_object('price', v_old_price),
        jsonb_build_object('price', p_new_price)
    );

    -- Return success (FIXED)
    RETURN QUERY 
    SELECT TRUE,
           ('Price updated from ' || v_old_price || ' to ' || p_new_price)::VARCHAR;

END;
$$;


-- ========================================================================
-- PROCEDURE: RestockInventory (With low stock alerts)
-- Purpose: Replenish inventory with validation
-- ========================================================================
CREATE OR REPLACE PROCEDURE "RestockInventory"(
    p_product_id INT,
    p_quantity_added INT,
    OUT p_new_quantity INT,
    OUT p_message VARCHAR
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_product_name VARCHAR;
    v_current_quantity INT;
    v_reorder_level INT;
BEGIN
    p_message := NULL;
    p_new_quantity := NULL;

    BEGIN
        -- Get product details
        SELECT "product_name" INTO v_product_name
        FROM "products"
        WHERE "product_id" = p_product_id;

        IF v_product_name IS NULL THEN
            RAISE EXCEPTION 'ERR_PRODUCT_NOT_FOUND: Product ID % does not exist', p_product_id;
        END IF;

        -- Validate quantity
        IF p_quantity_added <= 0 THEN
            RAISE EXCEPTION 'ERR_INVALID_QUANTITY: Restock quantity must be positive';
        END IF;

        -- Get current inventory
        SELECT "quantity_on_hand", "reorder_level" INTO v_current_quantity, v_reorder_level
        FROM "inventory"
        WHERE "product_id" = p_product_id
        FOR UPDATE;

        -- Update inventory
        UPDATE "inventory"
        SET "quantity_on_hand" = "quantity_on_hand" + p_quantity_added,
            "updated_at" = CURRENT_TIMESTAMP
        WHERE "product_id" = p_product_id
        RETURNING "quantity_on_hand" INTO p_new_quantity;

        -- Audit log
        INSERT INTO "audit_log" ("table_name", "operation", "record_id", "new_values")
        VALUES ('inventory', 'UPDATE', p_product_id,
                jsonb_build_object('quantity_on_hand', p_new_quantity, 'restocked', p_quantity_added));

        p_message := v_product_name || ': Restocked ' || p_quantity_added || ' units. New quantity: ' || p_new_quantity;

        -- Alert if still below reorder level
        IF p_new_quantity < v_reorder_level THEN
            p_message := p_message || ' [WARNING: Still below reorder level of ' || v_reorder_level || ']';
        END IF;

    EXCEPTION WHEN OTHERS THEN
        p_message := 'Error restocking inventory: ' || SQLERRM;
    END;
END;
$$;


-- ========================================================================
-- PROCEDURE: CancelOrder (With inventory restoration)
-- Purpose: Cancel an order and restore inventory
-- ========================================================================
CREATE OR REPLACE PROCEDURE "CancelOrder"(
    p_order_id INT,
    OUT p_success BOOLEAN,
    OUT p_message VARCHAR
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_order_status VARCHAR;
    v_item RECORD;
BEGIN
    p_success := FALSE;
    p_message := NULL;

    BEGIN
        -- Check order exists and get current status
        SELECT "status" INTO v_order_status
        FROM "orders"
        WHERE "order_id" = p_order_id;

        IF v_order_status IS NULL THEN
            RAISE EXCEPTION 'ERR_ORDER_NOT_FOUND: Order ID % does not exist', p_order_id;
        ELSIF v_order_status NOT IN ('Pending', 'Processing') THEN
            RAISE EXCEPTION 'ERR_CANNOT_CANCEL: Cannot cancel order with status %', v_order_status;
        END IF;

        -- Restore inventory for each item
        FOR v_item IN SELECT "product_id", "quantity" FROM "order_items" WHERE "order_id" = p_order_id
        LOOP
            UPDATE "inventory"
            SET "quantity_on_hand" = "quantity_on_hand" + v_item.quantity,
                "updated_at" = CURRENT_TIMESTAMP
            WHERE "product_id" = v_item.product_id;
        END LOOP;

        -- Update order status
        UPDATE "orders"
        SET "status" = 'Cancelled',
            "updated_at" = CURRENT_TIMESTAMP
        WHERE "order_id" = p_order_id;

        -- Audit log
        INSERT INTO "audit_log" ("table_name", "operation", "record_id", "new_values")
        VALUES ('orders', 'UPDATE', p_order_id, jsonb_build_object('status', 'Cancelled'));

        p_success := TRUE;
        p_message := 'Order ' || p_order_id || ' cancelled and inventory restored';

    EXCEPTION WHEN OTHERS THEN
        p_success := FALSE;
        p_message := 'Error cancelling order: ' || SQLERRM;
    END;
END;
$$;


-- ========================================================================
-- 3. BUSINESS KPI QUERIES
-- ========================================================================

-- KPI: Total Revenue (Only from Shipped or Delivered orders)
SELECT 'Total Revenue (Shipped/Delivered)' AS "KPI",
       SUM("total_amount") AS "Value",
       'USD' AS "Currency"
FROM "orders"
WHERE "status" IN ('Shipped', 'Delivered');

-- KPI: Top 10 Customers by Total Spending
SELECT 'Top 10 Customers' AS "Category",
       c."full_name" AS "Customer",
       SUM(o."total_amount") AS "Total Spent",
       COUNT(o."order_id") AS "Order Count"
FROM "customers" c
LEFT JOIN "orders" o ON c."customer_id" = o."customer_id"
WHERE c."is_active" = true
GROUP BY c."customer_id", c."full_name"
ORDER BY "Total Spent" DESC
LIMIT 10;

-- KPI: Best-Selling Products (Top 5 by Quantity)
SELECT 'Top 5 Products' AS "Category",
       p."product_name",
       p."category",
       SUM(oi."quantity") AS "Total Quantity Sold",
       SUM(oi."quantity" * oi."price_at_purchase") AS "Total Revenue"
FROM "products" p
LEFT JOIN "order_items" oi ON p."product_id" = oi."product_id"
WHERE p."is_active" = true
GROUP BY p."product_id", p."product_name", p."category"
ORDER BY "Total Quantity Sold" DESC NULLS LAST
LIMIT 5;

-- KPI: Monthly Sales Trend
SELECT TO_CHAR(o."order_date", 'YYYY-MM') AS "Month",
       COUNT(o."order_id") AS "Order Count",
       SUM(o."total_amount") AS "Monthly Revenue"
FROM "orders" o
WHERE o."status" IN ('Shipped', 'Delivered', 'Processing', 'Pending')
GROUP BY TO_CHAR(o."order_date", 'YYYY-MM')
ORDER BY "Month" DESC;

-- KPI: Order Status Distribution
SELECT o."status",
       COUNT(*) AS "Count",
       SUM(o."total_amount") AS "Total Amount",
       ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 2) AS "Percentage"
FROM "orders" o
GROUP BY o."status"
ORDER BY "Count" DESC;


-- ========================================================================
-- 4. ANALYTICAL QUERIES (WINDOW FUNCTIONS)
-- ========================================================================

-- Query: Sales Rank by Category
SELECT p."category",
       p."product_name",
       SUM(oi."quantity" * oi."price_at_purchase") AS "Category Revenue",
       RANK() OVER (PARTITION BY p."category" ORDER BY SUM(oi."quantity" * oi."price_at_purchase") DESC) AS "Category Rank"
FROM "products" p
LEFT JOIN "order_items" oi ON p."product_id" = oi."product_id"
WHERE p."is_active" = true
GROUP BY p."category", p."product_id", p."product_name"
ORDER BY p."category", "Category Rank";

-- Query: Customer Order Frequency Analysis
SELECT c."full_name" AS "Customer",
       o."order_id",
       o."order_date" AS "Current Order Date",
       LAG(o."order_date") OVER (PARTITION BY c."customer_id" ORDER BY o."order_date") AS "Previous Order Date",
       EXTRACT(DAY FROM o."order_date" - LAG(o."order_date") OVER (PARTITION BY c."customer_id" ORDER BY o."order_date")) AS "Days Since Last Order"
FROM "customers" c
JOIN "orders" o ON c."customer_id" = o."customer_id"
ORDER BY c."customer_id", o."order_date";

-- Query: Customer Spending Trend (Running Total)
SELECT c."full_name" AS "Customer",
       o."order_date",
       o."total_amount",
       SUM(o."total_amount") OVER (PARTITION BY c."customer_id" ORDER BY o."order_date") AS "Running Total"
FROM "customers" c
JOIN "orders" o ON c."customer_id" = o."customer_id"
ORDER BY c."customer_id", o."order_date";

-- Query: Percentile Analysis (Top spending customers by percentile)
SELECT c."full_name" AS "Customer",
       SUM(o."total_amount") AS "Total Spending",
       PERCENT_RANK() OVER (ORDER BY SUM(o."total_amount")) AS "Percentile Rank"
FROM "customers" c
LEFT JOIN "orders" o ON c."customer_id" = o."customer_id"
GROUP BY c."customer_id", c."full_name"
ORDER BY "Total Spending" DESC;


-- ========================================================================
-- 5. PERFORMANCE OPTIMIZATION: VIEWS
-- ========================================================================

-- VIEW: Customer Sales Summary (Pre-calculated Customer LTV)
CREATE OR REPLACE VIEW "CustomerSalesSummary" AS
SELECT c."customer_id",
       c."full_name",
       c."email",
       COUNT(DISTINCT o."order_id") AS "Total Orders",
       SUM(o."total_amount") AS "Total Spent",
       ROUND(AVG(o."total_amount"), 2) AS "Average Order Value",
       MAX(o."order_date") AS "Last Order Date",
       c."is_active"
FROM "customers" c
LEFT JOIN "orders" o ON c."customer_id" = o."customer_id"
GROUP BY c."customer_id", c."full_name", c."email", c."is_active";

-- VIEW: Inventory Health Dashboard
CREATE OR REPLACE VIEW "InventoryHealth" AS
SELECT p."product_id",
       p."product_name",
       p."category",
       i."quantity_on_hand",
       i."reorder_level",
       CASE 
         WHEN i."quantity_on_hand" = 0 THEN 'OUT OF STOCK'
         WHEN i."quantity_on_hand" < i."reorder_level" THEN 'LOW STOCK'
         WHEN i."quantity_on_hand" < (i."reorder_level" * 2) THEN 'NORMAL'
         ELSE 'ADEQUATE'
       END AS "Stock Status",
       (i."reorder_level" - i."quantity_on_hand") AS "Shortage Units"
FROM "products" p
JOIN "inventory" i ON p."product_id" = i."product_id"
WHERE p."is_active" = true
ORDER BY i."quantity_on_hand" ASC;

-- VIEW: Order History with Details
CREATE OR REPLACE VIEW "OrderHistory" AS
SELECT o."order_id",
       c."full_name" AS "Customer",
       o."order_date",
       o."status",
       o."total_amount",
       COUNT(oi."order_item_id") AS "Item Count",
       STRING_AGG(p."product_name", ', ') AS "Products"
FROM "orders" o
JOIN "customers" c ON o."customer_id" = c."customer_id"
LEFT JOIN "order_items" oi ON o."order_id" = oi."order_id"
LEFT JOIN "products" p ON oi."product_id" = p."product_id"
GROUP BY o."order_id", c."full_name", o."order_date", o."status", o."total_amount"
ORDER BY o."order_date" DESC;



-- ========================================================================
-- VIEWS FOR REPORTING
-- ========================================================================
CREATE OR REPLACE VIEW "vw_low_stock_products" AS
SELECT 
  p.product_id,
  p.product_name,
  p.category,
  i.quantity_on_hand,
  i.reorder_level,
  (i.reorder_level - i.quantity_on_hand) AS "units_to_reorder"
FROM "products" p
JOIN "inventory" i ON p.product_id = i.product_id
WHERE i.quantity_on_hand <= i.reorder_level
ORDER BY "units_to_reorder" DESC;

CREATE OR REPLACE VIEW "vw_product_sales_summary" AS
SELECT 
  p.product_id,
  p.product_name,
  p.category,
  COUNT(DISTINCT oi.order_id) AS "number_of_orders",
  SUM(oi.quantity) AS "total_quantity_sold",
  SUM(oi.quantity * oi.price_at_purchase) AS "total_revenue"
FROM "products" p
LEFT JOIN "order_items" oi ON p.product_id = oi.product_id
GROUP BY p.product_id, p.product_name, p.category
ORDER BY "total_revenue" DESC NULLS LAST;


-- ========================================================================
-- 6. MONITORING & ALERTING QUERIES
-- ========================================================================

-- Query: Low Stock Alert
SELECT * FROM "vw_low_stock_products"
WHERE "units_to_reorder" > 0
ORDER BY "units_to_reorder" DESC;

-- Query: Revenue Forecast (Based on recent trends)
SELECT TO_CHAR(o."order_date", 'YYYY-MM') AS "Month",
       COUNT(o."order_id") AS "Orders",
       SUM(o."total_amount") AS "Revenue",
       ROUND(AVG(SUM(o."total_amount")) OVER (ORDER BY TO_CHAR(o."order_date", 'YYYY-MM') ROWS BETWEEN 2 PRECEDING AND CURRENT ROW), 2) AS "3-Month Moving Avg"
FROM "orders" o
WHERE o."status" IN ('Shipped', 'Delivered')
GROUP BY TO_CHAR(o."order_date", 'YYYY-MM')
ORDER BY "Month" DESC;

-- Query: Customer Churn Analysis (No orders in 60+ days)
SELECT c."customer_id",
       c."full_name",
       c."email",
       MAX(o."order_date") AS "Last Order Date",
       EXTRACT(DAY FROM CURRENT_TIMESTAMP - MAX(o."order_date")) AS "Days Since Last Order"
FROM "customers" c
LEFT JOIN "orders" o ON c."customer_id" = o."customer_id"
WHERE c."is_active" = true AND MAX(o."order_date") IS NOT NULL
GROUP BY c."customer_id", c."full_name", c."email"
HAVING EXTRACT(DAY FROM CURRENT_TIMESTAMP - MAX(o."order_date")) >= 60
ORDER BY "Days Since Last Order" DESC;

-- Query: Audit Log Summary
SELECT "table_name",
       "operation",
       COUNT(*) AS "Count",
       MAX("created_at") AS "Last Modified"
FROM "audit_log"
WHERE "created_at" >= CURRENT_DATE - INTERVAL '30 days'
GROUP BY "table_name", "operation"
ORDER BY "Last Modified" DESC;


-- ========================================================================
-- 7. TEST CASES FOR PROCEDURES
-- ========================================================================

-- Test: ProcessNewOrder (Success case)
-- SELECT * FROM "ProcessNewOrder"(1, 3, 2);

-- Test: ProcessNewOrder (Insufficient stock)
-- SELECT * FROM "UpdateProductPrice"(1, 1499.99);

-- Test: ProcessNewOrder (Invalid customer)
-- SELECT * FROM "UpdateProductPrice"(90, 1499.99);

-- Test: UpdateProductPrice (Success)
-- SELECT * FROM "UpdateProductPrice"(2, -10);

-- Test: RestockInventory (Success)
-- SELECT * FROM "RestockInventory"(2, 100);

-- Test: CancelOrder (Success)
-- CALL "CancelOrder"(1, NULL, NULL);
