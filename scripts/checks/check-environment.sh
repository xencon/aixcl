#!/usr/bin/env bash
# Environment Validation Script for AIXCL Development
# Checks that the development environment is ready for OpenCode and Issue-First workflow
#
# Usage: ./scripts/checks/check-environment.sh

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$REPO_ROOT"

ERRORS=0
WARNINGS=0
CHECKS_PASSED=0

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

error() {
    echo -e "${RED}✗${NC} $1" >&2
    ((ERRORS++))
}

warn() {
    echo -e "${YELLOW}⚠${NC} $1" >&2
    ((WARNINGS++))
}

info() {
    echo -e "${BLUE}ℹ${NC} $1"
}

pass() {
    echo -e "${GREEN}✓${NC} $1"
    ((CHECKS_PASSED++))
}

# Check if command exists
check_command() {
    local cmd=$1
    local required=${2:-true}
    
    if command -v "$cmd" &> /dev/null; then
        local version
        version=$($cmd --version 2>/dev/null | head -1 || echo "version unknown")
        pass "$cmd installed ($version)"
        return 0
    else
        if [ "$required" = true ]; then
            error "$cmd is required but not installed"
        else
            warn "$cmd is optional but not installed"
        fi
        return 1
    fi
}

# Check Git configuration
check_git_config() {
    info "Checking Git configuration..."
    
    local git_user_name
    local git_user_email
    
    git_user_name=$(git config user.name 2>/dev/null || echo "")
    git_user_email=$(git config user.email 2>/dev/null || echo "")
    
    if [ -n "$git_user_name" ]; then
        pass "Git user.name configured: $git_user_name"
    else
        error "Git user.name not configured. Run: git config --global user.name 'Your Name'"
    fi
    
    if [ -n "$git_user_email" ]; then
        pass "Git user.email configured: $git_user_email"
    else
        error "Git user.email not configured. Run: git config --global user.email 'your@email.com'"
    fi
}

# Check GitHub CLI
check_github_cli() {
    info "Checking GitHub CLI..."
    
    if ! check_command "gh"; then
        error "GitHub CLI (gh) is required for Issue-First workflow"
        info "Install from: https://cli.github.com/"
        return
    fi
    
    # Check authentication
    if gh auth status &>/dev/null; then
        local username
        username=$(gh api user -q .login 2>/dev/null || echo "unknown")
        pass "GitHub CLI authenticated as: $username"
    else
        error "GitHub CLI not authenticated. Run: gh auth login"
    fi
}

# Check Git remotes
check_git_remotes() {
    info "Checking Git remotes..."
    
    local remotes
    remotes=$(git remote 2>/dev/null || echo "")
    
    if [ -n "$remotes" ]; then
        pass "Git remotes configured:"
        git remote -v | while read -r line; do
            echo "    $line"
        done
    else
        error "No Git remotes configured"
    fi
}

# Check OpenCode configuration
check_opencode_config() {
    info "Checking OpenCode configuration..."
    
    if [ -f "opencode.json" ]; then
        pass "opencode.json exists"
        
        # Validate JSON
        if python3 -m json.tool opencode.json > /dev/null 2>&1; then
            pass "opencode.json is valid JSON"
        else
            error "opencode.json contains invalid JSON"
        fi
        
        # Check for required fields
        if grep -q '"default_agent"' opencode.json; then
            pass "default_agent configured"
        else
            warn "default_agent not configured in opencode.json"
        fi
        
        if grep -q '"instructions"' opencode.json; then
            pass "instructions array configured"
        else
            warn "instructions array not configured"
        fi
    else
        error "opencode.json not found in repository root"
    fi
}

# Check OpenCode directory structure
check_opencode_structure() {
    info "Checking OpenCode directory structure..."
    
    local dirs=(
        ".opencode/agents"
    )
    
    for dir in "${dirs[@]}"; do
        if [ -d "$dir" ]; then
            local count
            count=$(find "$dir" -name "*.md" | wc -l)
            pass "$dir exists ($count markdown files)"
        else
            error "$dir directory missing"
        fi
    done
}

# Check AI directory structure
check_ai_structure() {
    info "Checking AI directory structure..."
    
    local required_dirs=(
        "ai/actions"
        "ai/governance"
        "ai/orchestration"
        "ai/templates"
    )
    
    for dir in "${required_dirs[@]}"; do
        if [ -d "$dir" ]; then
            pass "$dir exists"
        else
            error "$dir directory missing"
        fi
    done
    
    # Check for actions
    local action_count
    action_count=$(find "ai/actions" -name "action-*.md" 2>/dev/null | wc -l)
    if [ "$action_count" -gt 0 ]; then
        pass "Found $action_count action files"
    else
        warn "No action files found in ai/actions/"
    fi
}

# Check validation scripts
check_validation_scripts() {
    info "Checking validation scripts..."
    
    local script="scripts/checks/check-agents.sh"
    
    if [ -f "$script" ]; then
        if [ -x "$script" ]; then
            pass "$script exists and is executable"
        else
            warn "$script exists but is not executable"
            info "Run: chmod +x $script"
        fi
    else
        warn "$script not found"
    fi
}

# Check permissions
check_permissions() {
    info "Checking file permissions..."
    
    # Check if any scripts in scripts/ are not executable
    local non_executable
    non_executable=$(find scripts/ -name "*.sh" -type f ! -perm -111 2>/dev/null || true)
    
    if [ -n "$non_executable" ]; then
        warn "Some shell scripts are not executable:"
        echo "$non_executable" | while read -r file; do
            echo "    $file"
        done
    else
        pass "All shell scripts are executable"
    fi
}

# Run agent validation
check_agent_validation() {
    info "Running agent validation..."
    
    if [ -f "scripts/checks/check-agents.sh" ]; then
        if scripts/checks/check-agents.sh > /dev/null 2>&1; then
            pass "Agent validation passed"
        else
            error "Agent validation failed. Run: ./scripts/checks/check-agents.sh for details"
        fi
    else
        warn "Cannot run agent validation - script not found"
    fi
}

# Check for ShellCheck (required for pre-commit linting)
check_shellcheck() {
    info "Checking ShellCheck..."
    
    if command -v shellcheck &> /dev/null; then
        local version
        version=$(shellcheck --version 2>/dev/null | head -2 | tail -1 || echo "installed")
        pass "ShellCheck installed ($version)"
    else
        error "ShellCheck is required but not installed"
        info "Install: ./scripts/utils/setup-shellcheck.sh"
    fi
}

# Check for Docker (optional)
check_docker() {
    info "Checking Docker (optional)..."
    
    if command -v docker &> /dev/null; then
        local version
        version=$(docker --version 2>/dev/null | head -1 || echo "installed")
        pass "Docker installed ($version)"
        
        # Check if Docker daemon is running
        if docker info > /dev/null 2>&1; then
            pass "Docker daemon is running"
        else
            warn "Docker daemon is not running"
        fi
    else
        warn "Docker not installed (optional for non-Docker workflows)"
    fi
}

# Main execution
main() {
    echo "═══════════════════════════════════════════════════════════════"
    echo "  AIXCL Environment Validation"
    echo "═══════════════════════════════════════════════════════════════"
    echo ""
    
    # Required checks
    check_command "git"
    check_git_config
    check_github_cli
    check_git_remotes
    
    echo ""
    
    # Configuration checks
    check_opencode_config
    check_opencode_structure
    check_ai_structure
    
    echo ""
    
    # Validation checks
    check_validation_scripts
    check_agent_validation
    check_permissions
    
    echo ""
    
    # Optional checks
    check_shellcheck
    check_docker
    
    echo ""
    echo "═══════════════════════════════════════════════════════════════"
    echo "  Summary"
    echo "═══════════════════════════════════════════════════════════════"
    
    if [ $ERRORS -eq 0 ] && [ $WARNINGS -eq 0 ]; then
        echo -e "${GREEN}✓ All checks passed!${NC}"
        echo ""
        echo "Your environment is ready for AIXCL development."
        echo "Start OpenCode and use /workflow to run the Issue-First workflow."
        exit 0
    elif [ $ERRORS -eq 0 ]; then
        echo -e "${YELLOW}✓ Checks passed with warnings${NC}"
        echo ""
        echo "Warnings: $WARNINGS"
        echo ""
        echo "Your environment should work but consider addressing the warnings."
        exit 0
    else
        echo -e "${RED}✗ Environment validation failed${NC}"
        echo ""
        echo "Errors: $ERRORS"
        echo "Warnings: $WARNINGS"
        echo "Passed: $CHECKS_PASSED"
        echo ""
        echo "Please fix the errors above before proceeding."
        exit 1
    fi
}

main "$@"
