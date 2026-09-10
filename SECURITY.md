# Security reporting

OpenLid processes screen content, so unintended recording, disclosure, capture after pause, permission bypass, or unsafe overlay behavior deserve careful handling.

## Report privately

On GitHub, use **Security → Advisories → Report a vulnerability** if the repository offers it. That reporting channel must be enabled by a repository administrator; adding this file does not enable it.

If private reporting is unavailable, open an issue asking only for a private security contact. Do not include exploit details, sensitive logs, screenshots of personal content, or credentials in that issue. Wait for a private channel before sending the report. The maintainer setup checklist requires enabling private reporting before launch.

A useful private report includes the affected commit or build, macOS version, hardware model (not serial number), reproduction steps using synthetic content, expected behavior, observed impact, and any suggested mitigation.

## Support status

The project is an unreleased alpha. There are no supported production releases or guaranteed response times yet. Security fixes will initially target the development branch; older local builds should be rebuilt after a fix is published.

Do not test against other people's devices or data. If an issue affects capture safety, pause or quit OpenLid until it is resolved.
