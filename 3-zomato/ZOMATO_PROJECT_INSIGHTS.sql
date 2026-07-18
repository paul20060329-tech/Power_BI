-- ------------ ZOMATO RESTAURANT ANALYSIS ------------- ----------
/* TABLES USED */
SELECT * FROM MAIN; -- RESTAURANT DATA TABLE
SELECT * FROM COUNTRY; -- COUNTRY TABLE
SELECT * FROM CURRENCY; -- CURRENCY TABLE
SELECT * FROM CALENDAR; -- CALENDAR TABLE

-- --------- KEY KPI'S ----------------------------------------------------

SELECT COUNT(DISTINCT(RestaurantID)) TOTAL_RESTAURANTS FROM main;
SELECT COUNT(DISTINCT(CITY)) TOTAL_CITIES FROM main;
SELECT COUNT(DISTINCT(COUNTRYNAME)) TOTAL_COUNTRY FROM COUNTRY;
SELECT COUNT(DISTINCT(Cuisines)) TOTAL_CUISINES FROM main;
SELECT ROUND(AVG(rating),2) OVERALL_AVG_RATING FROM main; 

-- 2 --------------------------------------------------------------------------------------------
/* CALENDAR TABLE */

CREATE TABLE calendar AS
SELECT 
  STR_TO_DATE(CONCAT(`Year Opening`, '-', `Month Opening`, '-', `Day Opening`), '%Y-%m-%d') AS Datekey_Opening,
  YEAR(STR_TO_DATE(CONCAT(`Year Opening`, '-', `Month Opening`, '-', `Day Opening`), '%Y-%m-%d')) AS Year,
  MONTH(STR_TO_DATE(CONCAT(`Year Opening`, '-', `Month Opening`, '-', `Day Opening`), '%Y-%m-%d')) AS MonthNo,
  MONTHNAME(STR_TO_DATE(CONCAT(`Year Opening`, '-', `Month Opening`, '-', `Day Opening`), '%Y-%m-%d')) AS MonthFullName,
  CONCAT('Q', QUARTER(STR_TO_DATE(CONCAT(`Year Opening`, '-', `Month Opening`, '-', `Day Opening`), '%Y-%m-%d'))) AS Quarter,
  DATE_FORMAT(STR_TO_DATE(CONCAT(`Year Opening`, '-', `Month Opening`, '-', `Day Opening`), '%Y-%m-%d'), '%Y-%b') AS YearMonth,
  DAYOFWEEK(STR_TO_DATE(CONCAT(`Year Opening`, '-', `Month Opening`, '-', `Day Opening`), '%Y-%m-%d')) AS WeekdayNo,
  DAYNAME(STR_TO_DATE(CONCAT(`Year Opening`, '-', `Month Opening`, '-', `Day Opening`), '%Y-%m-%d')) AS WeekdayName,  
  -- Financial Month (April=1 ... March=12)
  CASE 
    WHEN MONTH(STR_TO_DATE(CONCAT(`Year Opening`, '-', `Month Opening`, '-', `Day Opening`), '%Y-%m-%d')) >= 4 
         THEN MONTH(STR_TO_DATE(CONCAT(`Year Opening`, '-', `Month Opening`, '-', `Day Opening`), '%Y-%m-%d')) - 3
    ELSE MONTH(STR_TO_DATE(CONCAT(`Year Opening`, '-', `Month Opening`, '-', `Day Opening`), '%Y-%m-%d')) + 9
  END AS FinancialMonth,

  -- Financial Quarter
  CONCAT('FQ', 
    CASE 
      WHEN MONTH(STR_TO_DATE(CONCAT(`Year Opening`, '-', `Month Opening`, '-', `Day Opening`), '%Y-%m-%d')) BETWEEN 4 AND 6 THEN 1
      WHEN MONTH(STR_TO_DATE(CONCAT(`Year Opening`, '-', `Month Opening`, '-', `Day Opening`), '%Y-%m-%d')) BETWEEN 7 AND 9 THEN 2
      WHEN MONTH(STR_TO_DATE(CONCAT(`Year Opening`, '-', `Month Opening`, '-', `Day Opening`), '%Y-%m-%d')) BETWEEN 10 AND 12 THEN 3
      ELSE 4
    END
  ) AS FinancialQuarter
FROM main;

-- 3 -------------------------------------------------------------------------------------
-- Converting the Average cost for 2 column into USD dollars 
UPDATE main m left JOIN currency cr on m.Currency=cr.Currency 
SET m.avg_cost_USD = m.Average_Cost_for_two*cr.USD_rate;

-- 4 ----------------------------------------------------------------------------------------
-- Number of restaurants based on city 
SELECT city,COUNT(RestaurantID) rest_count FROM main GROUP BY city ORDER BY rest_count DESC;

-- Number of restaurants based on country
SELECT cn.Countryname,COUNT(RestaurantID) rest_count
FROM main m JOIN country cn ON m.CountryCode=cn.CountryID
GROUP BY cn.Countryname ORDER BY rest_count DESC;

-- 5 ------------------------------------------------------------------------------------------
-- Numbers of Resturants opening based on Year , Quarter , Month
SELECT cal.Year,cal.Quarter,cal.MonthFullName AS month_name,COUNT(*) AS number_of_restaurants
FROM main m
JOIN calendar cal
    ON cal.Datekey_Opening = m.Datekey
GROUP BY cal.Year, cal.Quarter, cal.MonthFullName
ORDER BY cal.Year, cal.Quarter;

-- 6 ------------------------------------------------------------------------------------------------
-- Count of Resturants based on Average Ratings
SELECT Rating AS average_rating, COUNT(*) AS restaurant_count
FROM main
GROUP BY Rating
ORDER BY average_rating DESC;

-- 7 ----------------------------------------------------------------------------------------------------
-- Creating buckets based on Average Price of reasonable size and restaurants count falls in each buckets
SELECT 
    CASE
      WHEN Average_Cost_for_two < 500 THEN '(<500) : Low'
      WHEN Average_Cost_for_two BETWEEN 500 AND 2000 THEN '(500-2000) : Medium'
      WHEN Average_Cost_for_two BETWEEN 2001 AND 5000 THEN '(2001-5000) : High'
      ELSE '(>5000) : Luxury'
	END AS PRICE_BUCKETT,
    COUNT(*) AS Restaurant_Count
FROM main
Group By PRICE_BUCKETT;

-- 8 ---------------------------------------------------------------------------------------
-- Percentage of Resturants based on "Has_Table_booking"
SELECT 
    Has_Table_booking,
    COUNT(*) AS table_book_rest_count,
    ROUND((COUNT(*) * 100.0 / (SELECT COUNT(*) FROM main)), 2) AS percentage
FROM main
GROUP BY Has_Table_booking;

-- 9 ----------------------------------------------------------------------------------------
-- Percentage of Resturants based on "Has_Online_delivery"
SELECT 
    Has_Online_delivery,
    COUNT(*) AS online_del_rest_count,
    ROUND((COUNT(*) * 100.0 / (SELECT COUNT(*) FROM main)), 2) AS percentage
FROM main
GROUP BY Has_Online_delivery;

-- ------------------ADDITIONAL INSIGHTS--------------------------------------

/*Insights based on Cuisines, City, Ratings */
-- ----------------CUISISNES ------------------------------------------------------
-- Top Cuisine available in most of the restaurants
select Cuisines Top_cuisine,count(RestaurantID) restaurant_count 
from main group by cuisines limit 1;


-- Top rated cuisine
SELECT Countryname, Cuisines, AvgRating
FROM (
    SELECT 
        cn.Countryname,
        m.Cuisines,
        ROUND(AVG(m.Rating),2) AS AvgRating,
        RANK() OVER (PARTITION BY cn.Countryname ORDER BY AVG(m.Rating) DESC) AS rnk
    FROM main m
    JOIN country cn ON m.CountryCode = cn.CountryID
    GROUP BY cn.Countryname, m.Cuisines
    ORDER BY AvgRating desc
) t
WHERE rnk = 1;

-- -------------------------------CITY -----------------------------------------------
 -- Top/Bottom 5 Cities based on average rating
 -- TOP ------------------
SELECT city 'Top-5 Cities',
       ROUND(AVG(rating),2) AS avg_rating,
       COUNT(*) AS restaurant_count
FROM main
GROUP BY city
HAVING COUNT(*) >= 10
ORDER BY avg_rating DESC
LIMIT 5;
-- BOTTOM ------------------------------
SELECT city 'Bottom-5 cities',
       ROUND(AVG(rating),2) AS avg_rating,
       COUNT(*) AS restaurant_count
FROM main
GROUP BY city
HAVING COUNT(*) >= 10
ORDER BY avg_rating ASC
LIMIT 5;

-- most expensive city per country
SELECT Countryname, City, AvgCost
FROM (
    SELECT cn.Countryname,m.City,ROUND(AVG(m.Average_Cost_for_two),2) AS AvgCost,
        RANK() OVER (PARTITION BY cn.Countryname ORDER BY AVG(m.Average_Cost_for_two) DESC) AS rnk
    FROM main m
    JOIN country cn ON m.CountryCode = cn.CountryID
    GROUP BY cn.Countryname, m.City
    ORDER BY AvgCost desc
) t
WHERE rnk = 1;



-- -------COUNTRY--------------------------------------------------------------------------
-- Top country with MAX number of restaurants 
Select  cn.countryname,count(m.RestaurantID) restaurant_count  
from main m left join country cn on m.CountryCode=cn.countryid 
group by cn.countryname order by restaurant_count desc limit 1;


-- Country with LEAST number of restaurants
Select  cn.countryname,count(m.RestaurantID) restaurant_count  
from main m left join country cn on m.CountryCode=cn.countryid 
group by cn.countryname order by restaurant_count asc limit 1;