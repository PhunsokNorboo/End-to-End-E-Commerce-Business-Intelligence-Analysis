"""
Export data for Tableau Dashboard visualization.

This script creates optimized CSV exports from the SQLite database
for use in Tableau Public.

Exports:
1. orders_fact.csv - Main fact table with orders, payments, reviews
2. product_sales.csv - Product sales with categories and seller info
3. customer_segments.csv - Customer RFM segmentation data
4. monthly_metrics.csv - Monthly summary metrics

Author: Steward Agent
Date: 2026-02-04
"""

import pandas as pd
import sqlite3
import numpy as np
from pathlib import Path

# Paths
PROJECT_ROOT = Path(__file__).parent.parent
DB_PATH = PROJECT_ROOT / 'data' / 'olist_ecommerce.db'
EXPORT_PATH = PROJECT_ROOT / 'data' / 'tableau_exports'

# Ensure export directory exists
EXPORT_PATH.mkdir(parents=True, exist_ok=True)


def export_orders_fact(conn):
    """
    Export main fact table: orders with payments, reviews, and customer info.
    """
    print("Exporting orders_fact.csv...")

    query = '''
    SELECT
        o.order_id,
        o.customer_id,
        c.customer_unique_id,
        o.order_status,
        o.order_purchase_timestamp,
        o.order_approved_at,
        o.order_delivered_carrier_date,
        o.order_delivered_customer_date,
        o.order_estimated_delivery_date,
        c.customer_city,
        c.customer_state,
        c.customer_zip_code_prefix
    FROM orders o
    LEFT JOIN customers c ON o.customer_id = c.customer_id
    '''
    orders_df = pd.read_sql_query(query, conn)

    # Get payments aggregated by order
    payments_query = '''
    SELECT
        order_id,
        SUM(payment_value) as total_payment_value,
        MAX(payment_type) as primary_payment_type,
        SUM(payment_installments) as total_installments,
        COUNT(*) as payment_count
    FROM order_payments
    GROUP BY order_id
    '''
    payments_df = pd.read_sql_query(payments_query, conn)

    # Get reviews (one per order)
    reviews_query = '''
    SELECT
        order_id,
        review_score,
        review_creation_date
    FROM order_reviews
    '''
    reviews_df = pd.read_sql_query(reviews_query, conn)
    # Keep first review per order if duplicates exist
    reviews_df = reviews_df.drop_duplicates(subset=['order_id'], keep='first')

    # Merge all data
    orders_fact = orders_df.merge(payments_df, on='order_id', how='left')
    orders_fact = orders_fact.merge(reviews_df, on='order_id', how='left')

    # Convert timestamps
    date_cols = [
        'order_purchase_timestamp', 'order_approved_at',
        'order_delivered_carrier_date', 'order_delivered_customer_date',
        'order_estimated_delivery_date', 'review_creation_date'
    ]
    for col in date_cols:
        orders_fact[col] = pd.to_datetime(orders_fact[col], errors='coerce')

    # Add calculated fields for Tableau
    orders_fact['order_year'] = orders_fact['order_purchase_timestamp'].dt.year
    orders_fact['order_month'] = orders_fact['order_purchase_timestamp'].dt.to_period('M').astype(str)
    orders_fact['order_quarter'] = orders_fact['order_purchase_timestamp'].dt.to_period('Q').astype(str)
    orders_fact['order_day_of_week'] = orders_fact['order_purchase_timestamp'].dt.day_name()

    # Delivery time calculations (only for delivered orders)
    delivered_mask = orders_fact['order_status'] == 'delivered'
    orders_fact['actual_delivery_days'] = np.nan
    orders_fact.loc[delivered_mask, 'actual_delivery_days'] = (
        orders_fact.loc[delivered_mask, 'order_delivered_customer_date'] -
        orders_fact.loc[delivered_mask, 'order_purchase_timestamp']
    ).dt.days

    orders_fact['estimated_delivery_days'] = np.nan
    orders_fact.loc[delivered_mask, 'estimated_delivery_days'] = (
        orders_fact.loc[delivered_mask, 'order_estimated_delivery_date'] -
        orders_fact.loc[delivered_mask, 'order_purchase_timestamp']
    ).dt.days

    orders_fact['delivery_delay_days'] = (
        orders_fact['actual_delivery_days'] - orders_fact['estimated_delivery_days']
    )

    orders_fact['on_time_delivery'] = (orders_fact['delivery_delay_days'] <= 0).map({True: 'On Time', False: 'Late'})
    orders_fact.loc[~delivered_mask, 'on_time_delivery'] = None

    # Save
    orders_fact.to_csv(EXPORT_PATH / 'orders_fact.csv', index=False)
    print(f"  - Exported {len(orders_fact):,} orders")

    return orders_fact


def export_product_sales(conn):
    """
    Export product sales data with categories and seller information.
    """
    print("Exporting product_sales.csv...")

    query = '''
    SELECT
        oi.order_id,
        oi.order_item_id,
        oi.product_id,
        oi.seller_id,
        oi.shipping_limit_date,
        oi.price,
        oi.freight_value,
        p.product_category_name,
        t.product_category_name_english,
        p.product_weight_g,
        p.product_length_cm,
        p.product_height_cm,
        p.product_width_cm,
        p.product_photos_qty,
        s.seller_city,
        s.seller_state,
        s.seller_zip_code_prefix
    FROM order_items oi
    LEFT JOIN products p ON oi.product_id = p.product_id
    LEFT JOIN product_category_translation t ON p.product_category_name = t.product_category_name
    LEFT JOIN sellers s ON oi.seller_id = s.seller_id
    '''
    product_sales = pd.read_sql_query(query, conn)

    # Add order date for time-based analysis
    order_dates_query = '''
    SELECT order_id, order_purchase_timestamp, order_status
    FROM orders
    '''
    order_dates = pd.read_sql_query(order_dates_query, conn)
    product_sales = product_sales.merge(order_dates, on='order_id', how='left')

    # Convert timestamps
    product_sales['order_purchase_timestamp'] = pd.to_datetime(product_sales['order_purchase_timestamp'])
    product_sales['shipping_limit_date'] = pd.to_datetime(product_sales['shipping_limit_date'])

    # Add time dimensions
    product_sales['order_month'] = product_sales['order_purchase_timestamp'].dt.to_period('M').astype(str)
    product_sales['order_year'] = product_sales['order_purchase_timestamp'].dt.year

    # Calculate total item value
    product_sales['total_item_value'] = product_sales['price'] + product_sales['freight_value']

    # Fill missing category names
    product_sales['product_category_name_english'] = product_sales['product_category_name_english'].fillna('Unknown')

    # Save
    product_sales.to_csv(EXPORT_PATH / 'product_sales.csv', index=False)
    print(f"  - Exported {len(product_sales):,} order items")

    return product_sales


def export_customer_segments(conn):
    """
    Create and export customer RFM segmentation data.
    """
    print("Exporting customer_segments.csv...")

    # Get customer order history
    query = '''
    SELECT
        c.customer_unique_id,
        c.customer_city,
        c.customer_state,
        o.order_id,
        o.order_purchase_timestamp,
        o.order_status
    FROM customers c
    JOIN orders o ON c.customer_id = o.customer_id
    WHERE o.order_status = 'delivered'
    '''
    customer_orders = pd.read_sql_query(query, conn)
    customer_orders['order_purchase_timestamp'] = pd.to_datetime(customer_orders['order_purchase_timestamp'])

    # Get payments per order
    payments_query = '''
    SELECT order_id, SUM(payment_value) as payment_value
    FROM order_payments
    GROUP BY order_id
    '''
    payments = pd.read_sql_query(payments_query, conn)
    customer_orders = customer_orders.merge(payments, on='order_id', how='left')

    # Calculate RFM metrics
    analysis_date = customer_orders['order_purchase_timestamp'].max() + pd.Timedelta(days=1)

    rfm = customer_orders.groupby('customer_unique_id').agg({
        'order_purchase_timestamp': lambda x: (analysis_date - x.max()).days,  # Recency
        'order_id': 'count',  # Frequency
        'payment_value': 'sum',  # Monetary
        'customer_city': 'first',
        'customer_state': 'first'
    }).reset_index()

    rfm.columns = ['customer_unique_id', 'recency', 'frequency', 'monetary', 'customer_city', 'customer_state']

    # Calculate RFM scores (1-5)
    rfm['r_score'] = pd.qcut(rfm['recency'], 5, labels=[5, 4, 3, 2, 1], duplicates='drop')
    rfm['f_score'] = pd.qcut(rfm['frequency'].rank(method='first'), 5, labels=[1, 2, 3, 4, 5])
    rfm['m_score'] = pd.qcut(rfm['monetary'], 5, labels=[1, 2, 3, 4, 5], duplicates='drop')

    # Convert scores to int
    rfm['r_score'] = rfm['r_score'].astype('Int64')
    rfm['f_score'] = rfm['f_score'].astype('Int64')
    rfm['m_score'] = rfm['m_score'].astype('Int64')

    # Create RFM string
    rfm['rfm_score'] = rfm['r_score'].astype(str) + rfm['f_score'].astype(str) + rfm['m_score'].astype(str)

    # Segment customers
    def segment_customer(row):
        r, f = row['r_score'], row['f_score']
        if pd.isna(r) or pd.isna(f):
            return 'Unknown'
        r, f = int(r), int(f)
        if r >= 4 and f >= 4:
            return 'Champions'
        elif r >= 3 and f >= 3:
            return 'Loyal Customers'
        elif r >= 4 and f <= 2:
            return 'New Customers'
        elif r >= 3 and f <= 2:
            return 'Potential Loyalists'
        elif r <= 2 and f >= 3:
            return 'At Risk'
        elif r <= 2 and f <= 2:
            return 'Hibernating'
        else:
            return 'Need Attention'

    rfm['segment'] = rfm.apply(segment_customer, axis=1)

    # Add first and last purchase dates
    purchase_dates = customer_orders.groupby('customer_unique_id').agg({
        'order_purchase_timestamp': ['min', 'max']
    }).reset_index()
    purchase_dates.columns = ['customer_unique_id', 'first_purchase_date', 'last_purchase_date']

    rfm = rfm.merge(purchase_dates, on='customer_unique_id', how='left')
    rfm['customer_tenure_days'] = (rfm['last_purchase_date'] - rfm['first_purchase_date']).dt.days

    # Calculate average order value
    rfm['avg_order_value'] = rfm['monetary'] / rfm['frequency']

    # Save
    rfm.to_csv(EXPORT_PATH / 'customer_segments.csv', index=False)
    print(f"  - Exported {len(rfm):,} customers with segments")

    return rfm


def export_monthly_metrics(conn):
    """
    Export monthly aggregated metrics for trend analysis.
    """
    print("Exporting monthly_metrics.csv...")

    query = '''
    SELECT
        o.order_id,
        o.customer_id,
        c.customer_unique_id,
        o.order_status,
        o.order_purchase_timestamp,
        o.order_delivered_customer_date,
        o.order_estimated_delivery_date
    FROM orders o
    JOIN customers c ON o.customer_id = c.customer_id
    '''
    orders = pd.read_sql_query(query, conn)
    orders['order_purchase_timestamp'] = pd.to_datetime(orders['order_purchase_timestamp'])
    orders['order_month'] = orders['order_purchase_timestamp'].dt.to_period('M')

    # Get payments
    payments_query = '''
    SELECT order_id, SUM(payment_value) as payment_value
    FROM order_payments
    GROUP BY order_id
    '''
    payments = pd.read_sql_query(payments_query, conn)
    orders = orders.merge(payments, on='order_id', how='left')

    # Get reviews
    reviews_query = '''
    SELECT order_id, review_score
    FROM order_reviews
    '''
    reviews = pd.read_sql_query(reviews_query, conn)
    reviews = reviews.drop_duplicates(subset=['order_id'], keep='first')
    orders = orders.merge(reviews, on='order_id', how='left')

    # Filter to delivered orders for most metrics
    delivered = orders[orders['order_status'] == 'delivered'].copy()
    delivered['order_delivered_customer_date'] = pd.to_datetime(delivered['order_delivered_customer_date'])
    delivered['order_estimated_delivery_date'] = pd.to_datetime(delivered['order_estimated_delivery_date'])

    # Calculate on-time delivery
    delivered['delivery_days'] = (delivered['order_delivered_customer_date'] - delivered['order_purchase_timestamp']).dt.days
    delivered['estimated_days'] = (delivered['order_estimated_delivery_date'] - delivered['order_purchase_timestamp']).dt.days
    delivered['is_on_time'] = delivered['delivery_days'] <= delivered['estimated_days']

    # Monthly aggregations
    monthly = delivered.groupby('order_month').agg({
        'order_id': 'count',
        'customer_unique_id': 'nunique',
        'payment_value': ['sum', 'mean'],
        'review_score': 'mean',
        'delivery_days': 'mean',
        'is_on_time': 'mean'
    }).reset_index()

    monthly.columns = [
        'order_month', 'total_orders', 'unique_customers',
        'total_revenue', 'avg_order_value', 'avg_review_score',
        'avg_delivery_days', 'on_time_delivery_rate'
    ]

    # Convert period to string for CSV
    monthly['order_month'] = monthly['order_month'].astype(str)

    # Add date for proper time series in Tableau
    monthly['month_date'] = pd.to_datetime(monthly['order_month'] + '-01')

    # Calculate new vs returning customers
    # First, find first purchase month for each customer
    first_purchase = delivered.groupby('customer_unique_id')['order_month'].min().reset_index()
    first_purchase.columns = ['customer_unique_id', 'first_purchase_month']
    delivered = delivered.merge(first_purchase, on='customer_unique_id', how='left')
    delivered['is_new_customer'] = delivered['order_month'] == delivered['first_purchase_month']

    new_customers = delivered[delivered['is_new_customer']].groupby('order_month')['customer_unique_id'].nunique().reset_index()
    new_customers.columns = ['order_month', 'new_customers']
    new_customers['order_month'] = new_customers['order_month'].astype(str)

    monthly = monthly.merge(new_customers, on='order_month', how='left')
    monthly['returning_customers'] = monthly['unique_customers'] - monthly['new_customers']

    # Convert on-time rate to percentage
    monthly['on_time_delivery_rate'] = (monthly['on_time_delivery_rate'] * 100).round(2)

    # Round other metrics
    monthly['avg_order_value'] = monthly['avg_order_value'].round(2)
    monthly['avg_review_score'] = monthly['avg_review_score'].round(2)
    monthly['avg_delivery_days'] = monthly['avg_delivery_days'].round(1)
    monthly['total_revenue'] = monthly['total_revenue'].round(2)

    # Save
    monthly.to_csv(EXPORT_PATH / 'monthly_metrics.csv', index=False)
    print(f"  - Exported {len(monthly):,} months of metrics")

    return monthly


def export_seller_performance(conn):
    """
    Export seller performance metrics for seller scorecard.
    """
    print("Exporting seller_performance.csv...")

    query = '''
    SELECT
        s.seller_id,
        s.seller_city,
        s.seller_state,
        oi.order_id,
        oi.price,
        oi.freight_value
    FROM sellers s
    JOIN order_items oi ON s.seller_id = oi.seller_id
    JOIN orders o ON oi.order_id = o.order_id
    WHERE o.order_status = 'delivered'
    '''
    seller_items = pd.read_sql_query(query, conn)

    # Get reviews per order
    reviews_query = '''
    SELECT oi.seller_id, r.order_id, r.review_score
    FROM order_reviews r
    JOIN order_items oi ON r.order_id = oi.order_id
    '''
    reviews = pd.read_sql_query(reviews_query, conn)
    reviews = reviews.drop_duplicates(subset=['order_id', 'seller_id'], keep='first')

    # Get delivery performance
    delivery_query = '''
    SELECT
        oi.seller_id,
        oi.order_id,
        JULIANDAY(o.order_delivered_customer_date) - JULIANDAY(o.order_purchase_timestamp) as delivery_days,
        JULIANDAY(o.order_estimated_delivery_date) - JULIANDAY(o.order_purchase_timestamp) as estimated_days
    FROM order_items oi
    JOIN orders o ON oi.order_id = o.order_id
    WHERE o.order_status = 'delivered'
        AND o.order_delivered_customer_date IS NOT NULL
        AND o.order_estimated_delivery_date IS NOT NULL
    '''
    delivery = pd.read_sql_query(delivery_query, conn)
    delivery['is_on_time'] = delivery['delivery_days'] <= delivery['estimated_days']
    delivery = delivery.drop_duplicates(subset=['order_id', 'seller_id'], keep='first')

    # Aggregate seller metrics
    seller_revenue = seller_items.groupby('seller_id').agg({
        'order_id': 'nunique',
        'price': 'sum',
        'freight_value': 'sum',
        'seller_city': 'first',
        'seller_state': 'first'
    }).reset_index()
    seller_revenue.columns = ['seller_id', 'total_orders', 'total_revenue', 'total_freight', 'seller_city', 'seller_state']

    # Add review scores
    seller_reviews = reviews.groupby('seller_id').agg({
        'review_score': ['mean', 'count']
    }).reset_index()
    seller_reviews.columns = ['seller_id', 'avg_review_score', 'review_count']

    # Add delivery performance
    seller_delivery = delivery.groupby('seller_id').agg({
        'is_on_time': 'mean',
        'delivery_days': 'mean'
    }).reset_index()
    seller_delivery.columns = ['seller_id', 'on_time_rate', 'avg_delivery_days']

    # Merge all
    seller_performance = seller_revenue.merge(seller_reviews, on='seller_id', how='left')
    seller_performance = seller_performance.merge(seller_delivery, on='seller_id', how='left')

    # Calculate composite score (normalized)
    # Normalize each metric to 0-100 scale
    seller_performance['revenue_score'] = (
        (seller_performance['total_revenue'] - seller_performance['total_revenue'].min()) /
        (seller_performance['total_revenue'].max() - seller_performance['total_revenue'].min()) * 100
    )
    seller_performance['review_score_normalized'] = seller_performance['avg_review_score'] / 5 * 100
    seller_performance['delivery_score'] = seller_performance['on_time_rate'] * 100

    # Composite score: weighted average
    seller_performance['composite_score'] = (
        seller_performance['revenue_score'] * 0.3 +
        seller_performance['review_score_normalized'] * 0.4 +
        seller_performance['delivery_score'] * 0.3
    ).round(2)

    # Round metrics
    seller_performance['avg_review_score'] = seller_performance['avg_review_score'].round(2)
    seller_performance['on_time_rate'] = (seller_performance['on_time_rate'] * 100).round(2)
    seller_performance['avg_delivery_days'] = seller_performance['avg_delivery_days'].round(1)
    seller_performance['total_revenue'] = seller_performance['total_revenue'].round(2)

    # Rank sellers
    seller_performance['seller_rank'] = seller_performance['composite_score'].rank(ascending=False, method='min').astype('Int64')

    # Save
    seller_performance.to_csv(EXPORT_PATH / 'seller_performance.csv', index=False)
    print(f"  - Exported {len(seller_performance):,} sellers")

    return seller_performance


def main():
    """Main export function."""
    print("=" * 60)
    print("TABLEAU DATA EXPORT")
    print("=" * 60)
    print(f"\nDatabase: {DB_PATH}")
    print(f"Export path: {EXPORT_PATH}\n")

    # Connect to database
    conn = sqlite3.connect(DB_PATH)

    try:
        # Export all datasets
        orders_fact = export_orders_fact(conn)
        product_sales = export_product_sales(conn)
        customer_segments = export_customer_segments(conn)
        monthly_metrics = export_monthly_metrics(conn)
        seller_performance = export_seller_performance(conn)

        print("\n" + "=" * 60)
        print("EXPORT COMPLETE")
        print("=" * 60)
        print(f"\nFiles exported to: {EXPORT_PATH}")
        print("\nFiles created:")
        print("  - orders_fact.csv")
        print("  - product_sales.csv")
        print("  - customer_segments.csv")
        print("  - monthly_metrics.csv")
        print("  - seller_performance.csv")

        # Print summary statistics
        print("\n" + "=" * 60)
        print("SUMMARY STATISTICS")
        print("=" * 60)
        print(f"\nOrders: {len(orders_fact):,}")
        print(f"Product sales (line items): {len(product_sales):,}")
        print(f"Customers with segments: {len(customer_segments):,}")
        print(f"Months of data: {len(monthly_metrics):,}")
        print(f"Sellers: {len(seller_performance):,}")

        # Key metrics
        print("\nKey Metrics:")
        delivered = orders_fact[orders_fact['order_status'] == 'delivered']
        print(f"  - Total Revenue: R$ {delivered['total_payment_value'].sum():,.2f}")
        print(f"  - Delivered Orders: {len(delivered):,}")
        print(f"  - Unique Customers: {orders_fact['customer_unique_id'].nunique():,}")
        print(f"  - Avg Order Value: R$ {delivered['total_payment_value'].mean():,.2f}")
        print(f"  - Avg Review Score: {delivered['review_score'].mean():.2f}")

    finally:
        conn.close()

    print("\n" + "=" * 60)


if __name__ == '__main__':
    main()
