# Part 3: Data Integrity Audit - SQL Queries

## Overview

Data integrity audit queries validate the CodeJudge database against schema constraints, referential integrity rules, and business logic requirements. These queries identify data quality issues, inconsistencies, and violations.

---

## Section 1: Foreign Key Integrity Audit

### Audit 1.1: Orphan Students (Batch FK Violations)
**Purpose:** Find students referencing non-existent batches.

```sql
-- Audit: Students with invalid batch_id
-- Should return 0 rows if FK constraint enforced
SELECT 
  s.student_id,
  s.roll_number,
  s.full_name,
  s.batch_id,
  'ORPHAN: batch_id not in batches' AS issue
FROM students s
LEFT JOIN batches b ON s.batch_id = b.batch_id
WHERE b.batch_id IS NULL
ORDER BY s.student_id;

-- Expected: 0 rows (all students have valid batches)
-- Severity: CRITICAL (referential integrity violation)
```

---

### Audit 1.2: Orphan Enrollments (Course FK Violations)
**Purpose:** Find enrollments referencing non-existent courses.

```sql
-- Audit: Enrollments with invalid course_id
SELECT 
  e.enrollment_id,
  e.student_id,
  e.course_id,
  'ORPHAN: course_id not in courses' AS issue
FROM enrollments e
LEFT JOIN courses c ON e.course_id = c.course_id
WHERE c.course_id IS NULL;

-- Expected: 0 rows
-- Severity: CRITICAL
```

---

### Audit 1.3: Orphan Problems (Course FK Violations)
**Purpose:** Find problems referencing non-existent courses.

```sql
-- Audit: Problems with invalid course_id
SELECT 
  p.problem_id,
  p.problem_code,
  p.title,
  p.course_id,
  'ORPHAN: course_id not in courses' AS issue
FROM problems p
LEFT JOIN courses c ON p.course_id = c.course_id
WHERE c.course_id IS NULL;

-- Expected: 0 rows
-- Severity: CRITICAL
-- Note: Data issue CT008 references C999 which doesn't exist
```

---

### Audit 1.4: Orphan Test Cases (Problem FK Violations)
**Purpose:** Find test cases referencing non-existent problems.

```sql
-- Audit: Test cases with invalid problem_id
SELECT 
  tc.test_case_id,
  tc.problem_id,
  tc.case_no,
  'ORPHAN: problem_id not in problems' AS issue
FROM test_cases tc
LEFT JOIN problems p ON tc.problem_id = p.problem_id
WHERE p.problem_id IS NULL;

-- Expected: 0 rows
-- Severity: CRITICAL
```

---

### Audit 1.5: Orphan Submissions (Student FK Violations)
**Purpose:** Find submissions from non-existent students.

```sql
-- Audit: Submissions with invalid student_id
SELECT 
  sub.submission_id,
  sub.student_id,
  sub.problem_id,
  'ORPHAN: student_id not in students' AS issue
FROM submissions sub
LEFT JOIN students s ON sub.student_id = s.student_id
WHERE s.student_id IS NULL;

-- Expected: 0 rows
-- Severity: CRITICAL
```

---

### Audit 1.6: Orphan Submissions (Problem FK Violations)
**Purpose:** Find submissions for non-existent problems.

```sql
-- Audit: Submissions with invalid problem_id
SELECT 
  sub.submission_id,
  sub.student_id,
  sub.problem_id,
  'ORPHAN: problem_id not in problems' AS issue
FROM submissions sub
LEFT JOIN problems p ON sub.problem_id = p.problem_id
WHERE p.problem_id IS NULL;

-- Expected: 0 rows
-- Severity: CRITICAL
```

---

### Audit 1.7: Orphan Submissions (Contest FK Violations - Optional)
**Purpose:** Find contest submissions where contest doesn't exist (contest_id NOT NULL but invalid).

```sql
-- Audit: Submissions with invalid contest_id
-- Note: contest_id is NULLABLE, so this checks when it's NOT NULL
SELECT 
  sub.submission_id,
  sub.student_id,
  sub.contest_id,
  'ORPHAN: contest_id not in contests' AS issue
FROM submissions sub
WHERE sub.contest_id IS NOT NULL
  AND NOT EXISTS (
    SELECT 1 FROM contests c WHERE c.contest_id = sub.contest_id
  );

-- Expected: 0 rows
-- Severity: HIGH (optional FK, but if present should be valid)
```

---

### Audit 1.8: Orphan Test Results (Submission FK Violations)
**Purpose:** Find test results for non-existent submissions.

```sql
-- Audit: Test results with invalid submission_id
SELECT 
  tr.result_id,
  tr.submission_id,
  'ORPHAN: submission_id not in submissions' AS issue
FROM test_results tr
LEFT JOIN submissions sub ON tr.submission_id = sub.submission_id
WHERE sub.submission_id IS NULL;

-- Expected: 0 rows
-- Severity: CRITICAL
```

---

### Audit 1.9: Orphan Test Results (Test Case FK Violations)
**Purpose:** Find test results for non-existent test cases.

```sql
-- Audit: Test results with invalid test_case_id
SELECT 
  tr.result_id,
  tr.submission_id,
  tr.test_case_id,
  'ORPHAN: test_case_id not in test_cases' AS issue
FROM test_results tr
LEFT JOIN test_cases tc ON tr.test_case_id = tc.test_case_id
WHERE tc.test_case_id IS NULL;

-- Expected: 0 rows
-- Severity: CRITICAL
```

---

### Audit 1.10: Orphan Attendance (Session FK Violations)
**Purpose:** Find attendance records for non-existent sessions.

```sql
-- Audit: Attendance with invalid session_id
SELECT 
  a.attendance_id,
  a.session_id,
  'ORPHAN: session_id not in sessions' AS issue
FROM attendance a
LEFT JOIN sessions s ON a.session_id = s.session_id
WHERE s.session_id IS NULL;

-- Expected: 0 rows
-- Severity: CRITICAL
```

---

### Audit 1.11: Orphan Attendance (Student FK Violations)
**Purpose:** Find attendance records for non-existent students.

```sql
-- Audit: Attendance with invalid student_id
SELECT 
  a.attendance_id,
  a.student_id,
  'ORPHAN: student_id not in students' AS issue
FROM attendance a
LEFT JOIN students s ON a.student_id = s.student_id
WHERE s.student_id IS NULL;

-- Expected: 0 rows
-- Severity: CRITICAL
```

---

### Audit 1.12: Orphan Regrade Requests (Submission FK Violations)
**Purpose:** Find regrade requests for non-existent submissions.

```sql
-- Audit: Regrade requests with invalid submission_id
SELECT 
  rr.request_id,
  rr.submission_id,
  'ORPHAN: submission_id not in submissions' AS issue
FROM regrade_requests rr
LEFT JOIN submissions sub ON rr.submission_id = sub.submission_id
WHERE sub.submission_id IS NULL;

-- Expected: 0 rows
-- Severity: CRITICAL
-- Note: Data issue RG0006 references SUB999999 which doesn't exist
```

---

### Audit 1.13: Orphan Regrade Requests (Student FK Violations)
**Purpose:** Find regrade requests from non-existent students.

```sql
-- Audit: Regrade requests with invalid student_id
SELECT 
  rr.request_id,
  rr.student_id,
  'ORPHAN: student_id not in students' AS issue
FROM regrade_requests rr
LEFT JOIN students s ON rr.student_id = s.student_id
WHERE s.student_id IS NULL;

-- Expected: 0 rows
-- Severity: CRITICAL
```

---

### Audit 1.14: Regrade Request Student ID Mismatch
**Purpose:** Verify regrade_requests.student_id matches the student_id in the referenced submission.

```sql
-- Audit: Regrade request student_id doesn't match submission's student_id
SELECT 
  rr.request_id,
  rr.submission_id,
  rr.student_id AS regrade_student_id,
  sub.student_id AS submission_student_id,
  'MISMATCH: student_id in regrade_requests != student_id in submissions' AS issue
FROM regrade_requests rr
INNER JOIN submissions sub ON rr.submission_id = sub.submission_id
WHERE rr.student_id != sub.student_id;

-- Expected: 0 rows
-- Severity: CRITICAL (data consistency)
-- Purpose: student_id redundancy is validated
```

---

### Audit 1.15: Orphan Plagiarism Flags (Submission FK Violations)
**Purpose:** Find plagiarism flags with non-existent submission references.

```sql
-- Audit: Plagiarism flags with invalid submission_id or matched_submission_id
SELECT 
  pf.flag_id,
  pf.submission_id,
  pf.matched_submission_id,
  CASE 
    WHEN NOT EXISTS (SELECT 1 FROM submissions WHERE submission_id = pf.submission_id) 
      THEN 'ORPHAN: submission_id not in submissions'
    WHEN NOT EXISTS (SELECT 1 FROM submissions WHERE submission_id = pf.matched_submission_id) 
      THEN 'ORPHAN: matched_submission_id not in submissions'
  END AS issue
FROM plagiarism_flags pf
WHERE NOT EXISTS (SELECT 1 FROM submissions WHERE submission_id = pf.submission_id)
   OR NOT EXISTS (SELECT 1 FROM submissions WHERE submission_id = pf.matched_submission_id);

-- Expected: 0 rows
-- Severity: CRITICAL
```

---

## Section 2: Unique Constraint Violations

### Audit 2.1: Duplicate Roll Numbers
**Purpose:** Find students with duplicate roll numbers (should be unique).

```sql
-- Audit: Duplicate roll_number
SELECT 
  roll_number,
  COUNT(*) AS duplicate_count,
  STRING_AGG(student_id, ', ') AS student_ids
FROM students
GROUP BY roll_number
HAVING COUNT(*) > 1;

-- Expected: 0 rows
-- Severity: CRITICAL (roll_number is business key)
```

---

### Audit 2.2: Duplicate Emails (Non-NULL)
**Purpose:** Find duplicate non-NULL emails (should be unique when present).

```sql
-- Audit: Duplicate email (excluding NULLs)
SELECT 
  email,
  COUNT(*) AS duplicate_count,
  STRING_AGG(student_id, ', ') AS student_ids
FROM students
WHERE email IS NOT NULL
GROUP BY email
HAVING COUNT(*) > 1;

-- Expected: 0 rows
-- Severity: CRITICAL (email is business key when not NULL)
```

---

### Audit 2.3: Duplicate Batch Codes
**Purpose:** Find duplicate batch codes (should be unique).

```sql
-- Audit: Duplicate batch_code
SELECT 
  batch_code,
  COUNT(*) AS duplicate_count,
  STRING_AGG(batch_id, ', ') AS batch_ids
FROM batches
GROUP BY batch_code
HAVING COUNT(*) > 1;

-- Expected: 0 rows
-- Severity: CRITICAL
```

---

### Audit 2.4: Duplicate Course Codes
**Purpose:** Find duplicate course codes (should be unique).

```sql
-- Audit: Duplicate course_code
SELECT 
  course_code,
  COUNT(*) AS duplicate_count,
  STRING_AGG(course_id, ', ') AS course_ids
FROM courses
GROUP BY course_code
HAVING COUNT(*) > 1;

-- Expected: 0 rows
-- Severity: CRITICAL
```

---

### Audit 2.5: Duplicate Problem Codes
**Purpose:** Find duplicate problem codes (should be unique).

```sql
-- Audit: Duplicate problem_code
SELECT 
  problem_code,
  COUNT(*) AS duplicate_count,
  STRING_AGG(problem_id, ', ') AS problem_ids
FROM problems
GROUP BY problem_code
HAVING COUNT(*) > 1;

-- Expected: 0 rows
-- Severity: CRITICAL
```

---

### Audit 2.6: Duplicate Enrollment (Student-Course pairs)
**Purpose:** Find students enrolled in same course multiple times.

```sql
-- Audit: Duplicate student-course enrollment
SELECT 
  student_id,
  course_id,
  COUNT(*) AS enrollment_count,
  STRING_AGG(enrollment_id, ', ') AS enrollment_ids
FROM enrollments
GROUP BY student_id, course_id
HAVING COUNT(*) > 1;

-- Expected: 0 rows
-- Severity: CRITICAL (composite key violation)
```

---

### Audit 2.7: Duplicate Attendance (Session-Student pairs)
**Purpose:** Find students with multiple attendance records per session.

```sql
-- Audit: Duplicate session-student attendance
SELECT 
  session_id,
  student_id,
  COUNT(*) AS attendance_count,
  STRING_AGG(attendance_id, ', ') AS attendance_ids
FROM attendance
GROUP BY session_id, student_id
HAVING COUNT(*) > 1;

-- Expected: 0 rows
-- Severity: CRITICAL (composite key violation)
```

---

### Audit 2.8: Duplicate Test Case (Problem-Case No pairs)
**Purpose:** Find duplicate test case numbers within problems.

```sql
-- Audit: Duplicate test case number within problem
SELECT 
  problem_id,
  case_no,
  COUNT(*) AS test_case_count,
  STRING_AGG(test_case_id, ', ') AS test_case_ids
FROM test_cases
GROUP BY problem_id, case_no
HAVING COUNT(*) > 1;

-- Expected: 0 rows
-- Severity: CRITICAL (composite key violation)
```

---

### Audit 2.9: Duplicate Test Result (Submission-Test Case pairs)
**Purpose:** Find submissions with multiple results for same test case.

```sql
-- Audit: Duplicate test result for submission-test case
SELECT 
  submission_id,
  test_case_id,
  COUNT(*) AS result_count,
  STRING_AGG(result_id, ', ') AS result_ids
FROM test_results
GROUP BY submission_id, test_case_id
HAVING COUNT(*) > 1;

-- Expected: 0 rows
-- Severity: CRITICAL (composite key violation)
```

---

### Audit 2.10: Duplicate Contest-Problem (Contest-Problem pairs)
**Purpose:** Find problems added to same contest multiple times.

```sql
-- Audit: Duplicate contest-problem assignment
SELECT 
  contest_id,
  problem_id,
  COUNT(*) AS assignment_count
FROM contest_problems
GROUP BY contest_id, problem_id
HAVING COUNT(*) > 1;

-- Expected: 0 rows
-- Severity: CRITICAL (composite key violation)
```

---

## Section 3: Domain Constraint Violations

### Audit 3.1: Invalid Batch Status
**Purpose:** Find batches with invalid status values.

```sql
-- Audit: Invalid batch_status (should be in: active, completed, archived)
SELECT 
  batch_id,
  batch_code,
  batch_status,
  'INVALID: batch_status not in domain' AS issue
FROM batches
WHERE batch_status NOT IN ('active', 'completed', 'archived');

-- Expected: 0 rows
-- Severity: MEDIUM
```

---

### Audit 3.2: Invalid Course Status
**Purpose:** Find courses with invalid status values.

```sql
-- Audit: Invalid course_status (should be in: active, archived, draft)
SELECT 
  course_id,
  course_code,
  course_status,
  'INVALID: course_status not in domain' AS issue
FROM courses
WHERE course_status NOT IN ('active', 'archived', 'draft');

-- Expected: 0 rows
-- Severity: MEDIUM
```

---

### Audit 3.3: Invalid Student Enrollment Status
**Purpose:** Find students with invalid enrollment status.

```sql
-- Audit: Invalid student enrollment_status
SELECT 
  student_id,
  roll_number,
  enrollment_status,
  'INVALID: enrollment_status not in domain' AS issue
FROM students
WHERE enrollment_status NOT IN ('active', 'inactive', 'graduated', 'suspended');

-- Expected: 0 rows
-- Severity: MEDIUM
```

---

### Audit 3.4: Invalid Enrollment Status
**Purpose:** Find enrollments with invalid status values.

```sql
-- Audit: Invalid enrollment_status (should be in: active, completed, dropped, suspended)
SELECT 
  enrollment_id,
  student_id,
  course_id,
  enrollment_status,
  'INVALID: enrollment_status not in domain' AS issue
FROM enrollments
WHERE enrollment_status NOT IN ('active', 'completed', 'dropped', 'suspended');

-- Expected: 0 rows
-- Severity: MEDIUM
```

---

### Audit 3.5: Invalid Problem Difficulty
**Purpose:** Find problems with invalid difficulty levels.

```sql
-- Audit: Invalid problem difficulty (should be in: Easy, Medium, Hard)
SELECT 
  problem_id,
  problem_code,
  difficulty,
  'INVALID: difficulty not in domain' AS issue
FROM problems
WHERE difficulty NOT IN ('Easy', 'Medium', 'Hard');

-- Expected: 0 rows
-- Severity: MEDIUM
```

---

### Audit 3.6: Invalid Submission Status
**Purpose:** Find submissions with invalid status values.

```sql
-- Audit: Invalid submission status
SELECT 
  submission_id,
  student_id,
  status,
  'INVALID: status not in domain' AS issue
FROM submissions
WHERE status NOT IN (
  'Accepted', 'Wrong Answer', 'Compilation Error', 'Runtime Error', 
  'Time Limit Exceeded', 'Partial Accepted', 'Waiting', 'Judging'
);

-- Expected: 0 rows
-- Severity: MEDIUM
```

---

### Audit 3.7: Invalid Submission Language
**Purpose:** Find submissions in invalid programming languages.

```sql
-- Audit: Invalid submission language
SELECT 
  submission_id,
  student_id,
  language,
  'INVALID: language not in domain' AS issue
FROM submissions
WHERE language NOT IN (
  'C', 'C++', 'Java', 'Python', 'JavaScript', 'Go', 'Ruby', 'PHP', 'Rust', 'Kotlin', 'C#', 'Swift'
);

-- Expected: 0 rows
-- Severity: MEDIUM
```

---

### Audit 3.8: Invalid Submission Test Result Status
**Purpose:** Find test results with invalid status values.

```sql
-- Audit: Invalid test result status
SELECT 
  result_id,
  submission_id,
  result_status,
  'INVALID: result_status not in domain' AS issue
FROM test_results
WHERE result_status NOT IN (
  'Passed', 'Failed', 'Runtime Error', 'Time Limit Exceeded', 
  'Memory Limit Exceeded', 'Compilation Error', 'Presentation Error', 'Wrong Answer'
);

-- Expected: 0 rows
-- Severity: MEDIUM
```

---

### Audit 3.9: Invalid Contest Status
**Purpose:** Find contests with invalid status values.

```sql
-- Audit: Invalid contest_status
SELECT 
  contest_id,
  contest_title,
  contest_status,
  'INVALID: contest_status not in domain' AS issue
FROM contests
WHERE contest_status NOT IN ('draft', 'scheduled', 'published', 'ongoing', 'completed');

-- Expected: 0 rows
-- Severity: MEDIUM
```

---

### Audit 3.10: Invalid Attendance Status
**Purpose:** Find attendance records with invalid status.

```sql
-- Audit: Invalid attendance_status
SELECT 
  attendance_id,
  session_id,
  attendance_status,
  'INVALID: attendance_status not in domain' AS issue
FROM attendance
WHERE attendance_status NOT IN ('present', 'absent', 'late', 'excused', 'unauthorized leave');

-- Expected: 0 rows
-- Severity: MEDIUM
```

---

### Audit 3.11: Invalid Regrade Request Status
**Purpose:** Find regrade requests with invalid status.

```sql
-- Audit: Invalid regrade_request status
SELECT 
  request_id,
  submission_id,
  request_status,
  'INVALID: request_status not in domain' AS issue
FROM regrade_requests
WHERE request_status NOT IN ('open', 'approved', 'rejected', 'closed');

-- Expected: 0 rows
-- Severity: MEDIUM
```

---

### Audit 3.12: Invalid Plagiarism Flag Status
**Purpose:** Find plagiarism flags with invalid status.

```sql
-- Audit: Invalid plagiarism_flag status
SELECT 
  flag_id,
  submission_id,
  flag_status,
  'INVALID: flag_status not in domain' AS issue
FROM plagiarism_flags
WHERE flag_status NOT IN ('new', 'reviewing', 'confirmed', 'cleared', 'false positive');

-- Expected: 0 rows
-- Severity: MEDIUM
```

---

## Section 4: Range & Logic Constraint Violations

### Audit 4.1: Batch Dates Invalid (end_date < start_date)
**Purpose:** Find batches where end date is before start date.

```sql
-- Audit: Batch end_date before start_date
SELECT 
  batch_id,
  batch_code,
  start_date,
  end_date,
  'VIOLATION: end_date < start_date' AS issue
FROM batches
WHERE end_date < start_date;

-- Expected: 0 rows
-- Severity: CRITICAL
-- Note: Data issue CT005 has this violation
```

---

### Audit 4.2: Contest Time Invalid (end_time < start_time)
**Purpose:** Find contests where end time is before start time.

```sql
-- Audit: Contest end_time before start_time
SELECT 
  contest_id,
  contest_title,
  start_time,
  end_time,
  EXTRACT(EPOCH FROM (end_time - start_time)) / 60 AS duration_minutes,
  'VIOLATION: end_time < start_time' AS issue
FROM contests
WHERE end_time < start_time;

-- Expected: 0 rows
-- Severity: CRITICAL
-- Note: Data issue CT005 violates this
```

---

### Audit 4.3: Invalid Admission Dates (Future Dates)
**Purpose:** Find students with admission dates in the future.

```sql
-- Audit: Student admission_date in future
SELECT 
  student_id,
  roll_number,
  full_name,
  admission_date,
  'VIOLATION: admission_date > CURRENT_DATE' AS issue
FROM students
WHERE admission_date > CURRENT_DATE;

-- Expected: 0 rows
-- Severity: HIGH
```

---

### Audit 4.4: Invalid Graduation Year
**Purpose:** Find students with unreasonable graduation years.

```sql
-- Audit: Invalid graduation_year
SELECT 
  student_id,
  roll_number,
  admission_date,
  graduation_year,
  'VIOLATION: graduation_year < 2020 or graduation_year > CURRENT_YEAR + 5' AS issue
FROM students
WHERE graduation_year < 2020 OR graduation_year > EXTRACT(YEAR FROM CURRENT_DATE) + 5;

-- Expected: 0 rows
-- Severity: LOW (informational)
```

---

### Audit 4.5: Invalid Credit Hours
**Purpose:** Find courses with unreasonable credit hour values.

```sql
-- Audit: Invalid credit_hours
SELECT 
  course_id,
  course_code,
  credit_hours,
  'VIOLATION: credit_hours not in range [1, 10]' AS issue
FROM courses
WHERE credit_hours < 1 OR credit_hours > 10;

-- Expected: 0 rows
-- Severity: MEDIUM
```

---

### Audit 4.6: Invalid Problem Max Score
**Purpose:** Find problems with invalid score ranges.

```sql
-- Audit: Invalid problem max_score
SELECT 
  problem_id,
  problem_code,
  max_score,
  'VIOLATION: max_score not in range [1, 1000]' AS issue
FROM problems
WHERE max_score < 1 OR max_score > 1000;

-- Expected: 0 rows
-- Severity: MEDIUM
```

---

### Audit 4.7: Test Case Points Exceed Problem Max
**Purpose:** Find test cases awarding more points than problem's max.

```sql
-- Audit: Test case points exceed problem max_score
SELECT 
  tc.test_case_id,
  tc.problem_id,
  tc.case_no,
  tc.points AS test_points,
  p.max_score AS problem_max,
  'VIOLATION: test_case.points > problem.max_score' AS issue
FROM test_cases tc
INNER JOIN problems p ON tc.problem_id = p.problem_id
WHERE tc.points > p.max_score;

-- Expected: 0 rows
-- Severity: MEDIUM (business logic)
```

---

### Audit 4.8: Submission Score Exceeds Problem Max
**Purpose:** Find submissions with score > problem's max_score.

```sql
-- Audit: Submission score exceeds problem max_score
SELECT 
  sub.submission_id,
  sub.student_id,
  sub.problem_id,
  sub.score AS submission_score,
  p.max_score AS problem_max,
  'VIOLATION: submission.score > problem.max_score' AS issue
FROM submissions sub
INNER JOIN problems p ON sub.problem_id = p.problem_id
WHERE sub.score > p.max_score;

-- Expected: 0 rows
-- Severity: CRITICAL
```

---

### Audit 4.9: Test Result Points Exceed Test Case Max
**Purpose:** Find test results awarding more points than test case's max.

```sql
-- Audit: Test result points exceed test case max_points
SELECT 
  tr.result_id,
  tr.submission_id,
  tr.test_case_id,
  tr.awarded_points AS result_points,
  tc.points AS test_case_max,
  'VIOLATION: test_result.awarded_points > test_case.points' AS issue
FROM test_results tr
INNER JOIN test_cases tc ON tr.test_case_id = tc.test_case_id
WHERE tr.awarded_points > tc.points;

-- Expected: 0 rows
-- Severity: CRITICAL
```

---

### Audit 4.10: Similarity Score Out of Range
**Purpose:** Find plagiarism flags with invalid similarity scores (not 0-100).

```sql
-- Audit: Plagiarism similarity_score outside [0, 100]
SELECT 
  flag_id,
  submission_id,
  matched_submission_id,
  similarity_score,
  'VIOLATION: similarity_score not in range [0, 100]' AS issue
FROM plagiarism_flags
WHERE similarity_score < 0 OR similarity_score > 100;

-- Expected: 0 rows
-- Severity: MEDIUM
```

---

### Audit 4.11: Negative Runtime/Memory Values
**Purpose:** Find test results with negative runtime or memory values.

```sql
-- Audit: Negative runtime_ms or memory_kb
SELECT 
  result_id,
  submission_id,
  runtime_ms,
  memory_kb,
  'VIOLATION: negative runtime_ms or memory_kb' AS issue
FROM test_results
WHERE runtime_ms < 0 OR memory_kb < 0;

-- Expected: 0 rows
-- Severity: MEDIUM
```

---

## Section 5: Conditional Logic Violations

### Audit 5.1: Completed Enrollment Without Grade
**Purpose:** Find enrollments marked "completed" but missing final_grade.

```sql
-- Audit: Completed enrollment without final_grade
SELECT 
  enrollment_id,
  student_id,
  course_id,
  enrollment_status,
  final_grade,
  'VIOLATION: enrollment_status=completed but final_grade IS NULL' AS issue
FROM enrollments
WHERE enrollment_status = 'completed' AND final_grade IS NULL;

-- Expected: Few or 0 rows
-- Severity: MEDIUM (business logic violation)
```

---

### Audit 5.2: Regrade Request Status vs Resolution Date
**Purpose:** Find regrade requests with inconsistent status/resolved_at.

```sql
-- Audit: Regrade request with inconsistent status and resolved_at
SELECT 
  request_id,
  submission_id,
  request_status,
  resolved_at,
  'VIOLATION: status=open but resolved_at IS NOT NULL' AS issue
FROM regrade_requests
WHERE (request_status = 'open' AND resolved_at IS NOT NULL)
   OR (request_status != 'open' AND resolved_at IS NULL);

-- Expected: 0 rows
-- Severity: MEDIUM
```

---

### Audit 5.3: Accepted Submission with Score 0
**Purpose:** Find submissions marked "Accepted" but with score 0 (contradictory).

```sql
-- Audit: Accepted submission with score 0
SELECT 
  submission_id,
  student_id,
  problem_id,
  status,
  score,
  'VIOLATION: status=Accepted but score=0' AS issue
FROM submissions
WHERE status = 'Accepted' AND score = 0;

-- Expected: 0 rows
-- Severity: MEDIUM (data quality issue)
```

---

### Audit 5.4: Compilation Error with Positive Score
**Purpose:** Find compilation error submissions with non-zero score.

```sql
-- Audit: Compilation error with score > 0
SELECT 
  submission_id,
  student_id,
  status,
  score,
  'VIOLATION: status=CompilationError but score > 0' AS issue
FROM submissions
WHERE status = 'Compilation Error' AND score > 0;

-- Expected: 0 rows
-- Severity: MEDIUM
```

---

### Audit 5.5: Test Result Passed Status Mismatch
**Purpose:** Find test results marked "Passed" but awarded_points < test_case.points.

```sql
-- Audit: Passed test but awarded points < max points
SELECT 
  tr.result_id,
  tr.submission_id,
  tr.result_status,
  tr.awarded_points,
  tc.points AS max_points,
  'VIOLATION: result_status=Passed but awarded_points < points' AS issue
FROM test_results tr
INNER JOIN test_cases tc ON tr.test_case_id = tc.test_case_id
WHERE tr.result_status = 'Passed' AND tr.awarded_points < tc.points;

-- Expected: 0 rows
-- Severity: MEDIUM
```

---

### Audit 5.6: Failed Test with Full Points
**Purpose:** Find test results marked "Failed" but awarded full points (contradictory).

```sql
-- Audit: Failed test with awarded_points = max_points
SELECT 
  tr.result_id,
  tr.submission_id,
  tr.result_status,
  tr.awarded_points,
  tc.points AS max_points,
  'VIOLATION: result_status=Failed but awarded_points = points' AS issue
FROM test_results tr
INNER JOIN test_cases tc ON tr.test_case_id = tc.test_case_id
WHERE tr.result_status = 'Failed' AND tr.awarded_points = tc.points;

-- Expected: 0 rows
-- Severity: MEDIUM
```

---

### Audit 5.7: Self-Plagiarism Flag
**Purpose:** Find plagiarism flags where submission_id = matched_submission_id.

```sql
-- Audit: Plagiarism flag comparing submission to itself
SELECT 
  flag_id,
  submission_id,
  matched_submission_id,
  similarity_score,
  'VIOLATION: submission_id = matched_submission_id (self-plagiarism)' AS issue
FROM plagiarism_flags
WHERE submission_id = matched_submission_id;

-- Expected: 0 rows
-- Severity: MEDIUM (data quality issue)
-- Note: Data issue PF0008 violates this
```

---

## Section 6: Consistency Checks

### Audit 6.1: Submission Score vs Test Results Sum
**Purpose:** Find submissions where score doesn't equal sum of test_results.awarded_points.

```sql
-- Audit: Submission score inconsistent with test results
SELECT 
  sub.submission_id,
  sub.student_id,
  sub.problem_id,
  sub.score AS submission_score,
  COALESCE(SUM(tr.awarded_points), 0) AS sum_test_results,
  'INCONSISTENCY: submission.score != SUM(test_results.awarded_points)' AS issue
FROM submissions sub
LEFT JOIN test_results tr ON sub.submission_id = tr.submission_id
GROUP BY sub.submission_id, sub.score, sub.student_id, sub.problem_id
HAVING sub.score != COALESCE(SUM(tr.awarded_points), 0)
ORDER BY sub.submission_id;

-- Expected: Few rows (known data quality issue)
-- Severity: HIGH
-- Note: SUB000001 has score=46 but test_results sum=8
```

---

### Audit 6.2: Submission Status vs Test Results
**Purpose:** Analyze if submission status aligns with test results.

```sql
-- Audit: Submission status vs test results alignment
SELECT 
  sub.submission_id,
  sub.status,
  COUNT(DISTINCT tr.result_id) AS test_count,
  COUNT(CASE WHEN tr.result_status = 'Passed' THEN 1 END) AS passed_count,
  COUNT(CASE WHEN tr.result_status IN ('Failed', 'Wrong Answer') THEN 1 END) AS failed_count,
  CASE 
    WHEN COUNT(DISTINCT tr.result_id) = 0 THEN 'No tests run'
    WHEN COUNT(CASE WHEN tr.result_status = 'Passed' THEN 1 END) = COUNT(DISTINCT tr.result_id) THEN 'Should be Accepted'
    WHEN COUNT(CASE WHEN tr.result_status = 'Passed' THEN 1 END) > 0 THEN 'Should be Partial Accepted'
    ELSE 'Should be Failed'
  END AS expected_status
FROM submissions sub
LEFT JOIN test_results tr ON sub.submission_id = tr.submission_id
WHERE sub.status NOT IN ('Compilation Error', 'Time Limit Exceeded', 'Runtime Error')
GROUP BY sub.submission_id, sub.status
HAVING sub.status NOT IN (
  CASE 
    WHEN COUNT(DISTINCT tr.result_id) = 0 THEN 'No tests run'
    WHEN COUNT(CASE WHEN tr.result_status = 'Passed' THEN 1 END) = COUNT(DISTINCT tr.result_id) THEN 'Accepted'
    WHEN COUNT(CASE WHEN tr.result_status = 'Passed' THEN 1 END) > 0 THEN 'Partial Accepted'
    ELSE 'Wrong Answer'
  END
)
LIMIT 50;

-- Expected: Few or 0 rows (should be mostly consistent)
-- Severity: MEDIUM
```

---

### Audit 6.3: Test Case Points Sum vs Problem Max
**Purpose:** Verify sum of test case points aligns with problem max_score.

```sql
-- Audit: Sum of test case points vs problem max_score
SELECT 
  p.problem_id,
  p.problem_code,
  p.max_score,
  SUM(tc.points) AS sum_test_points,
  p.max_score - SUM(tc.points) AS point_difference,
  CASE 
    WHEN SUM(tc.points) = p.max_score THEN 'OK'
    WHEN SUM(tc.points) < p.max_score THEN 'Points Short'
    ELSE 'Points Over'
  END AS status
FROM problems p
LEFT JOIN test_cases tc ON p.problem_id = tc.problem_id
GROUP BY p.problem_id, p.problem_code, p.max_score
HAVING SUM(tc.points) != p.max_score
ORDER BY ABS(p.max_score - SUM(tc.points)) DESC;

-- Expected: Few rows (test case design issue)
-- Severity: LOW (informational)
```

---

### Audit 6.4: Duplicate Submission Check
**Purpose:** Identify students with multiple submissions to same problem in short time.

```sql
-- Audit: Rapid duplicate submissions (potential retry spam)
SELECT 
  sub1.submission_id AS first_submission,
  sub2.submission_id AS duplicate_submission,
  sub1.student_id,
  sub1.problem_id,
  sub1.submitted_at AS first_time,
  sub2.submitted_at AS second_time,
  EXTRACT(EPOCH FROM (sub2.submitted_at - sub1.submitted_at)) / 60 AS minutes_apart,
  'Same problem submitted twice within 1 minute' AS note
FROM submissions sub1
INNER JOIN submissions sub2 
  ON sub1.student_id = sub2.student_id 
  AND sub1.problem_id = sub2.problem_id
  AND sub1.submission_id < sub2.submission_id
  AND sub2.submitted_at - sub1.submitted_at < INTERVAL '1 minute'
ORDER BY sub1.student_id, sub1.problem_id, sub1.submitted_at
LIMIT 50;

-- Expected: Many rows (rapid retries common)
-- Severity: LOW (informational only)
```

---

## Section 7: Referential Integrity Summary Report

### Audit 7.1: Foreign Key Integrity Summary
**Purpose:** Quick summary of all orphaned records.

```sql
-- Summary of all orphan records
WITH orphan_counts AS (
  SELECT 'students with invalid batch_id' AS issue, COUNT(*) AS count
  FROM students s
  LEFT JOIN batches b ON s.batch_id = b.batch_id
  WHERE b.batch_id IS NULL
  
  UNION ALL
  
  SELECT 'enrollments with invalid course_id', COUNT(*)
  FROM enrollments e
  LEFT JOIN courses c ON e.course_id = c.course_id
  WHERE c.course_id IS NULL
  
  UNION ALL
  
  SELECT 'problems with invalid course_id', COUNT(*)
  FROM problems p
  LEFT JOIN courses c ON p.course_id = c.course_id
  WHERE c.course_id IS NULL
  
  -- Add more orphan checks as needed
)
SELECT issue, count, CASE WHEN count = 0 THEN '✓ OK' ELSE '✗ ISSUES' END AS status
FROM orphan_counts
ORDER BY count DESC;

-- Expected: All counts = 0 with ✓ OK
-- Severity: CRITICAL
```

---

## Summary

These audit queries cover:
- ✓ **Foreign Key Integrity** (15 queries): Orphan records
- ✓ **Unique Constraints** (10 queries): Duplicates
- ✓ **Domain Constraints** (12 queries): Invalid enum values
- ✓ **Range Constraints** (11 queries): Out-of-range values
- ✓ **Conditional Logic** (7 queries): Inconsistent state
- ✓ **Consistency Checks** (4 queries): Data alignment

**Total: 59 audit queries**

Execute regularly to maintain data quality and catch issues early.

