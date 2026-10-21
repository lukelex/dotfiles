# Software Architecture Rules

When designing, implementing, or reviewing software, follow these rules:

1. **Put decisions where the knowledge lives.**  
   The component with the most complete domain context should make the decision. Do not push responsibility downstream and force another component to reconstruct intent.

2. **Prefer explicit behavior over clever generic abstractions.**  
   A few clear domain-specific implementations are better than one highly configurable abstraction full of type checks, flags, callbacks, or inferred behavior.

3. **Do not abstract prematurely.**  
   Start with concrete use cases. Extract shared behavior only when the common concept is clear and meaningful, not merely because code looks similar.

4. **Protect responsibility boundaries.**  
   A child, shared service, serializer, notification handler, or infrastructure component should not gradually become responsible for interpreting what its callers meant. Push that decision back to the caller when the caller has the necessary context.

5. **Model business operations, not implementation mechanics.**  
   Prefer APIs and services that describe domain intent, such as `ReleaseDocument`, `AcceptChangeRequest`, or `AddGroupMember`, rather than generic processors with many configuration options.

6. **Treat timing as part of the architecture.**  
   Ask not only *what* should happen, but *when*. Keep behavior synchronous when it is required for the originating operation to be valid. Move non-essential side effects to background processing.

7. **Treat transactions as semantic boundaries.**  
   A transaction should encompass everything that must succeed for the requested business operation to truthfully be considered complete.

8. **Design the failure path alongside the happy path.**  
   For every operation, understand:
   - What can partially succeed?
   - What does failure mean?
   - Can it safely retry?
   - Is it idempotent?
   - Can it resume?
   - What state is left behind?

9. **Make invalid states difficult to create.**  
   Enforce important invariants as close to the authoritative data as possible. Prefer database constraints for true data invariants rather than relying exclusively on application validation.

10. **Preserve context instead of recreating it later.**  
    Perform work while the authoritative information is available. Avoid pipelines that throw away domain knowledge and later rediscover it through queries, type inspection, or state inference.

11. **Keep infrastructure side effects separate from domain intent.**  
    Events, jobs, emails, notifications, analytics, and similar consequences should not unnecessarily complicate the core business operation.

12. **Prefer Rails/platform-native mechanisms first.**  
    Use the framework and database capabilities already available before introducing custom infrastructure. However, avoid framework magic when it hides important behavior.

13. **Make performance characteristics visible and predictable.**  
    Know where queries, network calls, memory usage, and expensive computation happen. Avoid hidden I/O, especially in serializers, callbacks, and presentation code.

14. **Optimize architecture for reasoning, not minimum line count.**  
    Slight duplication is acceptable when it makes behavior obvious. Removing five lines of code is not valuable if understanding the resulting abstraction becomes substantially harder.

15. **Test contracts and observable behavior.**  
    Tests should primarily prove that an input or business intent produces the correct externally observable result. Avoid coupling tests unnecessarily to private implementation details.

16. **Design across the whole system.**  
    Application code, database behavior, queues, deployment, infrastructure, monitoring, and CI/CD are parts of the same architecture. Do not solve an application problem while ignoring its operational consequences.

17. **Keep scope disciplined.**  
    Solve the problem being addressed. Do not introduce unrelated abstractions, cleanup, or redesign unless they are necessary for correctness or the requested architectural direction.

18. **Use complexity only when the problem has earned it.**  
    Before introducing another abstraction, service, event, state machine, or layer, ask:

    > Is this a genuinely different concept, or merely a different caller/use case?

## Default decision heuristic

When uncertain, ask these questions in order:

1. **Who has the information required to make this decision correctly?**
2. **What business invariant are we protecting?**
3. **When must this happen for that invariant to remain true?**
4. **What happens if it fails halfway through?**
5. **Can the database enforce any part of this invariant?**
6. **Does this abstraction make the system easier or harder to reason about?**
7. **Is the additional complexity justified by an actual requirement?**

Favor designs where the answers remain obvious when another developer reads the code six months later.
