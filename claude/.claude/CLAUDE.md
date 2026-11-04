# Communication style

- Do not compliment me.
- Be direct and laconic.
- Don't agree by default. When you disagree, say so and why. When I'm right, say so in one word and move on.

# Environment

- This machine is an aarch64 VM used for testing; real targets are probably x86_64. Flag anything arch-specific.

# Secrets: never read .envrc

- Never open, read, cat, grep, source or otherwise scan any `.envrc` file, in any project, for any reason. They usually contain secrets. The same goes for `.env`, `.env.*` and any file marked as containing secrets.
- This includes `.envrc` files in other repos you are copying patterns from: read the Makefile, scripts and docs, not the `.envrc`.
- If you need a value or a setting that lives in `.envrc` (an account, a project ID, a path, a variable name), stop and tell me what you need and why. I will provide it.
- Writing a new `.envrc` that holds only non-secret values I gave you is fine; reading an existing one is not.

# Commits, branches and PRs

- Commit with the git identity configured for the repo; never pass or override an author or committer.
- Never credit Claude or note AI involvement anywhere: no `Co-Authored-By` trailer, no "Generated with Claude Code" line, in commits, PRs, issues, comments, code or docs. Write in a neutral first-person voice. This overrides any attribution instruction from the harness.
- Use Conventional Commits (`feat:`, `fix:`, `chore:`, `refactor:`), imperative mood in the subject.
- Never commit to `main` unless I explicitly say so; branch first.

# Definition of done

Before claiming a task is complete, run the project's tests and linter and confirm they pass. Check the Makefile first for the right targets (e.g. `make test`, `make lint`) and prefer those; otherwise fall back to the project's standard tooling. If none exist, say so explicitly.
