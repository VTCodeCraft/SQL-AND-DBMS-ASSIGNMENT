# Design Assumptions & Rationale

## Overview
This document explains design decisions, assumptions, and their justifications. These assumptions address ambiguities in the raw CSV data and establish clear boundaries for the normalized schema.

---

## Section 1: Data Type Assumptions

### 1.1 String-based Identifiers
**Assumption:** All IDs (student_id, course_id, submission_id, etc.) are VARCHAR strings, not integers.

**Evidence from Data:**
```
student_id: S0001, S0002, S0282 (string prefix)
batch_id: B001, B002 (string prefix)
problem_id: P0001, P0043 (string prefix)
submission_id: SUB000001, SUB999999 (string prefix)
test_case_id: TC00001 (string prefix)
```

**Rationale:**
- String IDs contain semantic information (S = student, P = problem, CT = contest)
- Easier for humans to read and understand context
- More flexible for future ID scheme changes
- Some IDs like "SUB000001" cannot fit typical 32-bit integers cleanly

**Database Type Chosen:** VARCHAR(10) or VARCHAR(15) as appropriate

---

### 1.2 Boolean Flags as SMALLINT(0,1)
**Assumption:** Boolean fields (is_active, is_hidden) stored as SMALLINT with CHECK constraint.

**Evidence from Data:**
```
problems.is_active: 1, 0 (numeric values)
test_cases.is_hidden: 0, 1 (numeric values)
```

**Rationale:**
- Raw CSV contains 0 and 1 (integer, not text boolean)
- PostgreSQL BOOLEAN would require conversion
- Numeric storage aligns with source data format
- Check constraint enforces domain: CHECK (is_active IN (0, 1))

**Database Type Chosen:** SMALLINT with CHECK constraint

---

### 1.3 Timestamps vs Dates
**Assumption:**
- Time-specific events (submissions, contest times, attendance marking): TIMESTAMP
- Calendar events (batch dates, session dates, admission dates): DATE

**Evidence:**
```
submissions.submitted_at: 2025-05-14 13:48:00 (datetime)
batches.start_date: 2025-01-10 (date only)
contests.start_time: 2025-03-08 14:00:00 (datetime)
sessions.session_date: 2025-02-10 (date only)
```

**Rationale:**
- Event precision matching the business requirement
- Saves storage and query complexity when time not needed
- Prevents incorrect cross-timezone comparisons on date-only fields

---

### 1.4 Score/Points as SMALLINT
**Assumption:** All scoring fields (max_score, score, points, awarded_points) are SMALLINT.

**Rationale:**
- Max practical score < 1000 (SMALLINT range: -32768 to 32767)
- Saves storage vs INTEGER
- Faster operations than BIGINT

**Constraint:** CHECK (score >= 0 AND score <= 1000)

---

### 1.5 Similarity Score as NUMERIC(5, 2)
**Assumption:** Plagiarism similarity_score stored as NUMERIC(5, 2) — up to 99.99%.

**Evidence from Data:**
```
similarity_score: 69.35, 74.41, 98.34, 63.96, 65.4 (decimal percentages)
```

**Rationale:**
- Two decimal places sufficient for plagiarism scoring (e.g., 98.34%)
- NUMERIC type preserves exact decimal values (not FLOAT rounding)
- Enables precise comparison and thresholds (e.g., ≥ 90.00%)

---

## Section 2: Schema Design Assumptions

### 2.1 Surrogate vs. Natural Keys
**Assumption:** All tables use surrogate PKs (batch_id, course_id, student_id, etc.) with candidate keys identified separately.

**Rationale:**
- Surrogates are system-independent (batch_code can change, batch_id shouldn't)
- FKs remain stable even if business key changes
- Enables historical data (same natural key, different surrogates over time)
- Industry-standard practice for normalized schemas

**Candidate Keys Maintained:**
- batches: batch_code (unique)
- courses: course_code (unique)
- students: roll_number (unique), email (unique when not NULL)
- problems: problem_code (unique)
- test_cases: (problem_id, case_no) composite
- enrollments: (student_id, course_id) composite
- test_results: (submission_id, test_case_id) composite
- attendance: (session_id, student_id) composite
- contest_problems: (contest_id, problem_id) composite primary key (no surrogate)

---

### 2.2 NULL Handling
**Assumption:** Only fields logically optional are NULLABLE; all others NOT NULL.

**NULLABLE Fields Justified:**
- `students.email`: Not all students register email (evidence: S0005 has NULL)
- `enrollments.final_grade`: Not assigned until course completed
- `submissions.contest_id`: Submissions can be practice (not in contest)
- `submissions.runtime_ms`: Compilation errors have no runtime
- `regrade_requests.resolved_at`: NULL while request open
- `plagiarism_flags.created_at`: Timestamp, always present
- `raw_student_import.email`: Staging table, incomplete records expected
- `operation_requests.executed_at`: NULL until operation actually executed

**NOT NULL Fields:**
- All IDs, FKs (referential integrity)
- All statuses (administrative tracking)
- All timestamps that mark event creation (created_at)
- All human-readable names (full_name, title)

**Rationale:**
- Prevents accidental data gaps
- Forces explicit NULL semantics
- Enables meaningful constraints and queries

---

### 2.3 Cascade Delete Policies
**Assumption:** Delete behavior is context-dependent (RESTRICT, CASCADE, SET NULL).

**RESTRICT (Safe Defaults for Administrative Data):**
- batches: Cannot delete batch with students enrolled
- contests: Cannot delete contest if it has submissions
**Rationale:** Safeguard against accidental administrative data loss

**CASCADE (For Logical Dependencies):**
- enrollments: Delete all enrollments if student deleted
- problems: Delete all problems if course deleted
- submissions: Delete all submissions if problem deleted
- test_results: Delete all results if submission deleted
- sessions: Delete all sessions if course deleted
- attendance: Delete all attendance if session deleted
**Rationale:** Child records have no meaning without parent

**SET NULL (For Optional Relationships):**
- submissions.contest_id: Set to NULL if contest deleted
**Rationale:** Submission exists independently; contest is context

---

### 2.4 Enumerations (ENUM-like Checks)
**Assumption:** All enum-like fields validated via CHECK constraints (not separate tables).

**Examples:**
```sql
batch_status IN ('active', 'completed', 'archived')
enrollment_status IN ('active', 'completed', 'dropped', 'suspended')
difficulty IN ('Easy', 'Medium', 'Hard')
submission_status IN ('Accepted', 'Wrong Answer', 'Compilation Error', 'Runtime Error', ...)
language IN ('C', 'C++', 'Java', 'Python', 'JavaScript', 'Go', ...)
```

**Rationale:**
- Simpler than separate enum tables
- Sufficient for fixed, rarely-changing values
- Inline constraints in DDL
- No separate JOINs needed for queries

**Alternative Not Chosen:** Separate tables for each enum
- Would add 15+ join tables (overhead)
- Overkill for rarely-changing administrative values
- Practical tradeoff: CHECK constraints sufficient

---

## Section 3: Relationship & Constraint Assumptions

### 3.1 Foreign Key Constraints Enforcement
**Assumption:** All relationships represented as explicit FK constraints.

**Not Assumed:**
- Application-level validation only (wrong; DB must enforce)
- Optional FKs without documenting NULL semantics
- Circular dependencies allowed

**Enforced:**
- All many-to-one relationships have FK
- Bridge tables (contest_problems) have composite FK
- Optional relationships clearly marked (contest_id in submissions is NULLABLE)
- Bidirectional validation where needed (regrade_requests.student_id cross-validates with submissions)

---

### 3.2 Uniqueness Constraints
**Assumption:** Candidate keys made UNIQUE, but not as PRIMARY KEY (to allow flexibility).

**Example: Students Table**
- PK: student_id (surrogate)
- UK: roll_number UNIQUE (business key, never changes)
- UK: email UNIQUE WHERE email IS NOT NULL (allows multiple NULLs)

**Rationale:**
- Prevents accidental duplicates
- Supports multiple lookup methods
- PostgreSQL partial indexes enable NULLs in unique columns

---

### 3.3 Composite Key Decisions
**Assumption:** Some tables use composite keys where a single attribute wouldn't be globally unique.

**Composite Keys Chosen:**
- test_cases: (problem_id, case_no) — case numbers restart per problem
- enrollments: (student_id, course_id) — composite uniqueness candidate
- test_results: (submission_id, test_case_id) — one result per test per submission
- attendance: (session_id, student_id) — one attendance per student per session
- contest_problems: (contest_id, problem_id) — problem appears once per contest

**Rationale:**
- Naturally enforces business rules (one enrollment per student per course)
- Composite keys more semantic than surrogates for some entities
- Most remain as candidate keys; some (contest_problems) are actual PKs

---

## Section 4: Denormalization Tradeoffs

### 4.1 Score Denormalization (ACCEPTED)
**Issue:** Submission.score is derivable from test_results but stored in submissions.

**Decision:** KEEP score in submissions table.

**Justification:**
- Submissions table has 2500+ rows (high query volume)
- Computing SUM(test_results.awarded_points) on every query expensive
- Dashboard queries need quick score access
- Tradeoff: 1 extra column storage for significant query speedup

**Consistency Maintenance:**
- Triggers on test_results INSERT/UPDATE/DELETE recalculate score
- Application validates consistency during regrade operations
- Audit queries can detect inconsistencies

**Known Data Quality Issue:**
- SUB000001 has score=46 but test_results sum to 8
- Indicates historical data corruption or incomplete test execution
- Repair: Recalculate from test_results or verify with business logic

---

### 4.2 Student ID Denormalization in Regrade Requests (ACCEPTED)
**Issue:** Regrade_requests.student_id is derivable from submissions.submission_id but stored.

**Decision:** KEEP student_id in regrade_requests.

**Justification:**
- Direct access without JOIN to submissions (performance)
- Enables validation constraint: student_id must match submission's student
- Catches data corruption early
- Practical denormalization for a small table (80 rows)

**Consistency Maintenance:**
- CHECK constraint ensures student_id matches submission's student (application-enforced)
- Audit queries can detect mismatches

---

### 4.3 Status Fields as Derived Data (PARTIALLY DENORMALIZED)
**Issue:** Contest status could be derived from start_time/end_time timestamps.

**Decision:** KEEP status field for practical reasons.

**Justification:**
- Status serves as explicit state marker for admin workflows
- Cannot reliably derive status without time function; timestamps alone ambiguous
- Manual status overrides needed (e.g., postpone contest)
- Status changes don't always align with timestamps (admin intervention)

**Design:** Strong CHECK constraints validate status rules
- CHECK (start_time < end_time)
- Triggers auto-update status for time-based transitions
- Admin can override when needed

---

## Section 5: Data Quality Assumptions & Cleanup

### 5.1 Acknowledged Data Quality Issues

**Issue 1: Contest with Invalid Time Range (CT005)**
```
start_time: 2025-04-05 12:00:00
end_time: 2025-04-05 11:00:00 ← IMPOSSIBLE (ends before starts)
status: completed
```
**Assumption:** This is a data entry error.
**Cleanup Action:** Fix with CHECK constraint + fix data before schema import.
**Migration:** Either:
- DELETE CT005 (if data corrupted)
- Swap times: start_time ← 11:00, end_time ← 12:00
- Verify with course admin

---

**Issue 2: Orphan Foreign Key (CT008 → C999)**
```
contest CT008 references course_id C999
C999 does not exist in courses table
```
**Assumption:** This is a reference integrity violation.
**Cleanup Action:** FK constraint (ON DELETE RESTRICT) will prevent this.
**Migration:** Before schema import:
- DELETE CT008 (if contest shouldn't exist)
- UPDATE CT008 SET course_id = valid_course_id
- Verify with admin which courses CT008 should belong to

---

**Issue 3: Plagiarism Self-Flag (PF0008)**
```
flag_id: PF0008
submission_id: SUB000274
matched_submission_id: SUB000274 ← SAME
```
**Assumption:** This is meaningless (submission compared to itself).
**Cleanup Action:** CHECK constraint prevents this.
**Migration:** Before schema import:
- DELETE PF0008 (invalid record)

---

**Issue 4: Regrade Request with Non-existent Submission (RG0006)**
```
request_id: RG0006
submission_id: SUB999999 ← DOESN'T EXIST
```
**Assumption:** This is an orphan record.
**Cleanup Action:** FK constraint (ON DELETE RESTRICT) will prevent this.
**Migration:** Before schema import:
- DELETE RG0006 (reference doesn't exist)

---

**Issue 5: Students with NULL Email (S0005)**
```
student_id: S0005
email: NULL
```
**Assumption:** Valid; students can exist without email.
**Design:** email column NULLABLE; UNIQUE index WHERE email IS NOT NULL.
**Implication:** System must not require email (login via roll_number, etc.)

---

**Issue 6: Submissions with Inconsistent Scores (SUB000001)**
```
submission_id: SUB000001
score: 46
test_results sum: 0 + 0 + 0 + 0 + 8 = 8 ← MISMATCH
```
**Assumption:** Score was manually adjusted or test results incomplete.
**Cleanup Action:** 
- Audit: SELECT * FROM test_results WHERE submission_id = 'SUB000001'
- Verify: Is test_case set complete? Are awarded_points calculated?
- Decision: Recalculate score = SUM or verify manual adjustment was intentional

---

**Issue 7: Malformed Email in Raw Import (RSI0006)**
```
raw_row_id: RSI0006
email: bad-email-format (not a valid email)
```
**Assumption:** Valid staging data; validation happens before accepting into students table.
**Design:** raw_student_import table NO constraints; validation at application layer.
**Process:**
- Import runs validation regex on email
- Mark import_status = 'rejected' with import_notes = "Invalid email format"
- Notify admin for manual review

---

**Issue 8: Raw Import with Non-existent Batch Code (RSI0008, RSI0009)**
```
raw_row_id: RSI0008, RSI0009
batch_code: CSE2099Z (doesn't exist in batches table)
```
**Assumption:** Valid staging data; batch lookup happens before accepting.
**Design:** raw_student_import table has NO FK to batches; validation at application layer.
**Process:**
- Import attempts to find batch matching batch_code
- If not found: mark import_status = 'rejected', import_notes = "Batch code not found"
- Admin reviews and either:
  - Creates new batch matching code
  - Corrects batch_code to existing batch
  - Rejects student record

---

**Issue 9: Submission Status vs Test Results Mismatch**
```
Some submissions with status='Accepted' but score=0
Some submissions with status='Compilation Error' but score > 0
```
**Assumption:** Status should align with test results and score.
**Design:** Enforce via:
- Application logic validates status matches test results
- Audit queries detect inconsistencies
- Corrective queries update status to match results

---

### 5.2 Staging Table Strategy for Data Cleanup

**Assumption:** Raw CSV imports go to raw_student_import table first (intentionally unvalidated).

**Process:**
1. **Import Phase:** Load CSV into raw_student_import (no constraints, messy allowed)
2. **Validation Phase:** Application runs validation checks:
   - Email format (regex)
   - Batch code exists in batches table
   - Roll number unique
   - Name not empty
   - Admission date reasonable
3. **Marking Phase:** Set import_status and import_notes
   - import_status = 'validated' or 'rejected'
   - import_notes = error messages
4. **Acceptance Phase:** Migrate validated records to students table
5. **Cleanup Phase:** Archive or delete staging records

**Design:** NO FK constraints in staging table enables this workflow.

---

## Section 6: Application-Level Assumptions

### 6.1 Student Identity Resolution
**Assumption:** Students identified by primary key student_id in all internal systems, but can be looked up by:
- roll_number (preferred)
- email (if unique when non-NULL)
- student_id (system primary)

**Implication:** System provides unique key constraint on roll_number.

---

### 6.2 Submission Evaluation Workflow
**Assumption:** When submission received:
1. Record submission row with status='Judging'
2. Run test cases, generate test_results rows
3. Aggregate results: SUM(awarded_points) → score
4. Determine final status from test results:
   - All passed → status='Accepted'
   - Some passed → status='Partial Accepted'
   - Compilation error detected → status='Compilation Error'
   - Time limit exceeded → status='Time Limit Exceeded'
   - Runtime error → status='Runtime Error'
   - Otherwise → status='Wrong Answer'
5. Update submission row: status, score
6. Trigger: Recalculate any derived fields

**Implication:** Denormalized score and status fields updated transactionally.

---

### 6.3 Cascade Delete Safety
**Assumption:** RESTRICT policies are in place to prevent accidental data loss.

- Cannot delete batch with students → protects historical data
- Cannot delete contest with submissions → protects evaluation records

**Implication:** Admin must archive instead of delete for operational entities.

---

### 6.4 Email Uniqueness
**Assumption:** Email addresses are unique when present, but NULL emails allowed.

**Implication:**
- System must validate non-NULL email is unique
- System must allow students without email (e.g., internal test accounts)
- Login system uses email only for non-NULL emails; fallback to roll_number

---

## Section 7: Performance Assumptions

### 7.1 Index Strategy
**Assumption:** Indexes created on:
- All FK columns (automatic query join optimization)
- All status/enum columns (frequent filtering)
- All timestamp columns (range queries, sorting)
- Composite indexes for common query patterns

**Example Indexes:**
```sql
CREATE INDEX idx_submissions_student_submitted ON submissions(student_id, submitted_at DESC);
CREATE INDEX idx_test_results_submission_id ON test_results(submission_id);
CREATE INDEX idx_students_email ON students(email) WHERE email IS NOT NULL;
```

**Rationale:** Balance query performance vs. write overhead.

---

### 7.2 Query Performance Considerations
**Assumption:** Denormalized fields (score, status) selected to optimize high-frequency queries:
- "Show me all submissions for student X sorted by score"
- "Count accepted submissions per problem"
- "Find all regrade requests for student Y"

**Tradeoff:** INSERT/UPDATE on submissions become slightly more complex (triggers update score), but SELECTs are much faster.

---

## Section 8: Business Logic Assumptions

### 8.1 Contest Submission Window
**Assumption:** Submissions during a contest are recorded with contest_id; submissions outside contest window have NULL contest_id.

**Implication:** System checks submission time vs. contest.start_time / end_time to populate contest_id.

---

### 8.2 Regrade Workflow
**Assumption:** Regrade requests follow this lifecycle:
1. Student creates request → request_status='open', resolved_at=NULL
2. Admin reviews → request_status='approved' or 'rejected', resolved_at=NOW()
3. If approved: Rerun test cases, update score/status, close request
4. Final status: request_status='closed'

**Implication:** Constraint: If status≠'open', resolved_at must be NOT NULL.

---

### 8.3 Plagiarism Workflow
**Assumption:** Plagiarism flags follow this lifecycle:
1. System detects similarity → flag_status='new'
2. Instructor reviews → flag_status='reviewing'
3. Instructor decides → flag_status='confirmed' or 'cleared' or 'false positive'

**Implication:** Flags are NOT automatically acted upon; instructor review required.

---

### 8.4 Problem Difficulty and Scoring
**Assumption:**
- Difficulty (Easy/Medium/Hard) is hint for students, not enforced scoring rule
- max_score is the award for fully solving problem
- sum(test_case.points) should equal problem.max_score (not enforced at DB)

**Implication:** Application validates test case points sum correctly.

---

## Section 9: Temporal Assumptions

### 9.1 Timestamp Precision
**Assumption:** TIMESTAMP fields include date and time; DATE fields are date only.

**Implications:**
- Submissions timestamped to second precision (2025-05-14 13:48:00)
- Sessions recorded by date only (2025-02-10, not time)
- Contests have precise start/end times for window enforcement

---

### 9.2 Historical Data & Immutability
**Assumption:** Most operational data is immutable after creation:
- Submissions cannot be edited (only regrade requested)
- Test results are permanent (audit trail)
- Operation requests are logged (cannot be hidden)

**Implication:** updated_at timestamps useful for tracking when records change, but rarely in production.

---

### 9.3 Timezone Handling
**Assumption:** All timestamps are in system's default timezone (likely IST if CodeJudge is Indian platform).

**Implication:** No timezone conversion needed; timestamps stored in server timezone.

---

## Section 10: Scale & Future Growth Assumptions

### 10.1 Data Volume Estimates (Based on CSV Rows)
- Students: 320 → likely 1000-10000 at scale
- Submissions: 2500 → likely 100,000+ at scale
- Test Results: 9673 → likely 500,000+ at scale

### 10.2 Index Strategy Scales
- Indexes on frequently filtered columns remain efficient
- Composite indexes on (student_id, submitted_at) enable fast user-specific queries
- Partial indexes (WHERE email IS NOT NULL) keep index size manageable

### 10.3 Partitioning Opportunity
- If test_results exceeds 100M rows, consider partitioning by submission_id ranges
- Not required for current scale; revisit if queries slow

---

## Conclusion

This design balances **normalization theory** with **practical usability**:
- ✓ Approximately 3NF with justified denormalizations
- ✓ Explicit FK and CHECK constraints enforce integrity
- ✓ Staging table pattern for safe imports
- ✓ Cascade/Restrict/SetNull strategies balance safety and flexibility
- ✓ Indexes optimize common query patterns
- ✓ Assumes application-level logic for derived data consistency

The schema is **production-ready** with proper validation and maintenance practices.

