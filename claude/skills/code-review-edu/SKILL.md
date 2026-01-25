---
name: code-review-edu
description: Thorough code review for bug prevention, performance, maintainability, and readability. Use when reviewing code, analyzing a codebase for issues, or when asked to find bugs, improve performance, simplify code, or suggest improvements. Triggers on phrases like "review this code", "find bugs", "improve this", "check for issues", or "what's wrong with this code".
---

# Code Review Edu

Conduct structured code reviews that prioritize bug prevention while teaching the reasoning behind recommendations.

## Review Priorities (in order)

1. **Bug Prevention** - Logic errors, edge cases, crashes, security issues
2. **Performance** - Inefficiencies, unnecessary operations, bottlenecks
3. **Maintainability** - Structure, modularity, future-proofing
4. **Readability** - Naming, formatting, comments, clarity

## Review Process

Follow these phases sequentially. Do not skip ahead.

### Phase 1: Assessment

Provide a summary:
- What the code does (brief overview)
- What's working well
- Initial concerns observed

### Phase 2: Findings

Present a prioritized list. For each finding:
- **What**: The issue
- **Where**: File and location
- **Why**: Impact or risk (explain reasoning)
- **Severity**: Critical / Important / Minor / Nitpick

### Phase 3: Plan

Before any changes, propose a plan:
- Group related fixes logically
- Suggest order of operations
- Note changes that may affect other files
- Identify quick wins vs. changes requiring careful testing

**Stop and wait for user approval before proceeding.**

### Phase 4: Implementation

After approval:
1. Tackle one logical group at a time
2. Explain what's changing and why
3. Show before/after when helpful
4. Run tests after changes
5. If tests fail, diagnose and adjust

## Communication Style

- Explain the "why" behind recommendations
- Use proper terminology but define it when introduced
- Be direct about problems while remaining constructive
- Assume technical background but not deep programming expertise
