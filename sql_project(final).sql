# Convert epoch time to Natural time
SELECT from_unixtime(created_at) AS created_at_new
FROM projects;

ALTER TABLE projects
ADD Column created_at_new datetime AFTER created_at;
UPDATE projects
SET created_at_new = from_unixtime(created_at);

ALTER TABLE projects
ADD Column deadline_new datetime AFTER deadline,
ADD Column updated_at_new datetime AFTER updated_at,
ADD Column state_changed_at_new datetime AFTER state_changed_at,
ADD Column successful_at_new datetime AFTER successful_at,
ADD Column launched_at_new datetime AFTER launched_at,
ADD Column usd_goal_amount int AFTER disable_communication;

ALTER TABLE projects
DROP Column successful_at_new;

UPDATE projects
SET 
    deadline_new = FROM_UNIXTIME(deadline),
    updated_at_new = FROM_UNIXTIME(updated_at),
    state_changed_at_new = FROM_UNIXTIME(state_changed_at),
    launched_at_new = FROM_UNIXTIME(launched_at);

UPDATE projects
SET usd_goal_amount = goal*static_usd_rate;

ALTER TABLE projects 
ADD Column successful_at_new datetime AFTER successful_at;

UPDATE projects
SET successful_at_new = 
    CASE 
        WHEN successful_at REGEXP '^[0-9]+$' THEN FROM_UNIXTIME(CAST(successful_at AS SIGNED))
        ELSE NULL  
    END;

ALTER TABLE projects
ADD Column created_copy date AFTER usd_goal_amount,
ADD Column launched_copy date AFTER created_copy,
ADD Column No_of_Days INT AFTER launched_copy;

UPDATE projects
SET created_copy = date(created_at_new),
	launched_copy = date(launched_at_new),
    No_of_Days = launched_copy - created_copy;

ALTER TABLE projects
DROP Column No_of_Days;
 
ALTER TABLE projects
ADD Column days date AFTER launched_copy;
ALTER TABLE projects
DROP Column days;
ALTER TABLE projects
ADD Column No_of_Days INT AFTER launched_copy;

UPDATE projects
SET No_of_Days = datediff(launched_copy, created_copy);
   
SELECT AVG(No_of_Days) as average_days FROM projects;

# Build relations
Select id
From crowdfunding_category inner join projects on id = category_id;

Select id 
From crowdfunding_creator inner join projects on id = creator_id;

Select id 
From crowdfunding_location inner join projects on id = location_id;

# KPI:1 Total Number Of Projects based on outcome
Select
state as Outcome, 
Count(ProjectID) As Total_Projects
        from projects
        group by state;

# KPI:2 Total Number Of Projects based on Locations (Limit 10 can be used to execute Top 10 Countries)
SELECT
    l.country,
    COUNT(p.ProjectID) AS Total_Projects
FROM crowdfunding_location AS l
INNER JOIN projects AS p ON l.id = p.location_id
GROUP BY l.country
ORDER BY Total_Projects DESC; 

# KPI:3 Total Number Of Projects based on Category (Limit 10 to use for top 10)
Select 
     c.name,
     Count(p.ProjectID) As Total_Projects
From crowdfunding_category As c 
Inner Join projects as p On c.id = p.category_id
Group by c.name
order by Total_Projects DESC;

# KPI:4 Total number Of Projects Based on year quarter and month
SELECT
    YEAR(created_at_new) AS Project_Year,
    QUARTER(created_at_new) AS Project_Quarter,
    monthname(created_at_new) AS Project_Month,
    COUNT(ProjectID) AS Total_Projects
FROM projects
GROUP BY Project_Year, Project_Quarter, Project_Month
ORDER BY Total_Projects DESC;

# KPI:5 Successful projects (Amount Raised, Number Of Backers, Avg_no of days)
SELECT 
    CONCAT('$ ', ROUND(SUM(usd_goal_amount))) AS Amount_Raised,
    SUM(backers_count) AS Number_of_backers,
    ROUND(AVG(No_of_Days)) AS Avg_Days
FROM projects
WHERE state = 'successful'
ORDER BY Number_of_backers DESC;
 
# KPI:6 Top Successful projects (Amount Raised, Number of backers)
SELECT 
    CONCAT('$ ', ROUND(SUM(usd_goal_amount))) AS Amount_Raised,
    SUM(backers_count) AS Number_of_backers,
    CONCAT('$ ', ROUND(SUM(usd_pledged))) AS Amount_Pledged,
    Project_name
FROM (
    SELECT 
        usd_goal_amount,
        backers_count,
        usd_pledged,
        name AS Project_name
    FROM projects
    WHERE state = 'successful'
    ORDER BY usd_pledged DESC
    Limit 10
) AS subquery
GROUP BY Project_name
ORDER BY Amount_Pledged DESC;

# KPI:7 Percentage Of successful projects overall
SELECT
    state as Outcome,
    COUNT(*) AS Total_Projects,
   CONCAT(ROUND((COUNT(*) / (SELECT COUNT(*) FROM projects)) * 100, 2), " %") AS Outcome_Percentage
FROM projects
GROUP BY Outcome;

SELECT
    COUNT(CASE WHEN state = 'successful' THEN 1 END) AS Successful_Projects,
    COUNT(*) AS Total_Projects,
   CONCAT(ROUND((COUNT(CASE WHEN state = 'successful' THEN 1 END) / COUNT(*)) * 100, 2), " %")
   AS Success_Percentage
FROM projects;

# KPI:8 Percentage Of successful projects by Category
SELECT
    c.name As Category_Name,
    COUNT(p.ProjectID) AS Total_Projects,
    SUM(CASE WHEN p.state = 'successful' THEN 1 ELSE 0 END) AS Successful_Projects,
CONCAT(CAST((SUM(CASE WHEN p.state = 'successful' THEN 1 ELSE 0 END) / COUNT(p.ProjectID)) * 100 AS SIGNED)," %")
  AS Success_Percentage
FROM crowdfunding_category as c
INNER JOIN projects p ON c.id = p.category_id
GROUP BY Category_Name
order by Success_Percentage DESC
Limit 10;

# KPI:9 Percentage of successful projects by year, month and quarter
SELECT
    name AS Project_Name,
    YEAR(created_at_new) AS Project_Year,
    QUARTER(created_at_new) AS Project_Quarter,
    MONTHNAME(created_at_new) AS Project_Month,
    COUNT(*) AS Total_Projects,
    SUM(CASE WHEN state = 'Successful' THEN 1 ELSE 0 END) AS Successful_Projects,
    CONCAT(ROUND((SUM(CASE WHEN state = 'Successful' THEN 1 ELSE 0 END) / COUNT(*)) * 100, 2), " %")
    AS Success_Percentage
FROM projects
GROUP BY Project_Name, Project_Year, Project_Quarter, Project_Month
ORDER BY Success_Percentage DESC;

# KPI:10 Percentage of successful Projects based on goal_range
SELECT 
     usd_goal_amount,
     Count(*)  As Total_Projects,
     SUM(CASE WHEN state = 'Successful' THEN 1 ELSE 0 END) AS Successful_Projects,
CONCAT(ROUND((SUM(CASE WHEN state = 'Successful' THEN 1 ELSE 0 END) / COUNT(*)) * 100, 2), " %")
    AS Success_Percentage
From ( Select 
       Case 
         When usd_goal_amount <= 10000 Then "Very Less"
         When usd_goal_amount Between 10000 And 40000 Then "Less"
         When usd_goal_amount Between 40000 And 100000 Then "Average"
         When usd_goal_amount Between 100000 And 1000000 Then "High"
         Else "Very High"
         End as usd_goal_amount, state
         From projects ) As GoalCategorizedProjects
Group By usd_goal_amount
Order By Success_Percentage DESC;


    
 # EXTRA KPI
 
 # Aggregation
 SELECT Count(ProjectID) As Total_Projects,
        CONCAT("$ ", Sum(usd_goal_amount)) As Total_goal_amount,
        CONCAT("$ ", Sum(usd_pledged)) As Total_pledged_amount,
	    Sum(backers_count) As Total_backers,
	    ROUND(AVG(No_of_Days)) As Avg_Days
From projects;

# Top successful creators by (amount_pledged, amount_raised, backers_count)
Select c.name as Creator_name,
	  Sum(p.usd_pledged) As Amount_pledged,
      Sum(p.usd_goal_amount) As Amount_Raised,
	  Sum(p.backers_count) As Total_backers
From crowdfunding_creator as c inner join projects as p On p.creator_id = c.id
Group by Creator_name
Order by Amount_pledged Desc
Limit 10;

# Top successful categories by (amount_pledged, backers_count)
 

# Weekday wise successful projects 
Select c.Weekday_name As week_day,
	   Count(p.ProjectID) As Total_Projects,
       Sum(p.usd_goal_amount) As Amount_Raised,
       Sum(p.usd_pledged) As Amount_Pledged
From calendar as c inner join projects as p On p.created_at_new = c.Dates
where p.state = 'successful'
Group By week_day
Order By Total_Projects DESC;

# Yearwise Financial_month, financial_quarter successful projects 
Select c.Year As Year_wise,
	   c.FinancialMonth As Financial_Month,
       c.FinancialQuarter As Financial_quarter,
       Count(p.ProjectID) As Total_projects,
       Sum(p.usd_goal_amount) As Amount_Raised,
       Sum(p.usd_pledged) As Amount_Pledged
From calendar as c inner join projects as p On p.created_at_new = c.Dates
where p.state = 'successful'
Group by Year_wise, Financial_Month, Financial_quarter
Order by Total_projects DESC;

# Statewise successful projects 
Select l.state as State,
	   Count(p.ProjectID) As Total_projects,
       Sum(p.usd_pledged) As Amount_pledged,
       Sum(p.usd_goal_amount) As Amount_Raised
From crowdfunding_location as l inner join projects as p On p.location_id = l.id
Group By state
Order By Total_Projects DESC;



        
