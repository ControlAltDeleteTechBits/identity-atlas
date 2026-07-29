# Identity Atlas first community release checklist

Target release: `v0.14.0-preview.1`

Publisher: Control Alt Delete Tech Bits

Lead maintainer: Mark Oldham

Complete every required item before making the repository public.

## 1. Ownership and licence

- [ ] Confirm the legal owner named in the copyright notice.
- [ ] Confirm the MIT Licence is approved for Identity Atlas.
- [ ] Confirm `IdentityAtlas.psd1` names Mark Oldham as author.
- [ ] Confirm `IdentityAtlas.psd1` names Control Alt Delete Tech Bits as company.
- [ ] Confirm the repository is owned by the Control Alt Delete Tech Bits GitHub organisation.
- [ ] Confirm the project states that it is an independent community project.

## 2. GitHub account security

- [ ] Verify the maintainer’s email address.
- [ ] Enable two-factor authentication.
- [ ] Store recovery codes in a password manager.
- [ ] Add a second recovery method.
- [ ] Check that the organisation has no unknown members or applications.

## 3. Source safety

- [ ] Run `.\tools\Test-IdentityAtlasRelease.ps1`.
- [ ] Confirm the scan reports zero findings.
- [ ] Confirm `Output` is ignored by Git.
- [ ] Confirm `Release` is ignored by Git.
- [ ] Confirm no generated report is staged.
- [ ] Confirm no access token, secret, certificate or authentication context is staged.
- [ ] Confirm no local user path is staged.
- [ ] Confirm no live tenant identifier, email address or object identifier is staged.
- [ ] Confirm no confidential screenshot is staged.
- [ ] Review the complete first commit before pushing.

## 4. Product validation

- [ ] Run `.\build.ps1` with a valid Node.js path.
- [ ] Confirm every Pester test passes.
- [ ] Confirm every JavaScript test passes.
- [ ] Confirm PSScriptAnalyzer reports zero errors or warnings.
- [ ] Import the module from a clean folder.
- [ ] Connect with delegated read permissions.
- [ ] Generate a new development-tenant report.
- [ ] Confirm Applications, Roles, Policies, Insights, Timeline and Access explorer load.
- [ ] Confirm Settings opens.
- [ ] Confirm graph navigation and breadcrumbs work.
- [ ] Confirm SVG and PNG export work.
- [ ] Confirm there are no browser console errors.
- [ ] Disconnect Microsoft Graph after testing.

## 5. Release package

- [ ] Run `.\tools\New-IdentityAtlasRelease.ps1`.
- [ ] Confirm the ZIP name contains `v0.14.0-preview.1`.
- [ ] Confirm the SHA256 file was generated.
- [ ] Open the ZIP and inspect its contents.
- [ ] Confirm the ZIP contains no `Output`, `Tests`, `Release` or generated report data.
- [ ] Extract the ZIP into a clean folder.
- [ ] Run `Test-ModuleManifest` against the extracted manifest.
- [ ] Import the extracted module.
- [ ] Generate and open a report from the extracted module.

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
- [ ] Create tag `v0.14.0-preview.1` from the tested commit.
- [ ] Mark the release as a pre-release.
- [ ] Attach the clean ZIP.
- [ ] Attach the SHA256 file.
- [ ] Change repository visibility to public.
- [ ] Recheck the public Actions history and repository files.
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
