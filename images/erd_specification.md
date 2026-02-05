# Olist E-Commerce ERD Specification

This file contains the dbdiagram.io DBML code for generating the Entity-Relationship Diagram for the Olist Brazilian E-Commerce dataset.

## How to Generate the Visual ERD

1. Go to [dbdiagram.io](https://dbdiagram.io)
2. Click "Go to App" or sign in
3. Create a new diagram
4. Copy and paste the DBML code below into the editor
5. The diagram will render automatically

---

## DBML Code

```dbml
// Olist Brazilian E-Commerce Dataset ERD
// 9 Tables with their relationships

// =====================
// CORE ENTITIES
// =====================

Table customers {
  customer_id varchar [pk, note: 'Key to orders table']
  customer_unique_id varchar [note: 'Unique identifier of a customer']
  customer_zip_code_prefix varchar [note: 'First 5 digits of customer zip code']
  customer_city varchar
  customer_state varchar [note: '2-letter state code']
}

Table sellers {
  seller_id varchar [pk, note: 'Seller unique identifier']
  seller_zip_code_prefix varchar [note: 'First 5 digits of seller zip code']
  seller_city varchar
  seller_state varchar [note: '2-letter state code']
}

Table products {
  product_id varchar [pk, note: 'Unique product identifier']
  product_category_name varchar [note: 'Root category in Portuguese']
  product_name_length int [note: 'Number of characters in product name']
  product_description_length int [note: 'Number of characters in product description']
  product_photos_qty int [note: 'Number of product photos']
  product_weight_g int [note: 'Product weight in grams']
  product_length_cm int [note: 'Product length in centimeters']
  product_height_cm int [note: 'Product height in centimeters']
  product_width_cm int [note: 'Product width in centimeters']
}

// =====================
// ORDERS (Central Hub)
// =====================

Table orders {
  order_id varchar [pk, note: 'Unique order identifier']
  customer_id varchar [ref: > customers.customer_id, note: 'FK to customer who made the order']
  order_status varchar [note: 'Order status: delivered, shipped, canceled, etc.']
  order_purchase_timestamp timestamp [note: 'Purchase timestamp']
  order_approved_at timestamp [note: 'Payment approval timestamp']
  order_delivered_carrier_date timestamp [note: 'Order posting timestamp (handed to carrier)']
  order_delivered_customer_date timestamp [note: 'Actual delivery date to customer']
  order_estimated_delivery_date timestamp [note: 'Estimated delivery date informed at purchase']
}

// =====================
// ORDER DETAILS
// =====================

Table order_items {
  order_id varchar [ref: > orders.order_id, note: 'FK to orders table']
  order_item_id int [note: 'Sequential number identifying items within same order']
  product_id varchar [ref: > products.product_id, note: 'FK to products table']
  seller_id varchar [ref: > sellers.seller_id, note: 'FK to sellers table']
  shipping_limit_date timestamp [note: 'Seller shipping limit date for handling to carrier']
  price decimal [note: 'Item price']
  freight_value decimal [note: 'Freight value for this item']

  indexes {
    (order_id, order_item_id) [pk, note: 'Composite primary key']
  }
}

Table order_payments {
  order_id varchar [ref: > orders.order_id, note: 'FK to orders table']
  payment_sequential int [note: 'Sequence for orders with multiple payment methods']
  payment_type varchar [note: 'Payment method: credit_card, boleto, voucher, debit_card']
  payment_installments int [note: 'Number of installments chosen']
  payment_value decimal [note: 'Transaction value']

  indexes {
    (order_id, payment_sequential) [pk, note: 'Composite primary key']
  }
}

Table order_reviews {
  review_id varchar [pk, note: 'Unique review identifier']
  order_id varchar [unique, ref: > orders.order_id, note: 'FK to orders table (one review per order)']
  review_score int [note: 'Rating from 1 to 5']
  review_comment_title varchar [note: 'Comment title (Portuguese)']
  review_comment_message varchar [note: 'Comment message (Portuguese)']
  review_creation_date timestamp [note: 'Survey sent date']
  review_answer_timestamp timestamp [note: 'Survey response timestamp']
}

// =====================
// REFERENCE/LOOKUP TABLES
// =====================

Table geolocation {
  geolocation_zip_code_prefix varchar [note: 'First 5 digits of zip code']
  geolocation_lat decimal [note: 'Latitude']
  geolocation_lng decimal [note: 'Longitude']
  geolocation_city varchar
  geolocation_state varchar [note: '2-letter state code']

  Note: 'Multiple lat/lng per zip code prefix. Join to customers/sellers via zip_code_prefix.'
}

Table product_category_translation {
  product_category_name varchar [pk, note: 'Category name in Portuguese']
  product_category_name_english varchar [note: 'Category name in English']
}

// =====================
// RELATIONSHIPS
// =====================

// Implicit relationships (join via matching fields, not FK constraints in source data)
// customers.customer_zip_code_prefix -> geolocation.geolocation_zip_code_prefix
// sellers.seller_zip_code_prefix -> geolocation.geolocation_zip_code_prefix
// products.product_category_name -> product_category_translation.product_category_name

Ref: products.product_category_name > product_category_translation.product_category_name
```

---

## Relationship Summary

| Relationship | Type | Description |
|--------------|------|-------------|
| orders -> customers | Many-to-One | Each order belongs to one customer; a customer can have multiple orders |
| orders -> order_items | One-to-Many | Each order can have multiple items |
| orders -> order_payments | One-to-Many | Each order can have multiple payment records (split payments) |
| orders -> order_reviews | One-to-One | Each order has at most one review |
| order_items -> products | Many-to-One | Each order item references one product |
| order_items -> sellers | Many-to-One | Each order item is sold by one seller |
| products -> product_category_translation | Many-to-One | Category name translation lookup |
| customers -> geolocation | Many-to-Many | Via zip_code_prefix (multiple geo points per zip) |
| sellers -> geolocation | Many-to-Many | Via zip_code_prefix (multiple geo points per zip) |

---

## Data Model Notes

1. **Central Hub**: The `orders` table is the central hub connecting customers to their purchases.

2. **Composite Keys**:
   - `order_items` uses (order_id, order_item_id) as composite PK
   - `order_payments` uses (order_id, payment_sequential) as composite PK

3. **Geolocation**: This table has multiple records per zip code prefix (different lat/lng coordinates). When joining, use aggregation or select one representative point.

4. **Category Translation**: Products have Portuguese category names. Use the translation table to get English names.

5. **Review Cardinality**: While the schema suggests one-to-one (order_id is unique in reviews), not all orders have reviews.
