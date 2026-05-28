# Part 4: Transactions & Reliability - SQL Examples

## Overview

Demonstrates PostgreSQL transaction handling, ACID properties, isolation levels, deadlock prevention, and recovery mechanisms using CodeJudge domain scenarios.

---

## Section 1: Basic Transaction Structure

### Example 1.1: Simple Transaction with COMMIT
**Scenario:** Enroll student in course (single atomic operation)

```sql
-- Simple transaction: enroll student in course
BEGIN TRANSACTION;

-- Insert enrollment record
INSERT INTO enrollments (enrollment_id, student_id, course_id, enrollment_status, enrollment_date)
VALUES ('E00001', 'S0001', 'C001', 'active', CURRENT_DATE);

-- If everything succeeds, commit
COMMIT;

-- After COMMIT, enrollment is permanent and visible to other transactions
```

**Explanation:**
- `BEGIN` or `BEGIN TRANSACTION`: Starts new transaction
- SQL statements execute
- `COMMIT`: Saves all changes atomically
- **Result:** Enrollment appears in database permanently

---

### Example 1.2: Transaction with ROLLBACK
**Scenario:** Attempt to enroll student, rollback if student doesn't exist

```sql
-- Transaction with error handling
BEGIN TRANSACTION;

-- Try to enroll non-existent student
INSERT INTO enrollments (enrollment_id, student_id, course_id, enrollment_status, enrollment_date)
VALUES ('E00002', 'S9999', 'C001', 'active', CURRENT_DATE);
-- This will fail: FK constraint student_id not in students

-- If error occurs, rollback
ROLLBACK;

-- Result: No enrollment created, database unchanged
-- Error message: "duplicate key value violates unique constraint..."
```

**Explanation:**
- FK constraint prevents insert
- `ROLLBACK`: Undoes all changes in transaction
- **Result:** Database returns to pre-transaction state

---

### Example 1.3: Transaction with Savepoints
**Scenario:** Multi-step process with partial rollback capability

```sql
-- Transaction with multiple savepoints for partial recovery
BEGIN TRANSACTION;

-- Step 1: Create regrade request
INSERT INTO regrade_requests (request_id, submission_id, student_id, request_status, created_at)
VALUES ('RG0100', 'SUB000001', 'S0001', 'open', CURRENT_TIMESTAMP);

-- Create savepoint after first step
SAVEPOINT sp_after_regrade_created;

-- Step 2: Update submission status
UPDATE submissions SET status = 'Waiting' WHERE submission_id = 'SUB000001';

-- Create another savepoint
SAVEPOINT sp_after_status_updated;

-- Step 3: Log the action
INSERT INTO audit_log (action, affected_record, timestamp)
VALUES ('REGRADE_CREATED', 'SUB000001', CURRENT_TIMESTAMP);

-- If logging failed, rollback to sp_after_status_updated
-- ROLLBACK TO sp_after_status_updated;

-- Otherwise, commit everything
COMMIT;

-- Result: Regrade request created, submission status updated, action logged
```

**Explanation:**
- `SAVEPOINT name`: Creates recovery point within transaction
- `ROLLBACK TO name`: Rolls back to specific savepoint, not entire transaction
- **Use case:** Multi-step operations where later steps might fail

---

## Section 2: ACID Properties Demonstrations

### 2.1: Atomicity - All or Nothing
**Scenario:** Update test results and recalculate submission score (must succeed together)

```sql
-- ATOMICITY: Both updates succeed or both fail
BEGIN TRANSACTION;

-- Step 1: Award points for test result
UPDATE test_results 
SET awarded_points = 10, result_status = 'Passed'
WHERE result_id = 'TR001';

-- Step 2: Recalculate submission score
UPDATE submissions
SET score = (
  SELECT SUM(awarded_points)
  FROM test_results
  WHERE submission_id = 'SUB000001'
)
WHERE submission_id = 'SUB000001';

-- Both succeed or both fail
COMMIT;

-- If either statement fails, entire transaction rolls back
-- Result: Submission score is always consistent with test results
```

**ACID Property: Atomicity**
- All operations in transaction succeed together
- If any fails, all changes are rolled back
- No partial results (no "half-updated" states)

---

### 2.2: Consistency - Maintain Data Integrity
**Scenario:** Transfer submission from one contest to another (FK constraints)

```sql
-- CONSISTENCY: All constraints must be satisfied
BEGIN TRANSACTION;

-- Check if submission exists
IF EXISTS (SELECT 1 FROM submissions WHERE submission_id = 'SUB000001') THEN
  -- Check if new contest exists
  IF EXISTS (SELECT 1 FROM contests WHERE contest_id = 'CT002') THEN
    -- Update submission's contest
    UPDATE submissions
    SET contest_id = 'CT002'
    WHERE submission_id = 'SUB000001';
    
    COMMIT;
  ELSE
    ROLLBACK; -- Contest doesn't exist
    RAISE EXCEPTION 'Contest CT002 does not exist';
  END IF;
ELSE
  ROLLBACK; -- Submission doesn't exist
  RAISE EXCEPTION 'Submission SUB000001 does not exist';
END IF;

-- Result: Submission.contest_id always points to valid contest (or NULL)
-- Foreign key constraints prevent inconsistent states
```

**ACID Property: Consistency**
- Transaction only executes if it maintains all constraints
- FK constraints, UNIQUE constraints, CHECK constraints
- Database state before = valid, state after = valid, never in-between

---

### 2.3: Isolation - Independence Between Transactions
**Scenario:** Two students submitting simultaneously (race condition scenario)

```sql
-- Transaction A (Student S0001 submitting)
BEGIN TRANSACTION;

-- Create new submission
INSERT INTO submissions (submission_id, student_id, problem_id, status, submitted_at)
VALUES ('SUB000500', 'S0001', 'P0001', 'Judging', CURRENT_TIMESTAMP);

-- Student's transaction running...
-- (Transaction B is executing in parallel)

-- Check submission count
SELECT COUNT(*) FROM submissions WHERE student_id = 'S0001';
-- Student A sees only their own submission count (consistent read)

COMMIT;

-- With proper isolation level, students don't see incomplete changes from each other
```

**ACID Property: Isolation**
- Transactions execute independently
- Changes from one transaction not visible to others until COMMIT
- Prevents "dirty reads" and "race conditions"

---

### 2.4: Durability - Permanent Once Committed
**Scenario:** Course enrollment is permanent after commit (even if system crashes)

```sql
-- DURABILITY: Changes persist forever
BEGIN TRANSACTION;

INSERT INTO enrollments (enrollment_id, student_id, course_id, enrollment_status, enrollment_date)
VALUES ('E00003', 'S0001', 'C001', 'active', CURRENT_DATE);

COMMIT;
-- ← At this point, enrollment is permanently saved to disk
-- Even if power fails immediately after, enrollment persists

-- Verify enrollment is permanent
SELECT * FROM enrollments WHERE enrollment_id = 'E00003';
-- ✓ Returns the enrollment (survived any crash)
```

**ACID Property: Durability**
- Once `COMMIT` succeeds, data is written to disk
- Survives system crashes, power failures
- Recovery mechanisms ensure no data loss

---

## Section 3: Isolation Levels

### 3.1: READ UNCOMMITTED (Dirty Read Allowed)
**Scenario:** Lowest isolation level, allows dirty reads

```sql
-- Session A (Writer)
BEGIN TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;
UPDATE submissions SET score = 100 WHERE submission_id = 'SUB000001';
-- Transaction still open, changes not committed

-- Session B (Reader) - Running concurrently
BEGIN TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;
SELECT score FROM submissions WHERE submission_id = 'SUB000001';
-- ⚠️ DIRTY READ: Sees uncommitted score = 100 from Session A

-- Session A rollbacks
ROLLBACK; -- Undo score update

-- Session B's read was of data that no longer exists!
COMMIT;

-- Issue: Dirty reads cause inconsistency
-- Use case: Non-critical reads where slight inconsistency acceptable
```

**Isolation Level Properties:**
- ✗ Prevents lost updates: NO
- ✗ Prevents dirty reads: NO (main issue)
- ✗ Prevents non-repeatable reads: NO
- ✗ Prevents phantom reads: NO
- **Risk Level:** VERY HIGH
- **PostgreSQL:** Not actually implemented (uses READ COMMITTED minimum)

---

### 3.2: READ COMMITTED (No Dirty Reads)
**Scenario:** Default PostgreSQL isolation level

```sql
-- Session A (Writer)
BEGIN TRANSACTION ISOLATION LEVEL READ COMMITTED;
UPDATE students SET enrollment_status = 'graduated' 
WHERE student_id = 'S0001';
-- Transaction open

-- Session B (Reader)
BEGIN TRANSACTION ISOLATION LEVEL READ COMMITTED;
SELECT enrollment_status FROM students WHERE student_id = 'S0001';
-- ✓ SAFE: Sees old value ('active'), not uncommitted 'graduated'

-- Session A commits
COMMIT;

-- Now Session B sees new value
SELECT enrollment_status FROM students WHERE student_id = 'S0001';
-- ✓ Sees 'graduated' (post-commit)

COMMIT;

-- Issue: Non-repeatable reads possible within same transaction
-- Use case: Most common, balances safety and performance
```

**Isolation Level Properties:**
- ✗ Prevents dirty reads: YES ✓
- ✗ Prevents non-repeatable reads: NO (possible)
- ✗ Prevents phantom reads: NO (possible)
- **Risk Level:** LOW
- **PostgreSQL Default:** Yes, this is PostgreSQL default

---

### 3.3: REPEATABLE READ (Snapshot Isolation)
**Scenario:** Higher isolation - all reads see consistent snapshot

```sql
-- Session A (Reader)
BEGIN TRANSACTION ISOLATION LEVEL REPEATABLE READ;

SELECT COUNT(*) FROM enrollments WHERE course_id = 'C001';
-- Returns: 45 enrollments

-- Session B runs concurrently and adds new enrollment
-- (We simulate this by switching sessions)

-- Session A reads again from same snapshot
SELECT COUNT(*) FROM enrollments WHERE course_id = 'C001';
-- ✓ Returns: 45 (same as before, consistent)
-- Session A doesn't see Session B's new enrollments

COMMIT;

-- Issue: Phantom reads possible (new rows added after transaction started)
-- Use case: Reports, analytics where consistency within transaction crucial
```

**Isolation Level Properties:**
- ✓ Prevents dirty reads: YES
- ✓ Prevents non-repeatable reads: YES
- ✗ Prevents phantom reads: NO (phantom read possible)
- **Risk Level:** VERY LOW
- **Use Case:** High-consistency requirements

---

### 3.4: SERIALIZABLE (Highest Isolation)
**Scenario:** Transactions execute as if serialized (one after another)

```sql
-- Session A (Transaction 1)
BEGIN TRANSACTION ISOLATION LEVEL SERIALIZABLE;

-- Create new problem
INSERT INTO problems (problem_id, problem_code, title, course_id, difficulty, max_score)
VALUES ('P0100', 'PROB0100', 'Advanced Algorithm', 'C001', 'Hard', 100);

-- Session B attempts concurrent modification (would conflict)
-- B's changes to course C001 would cause serialization conflict

COMMIT;
-- Session A succeeds

-- Session B's conflicting transaction would get:
-- ERROR: could not serialize access due to concurrent update

-- Issue: Highest isolation but lowest concurrency
// Use case: Critical financial transactions, audit systems
```

**Isolation Level Properties:**
- ✓ Prevents dirty reads: YES
- ✓ Prevents non-repeatable reads: YES
- ✓ Prevents phantom reads: YES
- **Risk Level:** NONE (safest)
- **Performance Cost:** Highest (lowest throughput)
- **Use Case:** Critical operations requiring guaranteed isolation

---

### 3.5: Isolation Level Comparison Table

```sql
-- Practical demonstration of choosing isolation levels

-- For submission judging (critical - score must be accurate)
BEGIN TRANSACTION ISOLATION LEVEL SERIALIZABLE;
  UPDATE submissions SET score = 85, status = 'Accepted'
  WHERE submission_id = 'SUB000001';
COMMIT;

-- For dashboard queries (non-critical - slight staleness acceptable)
BEGIN TRANSACTION ISOLATION LEVEL READ COMMITTED;
  SELECT COUNT(*) FROM submissions WHERE status = 'Accepted';
COMMIT;

-- For consistency requirements
BEGIN TRANSACTION ISOLATION LEVEL REPEATABLE READ;
  SELECT * FROM enrollments WHERE student_id = 'S0001';
  UPDATE enrollments SET final_grade = 'A' WHERE student_id = 'S0001';
COMMIT;
```

| Level | Dirty Reads | Non-Rep. Reads | Phantom Reads | Performance | Use Case |
|-------|:-----------:|:--------------:|:-------------:|:-----------:|----------|
| READ UNCOMMITTED | ⚠️ Yes | ⚠️ Yes | ⚠️ Yes | Fastest | Not recommended |
| READ COMMITTED | ✓ No | ⚠️ Yes | ⚠️ Yes | Good | General use (DEFAULT) |
| REPEATABLE READ | ✓ No | ✓ No | ⚠️ Yes | Fair | Consistency required |
| SERIALIZABLE | ✓ No | ✓ No | ✓ No | Slowest | Critical operations |

---

## Section 4: Deadlock Scenarios & Prevention

### 4.1: Classic Deadlock Scenario
**Scenario:** Two transactions lock resources in opposite order

```sql
-- Session A (Transaction 1)
BEGIN TRANSACTION;

-- Lock: Update submission first
UPDATE submissions SET score = 90 WHERE submission_id = 'SUB000001';

-- Wait for lock on student (held by Session B)
UPDATE students SET enrollment_status = 'active' WHERE student_id = 'S0001';
-- ⏳ WAITING... (Session B holds lock on students)

-- Session B (Transaction 2) - Running concurrently
BEGIN TRANSACTION;

-- Lock: Update student first
UPDATE students SET enrollment_status = 'graduated' WHERE student_id = 'S0001';

-- Wait for lock on submission (held by Session A)
UPDATE submissions SET score = 95 WHERE submission_id = 'SUB000001';
-- ⏳ WAITING... (Session A holds lock on submissions)

-- DEADLOCK: Both waiting for each other!
-- PostgreSQL detects and aborts one transaction
-- ERROR: Deadlock detected

-- Recovery: Retry aborted transaction
```

**Deadlock Chain:**
```
Session A → Locks submissions → Waits for students (held by B)
Session B → Locks students → Waits for submissions (held by A)
         ↓
      DEADLOCK!
```

---

### 4.2: Preventing Deadlocks - Consistent Lock Ordering
**Scenario:** Always acquire locks in same order (prevents cycles)

```sql
-- SAFE: Lock submissions BEFORE students (consistent order)

-- Session A
BEGIN TRANSACTION;
UPDATE submissions SET score = 90 WHERE submission_id = 'SUB000001';
UPDATE students SET enrollment_status = 'active' WHERE student_id = 'S0001';
COMMIT;

-- Session B (different order, but still safe if both follow rule)
BEGIN TRANSACTION;
UPDATE submissions SET score = 95 WHERE submission_id = 'SUB000001';
UPDATE students SET enrollment_status = 'graduated' WHERE student_id = 'S0001';
COMMIT;

-- Both sessions acquire submission lock first, then student lock
// No circular wait possible → No deadlock
```

**Prevention Rule:**
```
If multiple transactions need multiple locks,
always acquire locks in the SAME ORDER:
- Lock students first
- Then lock submissions
- Then lock test_results
(Apply globally across all transactions)
```

---

### 4.3: Deadlock Detection & Retry Logic
**Scenario:** Application-level retry with exponential backoff

```sql
-- Pseudocode for deadlock handling
FUNCTION submit_code_with_retry(submission_data) {
  max_retries = 3;
  retry_count = 0;
  
  WHILE retry_count < max_retries:
    TRY:
      BEGIN TRANSACTION ISOLATION LEVEL SERIALIZABLE;
      
      -- Insert submission
      INSERT INTO submissions (...) VALUES (...);
      
      -- Create initial test results
      INSERT INTO test_results (...)
      SELECT ... FROM test_cases ...;
      
      COMMIT;
      RETURN success;
      
    CATCH Deadlock Exception:
      ROLLBACK;
      retry_count = retry_count + 1;
      wait_time = 2^retry_count * 100ms; -- Exponential backoff
      SLEEP(wait_time);
      
    CATCH Other Exception:
      ROLLBACK;
      RAISE exception;
  
  RETURN failure (max retries exceeded);
}

-- Example execution:
-- Attempt 1: Deadlock → Wait 200ms → Retry
-- Attempt 2: Deadlock → Wait 400ms → Retry
-- Attempt 3: Success!
```

---

### 4.4: Detecting Current Locks

```sql
-- Check active locks in database
SELECT 
  pid,
  usename,
  application_name,
  state,
  query,
  EXTRACT(EPOCH FROM (NOW() - query_start)) AS query_duration_sec
FROM pg_stat_activity
WHERE state = 'active'
ORDER BY query_start;

-- Check blocking relationships
SELECT 
  blocked_locks.pid AS blocked_pid,
  blocked_activity.usename AS blocked_user,
  blocking_locks.pid AS blocking_pid,
  blocking_activity.usename AS blocking_user,
  blocked_activity.query AS blocked_statement,
  blocking_activity.query AS blocking_statement
FROM pg_catalog.pg_locks blocked_locks
JOIN pg_catalog.pg_stat_activity blocked_activity ON blocked_activity.pid = blocked_locks.pid
JOIN pg_catalog.pg_locks blocking_locks ON blocking_locks.locktype = blocked_locks.locktype
  AND blocking_locks.database IS NOT DISTINCT FROM blocked_locks.database
  AND blocking_locks.relation IS NOT DISTINCT FROM blocked_locks.relation
  AND blocking_locks.page IS NOT DISTINCT FROM blocked_locks.page
  AND blocking_locks.tuple IS NOT DISTINCT FROM blocked_locks.tuple
  AND blocking_locks.virtualxid IS NOT DISTINCT FROM blocked_locks.virtualxid
  AND blocking_locks.transactionid IS NOT DISTINCT FROM blocked_locks.transactionid
  AND blocking_locks.classid IS NOT DISTINCT FROM blocked_locks.classid
  AND blocking_locks.objid IS NOT DISTINCT FROM blocked_locks.objid
  AND blocking_locks.objsubid IS NOT DISTINCT FROM blocked_locks.objsubid
  AND blocking_locks.pid != blocked_locks.pid
JOIN pg_catalog.pg_stat_activity blocking_activity ON blocking_activity.pid = blocking_locks.pid
WHERE NOT blocked_locks.granted;

-- Kill a blocking session (force termination)
SELECT pg_terminate_backend(pid) FROM pg_stat_activity 
WHERE pid = <blocking_pid> AND pid <> pg_backend_pid();
```

---

## Section 5: Real-World CodeJudge Scenarios

### 5.1: Submission Judging Transaction
**Scenario:** Complete submission judging flow (atomic operation)

```sql
-- Complete submission judging as single transaction
BEGIN TRANSACTION ISOLATION LEVEL SERIALIZABLE;

-- 1. Update submission status to 'Judging'
UPDATE submissions 
SET status = 'Judging', last_updated = CURRENT_TIMESTAMP
WHERE submission_id = 'SUB000001';

-- 2. Insert test results for each test case
INSERT INTO test_results (result_id, submission_id, test_case_id, result_status, awarded_points, runtime_ms, memory_kb)
SELECT 
  'TR' || ROW_NUMBER() OVER (ORDER BY case_no),
  'SUB000001',
  test_case_id,
  CASE WHEN random() > 0.3 THEN 'Passed' ELSE 'Failed' END,
  CASE WHEN random() > 0.3 THEN points ELSE 0 END,
  (random() * 1000)::integer,
  (random() * 65536)::integer
FROM test_cases
WHERE problem_id = 'P0001'
ORDER BY case_no;

-- 3. Calculate final score
WITH test_summary AS (
  SELECT submission_id, SUM(awarded_points) AS total_score
  FROM test_results
  WHERE submission_id = 'SUB000001'
  GROUP BY submission_id
)
UPDATE submissions
SET score = COALESCE(test_summary.total_score, 0),
    status = CASE 
      WHEN COALESCE(test_summary.total_score, 0) = p.max_score THEN 'Accepted'
      WHEN COALESCE(test_summary.total_score, 0) > 0 THEN 'Partial Accepted'
      ELSE 'Wrong Answer'
    END,
    last_updated = CURRENT_TIMESTAMP
FROM test_summary, problems p
WHERE submissions.submission_id = 'SUB000001'
  AND p.problem_id = 'P0001';

-- 4. Update plagiarism check status
INSERT INTO plagiarism_flags (flag_id, submission_id, matched_submission_id, similarity_score, flag_status, created_at)
VALUES ('PF0200', 'SUB000001', 'SUB000002', 78.50, 'new', CURRENT_TIMESTAMP);

-- 5. Log the judging event
INSERT INTO audit_log (action, affected_record, details, timestamp)
VALUES ('SUBMISSION_JUDGED', 'SUB000001', 'Score calculated, tests executed', CURRENT_TIMESTAMP);

COMMIT;

-- All-or-nothing: Either complete judging succeeds or entire process rolls back
// Result: Submission completely judged with all test results, score calculated, plagiarism checked
```

---

### 5.2: Course Enrollment with Validation
**Scenario:** Enroll student with constraints verification

```sql
-- Enroll student in course with validation
BEGIN TRANSACTION ISOLATION LEVEL REPEATABLE READ;

-- 1. Verify student exists and is active
IF NOT EXISTS (SELECT 1 FROM students WHERE student_id = 'S0001' AND enrollment_status = 'active') THEN
  ROLLBACK;
  RAISE EXCEPTION 'Student S0001 does not exist or is not active';
END IF;

-- 2. Verify course exists and is active
IF NOT EXISTS (SELECT 1 FROM courses WHERE course_id = 'C001' AND course_status = 'active') THEN
  ROLLBACK;
  RAISE EXCEPTION 'Course C001 does not exist or is not active';
END IF;

-- 3. Check for duplicate enrollment
IF EXISTS (SELECT 1 FROM enrollments WHERE student_id = 'S0001' AND course_id = 'C001') THEN
  ROLLBACK;
  RAISE EXCEPTION 'Student S0001 already enrolled in course C001';
END IF;

-- 4. Create enrollment
INSERT INTO enrollments (enrollment_id, student_id, course_id, enrollment_status, enrollment_date)
VALUES ('E00004', 'S0001', 'C001', 'active', CURRENT_DATE);

-- 5. Log enrollment
INSERT INTO audit_log VALUES (DEFAULT, 'ENROLLMENT_CREATED', 'S0001 enrolled in C001', CURRENT_TIMESTAMP);

COMMIT;

// Result: Student enrolled only if all validations pass, otherwise entire transaction rolls back
```

---

### 5.3: Plagiarism Detection & Flagging
**Scenario:** Detect plagiarism with comparison check

```sql
-- Plagiarism detection transaction
BEGIN TRANSACTION ISOLATION LEVEL SERIALIZABLE;

-- Parameters: @student_id, @problem_id, @submission_id

-- 1. Get current submission code
WITH current_submission AS (
  SELECT submission_id, code FROM submissions
  WHERE submission_id = 'SUB000001'
)

-- 2. Compare with all previous submissions from same student+problem
INSERT INTO plagiarism_flags (flag_id, submission_id, matched_submission_id, similarity_score, flag_status, created_at)
SELECT 
  'PF' || LPAD(ROW_NUMBER() OVER (ORDER BY similarity DESC), 4, '0'),
  'SUB000001',
  s2.submission_id,
  -- Simplified similarity calculation (real implementation would be more complex)
  CASE 
    WHEN cs.code = s2.code THEN 100.00
    WHEN SIMILARITY(cs.code, s2.code) > 0.8 THEN SIMILARITY(cs.code, s2.code) * 100
    ELSE 0
  END AS similarity_score,
  'new',
  CURRENT_TIMESTAMP
FROM current_submission cs
CROSS JOIN LATERAL (
  SELECT s2.submission_id, s2.code,
         SIMILARITY(cs.code, s2.code) AS similarity
  FROM submissions s2
  WHERE s2.student_id = 'S0001'
    AND s2.problem_id = 'P0001'
    AND s2.submission_id != 'SUB000001'
    AND SIMILARITY(cs.code, s2.code) > 0.6  -- Only flag if >60% similar
  ORDER BY similarity DESC
) s2
WHERE s2.similarity > 0.6;

-- 3. Flag suspicious plagiarism
UPDATE plagiarism_flags
SET flag_status = 'reviewing'
WHERE submission_id = 'SUB000001'
  AND similarity_score > 85.0;

COMMIT;

// Result: Plagiarism flags created and flagged for review if high similarity detected
```

---

### 5.4: Regrade Request Processing
**Scenario:** Process regrade request with score update

```sql
-- Process regrade request
BEGIN TRANSACTION ISOLATION LEVEL SERIALIZABLE;

-- 1. Retrieve regrade request
WITH regrade AS (
  SELECT rr.request_id, rr.submission_id, s.student_id, s.problem_id
  FROM regrade_requests rr
  JOIN submissions s ON rr.submission_id = s.submission_id
  WHERE rr.request_id = 'RG0006'
)

-- 2. Verify submission exists (not already deleted)
IF NOT EXISTS (SELECT 1 FROM submissions WHERE submission_id = (SELECT submission_id FROM regrade)) THEN
  ROLLBACK;
  RAISE EXCEPTION 'Submission no longer exists';
END IF;

-- 3. Manually adjust test result
UPDATE test_results
SET awarded_points = 10,
    result_status = 'Passed'
WHERE submission_id = (SELECT submission_id FROM regrade)
  AND test_case_id = 'TC0001';

-- 4. Recalculate submission score
UPDATE submissions
SET score = (
  SELECT SUM(awarded_points)
  FROM test_results
  WHERE submission_id = (SELECT submission_id FROM regrade)
)
WHERE submission_id = (SELECT submission_id FROM regrade);

-- 5. Update regrade request status
UPDATE regrade_requests
SET request_status = 'approved',
    resolved_at = CURRENT_TIMESTAMP,
    resolution_notes = 'Score adjusted based on manual review'
WHERE request_id = 'RG0006';

-- 6. Create audit log
INSERT INTO audit_log (action, affected_record, details, timestamp)
VALUES ('REGRADE_APPROVED', 'RG0006', 'Score updated to ' || 
  (SELECT score FROM submissions WHERE submission_id = (SELECT submission_id FROM regrade)), 
  CURRENT_TIMESTAMP);

COMMIT;

// Result: Regrade processed atomically with audit trail
```

---

### 5.5: Concurrent Score Updates (Conflict Scenario)
**Scenario:** Two judges updating same submission score (should use serializable to prevent race)

```sql
-- UNSAFE: Without isolation level
BEGIN TRANSACTION;
UPDATE submissions SET score = 85 WHERE submission_id = 'SUB000001';
COMMIT;

-- ⚠️ Problem: If another transaction updates same row concurrently,
//    last update wins (lost update problem)

-- SAFE: Using SERIALIZABLE
BEGIN TRANSACTION ISOLATION LEVEL SERIALIZABLE;
UPDATE submissions SET score = 85 WHERE submission_id = 'SUB000001';
COMMIT;

-- ✓ PostgreSQL detects conflict and aborts one transaction
// If second transaction tries to update same row concurrently:
// ERROR: could not serialize access due to concurrent update
// → Application retries safely
```

---

## Section 6: Transaction Logging & Recovery

### 6.1: Write-Ahead Logging (WAL)
**Explanation:** PostgreSQL writes changes to log before applying to data

```sql
-- WAL ensures durability

-- User commits transaction
BEGIN TRANSACTION;
INSERT INTO submissions (...) VALUES (...);
COMMIT;

-- Behind the scenes:
-- 1. Change recorded in Write-Ahead Log (WAL)
-- 2. WAL flushed to disk (synchronously)
-- 3. COMMIT confirmed to user
// 4. Changes later applied to data pages (asynchronously)
// 5. If crash between 3 and 4, recovery replays WAL

-- Result: Even if system crashes immediately after commit,
// data is permanently saved
```

---

### 6.2: Transaction Log Inspection

```sql
-- View transaction log activity
SELECT 
  datname,
  pg_wal_lsn_diff(pg_current_wal_lsn(), '0/0') / 1024 / 1024 / 1024 AS wal_size_gb,
  checkpoint_timeout,
  max_wal_size
FROM pg_settings
WHERE name IN ('checkpoint_timeout', 'max_wal_size');

-- Monitor ongoing transactions
SELECT 
  pid,
  usename,
  xact_start,
  state,
  EXTRACT(EPOCH FROM (NOW() - xact_start)) AS transaction_duration_sec
FROM pg_stat_activity
WHERE xact_start IS NOT NULL
ORDER BY xact_start;

-- Identify long-running transactions (potential issues)
SELECT 
  pid,
  usename,
  state,
  query,
  EXTRACT(EPOCH FROM (NOW() - xact_start)) AS duration_sec
FROM pg_stat_activity
WHERE xact_start IS NOT NULL
  AND EXTRACT(EPOCH FROM (NOW() - xact_start)) > 300  -- Running > 5 minutes
ORDER BY xact_start;
```

---

## Section 7: Best Practices for Reliable Transactions

### 7.1: Keep Transactions Short
```sql
-- GOOD: Quick, focused transaction
BEGIN TRANSACTION;
INSERT INTO submissions (...) VALUES (...);
COMMIT;

-- BAD: Long transaction with external operations
BEGIN TRANSACTION;
-- HTTP request to plagiarism service (slow, might fail)
INSERT INTO submissions (...) VALUES (...);
-- Another HTTP request (even slower)
INSERT INTO plagiarism_flags (...) VALUES (...);
COMMIT;

-- Problem: Long transaction holds locks, increases deadlock risk
// Solution: Do external work outside transaction
```

---

### 7.2: Avoid Distributed Transactions
```sql
-- AVOID: Distributed transactions (complex, risky)
BEGIN;
  -- Update in codejudge database
  UPDATE submissions SET score = 100 WHERE submission_id = 'SUB000001';
  
  -- Update in external system (different database/server)
  -- [This is problematic - ACID guarantees don't span systems]
COMMIT;

-- BETTER: Use event-driven architecture
BEGIN;
  UPDATE submissions SET score = 100, notified = FALSE 
  WHERE submission_id = 'SUB000001';
COMMIT;

-- Separate process polls for notified = FALSE and updates external system
// Each system is consistent within its own boundaries
```

---

### 7.3: Error Handling in Transactions
```sql
-- Proper error handling pattern
CREATE OR REPLACE FUNCTION judge_submission(p_submission_id VARCHAR)
RETURNS TABLE(success BOOLEAN, message VARCHAR)
LANGUAGE plpgsql
AS $$
DECLARE
  v_error_message VARCHAR;
BEGIN
  BEGIN
    -- Wrap transaction in exception handler
    INSERT INTO submissions (...) VALUES (...);
    INSERT INTO test_results (...) VALUES (...);
    UPDATE submissions SET status = 'Accepted' WHERE ...;
    
    RETURN QUERY SELECT TRUE, 'Submission judged successfully'::VARCHAR;
    
  EXCEPTION WHEN OTHERS THEN
    -- Catch any error
    v_error_message := SQLSTATE || ': ' || SQLERRM;
    
    -- Log error
    INSERT INTO error_log (error_message, timestamp) VALUES (v_error_message, NOW());
    
    -- Return error to caller
    RETURN QUERY SELECT FALSE, v_error_message::VARCHAR;
    
    -- Transaction will rollback automatically
  END;
END;
$$;
```

---

## Section 8: Performance Considerations

### 8.1: Lock Timeouts
```sql
-- Set transaction lock timeout (prevent infinite waits)
SET statement_timeout = '5 seconds';  -- SQL statement times out after 5s
SET lock_timeout = '3 seconds';        -- Lock acquire times out after 3s

BEGIN TRANSACTION;
  -- If this statement takes > 5s, transaction aborts
  SELECT * FROM large_table WHERE condition;
COMMIT;

-- Reset to defaults
RESET statement_timeout;
RESET lock_timeout;
```

---

### 8.2: Batch Processing for Performance
```sql
-- INEFFICIENT: Individual inserts in loop
BEGIN TRANSACTION;
  FOR i IN 1..1000 LOOP
    INSERT INTO test_results (...) VALUES (...);
  END LOOP;
COMMIT;

-- EFFICIENT: Batch insert
BEGIN TRANSACTION;
  INSERT INTO test_results (...)
  SELECT ... FROM test_cases
  WHERE problem_id = 'P0001';
COMMIT;

// Batch: Single transaction overhead, better performance
```

---

## Summary

These transaction examples demonstrate:
- ✓ **Basic Transaction Control** (BEGIN, COMMIT, ROLLBACK, SAVEPOINT)
- ✓ **ACID Properties** (Atomicity, Consistency, Isolation, Durability)
- ✓ **Isolation Levels** (READ COMMITTED, REPEATABLE READ, SERIALIZABLE)
- ✓ **Deadlock Scenarios** (Detection, prevention, recovery)
- ✓ **Real-World CodeJudge Patterns** (Judging, enrollment, plagiarism)
- ✓ **Error Handling** (Rollback, exception handling, retry logic)
- ✓ **Performance Optimization** (Lock management, batching, timeouts)

All examples are directly applicable to CodeJudge domain requirements.
