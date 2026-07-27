#!/bin/bash
# Test all Terraform examples with full apply/destroy cycle

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CODE_DIR="$SCRIPT_DIR/../examples"

# Setup example - creates publishers that other examples depend on
SETUP_EXAMPLE="npa/publisher-management"

# Examples organized by topic
NPA_EXAMPLES=(
  "npa/client-app"
  "npa/full-deployment"
  "npa/policy-as-code"
)

DNSPROFILES_EXAMPLES=(
  "dnsprofiles/basic-profile"
  "dnsprofiles/security-categories"
  "dnsprofiles/full-deployment"
)

WEBPOLICY_EXAMPLES=(
  "web-policy/custom-categories"
  "web-policy/service-objects"
)

# All testable examples (default: NPA + DNS + web policy)
EXAMPLES=("${NPA_EXAMPLES[@]}" "${DNSPROFILES_EXAMPLES[@]}" "${WEBPOLICY_EXAMPLES[@]}")

# Examples excluded from default testing:
# NPA:
# - npa/browser-app (requires is_user_portal_app support, not available on all tenants)
# - npa/private-app-inventory (requires existing publishers by specific name in tfvars)
# - npa/rbac-roles (uses placeholder api_group_id values — update before testing)
#
# Cloud provider examples excluded:
# - npa/publisher-aws (requires AWS credentials and marketplace subscription)
#
# IPSec examples excluded:
# - ipsec/vpn (requires IPSec/GRE license and network configuration)
# - ipsec/aws-transitgateway-vpn (requires AWS credentials)

SKIP_EXAMPLES=()
VALIDATE_ONLY=false
TOPIC_FILTER=""
FAILED_EXAMPLES=()
PASSED_EXAMPLES=()
DRIFT_EXAMPLES=()

# Debug mode detection (provider already running via TF_REATTACH_PROVIDERS)
DEBUG_MODE=false
if [[ -n "${TF_REATTACH_PROVIDERS:-}" ]]; then
  DEBUG_MODE=true
fi

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

usage() {
  echo "Usage: $0 [-s example] [-v] [-t topic]"
  echo "  -s, --skip      Skip specific example (can be used multiple times)"
  echo "  -v, --validate  Run syntax validation only (no apply/destroy)"
  echo "  -t, --topic     Run only examples for a topic: npa, dnsprofiles, web-policy, ipsec"
  echo ""
  echo "Environment variables:"
  echo "  NETSKOPE_SERVER_URL  Netskope API server URL (required for apply/destroy)"
  echo "  NETSKOPE_API_KEY     Netskope API key (required for apply/destroy)"
  echo "  TF_REATTACH_PROVIDERS  Debug mode - attach to running provider (skips init)"
  exit 1
}

# Parse arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    -s|--skip) SKIP_EXAMPLES+=("$2"); shift 2 ;;
    -v|--validate) VALIDATE_ONLY=true; shift ;;
    -t|--topic) TOPIC_FILTER="$2"; shift 2 ;;
    -h|--help) usage ;;
    *) echo "Unknown option: $1"; usage ;;
  esac
done

# Apply topic filter
if [[ -n "$TOPIC_FILTER" ]]; then
  case "$TOPIC_FILTER" in
    npa)
      EXAMPLES=("${NPA_EXAMPLES[@]}")
      ;;
    dnsprofiles)
      EXAMPLES=("${DNSPROFILES_EXAMPLES[@]}")
      SETUP_EXAMPLE="" # DNS examples don't need publisher setup
      ;;
    web-policy)
      EXAMPLES=("${WEBPOLICY_EXAMPLES[@]}")
      SETUP_EXAMPLE="" # Web policy examples don't need publisher setup
      ;;
    ipsec)
      echo -e "${YELLOW}IPSec examples require manual configuration and are not auto-tested${NC}"
      exit 0
      ;;
    *)
      echo "Unknown topic: $TOPIC_FILTER (valid: npa, dnsprofiles, web-policy, ipsec)"
      exit 1
      ;;
  esac
fi

# Check required environment variables
check_credentials() {
  if [[ -z "${NETSKOPE_SERVER_URL:-}" ]] || [[ -z "${NETSKOPE_API_KEY:-}" ]]; then
    echo -e "${RED}Error: NETSKOPE_SERVER_URL and NETSKOPE_API_KEY must be set${NC}"
    exit 1
  fi
}

# Check if example should be skipped
should_skip() {
  local example=$1
  for skip in "${SKIP_EXAMPLES[@]:-}"; do
    [[ "$skip" == "$example" ]] && return 0
  done
  return 1
}

# Setup tfvars if example file exists
setup_tfvars() {
  local dir=$1
  if [[ -f "$dir/terraform.tfvars.example" ]] && [[ ! -f "$dir/terraform.tfvars" ]]; then
    cp "$dir/terraform.tfvars.example" "$dir/terraform.tfvars"
    echo "  Copied terraform.tfvars.example to terraform.tfvars"
  fi
}

# Cleanup tfvars and terraform files
cleanup() {
  local dir=$1
  # Don't remove .terraform in debug mode
  if [[ "$DEBUG_MODE" == false ]]; then
    rm -rf "$dir/.terraform" "$dir/.terraform.lock.hcl"
  fi
  rm -f "$dir/terraform.tfstate" "$dir/terraform.tfstate.backup"
  # Only remove tfvars if we created it from example
  if [[ -f "$dir/terraform.tfvars.example" ]]; then
    rm -f "$dir/terraform.tfvars"
  fi
}

# Run terraform init
run_init() {
  local dir=$1
  if [[ "$DEBUG_MODE" == true ]]; then
    echo "  Skipping terraform init (debug mode - provider attached)"
    return 0
  fi
  echo "  Running terraform init..."
  if ! terraform init -input=false > /dev/null 2>&1; then
    echo -e "  ${RED}FAILED: terraform init${NC}"
    return 1
  fi
  return 0
}

# Check for drift (re-plan after apply)
#
# Known behaviour: Terraform's -detailed-exitcode returns 2 for ANY planned
# changes, including output-only changes. Some resources legitimately cause
# output-only drift on re-plan:
#
#   - Clientless private apps (clientless_access = true): the API auto-generates
#     private_app_hostname as "ns.<hash>", replacing the user's config value.
#     The plan modifier suppresses the resource update, but outputs referencing
#     private_app_hostname still reflect the refreshed state value on the first
#     re-plan after apply. This is NOT a provider bug — the resource itself has
#     no planned changes.
#
# To avoid false failures, this function captures the plan output and checks
# whether any resource changes are planned. Output-only changes are reported
# as warnings, not failures.
run_drift_check() {
  local example=$1
  local dir="$CODE_DIR/$example"

  echo "  Checking for drift (re-plan after apply)..."
  cd "$dir"

  set +e
  local plan_output
  plan_output=$(terraform plan -detailed-exitcode -input=false 2>&1)
  local exit_code=$?
  set -e

  case $exit_code in
    0)
      echo -e "  ${GREEN}No drift detected${NC}"
      return 0
      ;;
    2)
      # Exit code 2 means changes detected. Check if any are resource changes
      # (update in-place, replace, create, destroy) vs output-only changes.
      if echo "$plan_output" | grep -qE '(will be updated in-place|will be created|will be destroyed|must be replaced)'; then
        echo -e "  ${RED}DRIFT DETECTED: plan shows resource changes after apply${NC}"
        echo "  Drift details:"
        terraform plan -input=false 2>&1 | head -80
        return 1
      else
        # Output-only changes — not a provider bug. See note above.
        echo -e "  ${YELLOW}Output-only changes detected (no resource drift)${NC}"
        echo "  This is expected for clientless apps — see script comments."
        return 0
      fi
      ;;
    *)
      echo -e "  ${RED}FAILED: terraform plan error during drift check${NC}"
      return 1
      ;;
  esac
}

# Run validation only
run_validate() {
  local example=$1
  local dir="$CODE_DIR/$example"

  echo -e "\n${YELLOW}=== Validating: $example ===${NC}"
  cleanup "$dir"
  cd "$dir"
  setup_tfvars "$dir"

  if ! run_init "$dir"; then return 1; fi

  echo "  Running terraform validate..."
  if ! terraform validate > /dev/null 2>&1; then
    echo -e "  ${RED}FAILED: terraform validate${NC}"
    return 1
  fi

  echo "  Running terraform fmt -check..."
  if ! terraform fmt -check > /dev/null 2>&1; then
    echo -e "  ${RED}FAILED: terraform fmt -check${NC}"
    return 1
  fi

  echo -e "  ${GREEN}PASSED (validate only)${NC}"
  cleanup "$dir"
  return 0
}

# Apply resources (no destroy)
run_apply() {
  local example=$1
  local dir="$CODE_DIR/$example"

  echo -e "\n${YELLOW}=== Applying: $example ===${NC}"
  cleanup "$dir"
  cd "$dir"
  setup_tfvars "$dir"

  if ! run_init "$dir"; then return 1; fi

  echo "  Running terraform validate..."
  if ! terraform validate > /dev/null 2>&1; then
    echo -e "  ${RED}FAILED: terraform validate${NC}"
    return 1
  fi

  echo "  Running terraform apply..."
  if ! terraform apply -auto-approve -input=false; then
    echo -e "  ${RED}FAILED: terraform apply${NC}"
    return 1
  fi

  echo -e "  ${GREEN}APPLIED${NC}"
  return 0
}

# Destroy resources
run_destroy() {
  local example=$1
  local dir="$CODE_DIR/$example"

  echo -e "\n${YELLOW}=== Destroying: $example ===${NC}"
  cd "$dir"

  echo "  Running terraform destroy..."
  if ! terraform destroy -auto-approve -input=false; then
    echo -e "  ${RED}FAILED: terraform destroy${NC}"
    return 1
  fi

  echo -e "  ${GREEN}DESTROYED${NC}"
  cleanup "$dir"
  return 0
}

# Test single example (apply + destroy)
test_example() {
  local example=$1
  local dir="$CODE_DIR/$example"

  echo -e "\n${YELLOW}=== Testing: $example ===${NC}"
  cleanup "$dir"
  cd "$dir"
  setup_tfvars "$dir"

  if ! run_init "$dir"; then return 1; fi

  echo "  Running terraform validate..."
  if ! terraform validate > /dev/null 2>&1; then
    echo -e "  ${RED}FAILED: terraform validate${NC}"
    return 1
  fi

  echo "  Running terraform fmt -check..."
  if ! terraform fmt -check > /dev/null 2>&1; then
    echo -e "  ${RED}FAILED: terraform fmt -check${NC}"
    return 1
  fi

  echo "  Running terraform apply..."
  if ! terraform apply -auto-approve -input=false; then
    echo -e "  ${RED}FAILED: terraform apply${NC}"
    terraform destroy -auto-approve -input=false 2>/dev/null || true
    return 1
  fi

  # Drift check
  if ! run_drift_check "$example"; then
    DRIFT_EXAMPLES+=("$example")
  fi

  echo "  Running terraform destroy..."
  if ! terraform destroy -auto-approve -input=false; then
    echo -e "  ${RED}FAILED: terraform destroy${NC}"
    return 1
  fi

  echo -e "  ${GREEN}PASSED${NC}"
  cleanup "$dir"
  return 0
}

# Main
main() {
  if [[ "$VALIDATE_ONLY" == false ]]; then
    check_credentials
  fi

  echo "Testing Terraform examples..."
  echo "Validate only: $VALIDATE_ONLY"
  echo "Debug mode: $DEBUG_MODE"
  [[ -n "$TOPIC_FILTER" ]] && echo "Topic: $TOPIC_FILTER"
  [[ ${#SKIP_EXAMPLES[@]} -gt 0 ]] && echo "Skipping: ${SKIP_EXAMPLES[*]}"

  if [[ "$VALIDATE_ONLY" == true ]]; then
    # Validation only mode - test each example independently
    if [[ -n "$SETUP_EXAMPLE" ]]; then
      if ! should_skip "$SETUP_EXAMPLE"; then
        if run_validate "$SETUP_EXAMPLE"; then
          PASSED_EXAMPLES+=("$SETUP_EXAMPLE")
        else
          FAILED_EXAMPLES+=("$SETUP_EXAMPLE")
        fi
      fi
    fi
    for example in "${EXAMPLES[@]}"; do
      if should_skip "$example"; then
        echo -e "\n${YELLOW}=== Skipping: $example ===${NC}"
        continue
      fi
      if run_validate "$example"; then
        PASSED_EXAMPLES+=("$example")
      else
        FAILED_EXAMPLES+=("$example")
      fi
    done
  else
    # Full test mode

    # Step 1: Apply setup example (creates publishers) if needed
    if [[ -n "$SETUP_EXAMPLE" ]] && ! should_skip "$SETUP_EXAMPLE"; then
      if run_apply "$SETUP_EXAMPLE"; then
        PASSED_EXAMPLES+=("$SETUP_EXAMPLE")
        # Skip drift check for setup example — its data sources (publishers list)
        # reflect newly-created resources, so re-plan always shows output changes
      else
        FAILED_EXAMPLES+=("$SETUP_EXAMPLE")
        echo -e "${RED}Setup failed, cannot continue with dependent tests${NC}"
      fi
    fi

    # Step 2: Test each example (apply + destroy)
    for example in "${EXAMPLES[@]}"; do
      if should_skip "$example"; then
        echo -e "\n${YELLOW}=== Skipping: $example ===${NC}"
        continue
      fi
      if test_example "$example"; then
        PASSED_EXAMPLES+=("$example")
      else
        FAILED_EXAMPLES+=("$example")
      fi
    done

    # Step 3: Destroy setup example (cleanup publishers) if needed
    if [[ -n "$SETUP_EXAMPLE" ]] && ! should_skip "$SETUP_EXAMPLE"; then
      echo -e "\n${YELLOW}=== Cleanup ===${NC}"
      run_destroy "$SETUP_EXAMPLE" || true
    fi
  fi

  # Summary
  echo -e "\n${YELLOW}=== Summary ===${NC}"
  echo -e "${GREEN}Passed: ${#PASSED_EXAMPLES[@]}${NC}"
  [[ ${#PASSED_EXAMPLES[@]} -gt 0 ]] && echo "  ${PASSED_EXAMPLES[*]}"
  echo -e "${RED}Failed: ${#FAILED_EXAMPLES[@]}${NC}"
  [[ ${#FAILED_EXAMPLES[@]} -gt 0 ]] && echo "  ${FAILED_EXAMPLES[*]}"
  if [[ ${#DRIFT_EXAMPLES[@]} -gt 0 ]]; then
    echo -e "${RED}Drift: ${#DRIFT_EXAMPLES[@]}${NC}"
    echo "  ${DRIFT_EXAMPLES[*]}"
  fi

  [[ ${#FAILED_EXAMPLES[@]} -gt 0 || ${#DRIFT_EXAMPLES[@]} -gt 0 ]] && exit 1
  exit 0
}

main