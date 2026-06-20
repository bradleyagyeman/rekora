# AGENTS.md

Instructions for agents working on Rekora.

## Project Context

Rekora is an iPhone-first Apple Music backup app.

The MVP should prove that we can request Apple Music permission, read useful
library data, save local snapshots, export backups, and eventually rebuild
playlists where Apple allows it.

## Documentation State

Keep the project documentation current as the source of truth.

Update the relevant docs when meaningful project state changes:

- `README.md`: project summary, stack, app target, MVP scope, and current build
  direction.
- `PROJECT_STATE.md`: current handoff summary, latest validation results,
  changed files, commands already run, next steps, and open risks.
- `DEVELOPMENT.md`: deeper setup steps, Apple/Xcode/MusicKit requirements, and
  local development notes.
- `PROBLEM.md`: the user problem, product promise, scope, and recovery limits.
- `monetization.md`: pricing, paid features, free limits, subscriptions, or
  business model changes.
- `NAMING.md`: project name, naming rationale, runner-up names, and availability
  concerns.

## Documentation Checkpoints

Before finishing a meaningful change, check whether docs need updates.

Update docs when any of these change:

- The app target changes, such as iPhone-first, Mac support, or web support.
- The tech stack changes.
- The first build milestone changes.
- MusicKit, Apple Developer, Xcode, bundle ID, or permission setup changes.
- The snapshot schema changes.
- Backup, export, restore, or playlist rebuild behavior changes.
- User-visible behavior changes.
- Known limitations or product promises change.
- Monetization, pricing, paid features, or free features change.
- The project name, positioning, or public-facing language changes.

Do not update docs for tiny internal refactors unless they change how the
project works, how users experience it, or how future agents should continue.

## Commit And Issue Hygiene

- Use short scoped commit messages, such as `docs:`, `app:`, or `build:`.
- Keep commit subject lines under 80 characters.
- Use `gh` for GitHub issues when available.
- Use at most one label per GitHub issue.
- Prefer these labels: `bug`, `enhancement`, `documentation`, `security`,
  `maintenance`, `question`.
- Keep `main` as the default branch.
- After initial setup, do feature and bug-fix work on branches instead of
  committing directly to `main`.
- Use branch names like `feature/ios-scaffold`, `feature/musickit-permission`,
  or `fix/snapshot-export`.
- Suggest an annotated semantic version tag when the first working app,
  significant feature, breaking change, or notable bug fix lands.
- The first working release should use `v0.1.0`.
- Use annotated tags only, for example:
  `git tag -a v0.1.0 -m "Initial release"`.

## Safety And Privacy

Treat Apple Music library data as personal user data.

- Keep the MVP local-first.
- Do not store library data on external servers unless the user clearly opts in.
- Do not sell listening or library data.
- Be honest that Rekora may not restore every song perfectly.
- Make export available to users without locking their own data behind payment.

## Xcode Tooling

Keep Xcode command-line setup project-specific.

- Do not change the global active developer directory with `sudo xcode-select`
  for this project unless the user explicitly asks.
- Prefer setting `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer`
  on Rekora build/test commands.
- If build commands become repetitive, add project-local wrappers such as a
  `Makefile` or script that sets `DEVELOPER_DIR` internally.
- Document any required project-local build wrappers in `PROJECT_STATE.md` and,
  when they are durable setup details, in `DEVELOPMENT.md`.

## Before Final Response

In the final response, mention:

- What changed.
- Which docs were updated, if any.
- What tests or checks were run.
- Any setup or permission work still needed.
