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

## 6. Docker Socket Security Considerations

AIXCL uses Docker socket mounts for specific operational services. This section documents the security trade-offs and recommendations.

### 6.1 Services Using Docker Socket

The following services mount the Docker socket (`/var/run/docker.sock`):

| Service | Profile | Purpose | Risk Level |
|---------|---------|---------|------------|
| **watchtower** | `sys` | Automatic container updates | High |
| **promtail** | `ops`, `sys` | Log collection from containers | High |

### 6.2 Security Implications

**Docker socket access is equivalent to root access on the host.**

Containers with Docker socket access can:
- Start, stop, or remove any container
- Access the host filesystem
- Create privileged containers
- Access other containers' networks and volumes

### 6.3 Risk Assessment

**For AIXCL's target use case (local/self-hosted deployments):**
- **Acceptable risk**: AIXCL is designed for single-node, self-hosted deployments where the user controls the entire stack
- **Trusted environment**: Users run AIXCL on their own infrastructure with administrative control
- **Well-maintained tools**: Both watchtower and promtail are standard, widely-used open source projects

**Not recommended for:**
- Multi-tenant environments
- Untrusted networks
- Shared hosting scenarios
- Production environments with strict security requirements

### 6.4 Mitigation Options

**Option 1: Document and Accept (Default)**
- Understand the security trade-off
- Use only in trusted, single-administrator environments
- Monitor for unusual container activity

**Option 2: Disable watchtower (Manual Updates)**
```bash
# Use a profile without watchtower (usr, dev, ops)
./aixcl stack start --profile ops

# Or manually remove watchtower from sys profile
./aixcl service stop watchtower
```

**Option 3: Docker Socket Proxy (Advanced)**
For users requiring stricter security, consider implementing a Docker socket proxy (e.g., `docker-socket-proxy`) to restrict API access:
- watchtower: Allow only container inspection and restart
- promtail: Allow only container listing and log access

Note: This requires manual configuration and is not officially supported.

### 6.5 Recommendations by Profile

| Profile | watchtower | Recommendation |
|---------|------------|----------------|
| `usr` | No | No action needed |
| `dev` | No | No action needed |
| `ops` | No | No action needed |
| `sys` | Yes | Consider if automatic updates are worth the risk |

---

**Note:** This file is located in `docs/reference/security.md` and should be linked from the main README.

