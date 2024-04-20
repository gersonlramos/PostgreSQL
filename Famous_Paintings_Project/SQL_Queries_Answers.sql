-- 1: Fetch all the paintings that are not displayed in any museum.
SELECT * FROM work
WHERE museum_id is NULL;

-- 2: Are there museums without any paintings?
SELECT * FROM museum m
WHERE NOT EXISTS(SELECT 1 FROM work w WHERE w.museum_id=m.museum_id);

-- 3: How many paintings have an asking price of more than their regular price?
SELECT * FROM product_size
WHERE sale_price > regular_price;

-- 4: Identify the paintings whose asking price is less than 50% of its regular price
SELECT * FROM product_size
WHERE sale_price < (regular_price * 0.5);

-- 5: Which canva size costs the most?
SELECT cs.label AS canva_size, ps.sale_price
FROM (SELECT * , RANK() OVER(ORDER BY sale_price DESC) AS rnk
	 FROM product_size) AS ps
JOIN canvas_size AS cs
ON cs.size_id::text=ps.size_id
WHERE ps.rnk=1;

-- 6: Delete duplicate records from work, product_size, subject and image_link tables
DELETE FROM work 
	WHERE ctid NOT IN (SELECT MIN(ctid)
						FROM work
						GROUP BY work_id);
DELETE FROM product_size 
	WHERE ctid NOT IN (SELECT MIN(ctid)
					FROM product_size
					GROUP BY work_id);
DELETE FROM subject 
	WHERE ctid NOT IN (SELECT MIN(ctid)
					FROM subject
					GROUP BY work_id);
DELETE FROM image_link 
	WHERE ctid NOT IN (SELECT MIN(ctid)
					FROM image_link
					GROUP BY work_id);

-- 7: Identify the museums with invalid city information in the given dataset
SELECT * FROM museum
WHERE city ~ '^[0-9]';

-- 8: Museum_Hours table has 1 invalid entry. Identify it and remove it.
DELETE FROM museum_hours
WHERE ctid NOT IN (SELECT MIN(ctid)
				  FROM museum_hours
				  GROUP BY museum_id, day);

-- 9: Fetch the top 10 most famous painting subject
SELECT * 
FROM (SELECT s.subject, COUNT(1) AS nr_of_paintings, 
		RANK()OVER(ORDER BY COUNT(1) DESC) AS ranking
		FROM work w
		JOIN subject s 
		ON s.work_id=w.work_id
		GROUP BY subject) AS x
WHERE ranking <=10;

-- 10: Identify the museums which are open on both Sunday and Monday. Display museum name, city.
SELECT DISTINCT m.name as museum_name, m.city, m.state, m.country
FROM museum m
INNER JOIN museum_hours mh
ON m.museum_id=mh.museum_id
WHERE day = 'Sunday' AND EXISTS(SELECT * FROM museum_hours mh2
							   WHERE mh.museum_id=mh2.museum_id
							   AND mh2.day='Monday');

-- 11: How many museums are open every single day?
SELECT COUNT(*)
FROM (SELECT museum_id, COUNT(*)
	  FROM museum_hours
	  GROUP BY museum_id
	  HAVING COUNT(*) = 7);

-- 12: Which are the top 5 most popular museum? (Popularity is defined based on most no of paintings in a museum)
SELECT m.name AS museum, m.city, m.country, x.no_of_paintings
FROM (SELECT m.museum_id, COUNT(*) AS no_of_paintings,
	  RANK()OVER(ORDER BY COUNT(*) DESC) AS rnk
	  FROM work w
	 JOIN museum m ON m.museum_id=w.museum_id
	 GROUP BY m.museum_id) AS x
JOIN museum m ON m.museum_id=x.museum_id
WHERE rnk <= 5;

-- 13: Who are the top 5 most popular artist? (Popularity is defined based on most no of paintings done by an artist)
SELECT a.full_name AS artist, a.nationality, x.no_of_paintings
FROM (SELECT a.artist_id, COUNT(*) AS no_of_paintings,
	 RANK()OVER(ORDER BY COUNT(*) DESC) AS rnk
	 FROM work w 
	 JOIN artist a ON a.artist_id=w.artist_id
	 GROUP BY a.artist_id) AS x
JOIN artist a ON a.artist_id=x.artist_id
WHERE rnk <= 5;

-- 14: Display the 3 least popular canva sizes
SELECT label, ranking, no_of_paintings
FROM (SELECT cs.size_id, cs.label, COUNT(*) AS no_of_paintings,
	 DENSE_RANK()OVER(ORDER BY COUNT(*)) AS ranking
	 FROM work w
	 JOIN product_size ps ON ps.work_id=w.work_id
	 JOIN canvas_size cs ON cs.size_id::text=ps.size_id
	 GROUP BY cs.size_id, cs.label) AS x
WHERE x.ranking <=3;

-- 15: Which museum is open for the longest during a day. Dispay museum name, state and hours open and which day?
SELECT museum_name, state AS city, day, open, close, duration
FROM (SELECT m.name AS museum_name, m.state, day, open, close,
	 TO_TIMESTAMP(open, 'HH:MI AM'), TO_TIMESTAMP(close, 'HH:MI PM'), 
	 TO_TIMESTAMP(close, 'HH:MI PM') - TO_TIMESTAMP(open, 'HH:MI AM') AS duration,
	 RANK()OVER(ORDER BY (TO_TIMESTAMP(close, 'HH:MI PM') - TO_TIMESTAMP(open, 'HH:MI AM')) DESC) AS rnk
	 FROM museum_hours mh
	 JOIN museum m ON m.museum_id=mh.museum_id) AS x
WHERE x.rnk=1;

-- 16: Which museum has the most no of most popular painting style?
WITH pop_style AS (
	SELECT style, RANK()OVER(ORDER BY COUNT(1)DESC) AS rnk
	FROM work
	GROUP BY style),
	cte AS (SELECT w.museum_id, m.name AS museum_name, ps.style, COUNT(*) AS no_of_paintings,
		   RANK()OVER(ORDER BY COUNT(*) DESC) AS rnk
		   FROM work w
		   JOIN museum m ON m.museum_id=w.museum_id
		   JOIN pop_style ps ON ps.style=w.style
		   WHERE w.museum_id IS NOT NULL AND ps.rnk=1
		   GROUP BY w.museum_id, m.name, ps.style)
SELECT museum_name, style, no_of_paintings
FROM cte
WHERE rnk=1;
	
-- 17: Identify the artists whose paintings are displayed in multiple countries]
WITH cte AS (SELECT DISTINCT a.full_name AS artist, w.name AS painting,
			 m.museum_id AS museum, m.country
			FROM work w
			JOIN artist a ON a.artist_id=w.artist_id
			JOIN museum m ON m.museum_id=w.museum_id)
SELECT artist, COUNT(*) AS no_of_paintings
FROM cte 
GROUP BY artist
HAVING COUNT(*)>1
ORDER BY 2 DESC;

-- 18: Display the country and the city with most no of museums. Output 2 seperate columns to mention the city and country. 
-- If there are multiple value, seperate them with comma.
WITH cte_country AS (SELECT country, COUNT(*),
				RANK()OVER(ORDER BY COUNT(*) DESC) AS rnk
				FROM museum
				GROUP BY country),				
		cte_city AS (SELECT city, COUNT(*),
				RANK()OVER(ORDER BY COUNT(*) DESC) AS rnk
				FROM museum
				GROUP BY city)
SELECT string_agg(DISTINCT country.country,', '), string_agg(city.city,', ')
FROM cte_country country
CROSS JOIN cte_city city
WHERE country.rnk = 1
AND city.rnk = 1;

-- 19: Identify the artist and the museum where the most expensive and least expensive painting is placed. 
-- Display the artist name, sale_price, painting name, museum name, museum city and canvas label
WITH cte AS (SELECT *,
			RANK()OVER(ORDER BY sale_price DESC) AS rnk,
			RANK()OVER(ORDER BY sale_price) AS rnk_asc
			FROM product_size)
SELECT w.name AS painting, cte.sale_price, a.full_name AS artist, m.name AS museum, m.city, cz.label AS canvas
FROM cte
JOIN work w ON w.work_id=cte.work_id
JOIN museum m ON m.museum_id=w.museum_id
JOIN artist a ON a.artist_id=w.artist_id
JOIN canvas_size cz ON cz.size_id=cte.size_id::NUMERIC
WHERE rnk =1 OR rnk_asc=1;


-- 20: Which country has the 5th highest no of paintings?
WITH cte AS
	(SELECT m.country AS country, COUNT(*) AS no_of_paintings,
	  RANK()OVER(ORDER BY COUNT(*) DESC) as rnk
	  FROM work w
	  JOIN museum m	ON m.museum_id=w.museum_id
	  GROUP BY m.country)
SELECT country, no_of_paintings
FROM cte
WHERE rnk =5;

-- 21: Which are the 3 most popular and 3 least popular painting styles?

WITH cte AS (SELECT style, COUNT(style) as total_arts,
	RANK()OVER(ORDER BY COUNT(style) DESC) AS rnk,
	COUNT(*)OVER() AS num_of_records
	FROM work
	WHERE style IS NOT NULL
	GROUP BY style)
SELECT style, total_arts,
CASE WHEN rnk <=3 THEN 'Most Popular' ELSE 'Least Popular' END AS remarks
FROM cte
WHERE rnk <= 3 OR rnk > num_of_records -3;

-- 22) Which artist has the most no of Portrait paintings outside the USA? 
-- Display the artist's name, no of paintings, and the artist's nationality.

SELECT full_name AS artist_name, nationality, num_of_paintings
FROM
	(SELECT a.full_name, a.nationality, COUNT(*) AS num_of_paintings,
	RANK()OVER(ORDER BY COUNT(*) DESC) AS rnk
	FROM work w
	JOIN artist a ON a.artist_id=w.artist_id
	JOIN subject s ON s.work_id=w.work_id
	JOIN museum m ON m.museum_id=w.museum_id
	WHERE s.subject = 'Portraits'
	AND m.country != 'USA'
	GROUP BY a.full_name, a.nationality) x
WHERE rnk=1;

-- Thanks!!





			   