-- ============================================================================
-- CodeJudge Database Schema - PostgreSQL DDL
-- ============================================================================
-- This SQL file defines the complete relational database schema for the
-- CodeJudge online coding practice and evaluation platform.
--
-- Design Principles:
-- 1. Approximately 3NF with justified denormalizations for performance
-- 2. Explicit constraints enforce data integrity
-- 3. Foreign key constraints maintain referential integrity
-- 4. Check constraints validate domain rules
-- 5. Triggers maintain denormalized values (score, status)
--
-- Execution: psql -U postgres -d codejudge -f schema.sql
-- ============================================================================

-- Drop existing schema if it exists (for clean re-creation)
DROP SCHEMA IF EXISTS public CASCADE;
CREATE SCHEMA public;

-- ============================================================================
-- 1. BATCHES TABLE
-- ============================================================================
-- Purpose: Academic cohorts/batches of students
-- Represents groups of students enrolled in a program during a term
--
CREATE TABLE batches (
  batch_id VARCHAR(10) PRIMARY KEY,
  batch_code VARCHAR(20) NOT NULL UNIQUE,
  program VARCHAR(50) NOT NULL,
  start_date DATE NOT NULL,
  end_date DATE NOT NULL,
  batch_status VARCHAR(20) NOT NULL DEFAULT 'active',
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  
  -- Constraints
  CONSTRAINT check_batch_dates CHECK (start_date <= end_date),
  CONSTRAINT check_batch_status CHECK (batch_status IN ('active', 'completed', 'archived')),
  CONSTRAINT check_batch_code_not_empty CHECK (TRIM(batch_code) != '')
);

CREATE INDEX idx_batches_status ON batches(batch_status);

-- ============================================================================
-- 2. COURSES TABLE
-- ============================================================================
-- Purpose: Course catalog
-- Defines all courses offered on the platform
--
CREATE TABLE courses (
  course_id VARCHAR(10) PRIMARY KEY,
  course_code VARCHAR(20) NOT NULL UNIQUE,
  course_title VARCHAR(100) NOT NULL,
  course_status VARCHAR(20) NOT NULL DEFAULT 'active',
  credit_hours SMALLINT NOT NULL DEFAULT 3,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  
  -- Constraints
  CONSTRAINT check_course_status CHECK (course_status IN ('active', 'archived', 'draft')),
  CONSTRAINT check_credit_hours CHECK (credit_hours > 0 AND credit_hours <= 10),
  CONSTRAINT check_course_code_not_empty CHECK (TRIM(course_code) != '')
);

CREATE INDEX idx_courses_status ON courses(course_status);
CREATE INDEX idx_courses_code ON courses(course_code);

-- ============================================================================
-- 3. STUDENTS TABLE
-- ============================================================================
-- Purpose: Student master data
-- Core entity representing all students using the platform
--
CREATE TABLE students (
  student_id VARCHAR(10) PRIMARY KEY,
  roll_number VARCHAR(30) NOT NULL UNIQUE,
  full_name VARCHAR(100) NOT NULL,
  email VARCHAR(100),
  batch_id VARCHAR(10) NOT NULL REFERENCES batches(batch_id) ON DELETE RESTRICT ON UPDATE CASCADE,
  admission_date DATE NOT NULL,
  enrollment_status VARCHAR(20) NOT NULL DEFAULT 'active',
  graduation_year SMALLINT,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  
  -- Constraints
  CONSTRAINT check_enrollment_status CHECK (enrollment_status IN ('active', 'inactive', 'graduated', 'suspended')),
  CONSTRAINT check_graduation_year CHECK (graduation_year >= 2020),
  CONSTRAINT check_admission_date CHECK (admission_date <= CURRENT_DATE),
  CONSTRAINT check_full_name_not_empty CHECK (TRIM(full_name) != '')
);

-- Partial unique index for email (allows multiple NULLs)
CREATE UNIQUE INDEX idx_students_email ON students(email) WHERE email IS NOT NULL;
CREATE INDEX idx_students_batch_id ON students(batch_id);
CREATE INDEX idx_students_status ON students(enrollment_status);
CREATE INDEX idx_students_roll_number ON students(roll_number);

-- ============================================================================
-- 4. ENROLLMENTS TABLE
-- ============================================================================
-- Purpose: Student-Course many-to-many relationship
-- Records each student's enrollment in each course with final grade
--
CREATE TABLE enrollments (
  enrollment_id VARCHAR(10) PRIMARY KEY,
  student_id VARCHAR(10) NOT NULL REFERENCES students(student_id) ON DELETE CASCADE ON UPDATE CASCADE,
  course_id VARCHAR(10) NOT NULL REFERENCES courses(course_id) ON DELETE CASCADE ON UPDATE CASCADE,
  enrolled_on DATE NOT NULL,
  enrollment_status VARCHAR(20) NOT NULL DEFAULT 'active',
  final_grade CHAR(1),
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  
  -- Constraints
  CONSTRAINT check_enrollment_status_values CHECK (enrollment_status IN ('active', 'completed', 'dropped', 'suspended')),
  CONSTRAINT check_final_grade CHECK (final_grade IS NULL OR final_grade IN ('A', 'B', 'C', 'D', 'F')),
  CONSTRAINT check_enrolled_date CHECK (enrolled_on <= CURRENT_DATE),
  CONSTRAINT unique_student_course UNIQUE(student_id, course_id)
);

CREATE INDEX idx_enrollments_student_id ON enrollments(student_id);
CREATE INDEX idx_enrollments_course_id ON enrollments(course_id);
CREATE INDEX idx_enrollments_status ON enrollments(enrollment_status);

-- ============================================================================
-- 5. PROBLEMS TABLE
-- ============================================================================
-- Purpose: Programming problems
-- Defines coding problems linked to courses
--
CREATE TABLE problems (
  problem_id VARCHAR(10) PRIMARY KEY,
  course_id VARCHAR(10) NOT NULL REFERENCES courses(course_id) ON DELETE CASCADE ON UPDATE CASCADE,
  problem_code VARCHAR(30) NOT NULL UNIQUE,
  title VARCHAR(150) NOT NULL,
  difficulty VARCHAR(20) NOT NULL,
  max_score SMALLINT NOT NULL,
  created_at TIMESTAMP NOT NULL,
  is_active SMALLINT NOT NULL DEFAULT 1,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  
  -- Constraints
  CONSTRAINT check_difficulty CHECK (difficulty IN ('Easy', 'Medium', 'Hard')),
  CONSTRAINT check_max_score CHECK (max_score > 0 AND max_score <= 1000),
  CONSTRAINT check_is_active CHECK (is_active IN (0, 1)),
  CONSTRAINT check_problem_code_not_empty CHECK (TRIM(problem_code) != ''),
  CONSTRAINT check_title_not_empty CHECK (TRIM(title) != '')
);

CREATE INDEX idx_problems_course_id ON problems(course_id);
CREATE INDEX idx_problems_difficulty ON problems(difficulty);
CREATE INDEX idx_problems_active ON problems(is_active);
CREATE INDEX idx_problems_code ON problems(problem_code);

-- ============================================================================
-- 6. TEST_CASES TABLE
-- ============================================================================
-- Purpose: Test cases for problems
-- Defines input/output validation criteria for submissions
--
CREATE TABLE test_cases (
  test_case_id VARCHAR(10) PRIMARY KEY,
  problem_id VARCHAR(10) NOT NULL REFERENCES problems(problem_id) ON DELETE CASCADE ON UPDATE CASCADE,
  case_no SMALLINT NOT NULL,
  input_label VARCHAR(50) NOT NULL,
  expected_output_label VARCHAR(50) NOT NULL,
  points SMALLINT NOT NULL,
  is_hidden SMALLINT NOT NULL DEFAULT 0,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  
  -- Constraints
  CONSTRAINT check_case_no CHECK (case_no >= 1),
  CONSTRAINT check_points CHECK (points > 0 AND points <= 500),
  CONSTRAINT check_is_hidden CHECK (is_hidden IN (0, 1)),
  CONSTRAINT unique_problem_case UNIQUE(problem_id, case_no)
);

CREATE INDEX idx_test_cases_problem_id ON test_cases(problem_id);

-- ============================================================================
-- 7. CONTESTS TABLE
-- ============================================================================
-- Purpose: Coding contests/evaluations
-- Represents time-bounded contests within courses
--
CREATE TABLE contests (
  contest_id VARCHAR(10) PRIMARY KEY,
  course_id VARCHAR(10) NOT NULL REFERENCES courses(course_id) ON DELETE RESTRICT ON UPDATE CASCADE,
  contest_title VARCHAR(150) NOT NULL,
  start_time TIMESTAMP NOT NULL,
  end_time TIMESTAMP NOT NULL,
  contest_status VARCHAR(20) NOT NULL DEFAULT 'draft',
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  
  -- Constraints
  CONSTRAINT check_contest_time CHECK (start_time < end_time),
  CONSTRAINT check_contest_status CHECK (contest_status IN ('draft', 'scheduled', 'published', 'ongoing', 'completed')),
  CONSTRAINT check_contest_title_not_empty CHECK (TRIM(contest_title) != '')
);

CREATE INDEX idx_contests_course_id ON contests(course_id);
CREATE INDEX idx_contests_status ON contests(contest_status);
CREATE INDEX idx_contests_times ON contests(start_time, end_time);

-- ============================================================================
-- 8. CONTEST_PROBLEMS TABLE (Bridge/Junction Table)
-- ============================================================================
-- Purpose: Many-to-many relationship between contests and problems
-- Defines which problems are included in which contests
--
CREATE TABLE contest_problems (
  contest_id VARCHAR(10) NOT NULL REFERENCES contests(contest_id) ON DELETE CASCADE ON UPDATE CASCADE,
  problem_id VARCHAR(10) NOT NULL REFERENCES problems(problem_id) ON DELETE CASCADE ON UPDATE CASCADE,
  problem_order SMALLINT NOT NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  
  -- Constraints
  PRIMARY KEY(contest_id, problem_id),
  CONSTRAINT check_problem_order CHECK (problem_order >= 1)
);

CREATE INDEX idx_contest_problems_problem_id ON contest_problems(problem_id);

-- ============================================================================
-- 9. SUBMISSIONS TABLE
-- ============================================================================
-- Purpose: Student code submissions
-- Records each submission of code against a problem
--
-- NOTE: score field is DENORMALIZED from test_results for performance.
-- Consistency maintained via triggers on test_results changes.
--
CREATE TABLE submissions (
  submission_id VARCHAR(15) PRIMARY KEY,
  student_id VARCHAR(10) NOT NULL REFERENCES students(student_id) ON DELETE CASCADE ON UPDATE CASCADE,
  problem_id VARCHAR(10) NOT NULL REFERENCES problems(problem_id) ON DELETE CASCADE ON UPDATE CASCADE,
  contest_id VARCHAR(10) REFERENCES contests(contest_id) ON DELETE SET NULL ON UPDATE CASCADE,
  language VARCHAR(20) NOT NULL,
  submitted_at TIMESTAMP NOT NULL,
  status VARCHAR(30) NOT NULL,
  score SMALLINT NOT NULL DEFAULT 0,
  runtime_ms INTEGER,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  
  -- Constraints
  CONSTRAINT check_language CHECK (language IN ('C', 'C++', 'Java', 'Python', 'JavaScript', 'Go', 'Ruby', 'PHP', 'Rust', 'Kotlin', 'C#', 'Swift')),
  CONSTRAINT check_submission_status CHECK (status IN ('Accepted', 'Wrong Answer', 'Compilation Error', 'Runtime Error', 'Time Limit Exceeded', 'Partial Accepted', 'Waiting', 'Judging')),
  CONSTRAINT check_score CHECK (score >= 0 AND score <= 1000),
  CONSTRAINT check_runtime_ms CHECK (runtime_ms IS NULL OR runtime_ms >= 0),
  CONSTRAINT check_submitted_time CHECK (submitted_at <= CURRENT_TIMESTAMP)
);

CREATE INDEX idx_submissions_student_id ON submissions(student_id);
CREATE INDEX idx_submissions_problem_id ON submissions(problem_id);
CREATE INDEX idx_submissions_contest_id ON submissions(contest_id);
CREATE INDEX idx_submissions_status ON submissions(status);
CREATE INDEX idx_submissions_submitted_at ON submissions(submitted_at DESC);
CREATE INDEX idx_submissions_student_submitted ON submissions(student_id, submitted_at DESC);

-- ============================================================================
-- 10. TEST_RESULTS TABLE
-- ============================================================================
-- Purpose: Execution results for individual test cases
-- Records detailed results of running test cases against submissions
--
CREATE TABLE test_results (
  result_id VARCHAR(10) PRIMARY KEY,
  submission_id VARCHAR(15) NOT NULL REFERENCES submissions(submission_id) ON DELETE CASCADE ON UPDATE CASCADE,
  test_case_id VARCHAR(10) NOT NULL REFERENCES test_cases(test_case_id) ON DELETE CASCADE ON UPDATE CASCADE,
  result_status VARCHAR(30) NOT NULL,
  runtime_ms INTEGER NOT NULL,
  memory_kb INTEGER NOT NULL,
  awarded_points SMALLINT NOT NULL DEFAULT 0,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  
  -- Constraints
  CONSTRAINT check_result_status CHECK (result_status IN ('Passed', 'Failed', 'Runtime Error', 'Time Limit Exceeded', 'Memory Limit Exceeded', 'Compilation Error', 'Presentation Error', 'Wrong Answer')),
  CONSTRAINT check_runtime CHECK (runtime_ms >= 0),
  CONSTRAINT check_memory CHECK (memory_kb >= 0),
  CONSTRAINT check_awarded_points CHECK (awarded_points >= 0 AND awarded_points <= 500),
  CONSTRAINT unique_submission_testcase UNIQUE(submission_id, test_case_id)
);

CREATE INDEX idx_test_results_submission_id ON test_results(submission_id);
CREATE INDEX idx_test_results_test_case_id ON test_results(test_case_id);
CREATE INDEX idx_test_results_status ON test_results(result_status);

-- ============================================================================
-- 11. SESSIONS TABLE
-- ============================================================================
-- Purpose: Course sessions (lectures, labs, tutorials)
-- Tracks scheduled sessions for which attendance is recorded
--
CREATE TABLE sessions (
  session_id VARCHAR(10) PRIMARY KEY,
  course_id VARCHAR(10) NOT NULL REFERENCES courses(course_id) ON DELETE CASCADE ON UPDATE CASCADE,
  session_title VARCHAR(100) NOT NULL,
  session_date DATE NOT NULL,
  session_type VARCHAR(30) NOT NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  
  -- Constraints
  CONSTRAINT check_session_type CHECK (session_type IN ('lecture', 'lab', 'tutorial', 'practical', 'discussion', 'seminar', 'workshop')),
  CONSTRAINT check_session_date CHECK (session_date <= CURRENT_DATE),
  CONSTRAINT check_session_title_not_empty CHECK (TRIM(session_title) != '')
);

CREATE INDEX idx_sessions_course_id ON sessions(course_id);
CREATE INDEX idx_sessions_date ON sessions(session_date DESC);
CREATE INDEX idx_sessions_type ON sessions(session_type);

-- ============================================================================
-- 12. ATTENDANCE TABLE
-- ============================================================================
-- Purpose: Session attendance tracking
-- Records student attendance at course sessions
--
CREATE TABLE attendance (
  attendance_id VARCHAR(10) PRIMARY KEY,
  session_id VARCHAR(10) NOT NULL REFERENCES sessions(session_id) ON DELETE CASCADE ON UPDATE CASCADE,
  student_id VARCHAR(10) NOT NULL REFERENCES students(student_id) ON DELETE CASCADE ON UPDATE CASCADE,
  attendance_status VARCHAR(20) NOT NULL DEFAULT 'absent',
  marked_at TIMESTAMP NOT NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  
  -- Constraints
  CONSTRAINT check_attendance_status CHECK (attendance_status IN ('present', 'absent', 'late', 'excused', 'unauthorized leave')),
  CONSTRAINT check_marked_time CHECK (marked_at <= CURRENT_TIMESTAMP),
  CONSTRAINT unique_session_student UNIQUE(session_id, student_id)
);

CREATE INDEX idx_attendance_session_id ON attendance(session_id);
CREATE INDEX idx_attendance_student_id ON attendance(student_id);
CREATE INDEX idx_attendance_status ON attendance(attendance_status);

-- ============================================================================
-- 13. REGRADE_REQUESTS TABLE
-- ============================================================================
-- Purpose: Submission regrade workflow
-- Records student requests to re-evaluate submission scores
--
-- NOTE: student_id is DENORMALIZED from submissions table for performance
-- and to enable validation that student matches submission's student.
--
CREATE TABLE regrade_requests (
  request_id VARCHAR(10) PRIMARY KEY,
  submission_id VARCHAR(15) NOT NULL REFERENCES submissions(submission_id) ON DELETE CASCADE ON UPDATE CASCADE,
  student_id VARCHAR(10) NOT NULL REFERENCES students(student_id) ON DELETE CASCADE ON UPDATE CASCADE,
  requested_at TIMESTAMP NOT NULL,
  reason VARCHAR(200) NOT NULL,
  request_status VARCHAR(20) NOT NULL DEFAULT 'open',
  resolved_at TIMESTAMP,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  
  -- Constraints
  CONSTRAINT check_request_status CHECK (request_status IN ('open', 'approved', 'rejected', 'closed')),
  CONSTRAINT check_requested_time CHECK (requested_at <= CURRENT_TIMESTAMP),
  CONSTRAINT check_resolved_time CHECK (resolved_at IS NULL OR resolved_at >= requested_at),
  CONSTRAINT check_open_not_resolved CHECK (request_status = 'open' OR resolved_at IS NOT NULL),
  CONSTRAINT check_reason_not_empty CHECK (TRIM(reason) != '')
);

CREATE INDEX idx_regrade_requests_submission_id ON regrade_requests(submission_id);
CREATE INDEX idx_regrade_requests_student_id ON regrade_requests(student_id);
CREATE INDEX idx_regrade_requests_status ON regrade_requests(request_status);

-- ============================================================================
-- 14. PLAGIARISM_FLAGS TABLE
-- ============================================================================
-- Purpose: Plagiarism detection and review workflow
-- Records similarity flags between pairs of submissions
--
CREATE TABLE plagiarism_flags (
  flag_id VARCHAR(10) PRIMARY KEY,
  submission_id VARCHAR(15) NOT NULL REFERENCES submissions(submission_id) ON DELETE CASCADE ON UPDATE CASCADE,
  matched_submission_id VARCHAR(15) NOT NULL REFERENCES submissions(submission_id) ON DELETE CASCADE ON UPDATE CASCADE,
  similarity_score NUMERIC(5, 2) NOT NULL,
  flag_status VARCHAR(20) NOT NULL DEFAULT 'new',
  created_at TIMESTAMP NOT NULL,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  
  -- Constraints
  CONSTRAINT check_similarity_score CHECK (similarity_score >= 0 AND similarity_score <= 100),
  CONSTRAINT check_flag_status CHECK (flag_status IN ('new', 'reviewing', 'confirmed', 'cleared', 'false positive')),
  CONSTRAINT check_not_self_plagiarism CHECK (submission_id != matched_submission_id)
);

CREATE INDEX idx_plagiarism_flags_submission_id ON plagiarism_flags(submission_id);
CREATE INDEX idx_plagiarism_flags_matched_id ON plagiarism_flags(matched_submission_id);
CREATE INDEX idx_plagiarism_flags_status ON plagiarism_flags(flag_status);
CREATE INDEX idx_plagiarism_flags_score ON plagiarism_flags(similarity_score DESC);

-- ============================================================================
-- 15. RAW_STUDENT_IMPORT TABLE (Staging Table)
-- ============================================================================
-- Purpose: Staging for bulk student imports
-- Temporarily holds raw import data for validation before migrating to students
--
-- DESIGN NOTE: Intentionally has NO constraints; validates data before accepting
--
CREATE TABLE raw_student_import (
  raw_row_id VARCHAR(10) PRIMARY KEY,
  roll_number VARCHAR(30),
  full_name VARCHAR(100),
  email VARCHAR(100),
  batch_code VARCHAR(20),
  admission_date DATE,
  import_status VARCHAR(20) NOT NULL DEFAULT 'new',
  import_notes TEXT,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  processed_at TIMESTAMP
  
  -- NO constraints in staging table; validated before acceptance
);

CREATE INDEX idx_raw_import_status ON raw_student_import(import_status);
CREATE INDEX idx_raw_import_email ON raw_student_import(email);
CREATE INDEX idx_raw_import_roll ON raw_student_import(roll_number);

-- ============================================================================
-- 16. OPERATION_REQUESTS TABLE (Audit Trail)
-- ============================================================================
-- Purpose: Audit trail for administrative data changes
-- Records and tracks all administrative modify operations (INSERT, UPDATE, DELETE)
--
CREATE TABLE operation_requests (
  operation_id VARCHAR(10) PRIMARY KEY,
  requested_by VARCHAR(100) NOT NULL,
  operation_type VARCHAR(20) NOT NULL,
  target_table VARCHAR(50) NOT NULL,
  target_record_id VARCHAR(50) NOT NULL,
  requested_at TIMESTAMP NOT NULL,
  reason VARCHAR(200) NOT NULL,
  approval_status VARCHAR(20) NOT NULL DEFAULT 'pending',
  executed_at TIMESTAMP,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  
  -- Constraints
  CONSTRAINT check_operation_type CHECK (operation_type IN ('INSERT', 'UPDATE', 'MERGE', 'DELETE', 'DROP', 'RESTORE', 'BULK_IMPORT')),
  CONSTRAINT check_target_table CHECK (target_table IN ('students', 'enrollments', 'submissions', 'test_results', 'problems', 'courses', 'contests', 'sessions', 'attendance', 'regrade_requests', 'plagiarism_flags', 'batches')),
  CONSTRAINT check_approval_status CHECK (approval_status IN ('pending', 'approved', 'rejected', 'executed', 'failed')),
  CONSTRAINT check_operation_time CHECK (executed_at IS NULL OR executed_at >= requested_at),
  CONSTRAINT check_reason_not_empty CHECK (TRIM(reason) != '')
);

CREATE INDEX idx_operation_requests_status ON operation_requests(approval_status);
CREATE INDEX idx_operation_requests_table ON operation_requests(target_table);
CREATE INDEX idx_operation_requests_requested_at ON operation_requests(requested_at DESC);
CREATE INDEX idx_operation_requests_requested_by ON operation_requests(requested_by);

-- ============================================================================
-- VIEWS FOR COMMON QUERIES
-- ============================================================================

-- View: Active Students with Current Batch
CREATE VIEW vw_active_students_with_batch AS
SELECT 
  s.student_id,
  s.roll_number,
  s.full_name,
  s.email,
  b.batch_id,
  b.batch_code,
  b.program
FROM students s
JOIN batches b ON s.batch_id = b.batch_id
WHERE s.enrollment_status = 'active';

-- View: Student Enrollments with Course Details
CREATE VIEW vw_student_enrollments AS
SELECT 
  e.enrollment_id,
  s.student_id,
  s.full_name,
  c.course_id,
  c.course_code,
  c.course_title,
  e.enrolled_on,
  e.enrollment_status,
  e.final_grade
FROM enrollments e
JOIN students s ON e.student_id = s.student_id
JOIN courses c ON e.course_id = c.course_id;

-- View: Problem Statistics
CREATE VIEW vw_problem_statistics AS
SELECT 
  p.problem_id,
  p.problem_code,
  p.title,
  p.difficulty,
  p.max_score,
  COUNT(DISTINCT s.submission_id) AS submission_count,
  SUM(CASE WHEN s.status = 'Accepted' THEN 1 ELSE 0 END) AS accepted_count,
  ROUND(AVG(s.score), 2) AS avg_score
FROM problems p
LEFT JOIN submissions s ON p.problem_id = s.problem_id
GROUP BY p.problem_id, p.problem_code, p.title, p.difficulty, p.max_score;

-- View: Recent Submissions with Details
CREATE VIEW vw_recent_submissions AS
SELECT 
  sub.submission_id,
  s.student_id,
  s.full_name,
  p.problem_code,
  p.title,
  sub.language,
  sub.submitted_at,
  sub.status,
  sub.score,
  sub.runtime_ms
FROM submissions sub
JOIN students s ON sub.student_id = s.student_id
JOIN problems p ON sub.problem_id = p.problem_id
ORDER BY sub.submitted_at DESC;

-- ============================================================================
-- END OF SCHEMA DEFINITION
-- ============================================================================

-- Sample comment for execution feedback:
-- Execute this file with: psql -U postgres -d codejudge -f schema.sql
-- All tables will be created with appropriate constraints and indexes.

