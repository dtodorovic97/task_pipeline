## Data Model

**Decision**: Use a single tasks table with a JSONB column (attempts) to store attempt history directly on the task record.

**Rationale**: For the scope of this assignment, co locating attempts with their parent task keeps the data model simple and avoids additional joins or foreign key management. The assignment does not require cross task analytics on attempts, so normalization was not necessary.

**Pros**:
- Simpler schema (single table)
- No joins required when returning task details
- Straightforward serialization in API responses
- Faster development within time constraints
- Fully satisfies the operational requirements


**Cons**:
- Harder to query attempts independently across tasks
- Less efficient for global aggregations (e.g., "all failed attempts")
- Requires careful handling of JSONB updates to avoid potential race conditions
- Slightly more storage overhead compared to normalized rows

## Separation of Persistence Constraints and Lifecycle Rules

**Decision**: Use database enums to restrict valid status values, while enforcing allowed status transitions at the application layer.

**Rationale**: The database is responsible for guaranteeing that only valid status values (queued, processing, completed, failed) can be stored. However, it does not enforce how those values may transition from one to another.
Lifecycle rules are enforced in the changeset layer instead of the database because transitions represent domain behavior, not just data constraints. This keeps the persistence layer simple while ensuring business rules remain explicit and centralized in the application code.

## Consistency Between Persistence and Background Processing

**Decision**: Task insertion and job enqueueing are executed within the same database transaction.

**Rationale**: A task should never exist in the system without being scheduled for execution. By wrapping both operations in a single transaction, we ensure atomicity either both the task and its corresponding Oban job are created, or neither is.

**Considered Alternative Aproach**: In systems where execution can be deferred, tasks might be persisted independently and scheduled later via a periodic dispatcher job. However, this project assumes immediate processing upon creation, making transactional consistency the most straightforward and reliable approach.

## Concurrency Safe Task Handling

**Decision**: Implement task claiming using a conditional UPDATE statement that transitions a task from queued to processing only if it is still in the queued state.

**Rationale**: Multiple workers may attempt to process the same task concurrently. Instead of reading the task and then updating it (which would introduce a race condition), the system performs a single atomic database operation. The database guarantees that only one process can successfully update the row. If no rows are affected, the task was already claimed or does not exist.

**Pros**:
- Eliminates race conditions without explicit row locking
- Avoids the need for pessimistic SELECT ... FOR UPDATE
- Requires only one database round trip
- Scales safely across multiple worker processes or nodes

## Explicit Task Lifecycle Enforcement

**Decision**: Enforce allowed status transitions within the schema layer using changeset validation logic.

**Rationale**: The task lifecycle represents a domain rule, not just a persistence concern. By validating transitions inside update_changeset/2, the state machine is enforced consistently regardless of whether updates originate from the worker, context layer, or elsewhere.
This keeps lifecycle rules centralized, explicit, and impossible to bypass accidentally.

## Test Coverage and Verification Strategy

**Approach**: The test suite is structured to validate both correctness and behavioral guarantees across the full stack, from schema validations to background processing and HTTP boundaries. Rather than focusing only on happy paths, the goal was to ensure lifecycle integrity, retry behavior, and concurrency safety are verifiable through automated tests.

**Basic Cases Covered**: Tests span all layers of the application and schema validations, domain logic, background processing, and HTTP endpoints, ensuring correct lifecycle behavior, retry handling, concurrency safety, and proper API responses.

**Edge Cases Covered**:
- Competing workers attempting to claim the same task
- Exhaustion of retry limits

**Oban**: Oban’s testing utilities are used to assert job scheduling and execution behavior in a controlled, synchronous test environment.


