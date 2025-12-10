# Security Audit Report

This document identifies security issues found in the repository and their resolutions.

## Critical Issues Found

### 1. ⚠️ Hardcoded Credentials in `pgadmin-servers.json`

**Location:** `pgadmin-servers.json` (working directory)

**Issue:**
- File contains hardcoded credentials: `"Username": "admin"`, `"Password": "admin"`
- While the file is in `.gitignore`, the working directory version contains hardcoded values
- If accidentally committed, would expose database credentials

**Current Status:**
- ✅ File is in `.gitignore` (line 39)
- ✅ File is generated dynamically by `aixcl` script using environment variables
- ⚠️ Working directory version has hardcoded credentials

**Recommendation:**
- Remove the hardcoded version from working directory
- Ensure file is always generated from environment variables
- Add to `.gitignore` if not already present (already done)

**Resolution:**
- ✅ File is already in `.gitignore` (line 39) - will not be committed
- ✅ Script generates file dynamically from environment variables (see `aixcl` script `generate_pgadmin_config()`)
- ✅ Script sets secure file permissions (600) when generating
- ✅ Script cleans up file on service stop (lines 462-465, 670-673, 577-580)
- ⚠️ **Action Required**: Remove hardcoded version from working directory:
  ```bash
  rm -f pgadmin-servers.json
  ```
  The file will be regenerated automatically by the `aixcl start` command with proper credentials from `.env`

### 2. ⚠️ Default Weak Password in Grafana Configuration

**Location:** `docker-compose.yml` line 172

**Issue:**
```yaml
- GF_SECURITY_ADMIN_PASSWORD=${GRAFANA_ADMIN_PASSWORD:-admin}
```
- Default password is "admin" if `GRAFANA_ADMIN_PASSWORD` is not set
- Weak default password is a security risk

**Current Status:**
- ⚠️ Default password "admin" is used if environment variable is not set
- ✅ Documentation warns users to change default password

**Recommendation:**
- Require `GRAFANA_ADMIN_PASSWORD` to be set (fail if not provided)
- Or use a randomly generated password on first startup
- Update documentation to emphasize password requirement

**Resolution:**
- Add validation in startup script to require password
- Update documentation to emphasize security

### 3. ⚠️ Missing `.webui_secret_key` in `.gitignore`

**Location:** `scripts/openwebui.sh` creates `.webui_secret_key`

**Issue:**
- Script generates `.webui_secret_key` file (line 5, 14)
- File is not explicitly in `.gitignore`
- Secret key files should never be committed

**Current Status:**
- ⚠️ File not explicitly listed in `.gitignore`
- ✅ File is in `scripts/` directory which may be ignored by patterns
- ⚠️ Should be explicitly ignored for safety

**Recommendation:**
- Add `.webui_secret_key` to `.gitignore`
- Add pattern to ignore secret key files in any location

**Resolution:**
- Add to `.gitignore`

## Medium Priority Issues

### 4. ⚠️ Default Database Credentials

**Location:** `llm-council/backend/config.py` lines 58-60

**Issue:**
```python
POSTGRES_USER = os.getenv("POSTGRES_USER", "admin")
POSTGRES_PASSWORD = os.getenv("POSTGRES_PASSWORD", "")
POSTGRES_DATABASE = os.getenv("POSTGRES_DATABASE", "admin")
```
- Default username "admin" and database "admin"
- Empty string default for password (may cause connection issues)

**Current Status:**
- ⚠️ Defaults may lead to insecure configurations
- ✅ Environment variables are required in practice via `.env` file
- ✅ Documentation emphasizes setting secure passwords

**Recommendation:**
- Consider failing fast if critical credentials are not set
- Update documentation to emphasize security

### 5. ⚠️ API Key in Code Comments/Examples

**Location:** `llm-council/README.md` line 40

**Issue:**
- Example shows API key format: `OPENROUTER_API_KEY=sk-or-v1-...`
- While this is just an example, it shows the format

**Current Status:**
- ✅ Only example format, not actual key
- ✅ Actual keys stored in `.env` which is gitignored

**Recommendation:**
- No action needed (examples are acceptable)
- Ensure `.env` is properly gitignored (already done)

## Low Priority / Informational

### 6. ✅ Good Security Practices Found

- ✅ `.env` file is in `.gitignore`
- ✅ `pgadmin-servers.json` is in `.gitignore`
- ✅ Environment variables used for all sensitive data
- ✅ Credentials loaded from environment, not hardcoded
- ✅ Documentation warns about changing default passwords
- ✅ File permissions set to 600 for sensitive config files (in `aixcl` script)

## Recommendations Summary

### Immediate Actions:
1. ✅ Add `.webui_secret_key` to `.gitignore`
2. ✅ Remove hardcoded `pgadmin-servers.json` from working directory
3. ⚠️ Consider requiring Grafana password (fail if not set)
4. ⚠️ Add validation for critical environment variables

### Best Practices:
- ✅ All sensitive data in environment variables
- ✅ All sensitive files in `.gitignore`
- ✅ Documentation emphasizes security
- ⚠️ Consider adding pre-commit hooks to prevent committing secrets
- ⚠️ Consider using tools like `git-secrets` or `truffleHog` for secret scanning

## Verification

Run these commands to verify security:

```bash
# Check for tracked sensitive files
git ls-files | grep -E "(password|secret|key|credential|\.env)"

# Check .gitignore coverage
git check-ignore -v pgadmin-servers.json .webui_secret_key .env

# Search for hardcoded credentials
grep -r "password.*=.*[\"']" --include="*.py" --include="*.sh" --include="*.yml" | grep -v ".git" | grep -v "example"
```

## References

- [OWASP Top 10](https://owasp.org/www-project-top-ten/)
- [GitHub Security Best Practices](https://docs.github.com/en/code-security)
- [Docker Security Best Practices](https://docs.docker.com/engine/security/)

