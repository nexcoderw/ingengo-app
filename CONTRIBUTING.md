# Contributing to Ingengo App

Thanks for helping improve Ingengo. Documentation, bug reports, tests, fixes,
and feature ideas are welcome. Development can use a local API and synthetic
data.

## Choose a contribution

- **Report a bug.** Search existing [issues](https://github.com/nexcoderw/ingengo-app/issues)
  and include the app version or commit, platform, expected behavior, and
  steps using synthetic data.
- **Propose a feature.** Describe the problem, who it affects, and the
  user-visible outcome. Discuss changes to native permissions, payments, or
  backend contracts early.
- **Improve docs or tests.** Clarify a local setup step, cover an error state in
  a widget test, or add a synthetic parser fixture.
- **Report a vulnerability.** Follow the private reporting instructions in
  [SECURITY.md](SECURITY.md).

## Make your first pull request

1. Fork the repository and clone your fork. Follow the
   [local setup](README.md#getting-started) and configure a development API.
2. Add the upstream repository and start a branch from its latest `main`.

   ```bash
   git remote add upstream https://github.com/nexcoderw/ingengo-app.git
   git fetch upstream
   git switch --no-track -c docs/clarify-flutter-setup upstream/main
   ```

3. Address one outcome. Keep code with the feature that owns it.
   Reuse shared theme, HTTP, and session-storage components where appropriate.
4. Make one commit per changed file. Use a lowercase, imperative Conventional
   Commit subject of at most 72 characters. See the [Git rules](.agents/git.md).

   ```bash
   git add -- README.md
   git diff --cached --name-only
   git diff --cached --check
   git commit -m "docs(setup): clarify flutter setup"
   git push -u origin docs/clarify-flutter-setup
   ```

5. [Open a pull request](https://github.com/nexcoderw/ingengo-app/compare) against
   upstream `main`. Explain what changed, the targets you checked, and which
   checks ran. Use a draft if verification is still pending. Continue review
   fixes on the same branch.

## Verify your work

Run the [development checks](README.md#testing-and-builds) for code changes.
Mirror the source path under `test/` when adding a test. Use fakes for HTTP,
storage, and platform channels as appropriate. Use synthetic users, numbers,
and messages for tests, screenshots, and recordings.

For UI changes, check relevant loading, error, empty, and accessibility states.
For device integrations, check unsupported platforms and denied permissions
and verify on the affected target. For a backend contract change, link the
[API PR](https://github.com/nexcoderw/ingengo-api/pulls) and describe the merge
and release order. Check the [app rules](AGENTS.md) for repository-specific details.

## Work together

Ask questions and explain the reasoning behind feedback. Community spaces follow
the [code of conduct](CODE_OF_CONDUCT.md). Maintainers review changes and handle
production configuration and release signing.
