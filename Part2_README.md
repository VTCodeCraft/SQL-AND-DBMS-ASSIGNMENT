# Part 2: SQL Query Implementation - README

## Overview

**Part 2** implements comprehensive SQL queries against the CodeJudge database schema (from Part 1). Queries demonstrate fundamental SQL concepts: basic retrieval, JOINs, aggregation, and subqueries/set logic.

---

## Files Included

### 1. **Part2_queries.sql**
Complete SQL query implementations (20 queries total) organized by category.

**Categories:**
- **Category 1:** Basic Retrieval (5 queries)
  - Query 1.1: Active students with batch
  - Query 1.2: Students missing email
  - Query 1.3: Easy/Medium problems
  - Query 1.4: Latest 20 submissions
  - Query 1.5: Failed submissions

- **Category 2:** JOIN Queries (5 queries)
  - Query 2.1: Full submission context
  - Query 2.2: Student enrollments with grades
  - Query 2.3: Courses with enrollment stats
  - Query 2.4: Test case results details
  - Query 2.5: Enrolled but never submitted

- **Category 3:** Aggregation & HAVING (5 queries)
  - Query 3.1: Submission status distribution
  - Query 3.2: Average score per problem
  - Query 3.3: Students with many submissions
  - Query 3.4: Low success rate problems
  - Query 3.5: Top attempted problems

- **Category 4:** Subqueries & Set Logic (5 queries)
  - Query 4.1: Students with above-average score
  - Query 4.2: Never-attempted problems
  - Query 4.3: Enrolled but inactive students
  - Query 4.4: Students using multiple languages
  - Query 4.5: Second-highest score per problem

### 2. **Part2_query_outputs.md**
Sample outputs, validation strategies, and expected results for each query.

**Contains:**
- Sample output tables for each query
- Data validation checklists
- Expected statistics and row counts
- Data quality observations
- Business insights from outputs
- Expected execution times
- Performance optimization tips
- Query efficiency analysis

### 3. **README.md** (This File)
Overview, usage guide, and assessment criteria.

---

## SQL Concepts Demonstrated

### Basic Retrieval (Queries 1.1 - 1.5)
- `SELECT` with column projection
- `WHERE` clause filtering
- `ORDER BY` and `LIMIT`
- `CASE` expressions for computed columns
- `IS NULL` / `IS NOT NULL` checks
- String literals and data formats

**Key Skills:**
- Selecting appropriate columns for business context
- Filtering by status, dates, and NULL values
- Ordering results for readability
- Computing display fields from raw data

---

### JOIN Queries (Queries 2.1 - 2.5)
- `INNER JOIN` (required relationships)
- `LEFT JOIN` (optional relationships)
- Multi-table JOINs (3+ tables)
- Join conditions on FK columns
- Composite row selection from multiple tables

**Key Skills:**
- Understanding when INNER vs LEFT JOIN applies
- Chaining multiple JOINs for complex queries
- Preserving row count with correct join strategy
- Joining on FK columns for referential integrity

---

### Aggregation (Queries 3.1 - 3.5)
- `GROUP BY` clause
- Aggregate functions: `COUNT()`, `AVG()`, `SUM()`, `MIN()`, `MAX()`
- `HAVING` clause for aggregate filtering
- Conditional aggregates with `CASE` in aggregation
- `DISTINCT` in aggregates
- Complex GROUP BY with multiple aggregates

**Key Skills:**
- Understanding GROUP BY semantics (all non-aggregated columns must be grouped)
- Using HAVING instead of WHERE for post-aggregation filtering
- Computing percentages and ratios
- CASE expressions inside aggregates for conditional counting

---

### Subqueries & Set Logic (Queries 4.1 - 4.5)
- Scalar subqueries (return single value)
- Correlated subqueries (reference outer query)
- `NOT EXISTS` subqueries
- Common Table Expressions (CTEs/WITH clause)
- Window functions (`RANK() OVER PARTITION BY`)

**Key Skills:**
- Understanding when subqueries vs JOINs are appropriate
- Correlated subqueries (performance consideration)
- NOT EXISTS for anti-joins
- Window functions for partitioned ranking

---

## Query Execution Guide

### Prerequisites
1. PostgreSQL database created
2. schema.sql executed (all 16 tables created)
3. CSV data imported into tables
4. Indexes created (automatic with DDL)

### Running Queries

**Option A: Execute All Queries**
```bash
psql -U postgres -d codejudge -f Part2_queries.sql
```

**Option B: Execute Individual Queries**
```bash
psql -U postgres -d codejudge <<EOF
-- Copy-paste single query from Part2_queries.sql
-- Example: Query 1.1
SELECT 
  s.student_id,
  s.roll_number,
  s.full_name,
  ...
FROM students s
WHERE s.enrollment_status = 'active'
ORDER BY ...;
EOF
```

**Option C: In psql Interactive Mode**
```bash
psql -U postgres -d codejudge

-- Then copy-paste queries one by one
\i Part2_queries.sql
```

### Verify Execution
```sql
-- Check if queries execute without error
-- Sample: Verify Query 1.1 returns data
SELECT COUNT(*) FROM (
  SELECT s.student_id FROM students s
  WHERE s.enrollment_status = 'active'
) AS active_students;
-- Should return ~250-300 (active students count)
```

---

## Expected Output Validation

### Data Volume (from sample CSV):
- Students: 320 total, ~250-280 active
- Submissions: 2500 total
- Test Results: ~9600+ total
- Enrollments: ~720 total
- Problems: 67 total, ~60 active
- Courses: 10 total

### Sample Output Volumes:
| Query | Expected Rows | Notes |
|-------|---------------|-------|
| 1.1 | ~250 | Active students |
| 1.2 | 1-5 | Students without email |
| 1.3 | 30-40 | Easy/Medium active problems |
| 1.4 | 20 | Limited to 20 recent |
| 1.5 | 500-800 | Failed submissions |
| 2.1 | 2500 | All submissions |
| 2.2 | 720+ | All enrollments |
| 2.3 | 10 | All courses |
| 2.4 | 9600+ | All test results |
| 2.5 | 10-30 | Never-submitted students |
| 3.1 | 8-9 | Status categories |
| 3.2 | 60+ | Problems with submissions |
| 3.3 | 200+ | Students with submissions |
| 3.4 | 5-10 | Problems with <30% success |
| 3.5 | 20 | Top 20 attempted |
| 4.1 | 40-80 | Above-average students |
| 4.2 | 5-15 | Never-attempted problems |
| 4.3 | 10-30 | Inactive but enrolled |
| 4.4 | 20-50 | Multi-language students |
| 4.5 | 50-60 | Second-place per problem |

---

## Business Insights from Queries

### Student Engagement (Queries 1.1, 2.5, 3.3, 4.3)
- Identify active vs dormant students
- Track submission frequency patterns
- Flag at-risk students for intervention
- Recognize high-performing students

### Problem Quality Assessment (Queries 1.3, 2.4, 3.2, 3.4, 3.5)
- Success rates indicate problem difficulty
- Failure analysis identifies problem quality issues
- Popularity shows engagement
- Error distribution reveals problem clarity issues

### Course Analytics (Queries 2.2, 2.3)
- Enrollment trends per course
- Grade distributions
- Course load balancing
- Prerequisite prerequisites recommendations

### Submission Patterns (Queries 1.4, 1.5, 3.1, 2.1)
- Overall platform health
- Language preferences
- Success rates over time
- Performance tracking

### Test Case Validation (Queries 2.4)
- Test case execution details
- Hidden vs public test performance
- Resource utilization (runtime, memory)
- Test case efficiency

---

## Assessment Criteria (25 marks)

| Criterion | Marks | Verification |
|-----------|-------|--------------|
| Query Design & Correctness | 8 | Each query runs without error, returns expected output |
| SQL Concepts (JOINs, GROUP BY, aggregates) | 6 | Proper use of SQL constructs demonstrated |
| Business Logic Implementation | 6 | Queries answer business questions correctly |
| Output Validation & Documentation | 3 | Sample outputs provided, validated against expectations |
| Performance Optimization | 2 | Indexes used, efficient query patterns |
| **TOTAL** | **25** | **All queries tested & validated** |

---

## Common Issues & Troubleshooting

### Issue 1: Queries Return 0 Rows
**Cause:** Schema not created or data not imported
**Solution:**
```bash
# Verify tables exist
psql -U postgres -d codejudge -c "\dt"
# Should show 16 tables

# Verify data imported
psql -U postgres -d codejudge -c "SELECT COUNT(*) FROM students;"
# Should show 320
```

### Issue 2: Column Not Found Error
**Cause:** Table/column name mismatch (case sensitivity)
**Solution:**
```bash
# Check table schema
psql -U postgres -d codejudge -c "\d students"
# Verify column names match exactly
```

### Issue 3: Foreign Key Violations
**Cause:** Data quality issues or constraint violations
**Solution:**
```bash
# Test foreign key integrity
SELECT * FROM submissions WHERE problem_id NOT IN (SELECT problem_id FROM problems);
-- Should return 0 rows

# If violations found, review schema_explanation.md for known issues
```

### Issue 4: Slow Query Execution
**Cause:** Missing indexes or complex query logic
**Solution:**
```bash
# Use EXPLAIN ANALYZE to inspect query plan
EXPLAIN ANALYZE SELECT ...;

# Create missing indexes
CREATE INDEX idx_submissions_student_id ON submissions(student_id);

# Simplify complex subqueries to JOINs
```

---

## Query Examples for Each SQL Concept

### Concept: INNER vs LEFT JOIN
```sql
-- INNER JOIN (only matching rows)
SELECT s.student_id, c.course_code
FROM students s
INNER JOIN enrollments e ON s.student_id = e.student_id
INNER JOIN courses c ON e.course_id = c.course_id;
-- Result: Only students with enrollments

-- LEFT JOIN (all rows from left table, NULL for non-matching right)
SELECT s.student_id, COUNT(DISTINCT e.enrollment_id) AS courses
FROM students s
LEFT JOIN enrollments e ON s.student_id = e.student_id
GROUP BY s.student_id;
-- Result: All students, even those with 0 enrollments
```

### Concept: GROUP BY with HAVING
```sql
-- GROUP BY aggregates rows
SELECT problem_id, COUNT(*) AS submission_count
FROM submissions
GROUP BY problem_id;
-- Result: One row per problem with count

-- HAVING filters aggregated results (not WHERE!)
SELECT problem_id, COUNT(*) AS submission_count
FROM submissions
GROUP BY problem_id
HAVING COUNT(*) > 10;
-- Result: Only problems with >10 submissions
```

### Concept: NOT EXISTS
```sql
-- Find students with no submissions
SELECT s.student_id
FROM students s
WHERE NOT EXISTS (
  SELECT 1 FROM submissions WHERE student_id = s.student_id
);
-- Result: Students never submitted

-- Alternative with LEFT JOIN (shows same result)
SELECT s.student_id
FROM students s
LEFT JOIN submissions sub ON s.student_id = sub.student_id
WHERE sub.submission_id IS NULL;
```

### Concept: Window Functions
```sql
-- Rank submissions per problem by score
SELECT 
  submission_id,
  problem_id,
  score,
  RANK() OVER (PARTITION BY problem_id ORDER BY score DESC) AS rank
FROM submissions;
-- Result: Each submission's rank within its problem
```

---

## Next Steps: Part 3

After completing Part 2 queries:
- Verify all 20 queries execute successfully
- Validate output against expected results
- Note any data quality issues discovered
- Proceed to **Part 3: Data Integrity Audit**

---

## Key Takeaways

### From Query Design
- ✓ Understand entity relationships before writing joins
- ✓ INNER JOIN: both sides must match; LEFT JOIN: keep all from left
- ✓ GROUP BY: all non-aggregated columns must be grouped
- ✓ HAVING: filters on aggregates; WHERE: filters on row values

### From Business Logic
- ✓ Queries should answer specific business questions
- ✓ Aggregate functions reveal patterns (success rates, engagement)
- ✓ Subqueries useful for comparisons (above average, missing data)
- ✓ Data quality visible through query results (NULLs, inconsistencies)

### From Performance
- ✓ Indexes on FK, status, timestamps critical
- ✓ Correlated subqueries slow; prefer JOINs where possible
- ✓ LIMIT useful for pagination on large result sets
- ✓ EXPLAIN ANALYZE reveals optimization opportunities

---

## Summary

**Part 2 Deliverables:**
✓ 20 comprehensive SQL queries (Part2_queries.sql)
✓ Sample outputs and validation (Part2_query_outputs.md)
✓ Documentation and usage guide (this README)

**Covers:**
✓ Basic retrieval, filtering, ordering
✓ INNER/LEFT JOINs, multi-table queries
✓ GROUP BY, aggregates, HAVING filtering
✓ Subqueries, CTEs, window functions

**Demonstrates:**
✓ SQL fundamentals and best practices
✓ Real-world business logic implementation
✓ Data quality and integrity insights
✓ Performance optimization awareness

---

## Author Notes

These queries are designed to be:
1. **Executable** — Copy and paste into psql
2. **Educational** — Demonstrate SQL concepts
3. **Practical** — Answer real business questions
4. **Documented** — Comments explain intent and logic
5. **Realistic** — Based on actual CodeJudge platform needs

Each query builds on the schema design from Part 1, validating that the normalized structure supports efficient, flexible querying of the system.

