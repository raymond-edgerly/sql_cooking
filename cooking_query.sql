/* Temporary table to store data.*/
DROP TABLE IF EXISTS results_table CASCADE;
/* Four CTEs for different days of the week: M -> W, Th., Fr., Weekend */
CREATE TABLE results_table AS 
WITH initial_random AS (
    SELECT * FROM meals
     WHERE (meals.solo <> 1 AND meals.weekend <> 1 AND 2 = ANY(meals.season))
     ORDER BY (RANDOM())
     LIMIT 3
), additional_solo AS (
    SELECT * FROM meals
     WHERE ((meals.solo = 1 
             AND 2 = ANY(meals.season)) 
             AND NOT (
               (meals.meal_name)::text IN (
               SELECT initial_random.meal_name
                 FROM initial_random))
               )
     ORDER BY (RANDOM())
     LIMIT 1
), additional_friday AS (
    SELECT * FROM meals
     WHERE ((meals.weekend <> 1 
             AND meals.solo <> 1 
             AND 2 = ANY(meals.season)) 
             AND NOT (
               (meals.meal_name)::text IN (
               SELECT initial_random.meal_name
                 FROM initial_random
                UNION
               SELECT additional_solo.meal_name
                 FROM additional_solo))
           )
     ORDER BY (RANDOM())
     LIMIT 1
), additional_weekend AS (
    SELECT * FROM meals
     WHERE ((meals.solo <> 1 
             AND 2 = ANY(meals.season)) 
             AND NOT ((meals.meal_name)::text IN (
               SELECT initial_random.meal_name
                 FROM initial_random
                UNION
               SELECT additional_solo.meal_name
                 FROM additional_solo
                UNION
               SELECT additional_friday.meal_name
                 FROM additional_friday)))
     ORDER BY (RANDOM())
     LIMIT 2
), combined AS (
    SELECT initial_random.meal_id,
           initial_random.meal_name,
           initial_random.solo,
           initial_random.season,
           initial_random.weekend
      FROM initial_random
     UNION ALL
    SELECT additional_solo.meal_id,
           additional_solo.meal_name,
           additional_solo.solo,
           additional_solo.season,
           additional_solo.weekend
      FROM additional_solo
     UNION ALL
    SELECT additional_friday.meal_id,
           additional_friday.meal_name,
           additional_friday.solo,
           additional_friday.season,
           additional_friday.weekend
      FROM additional_friday
     UNION ALL
    SELECT additional_weekend.meal_id,
           additional_weekend.meal_name,
           additional_weekend.solo,
           additional_weekend.season,
           additional_weekend.weekend
      FROM additional_weekend
), numbered AS (
    SELECT combined.meal_id,
           combined.meal_name,
           combined.solo,
           combined.season,
           combined.weekend,
           ROW_NUMBER() OVER (ORDER BY ( SELECT NULL::text)) AS rn
      FROM combined
)
/* Output the day of the week in specific format + relevant columns from our table */
SELECT TO_CHAR((date_trunc('week'::text, (CURRENT_DATE)::timestamp with time zone) + (((numbered.rn - 1))::double precision * '1 day'::interval) + interval '7 days'), 'Dy FMMM/DD'::text) AS day_of_week,
     numbered.meal_id,
     numbered.meal_name,
     numbered.season
FROM numbered;
