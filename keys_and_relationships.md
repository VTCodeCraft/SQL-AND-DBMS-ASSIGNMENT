# Keys, Relationships & Constraints Analysis

## 1. BATCHES Table

### Primary Key
- **PK: `batch_id`**
  - Why: Surrogate key, designed to uniquely identify each batch record
  - Type: String identifier (B001, B002, etc.)
  - Property: Immutable, system-generated

### Candidate Keys
- **CK1: `batch_code`**
  - Why: Business key, human-readable, intended to be unique (CSE2025A, AIML2025B, etc.)
  - Rationale: Enables meaningful batch reference by batch codes
  - Usage: Often used in imports and manual references

### Foreign Keys
- None (batches is a root entity)

### Constraints to Enforce
- **UNIQUE**: batch_code — only one batch per code
- **NOT NULL**: batch_id, batch_code, program, start_date, end_date, batch_status
- **CHECK**: batch_status IN ('active', 'completed', 'archived')
- **CHECK**: start_date ≤ end_date — batch cannot end before it starts
- **Partial KEY**: (batch_code) uniquely identifies a batch in any time period

---

## 2. COURSES Table

### Primary Key
- **PK: `course_id`**
  - Why: Surrogate key for system references
  - Type: String identifier (C001, C002, etc.)

### Candidate Keys
- **CK1: `course_code`**
  - Why: Natural business key (CS101, CS102, etc.)
  - Rationale: Codes are meaningful and stable across semesters
  - Usage: Preferred by faculty and students

### Foreign Keys
- None (courses is a root entity)

### Constraints to Enforce
- **UNIQUE**: course_code — only one course per code
- **NOT NULL**: course_id, course_code, course_title, course_status, credit_hours
- **CHECK**: course_status IN ('active', 'archived', 'draft')
- **CHECK**: credit_hours > 0 AND credit_hours ≤ 10 — reasonable credit range
- **CHECK**: credit_hours is an integer

---

## 3. STUDENTS Table

### Primary Key
- **PK: `student_id`**
  - Why: Surrogate key for system references
  - Type: String identifier (S0001, S0002, etc.)

### Candidate Keys
- **CK1: `roll_number`**
  - Why: Institutional roll number, unique per student, used in registrar systems
  - Rationale: Every student has a unique roll number
  - Usage: Primary business identifier in academic systems

- **CK2: `email`** (with caveat: can be NULL)
  - Why: Email is unique when present, serves as login identifier
  - Rationale: Non-NULL emails should be unique for authentication
  - **Design Note**: Cannot declare simple UNIQUE because email is nullable
  - **Solution**: Use UNIQUE WHERE email IS NOT NULL (PostgreSQL feature) or application-level validation

### Foreign Keys
- **FK: `batch_id` → batches.batch_id**
  - Why: Every student belongs to exactly one batch
  - Referential Integrity: Ensures student's batch exists
  - ON DELETE behavior: RESTRICT (cannot delete batch with enrolled students) or SET NULL (student becomes batchless)
  - ON UPDATE behavior: CASCADE (if batch_id changes, update student)

### Constraints to Enforce
- **UNIQUE**: roll_number — one student per roll number
- **UNIQUE PARTIAL**: email WHERE email IS NOT NULL — emails must be unique when provided
- **NOT NULL**: student_id, roll_number, full_name, batch_id, admission_date, enrollment_status
- **NULLABLE**: email (some students may not have email registered)
- **CHECK**: enrollment_status IN ('active', 'inactive', 'graduated', 'suspended')
- **CHECK**: graduation_year ≥ 2020 — reasonable graduation year bound
- **CHECK**: admission_date ≤ CURRENT_DATE — cannot admit from future

### Key Dependencies (Functional Dependencies)
- roll_number → student_id, full_name, email, batch_id (roll_number is a candidate key)
- email → student_id, roll_number (when email is not NULL)

---

## 4. ENROLLMENTS Table

### Primary Key
- **PK: `enrollment_id`**
  - Why: Surrogate key, system-generated unique identifier
  - Type: String identifier (E00001, E00002, etc.)
  - Usage: Used in regrade_requests as foreign key

### Candidate Keys
- **CK1: (student_id, course_id)**
  - Why: A student can enroll in each course at most once
  - Rationale: Composite natural key identifying unique enrollment
  - **Design Decision**: Could be primary key instead of enrollment_id, but surrogate chosen for flexibility

### Foreign Keys
- **FK: `student_id` → students.student_id**
  - Why: Enrollment must reference existing student
  - ON DELETE: CASCADE (delete enrollments if student deleted) or RESTRICT
  - ON UPDATE: CASCADE

- **FK: `course_id` → courses.course_id**
  - Why: Enrollment must reference existing course
  - ON DELETE: CASCADE or RESTRICT
  - ON UPDATE: CASCADE

### Constraints to Enforce
- **UNIQUE**: (student_id, course_id) — one enrollment per student-course pair
- **NOT NULL**: enrollment_id, student_id, course_id, enrolled_on, enrollment_status
- **NULLABLE**: final_grade (not assigned until course complete)
- **CHECK**: enrollment_status IN ('active', 'completed', 'dropped', 'suspended')
- **CHECK**: final_grade IN ('A', 'B', 'C', 'D', 'F', NULL) — valid grades only
- **CHECK**: enrolled_on ≤ CURRENT_DATE — cannot enroll from future
- **Conditional Logic**: If enrollment_status = 'completed', final_grade should NOT be NULL (application-level)

### Key Dependencies
- (student_id, course_id) → enrollment_id, enrolled_on, enrollment_status, final_grade (composite key)
- **Partial Dependency Issue**: final_grade depends on enrollment_status being 'completed', not on full composite key

---

## 5. PROBLEMS Table

### Primary Key
- **PK: `problem_id`**
  - Why: Surrogate key for system references
  - Type: String identifier (P0001, P0002, etc.)

### Candidate Keys
- **CK1: `problem_code`**
  - Why: Natural business key (CS101_P01, CS101_P02, etc.)
  - Rationale: Codes are human-readable and stable
  - Usage: Referenced in problem sheets and materials

### Foreign Keys
- **FK: `course_id` → courses.course_id**
  - Why: Problem must belong to a course
  - ON DELETE: CASCADE (delete problems if course deleted) or RESTRICT
  - ON UPDATE: CASCADE

### Constraints to Enforce
- **UNIQUE**: problem_code — one problem per code
- **NOT NULL**: problem_id, course_id, problem_code, title, difficulty, max_score, created_at, is_active
- **CHECK**: difficulty IN ('Easy', 'Medium', 'Hard')
- **CHECK**: max_score > 0 AND max_score ≤ 1000 — reasonable point limit
- **CHECK**: is_active IN (0, 1) — boolean flag
- **CHECK**: created_at ≤ CURRENT_TIMESTAMP — creation in past or now

### Key Dependencies
- problem_code → problem_id, course_id, title, difficulty, max_score

---

## 6. TEST_CASES Table

### Primary Key
- **PK: `test_case_id`**
  - Why: Surrogate key, system-generated
  - Type: String/numeric identifier (TC00001, TC00002, etc.)

### Candidate Keys
- **CK1: (problem_id, case_no)**
  - Why: Test case number is unique within a problem
  - Rationale: Problem P001 has test cases 1, 2, 3, ... all unique within P001
  - Design: Could be PK instead of test_case_id, but surrogate chosen for efficiency

### Foreign Keys
- **FK: `problem_id` → problems.problem_id**
  - Why: Test case must belong to a problem
  - ON DELETE: CASCADE (delete test cases if problem deleted)
  - ON UPDATE: CASCADE

### Constraints to Enforce
- **UNIQUE**: (problem_id, case_no) — composite candidate key
- **NOT NULL**: test_case_id, problem_id, case_no, input_label, expected_output_label, points, is_hidden
- **CHECK**: case_no ≥ 1 — case numbers start from 1
- **CHECK**: points > 0 — every test case awards points
- **CHECK**: points ≤ problem.max_score (cross-table constraint, application-level)
- **CHECK**: is_hidden IN (0, 1) — boolean flag
- **SUM Constraint**: SUM(points) for all test cases ≤ problem.max_score (business rule, not enforced at DB)

---

## 7. CONTESTS Table

### Primary Key
- **PK: `contest_id`**
  - Why: Surrogate key for system references
  - Type: String identifier (CT001, CT002, etc.)

### Candidate Keys
- None (no natural business key defined; contests could be distinguished by (course_id, contest_title, start_time) but not enforced)

### Foreign Keys
- **FK: `course_id` → courses.course_id**
  - Why: Contest must belong to a course
  - **DATA QUALITY ISSUE**: CT008 references C999 which doesn't exist
  - ON DELETE: CASCADE or RESTRICT
  - ON UPDATE: CASCADE

### Constraints to Enforce
- **NOT NULL**: contest_id, course_id, contest_title, start_time, end_time, contest_status
- **CHECK**: contest_status IN ('draft', 'scheduled', 'published', 'ongoing', 'completed')
- **CHECK**: start_time < end_time — contest must start before it ends
  - **DATA QUALITY ISSUE**: CT005 violates this (end before start)
- **CHECK**: start_time ≥ CURRENT_TIMESTAMP (for draft/scheduled) or relaxed for completed
- **CHECK**: If contest_status = 'completed', end_time < CURRENT_TIMESTAMP (business logic)

### Key Dependencies
- None clearly defined (no composite natural key)

---

## 8. CONTEST_PROBLEMS Table

### Primary Key
- **Composite PK: (contest_id, problem_id)**
  - Why: Each problem appears in a contest exactly once
  - Rationale: Uniqueness defined by contest + problem combination
  - Design: No surrogate key needed; composite PK is efficient

### Foreign Keys
- **FK: `contest_id` → contests.contest_id**
  - Why: Contest must exist
  - ON DELETE: CASCADE (delete contest_problem if contest deleted)
  - ON UPDATE: CASCADE

- **FK: `problem_id` → problems.problem_id**
  - Why: Problem must exist
  - ON DELETE: CASCADE (delete contest_problem if problem deleted)
  - ON UPDATE: CASCADE

### Constraints to Enforce
- **UNIQUE**: (contest_id, problem_id) — primary key
- **NOT NULL**: contest_id, problem_id, problem_order
- **CHECK**: problem_order ≥ 1 — ordering starts at 1
- **CHECK**: problem_order is unique within a contest (application-level or database trigger)

---

## 9. SUBMISSIONS Table

### Primary Key
- **PK: `submission_id`**
  - Why: Unique identifier for each submission
  - Type: String identifier (SUB000001, SUB000002, etc.)

### Candidate Keys
- None clearly defined; could argue (student_id, problem_id, submitted_at) is quasi-unique but multiple submissions are allowed

### Foreign Keys
- **FK: `student_id` → students.student_id**
  - Why: Submission must be from an existing student
  - ON DELETE: CASCADE (delete submissions if student deleted) or RESTRICT
  - ON UPDATE: CASCADE

- **FK: `problem_id` → problems.problem_id**
  - Why: Submission must be for an existing problem
  - ON DELETE: CASCADE or RESTRICT
  - ON UPDATE: CASCADE

- **FK: `contest_id` → contests.contest_id** (NULLABLE)
  - Why: Submission may be part of a contest (optional)
  - ON DELETE: SET NULL (submission persists even if contest deleted)
  - ON UPDATE: CASCADE
  - **Design Note**: NULLABLE allows submissions outside contests

### Constraints to Enforce
- **NOT NULL**: submission_id, student_id, problem_id, language, submitted_at, status, score, runtime_ms
- **NULLABLE**: contest_id, runtime_ms (could be NULL for compilation errors)
- **CHECK**: language IN ('C', 'C++', 'Java', 'Python', 'JavaScript', 'Go', 'Ruby', 'PHP', 'Rust')
- **CHECK**: status IN ('Accepted', 'Wrong Answer', 'Compilation Error', 'Runtime Error', 'Time Limit Exceeded', 'Partial Accepted')
- **CHECK**: score ≥ 0 AND score ≤ problem.max_score — score within bounds
- **CHECK**: runtime_ms ≥ 0 — non-negative runtime
- **CHECK**: submitted_at ≤ CURRENT_TIMESTAMP — cannot submit in future
- **DERIVED Constraint**: score = SUM(test_results.awarded_points) — should equal test results (not enforced)
- **DERIVED Constraint**: status should match test_results (e.g., if all passed, status='Accepted')

### Key Dependencies
- submission_id is a surrogate identifier with no obvious functional dependencies

---

## 10. TEST_RESULTS Table

### Primary Key
- **PK: `result_id`**
  - Why: Surrogate key for unique test result
  - Type: Numeric identifier (R0000001, R0000002, etc.)

### Candidate Keys
- **CK1: (submission_id, test_case_id)**
  - Why: One submission runs one test case exactly once, producing one result
  - Rationale: Each test case is executed once per submission
  - Could be PK instead of result_id, but result_id chosen for efficiency

### Foreign Keys
- **FK: `submission_id` → submissions.submission_id**
  - Why: Result must reference an existing submission
  - ON DELETE: CASCADE (delete results if submission deleted)
  - ON UPDATE: CASCADE

- **FK: `test_case_id` → test_cases.test_case_id**
  - Why: Result must reference an existing test case
  - ON DELETE: CASCADE or RESTRICT
  - ON UPDATE: CASCADE

### Constraints to Enforce
- **UNIQUE**: (submission_id, test_case_id) — composite candidate key
- **NOT NULL**: result_id, submission_id, test_case_id, result_status, runtime_ms, memory_kb, awarded_points
- **CHECK**: result_status IN ('Passed', 'Failed', 'Runtime Error', 'Time Limit Exceeded', 'Compilation Error', 'Wrong Answer')
- **CHECK**: runtime_ms ≥ 0 — non-negative runtime
- **CHECK**: memory_kb ≥ 0 — non-negative memory
- **CHECK**: awarded_points ≥ 0 AND awarded_points ≤ test_case.points — points within bounds
- **Derived Constraint**: If result_status = 'Passed', awarded_points = test_case.points (business logic)
- **Derived Constraint**: If result_status ≠ 'Passed', awarded_points = 0 (business logic)

### Key Dependencies
- (submission_id, test_case_id) → result_id, result_status, runtime_ms, memory_kb, awarded_points

---

## 11. SESSIONS Table

### Primary Key
- **PK: `session_id`**
  - Why: Unique session identifier
  - Type: String identifier (SES0001, SES0002, etc.)

### Candidate Keys
- **CK1: (course_id, session_date, session_type)**
  - Why: Uniquely identifies a session within a course on a date of a type
  - Rationale: A course typically has one lecture, one lab per session_date
  - Design Note: Not enforced, allowing duplicate sessions

### Foreign Keys
- **FK: `course_id` → courses.course_id**
  - Why: Session belongs to a course
  - ON DELETE: CASCADE (delete sessions if course deleted)
  - ON UPDATE: CASCADE

### Constraints to Enforce
- **NOT NULL**: session_id, course_id, session_title, session_date, session_type
- **CHECK**: session_type IN ('lecture', 'lab', 'tutorial', 'practical', 'discussion', 'seminar')
- **CHECK**: session_date ≤ CURRENT_DATE (session is in past or today)
- **SOFT Constraint**: (course_id, session_date, session_type) should be unique (not enforced)

---

## 12. ATTENDANCE Table

### Primary Key
- **PK: `attendance_id`**
  - Why: Surrogate key for unique attendance record
  - Type: String identifier (A000001, A000002, etc.)

### Candidate Keys
- **CK1: (session_id, student_id)**
  - Why: A student's attendance at a session is recorded once
  - Rationale: Composite natural key identifying unique attendance
  - Could be PK instead of attendance_id, but surrogate chosen

### Foreign Keys
- **FK: `session_id` → sessions.session_id**
  - Why: Attendance refers to an existing session
  - ON DELETE: CASCADE (delete attendance if session deleted)
  - ON UPDATE: CASCADE

- **FK: `student_id` → students.student_id**
  - Why: Attendance refers to an existing student
  - ON DELETE: CASCADE (delete attendance if student deleted)
  - ON UPDATE: CASCADE

### Constraints to Enforce
- **UNIQUE**: (session_id, student_id) — composite candidate key
- **NOT NULL**: attendance_id, session_id, student_id, attendance_status, marked_at
- **CHECK**: attendance_status IN ('present', 'absent', 'late', 'excused', 'unauthorized leave')
- **CHECK**: marked_at ≤ CURRENT_TIMESTAMP — marked in past or now
- **CHECK**: marked_at ≥ session.session_date (should be marked after/on session date)

---

## 13. REGRADE_REQUESTS Table

### Primary Key
- **PK: `request_id`**
  - Why: Unique regrade request identifier
  - Type: String identifier (RG0001, RG0002, etc.)

### Candidate Keys
- None clearly defined (could argue (submission_id, student_id) but multiple regrade requests per submission possible)

### Foreign Keys
- **FK: `submission_id` → submissions.submission_id**
  - Why: Request refers to a specific submission
  - **DATA QUALITY ISSUE**: RG0006 references SUB999999 (doesn't exist)
  - ON DELETE: CASCADE or RESTRICT
  - ON UPDATE: CASCADE

- **FK: `student_id` → students.student_id**
  - Why: Request is from a student
  - Redundancy: student_id is redundant (can be derived from submission_id via submissions table)
  - Purpose: Denormalization for query performance
  - ON DELETE: CASCADE or RESTRICT
  - ON UPDATE: CASCADE

### Constraints to Enforce
- **NOT NULL**: request_id, submission_id, student_id, requested_at, reason, request_status
- **NULLABLE**: resolved_at (NULL while open, filled when resolved)
- **CHECK**: request_status IN ('open', 'approved', 'rejected', 'closed')
- **CHECK**: requested_at ≤ CURRENT_TIMESTAMP — request in past
- **CHECK**: resolved_at IS NULL OR resolved_at ≥ requested_at — resolution after request
- **CHECK**: If request_status = 'open', resolved_at IS NULL
- **CHECK**: If request_status IN ('approved', 'rejected', 'closed'), resolved_at IS NOT NULL
- **REFERENTIAL CONSTRAINT**: student_id in regrade request must match student_id in referenced submission (cross-table, application-level)

### Partial Dependency
- Final grade depends on request_status; if 'approved', new score should be assigned

---

## 14. PLAGIARISM_FLAGS Table

### Primary Key
- **PK: `flag_id`**
  - Why: Unique flag identifier
  - Type: String identifier (PF0001, PF0002, etc.)

### Candidate Keys
- **CK1: (submission_id, matched_submission_id)**
  - Why: Flag comparing submission pair; ideally one flag per ordered pair
  - Design Note: Not enforced; same pair could be flagged multiple times
  - **DATA QUALITY ISSUE**: PF0008 has submission_id = matched_submission_id (self-plagiarism, invalid)

### Foreign Keys
- **FK: `submission_id` → submissions.submission_id**
  - Why: Flag refers to first submission
  - ON DELETE: CASCADE
  - ON UPDATE: CASCADE

- **FK: `matched_submission_id` → submissions.submission_id**
  - Why: Flag refers to matched/compared submission
  - ON DELETE: CASCADE
  - ON UPDATE: CASCADE

### Constraints to Enforce
- **NOT NULL**: flag_id, submission_id, matched_submission_id, similarity_score, flag_status, created_at
- **CHECK**: submission_id ≠ matched_submission_id — cannot flag self-plagiarism (prevents self-matches)
- **CHECK**: similarity_score >= 0 AND similarity_score ≤ 100 — valid percentage
- **CHECK**: flag_status IN ('new', 'reviewing', 'confirmed', 'cleared')
- **CHECK**: created_at ≤ CURRENT_TIMESTAMP — flag created in past
- **ORDERING Constraint**: Ideally MIN(submission_id, matched_submission_id) always paired with MAX version (not enforced)

---

## 15. RAW_STUDENT_IMPORT Table

### Primary Key
- **PK: `raw_row_id`**
  - Why: Staging table row identifier
  - Type: String identifier (RSI0001, RSI0002, etc.)

### Candidate Keys
- None for staging table (intentionally raw and dirty)

### Foreign Keys
- No FK constraints (staging table, not yet validated)
- **Logical Link** (not enforced): batch_code should exist in batches.batch_code
- **Logical Link** (not enforced): email should be valid format

### Constraints to Enforce
- **NOT NULL**: raw_row_id, roll_number, full_name, batch_code, admission_date, import_status
- **NULLABLE**: email (students without email)
- **CHECK**: import_status IN ('new', 'validated', 'rejected', 'failed', 'duplicate', 'imported')
- **Pattern Validation**: email should match email regex (application-level)
- **Pattern Validation**: roll_number should follow format (application-level)
- **NO UNIQUE constraints** (staging table, may have intentional duplicates for reprocessing)

### Design Rationale
- No foreign key constraints (staging table is deliberately loose)
- Allows import of records with non-existent batch_code for later review
- Allows malformed emails for validation and correction workflow
- import_status tracks pipeline progression

---

## 16. OPERATION_REQUESTS Table

### Primary Key
- **PK: `operation_id`**
  - Why: Unique operation request identifier
  - Type: String identifier (OP0001, OP0002, etc.)

### Candidate Keys
- None clearly defined

### Foreign Keys
- None (audit trail table, doesn't reference operational data)

### Constraints to Enforce
- **NOT NULL**: operation_id, requested_by, operation_type, target_table, target_record_id, requested_at, reason, approval_status
- **NULLABLE**: executed_at (NULL if not yet executed)
- **CHECK**: operation_type IN ('INSERT', 'UPDATE', 'MERGE', 'DELETE', 'DROP', 'RESTORE')
- **CHECK**: target_table IN ('students', 'enrollments', 'submissions', 'test_results', 'problems', 'courses', 'contests', 'sessions', 'attendance', 'regrade_requests', 'plagiarism_flags')
- **CHECK**: approval_status IN ('pending', 'approved', 'rejected', 'executed')
- **CHECK**: requested_at ≤ CURRENT_TIMESTAMP
- **CHECK**: executed_at IS NULL OR executed_at ≥ requested_at
- **CHECK**: If approval_status = 'pending', executed_at IS NULL
- **CHECK**: If approval_status = 'approved', executed_at may be NULL or NOT NULL
- **CHECK**: If approval_status = 'executed', executed_at IS NOT NULL

---

## Summary: Key Strength & Constraints

| Table | PK Type | Natural Key(s) | FKs | Critical Constraints |
|-------|---------|----------------|-----|----------------------|
| batches | Surrogate (batch_id) | batch_code | None | UNIQUE(batch_code), start_date < end_date |
| courses | Surrogate (course_id) | course_code | None | UNIQUE(course_code), credit_hours > 0 |
| students | Surrogate (student_id) | roll_number, email* | batch_id | UNIQUE(roll_number), UNIQUE(email) WHERE NOT NULL |
| enrollments | Surrogate (enrollment_id) | (student_id, course_id) | student_id, course_id | UNIQUE(student_id, course_id) |
| problems | Surrogate (problem_id) | problem_code | course_id | UNIQUE(problem_code), difficulty valid, max_score > 0 |
| test_cases | Surrogate (test_case_id) | (problem_id, case_no) | problem_id | UNIQUE(problem_id, case_no), points > 0 |
| contests | Surrogate (contest_id) | None | course_id | start_time < end_time, status valid |
| contest_problems | Composite (contest_id, problem_id) | N/A | contest_id, problem_id | problem_order ≥ 1 |
| submissions | Surrogate (submission_id) | None | student_id, problem_id, contest_id | score ≤ max_score, status valid |
| test_results | Surrogate (result_id) | (submission_id, test_case_id) | submission_id, test_case_id | awarded_points ≤ points |
| sessions | Surrogate (session_id) | (course_id, session_date, session_type) | course_id | session_type valid, session_date valid |
| attendance | Surrogate (attendance_id) | (session_id, student_id) | session_id, student_id | UNIQUE(session_id, student_id), status valid |
| regrade_requests | Surrogate (request_id) | None | submission_id, student_id | status valid, resolved_at >= requested_at if not open |
| plagiarism_flags | Surrogate (flag_id) | (submission_id, matched_submission_id) | submission_id, matched_submission_id | submission_id ≠ matched_submission_id, similarity 0-100 |
| raw_student_import | Surrogate (raw_row_id) | None | None (staging) | NO constraints (intentionally loose) |
| operation_requests | Surrogate (operation_id) | None | None | operation_type valid, approval_status valid |

