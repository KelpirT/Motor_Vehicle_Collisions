/*

Cleaning Data and Exploration Data

*/

--------------------------------------------------------------------------------------------------------------------------
-- Load data from file
LOAD DATA INFILE 'Motor_Vehicle_Collisions_-_Crashes.csv'
INTO TABLE motor_vehicle_collisions_staging
FIELDS TERMINATED BY ','
ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS;

-- Create a new table Staging for work

CREATE TABLE motor_vehicle_collisions_staging AS
SELECT *
FROM motor_vehicle_collisions;

/*

Cleaning Data in SQL Queries

*/

--------------------------------------------------------------------------------------------------------------------------

-- Standardize Date Format

UPDATE motor_vehicle_collisions_staging
SET CRASH_DATE = STR_TO_DATE(CRASH_DATE, '%m/%d/%Y');
ALTER TABLE motor_vehicle_collisions_staging
MODIFY COLUMN CRASH_DATE DATE;

-- Check where is have same LOCATION but not have BOROUGH and ZIP_CODE
SELECT a.COLLISION_ID,a.BOROUGH,a.ZIP_CODE, a.LOCATION, b.COLLISION_ID,b.BOROUGH,b.ZIP_CODE, b.LOCATION, COALESCE(b.BOROUGH,a.BOROUGH), ifnull(a.ZIP_CODE,b.ZIP_CODE)
FROM motor_vehicle_collisions_staging a
JOIN motor_vehicle_collisions_staging b
	ON a.LONGITUDE = b.LONGITUDE
    AND a.LATITUDE = b.LATITUDE
    AND a.COLLISION_ID <> b.COLLISION_ID
WHERE a.LATITUDE IS NOT NULL AND b.LATITUDE IS NOT NULL AND a.LONGITUDE <> 0 AND b.LONGITUDE <> 0;

-- Create a table of location
CREATE TABLE location_borough_zip (
    LOCATION VARCHAR(255),
    BOROUGH VARCHAR(255),
    ZIP_CODE VARCHAR(10)
)
SELECT DISTINCT LOCATION, BOROUGH, ZIP_CODE
FROM motor_vehicle_collisions_staging
WHERE LATITUDE <> 0 and LONGITUDE <> 0 and BOROUGH <>'' and ZIP_CODE <>'' and LOCATION <> '' ;

-- Fill blank BOROUGH and ZIP_CODE with same LOCATION
UPDATE motor_vehicle_collisions_staging a
JOIN location_borough_zip b ON a.LOCATION = b.LOCATION
SET a.BOROUGH = b.BOROUGH,
    a.ZIP_CODE = b.ZIP_CODE;

/*

Exploration Data

*/

--------------------------------------------------------------------------------------------------------------------------
-- Borough and Total collisions 
SELECT BOROUGH, COUNT(*) AS Total_Collisions
FROM motor_vehicle_collisions_staging
GROUP BY BOROUGH
ORDER BY Total_Collisions DESC;

select *
from motor_vehicle_collisions_staging;

-- Time and session of collision
SELECT
    COLLISION_ID,
    CRASH_DATE,
    CAST(CRASH_TIME AS TIME) AS CRASH_TIME,
    YEAR(CRASH_DATE) AS YEAR,
    MONTH(CRASH_DATE) AS MONTH,
    DAY(CRASH_DATE) AS DAY,
    CASE
		WHEN  HOUR(CAST(CRASH_TIME AS TIME)) >= 5 and HOUR(CAST(CRASH_TIME AS TIME)) < 9 THEN 'Early morning'
		WHEN  HOUR(CAST(CRASH_TIME AS TIME)) >= 9 and HOUR(CAST(CRASH_TIME AS TIME)) < 12 THEN 'Morning'
        WHEN  HOUR(CAST(CRASH_TIME AS TIME)) >= 12 and HOUR(CAST(CRASH_TIME AS TIME)) < 16 THEN 'Noon'
        WHEN  HOUR(CAST(CRASH_TIME AS TIME)) >= 16 and HOUR(CAST(CRASH_TIME AS TIME)) < 20 THEN 'Afternoon'
        WHEN  HOUR(CAST(CRASH_TIME AS TIME)) >= 20 and HOUR(CAST(CRASH_TIME AS TIME)) <= 23 THEN 'Night'
        WHEN  HOUR(CAST(CRASH_TIME AS TIME)) >= 0 and HOUR(CAST(CRASH_TIME AS TIME)) < 5 THEN 'Late night'
	   -- ELSE  HOUR(CAST(CRASH_TIME AS TIME))
	   END AS SESSION_IN_DAY,
    DATE_FORMAT(CRASH_DATE, '%W') AS DAY_OF_WEEK
FROM
    motor_vehicle_collisions_staging;
    
-- Number of collisions during the session

WITH collisions_session AS (
SELECT
    COLLISION_ID,
    CRASH_DATE,
    CAST(CRASH_TIME AS TIME) AS CRASH_TIME,
    YEAR(CRASH_DATE) AS YEAR,
    MONTH(CRASH_DATE) AS MONTH,
    DAY(CRASH_DATE) AS DAY,
    HOUR(CAST(CRASH_TIME AS TIME)) AS HOUR
    ,
    CASE
		WHEN  HOUR(CAST(CRASH_TIME AS TIME)) >= 5 and HOUR(CAST(CRASH_TIME AS TIME)) < 9 THEN 'Early morning'
		WHEN  HOUR(CAST(CRASH_TIME AS TIME)) >= 9 and HOUR(CAST(CRASH_TIME AS TIME)) < 12 THEN 'Morning'
        WHEN  HOUR(CAST(CRASH_TIME AS TIME)) >= 12 and HOUR(CAST(CRASH_TIME AS TIME)) < 16 THEN 'Noon'
        WHEN  HOUR(CAST(CRASH_TIME AS TIME)) >= 16 and HOUR(CAST(CRASH_TIME AS TIME)) < 20 THEN 'Afternoon'
        WHEN  HOUR(CAST(CRASH_TIME AS TIME)) >= 20 and HOUR(CAST(CRASH_TIME AS TIME)) <= 23 THEN 'Night'
        WHEN  HOUR(CAST(CRASH_TIME AS TIME)) >= 0 and HOUR(CAST(CRASH_TIME AS TIME)) < 5 THEN 'Late night'
	   -- ELSE  HOUR(CAST(CRASH_TIME AS TIME))
	   END AS SESSION_IN_DAY,
    DATE_FORMAT(CRASH_DATE, '%W') AS DAY_OF_WEEK
FROM
    motor_vehicle_collisions_staging
)
SELECT SESSION_IN_DAY, COUNT(SESSION_IN_DAY) AS TOTAL_COLLISION
FROM collisions_session
GROUP BY SESSION_IN_DAY
ORDER BY TOTAL_COLLISION;
-- Number of vehicle types causing accidents
SELECT 
    SUM(CASE WHEN VEHICLE_TYPE_CODE_1 <> '' THEN 1 ELSE 0 END) AS TYPE_1,
    SUM(CASE WHEN VEHICLE_TYPE_CODE_2 <> '' THEN 1 ELSE 0 END) AS TYPE_2,
    SUM(CASE WHEN VEHICLE_TYPE_CODE_3 <> '' THEN 1 ELSE 0 END) AS TYPE_3,
    SUM(CASE WHEN VEHICLE_TYPE_CODE_4 <> '' THEN 1 ELSE 0 END) AS TYPE_4,
    SUM(CASE WHEN VEHICLE_TYPE_CODE_5 <> '' THEN 1 ELSE 0 END) AS TYPE_5
FROM motor_vehicle_collisions_staging;

-- Number of vehicles causing accidents in one incident
SELECT 
    SUM(CASE WHEN  CONTRIBUTING_FACTOR_VEHICLE_1 <> '' AND CONTRIBUTING_FACTOR_VEHICLE_2 = '' THEN 1 ELSE 0 END) AS ONE_VEHICLE,
    SUM(CASE WHEN  CONTRIBUTING_FACTOR_VEHICLE_1 <> '' AND CONTRIBUTING_FACTOR_VEHICLE_2 <> '' AND CONTRIBUTING_FACTOR_VEHICLE_3 = '' THEN 1 ELSE 0 END) AS TWO_VEHICLE,
    SUM(CASE WHEN  CONTRIBUTING_FACTOR_VEHICLE_1 <> '' AND CONTRIBUTING_FACTOR_VEHICLE_2 <> '' AND CONTRIBUTING_FACTOR_VEHICLE_3 <> '' AND CONTRIBUTING_FACTOR_VEHICLE_4 = '' THEN 1 ELSE 0 END) AS THREE_VEHICLE,
    SUM(CASE WHEN  CONTRIBUTING_FACTOR_VEHICLE_1 <> '' AND CONTRIBUTING_FACTOR_VEHICLE_2 <> '' AND CONTRIBUTING_FACTOR_VEHICLE_3 <> '' AND CONTRIBUTING_FACTOR_VEHICLE_4 <> ''  
    AND CONTRIBUTING_FACTOR_VEHICLE_5 = '' THEN 1 ELSE 0 END) AS FOUR_VEHICLE,
    SUM(CASE WHEN  CONTRIBUTING_FACTOR_VEHICLE_1 <> '' AND CONTRIBUTING_FACTOR_VEHICLE_2 <> '' AND CONTRIBUTING_FACTOR_VEHICLE_3 <> '' AND CONTRIBUTING_FACTOR_VEHICLE_4 <> ''  
    AND CONTRIBUTING_FACTOR_VEHICLE_5 <> ''  THEN 1 ELSE 0 END) AS FIVE_VEHICLE
FROM motor_vehicle_collisions_staging;
-- The number of accidents is allocated to each factor
SELECT
    CONTRIBUTING_FACTOR_VEHICLE_1 AS CONTRIBUTING_FACTOR,
    COUNT(CASE WHEN CONTRIBUTING_FACTOR_VEHICLE_1 <> '' THEN COLLISION_ID END) AS COUNT_FACTOR_1,
    CONTRIBUTING_FACTOR_VEHICLE_2 AS CONTRIBUTING_FACTOR,
    COUNT(CASE WHEN CONTRIBUTING_FACTOR_VEHICLE_2 <> '' THEN COLLISION_ID END) AS COUNT_FACTOR_2,
    CONTRIBUTING_FACTOR_VEHICLE_3 AS CONTRIBUTING_FACTOR,
    COUNT(CASE WHEN CONTRIBUTING_FACTOR_VEHICLE_3 <> '' THEN COLLISION_ID END) AS COUNT_FACTOR_3,
    CONTRIBUTING_FACTOR_VEHICLE_4 AS CONTRIBUTING_FACTOR,
    COUNT(CASE WHEN CONTRIBUTING_FACTOR_VEHICLE_4 <> ''THEN COLLISION_ID END) AS COUNT_FACTOR_4,
    CONTRIBUTING_FACTOR_VEHICLE_5 AS CONTRIBUTING_FACTOR,
    COUNT(CASE WHEN CONTRIBUTING_FACTOR_VEHICLE_5 <> '' THEN COLLISION_ID END) AS COUNT_FACTOR_5
FROM motor_vehicle_collisions
GROUP BY
    CONTRIBUTING_FACTOR_VEHICLE_1,
    CONTRIBUTING_FACTOR_VEHICLE_2,
    CONTRIBUTING_FACTOR_VEHICLE_3,
    CONTRIBUTING_FACTOR_VEHICLE_4,
    CONTRIBUTING_FACTOR_VEHICLE_5;
    
SELECT
    SUM(NUMBER_OF_PERSONS_INJURED) AS TOTAL_PERSONS_INJURED,
    SUM(NUMBER_OF_PERSONS_KILLED) AS TOTAL_PERSONS_KILLED,
    SUM(NUMBER_OF_PEDESTRIANS_INJURED) AS TOTAL_PEDESTRIANS_INJURED,
    SUM(NUMBER_OF_PEDESTRIANS_KILLED) AS TOTAL_PEDESTRIANS_KILLED,
    SUM(NUMBER_OF_CYCLIST_INJURED) AS TOTAL_CYCLIST_INJURED,
    SUM(NUMBER_OF_CYCLIST_KILLED) AS TOTAL_CYCLIST_KILLED,
    SUM(NUMBER_OF_MOTORIST_INJURED) AS TOTAL_MOTORIST_INJURED,
    SUM(NUMBER_OF_MOTORIST_KILLED) AS TOTAL_MOTORIST_KILLED
FROM motor_vehicle_collisions;

-- SELECT COUNT()









