# Security Policy

## Supported Versions

We provide security updates for the following versions:

| Version | Supported          |
| ------- | ------------------ |
| `main` branch | Yes |
| Latest release | Yes |
| Previous minor versions | Maintenance only |
| Older versions | No |

## Reporting a Vulnerability

We take security vulnerabilities seriously. If you discover a security vulnerability in AIXCL, please report it responsibly.

### How to Report

**Please do not report security vulnerabilities through public GitHub issues.**

Instead, please use one of the following methods:

1. **GitHub Security Advisories (Preferred)**: Use the [GitHub Security Advisory](https://github.com/xencon/aixcl/security/advisories/new) feature to report vulnerabilities privately.

### What to Include

When reporting a vulnerability, please include:

- A clear description of the vulnerability
- Steps to reproduce the issue
- The version or branch affected
- Potential impact and severity assessment
- Any suggested fixes or mitigations (if available)
- Your contact information (optional, for follow-up questions)

### Response Timeline

- **Initial Response**: We aim to acknowledge receipt within 72 hours
- **Assessment**: Preliminary assessment within 7 days
- **Fix Timeline**: Depends on severity, but we prioritize critical vulnerabilities
- **Disclosure**: Coordinated disclosure after a fix is available (typically 7-14 days after fix release)

### Responsible Disclosure

We follow responsible disclosure practices:

- **Confidentiality**: Reports are kept confidential until a fix is available
- **Coordination**: We work with reporters to coordinate public disclosure
- **Credit**: Reporters will be credited unless they request anonymity
- **Fix Priority**: Confirmed vulnerabilities in supported versions are fixed promptly

## Security Scope

### In-Scope Vulnerabilities

We consider the following types of security issues in-scope:

- **Unauthorized Access**: Vulnerabilities that allow unauthorized access to services, data, or systems
- **Code Injection**: Remote code execution, command injection, or code injection vulnerabilities
- **Data Exposure**: Unauthorized disclosure or modification of sensitive data
- **Authentication/Authorization**: Bypasses or weaknesses in authentication or authorization mechanisms
- **Cryptographic Weaknesses**: Issues in cryptographic implementations or configurations
- **Container Security**: Docker container escape vulnerabilities or misconfigurations
- **Network Security**: Vulnerabilities in service communication or network exposure
- **Configuration Security**: Security misconfigurations that could lead to exploitation

### Out-of-Scope

The following are generally considered out-of-scope (though we may address them at our discretion):

- **Third-Party Dependencies**: Vulnerabilities in upstream dependencies (Ollama, PostgreSQL, etc.) should be reported to their respective maintainers
- **Denial of Service**: DoS vulnerabilities that don't lead to other security issues
- **UI/UX Issues**: Minor interface issues without security impact
- **Performance Issues**: Performance problems without security implications
- **Model Security**: Security issues in LLM models themselves (report to model providers)
- **Social Engineering**: Social engineering attacks or phishing attempts

### AIXCL-Specific Considerations

AIXCL is a self-hosted platform designed for local deployment. Security considerations include:

- **Local-First Architecture**: Vulnerabilities should be assessed in the context of local deployment
- **Container Security**: Docker and Docker Compose security best practices
- **Service Communication**: Inter-service communication within the stack
- **Data Persistence**: PostgreSQL database security and data protection
- **Model Management**: Security of model downloads and execution
- **CLI Security**: Command-line interface security and privilege escalation

## Docker Socket Security Considerations

AIXCL uses Docker socket mounts for specific operational services. This section documents the security trade-offs and recommendations.

### Services Using Docker Socket

The following services mount the Docker socket (`/var/run/docker.sock`):

| Service | Profile | Purpose | Risk Level |
|---------|---------|---------|------------|
| **alloy** | `ops`, `sys` | Log collection from containers | High |

### Security Implications

**Docker socket access is equivalent to root access on the host.**

Containers with Docker socket access can:
- Start, stop, or remove any container
- Access the host filesystem
- Create privileged containers
- Access other containers' networks and volumes

### Risk Assessment

**For AIXCL's target use case (local/self-hosted deployments):**
- **Acceptable risk**: AIXCL is designed for single-node, self-hosted deployments where the user controls the entire stack
- **Trusted environment**: Users run AIXCL on their own infrastructure with administrative control
- **Well-maintained tool**: Alloy is a standard, widely-used open source project

**Not recommended for:**
- Multi-tenant environments
- Untrusted networks
- Shared hosting scenarios
- Production environments with strict security requirements

### Mitigation Options

**Option 1: Document and Accept (Default)**
- Understand the security trade-off
- Use only in trusted, single-administrator environments
- Monitor for unusual container activity

**Option 2: Docker Socket Proxy (Advanced)**
For users requiring stricter security, consider implementing a Docker socket proxy (e.g., `docker-socket-proxy`) to restrict API access:
- alloy: Allow only container listing and log access

Note: This requires manual configuration and is not officially supported.

### Recommendations by Profile

| Profile | Docker Socket Access | Recommendation |
|---------|----------------------|----------------|
| `usr` | No | No action needed |
| `dev` | No | No action needed |
| `ops` | Yes (`alloy`) | Use in trusted environments |
| `sys` | Yes (`alloy`) | Use in trusted environments |

## Network Mode Design

### network_mode: host is Intentional

AIXCL uses network_mode: host for all Docker services. This is an **intentional architectural decision**, not a security vulnerability.

### Rationale

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

### Security Context

**Not a vulnerability because:**
- AIXCL is designed for **localhost/trusted network** deployments
- Users have **full control** over their infrastructure
- All services run on the **same host**
- Alternative (custom networks) adds complexity without security benefit for single-node use

### Architecture Reference

See [docs/architecture/governance/00_invariants.md](docs/architecture/governance/00_invariants.md) section 7 for the formal architectural invariant.

## Security Best Practices

When deploying AIXCL:

1. **Network Security**: Ensure services are not exposed to untrusted networks unless necessary
2. **Authentication**: Use strong authentication for web interfaces (Open WebUI, pgAdmin, Grafana)
3. **Updates**: Keep Docker images and dependencies up to date
4. **Secrets Management**: Use secure methods for managing API keys and credentials
5. **Resource Limits**: Configure appropriate resource limits for containers
6. **Monitoring**: Enable observability features to detect anomalies
7. **Backups**: Regularly backup PostgreSQL data and configurations

For operational security guidance, see [docs/operations/security.md](docs/operations/security.md) for rootless container operations.

## Security Updates

Security updates are released as:

- **Security Advisories**: Published via GitHub Security Advisories
- **Patch Releases**: Versioned releases with security fixes
- **Release Notes**: Security fixes are documented in release notes

## Acknowledgments

We thank all security researchers and users who responsibly report vulnerabilities. Your efforts help make AIXCL more secure for everyone.

If you wish to be acknowledged for your report, please let us know. Otherwise, we will respect your anonymity.

---

**Last Updated**: April 2026

For questions about this security policy, please open a discussion in the repository.
