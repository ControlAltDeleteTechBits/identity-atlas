# Identity Atlas community contribution model

## Decision

Identity Atlas accepts community contributions through GitHub issues and pull requests.

Control Alt Delete Tech Bits remains the publisher and project owner. Mark Oldham remains the lead maintainer and makes the final decision on scope, permissions, security boundaries and releases.

Contributors do not receive direct write access by default. They work in a fork or separate branch and propose a pull request.

## Why this model fits the project

1. Administrators can report problems found in different tenant configurations.
2. Contributors can add tests, documentation and Microsoft Graph coverage.
3. Every proposed change remains reviewable before it reaches `main`.
4. Automated validation can reject unsafe or broken changes.
5. The public history shows community use and the maintainer’s continuing leadership.

Community participation does not transfer ownership of the project. A merged contributor remains the author of their commit while the repository and releases remain under Control Alt Delete Tech Bits.

## Contribution levels

### Feedback

Anyone can open an issue, describe a use case or confirm whether a fix works.

### Documentation and tests

These are suitable first contributions and normally have a lower security risk than new collectors.

### Code

Code changes require tests, a privacy review and maintainer approval.

### New Microsoft Graph collectors

These require an issue and design agreement before implementation. The proposal must identify:

1. The administrator question being answered.
2. The Microsoft Graph endpoint.
3. The least-privileged delegated permission.
4. The new object and relationship types.
5. Expected tenant-data sensitivity.
6. Partial-coverage behaviour.
7. Test coverage.

## Maintainer controls

1. Protect `main` from force pushes and deletion.
2. Require the validation workflow to pass.
3. Require pull requests for community changes.
4. Review every permission or schema change.
5. Keep release creation limited to the maintainer.
6. Revoke access promptly when it is no longer required.
7. Do not merge a change merely because it has community support.

## Recognition

Human contributors are recognised through the Git history. Release notes may thank people for substantial accepted work.

The project does not add automated tools as authors. The person submitting a change is responsible for reviewing it, testing it and confirming that it can be licensed under MIT.

## Microsoft MVP evidence

An open project can support an MVP nomination when it produces genuine, sustained benefit for the Microsoft technical community. The project alone does not guarantee nomination.

Keep a private activity record containing:

1. Release dates and release notes.
2. Download counts and adoption milestones.
3. Issues answered and problems resolved.
4. Accepted community contributions.
5. Administrator feedback that you have permission to retain.
6. Blog posts, demonstrations and talks.
7. Documentation improvements.
8. Microsoft product feedback arising from the project.

Record outcomes rather than chasing superficial numbers. A small number of administrators solving real identity problems is better evidence than unexplained traffic.
