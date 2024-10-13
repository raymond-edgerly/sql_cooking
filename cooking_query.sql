/* Temporary table to store data.*/
DROP TABLE IF EXISTS results_table CASCADE;

CREATE TABLE results_table AS 
WITH current_season AS (
    SELECT CASE
        WHEN EXTRACT(MONTH FROM CURRENT_DATE) IN (3, 4, 5) THEN 1  -- Spring
        WHEN EXTRACT(MONTH FROM CURRENT_DATE) IN (6, 7, 8) THEN 2  -- Summer
        WHEN EXTRACT(MONTH FROM CURRENT_DATE) IN (9, 10, 11) THEN 3  -- Autumn
        ELSE 4  -- Winter
    END AS season_number
),
dates AS (
    -- Generate dates for the next two weeks starting from next Monday
    SELECT date_trunc('week', CURRENT_DATE) + INTERVAL '7 days' + (n * INTERVAL '1 day') AS date
    FROM generate_series(0, 13) AS n
),
meal_type_day_numbers AS (
    -- Map meal types to dates and assign row numbers within each meal type
    SELECT 
        meal_type, 
        date,
        ROW_NUMBER() OVER (PARTITION BY meal_type ORDER BY date) AS rn
    FROM (
        SELECT date, 
            CASE 
                WHEN EXTRACT(ISODOW FROM date) BETWEEN 1 AND 3 THEN 'initial_random'      -- Monday to Wednesday
                WHEN EXTRACT(ISODOW FROM date) = 4 THEN 'additional_solo'                 -- Thursday
                WHEN EXTRACT(ISODOW FROM date) = 5 THEN 'additional_friday'               -- Friday
                WHEN EXTRACT(ISODOW FROM date) IN (6, 7) THEN 'additional_weekend'        -- Saturday and Sunday
            END AS meal_type
        FROM dates
    ) sub
),
initial_random_meals AS (
    SELECT meals.*, ROW_NUMBER() OVER (ORDER BY RANDOM()) AS rn
    FROM meals, current_season
    WHERE meals.solo <> 1 
      AND meals.weekend <> 1 
      AND current_season.season_number = ANY(meals.season)
    LIMIT (SELECT COUNT(*) FROM meal_type_day_numbers WHERE meal_type = 'initial_random')
),
additional_solo_meals AS (
    SELECT meals.*, ROW_NUMBER() OVER (ORDER BY RANDOM()) AS rn
    FROM meals, current_season
    WHERE meals.solo = 1 
      AND current_season.season_number = ANY(meals.season)
      AND meals.meal_name NOT IN (SELECT meal_name FROM initial_random_meals)
    LIMIT (SELECT COUNT(*) FROM meal_type_day_numbers WHERE meal_type = 'additional_solo')
),
additional_friday_meals AS (
    SELECT meals.*, ROW_NUMBER() OVER (ORDER BY RANDOM()) AS rn
    FROM meals, current_season
    WHERE meals.solo <> 1 
      AND meals.weekend <> 1 
      AND current_season.season_number = ANY(meals.season)
      AND meals.meal_name NOT IN (
          SELECT meal_name FROM initial_random_meals
          UNION
          SELECT meal_name FROM additional_solo_meals
      )
    LIMIT (SELECT COUNT(*) FROM meal_type_day_numbers WHERE meal_type = 'additional_friday')
),
additional_weekend_meals AS (
    SELECT meals.*, ROW_NUMBER() OVER (ORDER BY RANDOM()) AS rn
    FROM meals, current_season
    WHERE meals.solo <> 1 
      AND current_season.season_number = ANY(meals.season)
      AND meals.meal_name NOT IN (
          SELECT meal_name FROM initial_random_meals
          UNION
          SELECT meal_name FROM additional_solo_meals
          UNION
          SELECT meal_name FROM additional_friday_meals
      )
    LIMIT (SELECT COUNT(*) FROM meal_type_day_numbers WHERE meal_type = 'additional_weekend')
),
meals_with_rn AS (
    SELECT meal_id, meal_name, solo, season, weekend, 'initial_random' AS meal_type, rn
    FROM initial_random_meals
    UNION ALL
    SELECT meal_id, meal_name, solo, season, weekend, 'additional_solo' AS meal_type, rn
    FROM additional_solo_meals
    UNION ALL
    SELECT meal_id, meal_name, solo, season, weekend, 'additional_friday' AS meal_type, rn
    FROM additional_friday_meals
    UNION ALL
    SELECT meal_id, meal_name, solo, season, weekend, 'additional_weekend' AS meal_type, rn
    FROM additional_weekend_meals
),
selected_meals AS (
    SELECT
        mtd.date,
        mtd.meal_type,
        meals.meal_id,
        meals.meal_name,
        meals.season
    FROM meal_type_day_numbers mtd
    JOIN meals_with_rn meals
      ON mtd.meal_type = meals.meal_type AND mtd.rn = meals.rn
)
SELECT
    TO_CHAR(date, 'Dy FMMM/DD') AS day_of_week,
    meal_id,
    meal_name,
    season
FROM selected_meals
ORDER BY date;

