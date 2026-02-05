-- 01_create_tables.sql
-- Table creation scripts for marketplace BI analysis
-- Schema extracted from SQLite database: data/olist_ecommerce.db
-- Source: 9 CSV files from Olist e-commerce dataset

-- Customers table (99,441 rows)
CREATE TABLE "customers" (
    "customer_id" TEXT,
    "customer_unique_id" TEXT,
    "customer_zip_code_prefix" INTEGER,
    "customer_city" TEXT,
    "customer_state" TEXT
);

-- Geolocation table (1,000,163 rows)
CREATE TABLE "geolocation" (
    "geolocation_zip_code_prefix" INTEGER,
    "geolocation_lat" REAL,
    "geolocation_lng" REAL,
    "geolocation_city" TEXT,
    "geolocation_state" TEXT
);

-- Order items table (112,650 rows)
CREATE TABLE "order_items" (
    "order_id" TEXT,
    "order_item_id" INTEGER,
    "product_id" TEXT,
    "seller_id" TEXT,
    "shipping_limit_date" TEXT,
    "price" REAL,
    "freight_value" REAL
);

-- Order payments table (103,886 rows)
CREATE TABLE "order_payments" (
    "order_id" TEXT,
    "payment_sequential" INTEGER,
    "payment_type" TEXT,
    "payment_installments" INTEGER,
    "payment_value" REAL
);

-- Order reviews table (99,224 rows)
CREATE TABLE "order_reviews" (
    "review_id" TEXT,
    "order_id" TEXT,
    "review_score" INTEGER,
    "review_comment_title" TEXT,
    "review_comment_message" TEXT,
    "review_creation_date" TEXT,
    "review_answer_timestamp" TEXT
);

-- Orders table (99,441 rows)
CREATE TABLE "orders" (
    "order_id" TEXT,
    "customer_id" TEXT,
    "order_status" TEXT,
    "order_purchase_timestamp" TEXT,
    "order_approved_at" TEXT,
    "order_delivered_carrier_date" TEXT,
    "order_delivered_customer_date" TEXT,
    "order_estimated_delivery_date" TEXT
);

-- Product category translation table (71 rows)
CREATE TABLE "product_category_translation" (
    "product_category_name" TEXT,
    "product_category_name_english" TEXT
);

-- Products table (32,951 rows)
CREATE TABLE "products" (
    "product_id" TEXT,
    "product_category_name" TEXT,
    "product_name_lenght" REAL,
    "product_description_lenght" REAL,
    "product_photos_qty" REAL,
    "product_weight_g" REAL,
    "product_length_cm" REAL,
    "product_height_cm" REAL,
    "product_width_cm" REAL
);

-- Sellers table (3,095 rows)
CREATE TABLE "sellers" (
    "seller_id" TEXT,
    "seller_zip_code_prefix" INTEGER,
    "seller_city" TEXT,
    "seller_state" TEXT
);
