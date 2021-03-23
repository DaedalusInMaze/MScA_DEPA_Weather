# Group 1
# Jiekai Ma, Curtis Zhuang, Karim Itani, Arpit Parihar

# 1. Select top 3 drug-neighborhoods and calculated their robbery and theft crime percentage
# (insights high robbery and theft crime percentage around drug-neighborhoods)

WITH drug_neighbor as 
(select ca.ZIPCODE,
        count(c.CRIME_ID)
 from crime c
 LEFT JOIN chicago_area ca on ca.LOCATION_ID = c.LOCATION_ID
 where PRIMARY_TYPE = 'NARCOTICS'
 group by ca.ZIPCODE
 ORDER BY 2 DESC
 limit 3)
,
top_14_drugs as
(select count(c1.CRIME_ID) around_drug_neighbors_crime, 
        ca1.ZIPCODE, ca1.NEIGHBORHOOD
 from crime c1
 JOIN chicago_area ca1 ON ca1.LOCATION_ID = c1.LOCATION_ID
 INNER JOIN drug_neighbor dn ON abs(dn.ZIPCODE-ca1.ZIPCODE) <= 2
 where dn.ZIPCODE != ca1.ZIPCODE 
 AND (c1.PRIMARY_TYPE = 'THEFT' or c1.PRIMARY_TYPE = 'ROBBERY')
 Group by ca1.ZIPCODE,ca1.NEIGHBORHOOD
 Order By 1 DESC)

SELECT t.around_drug_neighbors_crime robbery_theft_number,
       t.ZIPCODE, count(c.CRIME_ID) crime_num, 
	   round(t.around_drug_neighbors_crime/count(c.CRIME_ID)*100,2) robbery_theft_percentage, 
       t.NEIGHBORHOOD
from crime c
JOIN chicago_area ca ON ca.LOCATION_ID = c.LOCATION_ID 
JOIN top_14_drugs t ON t.ZIPCODE = ca.ZIPCODE
GROUP BY t.around_drug_neighbors_crime, t.ZIPCODE,t.NEIGHBORHOOD
ORDER BY 4 DESC;

# 2. select top 10 crime/violations/complaints neighbors in chicago

SELECT distinct c.ZIPCODE location, count(crime.CRIME_ID) crime_num, 
round((count(crime.CRIME_ID) / 
(select count(*) from crime RIGHT JOIN chicago_area ca ON ca.LOCATION_ID = crime.LOCATION_ID
 ))* 100,2) crime_percentage
from crime
lEFT JOIN chicago_area c ON c.LOCATION_ID = crime.LOCATION_ID
GROUP BY c.ZIPCODE
ORDER BY 2 DESC
LIMIT 10;

select distinct c.ZIPCODE location, count(co.COMPLAINT_ID) complaint_num,c.NEIGHBORHOOD,
round((count(co.COMPLAINT_ID) / 
(select count(*) from complaints RIGHT JOIN chicago_area ca ON ca.LOCATION_ID = complaints.LOCATION_ID
 ))* 100,2) complaints_percentage
from complaints co
lEFT JOIN chicago_area c ON c.LOCATION_ID = co.LOCATION_ID
GROUP BY c.ZIPCODE
ORDER BY 2 DESC
LIMIT 10;

select distinct c.ZIPCODE location, count(v.VIOLATION_ID),c.NEIGHBORHOOD,
round((count(v.VIOLATION_ID) / 
(select count(*) from violations RIGHT JOIN chicago_area ca ON ca.LOCATION_ID = violations.LOCATION_ID
 ))* 100,2) violations_percentage
from violations v
lEFT JOIN chicago_area c ON c.LOCATION_ID = v.LOCATION_ID
GROUP BY c.ZIPCODE
ORDER BY 2 DESC
LIMIT 10;



# 3. View count of crimes, violations and crime for each zipcode, study weather type and crime type relationship 


USE depa_group_1;

SET sql_mode=(SELECT REPLACE(@@sql_mode,'ONLY_FULL_GROUP_BY',''));

# Get count of crimes, complaints and violations for each location 
SELECT
	t1.ZIPCODE, number_complaint, number_violation, number_crime
FROM
	(SELECT
		ZIPCODE, count(COMPLAINT_ID) number_complaint
	FROM 
		location lo
			LEFT JOIN
		complaints co ON lo.LOCATION_ID = co.LOCATION_ID
	GROUP BY
		ZIPCODE) AS t1 
		LEFT JOIN
	(SELECT
		ZIPCODE, count(VIOLATION_ID) number_violation
	FROM 
		location lo
			LEFT JOIN
		violations vi ON lo.LOCATION_ID = vi.LOCATION_ID
	GROUP BY
		ZIPCODE) AS t2 ON t1.ZIPCODE = t2.ZIPCODE
		LEFT JOIN
	(SELECT
		ZIPCODE, count(CRIME_ID) number_crime
	FROM 
		location lo
			LEFT JOIN
		crime cr ON lo.LOCATION_ID = cr.LOCATION_ID
	GROUP BY
		ZIPCODE) AS t3 ON t2.ZIPCODE = t3.ZIPCODE
	ORDER BY
		number_crime DESC, number_violation DESC, number_complaint DESC;
    
    
# see if there is correlation between weather type and crime type
SELECT * FROM weather;

SELECT
	DATE, ca.LOCATION_ID, (WT_THUNDER)
FROM
	weather AS w
		INNER JOIN
	chicago_area AS ca ON w.LOCATION_ID = ca.LOCATION_ID
GROUP BY
	DATE, LOCATION_ID
HAVING
	WT_THUNDER IS NOT NULL;
    
# Study the relationship between temperature, crime type and the occurences of crime
SELECT
	 avgtmp, PRIMARY_TYPE, COUNT(PRIMARY_TYPE) crimes_count
FROM
	crime c 
		LEFT JOIN
	(SELECT 
		avg(TEMP_AVG) avgtmp, DATE
	FROM 
		weather
	WHERE
		TEMP_AVG IS NOT NULL
	GROUP BY
		DATE) t1 ON DATE(c.CRIME_DATE) = t1.DATE
GROUP BY
	DATE, PRIMARY_TYPE
ORDER BY
	crimes_count DESC;
    

# 4. Crime as percent of total yearly crime goes down with temperature, while arrest made as a percent of crime goes up
SELECT T1.YEAR,
	   T1.MONTH,
       ROUND(AVG_TEMP, 2) AS AVG_TEMP_FAHRENHEIT,
       ROUND(100 * PERCENT_CRIME, 2) AS PERCENT_CRIME_YEAR,
       ROUND(100 * ARREST_PERCENT_YEAR, 2) AS ARREST_PERCENT_YEAR,
       ROUND(100 * ARREST_PERCENT, 2) AS ARREST_PERCENT
FROM 
(
	SELECT YEAR,
		   MONTH,
		   COUNT(*)/AVG(PERCENT_CRIME_YEAR) AS PERCENT_CRIME,
		   SUM(CASE WHEN ARREST = 'TRUE' THEN 1 ELSE 0 END)/AVG(PERCENT_ARREST_YEAR) AS ARREST_PERCENT_YEAR,
		   SUM(CASE WHEN ARREST = 'TRUE' THEN 1 ELSE 0 END)/COUNT(*) AS ARREST_PERCENT
	FROM
(
		SELECT YEAR(CRIME_DATE) AS YEAR,
			   MONTHNAME(CRIME_DATE) AS MONTH,
               CRIME_DATE,
			   COUNT(*) OVER(PARTITION BY YEAR(CRIME_DATE)) AS PERCENT_CRIME_YEAR,
			   ARREST,
			   SUM(CASE WHEN ARREST = 'TRUE' THEN 1 ELSE 0 END) OVER(PARTITION BY YEAR(CRIME_DATE)) AS PERCENT_ARREST_YEAR
		FROM crime
        -- WHERE DESCRIPTION LIKE '%DOMESTIC%'
) AS A
	GROUP BY YEAR,
			 MONTH,
             MONTH(CRIME_DATE)
	ORDER BY YEAR,
             MONTH(CRIME_DATE)
) AS T1 LEFT JOIN
(
	SELECT YEAR(DATE) AS YEAR,
		   MONTHNAME(DATE) AS MONTH,
		   AVG(TEMP_AVG) AS AVG_TEMP,
		   AVG(AVG_WIND) AS AVG_WIND
	FROM weather
	GROUP BY YEAR(DATE),
			 MONTHNAME(DATE)
) AS T2 
	ON T1.YEAR = T2.YEAR AND
       T1.MONTH = T2.MONTH;

# 4.1 Jan vs Feb deep dive
SELECT YEAR(DATE) AS YEAR,
	   MONTHNAME(DATE) AS MONTH,
	   ROUND(AVG(TEMP_AVG), 2) AS AVG_TEMP,
	   ROUND(AVG(AVG_WIND), 2) AS AVG_WIND,
       ROUND(AVG(PRECIPITATION), 2) AS PRECIPITATION,
       ROUND(AVG(SNOWFALL), 2) AS SNOWFALL
FROM weather
WHERE MONTH(DATE) IN (1, 2)
GROUP BY YEAR(DATE),
		 MONTH(DATE),
         MONTHNAME(DATE)
ORDER BY YEAR,
		 MONTH(DATE);


# Violations as percent of total yearly violations go down with temperature, and resolution time improves
SELECT T1.YEAR,
	   T1.MONTH,
       ROUND(AVG_TEMP, 2) AS AVG_TEMP_FAHRENHEIT,
       ROUND(100 * PERCENT_VIOLATIONS, 2) AS PERCENT_VIOLATIONS_YEAR,
       ROUND(RESOLUTION_TIME) AS AVG_RESOLUTION_TIME,
       IMPOSED_FINE,
       ADMIN_COSTS
FROM 
(
	SELECT YEAR,
		   MONTH,
		   COUNT(*)/AVG(PERCENT_VIOLATIONS_YEAR) AS PERCENT_VIOLATIONS,
           AVG(RESOLUTION_TIME) AS RESOLUTION_TIME,
           SUM(IMPOSED_FINE) AS IMPOSED_FINE,
		   SUM(ADMIN_COSTS) AS ADMIN_COSTS
	FROM
(
		SELECT YEAR(VIOLATION_DATE) AS YEAR,
			   MONTHNAME(VIOLATION_DATE) AS MONTH,
               VIOLATION_DATE,
			   COUNT(*) OVER(PARTITION BY YEAR(VIOLATION_DATE)) AS PERCENT_VIOLATIONS_YEAR,
               DATEDIFF(IF(LAST_MODIFIED_DATE IS NULL, HEARING_DATE, LAST_MODIFIED_DATE), VIOLATION_DATE) AS RESOLUTION_TIME,
               IMPOSED_FINE,
               ADMIN_COSTS
		FROM violations
        -- WHERE DESCRIPTION LIKE '%DOMESTIC%'
) AS A
	GROUP BY YEAR,
			 MONTH,
             MONTH(VIOLATION_DATE)
	ORDER BY YEAR,
             MONTH(VIOLATION_DATE)
) AS T1 INNER JOIN
(
	SELECT YEAR(DATE) AS YEAR,
		   MONTHNAME(DATE) AS MONTH,
		   AVG(TEMP_AVG) AS AVG_TEMP,
		   AVG(AVG_WIND) AS AVG_WIND
	FROM weather
	GROUP BY YEAR(DATE),
			 MONTHNAME(DATE)
) AS T2 
	ON T1.YEAR = T2.YEAR AND
       T1.MONTH = T2.MONTH;


# Tableau Queries

CREATE VIEW CRIME_TABLEAU AS
SELECT STR_TO_DATE(CONCAT(YEAR(CRIME_DATE), "-", MONTH(CRIME_DATE), "-01"), "%Y-%m-%d") AS CRIME_DATE,
       PRIMARY_TYPE,
	   ZIPCODE,
       COUNT(*) AS CRIME_CASES,
       SUM(IF(ARREST = 'TRUE', 1, 0)) AS NUM_ARRESTS
FROM crime AS C INNER JOIN
	 location AS L
		ON C.LOCATION_ID = L.LOCATION_ID
GROUP BY STR_TO_DATE(CONCAT(YEAR(CRIME_DATE), "-", MONTH(CRIME_DATE), "-01"), "%Y-%m-%d"),
         PRIMARY_TYPE,
         ZIPCODE;

CREATE VIEW WEATHER_TABLEAU AS
SELECT STR_TO_DATE(CONCAT(YEAR(DATE), "-", MONTH(DATE), "-01"), "%Y-%m-%d") AS WEATHER_DATE,
       ROUND(AVG(TEMP_AVG), 2) AS TEMP_AVG,
       ROUND(MAX(TEMP_MAX), 2) AS TEMP_MAX,
       ROUND(MIN(TEMP_MIN), 2) AS TEMP_MIN,
       ROUND(AVG(PRECIPITATION), 2) AS PRECIP_AVG,
       ROUND(SUM(PRECIPITATION), 2) AS PRECIP_SUM,
       ROUND(AVG(SNOWFALL), 2) AS SNOW_AVG,
       ROUND(SUM(SNOWFALL), 2) AS SNOW_SUM
FROM weather
GROUP BY STR_TO_DATE(CONCAT(YEAR(DATE), "-", MONTH(DATE), "-01"), "%Y-%m-%d");

CREATE VIEW VIOLATIONS_TABLEAU AS
SELECT STR_TO_DATE(CONCAT(YEAR(VIOLATION_DATE), "-", MONTH(VIOLATION_DATE), "-01"), "%Y-%m-%d") AS VIOLATION_DATE,
       ZIPCODE,
       COUNT(*) AS NUM_VIOLATIONS,
       SUM(IMPOSED_FINE) AS TOTAL_FINES,
       SUM(ADMIN_COSTS) AS ADMIN_COSTS,
       ROUND(AVG(DATEDIFF(IF(LAST_MODIFIED_DATE IS NULL, HEARING_DATE, LAST_MODIFIED_DATE), VIOLATION_DATE)), 2) AS AVG_RESOLUTION_TIME_VI
FROM violations AS V INNER JOIN
	 location AS L
		ON V.LOCATION_ID = L.LOCATION_ID
GROUP BY STR_TO_DATE(CONCAT(YEAR(VIOLATION_DATE), "-", MONTH(VIOLATION_DATE), "-01"), "%Y-%m-%d"),
         ZIPCODE;

CREATE VIEW COMPLAINTS_TABLEAU AS
SELECT STR_TO_DATE(CONCAT(YEAR(COMPLAINT_DATE), "-", MONTH(COMPLAINT_DATE), "-01"), "%Y-%m-%d") AS COMPLAINT_DATE,
       COMPLAINT_TYPE,
       ZIPCODE,
       COUNT(*) AS NUM_COMPLAINTS,
       ROUND(AVG(DATEDIFF(MODIFIED_DATE, COMPLAINT_DATE)), 2) AS AVG_RESOLUTION_TIME_COMP
FROM complaints AS C INNER JOIN
	 location AS L
		ON C.LOCATION_ID = L.LOCATION_ID
GROUP BY STR_TO_DATE(CONCAT(YEAR(COMPLAINT_DATE), "-", MONTH(COMPLAINT_DATE), "-01"), "%Y-%m-%d"),
		 COMPLAINT_TYPE,
		 ZIPCODE;

CREATE VIEW LOCATION_TABLEAU AS
SELECT DISTINCT ZIPCODE,
	   NEIGHBORHOOD
FROM location;    



# Some queries not adopted in the end    
# see if there is correlation between weather type and crime type
SELECT * FROM weather;

SELECT
	DATE, ca.LOCATION_ID, (WT_THUNDER)
FROM
	weather AS w
		INNER JOIN
	chicago_area AS ca ON w.LOCATION_ID = ca.LOCATION_ID
GROUP BY
	DATE, LOCATION_ID
HAVING
	WT_THUNDER IS NOT NULL;
    
# Study the relationship between temperature, crime type and the occurences of crime
SELECT
	 avgtmp, PRIMARY_TYPE, COUNT(PRIMARY_TYPE) crimes_count
FROM
	crime c 
		LEFT JOIN
	(SELECT 
		avg(TEMP_AVG) avgtmp, DATE
	FROM 
		weather
	WHERE
		TEMP_AVG IS NOT NULL
	GROUP BY
		DATE) t1 ON DATE(c.CRIME_DATE) = t1.DATE
GROUP BY
	DATE, PRIMARY_TYPE
ORDER BY
	crimes_count DESC;


# differences in dates grouped by complaint_type
SELECT 
COMPLAINT_TYPE, 
AVG(ABS(DATEDIFF(COMPLAINT_DATE,MODIFIED_DATE))) 
FROM 
COMPLAINTS 
GROUP BY 
COMPLAINT_TYPE 
ORDER BY 
2 DESC;

# number of violations in each street type
SELECT 
STREET_TYPE,
COUNT(STREET_TYPE) 
FROM 
VIOLATIONS1
GROUP BY 
STREET_TYPE 
ORDER BY 
2 DESC;


# number of crimes in each location description
SELECT 
LOCATION_DESCRIPTION,
COUNT(LOCATION_DESCRIPTION)
FROM 
CRIME 
GROUP BY 
LOCATION_DESCRIPTION 
ORDER BY 
2 DESC;
