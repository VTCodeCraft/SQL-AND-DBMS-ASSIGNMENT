# Relational Design, Keys & Normalization Assignment

## Overview

This assignment involves designing a relational database schema for CodeJudge, an online coding platform. The work is split into 4 parts: designing the schema with proper normalization, writing SQL queries, auditing data integrity, and handling transactions.

**Total Marks:** 100

## Assignment Parts

### Part 1: Relational Design, Keys & Normalization (30 marks)

Designing the schema from scratch. This involved analyzing the raw data, figuring out what entities exist, setting up primary and foreign keys, and making sure everything is normalized properly.

### Part 2: SQL Query Implementation (25 marks)

Writing 20 SQL queries to retrieve and analyze data. Includes basic SELECT queries, JOINs, GROUP BY aggregations, and subqueries.

### Part 3: Data Integrity Audit (20 marks)

Writing audit queries to check if the data follows all the constraints. Detecting foreign key violations, duplicates, invalid values, and inconsistencies in the data.

### Part 4: Transactions & Reliability (25 marks)

Implementing transaction examples to show ACID properties, isolation levels, and handling edge cases like deadlocks.

## Files in This Assignment

### Part 1 Files
- `schema_explanation.md` - Analysis of the raw data and entities
- `keys_and_relationships.md` - Primary keys, foreign keys, and other constraints
- `normalization_notes.md` - Normalization analysis (1NF, 2NF, 3NF)
- `schema.sql` - The actual database schema in SQL
- `erd.md` - Entity relationship diagram
- `assumptions.md` - Design decisions and assumptions

### Part 2 Files
- `Part2_queries.sql` - 20 SQL queries
- `Part2_query_outputs.md` - Example results from running the queries
- `Part2_README.md` - Notes on the queries

### Part 3 Files
- `Part3_audit_queries.sql` - 59 audit queries for data validation
- `Part3_audit_report.md` - Results of the audit and issues found
- `Part3_README.md` - How to run the audit

### Part 4 Files
- `Part4_transactions.sql` - Transaction examples
- `Part4_reliability_report.md` - Analysis of reliability and ACID properties
- `Part4_README.md` - Explanation of transactions

### Supporting Files
- `DATA_DICTIONARY.md` - Explanation of the dataset
- `README_DATASET.md` - Where the data comes from
- `data/` - Folder with CSV files for the tables

## What I Analyzed

### The Data

The assignment gave us raw CSV files for a coding platform (CodeJudge). I identified 16 different entities:
- batches, courses, students, enrollments
- problems, test_cases, contests, contest_problems
- submissions, test_results
- sessions, attendance
- regrade_requests, plagiarism_flags
- raw_student_import, operation_requests

### Keys and Constraints

I set up:
- Primary keys on each table (mostly using surrogate keys like B001, S0001, etc.)
- Foreign key relationships between tables
- Unique constraints on candidate keys (like email, roll number)
- CHECK constraints to validate data (e.g., end time must be after start time)

### Normalization

Most tables are in 3NF, but with a few intentional denormalizations:
- `submissions.score` is stored even though it could be calculated from test_results
- `regrade_requests.student_id` is redundant but kept for validation

The normalization notes explain when and why these choices were made.

## Design Choices

### Primary Keys
Most tables use surrogate keys (like B001, S0001, etc.) instead of natural keys. This makes it easier to reference records and handle cases where business data might change.

### Relationships
- Most relationships are one-to-many (students have multiple enrollments, etc.)
- Student-course enrollment and contest-problem mappings are many-to-many, so I used bridge tables
- Contests in submissions is optional (nullable)

### Data Issues Found
While analyzing the data, I found some problems:
1. Contest CT005 had end_time before start_time - added a CHECK constraint
2. Contest CT008 referenced a non-existent course - FK constraint prevents this
3. Some plagiarism flags had self-references - added constraint to prevent that
4. One regrade request referenced a deleted submission - CASCADE delete fixes this
5. A few submissions had score inconsistencies - documented in the audit

### Delete Policies
- CASCADE: For things that logically depend on something else (if a student is deleted, their submissions go too)
- RESTRICT: For administrative data (can't delete a batch or contest if submissions reference it)
- SET NULL: For optional relationships (submissions can have no associated contest)

---

## How to Set Up

If you want to test this schema:
```bash
psql -U postgres -d codejudge -f schema.sql
```

That's it - it creates all the tables with the necessary constraints and indexes.

## What I Learned

Working through this assignment, I realized that good database design is about balancing competing concerns:
- Normalization helps avoid redundant data, but sometimes denormalization is worth it for performance
- Constraints catch bad data at the database level, not just in the application
- Choosing the right delete policy (cascade, restrict, set null) matters a lot for data safety

## File Organization

Since this is a 4-part assignment, each part has its own README file explaining what's in it. You can start with Part 1 to understand the schema, then move on to the other parts.

