# Security Policy

## Supported Versions

We actively maintain and provide security updates for the following versions:

| Version | Supported          |
| ------- | ------------------ |
| latest  | :white_check_mark: |
| 2025.x  | :white_check_mark: |
| < 2025  | :x:                |

**Note:** We use CalVer versioning (YYYY.MM.PATCH). Only the current calendar year receives security updates.

## Security Features

### Container Security

This project implements multiple layers of security:

1. **Network Firewall**
   - Strict iptables-based allowlist using iptables-legacy
   - Only authorized domains permitted (GitHub, npm, Anthropic API, claude.ai, Statsig, GHCR)
   - Works on both Docker and Apple Container
   - Local network access auto-detected and restricted
   - Default DROP policy on all traffic
   - Verified blocking of unauthorized domains (Facebook, Google, Twitter, etc.)

2. **Minimal Attack Surface**
   - Alpine Linux base (~250MB total image size)
   - No unnecessary packages or tools
   - Build dependencies removed after use
   - No cached layers during build

3. **API Key Protection**
   - Keys stored in secure files (chmod 600)
   - Removed from environment variables after initialization
   - Never logged or exposed in process listings

### Supply Chain Security

Starting with version 2025.12.0, all releases include:

1. **Vulnerability Scanning**
   - Trivy scanner for CVE detection (Alpine packages + npm dependencies)
   - CRITICAL and HIGH CVEs block releases
   - Scan results available in workflow artifacts

2. **Software Bill of Materials (SBOM)**
   - SPDX-format SBOM generated for each release
   - Complete package inventory (OS + npm packages)
   - Available in workflow artifacts (90-day retention)

**Future Enhancements:** The following security features may be added in future releases:
- Build provenance attestation (SLSA)
- Image signing with Cosign/Sigstore
- SARIF upload to GitHub Security tab
- SBOM attachment to releases

### Security Verification

#### View SBOM and Vulnerability Scan Results

1. Navigate to the [Actions page](../../actions)
2. Click on the release workflow run you want to inspect
3. Download the `security-reports-*` artifact
4. Extract the artifact and view:
   - `sbom.spdx.json` - Complete package inventory
   - `trivy-results.json` - Detailed vulnerability information

```bash
# Example: View package list from SBOM
jq '.packages[] | "\(.name) \(.versionInfo)"' sbom.spdx.json

# Example: View critical vulnerabilities from Trivy
jq '.Results[].Vulnerabilities[] | select(.Severity=="CRITICAL")' trivy-results.json
```

## Reporting a Vulnerability

We take security vulnerabilities seriously. If you discover a security issue, please follow these steps:

### 1. **DO NOT** Create a Public Issue

Please do not open a public GitHub issue for security vulnerabilities. This puts all users at risk.

### 2. Report Privately

Send a detailed report to: **[security@erepublik-labs.com](mailto:security@erepublik-labs.com)**

Include in your report:
- Description of the vulnerability
- Steps to reproduce
- Potential impact
- Suggested fix (if available)

### 3. What to Expect

- **Acknowledgment**: Within 48 hours
- **Initial Assessment**: Within 5 business days
- **Status Updates**: Weekly until resolved
- **Fix Timeline**: Critical issues within 7 days, others within 30 days

### 4. Coordinated Disclosure

We follow responsible disclosure practices:
- We will work with you to understand and verify the issue
- We will develop and test a fix
- We will coordinate a disclosure timeline with you
- We will credit you in the security advisory (if desired)

### 5. Recognition

Security researchers who responsibly disclose vulnerabilities will be:
- Credited in the CHANGELOG and security advisory
- Listed in our Hall of Fame (if they wish)
- Invited to contribute to the fix (optional)

## Security Best Practices

### For Users

1. **Always use the latest version**
   - Run `container pull ghcr.io/erepublik-labs/claude-code-container:latest` regularly
   - Check for updates: container will notify on startup

2. **Use persistent volumes**
   - Mount a named volume for `/home/dev`
   - Protects credentials and configuration

3. **Review firewall rules**
   - Understand what domains are allowed
   - Modify `init-firewall.sh` if needed for your use case

4. **Protect API keys**
   - Pass `CLAUDE_API_KEY` as environment variable (not in files)
   - Keys are automatically secured inside container

5. **Verify container authenticity**
   - Review SBOM and vulnerability scan results from Actions artifacts
   - Only use images from `ghcr.io/erepublik-labs/`

### For Contributors

1. **Never commit secrets**
   - No API keys, tokens, or credentials
   - Use `.env` files (already in `.gitignore`)

2. **Minimize dependencies**
   - Only add packages when absolutely necessary
   - Document why each dependency is needed

3. **Update dependencies**
   - Keep Alpine packages current
   - Monitor npm package vulnerabilities

4. **Test security features**
   - Run Trivy scans locally before pushing
   - Test firewall rules with blocked/allowed domains

## Security Scanning

### Automated Scanning

Every release uses a **dual-scanner strategy**:

**Trivy (Primary - Blocks Releases)**
- Scans packages **we control and can patch**:
  - Alpine OS packages (apk)
  - npm packages (claude-powerline)
- Blocks releases on CRITICAL/HIGH vulnerabilities
- Skips binaries managed by upstream (Claude Code, gh CLI)

**Grype (Secondary - Visibility Only)**
- Scans **everything** including Go binaries
- Provides visibility into upstream vulnerabilities
- Does NOT block releases
- Useful for awareness of issues in Claude Code binary

**Rationale:** We cannot patch vulnerabilities in the Claude Code binary or GitHub CLI - these are managed by Anthropic and GitHub. Blocking releases on vulnerabilities we can't fix would be counterproductive. Instead, we:
1. Focus Trivy on what we control
2. Use Grype for full visibility
3. Document known upstream issues
4. Update binaries when new versions are released

### Manual Scanning

Test locally before releases:

```bash
# Scan with Trivy
trivy image --severity CRITICAL,HIGH,MEDIUM \
  ghcr.io/erepublik-labs/claude-code-container:latest

# Generate SBOM
syft ghcr.io/erepublik-labs/claude-code-container:latest \
  -o spdx-json
```

### Vulnerability Exceptions

**Upstream Vulnerabilities (Not Patched by Us)**

Vulnerabilities in upstream binaries are tracked but not blocked:
- Claude Code binary and its Go dependencies (managed by Anthropic)
- GitHub CLI and its dependencies (managed by GitHub)
- These appear in Grype reports for visibility
- Updates come from upstream maintainers

**Package Vulnerabilities (Patched by Us)**

Some vulnerabilities in packages we control may be accepted if:
- No fix is available yet
- The vulnerability doesn't apply to our use case
- The risk is minimal and documented

Accepted vulnerabilities are documented in `.trivyignore` with explanations.

## Security Updates

### Release Process

1. Security fixes are released as soon as possible
2. CRITICAL vulnerabilities: Emergency release within 24-48 hours
3. HIGH vulnerabilities: Patch release within 7 days
4. MEDIUM/LOW vulnerabilities: Included in next regular release

### Notification

Users are notified of security updates via:
- GitHub Security Advisories
- Container startup notification (built-in update checker)
- Release notes highlighting security fixes

## Compliance

### Standards Alignment

This project follows industry security standards where possible on GitHub Free plan:

- **SPDX**: Software Bill of Materials format ✅
- **Trivy**: Industry-standard vulnerability scanning ✅
- **CIS Docker Benchmark**: Container security best practices ✅
- **SLSA Level 2**: Build provenance (requires paid plan) ❌
- **Sigstore**: Keyless signing (requires paid plan) ❌
- **SARIF**: Security scan upload (requires GitHub Advanced Security) ❌

### Audit Trail

Every release provides an audit trail:
- Source commit SHA in release notes
- Package versions in SBOM
- Vulnerability scan results archived for 90 days
- All artifacts downloadable from Actions page

## Security Contacts

- **Security Issues**: security@erepublik-labs.com
- **General Security Questions**: Open a GitHub Discussion
- **Bug Reports**: Open a GitHub Issue (for non-security bugs only)

## License

This security policy is licensed under [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/).
