# Identity Atlas security policy

## Supported version

Security fixes are currently applied to the latest preview only.

Supported preview: 0.14.0

## Reporting a security issue

When the public GitHub repository has private vulnerability reporting enabled, use its `Report a vulnerability` form. Otherwise, email Mark@controlaltdeletetechbits.co.uk with the subject `Identity Atlas security report`.

Include the affected version, reproduction steps, expected result, observed result and the security impact. Do not attach a live tenant report, access token, client secret, password, certificate or other confidential material.

Please allow time to confirm the issue before publishing details.

## Product security boundary

Identity Atlas is read only. It requests delegated Microsoft Graph read permissions and creates a local static report.

Generated reports contain administrative evidence and are not encrypted. Anyone who can read the files can read the collected tenant information.

The local report server binds to the loopback interface and is intended only for review on the administrator's device. Do not expose it through a reverse proxy, port forwarding rule, shared web server or public hosting service.

## Administrator responsibilities

1. Review Microsoft Graph consent before accepting it.
2. Use a dedicated administrative workstation where possible.
3. Store reports and exports in an access controlled folder.
4. Follow organisational evidence retention requirements.
5. Delete reports and exports when they are no longer required.
6. Stop the report server after review.
7. Run `Disconnect-MgGraph` when collection is complete.
8. Clear browser site data when using a shared device.

## Security review

The current technical review is in `Docs/SECURITY-REVIEW.md`.
