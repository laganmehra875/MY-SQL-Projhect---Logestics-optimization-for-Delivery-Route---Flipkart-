use flipkart_project;
show tables;

# Task 1 – Data Cleaning & Preparation
-- 1.1 Identify and Delete Duplicate Order_ID records
-- To identify duplicate (order_id with >1 Count)

select * from flipkart_orders;
SELECT Order_ID, Count(*) as Row_no
FROM flipkart_orders
Group by order_id
Having count(*)>1;

-- 1.2 Replace NULL Traffic_Delay_Min with Average Delay for that Route

select * from flipkart_routes;

Update flipkart_routes r
JOIN (Select route_id, AVG(Traffic_Delay_Min) AS Avg_delay
from flipkart_routes WHERE Traffic_Delay_Min is NOT NULL
Group by Route_id) as Avg_table
on r.route_id = avg_table.Route_id
SET r.Traffic_Delay_Min= avg_table.avg_delay
Where r.Traffic_Delay_Min is NULL;


-- 1.3 Convert all date columns into YYYY-MM-DD format using SQL functions.

UPDATE flipkart_orders
SET 
    order_date = str_to_date(order_date, '%Y-%m-%d'),
    Expected_Delivery_Date = str_to_date(Expected_Delivery_Date, '%Y-%m-%d'),
    Actual_Delivery_Date = str_to_date(Actual_Delivery_Date, '%Y-%m-%d');
    
 UPDATE flipkart_shipmenttracking
SET 
    Checkpoint_time = str_to_date(checkpoint_time, '%Y-%m-%d %H:%i:%s');


select * from flipkart_shipmenttracking;
describe flipkart_orders;
select * from flipkart_orders;

-- 1.4 Ensure that no Actual_Delivery_Date is before Order_Date (flag such records).

SELECT 
    CASE
        WHEN Actual_Delivery_Date < Order_Date THEN 'Invalid'
        ELSE 'Valid'
    END AS Delivery_Flag,
    COUNT(*) AS Total_Orders
FROM flipkart_orders
GROUP BY Delivery_Flag;


# Task 2- Delivery Delay Analysis
-- 2.1 Calculate delivery delay (in days) for each order 

SELECT 
    order_id,
    order_date,
    Expected_Delivery_Date,
    Actual_Delivery_Date,
    DATEDIFF(Actual_Delivery_Date, Expected_Delivery_Date) AS Delivery_Delay_Days
FROM flipkart_orders;

-- 2.2 Find Top 10 delayed routes based on average delay days. 

Select Route_id, 
Avg(DATEDIFF(Actual_Delivery_Date, Expected_Delivery_Date)) AS Average_Delay_Days 
From flipkart_orders
Group by Route_id
Order by Average_delay_days DESC LIMIT 10;

-- 2.3 Use window functions to rank all orders by delay within each warehouse. 

SELECT 
    Warehouse_ID,
    Order_ID,
    Route_ID,
    DATEDIFF(Actual_Delivery_Date, Expected_Delivery_Date) AS Delay_Days,
    RANK() OVER (
        PARTITION BY Warehouse_ID
        ORDER BY DATEDIFF(Actual_Delivery_Date, Expected_Delivery_Date) DESC
    ) AS Delay_Rank
FROM flipkart_orders;


# Task 3- Route Optimization Insights
-- 3.1 For each route, calculate: 
-- ○ Average delivery time (in days). 

SELECT route_id,
ROUND(AVG(DATEDIFF(actual_delivery_date, order_date)),2) AS Avg_delivery_time_days
FROM flipkart_orders
GROUP BY route_id
ORDER BY Avg_delivery_time_days;

-- ○ Average traffic delay. 

Select * from flipkart_routes;
SELECT Route_id, AVG(traffic_delay_min) AS Avg_Traffic_Delay_Min
FROM flipkart_routes
GROUP BY Route_id;

-- ○ Distance-to-time efficiency ratio: Distance_KM / Average_Travel_Time_Min.
 
SELECT Route_ID, Distance_km/Average_travel_time_min as Efficiency_ratio 
FROM flipkart_routes
ORDER BY Efficiency_Ratio ASC;
 
-- 3.2 Identify 3 routes with the worst efficiency ratio. 
 
SELECT 
    Route_ID,
    ROUND(Distance_KM / Average_Travel_Time_Min, 3) AS Efficiency_Ratio
FROM flipkart_routes
ORDER BY Efficiency_Ratio ASC
LIMIT 3;

-- 3.3 Find routes with >20% delayed shipments. 
 
SELECT Route_id, count(*) as Total_Shipment,
SUM(CASE WHEN Actual_Delivery_Date > Expected_Delivery_Date THEN 1 ELSE 0 END) AS Delayed_Shipments,
ROUND((SUM(CASE WHEN Actual_Delivery_Date > Expected_Delivery_Date THEN 1 ELSE 0 
END)/ Count(*))* 100,2) as Delay_Shipment_Percentage
FROM flipkart_orders 
GROUP BY Route_id
HAVING Delay_shipment_percentage >20
ORDER BY Delay_shipment_percentage;
 
-- 3.4 Recommend potential routes for optimization.
SELECT Round(Avg(Distance_km/Average_travel_time_min),3) as Avg_Efficiency_ratio FROM flipkart_routes;

SELECT o.Route_ID, r.Start_Location, r.End_Location,
Round(Avg(datediff(Actual_Delivery_Date,Order_date)),2) AS Avg_Delivery_Time_Days,
Round(Avg(r.Traffic_Delay_Min),2) AS Avg_Traffic_Delay_Min,
Round(Avg(Distance_km/Average_travel_time_min),3) as Efficiency_ratio,
Round((Sum(Case When Actual_Delivery_date > Expected_Delivery_date THEN 1 ELSE 0 END)/ Count(*))*100,2)
AS Delay_Percentage FROM flipkart_orders o
JOIN flipkart_routes r 
ON o.route_id = r.route_id
GROUP BY o.route_id, r.Start_Location, r.End_Location
HAVING Efficiency_ratio < 2.6 AND Delay_Percentage >20
ORDER BY Delay_Percentage DESC;
    
-- 4.1 Find the top 3 warehouses with the highest average processing time.
select *from flipkart_warehouses;
select warehouse_id ,warehouse_name,city,Average_Processing_Time_Min from flipkart_warehouses 
order by Average_Processing_Time_Min desc limit 3;

-- 4.2 Calculate total vs. delayed shipments for each warehouse.
SELECT 
    w.warehouse_id,
    w.Warehouse_name,count(*)as total_order,
    sum(case when Actual_Delivery_Date>Expected_Delivery_Date then 1 else 0
    end)as delayed_shipment from flipkart_orders
    as o
    join flipkart_warehouses as w
    on w.Warehouse_ID=o.Warehouse_ID
    group by w.Warehouse_ID,w.Warehouse_Name;
    
        
select *from flipkart_orders;

-- 4.3 Use CTE to find bottleneck warehouses (processing time > global average)

With Global_Avg as
(Select Avg(Average_Processing_Time_min) AS Global_Avg from flipkart_warehouses)
Select w.Warehouse_ID, w.warehouse_name, w.Average_Processing_Time_min, g.Global_Avg
from flipkart_warehouses w
CROSS JOIN global_avg g
where w.Average_Processing_Time_Min > g.Global_Avg;

-- 4.4 Rank warehouses based on on-time delivery percentage
Select Warehouse_id, 
count(*) as Total_Shipment,
SUM(Case When Actual_Delivery_Date <= Expected_Delivery_Date THEN 1 ELSE 0 END) AS OnTime_Shipments,
Round(SUM(Case When Actual_Delivery_Date <= Expected_Delivery_Date THEN 1 ELSE 0 END)/Count(*)*100,2)
As On_Time_Delivery_Percentage,
Rank() Over(Order by Round(SUM(Case When Actual_Delivery_Date <= Expected_Delivery_Date THEN 1 ELSE 0 END)
 /Count(*)* 100,2) DESC)
AS Warehouse_Rank
from flipkart_orders 
GROUP BY Warehouse_ID
ORDER BY On_Time_Delivery_Percentage DESC;

-- 5.1 Rank agents (per route) by on-time delivery percentage

select  Agent_ID,Agent_Name,Route_ID,rank()over(partition by Route_ID order by
 On_Time_Delivery_Percentage desc )as 
route_rank 
 from 
flipkart_deliveryagents 
order by
 route_id, route_rank,agent_name;
 
select*from flipkart_deliveryagents;

 -- 5.2 Find agents with on-time % < 80%.
SELECT 
    agent_name, route_id, On_Time_Delivery_Percentage
FROM
    flipkart_deliveryagents
WHERE
    On_Time_Delivery_Percentage < 80 order by On_Time_Delivery_Percentage desc;
    
-- 5.3  Compare average speed of top 5 vs bottom 5 agents using subqueries

SELECT 
    ROUND(AVG(Avg_Speed_KMPH), 2) AS top_5_avg_speed
FROM
    (SELECT 
        agent_id, agent_name, Avg_Speed_KMPH
    FROM
        flipkart_deliveryagents
    ORDER BY Avg_Speed_KMPH DESC
    LIMIT 5) AS avg_speed;
SELECT 
    ROUND(AVG(Avg_Speed_KMPH), 2) AS bottom_5_avg_speed
FROM
    (SELECT 
        agent_id, agent_name, Avg_Speed_KMPH
    FROM
        flipkart_deliveryagents
    ORDER BY Avg_Speed_KMPH asc
    LIMIT 5) AS avg_speed;

-- 5.4 Suggest training or workload balancing strategies for low performers
-- ● Suggest training or workload balancing strategies for low performers 

/* Example suggestions for your report:

Training Recommendations:

Conduct targeted training for agents with on-time % below 80% — focusing on route planning,
 time management, and real-time navigation tools.

Offer refresher programs on handling traffic delays and prioritizing deliveries.

Workload Balancing Strategies:

Reassign high-delay routes from low-performing agents to top performers temporarily.

Distribute deliveries evenly based on average speed and experience years.

Use data to pair experienced + new agents on difficult routes for learning. */

-- 6.1 For each order, list the last checkpoint and time
    
   Select order_id, checkpoint, checkpoint_time
FROM ( Select order_id, checkpoint, checkpoint_time,
ROW_NUMBER() OVER (PARTITION BY Order_ID ORDER BY Checkpoint_Time DESC) AS RowNumber
from flipkart_shipmenttracking) as Ranked
Where RowNumber =1;

-- 6.2 Find the most common delay reasons (excluding None).

select*from flipkart_shipmenttracking;

SELECT 
    Delay_Reason,
    COUNT(*) AS `reason count`
FROM
    flipkart_shipmenttracking
WHERE
    Delay_Reason != 'none'
GROUP BY Delay_Reason
ORDER BY `reason count` DESC;
 
--  6.3 Identify orders with >2 delayed checkpoints

SELECT 
    order_id, COUNT(Delay_Minutes) AS `delayed checkpoints`
FROM
    flipkart_shipmenttracking
    where Delay_Minutes>0
GROUP BY Order_ID
HAVING COUNT(Delay_Minutes) > 2
ORDER BY `delayed checkpoints` DESC;

-- 7.1 Calculate KPIs using SQL queries

SELECT r.start_location as Region,
ROUND(AVG(DATEDIFF(o.Actual_Delivery_Date, o.Expected_Delivery_Date)), 2) AS Avg_Delivery_Delay_Days
FROM flipkart_orders o
JOIN flipkart_routes r 
ON o.Route_ID = r.Route_ID
GROUP BY r.Start_Location
ORDER BY Avg_Delivery_Delay_Days DESC;

-- 7.2 ON - Time delivery %

SELECT r.start_location as Region, 
Count(*) as Total_Deliveries,
SUM(Case When Actual_Delivery_Date <= Expected_Delivery_Date THEN 1 ELSE 0 END) AS Total_OnTime_Deliveries,
Round(SUM(Case When Actual_Delivery_Date <= Expected_Delivery_Date THEN 1 ELSE 0 END)/Count(*)*100,2)
As On_Time_Delivery_Percentage
From flipkart_orders o
JOIN flipkart_routes r
ON o.Route_ID = r.Route_ID
GROUP BY r.Start_Location
ORDER BY On_Time_Delivery_Percentage DESC;

-- 7.3 Average Traffic Delay per Route.

SELECT 
    Route_ID,
    ROUND(AVG(Traffic_Delay_Min), 2) AS Avg_Traffic_Delay_Min
FROM flipkart_routes
GROUP BY Route_ID
ORDER BY Avg_Traffic_Delay_Min DESC;
------------------------------------------------------------------------------------------