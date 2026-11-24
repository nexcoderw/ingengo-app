# Security policy

## Report a vulnerability privately

Use [GitHub Security Advisories](https://github.com/nexcoderw/ingengo-app/security/advisories/new)
if the private report form is available. If it is unavailable, contact
[KAJUGA Daniels](https://github.com/kajugadaniels) privately through a channel
listed on the profile and ask for a secure way to share the details. For an
issue specific to the backend, follow the
[Ingengo API security policy](https://github.com/nexcoderw/ingengo-api/security/policy).

Include the app version or commit, the affected platform and OS version, a
description of the impact, and steps to reproduce the issue in a local or
explicitly authorized environment. Use synthetic data. Redact session tokens,
Shortcut credentials, phone numbers, balances, payment references, and SMS
content from reports and attachments. Keep details out of public issues and
PRs while maintainers triage the report and coordinate disclosure.

## Security expectations

| Area | Practice |
| --- | --- |
| Client configuration | Treat bundled `.env` values and build-time configuration as public. Keep server secrets, signing credentials, and private keys out of the app and Git. |
| Sessions | Store session tokens through `SecureStorageService` and preserve cleanup on logout or unrecoverable refresh failure. Keep tokens out of URLs, logs, screenshots, and fixtures. |
| Networking | Use HTTPS for production and send authorization only to the configured API origin. Keep HTTP behavior in the existing network layer. |
| Native permissions | Request contacts or SMS access for the relevant flow. Respect denied access and gate platform-specific features on native capability. |
| Payment evidence | Keep user-reported and provider evidence distinct. Use synthetic accounts and messages in tests and public reproduction steps. |
| Apple Shortcuts | Treat device credentials as sensitive. Preserve rotation and revocation and avoid copying credentials into diagnostics. |
| Release signing | Keep signing keys, provisioning profiles, and local configuration in maintainer-controlled storage. |

Repository administrators can enable
[GitHub private vulnerability reporting](https://docs.github.com/en/code-security/how-tos/report-and-fix-vulnerabilities/configure-vulnerability-reporting/configure-for-a-repository)
to make the private form available.
