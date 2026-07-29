# Identity Atlas first community release checklist

Target release: `v0.14.0-preview.1`

Publisher: Control Alt Delete Tech Bits

Lead maintainer: Mark Oldham

Complete every required item before making the repository public.

Private launch rehearsal completed against commit `50c8ed52220d4648c857d295a6371c3e35646f3e`.

Current release candidate SHA256:

```text
0F6666B7C6A3A51B834C18355CC870FDDC823C04D70236152F39B48FDB0C09DC
```

Checked items have technical or repository evidence. Owner confirmations and public publication actions remain unchecked.

## 1. Ownership and licence

- [ ] Confirm the legal owner named in the copyright notice.
- [ ] Confirm the MIT Licence is approved for Identity Atlas.
- [x] Confirm `IdentityAtlas.psd1` names Mark Oldham as author.
- [x] Confirm `IdentityAtlas.psd1` names Control Alt Delete Tech Bits as company.
- [x] Confirm the repository is owned by the Control Alt Delete Tech Bits GitHub organisation.
- [x] Confirm the project states that it is an independent community project.

## 2. GitHub account security

- [x] Verify the maintainer’s email address.
- [x] Enable two-factor authentication.
- [ ] Store recovery codes in a password manager.
- [ ] Add a second recovery method.
- [x] Check that the organisation has no unknown members or applications.

## 3. Source safety

- [x] Run `.\tools\Test-IdentityAtlasRelease.ps1`.
- [x] Confirm the scan reports zero findings.
- [x] Confirm `Output` is ignored by Git.
- [x] Confirm `Release` is ignored by Git.
- [x] Confirm no generated report is staged.
- [x] Confirm no access token, secret, certificate or authentication context is staged.
- [x] Confirm no local user path is staged.
- [x] Confirm no live tenant identifier, email address or object identifier is staged.
- [x] Confirm no confidential screenshot is staged.
- [x] Review the complete Git history before publication.

## 4. Product validation

- [x] Run `.\build.ps1` with a valid Node.js path.
- [x] Confirm every Pester test passes.
- [x] Confirm every JavaScript test passes.
- [x] Confirm PSScriptAnalyzer reports zero errors or warnings.
- [x] Import the module from a clean folder.
- [x] Connect with delegated read permissions.
- [x] Generate a new development-tenant report.
- [x] Confirm Applications, Roles, Policies, Insights, Timeline and Access explorer load.
- [x] Confirm Settings opens.
- [x] Confirm graph navigation and breadcrumbs work.
- [x] Confirm SVG and PNG export work.
- [x] Confirm there are no browser console errors.
- [x] Disconnect Microsoft Graph after testing.

## 5. Release package

- [x] Run `.\tools\New-IdentityAtlasRelease.ps1`.
- [x] Confirm the ZIP name contains `v0.14.0-preview.1`.
- [x] Confirm the SHA256 file was generated and matches the ZIP.
- [x] Open the ZIP and inspect its contents.
- [x] Confirm the ZIP contains no `Output`, `Tests`, `Release` or generated report data.
- [x] Extract the ZIP into a clean folder.
- [x] Run `Test-ModuleManifest` against the extracted manifest.
- [x] Import the extracted module in a fresh PowerShell process.
- [x] Serve a previously collected live tenant report with the extracted local server.
- [ ] Generate a new live tenant report from the extracted module during the final publication session.

## 6. Private repository inspection

- [ ] Complete `Docs/PRIVATE-REPOSITORY-INSPECTION.md`.
- [ ] Confirm the repository is still private during inspection.
- [ ] Confirm the first GitHub Actions validation passes.
- [ ] Inspect the Actions log for tenant data or local paths.
- [ ] Confirm commits show only the intended human author and committer.
- [ ] Confirm community files appear in the GitHub community profile.
- [ ] Enable private vulnerability reporting when available.

## 7. Public preview

- [ ] Prepare release notes from `CHANGELOG.md`.
- [ ] Obtain explicit approval to make the repository public.
- [ ] Change repository visibility to public.
- [ ] Create and verify the enforced `main` branch ruleset.
- [ ] Recheck the public Actions history and repository files.
- [ ] Create tag `v0.14.0-preview.1` from the tested commit.
- [ ] Mark the release as a pre-release.
- [ ] Attach the clean ZIP.
- [ ] Attach the SHA256 file.
- [ ] Publish the pre-release.
- [ ] Test the public download link in a signed-out browser session.

## 8. After publication

- [ ] Open an issue to track preview feedback.
- [ ] Monitor security notifications and issues.
- [ ] Record release and download evidence for the project activity log.
- [ ] Publish corrections as a new version.
- [ ] Do not replace an existing tagged release with different code.
- [ ] Review feedback before planning the first stable release.

## Release approval

Release approved by:

Date:

Tested commit:

ZIP SHA256:

Known limitations reviewed:
