# CodeJudge Database Schema Understanding

## Overview
The CodeJudge platform is an online coding practice and evaluation system that manages students, courses, programming problems, contests, and code submissions with comprehensive testing and plagiarism detection.

---

## Table-by-Table Schema Analysis

### 1. **batches** — Student Cohorts
**Purpose:** Represents academic batches/cohorts enrolling in the platform.

**Columns:**
- `batch_id` (PK): Unique batch identifier (e.g., B001)
- `batch_code` (Unique, Candidate Key): Human-readable batch code (e.g., CSE2025A)
- `program`: Program name (e.g., "B.Tech CSE", "MCA")
- `start_date`: Batch commencement date
- `end_date`: Batch completion/end date
- `batch_status`: Current status (active, completed, archived)

**Business Role:** Represents academic cohorts. Students are assigned to batches which group them for administrative purposes, course enrollment, and session attendance.

**Key Observations:**
- batch_id is a surrogatekey (generated identifier) while batch_code is a natural/business key
- One batch can contain many students (one-to-many with students)
- One batch can have many sessions indirectly through courses

---

### 2. **courses** — Course Catalog
**Purpose:** Master catalog of all courses offered on the platform.

**Columns:**
- `course_id` (PK): Unique course identifier (e.g., C001)
- `course_code` (Unique, Candidate Key): Course code (e.g., CS101)
- `course_title`: Full course title
- `course_status`: Status (active, archived, draft)
- `credit_hours`: Academic credits associated with the course

**Business Role:** Defines all available courses. Multiple students enroll in courses, multiple problems are created for courses, contests are organized within courses.

**Key Observations:**
- course_code should be unique in a well-normalized schema
- Course can have many enrollments, many problems, many contests, many sessions
- No timestamp tracking (created_at/updated_at missing)

---

### 3. **students** — Student Master Data
**Purpose:** Maintains complete student information and their batch assignment.

**Columns:**
- `student_id` (PK): Unique student identifier (e.g., S0001)
- `roll_number` (Unique, Candidate Key): Student roll/registration number (e.g., CJ250001)
- `full_name`: Student's full name
- `email` (Unique, Candidate Key, NULLABLE): Student's institutional email
- `batch_id` (FK → batches): Batch to which student is assigned
- `admission_date`: Date student joined the platform/batch
- `enrollment_status`: Current status (active, inactive, graduated, suspended)
- `graduation_year`: Expected/actual graduation year

**Business Role:** Core entity representing all students using the platform. Students enroll in courses, submit solutions, attend sessions, request regrades, and generate plagiarism flags.

**Data Quality Issues Observed:**
- S0005: email is NULL (not all students have email addresses registered)
- Students can be in "inactive" state but still have enrollments
- No timestamp for when enrollment_status was last updated

**Functional Dependencies:**
- roll_number → full_name, email, batch_id, admission_date
- email → student_id, roll_number (assuming email is unique when not NULL)

---

### 4. **enrollments** — Student Course Enrollments
**Purpose:** Junction table linking students to courses with enrollment metadata.

**Columns:**
- `enrollment_id` (PK): Unique enrollment record identifier
- `student_id` (FK → students): Which student
- `course_id` (FK → courses): Which course
- `enrolled_on`: Enrollment date
- `enrollment_status`: Status (active, completed, dropped, suspended)
- `final_grade` (NULLABLE): Course grade upon completion (A, B, C, F, etc.)

**Business Role:** Represents the many-to-many relationship between students and courses. Links students to courses they're enrolled in, tracks their progress, and stores final grades.

**Key Observations:**
- Composite candidate key: (student_id, course_id) — a student should enroll in a course only once
- enrollment_status can be "completed" without a final_grade
- enrollment_status can be "active" with a final_grade (contradictory states possible)
- Partial dependency: final_grade depends on enrollment_status being "completed"

**Data Quality Issues:**
- Multiple enrollments show "active" status yet have final grades
- Some enrollments marked "dropped" still have grades assigned

---

### 5. **problems** — Programming Problems
**Purpose:** Defines all programming problems offered on the platform, mapped to courses.

**Columns:**
- `problem_id` (PK): Unique problem identifier (e.g., P0001)
- `course_id` (FK → courses): Course this problem belongs to
- `problem_code` (Unique, Candidate Key): Problem code (e.g., CS101_P01)
- `title`: Problem statement title
- `difficulty`: Difficulty level (Easy, Medium, Hard)
- `max_score`: Total points for this problem
- `created_at`: Creation timestamp
- `is_active`: Boolean flag (1=active, 0=inactive/archived)

**Business Role:** Defines coding problems. Problems are organized within courses, have test cases for validation, can be included in contests, and are submission targets.

**Key Observations:**
- problem_code is a natural key (human-readable, unique)
- is_active is a flag (0/1) rather than status field (design choice for backward compatibility)
- No updated_at timestamp
- One problem can have many test cases (one-to-many)
- One problem can appear in many contests (many-to-many through contest_problems)
- One problem can have many submissions (one-to-many)

**Redundancy Risk:**
- course_id could be derived from problem_code in some systems (not here)

---

### 6. **test_cases** — Test Cases for Problems
**Purpose:** Defines input/output test cases for validating submissions.

**Columns:**
- `test_case_id` (PK): Unique test case identifier
- `problem_id` (FK → problems): Problem this test case belongs to
- `case_no`: Sequential test case number within problem (1, 2, 3...)
- `input_label`: Label/reference to input data
- `expected_output_label`: Label/reference to expected output
- `points`: Points awarded if this test case passes
- `is_hidden`: Boolean (0=visible to students, 1=hidden/private test case)

**Business Role:** Defines validation criteria for submissions. When a student submits code, the system runs all test cases for that problem and generates test_results.

**Composite Key:** (problem_id, case_no) identifies a unique test case within a problem

**Key Observations:**
- Actual input/output data stored elsewhere (only labels/references here)
- Points should sum to problem's max_score (not enforced in schema)
- is_hidden determines if students can see the test case before submission

---

### 7. **contests** — Coding Contests/Evaluations
**Purpose:** Represents time-bounded coding contests/competitions within courses.

**Columns:**
- `contest_id` (PK): Unique contest identifier (e.g., CT001)
- `course_id` (FK → courses): Course under which contest is organized
- `contest_title`: Contest name
- `start_time`: Contest start timestamp
- `end_time`: Contest end timestamp
- `contest_status`: Status (draft, scheduled, published, ongoing, completed)

**Business Role:** Represents contests. Many problems can be added to a contest via contest_problems. Students submit solutions during contests, with contest_id optionally recorded in submissions.

**Data Quality Issues Observed:**
- CT005: end_time (2025-04-05 11:00) < start_time (2025-04-05 12:00) — impossible!
- CT008: course_id = C999 which doesn't exist in courses table (orphan FK)

**Design Issue:**
- Should validate start_time < end_time at DB or application level
- Contest can reference non-existent course

---

### 8. **contest_problems** — Contest Problem Mapping
**Purpose:** Many-to-many junction table linking contests to problems.

**Columns:**
- `contest_id` (FK → contests): Which contest
- `problem_id` (FK → problems): Which problem
- `problem_order`: Display/execution order of problem in contest

**Composite Key:** (contest_id, problem_id) — a problem appears in a contest once at a specific order

**Business Role:** Defines which problems are included in which contests. Enables flexible problem composition for contests.

**Design Pattern:** Classic many-to-many bridge table (no PK defined, but composite FK is unique)

---

### 9. **submissions** — Student Code Submissions
**Purpose:** Records each code submission by a student against a problem.

**Columns:**
- `submission_id` (PK): Unique submission identifier (e.g., SUB000001)
- `student_id` (FK → students): Student who submitted
- `problem_id` (FK → problems): Problem being solved
- `contest_id` (FK → contests, NULLABLE): Contest context (if submitted during a contest)
- `language`: Programming language (C, C++, Java, Python, JavaScript, Go, etc.)
- `submitted_at`: Submission timestamp
- `status`: Submission result status (Accepted, Wrong Answer, Compilation Error, Runtime Error, Time Limit Exceeded)
- `score`: Points awarded for submission
- `runtime_ms`: Execution time in milliseconds

**Business Role:** Records every code submission. Students submit solutions to problems, with optional contest context. Each submission generates one or more test_results.

**Key Observations:**
- contest_id is NULLABLE (students can submit to problems outside of contests)
- status can be derived from test_results but stored for quick access (denormalization for performance)
- score should equal sum of awarded_points in test_results (potential redundancy)
- One submission can have many test_results (one-to-many)
- Composite uniqueness: typically (student_id, problem_id, submitted_at) is meaningful but not enforced

**Data Quality Issues:**
- SUB000003: contest_id=CT001 but this contest may not have this problem
- Some submissions have status="Accepted" with score=0 (contradictory)

---

### 10. **test_results** — Test Case Execution Results
**Purpose:** Records results of running individual test cases against submissions.

**Columns:**
- `result_id` (PK): Unique result record identifier
- `submission_id` (FK → submissions): Which submission
- `test_case_id` (FK → test_cases): Which test case was run
- `result_status`: Result (Passed, Failed, Runtime Error, Time Limit Exceeded, etc.)
- `runtime_ms`: Execution time for this test case
- `memory_kb`: Memory used in kilobytes
- `awarded_points`: Points earned from this test case (≤ test_case.points)

**Business Role:** Detailed execution results for each test case run. Used for grading and debugging.

**Composite Candidate Key:** (submission_id, test_case_id) — each test case runs once per submission

**Key Observations:**
- Sum of awarded_points across all test_results for a submission should equal submission.score
- Multiple rows per submission (one per test case tested)
- Runtime/memory/points vary per test case

---

### 11. **sessions** — Course Sessions
**Purpose:** Records scheduled course sessions (lectures, labs, tutorials).

**Columns:**
- `session_id` (PK): Unique session identifier
- `course_id` (FK → courses): Course this session belongs to
- `session_title`: Session title/description
- `session_date`: Date of session
- `session_type`: Type (lecture, lab, tutorial, practical, etc.)

**Business Role:** Defines course sessions for which attendance is tracked. Many students can attend each session, recorded in attendance table.

**Key Observations:**
- One session has many attendance records (one-to-many)
- No start_time/end_time (only date, not duration)
- session_type is free-form text (no enum constraint)

---

### 12. **attendance** — Session Attendance
**Purpose:** Records student attendance at course sessions.

**Columns:**
- `attendance_id` (PK): Unique attendance record identifier
- `session_id` (FK → sessions): Which session
- `student_id` (FK → students): Which student
- `attendance_status`: Status (present, absent, late, excused, etc.)
- `marked_at`: Timestamp when attendance was recorded

**Business Role:** Tracks who attended which sessions. Used for attendance reports and academic compliance.

**Composite Candidate Key:** (session_id, student_id) — one student's attendance per session

**Key Observations:**
- Attendance not limited to enrolled students (session_id doesn't validate enrollment in course)
- attendance_status is free-form (no enum constraint)
- marked_at could be different from session_date (recorded later)

---

### 13. **regrade_requests** — Submission Regrade Requests
**Purpose:** Records student requests to re-evaluate submissions.

**Columns:**
- `request_id` (PK): Unique regrade request identifier
- `submission_id` (FK → submissions): Which submission to regrade
- `student_id` (FK → students): Which student requested regrade
- `requested_at`: When request was made
- `reason`: Reason for regrade request
- `request_status`: Status (open, approved, rejected, closed)
- `resolved_at` (NULLABLE): When request was resolved

**Business Role:** Allows students to appeal submission scores if they believe there's an error.

**Data Quality Issues Observed:**
- RG0006: submission_id = SUB999999 which likely doesn't exist (orphan)
- resolved_at is NULL for open requests (correct) but also NULL for some approved (inconsistent)
- request_status "closed" could mean rejected or approved (ambiguous)

---

### 14. **plagiarism_flags** — Plagiarism Detection Flags
**Purpose:** Records similarity detection between pairs of submissions.

**Columns:**
- `flag_id` (PK): Unique flag identifier
- `submission_id` (FK → submissions): First submission
- `matched_submission_id` (FK → submissions): Second submission (similar to first)
- `similarity_score`: Percentage similarity (0-100)
- `flag_status`: Status (new, reviewing, confirmed, cleared)
- `created_at`: When similarity was detected

**Business Role:** Flags potentially plagiarized submissions for review.

**Key Observations:**
- Directional relationship: submission_id and matched_submission_id could be swapped
- Ideally, composite key (submission_id, matched_submission_id) but no uniqueness constraint
- similarity_score should be 0-100 (not enforced)

**Data Quality Issues:**
- PF0008: submission_id (SUB000274) = matched_submission_id (SUB000274) — flagging itself!
- Some flags never resolve (status remains "new")

---

### 15. **raw_student_import** — Staging Table for Student Imports
**Purpose:** Temporary staging table for bulk student imports; raw, potentially dirty data.

**Columns:**
- `raw_row_id` (PK): Staging row identifier
- `roll_number`: Student roll number from import
- `full_name`: Student name from import
- `email`: Email from import (potentially malformed)
- `batch_code`: Batch code reference (may not exist in batches table)
- `admission_date`: Admission date from import
- `import_status`: Status (new, validated, rejected, failed, duplicate)
- `import_notes`: Notes/error messages from validation

**Business Role:** Validates and stages student records before inserting into actual students table. Allows data quality checks.

**Data Quality Issues:**
- RSI0006: email = "bad-email-format" (not a valid email)
- RSI0008, RSI0009: batch_code = "CSE2099Z" (doesn't exist in batches)
- RSI0002, RSI0007: import_status = "rejected" with no import_notes explaining why

---

### 16. **operation_requests** — Administrative Data Change Requests
**Purpose:** Audit trail and approval workflow for administrative data modifications.

**Columns:**
- `operation_id` (PK): Unique operation identifier
- `requested_by`: Email/user who requested operation
- `operation_type`: Type of operation (INSERT, UPDATE, MERGE, DELETE, DROP, etc.)
- `target_table`: Table being modified (e.g., students, submissions)
- `target_record_id`: ID of record being modified
- `requested_at`: When operation was requested
- `reason`: Business reason for the operation
- `approval_status`: Status (pending, approved, rejected, executed)
- `executed_at` (NULLABLE): When operation was actually performed

**Business Role:** Provides audit trail for data modifications with approval workflow. Enables safe, traceable data changes.

**Key Observations:**
- Allows tracking who changed what and when
- approval_status and executed_at together show workflow progression
- operation_type is free-form (should be validated enum)
- target_record_id is free-form (not type-specific)

**Data Quality Issues:**
- OP0002: target_record_id = "R0000040" (not a valid student_id format for students table)
- OP0007: approved but executed_at is NULL (approved but never executed?)

---

## Cross-Table Relationship Summary

### One-to-Many Relationships:
- batches → students (one batch has many students)
- courses → enrollments (one course has many enrollments)
- courses → problems (one course has many problems)
- courses → contests (one course has many contests)
- courses → sessions (one course has many sessions)
- students → enrollments (one student enrolls in many courses)
- students → submissions (one student submits many solutions)
- students → attendance (one student attends many sessions)
- students → regrade_requests (one student can request many regrades)
- problems → test_cases (one problem has many test cases)
- problems → submissions (one problem receives many submissions)
- submissions → test_results (one submission has many test results)
- sessions → attendance (one session has many attendance records)

### Many-to-Many Relationships:
- contests ↔ problems (via contest_problems junction table)
- submissions ↔ plagiarism_flags (asymmetric: one submission can be flagged with many others)

### Optional Foreign Keys:
- submissions.contest_id — contest is optional (can submit outside contests)
- enrollments.final_grade — grade is optional (active enrollments may not have grades)
- students.email — email is optional
- regrade_requests.resolved_at — resolution time is optional (open requests not yet resolved)

---

## Data Quality and Normalization Observations

### Redundancy Examples:
1. **submission.status and test_results**: Submission status (Accepted/Wrong Answer) can be derived from test_results but is stored in submissions table for performance (denormalization tradeoff)
2. **submission.score and test_results.awarded_points**: Submission score should equal SUM(test_results.awarded_points) but both are stored (potential inconsistency)
3. **course_id appears in both problems and contests**: Both problems and contests reference courses independently; this allows contests to have problems from different courses (which may be intentional or problematic)

### Denormalization Tradeoffs:
- Storing submission.status and submission.score trades write complexity for read performance (avoid expensive aggregations)

### Referential Integrity Issues Detected:
- contests.course_id = C999 (doesn't exist)
- regrade_requests.submission_id = SUB999999 (likely doesn't exist)
- raw_student_import.batch_code references non-existent batches (CSE2099Z)
- plagiarism_flags.flag_id=PF0008 self-matches (submission_id = matched_submission_id)

### Missing Constraints:
- No CHECK for contest start_time < end_time
- No CHECK for submission.score ≤ problem.max_score
- No CHECK for test_case.points ≤ problem.max_score
- No CHECK for similarity_score in [0, 100]
- No CHECK for valid difficulty levels (Easy/Medium/Hard)
- No CHECK for valid statuses (open enum of acceptable values)

### Missing Uniqueness:
- problem_code should be UNIQUE but students.email is sometimes NULL (can't have unique constraint on nullable columns)
- course_code should be UNIQUE
- roll_number should be UNIQUE
- (student_id, course_id) should be UNIQUE in enrollments

