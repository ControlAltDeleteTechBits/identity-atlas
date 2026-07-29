# Identity Atlas private repository inspection

Use this procedure after the first private push and before changing repository visibility.

## 1. Confirm repository identity

In GitHub, confirm:

1. The owner is Control Alt Delete Tech Bits.
2. The repository name is `identity-atlas`.
3. Visibility is `Private`.
4. The default branch is `main`.
5. The description accurately describes a local, read-only Microsoft Entra relationship explorer.
6. The website field is empty unless an approved project page exists.

## 2. Inspect the complete file list

From the local repository:

```powershell
git status --short
git ls-files
```

The list must not contain:

```text
Output/
Release/
work/
attachments/
.codex/
report.json
live tenant exports
release ZIP files
authentication material
local screenshots
```

Compare the local list with the Files view on GitHub.

## 3. Inspect authorship

Run:

```powershell
git log --format="commit: %H%nauthor: %an <%ae>%ncommitter: %cn <%ce>%nsubject: %s%n"
```

Confirm:

1. The author is Mark Oldham.
2. The author email is the intended verified GitHub email.
3. The committer is the expected human account.
4. Commit messages contain no additional automated author attribution.
5. No unknown account appears in the history.

## 4. Repeat the safety scan

Run:

```powershell
.\tools\Test-IdentityAtlasRelease.ps1
```

The result must report `Status: Passed` and zero findings.

Review the GitHub commit diff as well as the current file contents. Removing a sensitive file in a later commit does not remove it from the earlier history.

If tenant data or a credential reached the private repository, do not make the repository public. Revoke any exposed credential, remove the unsafe history and repeat the inspection.

## 5. Inspect GitHub Actions

Open `Actions`, select the `Validate` workflow and inspect every step.

Confirm:

1. Source scanning passed.
2. PowerShell tests passed.
3. JavaScript tests passed.
4. PSScriptAnalyzer passed.
5. Clean package generation passed.
6. No log contains a tenant identifier, user detail, object identifier, local path or credential.
7. The workflow has read-only repository permission.
8. The workflow does not create commits or releases.

## 6. Inspect community controls

Confirm GitHub recognises:

1. `README.md`
2. `LICENSE`
3. `CODE_OF_CONDUCT.md`
4. `CONTRIBUTING.md`
5. `SECURITY.md`
6. Bug and feature issue forms
7. Pull request template
8. `CODEOWNERS`

Create a temporary draft issue and draft pull request to check that the templates load. Close the drafts after inspection.

## 7. Test a fresh clone

Clone the private repository into a new folder using GitHub Desktop or:

```powershell
git clone REPOSITORY-URL IdentityAtlas-CleanReview
Set-Location .\IdentityAtlas-CleanReview
$nodePath = (Get-Command node -ErrorAction Stop).Source
.\build.ps1 -NodePath $nodePath
.\tools\New-IdentityAtlasRelease.ps1 -NodePath $nodePath
```

Do not copy files from the original working folder into this clone.

Inspect the new release ZIP and checksum.

## 8. Configure repository protection

After the validation workflow has passed:

1. Create a ruleset for `main`.
2. Block force pushes.
3. Block deletion.
4. Require the `PowerShell and JavaScript tests` status check.
5. Require pull requests for community changes.
6. Keep an owner bypass available for an emergency while the project has one maintainer.

## 9. Final visibility review

Before selecting `Public`, confirm:

1. The source and complete history are safe to disclose.
2. Actions logs are safe to disclose.
3. The release package passed a clean installation test.
4. The release notes describe preview limitations.
5. The support and security routes work.
6. The release checklist has been signed and dated.

Changing visibility is the final publication step, not a testing step.
