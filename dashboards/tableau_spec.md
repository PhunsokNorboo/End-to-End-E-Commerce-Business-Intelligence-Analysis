# Tableau Dashboard Specification

**Project:** Olist E-commerce Business Intelligence
**Version:** 1.0
**Date:** 2026-02-04

---

## Overview

This specification defines a 4-page interactive Tableau dashboard for the Olist e-commerce marketplace analysis. The dashboard is designed for executive stakeholders and operational teams to monitor business performance, customer behavior, and seller operations.

---

## Data Sources

All data files are located in `data/tableau_exports/`:

| File | Description | Rows | Key Fields |
|------|-------------|------|------------|
| `orders_fact.csv` | Main fact table with orders, payments, reviews | 99,441 | order_id, total_payment_value, review_score, delivery metrics |
| `product_sales.csv` | Product line items with categories | 112,650 | product_id, price, product_category_name_english |
| `customer_segments.csv` | RFM segmentation data | 93,358 | customer_unique_id, segment, rfm_score |
| `monthly_metrics.csv` | Monthly aggregated KPIs | 23 | month_date, total_revenue, unique_customers |
| `seller_performance.csv` | Seller scorecard data | 2,970 | seller_id, composite_score, on_time_rate |

---

## Color Palette

Use consistent colors across all visualizations:

| Purpose | Color Name | Hex Code | Usage |
|---------|-----------|----------|-------|
| Primary | Ocean Blue | `#2E86AB` | Primary metrics, titles, bars |
| Secondary | Magenta | `#A23B72` | Secondary metrics, accents |
| Success | Forest Green | `#28A745` | Positive trends, on-time, good reviews |
| Warning | Sunset Orange | `#F18F01` | Caution indicators, moderate values |
| Danger | Alert Red | `#DC3545` | Negative trends, late delivery, low scores |
| Neutral | Slate Gray | `#6C757D` | Backgrounds, secondary text |
| Light | Cloud White | `#F8F9FA` | Dashboard backgrounds |

### Segment Colors

| Segment | Hex Code |
|---------|----------|
| Champions | `#2ECC71` (Emerald Green) |
| Loyal Customers | `#3498DB` (Bright Blue) |
| New Customers | `#9B59B6` (Amethyst Purple) |
| Potential Loyalists | `#1ABC9C` (Turquoise) |
| At Risk | `#E74C3C` (Alizarin Red) |
| Hibernating | `#95A5A6` (Concrete Gray) |
| Need Attention | `#F39C12` (Sun Flower Yellow) |

---

## PAGE 1: Executive Overview

**Purpose:** High-level business performance snapshot for executive review

### Layout

```
+------------------------------------------------------------------+
|                    OLIST E-COMMERCE DASHBOARD                     |
|                      Executive Overview                           |
+------------------------------------------------------------------+
|  [Filter Bar: Date Range | State | Category]                      |
+------------------------------------------------------------------+
| [KPI 1]    | [KPI 2]     | [KPI 3]    | [KPI 4]    | [KPI 5]     |
| Revenue    | Orders      | Customers  | AOV        | Avg Rating  |
+------------------------------------------------------------------+
|                                              |                     |
|     Monthly Revenue Trend (Line Chart)       |  Revenue by State   |
|                                              |  (Map or Bar Chart) |
|                                              |                     |
+----------------------------------------------+---------------------+
|                                                                    |
|           Top 10 Product Categories (Horizontal Bar Chart)         |
|                                                                    |
+------------------------------------------------------------------+
```

### KPI Cards (Top Row)

| KPI | Data Source | Calculation | Format | Color |
|-----|-------------|-------------|--------|-------|
| Total Revenue | orders_fact.csv | SUM(total_payment_value) WHERE order_status='delivered' | R$ #,##0.00 | `#2E86AB` |
| Total Orders | orders_fact.csv | COUNT(DISTINCT order_id) WHERE order_status='delivered' | #,##0 | `#2E86AB` |
| Unique Customers | orders_fact.csv | COUNT(DISTINCT customer_unique_id) | #,##0 | `#2E86AB` |
| Avg Order Value | orders_fact.csv | SUM(total_payment_value) / COUNT(DISTINCT order_id) | R$ #,##0.00 | `#2E86AB` |
| Avg Review Score | orders_fact.csv | AVG(review_score) | 0.0 with star icon | Conditional (Green >4, Yellow 3-4, Red <3) |

### Charts

#### 1. Monthly Revenue Trend (Line Chart)

- **Data Source:** monthly_metrics.csv
- **X-Axis:** month_date (continuous, Month Year format)
- **Y-Axis:** total_revenue
- **Line Color:** `#2E86AB`
- **Area Fill:** Light gradient of primary color
- **Features:**
  - Tooltip: Month, Revenue, % Change MoM
  - Trend line optional
  - Highlight current month

#### 2. Revenue by State (Map or Horizontal Bar)

- **Option A - Filled Map:**
  - Geographic: Brazil states (customer_state)
  - Color: Sequential gradient (light to `#2E86AB`)
  - Metric: SUM(total_payment_value)
  - Tooltip: State name, Revenue, % of Total

- **Option B - Horizontal Bar Chart (recommended for clarity):**
  - Y-Axis: customer_state (sorted by revenue)
  - X-Axis: SUM(total_payment_value)
  - Color: `#2E86AB`
  - Show top 10 states with "Others" aggregated
  - Labels: Revenue value on bar end

#### 3. Top 10 Product Categories (Horizontal Bar)

- **Data Source:** product_sales.csv
- **Y-Axis:** product_category_name_english (sorted descending by revenue)
- **X-Axis:** SUM(price + freight_value)
- **Limit:** Top 10 categories
- **Color:** Gradient from `#2E86AB` (highest) to `#A23B72` (lowest)
- **Labels:** Revenue amount at bar end
- **Tooltip:** Category, Revenue, Order Count, % of Total

### Filters (Apply to all charts)

| Filter | Field | Type |
|--------|-------|------|
| Date Range | order_purchase_timestamp | Date Range Slider |
| State | customer_state | Dropdown Multi-select |
| Product Category | product_category_name_english | Dropdown Multi-select |

---

## PAGE 2: Customer Intelligence

**Purpose:** Deep dive into customer segments, behavior, and value

### Layout

```
+------------------------------------------------------------------+
|                      Customer Intelligence                         |
+------------------------------------------------------------------+
|  [Filter Bar: Segment | Cohort Month | State]                     |
+------------------------------------------------------------------+
| [Segment KPI 1]  | [Segment KPI 2]  | [Segment KPI 3]             |
| Champions Count  | At Risk Count    | Avg CLV                     |
+------------------------------------------------------------------+
|                               |                                    |
|   Customer Segment Donut      |      Segment Value Analysis       |
|   (by count)                  |      (Revenue by Segment)          |
|                               |                                    |
+-------------------------------+------------------------------------+
|                                                                    |
|           Cohort Retention Heatmap                                 |
|           (Months since first purchase vs Cohort)                  |
|                                                                    |
+------------------------------------------------------------------+
|                                                                    |
|      New vs Returning Customers (Stacked Area Chart)              |
|                                                                    |
+------------------------------------------------------------------+
```

### KPI Cards

| KPI | Data Source | Calculation | Format |
|-----|-------------|-------------|--------|
| Champions | customer_segments.csv | COUNT WHERE segment='Champions' | #,##0 with percentage |
| At Risk Customers | customer_segments.csv | COUNT WHERE segment IN ('At Risk', 'Hibernating') | #,##0 (red color) |
| Avg Customer Lifetime Value | customer_segments.csv | AVG(monetary) | R$ #,##0.00 |

### Charts

#### 1. Customer Segment Donut Chart

- **Data Source:** customer_segments.csv
- **Metric:** COUNT(customer_unique_id)
- **Dimension:** segment
- **Colors:** Use segment colors defined above
- **Inner Label:** Total customer count
- **Tooltip:** Segment name, Count, Percentage
- **Order:** Champions > Loyal > Potential Loyalists > New > Need Attention > At Risk > Hibernating

#### 2. Revenue by Segment (Horizontal Bar)

- **Data Source:** customer_segments.csv
- **Y-Axis:** segment
- **X-Axis:** SUM(monetary)
- **Colors:** Use segment colors
- **Sort:** By revenue descending
- **Labels:** Revenue value

#### 3. Cohort Retention Heatmap

- **Note:** Requires pre-calculated cohort data. If not available, use static image from Python analysis.
- **Alternative:** Create from monthly_metrics.csv
- **Y-Axis:** Cohort month (first_purchase_date month)
- **X-Axis:** Months since first purchase (0-12)
- **Color:** Sequential (white to `#E74C3C` reversed - higher retention = greener)
- **Format:** Percentage with 1 decimal

#### 4. New vs Returning Customers (Stacked Area)

- **Data Source:** monthly_metrics.csv
- **X-Axis:** month_date
- **Measures:** new_customers, returning_customers (stacked)
- **Colors:**
  - New Customers: `#3498DB`
  - Returning Customers: `#2ECC71`
- **Tooltip:** Month, New Count, Returning Count, % New

### Filters

| Filter | Field | Type |
|--------|-------|------|
| Segment | segment | Dropdown Multi-select |
| State | customer_state | Dropdown Multi-select |
| First Purchase Month | first_purchase_date | Month Picker |

---

## PAGE 3: Operations & Satisfaction

**Purpose:** Monitor delivery performance and customer satisfaction

### Layout

```
+------------------------------------------------------------------+
|                   Operations & Satisfaction                        |
+------------------------------------------------------------------+
|  [Filter Bar: Date Range | State | Category]                      |
+------------------------------------------------------------------+
| [On-Time Rate]   | [Avg Delivery]  | [Avg Rating]  | [5-Star %]  |
|    Gauge         |   Days KPI      |   KPI         |    KPI      |
+------------------------------------------------------------------+
|                               |                                    |
|   Delivery Time Distribution  |    Review Score Distribution      |
|   (Histogram)                 |    (Bar Chart)                    |
|                               |                                    |
+-------------------------------+------------------------------------+
|                                                                    |
|       Delivery Delay vs Review Score (Scatter Plot)               |
|       with trend line                                              |
|                                                                    |
+------------------------------------------------------------------+
|                                                                    |
|       Monthly Performance Trends (Dual-Axis Line Chart)           |
|       On-Time Rate + Avg Review Score over time                    |
|                                                                    |
+------------------------------------------------------------------+
```

### KPI Cards

| KPI | Data Source | Calculation | Format | Conditional Color |
|-----|-------------|-------------|--------|-------------------|
| On-Time Delivery Rate | orders_fact.csv | COUNT(on_time='On Time') / COUNT(*) | ##.#% | Green >90%, Yellow 80-90%, Red <80% |
| Avg Delivery Days | orders_fact.csv | AVG(actual_delivery_days) | #.0 days | Green <10, Yellow 10-15, Red >15 |
| Avg Review Score | orders_fact.csv | AVG(review_score) | 0.0 / 5.0 | Green >4, Yellow 3-4, Red <3 |
| 5-Star Reviews % | orders_fact.csv | COUNT(review_score=5) / COUNT(*) | ##.#% | Primary color |

### Charts

#### 1. On-Time Delivery Rate Gauge

- **Type:** Gauge or Radial
- **Metric:** On-time delivery rate
- **Bands:**
  - 0-70%: Red (`#DC3545`)
  - 70-85%: Yellow (`#F18F01`)
  - 85-100%: Green (`#28A745`)
- **Needle:** Current rate
- **Label:** Large percentage in center

#### 2. Delivery Time Distribution (Histogram)

- **Data Source:** orders_fact.csv (WHERE order_status='delivered')
- **X-Axis:** actual_delivery_days (bins of 5 days)
- **Y-Axis:** COUNT of orders
- **Color:** `#2E86AB`
- **Reference Line:** Average delivery days (dashed)
- **Reference Band:** Target delivery window (if applicable)

#### 3. Review Score Distribution (Bar Chart)

- **Data Source:** orders_fact.csv
- **X-Axis:** review_score (1-5)
- **Y-Axis:** COUNT of reviews
- **Colors:**
  - 5: `#28A745` (Green)
  - 4: `#8BC34A` (Light Green)
  - 3: `#F18F01` (Orange)
  - 2: `#FF5722` (Deep Orange)
  - 1: `#DC3545` (Red)
- **Labels:** Count and percentage on each bar

#### 4. Delivery Delay vs Review Score (Scatter Plot)

- **Data Source:** orders_fact.csv (WHERE order_status='delivered')
- **X-Axis:** delivery_delay_days (can be negative for early delivery)
- **Y-Axis:** review_score
- **Detail:** order_id (for point density)
- **Color:** By review_score (gradient)
- **Trend Line:** Linear regression
- **Annotations:** Average delay, average score
- **Note:** Use random sampling if too many points (10k max)

#### 5. Monthly Performance Trends (Dual-Axis Line)

- **Data Source:** monthly_metrics.csv
- **X-Axis:** month_date
- **Left Y-Axis:** on_time_delivery_rate (%)
- **Right Y-Axis:** avg_review_score (1-5)
- **Line Colors:**
  - On-Time Rate: `#28A745`
  - Avg Review: `#3498DB`
- **Synchronize axis scales for visual alignment**

### Filters

| Filter | Field | Type |
|--------|-------|------|
| Date Range | order_purchase_timestamp | Date Range |
| State | customer_state | Dropdown |
| Product Category | product_category_name_english | Dropdown |
| Delivery Status | on_time_delivery | Radio (All / On Time / Late) |

---

## PAGE 4: Seller Scorecard

**Purpose:** Evaluate and rank seller performance

### Layout

```
+------------------------------------------------------------------+
|                        Seller Scorecard                           |
+------------------------------------------------------------------+
|  [Filter Bar: State | Score Range | Category]                     |
+------------------------------------------------------------------+
| [Total Sellers]  | [Avg Score]    | [Top Seller]  | [At Risk]    |
|      KPI         |    KPI         |   Highlight   |   Count      |
+------------------------------------------------------------------+
|                                                                    |
|                 Seller Performance Table                          |
|   (Sortable by: Revenue, Rating, On-Time Rate, Composite Score)   |
|                                                                    |
+------------------------------------------------------------------+
|                               |                                    |
|  Revenue vs Review Score      |    Seller Geographic              |
|  Bubble Chart                 |    Distribution (Map)             |
|  (size = order count)         |                                    |
+-------------------------------+------------------------------------+
|                                                                    |
|           Seller Score Distribution (Histogram)                   |
|                                                                    |
+------------------------------------------------------------------+
```

### KPI Cards

| KPI | Data Source | Calculation | Format |
|-----|-------------|-------------|--------|
| Total Active Sellers | seller_performance.csv | COUNT(seller_id) | #,##0 |
| Avg Composite Score | seller_performance.csv | AVG(composite_score) | ##.# / 100 |
| Top Performer | seller_performance.csv | MAX(composite_score) seller_id | Seller ID + Score |
| At-Risk Sellers | seller_performance.csv | COUNT WHERE composite_score < 30 | #,##0 (red) |

### Charts

#### 1. Seller Performance Table

- **Data Source:** seller_performance.csv
- **Columns:**
  | Column | Field | Format | Sort |
  |--------|-------|--------|------|
  | Rank | seller_rank | #,##0 | Asc |
  | Seller ID | seller_id | Text (truncated) | - |
  | State | seller_state | Text | - |
  | Total Revenue | total_revenue | R$ #,##0 | Desc |
  | Orders | total_orders | #,##0 | Desc |
  | Avg Rating | avg_review_score | 0.00 | Desc |
  | On-Time % | on_time_rate | ##.#% | Desc |
  | Composite Score | composite_score | ##.# | Desc |

- **Features:**
  - Sortable columns
  - Conditional formatting on scores:
    - Green: >70
    - Yellow: 40-70
    - Red: <40
  - Search/filter functionality
  - Pagination (25 rows per page)

#### 2. Revenue vs Review Score Bubble Chart

- **Data Source:** seller_performance.csv
- **X-Axis:** total_revenue (log scale recommended)
- **Y-Axis:** avg_review_score
- **Size:** total_orders
- **Color:** composite_score (gradient)
- **Detail:** seller_id
- **Quadrant Lines:**
  - Horizontal: Average review score
  - Vertical: Average revenue
- **Quadrant Labels:**
  - High Revenue + High Rating = "Star Sellers"
  - High Revenue + Low Rating = "Needs Improvement"
  - Low Revenue + High Rating = "Rising Stars"
  - Low Revenue + Low Rating = "At Risk"

#### 3. Seller Geographic Distribution (Map)

- **Data Source:** seller_performance.csv
- **Geographic:** seller_state
- **Color:** COUNT(seller_id) or SUM(total_revenue)
- **Sequential Color:** Light to `#2E86AB`
- **Tooltip:** State, Seller Count, Total Revenue, Avg Score

#### 4. Seller Score Distribution (Histogram)

- **Data Source:** seller_performance.csv
- **X-Axis:** composite_score (bins of 10)
- **Y-Axis:** COUNT of sellers
- **Color:** Gradient by bin value
- **Reference Lines:**
  - Average score (solid)
  - 70 threshold (dashed, "Good")
  - 40 threshold (dashed, "At Risk")

### Filters

| Filter | Field | Type |
|--------|-------|------|
| Seller State | seller_state | Dropdown Multi-select |
| Score Range | composite_score | Range Slider |
| Minimum Orders | total_orders | Numeric Input (default: 10) |

---

## Interactivity Guidelines

### Cross-Filtering

Enable cross-filtering between charts on the same page:
- Clicking a segment in the donut filters the table
- Clicking a state on the map filters all other visualizations
- Date range filter affects all visualizations

### Tooltips

Standard tooltip format:
```
[Dimension Name]: [Value]
[Measure 1]: [Formatted Value]
[Measure 2]: [Formatted Value]
---
Click to filter
```

### Actions

| Action Type | Trigger | Effect |
|-------------|---------|--------|
| Filter | Click on chart element | Filter other sheets |
| Highlight | Hover | Highlight related data points |
| URL | Click on order_id | Open order details (if available) |

---

## Dashboard Settings

### General Settings

- **Size:** Fixed size (1400 x 900 pixels) for consistent display
- **Device Layouts:** Create separate layouts for Desktop and Tablet
- **Background Color:** `#F8F9FA`
- **Font Family:** Tableau default (Tableau Book) or Arial

### Header

- **Title:** "Olist E-commerce Business Intelligence"
- **Subtitle:** Page-specific (Executive Overview, Customer Intelligence, etc.)
- **Logo:** Optional - Olist logo in top-left corner
- **Last Updated:** Dynamic timestamp

### Footer

- **Data Source:** "Source: Olist Public Dataset"
- **Contact:** "Questions? Contact: [email]"
- **Export Options:** Enable PDF/Image/Data export

---

## Performance Optimization

1. **Use Extracts:** Convert data connections to Tableau extracts (.hyper)
2. **Aggregate Data:** Use monthly_metrics.csv for trend charts instead of order-level data
3. **Limit Rows:** Apply context filters before detail-level visualizations
4. **Optimize Calculations:** Pre-calculate metrics in Python export rather than in Tableau
5. **Reduce Marks:** Limit scatter plots to 10,000 points; use sampling if needed

---

## Publishing Checklist

Before publishing to Tableau Public:

- [ ] Remove any sensitive data (no PII, no internal notes)
- [ ] Verify all filters work correctly
- [ ] Test interactivity between all pages
- [ ] Check color contrast for accessibility
- [ ] Add alt-text to charts for screen readers
- [ ] Enable "Show Sheets as Tabs" for easy navigation
- [ ] Set appropriate sharing permissions
- [ ] Add dashboard description for Tableau Public profile

---

## Appendix: Calculated Fields

### Tableau Calculated Fields to Create

```
// On-Time Flag
IF [delivery_delay_days] <= 0 THEN "On Time" ELSE "Late" END

// Customer Type
IF [frequency] = 1 THEN "One-Time" ELSE "Repeat" END

// Revenue Tier
IF [total_payment_value] >= 500 THEN "High Value"
ELSEIF [total_payment_value] >= 100 THEN "Medium Value"
ELSE "Low Value"
END

// Review Category
CASE [review_score]
    WHEN 5 THEN "Excellent"
    WHEN 4 THEN "Good"
    WHEN 3 THEN "Average"
    WHEN 2 THEN "Poor"
    WHEN 1 THEN "Very Poor"
END

// Delivery Status Color
IF [delivery_delay_days] <= -3 THEN "Early"
ELSEIF [delivery_delay_days] <= 0 THEN "On Time"
ELSEIF [delivery_delay_days] <= 7 THEN "Slightly Late"
ELSE "Very Late"
END
```

---

**End of Specification**
