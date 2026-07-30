# Identity Atlas first community release checklist

Target release: `v0.14.0-preview.1`

Publisher: Control Alt Delete Tech Bits

Lead maintainer: Mark Oldham

Complete every required item before making the repository public.

Private launch rehearsal completed against commit `f2bc942d784a6b8dbef3606e6495e32b86fe9d66`.

Current release candidate SHA256:

```text
E062075D5169AEF9E7566DADFE82A1C94058D79BA33C398B8C06CC8AB180CE20
```

Checked items have technical or repository evidence. Owner confirmations and public publication actions remain unchecked.

## 1. Ownership and licence

- [x] Confirm the legal owner named in the copyright notice.
- [x] Confirm the MIT Licence is approved for Identity Atlas.
- [x] Confirm `IdentityAtlas.psd1` names Mark Oldham as author.
- [x] Confirm `IdentityAtlas.psd1` names Control Alt Delete Tech Bits as company.
- [x] Confirm the repository is owned by the Control Alt Delete Tech Bits GitHub organisation.
- [x] Confirm the project states that it is an independent community project.

## 2. GitHub account security

- [x] Verify the maintainer’s email address.
- [x] Enable two-factor authentication.
- [x] Store recovery codes in a password manager.
- [x] Add a second recovery method.
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
- [x] Run `.\tools\Test-IdentityAtlasPublicRelease.ps1` against the final release candidate.

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
- [x] Generate a new live tenant report from an extracted release candidate and re-render it with the final package assets.

## 6. Private repository inspection

- [x] Complete `Docs/PRIVATE-REPOSITORY-INSPECTION.md`.
- [x] Confirm the repository is still private during inspection.
- [x] Confirm the first GitHub Actions validation passes.
- [x] Inspect the Actions log for tenant data or local paths.
- [x] Confirm commits show only the intended human author and committer.
- [x] Confirm the bug, feature and security-report routes recognise the repository templates.
- [x] Enable the dependency graph, Dependabot alerts, security updates and grouped security updates.
- [x] Recheck the GitHub community profile after the repository becomes public.
- [x] Enable private vulnerability reporting after GitHub exposes the control for the public repository.

The GitHub Free private-repository view did not expose the Community Profile or private vulnerability reporting controls. Both were verified immediately after public visibility was enabled.

## 7. Public preview

- [x] Prepare release notes from `CHANGELOG.md`.
- [x] Obtain explicit approval to make the repository public.
- [x] Change repository visibility to public.
- [x] Create and verify the enforced `main` branch ruleset.
- [x] Recheck the public Actions history and repository files.
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
