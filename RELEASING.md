# Releasing Moltbot

This document describes how to create releases for the Moltbot deployment repository.

## Versioning Scheme

Moltbot uses **semantic versioning** (MAJOR.MINOR.PATCH), starting at `0.1.0`.

- **MAJOR**: Breaking changes (e.g., systemd service breaking changes, incompatible deployment steps)
- **MINOR**: New features (e.g., new deployment script, new workflow capability)
- **PATCH**: Bug fixes and improvements (e.g., security hardening, script fixes)

The current version is stored in the `VERSION` file at the repository root.

## Commit Message Format

Releases are automated using **conventional commits**. When creating commits, follow this format:

```
<type>: <description>

[optional body]

[optional footer]
```

### Commit Types

| Type | Bumps | Example |
|------|-------|---------|
| `feat:` | MINOR | `feat: add new systemd hardening option` |
| `fix:` | PATCH | `fix: correct installation script on low-memory VPS` |
| `docs:` | — | `docs: clarify deployment steps in README` |
| `chore:` | — | `chore: update yamllint config` |
| `ci:` | — | `ci: add release workflow` |
| `refactor:` | — | `refactor: simplify deploy.sh logic` |
| `test:` | — | `test: add shellcheck to CI` |

### Breaking Changes

For breaking changes, use either:

1. Add `BREAKING CHANGE:` footer:
   ```
   feat: change systemd service structure

   BREAKING CHANGE: systemd unit file format changed, requires reinstallation
   ```

2. Or suffix the type with `!`:
   ```
   feat!: rewrite deployment mechanism
   ```

Both approaches trigger a **MAJOR** version bump.

## Creating a Release

### Automated Release (Recommended)

1. **Push your commits to `main`** with proper conventional commit messages
2. **Go to Actions > Release workflow** on GitHub
3. **Click "Run workflow"**
4. **Select version bump type:**
   - `auto`: Auto-detect from commit messages since last release (recommended)
   - `patch`: Manually force a patch version bump (0.1.0 → 0.1.1)
   - `minor`: Manually force a minor version bump (0.1.0 → 0.2.0)
   - `major`: Manually force a major version bump (0.1.0 → 1.0.0)

The workflow will:
- Analyze commits since the last release
- Calculate the next semantic version
- Update the `VERSION` file
- Create a git tag (e.g., `v0.2.0`)
- Create a GitHub Release with auto-generated changelog
- Push the updated `VERSION` file and tag to `main`

### Manual Release (If Needed)

If the automated workflow fails or you need to create a release manually:

1. **Update the VERSION file:**
   ```bash
   echo "0.2.0" > VERSION
   ```

2. **Commit the change:**
   ```bash
   git add VERSION
   git commit -m "chore: bump version to 0.2.0"
   ```

3. **Create a git tag:**
   ```bash
   git tag -a v0.2.0 -m "Release version 0.2.0"
   ```

4. **Push the commit and tag:**
   ```bash
   git push origin main
   git push origin v0.2.0
   ```

5. **Create a GitHub Release:**
   - Go to **Releases > Draft a new release**
   - Select the tag you just created
   - Add a title (e.g., "v0.2.0")
   - Add release notes (list key changes, bug fixes, new features)
   - Click "Publish release"

## Deployment & Version Tracking

Each time the deployment workflow runs, it:
- Captures the repository version from the `VERSION` file
- Stores it on the VPS at `/opt/moltbot-version` for tracking
- Displays it in the deployment logs and health check output

To check which version is currently deployed on your VPS:

```bash
# On your VPS
cat /opt/moltbot-version
```

Or check the deployment history in GitHub:
- Go to **Settings > Environments > production**
- View deployment history with associated versions

## Example Release Workflow

Here's a typical release cycle:

1. **Develop and test changes** on a feature branch
2. **Open a pull request** against `main` with conventional commit messages
3. **Merge to `main`** once approved
4. **Go to Actions > Release** and trigger the workflow with `auto` detection
5. **Verify the release** — check GitHub Releases page and `VERSION` file
6. **Trigger a deployment** — workflow runs automatically on VERSION file changes, or manually trigger via Actions > Deploy to VPS

## Tips & Best Practices

- **Squash commits before merging:** Use `squash and merge` on PRs to create a clean history for release analysis
- **Group related changes:** Each PR should represent one logical feature or fix
- **Clear commit messages:** Help the release workflow detect the right version bump
- **Review release notes:** The auto-generated changelog lists all commits since the last release
- **Tag stable releases:** Don't tag experimental or temporary commits as releases
- **Keep VERSION file updated:** The `VERSION` file is the single source of truth

## Rollback

If you need to rollback to a previous version:

1. **Check available versions:**
   ```bash
   git tag -l | grep '^v'
   ```

2. **Check out the previous version:**
   ```bash
   git checkout v0.1.0
   git checkout -b rollback-to-0.1.0
   ```

3. **Update VERSION file and push:**
   ```bash
   echo "0.1.0" > VERSION
   git add VERSION
   git commit -m "chore: rollback to version 0.1.0"
   git push origin rollback-to-0.1.0
   ```

4. **Merge to main** and trigger deployment

## Troubleshooting

### Release workflow fails to push to main

- Check that the release workflow has `contents: write` permission (it does by default)
- Ensure the GitHub token has write access to the repository

### Commits not detected correctly

- Verify commits follow the conventional commit format
- Common mistake: forgetting the colon after type (e.g., `feat` instead of `feat:`)

### Version not updated on VPS

- The deployment workflow automatically runs when `VERSION` file changes on `main`
- You can manually trigger deployment via Actions > Deploy to VPS > Run workflow
- Check GitHub Actions logs for deployment status

## Questions?

Refer to:
- [CONTRIBUTING.md](CONTRIBUTING.md) — Contribution guidelines and commit format
- [CLAUDE.md](CLAUDE.md) — Project conventions and architecture notes
- [README.md](README.md) — Quick start and deployment reference
