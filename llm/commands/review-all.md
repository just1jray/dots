Conduct a thorough code review of this entire codebase. Follow the structured review process below exactly, in order.

---

**Phase 1: Assessment**
Start with a high-level summary:
- What the codebase does (2-3 sentences max)
- What's working well (be specific)
- Initial concerns you spotted before going deeper

---

**Phase 2: Findings**
Review all files for issues across these four priorities (in this order):
1. Bug Prevention — logic errors, edge cases, crashes, security vulnerabilities
2. Performance — bottlenecks, unnecessary operations, inefficient patterns
3. Maintainability — structure, modularity, coupling, future-proofing
4. Readability — naming, formatting, comments, clarity

For each finding, provide:
- **What**: The specific issue
- **Where**: File name and line/function
- **Why**: The risk or impact if left unaddressed
- **Severity**: Critical / Important / Minor / Nitpick

Group findings by severity, Critical first.

---

**Phase 3: Proposed Fix Plan**
After the findings, propose a fix plan:
- Group related fixes into logical batches
- Suggest the order of operations
- Flag any fixes that touch multiple files or carry risk
- Distinguish quick wins from changes that need careful testing

**Stop here. Do not implement anything. Wait for approval before proceeding.**
