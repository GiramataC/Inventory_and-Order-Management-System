# Inventory and Order Management System


---

## Overview

A relational database system for e-commerce inventory and order management. Built with performance optimization, and comprehensive disaster recovery capabilities.


##  Project Files

- **`Schema_implementation.sql`** - Table definitions with all constraints, indexes, and relationships
- **`Querries.sql`** - Data seeding, stored procedures, views, and analytical queries
- **`README.md`** - This documentation file


---

##  Quick Start

### Prerequisites
```bash
PostgreSQL 13+ (14+ recommended)
pgAdmin or psql client
```

### Setup Instructions

1. **Create Database**
   ```bash
   createdb inventory_and_order_db
   ```

2. **Deploy Schema**
   ```bash
   psql -d inventory_and_order_db -f Schema_implementation.sql
   ```

3. **Load Procedures & Data**
   ```bash
   psql -d inventory_and_order_db -f Querries.sql
   ```

---

## Database Architecture

### Schema Overview

```
CUSTOMERS (parent)
├── ORDERS (many-to-one)
│   ├── ORDER_ITEMS (one-to-many)
│   │   └── PRODUCTS (many-to-one)
│   └── PAYMENTS (one-to-many)
└── PRODUCTS
    └── INVENTORY (one-to-one)
AUDIT_LOG (independent - logs all changes)
```

### Tables & Constraints

#### `customers`
- **Columns:** customer_id (PK), full_name, email (UNIQUE), phone, shipping_address
- **Constraints:** Email validation, phone format validation, NOT NULL enforcement
- **Indexes:** Email (unique), created_at, is_active
- **Security:** RLS enabled for sensitive data

#### `products`
- **Columns:** product_id (PK), product_name, category, price
- **Constraints:** Price ≥ $0, non-empty name/category, NOT NULL
- **Indexes:** Category, created_at, is_active
- **Audit:** Full change tracking via audit_log

#### `inventory`
- **Columns:** product_id (FK/PK), quantity_on_hand, reorder_level
- **Constraints:** Quantity ≥ 0, reorder_level > 0
- **Indexes:** Low stock alerts, reorder tracking
- **Features:** Automatic low-stock notifications

#### `orders`
- **Columns:** order_id (PK), customer_id (FK), order_date, total_amount, status
- **Constraints:** Valid status values, amount ≥ $0
- **Indexes:** Customer lookup, date range queries, status filtering
- **Statuses:** Pending, Processing, Shipped, Delivered, Cancelled, Refunded

#### `order_items`
- **Columns:** order_item_id (PK), order_id (FK), product_id (FK), quantity, price_at_purchase
- **Constraints:** Quantity > 0, price ≥ $0, unique order-product pairing
- **Features:** Historical price preservation, prevents duplicate items per order

#### `payments`
- **Columns:** payment_id (PK), order_id (FK), amount_paid, payment_method, payment_status, payment_date
- **Constraints:** order_id references orders, ON DELETE RESTRICT
- **Payment Methods:** Card, Mobile Money, etc.
- **Payment Status:** Pending, Partial, Completed
- **Purpose:** Track all payment transactions linked to orders

#### `audit_log`
- **Columns:** audit_id (PK), table_name, operation, record_id, old_values (JSONB), new_values (JSONB), user_name, created_at
- **Purpose:** Complete audit trail for all DML operations
- **Operations:** INSERT, UPDATE, DELETE
- **Indexed:** On table_name and created_at for fast audit lookups

---

## Stored Procedures & Functions

### `ProcessNewOrder(customer_id, product_id, quantity)` - FUNCTION
Creates an order with comprehensive validation and transaction safety.

**Validations:**
- Verifies customer exists and is active
- Checks product exists and is active
- Validates quantity > 0
- Ensures sufficient inventory (with row-level locking)

**Actions:**
- Creates order header with Pending status
- Creates order_item with historical price capture
- Automatically deducts inventory
- Returns order_id and error_message

**Error Codes:** ERR_INVALID_CUSTOMER, ERR_INVALID_PRODUCT, ERR_PRODUCT_INACTIVE, ERR_INVALID_QUANTITY, ERR_NO_INVENTORY, ERR_INSUFFICIENT_STOCK

### `UpdateProductPrice(product_id, new_price)` - FUNCTION
Updates product pricing with automatic audit logging.

**Features:**
- Validates price > 0
- Logs old and new prices in audit_log
- Returns success/failure with descriptive message

### `RestockInventory(product_id, quantity_added)` - PROCEDURE
Replenishes inventory with validation and alerts.

**Features:**
- Adds quantity to inventory
- Logs restock operation in audit_log
- Warns if quantity still below reorder_level
- Returns new quantity and descriptive message

### `CancelOrder(order_id)` - PROCEDURE
Cancels orders and restores inventory automatically.

**Restrictions:**
- Only allows cancelling orders with status 'Pending' or 'Processing'

**Actions:**
- Restores inventory for all items in order
- Updates order status to 'Cancelled'
- Logs cancellation in audit_log
- Returns success status and message

---

## Pre-built Views

### Business Intelligence
- **`CustomerSalesSummary`** - Customer lifetime value (LTV) with total orders, spending, average order value, and last order date
- **`InventoryHealth`** - Stock status (OUT OF STOCK, LOW STOCK, NORMAL, ADEQUATE) with shortage calculations
- **`OrderHistory`** - Complete order tracking with customer name, status, total amount, and item count

---

## Sample Data

The `Querries.sql` file includes seeded data for quick testing:
- **5 Customers:** Alice Johnson, Bob Smith, Charlie Brown, Diana Prince, Eve Wilson
- **8 Products:** Electronics (Laptop Pro, USB Mouse, Wireless Keyboard), Apparel (Cotton Hoodie, Denim Jeans), Books (SQL Mastery, Database Design Guide), Accessories (Monitor Stand)
- **7 Sample Orders** with various statuses (Pending, Processing, Shipped, Delivered)
- **14 Order Items** showing real purchasing patterns
- **7 Payment Records** with different payment methods (Card, Mobile Money) and statuses

---

## Key Features

✓ **Data Integrity** - Foreign key constraints prevent orphaned records  
✓ **Audit Trail** - All changes logged in JSONB format for compliance  
✓ **Inventory Management** - Real-time stock tracking with low-stock alerts  
✓ **Transaction Safety** - Row-level locking in critical procedures  
✓ **Payment Tracking** - Support for multiple payment methods and partial payments  
✓ **Error Handling** - Meaningful error codes returned from all procedures  
✓ **Performance** - Indexes on frequently queried columns (customer_id, order_date, status, etc.)

---

## Key Business Queries

### Total Revenue (Shipped/Delivered Orders)
```sql
SELECT SUM(total_amount) AS revenue
FROM orders
WHERE status IN ('Shipped', 'Delivered');
```

### Top 10 Customers by Spending
```sql
SELECT c.full_name, SUM(o.total_amount) AS total_spent
FROM customers c
LEFT JOIN orders o ON c.customer_id = o.customer_id
GROUP BY c.customer_id, c.full_name
ORDER BY total_spent DESC
LIMIT 10;
```

### Monthly Sales Trend
```sql
SELECT TO_CHAR(order_date, 'YYYY-MM') AS month,
       SUM(total_amount) AS revenue
FROM orders
WHERE status IN ('Shipped', 'Delivered')
GROUP BY month
ORDER BY month DESC;
```

### Low Stock Alert
```sql
SELECT * FROM vw_low_stock_products
ORDER BY units_to_reorder DESC;
```

---

