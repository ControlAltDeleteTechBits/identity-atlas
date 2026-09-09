# Version 1.1.0 publication checklist

Prepared: 9 September 2026

## Current position

The implementation, automated tests and fresh live validation are complete within the limits recorded in LIVE-VALIDATION-2026-09-09.md. Changes remain uncommitted. Local main matches remote main at 6b1a212a3ec11aadce404cd63e0a2cb3957bcfdc. The remote tag v1.1.0 did not exist when checked. GitHub CLI was not available on PATH in the current terminal.

Release notes and the bug report version example were prepared after the last package build. Existing local packages must therefore be rebuilt; their earlier checksums must not be used for the final publication.

## Ordered publication gates

1. Obtain confirmation to upload and publish version 1.1.0. Review the documented validation limits with the maintainer.
2. Locate or install GitHub CLI and verify its authenticated account. Verify the repository's configured Git author is the maintainer. Do not add automated co-author attribution.
3. Review the complete diff, including new files. Keep Output, checkpoints, transcripts, Gallery and Release artefacts excluded from Git.
4. Commit the approved source, tests and documentation on a release branch. Push that branch, open a pull request and require successful validation before merging. Do not bypass repository protections.
5. Synchronise local main with the merged commit. Confirm the worktree is clean and rebuild both packages from that commit. Run the full build, public release security scan and isolated Gallery package checks again using explicit package paths.
6. Create and push v1.1.0 at the tested main commit. Use tools/Publish-IdentityAtlasGitHubRelease.ps1 with the prepared release notes to create a draft, upload the ZIP and checksum, and verify downloaded assets. Do not replace already published assets.
7. Inspect the draft and publish only after its asset verification succeeds. Remove the prepared/unpublished status wording from the public release description at publication.
8. Publish the same approved version to PowerShell Gallery using a short-lived key limited to new versions of IdentityAtlas. Keep the key out of chat, source, transcripts and logs. Revoke it after publication.
9. Download the published ZIP and Gallery package independently. Verify hashes where applicable, perform clean imports, check exported commands and verify the installed version. Do not describe a local package test as a published installation test.
10. Update release links and publication records only after both services expose the intended version. Announce the update with its relevant coverage limits.

The public release helper requires a clean checkout and a local and remote tag resolving to the tested commit. Review its current parameters before execution. Publication is not complete merely because a tag or draft exists.
