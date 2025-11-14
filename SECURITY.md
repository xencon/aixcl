# Security Policy for aixcl

## 1. Supported versions

| Version                        | Supported? | Notes                    |
| ------------------------------ | ---------- | ------------------------ |
| `main` branch / latest release | ✅ Yes      | Actively maintained      |
| Previous minor versions        | ✅ Yes      | Maintenance only         |
| Older versions                 | ❌ No       | Please upgrade to latest |

## 2. How to report a vulnerability

If you discover a security vulnerability in this project, please follow these steps:

1. Confidentially report it by sending an email to: **[security@yourdomain.com](mailto:security@yourdomain.com)** with the subject line: "[aixcl] Security Vulnerability Report".
2. Include in your report:

   * A clear description of the potential vulnerability.
   * Steps to reproduce (if possible).
   * The version or branch affected.
   * Relevant system/environment details.
   * Your contact information (optional).
3. We aim to respond within **72 hours** to acknowledge receipt and provide a preliminary assessment.
4. Once validated, we will coordinate with you to release a fix and announce disclosure.

### What not to include

* Do not publicly disclose the vulnerability until a fix is available.
* Avoid including sensitive production data in the report.

## 3. Responsible disclosure policy

* Confirmed vulnerabilities in supported versions will be fixed promptly.
* Security advisories or patch releases will be issued after the fix.
* Public disclosure will be coordinated, typically after 7 days of the fix release.
* Reporters may be credited unless anonymity is requested.
* Out-of-scope patches or reports may be declined.

## 4. Scope

In-scope issues affecting aixcl:

* Unauthorized access, modification, or disclosure of data.
* Code injection or remote code execution vulnerabilities.
* Security misconfigurations or cryptographic weaknesses.

Out-of-scope (may still be addressed at our discretion):

* Bugs in third-party dependencies.
* Minor UI/UX or performance issues without security impact.

## 5. Acknowledgements

We thank all security researchers and users who report vulnerabilities. If you wish to be acknowledged, please indicate; otherwise, anonymity will be respected.

---

**Note:** Place this file in the root of your repository as `SECURITY.md` and link to it in your README.

