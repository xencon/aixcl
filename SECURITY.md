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

Instead, please report them via one of the following methods:

1. **GitHub Security Advisories (Preferred)**: Use the [GitHub Security Advisory](https://github.com/xencon/aixcl/security/advisories/new) feature to report vulnerabilities privately.

2. **Email**: If you prefer email, contact us at `security@example.com` (replace this with a monitored security contact address for this project).

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

## Security Best Practices

When deploying AIXCL:

1. **Network Security**: Ensure services are not exposed to untrusted networks unless necessary
2. **Authentication**: Use strong authentication for web interfaces (Open WebUI, pgAdmin, Grafana)
3. **Updates**: Keep Docker images and dependencies up to date
4. **Secrets Management**: Use secure methods for managing API keys and credentials
5. **Resource Limits**: Configure appropriate resource limits for containers
6. **Monitoring**: Enable observability features to detect anomalies
7. **Backups**: Regularly backup PostgreSQL data and configurations

For detailed security guidance, see the security documentation in the [`docs/` directory](docs/).

## Security Updates

Security updates are released as:

- **Security Advisories**: Published via GitHub Security Advisories
- **Patch Releases**: Versioned releases with security fixes
- **Release Notes**: Security fixes are documented in release notes

## Acknowledgments

We thank all security researchers and users who responsibly report vulnerabilities. Your efforts help make AIXCL more secure for everyone.

If you wish to be acknowledged for your report, please let us know. Otherwise, we will respect your anonymity.

---

**Last Updated**: December 2024

For questions about this security policy, please open a discussion in the repository.

