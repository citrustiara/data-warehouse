# Data Warehouse for Tram Transport System (ZTM Gdańsk)

A university group project for the **Data Warehouses** course at Gdańsk University of Technology. The project involves designing and implementing a complete Business Intelligence system for a fictional tram transport organization (ZTM Gdańsk), focused on analyzing tram delays and malfunctions across the network.

> **Note:** This was a group project. My responsibilities covered stages 1–6 (from requirements specification through ETL implementation). The later stages — MDX queries, Power BI dashboard, and query optimization — were handled by other team members.

## Project Stages

### 1. Business Process Specification
Definition of two key business processes — tram operations (monitoring arrival times, registering delays) and maintenance service (reporting and repairing malfunctions). Identification of measurable goals: monthly reduction of total delays by ≥2% and total malfunctions by ≥3%.

### 2. Requirements Specification
Design of two data source structures — a relational GTFS database (Agency, Routes, Calendar_Dates, Trips, Stops, Stop_Times tables) and CSV files (malfunctions.csv, drivers.csv). Formulation of 12 analytical queries including cross-source queries, a query requiring additional weather data, and a query requiring business process changes.

### 3. Data Generator
Python-based data generators (pandas, numpy) producing realistic datasets — tram trips, stop times with delays (accounting for rush hours, weather conditions, delay propagation), malfunctions, and drivers. Data generated in two time snapshots (T1, T2) scalable up to 1 million records. Data loaded via BULK loading.

### 4. Data Warehouse Design
Star schema design with a central **TRIP_OPERATIONS_FACT** table containing measures: delay minutes, planned travel time, malfunction-caused delay, repair duration, and calculated measures (punctuality percentage, on-site repair percentage). Eight dimension tables:

| Dimension | Description |
|-----------|-------------|
| DATE_DIM | Hierarchical: Year → Month → Day |
| TIME_DIM | Hierarchical: Time of Day Category → Hour |
| ROUTE_DIM | Tram lines |
| STOP_DIM | Stops with geolocation and district |
| DRIVER_DIM | Drivers — **SCD Type 2** (tracking experience category changes) |
| TRAM_DIM | Tram vehicles |
| TRIP_DIM | Tram trips/courses |
| MALFUNCTION_DIM | Malfunction types (nullable) |

### Data Warehouse Schema
![Star Schema](projekty/hurtownie-danych/projectreport.png)

### 5. Data Warehouse Implementation
Implementation in MS SQL Server — DDL scripts for fact and dimension tables, loading scripts transferring data from source database and CSV files with surrogate key generation.

### 6. ETL Process (SSIS)
ETL process implemented in SQL Server Integration Services within Visual Studio 2022. Handles two-phase loading (initial full load + incremental updates), SCD Type 2 dimension loading for DRIVER_DIM with record versioning, and automatic OLAP cube processing after ETL completion.

![OLAP Cube in Visual Studio](projekty/hurtownie-danych/VS_cube.png)

![ETL Control Flow in SSIS](projekty/hurtownie-danych/automation.png)

### 7. MDX Queries & KPIs
MDX queries corresponding to the requirements specification. Usage of: calculated members, WHERE clause, hierarchy functions (PrevMember, Children), TopCount/BottomCount, numerical operations, and filters. KPI implementation in Visual Studio Data Tools.

### 8. Power BI Dashboard
Interactive reports with 8+ pages, KPI presentations across time periods, 8+ chart types, parameterizable reports (year, line, stop selection), delay trends, malfunction distribution analysis.

### 9. Query Optimization
Comparison of different physical cube models (MOLAP, ROLAP, HOLAP) with and without aggregations. Performance testing for query execution times and cube processing times.

## Tech Stack

- **Database:** MS SQL Server
- **ETL:** SQL Server Integration Services (SSIS)
- **OLAP:** SQL Server Analysis Services (SSAS)
- **IDE:** Visual Studio 2022
- **Reporting:** Power BI
- **Data Generation:** Python (pandas, numpy)
- **Query Languages:** T-SQL, MDX
- **Data Format:** GTFS (General Transit Feed Specification)
