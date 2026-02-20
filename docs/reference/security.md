# Security Policy for aixcl

## 1. Supported versions

| Version                        | Supported? | Notes                    |
| ------------------------------ | ---------- | ------------------------ |
| `main` branch / latest release | Yes         | Actively maintained      |
| Previous minor versions        | Yes         | Maintenance only         |
| Older versions                 | No          | Please upgrade to latest |

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

**Note:** This file is located in `docs/reference/security.md` and should be linked from the main README.


## 7. Network Mode Design

### 7.1  is Intentional

AIXCL uses  for all Docker services. This is an **intentional architectural decision**, not a security vulnerability.

### 7.2 Rationale

| Aspect | Design Choice |
|--------|---------------|
| **Networking** |  |
| **Purpose** | Simplified local development |
| **Target** | Single-node, self-hosted deployments |

**Benefits:**
- No Docker DNS resolution complexity
- No port mapping management
- No network aliases needed
- Direct localhost access for all services
- Clone

## 7. Network Mode Design

### 7.1 network_mode: host is Intentional

AIXCL uses network_mode: host for all Docker services. This is an **intentional architectural decision**, not a security vulnerability.

### 7.2 Rationale

| Aspect | Design Choice |
|--------|---------------|
| **Networking** | network_mode: host |
| **Purpose** | Simplified local development |
| **Target** | Single-node, self-hosted deployments |

**Benefits:**
- No Docker DNS resolution complexity
- No port mapping management
- No network aliases needed
- Direct localhost access for all services
- Clone and run simplicity

### 7.3 Security Context

**Not a vulnerability because:**
- AIXCL is designed for **localhost/trusted network** deployments
- Users have **full control** over their infrastructure
- All services run on the **same host**
- Alternative (custom networks) adds complexity without security benefit for single-node use

### 7.4 Architecture Reference

See docs/architecture/governance/00_invariants.md section 7 for the formal architectural invariant.
