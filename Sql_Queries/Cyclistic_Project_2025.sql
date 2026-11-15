# Data Cleaning
-- The datasets for the months of 2025 were combined into a single table:
CREATE TABLE complete_2025_divvy_tripdata 
SELECT * FROM Cyclistic_2025.`202501-divvy-tripdata`
UNION ALL
SELECT * FROM `202502-divvy-tripdata`
UNION ALL
SELECT * FROM `202503-divvy-tripdata`
UNION ALL
SELECT * FROM `202504-divvy-tripdata`
UNION ALL
SELECT * FROM `202505-divvy-tripdata`
UNION ALL
SELECT * FROM `202506-divvy-tripdata`
UNION ALL
SELECT * FROM `202507-divvy-tripdata`
UNION ALL
SELECT * FROM `202508-divvy-tripdata`
UNION ALL
SELECT * FROM `202509-divvy-tripdata`
UNION ALL
SELECT * FROM `202510-divvy-tripdata`
UNION ALL
SELECT * FROM `202511-divvy-tripdata`
UNION ALL
SELECT * FROM `202512-divvy-tripdata`;



-- Check for duplicates
SELECT 
    count(Distinct ride_id),
    count(ride_id)
FROM complete_2025_divvy_tripdata;



-- Determine the type of bikes used by the Cyclistic
SELECT 
	DISTINCT rideable_type
FROM 
	complete_2025_divvy_tripdata;



-- Determine the type of bikes used by the Cyclistic
SELECT 
	DISTINCT member_casual
FROM 
	complete_2025_divvy_tripdata;



-- The following code steps was used to replace blank cells with null
-- 1. Safety precaution anytime we want to make permanent changes to our table
START TRANSACTION;

-- 2. Turn off safe update mode
SET SQL_SAFE_UPDATES = 0;

--  3: Turn empty strings into NULL for all columns
UPDATE complete_2025_divvy_tripdata 
SET 
    start_station_name = NULLIF(start_station_name, ''),
    start_station_id = NULLIF(start_station_id, ''),
    end_station_name = NULLIF(end_station_name, ''),
    end_station_id= NULLIF(end_station_id, ''),
    end_lat = NULLIF(end_lat, ''),
    end_lng = NULLIF(end_lng, '');
    
-- 4. Turn safe update mode back on
SET SQL_SAFE_UPDATES = 1;

-- 5. After the updates has been verified to be correct we run the following
COMMIT;



/* Columns that were unable to upload in their original datatype were converted to text 
for easy upload. Which was then converted to their original datatype after the upload*/

ALTER TABLE complete_2025_divvy_tripdata 
MODIFY started_at DATETIME,
MODIFY ended_at DATETIME,
MODIFY end_lat DOUBLE,
MODIFY end_lng DOUBLE;



-- The following steps creates a new column, ride_minutes_precise and calculates the trip duration
--  1. Create a new column for the travel duration of every ride
ALTER TABLE complete_2025_divvy_tripdata
ADD COLUMN ride_minutes_precise DECIMAL(8,2);

-- 2. Safety precaution anytime we want to make permanent changes to our table
START TRANSACTION;

-- 3. Turn off safe update mode
SET SQL_SAFE_UPDATES = 0;

-- 4. Calculates and populate the ride_minutes_precise column with the trip duration
UPDATE complete_2025_divvy_tripdata
SET ride_minutes_precise = ROUND(TIMESTAMPDIFF(SECOND, started_at, ended_at) / 60, 2);

-- 5. Turn safe update mode back on
SET SQL_SAFE_UPDATES = 1;

-- 6. After the updates has been verified to be correct we run the following
COMMIT;



-- The following steps deletes rows with ride_minutes_precise <= 0
-- 1. Safety precaution anytime we want to make permanent changes to our table
START TRANSACTION;

-- 2. Turn off safe update mode
SET SQL_SAFE_UPDATES = 0;

-- 3. Delete rows with ride_minutes_precise less than  or equal to 0
DELETE FROM complete_2025_divvy_tripdata 
WHERE ride_minutes_precise <= 0;

-- 4. Turn safe update mode back on
SET SQL_SAFE_UPDATES = 1;

-- 5. After the updates has been verified to be correct we run the following
COMMIT;



-- The following steps creates the column, trip_month_name and generates the month in which each ride took place.
-- 1. Safety precaution anytime we want to make permanent changes to our table
START TRANSACTION;

-- 2. Turn off safe update mode
SET SQL_SAFE_UPDATES = 0;

-- 3. Create a text column for the month of every trip
ALTER TABLE complete_2025_divvy_tripdata 
ADD COLUMN trip_month_name VARCHAR(15);

-- 5. Fill it with the month name
UPDATE complete_2025_divvy_tripdata 
SET trip_month_name = MONTHNAME(started_at);

-- 6. Turn safe update mode back on
SET SQL_SAFE_UPDATES = 1;

-- 7. After the updates has been verified to be correct we run the following
COMMIT;



-- The following steps creates the column, trip_season and generates the season in which each ride took place
-- 1. Create a new column for seasons
ALTER TABLE complete_2025_divvy_tripdata
ADD COLUMN trip_season VARCHAR(15);

-- 2. Safety precaution anytime we want to make permanent changes to our table
START TRANSACTION;

-- 3. Turn off safe update mode
SET SQL_SAFE_UPDATES = 0;

-- 4. Populate the seasons column with its values using the following code
UPDATE complete_2025_divvy_tripdata
SET trip_season = CASE 
    WHEN trip_month_name IN ('December', 'January', 'February')  THEN 'Winter'
    WHEN trip_month_name IN ('March', 'April', 'May')   THEN 'Spring'
    WHEN trip_month_name IN ('June', 'July', 'August')   THEN 'Summer'
    WHEN trip_month_name IN ('September', 'October', 'November') THEN 'Autumn'
END;

-- 5. Turn safe update mode back on
SET SQL_SAFE_UPDATES = 1;

-- 6. After the updates has been verified to be correct we run the following
COMMIT;



-- Finding the distributions and average of the trip duration column, ride_minutes_precise 
WITH RankedData AS (
    SELECT
        ride_minutes_precise,

        ROW_NUMBER() OVER (
            ORDER BY ride_minutes_precise
        ) AS rn,

        COUNT(*) OVER () AS n

    FROM complete_2025_divvy_tripdata
    WHERE ride_minutes_precise > 0
),

Positions AS (
    SELECT DISTINCT
        n,

        1 + (n - 1) * 0.25 AS q1_pos,
        1 + (n - 1) * 0.50 AS q2_pos,
        1 + (n - 1) * 0.75 AS q3_pos

    FROM RankedData
),

Quartiles AS (
    SELECT
        p.n,

        /* Q1 */
        MAX(CASE
            WHEN r.rn = FLOOR(p.q1_pos)
            THEN r.ride_minutes_precise
        END)
        +
        (p.q1_pos - FLOOR(p.q1_pos))
        *
        (
            MAX(CASE
                WHEN r.rn = CEIL(p.q1_pos)
                THEN r.ride_minutes_precise
            END)
            -
            MAX(CASE
                WHEN r.rn = FLOOR(p.q1_pos)
                THEN r.ride_minutes_precise
            END)
        ) AS q1,

        /* Q2 / Median */
        MAX(CASE
            WHEN r.rn = FLOOR(p.q2_pos)
            THEN r.ride_minutes_precise
        END)
        +
        (p.q2_pos - FLOOR(p.q2_pos))
        *
        (
            MAX(CASE
                WHEN r.rn = CEIL(p.q2_pos)
                THEN r.ride_minutes_precise
            END)
            -
            MAX(CASE
                WHEN r.rn = FLOOR(p.q2_pos)
                THEN r.ride_minutes_precise
            END)
        ) AS q2,

        /* Q3 */
        MAX(CASE
            WHEN r.rn = FLOOR(p.q3_pos)
            THEN r.ride_minutes_precise
        END)
        +
        (p.q3_pos - FLOOR(p.q3_pos))
        *
        (
            MAX(CASE
                WHEN r.rn = CEIL(p.q3_pos)
                THEN r.ride_minutes_precise
            END)
            -
            MAX(CASE
                WHEN r.rn = FLOOR(p.q3_pos)
                THEN r.ride_minutes_precise
            END)
        ) AS q3

    FROM Positions p
    CROSS JOIN RankedData r

    GROUP BY
        p.n,
        p.q1_pos,
        p.q2_pos,
        p.q3_pos
),

Statistics AS (
    SELECT
        n,
        q1,
        q2,
        q3,

        q3 - q1 AS iqr,

        q3 + 1.5 * (q3 - q1) AS upper_fence

    FROM Quartiles
)

SELECT
    s.n AS ride_count,

    MIN(r.ride_minutes_precise) AS minimum,

    s.q1,

    s.q2 AS median,

    s.q3,

    s.iqr,

    s.upper_fence,

    MAX(r.ride_minutes_precise) AS maximum,

    /* Average including all rides */
    AVG(r.ride_minutes_precise) AS average_all,

    /* Average excluding upper outliers */
    AVG(
        CASE
            WHEN r.ride_minutes_precise <= s.upper_fence
            THEN r.ride_minutes_precise
        END
    ) AS average_without_outliers,

    /* Number of upper outliers */
    SUM(
        CASE
            WHEN r.ride_minutes_precise > s.upper_fence
            THEN 1
            ELSE 0
        END
    ) AS upper_outlier_count

FROM Statistics s
CROSS JOIN RankedData r

GROUP BY
    s.n,
    s.q1,
    s.q2,
    s.q3,
    s.iqr,
    s.upper_fence;
    
    
 
 -- Calculate their distributions and averages and group by member_casual
 WITH RankedData AS (
    SELECT
        member_casual,
        ride_minutes_precise,

        ROW_NUMBER() OVER (
            PARTITION BY member_casual
            ORDER BY ride_minutes_precise
        ) AS rn,

        COUNT(*) OVER (
            PARTITION BY member_casual
        ) AS n

    FROM complete_2025_divvy_tripdata
    WHERE ride_minutes_precise > 0
),

Positions AS (
    SELECT DISTINCT
        member_casual,
        n,

        1 + (n - 1) * 0.25 AS q1_pos,
        1 + (n - 1) * 0.50 AS q2_pos,
        1 + (n - 1) * 0.75 AS q3_pos

    FROM RankedData
),

Quartiles AS (
    SELECT
        p.member_casual,
        p.n,

        /* Q1 */
        MAX(
            CASE
                WHEN r.rn = FLOOR(p.q1_pos)
                THEN r.ride_minutes_precise
            END
        )
        +
        (p.q1_pos - FLOOR(p.q1_pos))
        *
        (
            MAX(
                CASE
                    WHEN r.rn = CEIL(p.q1_pos)
                    THEN r.ride_minutes_precise
                END
            )
            -
            MAX(
                CASE
                    WHEN r.rn = FLOOR(p.q1_pos)
                    THEN r.ride_minutes_precise
                END
            )
        ) AS q1,

        /* Q2 / Median */
        MAX(
            CASE
                WHEN r.rn = FLOOR(p.q2_pos)
                THEN r.ride_minutes_precise
            END
        )
        +
        (p.q2_pos - FLOOR(p.q2_pos))
        *
        (
            MAX(
                CASE
                    WHEN r.rn = CEIL(p.q2_pos)
                    THEN r.ride_minutes_precise
                END
            )
            -
            MAX(
                CASE
                    WHEN r.rn = FLOOR(p.q2_pos)
                    THEN r.ride_minutes_precise
                END
            )
        ) AS q2,

        /* Q3 */
        MAX(
            CASE
                WHEN r.rn = FLOOR(p.q3_pos)
                THEN r.ride_minutes_precise
            END
        )
        +
        (p.q3_pos - FLOOR(p.q3_pos))
        *
        (
            MAX(
                CASE
                    WHEN r.rn = CEIL(p.q3_pos)
                    THEN r.ride_minutes_precise
                END
            )
            -
            MAX(
                CASE
                    WHEN r.rn = FLOOR(p.q3_pos)
                    THEN r.ride_minutes_precise
                END
            )
        ) AS q3

    FROM Positions p

    JOIN RankedData r
        ON p.member_casual = r.member_casual

    GROUP BY
        p.member_casual,
        p.n,
        p.q1_pos,
        p.q2_pos,
        p.q3_pos
),

Statistics AS (
    SELECT
        member_casual,
        n,
        q1,
        q2,
        q3,

        q3 - q1 AS iqr,

        /* Only calculate the upper fence */
        q3 + 1.5 * (q3 - q1) AS upper_fence

    FROM Quartiles
)

SELECT
    s.member_casual,

    s.n AS ride_count,

    MIN(r.ride_minutes_precise) AS minimum,

    s.q1,

    s.q2 AS median,

    s.q3,

    s.iqr,

    s.upper_fence,

    MAX(r.ride_minutes_precise) AS maximum,

    /* Average including all rides */
    AVG(r.ride_minutes_precise) AS average_all,

    /* Average excluding upper outliers */
    AVG(
        CASE
            WHEN r.ride_minutes_precise <= s.upper_fence
            THEN r.ride_minutes_precise
        END
    ) AS average_without_outliers,

    /* Number of upper outliers */
    SUM(
        CASE
            WHEN r.ride_minutes_precise > s.upper_fence
            THEN 1
            ELSE 0
        END
    ) AS upper_outlier_count,

    /* Percentage of rides that are upper outliers */
    ROUND(
        100.0 *
        SUM(
            CASE
                WHEN r.ride_minutes_precise > s.upper_fence
                THEN 1
                ELSE 0
            END
        ) / s.n,
        2
    ) AS upper_outlier_percentage

FROM Statistics s

JOIN RankedData r
    ON s.member_casual = r.member_casual

GROUP BY
    s.member_casual,
    s.n,
    s.q1,
    s.q2,
    s.q3,
    s.iqr,
    s.upper_fence

ORDER BY
    s.member_casual;
    


-- Calculate distributions and average and group by member_casual and trip_season
WITH RankedData AS (
    SELECT
        member_casual,
        trip_season,
        ride_minutes_precise,

        ROW_NUMBER() OVER (
            PARTITION BY member_casual, trip_season
            ORDER BY ride_minutes_precise
        ) AS rn,

        COUNT(*) OVER (
            PARTITION BY member_casual, trip_season
        ) AS n

    FROM complete_2025_divvy_tripdata
    WHERE ride_minutes_precise > 0
),

QuartilePositions AS (
    SELECT
        member_casual,
        trip_season,
        n,

        1 + (n - 1) * 0.25 AS q1_pos,
        1 + (n - 1) * 0.50 AS q2_pos,
        1 + (n - 1) * 0.75 AS q3_pos

    FROM RankedData
    GROUP BY
        member_casual,
        trip_season,
        n
),

Quartiles AS (
    SELECT
        q.member_casual,
        q.trip_season,
        q.n,

        /* Q1 */
        MAX(CASE
            WHEN r.rn = FLOOR(q.q1_pos)
            THEN r.ride_minutes_precise
        END)
        +
        (q.q1_pos - FLOOR(q.q1_pos))
        *
        (
            MAX(CASE
                WHEN r.rn = CEIL(q.q1_pos)
                THEN r.ride_minutes_precise
            END)
            -
            MAX(CASE
                WHEN r.rn = FLOOR(q.q1_pos)
                THEN r.ride_minutes_precise
            END)
        ) AS q1,

        /* Q2 / Median */
        MAX(CASE
            WHEN r.rn = FLOOR(q.q2_pos)
            THEN r.ride_minutes_precise
        END)
        +
        (q.q2_pos - FLOOR(q.q2_pos))
        *
        (
            MAX(CASE
                WHEN r.rn = CEIL(q.q2_pos)
                THEN r.ride_minutes_precise
            END)
            -
            MAX(CASE
                WHEN r.rn = FLOOR(q.q2_pos)
                THEN r.ride_minutes_precise
            END)
        ) AS q2,

        /* Q3 */
        MAX(CASE
            WHEN r.rn = FLOOR(q.q3_pos)
            THEN r.ride_minutes_precise
        END)
        +
        (q.q3_pos - FLOOR(q.q3_pos))
        *
        (
            MAX(CASE
                WHEN r.rn = CEIL(q.q3_pos)
                THEN r.ride_minutes_precise
            END)
            -
            MAX(CASE
                WHEN r.rn = FLOOR(q.q3_pos)
                THEN r.ride_minutes_precise
            END)
        ) AS q3

    FROM QuartilePositions q

    JOIN RankedData r
        ON q.member_casual = r.member_casual
        AND q.trip_season = r.trip_season

    GROUP BY
        q.member_casual,
        q.trip_season,
        q.n,
        q.q1_pos,
        q.q2_pos,
        q.q3_pos
),

Fences AS (
    SELECT
        member_casual,
        trip_season,
        n,
        q1,
        q2,
        q3,

        /* IQR */
        q3 - q1 AS iqr,

        /* Only upper fence */
        q3 + 1.5 * (q3 - q1) AS upper_fence

    FROM Quartiles
)

SELECT
    r.member_casual,
    r.trip_season,

    f.n AS ride_count,

    /* Minimum and maximum */
    MIN(r.ride_minutes_precise) AS minimum,
    MAX(r.ride_minutes_precise) AS maximum,

    /* Quartiles */
    f.q1,
    f.q2 AS median,
    f.q3,

    /* IQR */
    f.iqr,

    /* Upper outlier fence only */
    f.upper_fence,

    /* Average using ALL rides */
    AVG(r.ride_minutes_precise) AS average_all,

    /* Average excluding upper outliers */
    AVG(
        CASE
            WHEN r.ride_minutes_precise <= f.upper_fence
            THEN r.ride_minutes_precise
        END
    ) AS average_without_outliers,

    /* Number of upper outlier rides */
    SUM(
        CASE
            WHEN r.ride_minutes_precise > f.upper_fence
            THEN 1
            ELSE 0
        END
    ) AS upper_outlier_count

FROM RankedData r

JOIN Fences f
    ON r.member_casual = f.member_casual
    AND r.trip_season = f.trip_season

GROUP BY
    r.member_casual,
    r.trip_season,
    f.n,
    f.q1,
    f.q2,
    f.q3,
    f.iqr,
    f.upper_fence

ORDER BY
    r.member_casual,
    FIELD(
        r.trip_season,
        'Winter',
        'Spring',
        'Summer',
        'Fall'
    );
    
    
    
-- Calculate the most frequent station to station route
SELECT
	start_station_name,
    end_station_name,
    member_casual,
    Count(member_casual)
FROM complete_2025_divvy_tripdata
WHERE start_station_name != 'NULL' AND end_station_name != 'NULL'
GROUP BY start_station_name,end_station_name,member_casual
ORDER BY Count(member_casual) DESC
LIMIT 10;



-- Calculate the most frequent station to station route by members
SELECT
	start_station_name,
    end_station_name,
    member_casual,
    Count(member_casual)
FROM complete_2025_divvy_tripdata
WHERE start_station_name != 'NULL' AND end_station_name != 'NULL' AND member_casual = 'member'
GROUP BY start_station_name,end_station_name,member_casual
ORDER BY Count(member_casual) DESC
LIMIT 10;



-- Calculate the most frequent station to station route by casuals
SELECT
	start_station_name,
    end_station_name,
    member_casual,
    Count(member_casual)
FROM complete_2025_divvy_tripdata
WHERE start_station_name != 'NULL' AND end_station_name != 'NULL' AND member_casual = 'casual'
GROUP BY start_station_name,end_station_name,member_casual
ORDER BY Count(member_casual) DESC
LIMIT 10;



-- Determines the ride per month for both casual and members 
SELECT
    member_casual,
    trip_month_name,
    Count(ride_id)
FROM complete_2025_divvy_tripdata
GROUP BY member_casual,trip_month_name;