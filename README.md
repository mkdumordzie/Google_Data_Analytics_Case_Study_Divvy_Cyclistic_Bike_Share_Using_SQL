# Google_Data_Analytics_Case_Study_Divvy_Cyclistic_Bike_Share_Using_SQL
Using SQL to analyze the the 2025 Divvy Bike Share dataset to determine marketing strategies for converting casual riders to  members based on how they use the bike share differently.

# Project Title
Cyclistic 2025 Bike Share Analysis

# Project Overview & Business Problem
## 1. The Business Goal
Cyclistic's financial success depends on maximizing the number of annual memberships. The main goal of this project is to design targeted marketing strategies aimed at converting casual riders into loyal, annual members.

## 2. The Analysis Question
Before marketing can create a campaign, they need to know *why* and *how* these two groups ride. This project uses SQL to analyze historical bike-trip data to answer the core question: 
* **How do annual members and casual riders use Cyclistic bikes differently?**

By uncovering these hidden trends, we can give the marketing team data-driven recommendations to help them launch a successful campaign.

# Data Source
The dataset used for this case study is public data provided by **Motivate International Inc.**. 
* You can access and download the original raw data here: [Click Here to View the Dataset](https://divvy-tripdata.s3.amazonaws.com/index.html)
* **Data Privacy Note:** This data has been made available under a public license and does not contain any personally identifiable information (PII).

# Tools Used
* MYSQL
* Google sheets

# Data Cleaning
* The datasets for the months of 2025 were combined into a single table:
* Check for duplicates
* Determine the type of bikes used by the Cyclistic
* Check for the distinct membership type used by the Cyclistic
* Replace blank cells with null
* Columns that were unable to upload in their original datatype were converted to text 
for easy upload. Which was then converted to their original datatype after the upload
* Created a new column, ride_minutes_precise and calculates the trip duration
* Deletes rows with ride_minutes_precise <= 0
* Creates the column, trip_month_name and generates the month in which each ride took place.
* The following steps creates the column, trip_season and generates the season in which each ride took place
```
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
```

# Analysis
* Found the distributions and average of the trip duration column, ride_minutes_precise 
* Calculate the distributions and average of the trip duration column, ride_minutes_precise and group by member_casual
* Calculate the distributions and average of the trip duration column, ride_minutes_precise and group by member_casual and trip_season using code below.
```
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
``` 
* Determined the most frequent station to station route
* Determined the most frequent station to station route by members
* Determined the most frequent station to station route by casuals
* Determined the ride per month for both casual and members

# Visual Report

## Trip Duration Distribution By Member Type and Season
![Visuals](<Visualization_Report/Trip Duration Distribution of Member Type and Seasons.png>)

## Rides Per Month and Member Type
![Visuals](<Visualization_Report/Number of Rides Per Month and Member_Type; Casual and Member.png>)

## Rides Per Season and Member Type
![Visuals](<>)

# Key Insights
* The casual ride duration has a high average and variability than member ride duration
* Casual ride duration variability and average is high during the summer compared to member ride duration
* Casual rides increases between the months of June and August.
* Below are the 10 most used station to station route used by casuals.
- DuSable Lake Shore Dr & Monroe St To DuSable Lake Shore Dr & Monroe St
- Navy Pier To Navy Pier
- Streeter Dr & Grand Ave To Streeter Dr & Grand Ave
- Michigan Ave & Oak St To Michigan Ave & Oak St
- Millennium Park To Millennium Park
- DuSable Lake Shore Dr & Monroe St To Navy Pier
- Dusable Harbor To Dusable Harbor
- DuSable Lake Shore Dr & Monroe St To Streeter Dr & Grand Ave
- Shedd Aquarium To DuSable Lake Shore Dr & Monroe St
- DuSable Lake Shore Dr & North Blvd To DuSable Lake Shore Dr & North Blvd

# Recommendations
- Membership discounts for rides should be increased during the summer to encourage casuals from wanting to become members
- Boost our digital marketing adverts on signages, bill boards and city screens on route used mostly by casuals.
