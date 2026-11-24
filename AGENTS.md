# Ingengo Flutter Agent Rules

These instructions apply to the entire `app` project.

Before changing code, read the rule documents relevant to the task from the
`.agents/` directory:

- `.agents/folder-structure.md` for ownership and dependency boundaries.
- `.agents/coding-standards.md` for Dart, Flutter, UI, and API conventions.
- `.agents/security.md` for secrets, authentication, storage, and network safety.
- `.agents/environment.md` for runtime configuration.
- `.agents/testing.md` for validation expectations.
- `.agents/git.md` before editing and for branch, commit, and pull request handoffs.

## Required Workflow

1. Preserve unrelated user changes and inspect the working tree before editing.
2. Keep changes inside this Flutter project unless the user explicitly expands the scope.
3. Do not run formatting, analysis, tests, builds, dependency installation, or application processes unless the user explicitly asks. Provide the exact commands for the user to run.
4. Use feature-first architecture and remove stale imports, routes, dependencies, tests, and platform configuration when deleting a feature.
5. Never read, print, modify, or commit real secrets from `.env` files.
6. Use read-only Git commands. Follow `.agents/git.md` for the pre-edit branch report, one commit
   command pair per changed file, and the complete PR handoff.

When instructions conflict, the user's current request takes precedence.
