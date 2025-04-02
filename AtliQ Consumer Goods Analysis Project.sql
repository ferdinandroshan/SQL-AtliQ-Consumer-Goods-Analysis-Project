# Atliq Hardwares Problem and Solution Queries

use gdb0041;
select * from dim_customer;
# heirarchy is as follows: division -> segment -> category -> product -> variant

# selecting customer id for Croma
select * from dim_customer where customer like "%croma%" and market = "India";

# croma customer code  is 90002002
# select croma by fiscal year & product details
select * from fact_sales_monthly where customer_code = 90002002
and year(date_add(date, interval 4 month)) = 2021
order by date desc;

## Checking the Date Add Function to add 4 months. This is because AtliQ Fiscal Years Starts on September 1st. 
select date_add("2020-01-01", interval 4 month);

# creating a sql user defined function get_fiscal_year, this will help to correctly query the fiscal year & is more efficient
## CREATE FUNCTION `get_fiscal_year` (
## 	calendar_date date
## ) RETURNS INTEGER
## DETERMINISTIC
## BEGIN
##	DECLARE fiscal_year int;
##    SET fiscal_year = YEAR(DATE_ADD(calendar_date, INTERVAL 4 MONTH));
##    RETURN fiscal_year;
## END

# calling it with the new function
select * from fact_sales_monthly where customer_code = 90002002
and get_fiscal_year(date) = 2021
order by date ASC;

# created another user defined function for Quarters
# code for writing get_fiscal_quarter function
## CREATE FUNCTION `get_fiscal_quarter` (
## calendar_date date
## ) RETURNS CHAR(2)
## DETERMINISTIC
## BEGIN
##    DECLARE fiscal_month int;
##    DECLARE fiscal_qtr char(2);
##    SET fiscal_month = MONTH(calendar_date);
    
##    CASE 
## 		  when fiscal_month in (9,10,11) then SET fiscal_qtr = "Q1";
##        when fiscal_month in (12,1,2) then SET fiscal_qtr ="Q2";
##        when fiscal_month in (3,4,5) then SET fiscal_qtr ="Q3";
##        when fiscal_month in (6,7,8) then SET fiscal_qtr ="Q4";
## 	  END CASE;
##    RETURN fiscal_qtr;
## END


select * from fact_sales_monthly
where customer_code = 90002002 and 
get_fiscal_year(date) = "2021" and 
get_fiscal_quarter(date) = "Q4"
order by date asc
limit 1000000;

# expanding the code to fit into the picture both product name and variant details 
select 
	s.date, s.product_code,
    p.product, p.variant, s.sold_quantity 
from fact_sales_monthly s
join dim_product p
on s.product_code=p.product_code
where customer_code = 90002002 and 
get_fiscal_year(date) = "2021" and 
get_fiscal_quarter(date) = "Q4"
order by date asc
limit 1000000;

# expanding the code to fit into the picture both gross price & date
select 
	s.date, s.product_code,
    p.product, p.variant, s.sold_quantity, 
    round(g.gross_price,2) as gross_price,
    round(s.sold_quantity * g.gross_price, 2) as gross_price_total 
from fact_sales_monthly s
join dim_product p
on s.product_code=p.product_code
join fact_gross_price g
on 
	g.product_code = s.product_code and 
	g.fiscal_year = get_fiscal_year(s.date)
where customer_code = 90002002 and 
get_fiscal_year(date) = "2021" 
order by date asc
limit 1000000;

# creating a new stored procedure with multiple values
select 
    sum(s.sold_quantity) as total_qty
from fact_sales_monthly s
join dim_customer c
on s.customer_code = c.customer_code
where get_fiscal_year(s.date) = 2021 and c.market = "India"
group by c.market;

# stored procedure for inputing multple variable, actual code
-- CREATE PROCEDURE `get_market_badge` (
-- 	IN in_market varchar(45),
--     IN in_fiscal_year YEAR,
--     OUT out_badge varchar(45)
-- )
-- BEGIN
-- 	DECLARE qty INT DEFAULT 0;
--     
--  #set default market to be india 
--  if in_market = "" then 
-- 		set in_market = "India";
-- 	end if;
--     #retrieve total qty for a given market + FY
-- 	select 
-- 		sum(s.sold_quantity) into qty
-- 	from fact_sales_monthly s
-- 	join dim_customer c
-- 	on s.customer_code = c.customer_code
-- 	where 
-- 		get_fiscal_year(s.date) = in_fiscal_year and 
--         c.market = in_market
-- 	group by c.market;
--     
--     #determine market batch
--     if qty > 5000000 then 
-- 		set out_badge = "Gold";
-- 	else 
-- 		set out_badge = "Silver";
-- 	end if;
-- END


## combining the pre-invoice discount tables
use gdb0041;

# use explain analyze to check performance
# this query takes too long, need to update the user_defined_function
EXPLAIN ANALYZE
select 
	s.date, s.product_code,
    p.product, p.variant, s.sold_quantity, 
    round(g.gross_price,2) as gross_price,
    round(s.sold_quantity * g.gross_price, 2) as gross_price_total,
    round(pre.pre_invoice_discount_pct, 2) as pre_inv_disc
from fact_sales_monthly s
join dim_product p
on s.product_code=p.product_code
join fact_gross_price g
on 
	g.product_code = s.product_code and 
	g.fiscal_year = get_fiscal_year(s.date)
join fact_pre_invoice_deductions pre
on
	s.customer_code = pre.customer_code and
    pre.fiscal_year = get_fiscal_year(s.date) 
where get_fiscal_year(date) = 2021
order by date asc
limit 1000000; 

# optimising the code to join with date table to optimise query time
select 
	s.date, s.product_code,
    p.product, p.variant, s.sold_quantity, 
    round(g.gross_price,2) as gross_price,
    round(s.sold_quantity * g.gross_price, 2) as gross_price_total,
    round(pre.pre_invoice_discount_pct, 2) as pre_inv_disc
from fact_sales_monthly s
join dim_product p
on s.product_code=p.product_code
join dim_date dt
on s.date = dt.calendar_date
join fact_gross_price g
on 
	g.product_code = s.product_code and 
	g.fiscal_year = dt.fiscal_year
join fact_pre_invoice_deductions pre
on
	s.customer_code = pre.customer_code and
    pre.fiscal_year = dt.fiscal_year 
where dt.fiscal_year = 2021
order by date asc
limit 1000000;

# method two - directly add a generated column within fact table, avoids the extra join
use gdb0041;
select 
	s.date, s.product_code,
    p.product, p.variant, s.sold_quantity, 
    round(g.gross_price,2) as gross_price,
    round(s.sold_quantity * g.gross_price, 2) as gross_price_total,
    round(pre.pre_invoice_discount_pct, 2) as pre_inv_disc
from fact_sales_monthly s
join dim_product p
on s.product_code=p.product_code
join fact_gross_price g
on 
	g.product_code = s.product_code and 
	g.fiscal_year = s.fiscal_year
join fact_pre_invoice_deductions pre
on
	s.customer_code = pre.customer_code and
    pre.fiscal_year = s.fiscal_year 
where s.fiscal_year = 2021
order by date asc
limit 1000000;

# creating views 
# first run it by using CTE (basically pull net price after pre invoice disc)
WITH CTE1 as (
select 
	s.date, s.product_code,
    p.product, p.variant, s.sold_quantity, 
    round(g.gross_price,2) as gross_price,
    round(s.sold_quantity * g.gross_price, 2) as gross_price_total,
    pre.pre_invoice_discount_pct  as pre_inv_disc
from fact_sales_monthly s
join dim_product p
on s.product_code=p.product_code
join fact_gross_price g
on 
	g.product_code = s.product_code and 
	g.fiscal_year = s.fiscal_year
join fact_pre_invoice_deductions pre
on
	s.customer_code = pre.customer_code and
    pre.fiscal_year = s.fiscal_year 
where s.fiscal_year = 2021
order by date asc
limit 1000000)
# run the code to pull from CTE 
select 
	*,
	(gross_price_total - gross_price_total * pre_inv_disc) as net_invoice_sales
from CTE1;

# code to create a veiw instead 
CREATE VIEW `sales_preinv_discount` AS
select 
	s.date, s.customer_code,
    c.market, s.product_code,
    p.product, p.variant, s.sold_quantity, 
    round(g.gross_price,2) as gross_price,
    round(s.sold_quantity * g.gross_price, 2) as gross_price_total,
    pre.pre_invoice_discount_pct  as pre_inv_disc
from fact_sales_monthly s
join dim_product p
on s.product_code=p.product_code
join dim_customer c
on s.customer_code = c.customer_code
join fact_gross_price g
on 
	g.product_code = s.product_code and 
	g.fiscal_year = s.fiscal_year
join fact_pre_invoice_deductions pre
on
	s.customer_code = pre.customer_code and
    pre.fiscal_year = s.fiscal_year 
order by date asc
limit 1000000;

# displaying the view now
SELECT * FROM sales_preinv_discount;

# querying upon the view now
select 
	*,
	(gross_price_total - gross_price_total * pre_inv_disc) as net_invoice_sales
from sales_preinv_discount;

# rewriting better
select 
	*,
	(1-pre_inv_disc)*gross_price_total as net_invoice_sales
from sales_preinv_discount;

# code to execute view along with the post invoice discount
select
	*,
	(1-pre_inv_disc)*gross_price_total as net_invoice_sales,
    (po.discounts_pct + po.other_deductions_pct) as post_invoice_discount_pct
from sales_preinv_discount s
join fact_post_invoice_deductions po
on 
	s.date=po.date and
    s.customer_code=po.customer_code and
    s.product_code=po.product_code
;

# creating a new view "sales_postinv_discount"
CREATE VIEW `sales_postinv_discount` AS
Select 
	s.date, s.fiscal_year, 
    s.customer_code, s.market,
    s.product_code, s.product, s.variant, 
    s.sold_quantity, s.gross_total_price, 
    s.pre_inv_disc,
	(1-pre_inv_disc)*gross_price_total as net_invoice_sales,
		(po.discounts_pct + po.other_deductions_pct) as post_invoice_discount_pct
	from sales_preinv_discount s
	join fact_post_invoice_deductions po
	on 
		s.date=po.date and
		s.customer_code=po.customer_code and
		s.product_code=po.product_code
;
	 
# using sales_postinv_discount
SELECT * FROM sales_postinv_discount;

# finally calculating net sales
SELECT 
	*,
    (1-post_invoice_discount_pct) * net_invoice_sales as net_sales
FROM sales_postinv_discount;

# creating view for net sales
CREATE VIEW `net_sales` AS
Select
	*,
    (1-post_invoice_discount_pct) * net_invoice_sales as net_sales
FROM sales_postinv_discount;

# create view for gross sales
CREATE VIEW `gross_sales` AS
select 
	s.date, s.customer_code,
    c.customer, c.market, 
    s.product_code, p.product, p.variant,
    s.sold_quantity, gp.gross_price, 
    (s.sold_quantity * gp.gross_price) as gross_price_total
from fact_sales_monthly s
join dim_customer c
	on s.customer_code=c.customer_code
join dim_product p
	on s.product_code=p.product_code
join fact_gross_price gp
	on s.product_code=gp.product_code and
    s.fiscal_year=gp.fiscal_year
limit 10000000;

# top markets & customers. 
# working on our net_sales view table and generating insights 

select * from net_sales
limit 10000000;

# generating top 5 markets by net sales in million
select 
	market,
    round(sum(net_sales)/1000000, 2) as net_sales_mln
from net_sales
where fiscal_year = 2021
group by market
order by net_sales_mln desc
limit 5;

# writing a stored procedure for top n markets by sales
-- CREATE PROCEDURE `get_top_n_markets_by_net_sales`(
-- 	in_fiscal_year INT,
--     in_top_n INT
-- )
-- BEGIN
-- 	select 
-- 		market,
-- 		round(sum(net_sales)/1000000, 2) as net_sales_mln
-- 	from net_sales
-- 	where fiscal_year = in_fiscal_year
-- 	group by market
-- 	order by net_sales_mln desc
-- 	limit in_top_n;
-- END

# writing query for top n customers
select 
	c.customer,
    round(sum(n.net_sales)/1000000, 2) as net_sales_mln
from net_sales n
join dim_customer c
on n.customer_code=c.customer_code
where fiscal_year = 2021
group by c.customer
order by net_sales_mln desc
limit 5;

# stored procedure code for top n customers
-- CREATE PROCEDURE `get_top_n_customers_by_net_sales`(
-- 	in_fiscal_year int,
--     in_market varchar(45),
--     in_top_n int
--     )
-- BEGIN
-- 	select 
-- 		c.customer,
-- 		round(sum(n.net_sales)/1000000, 2) as net_sales_mln
-- 	from net_sales n
-- 	join dim_customer c
-- 		on n.customer_code=c.customer_code
-- 	where fiscal_year = in_fiscal_year and
-- 		n.market=in_market
-- 	group by c.customer
-- 	order by net_sales_mln desc
-- 	limit in_top_n;
-- END

# stored procedure for top products
-- CREATE PROCEDURE `top_n_products` (
-- 	in_fiscal_year int,
--     in_top_n int)
-- BEGIN
-- 	select 
-- 		product,
-- 		round(sum(net_sales)/1000000, 2) as net_sales_mln
-- 	from net_sales
-- 	where fiscal_year = in_fiscal_year
-- 	group by product
-- 	order by net_sales_mln desc
-- 	limit in_top_n;
-- END

# code to directly pull top n customers
select 
	product,
    round(sum(net_sales)/1000000, 2) as net_sales_mln
from net_sales
where fiscal_year = 2021
group by product
order by net_sales_mln desc
limit 5;


# using window functions to perform further advanced analysis
with CTE1 AS (
	select 
		c.customer,
		round(sum(n.net_sales)/1000000, 2) as net_sales_mln
	from net_sales n
	join dim_customer c
		on n.customer_code=c.customer_code
	where fiscal_year = 2021 
	group by c.customer
	order by net_sales_mln desc)

select
	*,
    net_sales_mln * 100 / sum(net_sales_mln) over() as pct
from CTE1;


# find percentage share based on different regions 
with CTE1 AS (
	select 
		c.customer,
        c.region,
		round(sum(n.net_sales)/1000000, 2) as net_sales_mln
	from net_sales n
	join dim_customer c
		on n.customer_code=c.customer_code
	where fiscal_year = 2021 
	group by c.customer, c.region)

select
	*,
    net_sales_mln * 100 / sum(net_sales_mln) over(partition by region) as pct_region_share
from CTE1
order by region, net_sales_mln desc;

# using rank, dense_rank & row_rank to get top n products in each division by their quantity sold 
use gdb0041;

with cte1 as (
select
	p.division,
    p.product, 
    sum(sold_quantity) as total_qty
from fact_sales_monthly s
join dim_product p 
	on s.product_code=p.product_code
where fiscal_year = 2021
group by p.product),

cte2 as (
select 
	*,
    dense_rank() over(partition by division order by total_qty desc) as drnk
from cte1) 

select * from cte2 
where drnk <= 3
group by division, product;


# Retrieve the top 2 markets in every region by their gross sales amount in FY=2021
with cte1 as (
select
	c.market, c.region, 
    round(sum(s.sold_quantity * gp.gross_price)/1000000,2) as gross_sales_mln
from fact_sales_monthly s
join dim_customer c
	on s.customer_code = c.customer_code
join fact_gross_price gp
	on s.product_code = gp.product_code and 
    s.fiscal_year = gp.fiscal_year
where s.fiscal_year = 2021
group by c.market, c.region
order by gross_sales_mln desc), 

cte2 as (select
	*, 
    dense_rank() over(partition by region order by gross_sales_mln desc) as rnk
from cte1) 

select * from cte2 where rnk <= 2;

## firstly creating new table including both sold quantity and forecast quantity
use gdb0041;
create table fact_act_est
	(
        	select 
                    s.date as date,
                    s.fiscal_year as fiscal_year,
                    s.product_code as product_code,
                    s.customer_code as customer_code,
                    s.sold_quantity as sold_quantity,
                    f.forecast_quantity as forecast_quantity
        	from 
                    fact_sales_monthly s
        	left join fact_forecast_monthly f 
        	using (date, customer_code, product_code)
	)
	union
	(
        	select 
                    f.date as date,
                    f.fiscal_year as fiscal_year,
                    f.product_code as product_code,
                    f.customer_code as customer_code,
                    s.sold_quantity as sold_quantity,
                    f.forecast_quantity as forecast_quantity
        	from 
		    fact_forecast_monthly  f
        	left join fact_sales_monthly s 
        	using (date, customer_code, product_code)
	);

# update values where sold_quantity is 0
	update fact_act_est
	set sold_quantity = 0
	where sold_quantity is null;

# update values where forecast_quantity is 0
	update fact_act_est
	set forecast_quantity = 0
	where forecast_quantity is null;

select * from fact_act_est;

# creating with a CTE to run the code and find forecast_accuracy

with forecast_err_table as (
	select
		s.customer_code,
		sum(s.sold_quantity) as total_sold_qty,
        sum(s.forecast_quantity) as total_forecast_qty,
		sum((forecast_quantity - sold_quantity)) as net_err,
		sum((forecast_quantity - sold_quantity))*100/sum(forecast_quantity) as net_err_pct,
		sum(abs(forecast_quantity - sold_quantity)) as abs_err,
		sum(abs(forecast_quantity - sold_quantity))*100/sum(forecast_quantity) as abs_err_pct
	from fact_act_est s
	where s.fiscal_year = 2021
	group by customer_code)

select
	e.*, 
    c.customer,
    c.market,
    if (abs_err_pct > 100, 0 , 100-abs_err_pct) as forecast_accuracy
from forecast_err_table e
join dim_customer c
using (customer_code)
order by forecast_accuracy desc;

## creating a stored procedure for the same
-- CREATE PROCEDURE `get_forecast_accuracy`(
-- 	in_fiscal_year INT
-- )
-- BEGIN
-- 	with forecast_err_table as (
-- 		select
-- 			s.customer_code,
-- 			sum(s.sold_quantity) as total_sold_qty,
-- 			sum(s.forecast_quantity) as total_forecast_qty,
-- 			sum((forecast_quantity - sold_quantity)) as net_err,
-- 			sum((forecast_quantity - sold_quantity))*100/sum(forecast_quantity) as net_err_pct,
-- 			sum(abs(forecast_quantity - sold_quantity)) as abs_err,
-- 			sum(abs(forecast_quantity - sold_quantity))*100/sum(forecast_quantity) as abs_err_pct
-- 		from fact_act_est s
-- 		where s.fiscal_year = in_fiscal_year
-- 		group by customer_code)

-- 	select
-- 		e.*, 
-- 		c.customer,
-- 		c.market,
-- 		if (abs_err_pct > 100, 0 , 100-abs_err_pct) as forecast_accuracy
-- 	from forecast_err_table e
-- 	join dim_customer c
-- 	using (customer_code)
-- 	order by forecast_accuracy desc;
-- END

## instead of using CTE we can also just create a temporary table instead 
## code to create via a temporary table 
create temporary table forecast_err_table
	select
		s.customer_code,
		sum(s.sold_quantity) as total_sold_qty,
        sum(s.forecast_quantity) as total_forecast_qty,
		sum((forecast_quantity - sold_quantity)) as net_err,
		sum((forecast_quantity - sold_quantity))*100/sum(forecast_quantity) as net_err_pct,
		sum(abs(forecast_quantity - sold_quantity)) as abs_err,
		sum(abs(forecast_quantity - sold_quantity))*100/sum(forecast_quantity) as abs_err_pct
	from fact_act_est s
	where s.fiscal_year = 2021
	group by customer_code;

select
	e.*, 
    c.customer,
    c.market,
    if (abs_err_pct > 100, 0 , 100-abs_err_pct) as forecast_accuracy
from forecast_err_table e
join dim_customer c
using (customer_code)
order by forecast_accuracy desc;

# Creating a Temp Table for Forecasts in 2021
create temporary table forecast_2021
with forecast_err_table_2021 as (
	select
		s.customer_code,
        c.customer,
        c.market,
		sum(abs(forecast_quantity - sold_quantity))*100/sum(forecast_quantity) as abs_err_pct
	from fact_act_est s
    join dim_customer c
    on s.customer_code = c.customer_code
	where s.fiscal_year = 2021
	group by c.customer)

select
	e.*, 
    if (abs_err_pct > 100, 0 , 100-abs_err_pct) as forecast_accuracy_2021
from forecast_err_table_2021 e
order by forecast_accuracy_2021 desc;

# Creating a Temp Table for Forecasts in 2020
create temporary table forecast_2020
with forecast_err_table_2020 as (
	select
		s.customer_code,
        c.customer,
        c.market,
		sum(abs(forecast_quantity - sold_quantity))*100/sum(forecast_quantity) as abs_err_pct
	from fact_act_est s
    join dim_customer c
    on s.customer_code = c.customer_code
	where s.fiscal_year = 2020
	group by c.customer)

select
	e.*, 
    if (abs_err_pct > 100, 0 , 100-abs_err_pct) as forecast_accuracy_2020
from forecast_err_table_2020 e
order by forecast_accuracy_2020 desc;

select 
    f20.customer_code,
    f20.customer,
    f20.market,
    f20.forecast_accuracy_2020,
    f21.forecast_accuracy_2021
from forecast_2020 f20
join forecast_2021 f21
using (customer_code)
where f21.forecast_accuracy_2021 < f20.forecast_accuracy_2020
order by forecast_accuracy_2020;

select * from fact_sales_monthly where fiscal_year <> 2018;