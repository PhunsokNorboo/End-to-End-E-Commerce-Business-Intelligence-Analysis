# Tableau Dashboard - Setup Instructions

This guide walks you through creating the Olist E-commerce Business Intelligence dashboard in Tableau Public.

---

## Prerequisites

1. **Tableau Public Desktop App** (free)
   - Download from: https://public.tableau.com/en-us/s/download
   - Available for Windows and macOS
   - Create a free Tableau Public account for publishing

2. **Data Files** (already exported)
   - Location: `data/tableau_exports/`
   - Files:
     - `orders_fact.csv` (99,441 rows)
     - `product_sales.csv` (112,650 rows)
     - `customer_segments.csv` (93,358 rows)
     - `monthly_metrics.csv` (23 rows)
     - `seller_performance.csv` (2,970 rows)

---

## Step 1: Connect to Data

### 1.1 Open Tableau Public

1. Launch Tableau Public Desktop
2. You'll see the "Connect" pane on the left

### 1.2 Connect to CSV Files

1. Click **"Text file"** under "To a File"
2. Navigate to: `[project_path]/data/tableau_exports/`
3. Select `orders_fact.csv` and click **Open**
4. The data preview will appear

### 1.3 Add Additional Data Sources

1. In the Data Source tab, click **"Add"** in the left pane
2. Select **"Text file"** again
3. Add each remaining CSV file:
   - `product_sales.csv`
   - `customer_segments.csv`
   - `monthly_metrics.csv`
   - `seller_performance.csv`

### 1.4 Create Relationships (Optional)

For cross-file analysis, create relationships:

1. Drag `orders_fact` to the canvas
2. Drag `product_sales` next to it
3. Tableau will suggest a relationship on `order_id` - accept it
4. Drag `customer_segments` and relate on `customer_unique_id`

**Note:** For this dashboard, most pages use single data sources, so relationships are optional.

---

## Step 2: Create the Dashboard Structure

### 2.1 Create a New Dashboard

1. Click the **"New Dashboard"** icon at the bottom (grid icon)
2. Set size: **Fixed size - 1400 x 900 pixels**
   - Click "Size" dropdown in the left pane
   - Select "Fixed size" and enter dimensions

### 2.2 Create Dashboard Tabs

You'll create 4 dashboard pages:
1. Executive Overview
2. Customer Intelligence
3. Operations & Satisfaction
4. Seller Scorecard

Right-click the dashboard tab to rename each one.

---

## Step 3: Build Page 1 - Executive Overview

### 3.1 Create KPI Sheets

For each KPI, create a new worksheet:

**Total Revenue:**
1. New Worksheet > Rename to "KPI - Revenue"
2. Data source: `orders_fact`
3. Drag `total_payment_value` to Text
4. Right-click > Format > Currency (R$)
5. Filter: `order_status` = "delivered"
6. Make it a big number display (Format > Font > Size 36)

**Total Orders:**
1. New Worksheet > "KPI - Orders"
2. Drag `order_id` to Text > Change to COUNT DISTINCT
3. Format as number with thousands separator

**Unique Customers:**
1. New Worksheet > "KPI - Customers"
2. Drag `customer_unique_id` to Text > COUNT DISTINCT

**Average Order Value:**
1. Create calculated field: `SUM([total_payment_value]) / COUNTD([order_id])`
2. Drag to Text

**Average Review Score:**
1. Drag `review_score` to Text > Change to AVG
2. Format to 1 decimal place

### 3.2 Create Monthly Revenue Trend

1. New Worksheet > "Monthly Revenue Trend"
2. Data source: `monthly_metrics`
3. Drag `month_date` to Columns (set to Month continuous)
4. Drag `total_revenue` to Rows
5. Change mark type to **Line**
6. Color: `#2E86AB`
7. Add area fill (Analytics > Trend Line or dual axis technique)

### 3.3 Create Revenue by State

1. New Worksheet > "Revenue by State"
2. Data source: `orders_fact`
3. Drag `customer_state` to Rows
4. Drag `total_payment_value` to Columns
5. Sort descending
6. Filter to Top 10 (right-click state > Filter > Top > By field > Top 10)
7. Color: `#2E86AB`

### 3.4 Create Top Categories Chart

1. New Worksheet > "Top Categories"
2. Data source: `product_sales`
3. Drag `product_category_name_english` to Rows
4. Create calculated field: `[price] + [freight_value]`
5. Drag to Columns
6. Filter to Top 10 categories
7. Sort descending
8. Add labels

### 3.5 Assemble Dashboard

1. Go to Dashboard 1 (Executive Overview)
2. Drag sheets from left pane to canvas:
   - KPI cards in a horizontal container at top
   - Revenue trend on left (2/3 width)
   - State chart on right (1/3 width)
   - Categories at bottom (full width)
3. Add filters (Date Range) and set to "Apply to All Worksheets"

---

## Step 4: Build Page 2 - Customer Intelligence

### 4.1 Create Segment Donut Chart

1. New Worksheet > "Customer Segments"
2. Data source: `customer_segments`
3. Drag `segment` to Color
4. Drag `customer_unique_id` to Angle (Pie chart)
5. Change mark type to Pie
6. Assign custom colors:
   - Champions: `#2ECC71`
   - Loyal Customers: `#3498DB`
   - New Customers: `#9B59B6`
   - Potential Loyalists: `#1ABC9C`
   - At Risk: `#E74C3C`
   - Hibernating: `#95A5A6`
   - Need Attention: `#F39C12`
7. Add donut hole (dual axis with blank pie)

### 4.2 Create Revenue by Segment

1. New Worksheet > "Segment Revenue"
2. Drag `segment` to Rows
3. Drag `monetary` to Columns (SUM)
4. Sort descending
5. Use same segment colors

### 4.3 Create New vs Returning Chart

1. New Worksheet > "New vs Returning"
2. Data source: `monthly_metrics`
3. Drag `month_date` to Columns
4. Drag `new_customers` and `returning_customers` to Rows
5. Set to dual axis or stacked area
6. Colors: New = `#3498DB`, Returning = `#2ECC71`

### 4.4 Assemble Dashboard

Arrange sheets according to layout in `tableau_spec.md`.

---

## Step 5: Build Page 3 - Operations & Satisfaction

### 5.1 Create On-Time Rate Gauge

Option A - Use a donut/radial chart
Option B - Use text with conditional formatting

For simplicity, create a large KPI:
1. New Worksheet > "On-Time Rate"
2. Calculated field: `SUM(IF [on_time_delivery] = "On Time" THEN 1 ELSE 0 END) / COUNT([order_id])`
3. Format as percentage
4. Color based on value (green >90%, yellow 80-90%, red <80%)

### 5.2 Create Delivery Distribution Histogram

1. New Worksheet > "Delivery Distribution"
2. Data source: `orders_fact`
3. Drag `actual_delivery_days` to Columns
4. Right-click > Create Bins (bin size: 5)
5. Drag bin to Columns
6. Drag `order_id` to Rows > COUNT
7. Filter to `order_status` = "delivered"

### 5.3 Create Review Score Distribution

1. New Worksheet > "Review Distribution"
2. Drag `review_score` to Columns (Dimension)
3. Drag `order_id` to Rows > COUNT
4. Assign colors:
   - 5: `#28A745`
   - 4: `#8BC34A`
   - 3: `#F18F01`
   - 2: `#FF5722`
   - 1: `#DC3545`

### 5.4 Create Scatter Plot

1. New Worksheet > "Delay vs Rating"
2. Drag `delivery_delay_days` to Columns
3. Drag `review_score` to Rows (Dimension or AVG)
4. Drag `order_id` to Detail
5. Add trend line (Analytics > Trend Line)
6. Consider sampling for performance

### 5.5 Assemble Dashboard

Arrange according to spec layout.

---

## Step 6: Build Page 4 - Seller Scorecard

### 6.1 Create Seller Performance Table

1. New Worksheet > "Seller Table"
2. Data source: `seller_performance`
3. Drag to Rows:
   - `seller_rank`
   - `seller_id`
   - `seller_state`
   - `total_revenue`
   - `total_orders`
   - `avg_review_score`
   - `on_time_rate`
   - `composite_score`
4. Format each column appropriately
5. Add conditional formatting on `composite_score`

### 6.2 Create Bubble Chart

1. New Worksheet > "Revenue vs Rating Bubble"
2. Drag `total_revenue` to Columns
3. Drag `avg_review_score` to Rows
4. Drag `total_orders` to Size
5. Drag `composite_score` to Color
6. Drag `seller_id` to Detail
7. Add reference lines at averages

### 6.3 Create Seller Map

1. New Worksheet > "Seller Map"
2. Drag `seller_state` to Detail
3. Change mark type to Map
4. Drag `seller_id` to Color > COUNT
5. Set geographic role if needed

### 6.4 Assemble Dashboard

Arrange according to spec layout.

---

## Step 7: Add Interactivity

### 7.1 Add Filter Actions

1. Dashboard > Actions > Add Action > Filter
2. Configure:
   - Source: Chart that triggers filter
   - Target: Sheets to filter
   - Run on: Select
   - Clearing: Show all values

### 7.2 Add Highlight Actions

1. Dashboard > Actions > Add Action > Highlight
2. Configure:
   - Source: All sheets
   - Target: All sheets
   - Run on: Hover

### 7.3 Create Navigation

1. Add navigation buttons between pages:
   - Dashboard > Objects > Navigation
   - Configure to link to each dashboard page

---

## Step 8: Format and Polish

### 8.1 Apply Consistent Formatting

1. Format > Workbook Theme > Select or customize
2. Apply color palette: Create custom palette in Preferences file

### 8.2 Add Titles and Labels

1. Add dashboard title (Text object)
2. Add chart titles
3. Add data source attribution in footer

### 8.3 Hide Sheet Tabs (Optional)

1. Right-click worksheet tabs > Hide All Sheets

---

## Step 9: Publish to Tableau Public

### 9.1 Save Workbook

1. File > Save to Tableau Public As...
2. Log in with your Tableau Public credentials
3. Enter workbook name: "Olist E-commerce BI Dashboard"
4. Click Save

### 9.2 Configure Public Settings

After publishing:
1. Go to your Tableau Public profile
2. Find the workbook
3. Click "Edit Details":
   - Add description
   - Add tags (e-commerce, business intelligence, Brazil, retail)
   - Set visibility to Public
4. Copy the public URL for sharing

### 9.3 Get Embed Code

1. On the published viz, click "Share"
2. Copy embed code for website integration
3. Copy link for direct sharing

---

## Troubleshooting

### Common Issues

**Data not loading:**
- Check file paths are correct
- Ensure CSV files have headers
- Check for special characters in file names

**Map not showing Brazil:**
- Right-click state field > Geographic Role > State/Province
- If still not working, create a calculated field mapping state codes

**Performance issues:**
- Use extracts instead of live connections
- Aggregate data at higher levels
- Limit the number of marks displayed

**Filters not working across pages:**
- Ensure "Apply to All Using This Data Source" is selected
- Check data source relationships

---

## Resources

- [Tableau Public Gallery](https://public.tableau.com/gallery/)
- [Tableau Community Forums](https://community.tableau.com/)
- [Tableau Knowledge Base](https://kb.tableau.com/)
- Dashboard Specification: See `tableau_spec.md` in this folder

---

## File Summary

| File | Purpose |
|------|---------|
| `tableau_spec.md` | Detailed dashboard specifications |
| `README.md` | This setup guide |
| `../data/tableau_exports/*.csv` | Data files for Tableau |
| `../scripts/export_tableau_data.py` | Script to regenerate data exports |

---

**Happy Visualizing!**
