# Part 2: SQL Query Implementation

## Overview

This section contains SQL queries implementing business logic for the CodeJudge platform. Queries are organized by category: Basic Retrieval, JOINs, Aggregation, and Subqueries/Set Logic.

**Important:** All queries assume schema.sql has been executed and data has been imported from CSVs.

---

## Category 1: Basic Retrieval Queries

### Query 1.1: Active Students with Current Batch Info
**Purpose:** Retrieve all active students with their batch information.

```sql
-- Retrieve active students with batch details
-- Shows students currently participating in the platform
-- Useful for: Class rosters, active user reports, communication lists
SELECT 
  s.student_id,
  s.roll_number,
  s.full_name,
  s.email,
  b.batch_id,
  b.batch_code,
  b.program,
  s.admission_date,
  s.graduation_year
FROM students s
INNER JOIN batches b ON s.batch_id = b.batch_id
WHERE s.enrollment_status = 'active'
ORDER BY b.batch_code, s.roll_number;
```

**Expected Output Sample:**
```
student_id | roll_number | full_name      | email                          | batch_id | batch_code  | program         | admission_date | graduation_year
S0001      | CJ250001    | Vivaan Gupta   | vivaan.gupta001@codejudge.edu  | B002     | CSE2025B    | B.Tech AIML     | 2025-02-13    | 2025
S0004      | CJ250004    | Ananya Bose    | ananya.bose004@codejudge.edu   | B003     | BCA         | BCA             | 2025-02-19    | 2026
```

**Key Considerations:**
- Filters only active students (excludes inactive, graduated, suspended)
- INNER JOIN ensures only students with existing batch_id
- Ordered by batch for easy grouping
- Output useful for class lists and communication

---

### Query 1.2: Students with Missing Email Addresses
**Purpose:** Identify students without email addresses in the system.

```sql
-- Find students without registered email addresses
-- Useful for: Email verification campaigns, contact info completion tasks
SELECT 
  s.student_id,
  s.roll_number,
  s.full_name,
  b.batch_code,
  s.admission_date,
  s.enrollment_status
FROM students s
INNER JOIN batches b ON s.batch_id = b.batch_id
WHERE s.email IS NULL
ORDER BY b.batch_code, s.roll_number;
```

**Expected Output Sample:**
```
student_id | roll_number | full_name     | batch_code | admission_date | enrollment_status
S0005      | CJ250005    | Ayaan Gupta   | MCA2025A   | 2025-01-27    | active
```

**Key Considerations:**
- WHERE clause uses IS NULL (proper NULL handling)
- Identifies potential data quality gaps
- Email is NULLABLE in design (not a constraint violation)

---

### Query 1.3: Easy and Medium Difficulty Problems
**Purpose:** Retrieve all problems at Easy or Medium difficulty levels.

```sql
-- Get problems by difficulty level
-- Useful for: Curated problem lists, beginner practice tracks
SELECT 
  p.problem_id,
  p.problem_code,
  p.title,
  p.difficulty,
  p.max_score,
  c.course_code,
  c.course_title,
  CASE WHEN p.is_active = 1 THEN 'Active' ELSE 'Inactive' END AS status,
  p.created_at
FROM problems p
INNER JOIN courses c ON p.course_id = c.course_id
WHERE p.difficulty IN ('Easy', 'Medium')
  AND p.is_active = 1
ORDER BY p.difficulty, p.created_at DESC;
```

**Expected Output Sample:**
```
problem_id | problem_code | title                      | difficulty | max_score | course_code | course_title              | status | created_at
P0002      | CS101_P02    | Dynamic Programming Basics | Easy       | 50        | CS101       | Programming Fundamentals | Active | 2025-04-08
P0005      | CS101_P05    | Queue using Stacks         | Easy       | 50        | CS101       | Programming Fundamentals | Active | 2025-04-03
```

**Key Considerations:**
- Filters by difficulty level (Easy, Medium)
- Only includes active problems (is_active=1)
- CASE statement converts numeric is_active to readable status
- Ordered by difficulty then recency

---

### Query 1.4: Latest 20 Submissions
**Purpose:** Retrieve the 20 most recent code submissions.

```sql
-- Get recent submissions with student and problem info
-- Useful for: Activity feeds, submission monitoring, debugging
SELECT 
  sub.submission_id,
  s.student_id,
  s.roll_number,
  s.full_name,
  p.problem_code,
  p.title,
  sub.language,
  sub.submitted_at,
  sub.status,
  sub.score,
  sub.runtime_ms,
  CASE WHEN sub.contest_id IS NOT NULL THEN 'Contest' ELSE 'Practice' END AS submission_type
FROM submissions sub
INNER JOIN students s ON sub.student_id = s.student_id
INNER JOIN problems p ON sub.problem_id = p.problem_id
ORDER BY sub.submitted_at DESC
LIMIT 20;
```

**Expected Output Sample:**
```
submission_id | student_id | roll_number | full_name      | problem_code | title                  | language | submitted_at        | status           | score | runtime_ms | submission_type
SUB000009     | S0117      | CJ250117    | (Student Name) | CS102_P02    | Dynamic Programming... | C++      | 2025-04-23 20:24:00 | Accepted         | 50    | 4428       | Contest
SUB000008     | S0196      | CJ250196    | (Student Name) | CS101_P11    | Problem Title          | Java     | 2025-02-08 10:22:00 | Compilation Error| 0     | 992        | Practice
```

**Key Considerations:**
- Uses LIMIT 20 for pagination
- Includes submission type (contest vs practice)
- Ordered by most recent first (DESC)
- Joins retrieve human-readable names

---

### Query 1.5: Failed Submissions (Wrong Answer, Compilation Error, Runtime Error)
**Purpose:** Identify all failed submissions for debugging and support.

```sql
-- Get failed submissions (not accepted)
-- Useful for: Debugging reports, support tickets, student help
SELECT 
  sub.submission_id,
  s.student_id,
  s.roll_number,
  s.full_name,
  p.problem_code,
  p.title,
  sub.language,
  sub.submitted_at,
  sub.status,
  sub.score,
  COUNT(DISTINCT tr.result_id) AS test_cases_run,
  SUM(CASE WHEN tr.result_status = 'Passed' THEN 1 ELSE 0 END) AS passed_tests
FROM submissions sub
INNER JOIN students s ON sub.student_id = s.student_id
INNER JOIN problems p ON sub.problem_id = p.problem_id
LEFT JOIN test_results tr ON sub.submission_id = tr.submission_id
WHERE sub.status IN ('Wrong Answer', 'Compilation Error', 'Runtime Error', 'Time Limit Exceeded')
GROUP BY sub.submission_id, s.student_id, s.roll_number, s.full_name, 
         p.problem_code, p.title, sub.language, sub.submitted_at, sub.status, sub.score
ORDER BY sub.submitted_at DESC;
```

**Expected Output Sample:**
```
submission_id | student_id | roll_number | full_name      | problem_code | title               | language | submitted_at        | status            | score | test_cases_run | passed_tests
SUB000001     | S0282      | CJ250282    | (Student Name) | CS101_P43    | Problem Title       | C        | 2025-05-14 13:48:00 | Wrong Answer      | 46    | 5              | 1
SUB000007     | S0248      | CJ250248    | (Student Name) | CS102_P23    | Problem Title       | Python   | 2025-05-06 22:44:00 | Wrong Answer      | 6     | 1              | 0
```

**Key Considerations:**
- Filters for non-accepted statuses
- LEFT JOIN test_results (some might have 0 results)
- Aggregates test case pass/fail counts
- Useful for identifying struggling students

---

## Category 2: JOIN Queries

### Query 2.1: Submissions with Student, Problem, and Contest Details
**Purpose:** Complete submission view with all related information.

```sql
-- Full submission detail view
-- Shows student submission with problem context and contest participation
-- Useful for: Submission review, contest analysis, performance tracking
SELECT 
  sub.submission_id,
  s.student_id,
  s.roll_number,
  s.full_name,
  e.enrollment_id,
  c.course_code,
  c.course_title,
  p.problem_code,
  p.title AS problem_title,
  p.difficulty,
  p.max_score,
  ct.contest_id,
  ct.contest_title,
  sub.language,
  sub.submitted_at,
  CASE 
    WHEN sub.status = 'Accepted' THEN 'Pass'
    WHEN sub.status IN ('Wrong Answer', 'Runtime Error', 'Compilation Error', 'Time Limit Exceeded') THEN 'Fail'
    ELSE 'Partial'
  END AS result_category,
  sub.status,
  sub.score,
  ROUND((sub.score::DECIMAL / NULLIF(p.max_score, 0)) * 100, 2) AS score_percentage,
  sub.runtime_ms
FROM submissions sub
INNER JOIN students s ON sub.student_id = s.student_id
INNER JOIN problems p ON sub.problem_id = p.problem_id
INNER JOIN courses c ON p.course_id = c.course_id
LEFT JOIN enrollments e ON s.student_id = e.student_id AND c.course_id = e.course_id
LEFT JOIN contests ct ON sub.contest_id = ct.contest_id
ORDER BY sub.submitted_at DESC;
```

**Key Considerations:**
- Multiple JOINs integrate submission context (student, problem, course, contest)
- LEFT JOINs for optional relationships (not all courses have enrollments, contests)
- Computed score percentage for quick performance assessment
- Result category derived from status

---

### Query 2.2: Students and Course Enrollments with Grades
**Purpose:** View student enrollment status and grades in courses.

```sql
-- Student enrollments with course details and grades
-- Shows each student's course progress
-- Useful for: Grade reports, course load tracking, enrollment audits
SELECT 
  e.enrollment_id,
  s.student_id,
  s.roll_number,
  s.full_name,
  c.course_id,
  c.course_code,
  c.course_title,
  c.credit_hours,
  e.enrolled_on,
  e.enrollment_status,
  e.final_grade,
  CASE 
    WHEN e.enrollment_status = 'active' THEN 'Ongoing'
    WHEN e.enrollment_status = 'completed' AND e.final_grade IS NOT NULL THEN 'Completed: ' || e.final_grade
    WHEN e.enrollment_status = 'dropped' THEN 'Dropped'
    ELSE 'Other'
  END AS enrollment_status_display,
  AGE(CURRENT_DATE, e.enrolled_on) AS enrollment_duration
FROM enrollments e
INNER JOIN students s ON e.student_id = s.student_id
INNER JOIN courses c ON e.course_id = c.course_id
WHERE s.enrollment_status = 'active'
ORDER BY s.roll_number, c.course_code;
```

**Key Considerations:**
- Shows only active students' enrollments
- CASE statement provides readable status
- AGE() function shows enrollment duration
- Useful for tracking course progress

---

### Query 2.3: Courses with Enrolled Student Count
**Purpose:** Aggregate enrollment statistics per course.

```sql
-- Course enrollment statistics
-- Shows how many students are enrolled in each course
-- Useful for: Course popularity, load balancing, resource allocation
SELECT 
  c.course_id,
  c.course_code,
  c.course_title,
  c.course_status,
  c.credit_hours,
  COUNT(DISTINCT e.enrollment_id) AS total_enrollments,
  COUNT(DISTINCT CASE WHEN e.enrollment_status = 'active' THEN e.enrollment_id END) AS active_enrollments,
  COUNT(DISTINCT CASE WHEN e.enrollment_status = 'completed' THEN e.enrollment_id END) AS completed_enrollments,
  COUNT(DISTINCT CASE WHEN e.enrollment_status = 'dropped' THEN e.enrollment_id END) AS dropped_enrollments,
  COUNT(DISTINCT CASE WHEN e.final_grade IN ('A', 'B') THEN e.enrollment_id END) AS high_performers,
  COUNT(DISTINCT CASE WHEN e.final_grade = 'F' THEN e.enrollment_id END) AS failures,
  ROUND(COUNT(DISTINCT CASE WHEN e.final_grade = 'F' THEN e.enrollment_id END)::DECIMAL 
        / NULLIF(COUNT(DISTINCT CASE WHEN e.enrollment_status = 'completed' THEN e.enrollment_id END), 0) * 100, 2) AS failure_rate_percent
FROM courses c
LEFT JOIN enrollments e ON c.course_id = e.course_id
GROUP BY c.course_id, c.course_code, c.course_title, c.course_status, c.credit_hours
ORDER BY total_enrollments DESC;
```

**Key Considerations:**
- LEFT JOIN allows courses with 0 enrollments to show
- Multiple conditional COUNTs aggregate enrollment states
- Calculates failure rate (useful for course quality)
- Ordered by enrollment count (most popular first)

---

### Query 2.4: Test Case Results with Submission and Problem Info
**Purpose:** Detailed test case execution results.

```sql
-- Test results with full context
-- Each test case run for each submission
-- Useful for: Debugging, test case analysis, quality metrics
SELECT 
  tr.result_id,
  sub.submission_id,
  s.student_id,
  s.roll_number,
  s.full_name,
  p.problem_code,
  p.title,
  tc.case_no,
  CASE WHEN tc.is_hidden = 1 THEN 'Hidden' ELSE 'Public' END AS test_visibility,
  tc.points AS max_points,
  tr.result_status,
  tr.awarded_points,
  CASE 
    WHEN tr.result_status = 'Passed' THEN '✓ Pass'
    WHEN tr.result_status = 'Failed' THEN '✗ Fail'
    WHEN tr.result_status = 'Runtime Error' THEN '⚠ Runtime Error'
    WHEN tr.result_status = 'Time Limit Exceeded' THEN '⏱ TLE'
    ELSE '? ' || tr.result_status
  END AS result_display,
  tr.runtime_ms,
  tr.memory_kb,
  sub.submitted_at
FROM test_results tr
INNER JOIN submissions sub ON tr.submission_id = sub.submission_id
INNER JOIN students s ON sub.student_id = s.student_id
INNER JOIN problems p ON sub.problem_id = p.problem_id
INNER JOIN test_cases tc ON tr.test_case_id = tc.test_case_id
ORDER BY sub.submitted_at DESC, tc.case_no;
```

**Key Considerations:**
- Shows which test cases passed/failed
- Visibility status shows public vs hidden tests
- Symbolic result display for quick scanning
- Includes performance metrics (runtime, memory)

---

### Query 2.5: Students Enrolled but Never Submitted
**Purpose:** Identify disengaged students who haven't submitted any solutions.

```sql
-- Enrolled students with NO submissions
-- Identifies students who haven't started working on problems
-- Useful for: Student engagement tracking, intervention planning
SELECT 
  s.student_id,
  s.roll_number,
  s.full_name,
  s.email,
  b.batch_code,
  COUNT(DISTINCT e.enrollment_id) AS courses_enrolled,
  MIN(e.enrolled_on) AS first_enrollment_date,
  CAST(CURRENT_DATE - MAX(e.enrolled_on) AS INTEGER) AS days_since_last_enrollment,
  COUNT(DISTINCT sub.submission_id) AS total_submissions
FROM students s
INNER JOIN batches b ON s.batch_id = b.batch_id
INNER JOIN enrollments e ON s.student_id = e.student_id
LEFT JOIN submissions sub ON s.student_id = sub.student_id
WHERE e.enrollment_status IN ('active', 'completed')
GROUP BY s.student_id, s.roll_number, s.full_name, s.email, b.batch_code
HAVING COUNT(DISTINCT sub.submission_id) = 0
ORDER BY MAX(e.enrolled_on) DESC;
```

**Key Considerations:**
- LEFT JOIN submissions (returns 0 count for non-matching)
- HAVING clause filters for students with NO submissions
- Shows enrollment history and potential inactivity
- Useful for identifying at-risk students

---

## Category 3: Aggregation & HAVING Queries

### Query 3.1: Submissions Grouped by Status with Counts
**Purpose:** Summary of submission outcomes.

```sql
-- Submission status distribution
-- Shows breakdown of how submissions performed
-- Useful for: Platform health metrics, quality assessment
SELECT 
  sub.status,
  COUNT(sub.submission_id) AS submission_count,
  COUNT(DISTINCT sub.student_id) AS unique_students,
  ROUND(AVG(sub.score), 2) AS avg_score,
  MIN(sub.score) AS min_score,
  MAX(sub.score) AS max_score,
  ROUND(COUNT(sub.submission_id)::DECIMAL / (SELECT COUNT(*) FROM submissions) * 100, 2) AS percentage_of_total
FROM submissions sub
GROUP BY sub.status
ORDER BY submission_count DESC;
```

**Expected Output Sample:**
```
status              | submission_count | unique_students | avg_score | min_score | max_score | percentage_of_total
Wrong Answer        | 650              | 180             | 18.5      | 0         | 49        | 26.0
Accepted            | 580              | 175             | 50.0      | 50        | 50        | 23.2
Compilation Error   | 420              | 120             | 0.0       | 0         | 0         | 16.8
```

**Key Considerations:**
- GROUP BY status aggregates all submissions
- Shows distribution and quality metrics
- Percentage calculation relative to total submissions
- Helps identify problem areas (too many compilation errors?)

---

### Query 3.2: Average Score per Problem
**Purpose:** Problem difficulty assessment based on student performance.

```sql
-- Average score per problem - performance indicator
-- Shows how well students perform on each problem
-- Useful for: Problem calibration, difficulty assessment, success rate tracking
SELECT 
  p.problem_id,
  p.problem_code,
  p.title,
  p.difficulty,
  p.max_score,
  c.course_code,
  COUNT(DISTINCT sub.submission_id) AS submission_count,
  COUNT(DISTINCT sub.student_id) AS unique_students,
  ROUND(AVG(sub.score), 2) AS avg_score,
  ROUND(AVG(sub.score)::DECIMAL / NULLIF(p.max_score, 0) * 100, 2) AS success_rate_percent,
  COUNT(CASE WHEN sub.status = 'Accepted' THEN 1 END) AS accepted_count,
  ROUND(COUNT(CASE WHEN sub.status = 'Accepted' THEN 1 END)::DECIMAL / NULLIF(COUNT(sub.submission_id), 0) * 100, 2) AS acceptance_rate_percent
FROM problems p
LEFT JOIN submissions sub ON p.problem_id = sub.problem_id
LEFT JOIN courses c ON p.course_id = c.course_id
GROUP BY p.problem_id, p.problem_code, p.title, p.difficulty, p.max_score, c.course_code
HAVING COUNT(DISTINCT sub.submission_id) > 0  -- Only problems with submissions
ORDER BY success_rate_percent DESC;
```

**Expected Output Sample:**
```
problem_code | title                  | difficulty | max_score | submission_count | avg_score | success_rate_percent | acceptance_rate_percent
CS101_P02    | Easy Problem           | Easy       | 50        | 120              | 48.5      | 97.0                 | 95.0
CS102_P01    | Medium Problem         | Medium     | 75        | 95               | 42.3      | 56.4                 | 45.3
CS201_P05    | Hard Problem           | Hard       | 100       | 30               | 15.7      | 15.7                 | 3.3
```

**Key Considerations:**
- LEFT JOINs show problems even with no submissions
- HAVING filters for only problems with data
- Success rate shows average score percentage
- Acceptance rate shows % of students who fully solved
- Useful for identifying too-easy or too-hard problems

---

### Query 3.3: Students with Many Submissions
**Purpose:** Identify prolific or struggling students based on submission frequency.

```sql
-- Students by submission frequency
-- Shows submission patterns (high volume = practice-focused or struggling)
-- Useful for: Student engagement profiles, workload tracking
SELECT 
  s.student_id,
  s.roll_number,
  s.full_name,
  COUNT(DISTINCT sub.submission_id) AS total_submissions,
  COUNT(DISTINCT CASE WHEN sub.status = 'Accepted' THEN sub.submission_id END) AS accepted_submissions,
  COUNT(DISTINCT CASE WHEN sub.status IN ('Wrong Answer', 'Runtime Error', 'Compilation Error') THEN sub.submission_id END) AS failed_submissions,
  ROUND(COUNT(DISTINCT CASE WHEN sub.status = 'Accepted' THEN sub.submission_id END)::DECIMAL / NULLIF(COUNT(DISTINCT sub.submission_id), 0) * 100, 2) AS acceptance_rate_percent,
  COUNT(DISTINCT sub.problem_id) AS unique_problems_attempted,
  MIN(sub.submitted_at) AS first_submission,
  MAX(sub.submitted_at) AS last_submission,
  CAST(MAX(sub.submitted_at) - MIN(sub.submitted_at) AS INTERVAL) AS submission_span
FROM students s
LEFT JOIN submissions sub ON s.student_id = sub.student_id
WHERE s.enrollment_status = 'active'
GROUP BY s.student_id, s.roll_number, s.full_name
HAVING COUNT(DISTINCT sub.submission_id) > 0  -- Only students with submissions
ORDER BY COUNT(DISTINCT sub.submission_id) DESC;
```

**Expected Output Sample:**
```
student_id | roll_number | full_name      | total_submissions | accepted_submissions | failed_submissions | acceptance_rate_percent | unique_problems_attempted
S0123      | CJ250123    | Diligent Dev   | 156              | 145                  | 11                 | 92.9                    | 48
S0045      | CJ250045    | Practice Pro   | 89               | 76                   | 13                 | 85.4                    | 32
```

**Key Considerations:**
- LEFT JOIN allows inactive students to show as 0 submissions
- Calculates acceptance rate and problem diversity
- Shows submission timeline (span from first to last)
- Helps identify engagement patterns (active vs dormant)

---

### Query 3.4: Low Success Rate Problems
**Purpose:** Identify problems students struggle with most.

```sql
-- Problems with low success rates
-- Identifies problematic or poorly-designed problems
-- Useful for: Problem remediation, difficulty calibration
SELECT 
  p.problem_id,
  p.problem_code,
  p.title,
  p.difficulty,
  p.max_score,
  c.course_code,
  COUNT(DISTINCT sub.submission_id) AS total_attempts,
  COUNT(DISTINCT CASE WHEN sub.status = 'Accepted' THEN sub.submission_id END) AS successful_attempts,
  ROUND(COUNT(DISTINCT CASE WHEN sub.status = 'Accepted' THEN sub.submission_id END)::DECIMAL / NULLIF(COUNT(DISTINCT sub.submission_id), 0) * 100, 2) AS success_rate,
  COUNT(DISTINCT CASE WHEN sub.status = 'Compilation Error' THEN sub.submission_id END) AS compilation_errors,
  COUNT(DISTINCT CASE WHEN sub.status = 'Runtime Error' THEN sub.submission_id END) AS runtime_errors,
  COUNT(DISTINCT CASE WHEN sub.status = 'Wrong Answer' THEN sub.submission_id END) AS wrong_answer_count,
  COUNT(DISTINCT CASE WHEN sub.status = 'Time Limit Exceeded' THEN sub.submission_id END) AS timeout_count
FROM problems p
LEFT JOIN submissions sub ON p.problem_id = sub.problem_id
LEFT JOIN courses c ON p.course_id = c.course_id
WHERE p.is_active = 1
GROUP BY p.problem_id, p.problem_code, p.title, p.difficulty, p.max_score, c.course_code
HAVING COUNT(DISTINCT sub.submission_id) >= 10  -- Minimum attempt threshold
  AND ROUND(COUNT(DISTINCT CASE WHEN sub.status = 'Accepted' THEN sub.submission_id END)::DECIMAL / NULLIF(COUNT(DISTINCT sub.submission_id), 0) * 100, 2) < 30
ORDER BY success_rate ASC;
```

**Expected Output Sample:**
```
problem_code | title                | difficulty | success_rate | total_attempts | compilation_errors | runtime_errors | wrong_answer_count
CS201_P08    | Complex Algorithm    | Hard       | 12.5         | 56             | 8                  | 15             | 28
CS102_P15    | Edge Cases Problem   | Medium     | 18.3         | 44             | 3                  | 12             | 22
```

**Key Considerations:**
- Filters for problems with minimum attempts (≥10) to avoid noise
- Identifies low success rate problems (< 30%)
- Breaks down error types for diagnosis
- Compilation errors might indicate unclear problem statement
- High runtime errors might indicate test case timeout issues

---

### Query 3.5: Top Attempted Problems
**Purpose:** Identify most popular/attempted problems.

```sql
-- Most attempted problems
-- Shows which problems students engage with most
-- Useful for: Content popularity, resource allocation
SELECT 
  p.problem_id,
  p.problem_code,
  p.title,
  p.difficulty,
  c.course_code,
  COUNT(DISTINCT sub.submission_id) AS submission_count,
  COUNT(DISTINCT sub.student_id) AS unique_students_attempted,
  COUNT(DISTINCT CASE WHEN sub.status = 'Accepted' THEN sub.student_id END) AS students_solved,
  ROUND(COUNT(DISTINCT CASE WHEN sub.status = 'Accepted' THEN sub.student_id END)::DECIMAL / NULLIF(COUNT(DISTINCT sub.student_id), 0) * 100, 2) AS percent_students_solved,
  AVG(sub.score) AS avg_score,
  ROUND(AVG(sub.score)::DECIMAL / NULLIF(p.max_score, 0) * 100, 2) AS avg_score_percent
FROM problems p
LEFT JOIN submissions sub ON p.problem_id = sub.problem_id
LEFT JOIN courses c ON p.course_id = c.course_id
WHERE p.is_active = 1
GROUP BY p.problem_id, p.problem_code, p.title, p.difficulty, c.course_code, p.max_score
ORDER BY submission_count DESC
LIMIT 20;
```

**Expected Output Sample:**
```
problem_code | title                      | difficulty | submission_count | unique_students_attempted | students_solved | percent_students_solved
CS101_P01    | Programming Fundamentals   | Easy       | 245              | 178                      | 165             | 92.7
CS101_P05    | Queue using Stacks         | Easy       | 198              | 145                      | 132             | 91.0
```

**Key Considerations:**
- Shows engagement (how many submissions)
- Shows diversity (how many unique students)
- Shows difficulty (what % actually solve it)
- Useful for curriculum planning

---

## Category 4: Subqueries & Set Logic Queries

### Query 4.1: Students with Above-Average Score
**Purpose:** Identify high-performing students.

```sql
-- Students scoring above the platform average
-- Identifies top performers for recognition/mentorship
-- Useful for: Performance reports, honors identification
SELECT 
  s.student_id,
  s.roll_number,
  s.full_name,
  (SELECT AVG(score) FROM submissions WHERE student_id = s.student_id) AS student_avg_score,
  (SELECT COUNT(*) FROM submissions WHERE student_id = s.student_id) AS total_submissions,
  (SELECT AVG(score) FROM submissions) AS platform_avg_score
FROM students s
WHERE (SELECT AVG(score) FROM submissions WHERE student_id = s.student_id) > (SELECT AVG(score) FROM submissions)
  AND s.enrollment_status = 'active'
ORDER BY student_avg_score DESC;
```

**Key Considerations:**
- Subquery calculates platform-wide average
- Correlated subquery calculates per-student average
- Multiple lookups for context (total submissions, platform avg)
- Could be optimized with a JOIN, but shows subquery technique

---

### Query 4.2: Never-Attempted Problems
**Purpose:** Find problems with no student submissions.

```sql
-- Problems that no student has attempted
-- Identifies unused/archived problems or new additions
-- Useful for: Content cleanup, curriculum review
SELECT 
  p.problem_id,
  p.problem_code,
  p.title,
  p.difficulty,
  p.max_score,
  c.course_code,
  c.course_title,
  CASE WHEN p.is_active = 1 THEN 'Active' ELSE 'Inactive' END AS status,
  p.created_at
FROM problems p
INNER JOIN courses c ON p.course_id = c.course_id
WHERE NOT EXISTS (
  SELECT 1 FROM submissions WHERE problem_id = p.problem_id
)
ORDER BY p.created_at DESC;
```

**Key Considerations:**
- NOT EXISTS (efficient way to find non-matching records)
- Identifies both recently created and orphaned problems
- Useful for identifying outdated content

---

### Query 4.3: Enrolled But Inactive Students
**Purpose:** Find students who are enrolled but haven't engaged.

```sql
-- Students enrolled in courses but with low submission activity
-- Identifies at-risk or disengaged students
-- Useful for: Student success intervention
SELECT 
  s.student_id,
  s.roll_number,
  s.full_name,
  s.email,
  b.batch_code,
  COUNT(DISTINCT e.enrollment_id) AS courses_enrolled,
  COALESCE(COUNT(DISTINCT sub.submission_id), 0) AS total_submissions,
  CASE 
    WHEN COUNT(DISTINCT sub.submission_id) IS NULL OR COUNT(DISTINCT sub.submission_id) = 0 THEN 'No Activity'
    WHEN COUNT(DISTINCT sub.submission_id) < 5 THEN 'Minimal Activity'
    ELSE 'Active'
  END AS engagement_level,
  MAX(sub.submitted_at) AS last_submission_date,
  CASE 
    WHEN MAX(sub.submitted_at) IS NULL THEN 'Never'
    ELSE CAST(CURRENT_DATE - DATE(MAX(sub.submitted_at)) AS VARCHAR) || ' days ago'
  END AS last_activity
FROM students s
INNER JOIN batches b ON s.batch_id = b.batch_id
INNER JOIN enrollments e ON s.student_id = e.student_id
LEFT JOIN submissions sub ON s.student_id = sub.student_id
WHERE e.enrollment_status IN ('active', 'completed')
GROUP BY s.student_id, s.roll_number, s.full_name, s.email, b.batch_code
HAVING COUNT(DISTINCT sub.submission_id) < 5 OR COUNT(DISTINCT sub.submission_id) IS NULL
ORDER BY total_submissions ASC, last_submission_date DESC NULLS LAST;
```

**Key Considerations:**
- COALESCE handles NULL counts
- Calculates engagement level based on thresholds
- Shows time since last activity
- Useful for identifying at-risk students early

---

### Query 4.4: Students Using Multiple Languages
**Purpose:** Find students who use different programming languages.

```sql
-- Students using both Python and Java
-- Identifies versatile or multilingual programmers
-- Useful for: Language proficiency tracking, curriculum alignment
SELECT 
  s.student_id,
  s.roll_number,
  s.full_name,
  STRING_AGG(DISTINCT sub.language, ', ' ORDER BY sub.language) AS languages_used,
  COUNT(DISTINCT sub.language) AS language_count,
  COUNT(DISTINCT CASE WHEN sub.language = 'Python' THEN sub.submission_id END) AS python_submissions,
  COUNT(DISTINCT CASE WHEN sub.language = 'Java' THEN sub.submission_id END) AS java_submissions,
  COUNT(DISTINCT CASE WHEN sub.language = 'C++' THEN sub.submission_id END) AS cpp_submissions,
  COUNT(DISTINCT sub.submission_id) AS total_submissions
FROM students s
LEFT JOIN submissions sub ON s.student_id = sub.student_id
WHERE s.enrollment_status = 'active'
GROUP BY s.student_id, s.roll_number, s.full_name
HAVING COUNT(DISTINCT sub.language) >= 2  -- At least 2 languages
ORDER BY COUNT(DISTINCT sub.language) DESC, COUNT(DISTINCT sub.submission_id) DESC;
```

**Expected Output Sample:**
```
student_id | roll_number | full_name      | languages_used           | language_count | python_submissions | java_submissions | cpp_submissions | total_submissions
S0089      | CJ250089    | Polyglot Pro   | C++, Java, Python        | 3              | 24                 | 18               | 32              | 74
S0156      | CJ250156    | Bilingual Dev  | Java, Python             | 2              | 15                 | 19               | 0               | 34
```

**Key Considerations:**
- STRING_AGG aggregates language list
- HAVING filters for students with ≥2 languages
- Specific counts for major languages
- Useful for assessing programming versatility

---

### Query 4.5: Second-Highest Score per Problem
**Purpose:** Find students with second-best score on each problem (interesting edge case).

```sql
-- Find students with second-highest score per problem
-- Shows runner-up performers
-- Useful for: Recognition, performance gap analysis
WITH ranked_submissions AS (
  SELECT 
    p.problem_id,
    p.problem_code,
    p.title,
    s.student_id,
    s.roll_number,
    s.full_name,
    sub.score,
    RANK() OVER (PARTITION BY p.problem_id ORDER BY sub.score DESC) AS score_rank
  FROM submissions sub
  INNER JOIN students s ON sub.student_id = s.student_id
  INNER JOIN problems p ON sub.problem_id = p.problem_id
  WHERE sub.status = 'Accepted'  -- Only fully solved problems
)
SELECT 
  problem_id,
  problem_code,
  title,
  student_id,
  roll_number,
  full_name,
  score,
  'Second Place' AS placement
FROM ranked_submissions
WHERE score_rank = 2
ORDER BY problem_code, score DESC;
```

**Key Considerations:**
- Uses CTE (Common Table Expression) for clarity
- RANK() window function partitions by problem and ranks by score
- Only considers "Accepted" submissions
- Useful for identifying who's close to top performers

---

## Query Performance Notes

### Optimization Considerations
1. **Index Usage:** All queries benefit from indexes on FK, status, timestamp, and composite columns
2. **EXPLAIN ANALYZE:** Use for production queries to verify index usage
3. **Materialized Views:** High-frequency aggregations could be pre-computed
4. **Pagination:** Add LIMIT/OFFSET for large result sets
5. **Timeout Thresholds:** Set query timeouts to prevent runaway queries

### Expected Row Counts (from sample data):
- submissions: 2500 rows
- test_results: 9600+ rows
- students: 320 rows
- enrollments: 720+ rows
- problems: 67 rows

---

## Next Section: query_outputs.md

The next file contains actual expected output samples and validation guidelines.

