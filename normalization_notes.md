# Normalization Analysis & Design Reasoning

## Executive Summary

The CodeJudge database has been analyzed for normalization up to **3NF (Third Normal Form)**. The design is **approximately 3NF with intentional denormalizations** for performance and practical usability. Below are detailed examples of redundancy, functional/partial dependencies, and normalization decisions.

---

## EXAMPLE 1: Redundancy — Submission Score Denormalization

### The Redundancy
**Issue:** A submission's `score` is stored in the `submissions` table, but this value is **derived** from `test_results`.

**Raw Data Evidence:**
```
submissions: submission_id=SUB000001, score=46, status='Wrong Answer'
test_results for SUB000001:
  - R0000001: awarded_points=0
  - R0000002: awarded_points=0
  - R0000003: awarded_points=0
  - R0000004: awarded_points=0
  - R0000005: awarded_points=8
  -- SUM(awarded_points) = 8, but submission.score = 46 ❌ INCONSISTENT
```

### Problem
- If score is updated without updating test_results, inconsistency occurs
- If test_results are recalculated (regrade), submission.score may become stale
- Wastes storage (minimal) but more importantly creates consistency liability

### Normalization Perspective
- **Strict 3NF**: Remove score from submissions; derive it at query time via `SUM(test_results.awarded_points)`
- **Practical Trade-off**: Keep score in submissions for query performance (avoid expensive GROUP BY on every query)

### Design Decision: DENORMALIZATION FOR PERFORMANCE
✓ **KEEP score in submissions** (reasoning below):
- Submissions table receives high query volume (dashboard, rankings, filtering)
- Computing score on-the-fly would require expensive JOIN + GROUP BY
- Solution: Maintain score via trigger/application logic on INSERT/UPDATE to test_results

---

## EXAMPLE 2: Redundancy — Regrade Request Student ID

### The Redundancy
**Issue:** `regrade_requests` contains both `submission_id` and `student_id`.

**Raw Data:**
```
regrade_requests:
  request_id=RG0001
  submission_id=SUB001225
  student_id=S0267    <-- REDUNDANT
  
This student_id is DERIVABLE from:
  SELECT student_id FROM submissions WHERE submission_id = SUB001225
```

### Problem
- Student ID is redundant (already in submissions table)
- If a student_id is entered differently, referential integrity violated
- Data duplication creates maintenance burden

### Normalization Perspective
- **Strict 3NF**: Remove student_id; derive via JOIN to submissions
- **Practical Trade-off**: Keep student_id for query efficiency and to catch data entry errors (redundancy as validation)

### Design Decision: KEEP REDUNDANCY WITH VALIDATION
✓ **KEEP student_id in regrade_requests** (reasoning):
- Allows direct filtering by student without joining submissions
- Enables CHECK constraint: `(submission_id→student_id in submissions) = student_id`
- Catches data corruption where regrade lists wrong student

---

## EXAMPLE 3: Redundancy — Contest Status vs Timestamps

### The Redundancy
**Issue:** Contest has both `contest_status` (enum) and `start_time`/`end_time` (timestamps).

**Contest Status Logic:**
- Status should be derivable from timestamps + current time:
  - If current_time < start_time → 'scheduled'
  - If start_time ≤ current_time < end_time → 'ongoing'
  - If current_time ≥ end_time → 'completed'

**Raw Data:**
```
contest CT005:
  start_time: 2025-04-05 12:00:00
  end_time: 2025-04-05 11:00:00    <-- IMPOSSIBLE (ends before starts!)
  contest_status: 'completed'      <-- Stored, but DERIVABLE
```

### Problem
- Status becomes redundant when it can be computed from timestamps
- Timestamp errors (end_time < start_time) invalidate status derivation
- Manual status changes may lag real contest progression

### Normalization Perspective
- **Strict 3NF**: Remove status; derive from timestamps at query time
- **Practical Trade-off**: Keep status for fast filtering, explicit state management

### Design Decision: KEEP WITH STRONG CONSTRAINTS
✓ **KEEP status but enforce CHECKs:**
- `CHECK (start_time < end_time)` — prevents impossible data
- Application code keeps status synchronized
- Could add trigger to auto-update status on timer, but manual control useful

---

## Functional Dependencies & 2NF Analysis

### BATCHES Table

**Functional Dependencies:**
```
batch_id → batch_code, program, start_date, end_date, batch_status
batch_code → batch_id, program, start_date, end_date, batch_status (batch_code is candidate key)
```

**2NF Check:**
- PK is batch_id (single attribute, not composite)
- All non-PK attributes (batch_code, program, ...) depend on the whole PK ✓
- **Result: IN 2NF** (single-column PK, so no partial dependencies possible)

**3NF Check:**
- Is there transitive dependency? 
  - batch_code → program? NO (program doesn't determine batch_code)
  - No non-key attribute determines another
- **Result: IN 3NF**

---

### ENROLLMENTS Table

**Functional Dependencies:**
```
enrollment_id → student_id, course_id, enrolled_on, enrollment_status, final_grade
(student_id, course_id) → enrollment_id, enrolled_on, enrollment_status, final_grade
  (composite candidate key)
```

**2NF Check:**
- PK is enrollment_id (single attribute)
- Non-PK attributes depend on full PK ✓
- **Result: IN 2NF**

**3NF Check:**
- Partial Dependency Found: final_grade
  - final_grade functionally depends on enrollment_status
  - If status='completed', grade should exist
  - If status='active', grade should be NULL
  - **Issue:** final_grade should logically live in a separate entity or be conditional

**Design Decision: Accept 3NF Violation**
- Reason: Maintaining grade in a separate table (enrollments_grades) would require extra JOINs
- Practical: Constraint enrollment_status='completed' → final_grade NOT NULL
- This is acceptable denormalization for usability

---

### TEST_RESULTS Table

**Functional Dependencies:**
```
result_id → submission_id, test_case_id, result_status, runtime_ms, memory_kb, awarded_points
(submission_id, test_case_id) → result_id, result_status, runtime_ms, memory_kb, awarded_points
  (composite candidate key)
```

**Transitive Dependency:**
```
result_status → awarded_points?
- If result_status='Passed', awarded_points = test_case.points
- If result_status≠'Passed', awarded_points = 0
- This is a DERIVED relationship, not stored dependency
```

**2NF & 3NF Check:**
- PK is result_id (single column) → all non-PK attributes depend on PK
- No transitive dependencies between non-key attributes
- **Result: IN 3NF** (with derived constraints)

---

### REGRADE_REQUESTS Table

**Functional Dependencies:**
```
request_id → submission_id, student_id, requested_at, reason, request_status, resolved_at
```

**Partial Dependency:**
```
resolved_at partially depends on request_status:
- If request_status='open', resolved_at = NULL
- If request_status IN ('approved','rejected','closed'), resolved_at ≠ NULL
- This is a CONDITIONAL relationship (business logic, not structural DB dependency)
```

**Redundancy:**
```
student_id is redundant:
- Can be derived: SELECT student_id FROM submissions WHERE submission_id = X
- BUT kept for performance and validation (already discussed in Example 2)
```

**2NF & 3NF Check:**
- Despite single-column PK, design is acceptable 3NF given redundancy justification
- **Result: PRAGMATIC 3NF** (with justified denormalization)

---

## Partial Dependency Examples

### EXAMPLE 4: Partial Dependency in Composite Keys

**Case: ATTENDANCE Table**

If we used composite PK (session_id, student_id):
```
(session_id, student_id) → attendance_id, attendance_status, marked_at
```

**Partial Dependency:**
```
session_id → session_id (self, trivial)
student_id → student_id (self, trivial)
attendance_status → NOTHING (non-key attribute doesn't determine anything)
```

**Conclusion:** No non-key attribute depends on only part of the PK (none depend on partial keys).
**Result: IN 2NF** (no partial dependencies)

---

### EXAMPLE 5: Another Partial Dependency Check

**Case: ENROLLMENTS Table (if using composite PK)**

If we used composite PK (student_id, course_id):
```
(student_id, course_id) → enrollment_id, enrolled_on, enrollment_status, final_grade
```

**Checking for Partial Dependencies:**
```
student_id alone → ??? (no non-key attribute depends on just student_id)
course_id alone → ??? (no non-key attribute depends on just course_id)
```

**BUT:** There's a logical partial dependency:
```
enrollment_status → final_grade (conditional)
  - NOT between key and non-key
  - BETWEEN non-key and non-key
  - This would violate 3NF (transitive), but is acceptable here
```

**Conclusion:** Technically acceptable; pragmatic denormalization.

---

## Transitive Dependency Examples

### EXAMPLE 6: Transitive Dependency

**Case: SUBMISSIONS Table**

If we kept:
```
submission_id → problem_id → max_score
(submission_id determines problem_id, problem_id determines max_score)
```

**However:** max_score is NOT in submissions table (correctly avoided this redundancy):
```
submissions:
  - submission_id, student_id, problem_id, score (NOT max_score)
  - To get max_score: JOIN to problems table
```

**Result: CORRECT, NO TRANSITIVE DEPENDENCY**

---

### EXAMPLE 7: Potential Transitive Dependency in COURSES

**Current Design (CORRECT):**
```
courses:
  - course_id → course_code, course_title, course_status, credit_hours
  - No transitive dependencies (all non-key attributes independent)
```

**Result: IN 3NF**

---

## Normalization Summary by Table

| Table | 1NF | 2NF | 3NF | Notes |
|-------|-----|-----|-----|-------|
| batches | ✓ | ✓ | ✓ | Simple, atomic values, no composite PK, no transitive deps |
| courses | ✓ | ✓ | ✓ | Simple, atomic values, clean design |
| students | ✓ | ✓ | ✓ | Atomic values, no transitive deps |
| enrollments | ✓ | ✓ | ~3NF | Partial dep: final_grade → enrollment_status (accepted denormalization) |
| problems | ✓ | ✓ | ✓ | Atomic, no transitive deps |
| test_cases | ✓ | ✓ | ✓ | Composite PK (problem_id, case_no), all non-key attrs depend on full PK |
| contests | ✓ | ✓ | ✓ | Status is derivable but kept for practical reasons |
| contest_problems | ✓ | ✓ | ✓ | Composite PK, bridge table, clean |
| submissions | ✓ | ✓ | ~3NF | Score is denormalized (derived from test_results) for performance |
| test_results | ✓ | ✓ | ✓ | Composite PK, clean deps |
| sessions | ✓ | ✓ | ✓ | Simple attributes, no deps |
| attendance | ✓ | ✓ | ✓ | Composite PK, no partial deps |
| regrade_requests | ✓ | ✓ | ~3NF | student_id is redundant but kept for performance; resolved_at conditional |
| plagiarism_flags | ✓ | ✓ | ✓ | Bridge table, clean structure |
| raw_student_import | ✓ | ✓ | ✓ | Staging table, intentionally loose structure |
| operation_requests | ✓ | ✓ | ✓ | Audit table, no transitive deps |

---

## Design Tradeoff Justifications

### 1. Score Denormalization in SUBMISSIONS
**Trade-off:** Redundancy for performance
**Justification:**
- Submissions table is heavily queried (100k+ rows typical at scale)
- Computing aggregate score on-the-fly would add latency (JOIN + GROUP BY)
- Solution: Maintain consistency via database triggers on test_results INSERT/UPDATE
- **Cost-Benefit:** 1 extra column (storage negligible) for significant query speedup

### 2. Student ID Redundancy in REGRADE_REQUESTS
**Trade-off:** Redundancy for validation
**Justification:**
- Allows direct access to requester without joining submissions
- Enables CHECK constraint to validate student_id matches submission's student_id
- Catches data corruption
- **Cost-Benefit:** 1 extra column for safety and query efficiency

### 3. Contest Status vs Timestamps
**Trade-off:** Redundancy for usability
**Justification:**
- Manual status control needed for admin workflows (e.g., postponing a contest)
- Storing status allows explicit state management
- Timestamps alone insufficient (can't distinguish 'scheduled' from 'ongoing' without time function)
- **Cost-Benefit:** Requires strong CHECK constraints and trigger maintenance

### 4. Session Date without Time Duration
**Design Issue:** Sessions only have `session_date`, not start/end times
**Impact:** Cannot validate attendance marked time against session time
**Tradeoff:** Simplified design for academic sessions (assume full-day, or time not tracked)
**Practical:** Times tracked separately in attendance via `marked_at` timestamp

---

## Data Quality Issues Preventing Full Normalization

### Issue 1: Contest with Invalid Timestamp Range (CT005)
```
start_time: 2025-04-05 12:00:00
end_time: 2025-04-05 11:00:00  ← ENDS BEFORE STARTS
```
**Normalization Impact:** Cannot derive valid status from timestamps
**Fix:** Enforce `CHECK (start_time < end_time)` at schema level

### Issue 2: Orphan Foreign Key (CT008 → C999)
```
contest_id: CT008
course_id: C999  ← DOESN'T EXIST IN COURSES
```
**Normalization Impact:** Violates referential integrity
**Fix:** Add FK constraint with ON DELETE RESTRICT to prevent this

### Issue 3: Plagiarism Self-Flag (PF0008)
```
submission_id: SUB000274
matched_submission_id: SUB000274  ← SAME AS submission_id
```
**Normalization Impact:** Meaningless record (comparing submission to itself)
**Fix:** Add CHECK constraint: `submission_id ≠ matched_submission_id`

### Issue 4: Regrade Request with Non-existent Submission (RG0006)
```
submission_id: SUB999999  ← DOESN'T EXIST
```
**Normalization Impact:** Orphan record violating referential integrity
**Fix:** FK constraint with ON DELETE RESTRICT

---

## Conclusion: Normalization Assessment

The CodeJudge database achieves **approximately 3NF** with justified denormalizations:

✓ **IN 1NF:** All attributes are atomic; no repeating groups  
✓ **IN 2NF:** No partial dependencies on composite keys  
✓ **IN 3NF (mostly):** No transitive dependencies except:
  - Enrollments: final_grade conditional on enrollment_status
  - Submissions: score derivable from test_results
  - Regrade_requests: resolved_at conditional on request_status
  - These exceptions are INTENTIONAL for performance/usability

**Practical Assessment:**
- The schema balances normalization theory with real-world usability
- Denormalizations are explicitly justified and can be maintained via triggers
- Data quality constraints will prevent most anomalies
- Design is suitable for production use with proper application-level validation

