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
  "npa/block-rules-and-ordering"
  "npa/periodic-reauth-policy"
)

# Examples whose first plan after apply legitimately shows ONE in-place update:
# provider >= 0.4.13 records the notification template display name in private
# state on the first update after create ("block_page.html" -> "<name>"). For
# these examples the harness runs a second (converging) apply before the drift
# check, then an update step that changes every rule description and verifies
# the update succeeds, no drift follows, and block rules keep their list
# position (provider issues #124, #129).
CONVERGING_EXAMPLES=(
  "npa/policy-as-code"
  "npa/block-rules-and-ordering"
  "npa/periodic-reauth-policy"
)

# Examples that need a tenant-specific variable and are skipped when it is unset.
# NETSKOPE_TEST_REAUTH_TEMPLATE: periodic_reauth notification template DISPLAY NAME
# (the API rejects filenames; see examples/npa/periodic-reauth-policy).

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
# - npa/multi-tenant-deployment (requires credentials + an existing publisher for
#   THREE separate Netskope tenants; this single-tenant test harness only sets one
#   NETSKOPE_SERVER_URL/NETSKOPE_API_KEY pair)
#
# npa/block-rules-and-ordering and npa/policy-as-code notes:
# - Require block_template to be set (default "Generic Block" may not exist on every
#   tenant; set TF_VAR_block_template to a valid block page template display name from
#   Settings > Security Cloud Platform > NPA > Block Templates)
# - These are CONVERGING_EXAMPLES: the first plan after apply shows one template update
#   per block rule; the harness applies it before the drift check (see above).
#
# npa/periodic-reauth-policy notes:
# - Skipped unless NETSKOPE_TEST_REAUTH_TEMPLATE is set (passed as TF_VAR_reauth_template).
# - Must be a template display name; the API rejects .html filenames for periodic_reauth.
#
# Cloud provider examples excluded:
# - npa/publisher-aws (requires AWS credentials and marketplace subscription)
#
# IPSec examples excluded:
# - ipsec/vpn (requires IPSec/GRE license and network configuration)
# - ipsec/aws-transitgateway-vpn (requires AWS credentials)

SKIP_EXAMPLES=()
VALIDATE_ONLY=false
SCALE_ONLY=false
SCALE_EXAMPLE="npa/policy-at-scale"
TOPIC_FILTER=""
FAILED_EXAMPLES=()
PASSED_EXAMPLES=()
DRIFT_EXAMPLES=()
UPDATE_FAILED_EXAMPLES=()

# Debug mode detection (provider already running via TF_REATTACH_PROVIDERS)
DEBUG_MODE=false
if [[ -n "${TF_REATTACH_PROVIDERS:-}" ]]; then
  DEBUG_MODE=true
fi

# Dev-override mode: the CLI config (~/.terraformrc or TF_CLI_CONFIG_FILE) has a
# provider_installation.dev_overrides entry for netskopeoss/netskope. Terraform
# then loads the provider from that directory for plan/apply, but `terraform init`
# still resolves versions against the registry and fails on constraints no
# published release satisfies (e.g. ">= 0.4.13" before release). Terraform itself
# says to skip init in this mode, so the harness does. Set TF_DEV_OVERRIDE=1 to
# force it, or =0 to disable detection.
DEV_OVERRIDE_MODE=false
_tfrc="${TF_CLI_CONFIG_FILE:-$HOME/.terraformrc}"
if [[ "${TF_DEV_OVERRIDE:-}" == "1" ]]; then
  DEV_OVERRIDE_MODE=true
elif [[ "${TF_DEV_OVERRIDE:-}" != "0" ]] && [[ -f "$_tfrc" ]] \
  && grep -qE '^\s*"netskopeoss/netskope"\s*=' "$_tfrc" 2>/dev/null \
  && grep -q 'dev_overrides' "$_tfrc" 2>/dev/null; then
  DEV_OVERRIDE_MODE=true
fi
# dev_overrides in TF_CLI_CONFIG_FILE also skip init (provider served locally).
if [[ -n "${TF_CLI_CONFIG_FILE:-}" ]] && grep -q "dev_overrides" "${TF_CLI_CONFIG_FILE}" 2>/dev/null; then
  DEBUG_MODE=true
fi

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

usage() {
  echo "Usage: $0 [-s example] [-v] [-t topic] [--scale]"
  echo "  -s, --skip      Skip specific example (can be used multiple times)"
  echo "  -v, --validate  Run syntax validation only (no apply/destroy)"
  echo "  -t, --topic     Run only examples for a topic: npa, dnsprofiles, web-policy, ipsec"
  echo "  --scale         Run ONLY the npa/policy-at-scale scenario (issues #125/#129 at"
  echo "                  realistic rule counts; times applies and counts PATCH calls)"
  echo ""
  echo "Environment variables:"
  echo "  NETSKOPE_SERVER_URL  Netskope API server URL (required for apply/destroy)"
  echo "  NETSKOPE_API_KEY     Netskope API key (required for apply/destroy)"
  echo "  TF_REATTACH_PROVIDERS  Debug mode - attach to running provider (skips init)"
  echo "  TF_DEV_OVERRIDE=1|0    Force/disable skipping init when ~/.terraformrc has"
  echo "                         dev_overrides for netskopeoss/netskope (auto-detected)"
  echo "  TF_VAR_block_template  Block page template display name (policy examples)"
  echo "  NETSKOPE_TEST_REAUTH_TEMPLATE  periodic_reauth template display name;"
  echo "                         npa/periodic-reauth-policy is skipped when unset"
  echo "  SCALE_RULE_COUNT       Rules for --scale (default 45; use 232 to match #125/#129)"
  echo "  SCALE_MAX_NOOP_SECONDS Fail --scale if a no-op/removal apply exceeds this (default 60)"
  exit 1
}

# Parse arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    -s|--skip) SKIP_EXAMPLES+=("$2"); shift 2 ;;
    -v|--validate) VALIDATE_ONLY=true; shift ;;
    -t|--topic) TOPIC_FILTER="$2"; shift 2 ;;
    --scale) SCALE_ONLY=true; shift ;;
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

# Check if example needs an env var that is not set (skip with a message).
# Uses a case statement instead of an associative array for bash 3 compatibility.
missing_required_env() {
  local example=$1
  local required_var=""
  case "$example" in
    "npa/periodic-reauth-policy") required_var="NETSKOPE_TEST_REAUTH_TEMPLATE" ;;
  esac
  if [[ -n "$required_var" ]] && [[ -z "${!required_var:-}" ]]; then
    echo -e "\n${YELLOW}=== Skipping: $example (set $required_var to run) ===${NC}"
    return 0
  fi
  return 1
}

# Export example-specific TF_VAR_* from NETSKOPE_TEST_* env vars
export_example_vars() {
  # The provider repo's .env uses NETSKOPE_TEST_PERIODIC_REAUTH_TEMPLATE; accept
  # both names so one .env serves both repos.
  if [[ -z "${NETSKOPE_TEST_REAUTH_TEMPLATE:-}" ]] && [[ -n "${NETSKOPE_TEST_PERIODIC_REAUTH_TEMPLATE:-}" ]]; then
    export NETSKOPE_TEST_REAUTH_TEMPLATE="$NETSKOPE_TEST_PERIODIC_REAUTH_TEMPLATE"
  fi
  if [[ -n "${NETSKOPE_TEST_REAUTH_TEMPLATE:-}" ]]; then
    export TF_VAR_reauth_template="$NETSKOPE_TEST_REAUTH_TEMPLATE"
  fi
}

is_converging() {
  local example=$1
  for c in "${CONVERGING_EXAMPLES[@]}"; do
    [[ "$c" == "$example" ]] && return 0
  done
  return 1
}

# Converging apply: provider >= 0.4.13 records the template display name on the
# first update after create, so the first plan shows exactly one in-place update
# per block/periodic_reauth rule ("block_page.html" -> "<name>"). Apply it so the
# drift check that follows runs against a converged state.
run_converging_apply() {
  local example=$1
  echo "  Converging apply (expected one-time template update per rule)..."
  if ! terraform apply -auto-approve -input=false > /dev/null 2>&1; then
    echo -e "  ${RED}FAILED: converging apply${NC}"
    terraform apply -auto-approve -input=false 2>&1 | tail -40
    return 1
  fi
  return 0
}

# Assert that the example's ordered_rule_ids output appears in the live rule list
# in exactly that relative order. Catches a provider that re-sends rule_order on
# update (#129 P2): any moved rule breaks the sequence. Requires jq; skipped with a
# warning if the output is absent. Note: assumes GET /policy/npa/rules returns the
# full list in display order with a rule_id (or id) field and no pagination.
check_live_order_matches() {
  local label=$1
  if ! command -v jq > /dev/null 2>&1; then
    echo -e "  ${YELLOW}jq not installed — skipping rule order check${NC}"
    return 0
  fi
  local raw desired
  raw=$(terraform output -json ordered_rule_ids 2>/dev/null || true)
  if [[ -z "$raw" ]]; then
    echo -e "  ${YELLOW}No ordered_rule_ids output — skipping rule order check${NC}"
    return 0
  fi
  desired=$(echo "$raw" | jq -r '.[]?')
  if [[ -z "$desired" ]]; then
    # The output exists but is empty: the example created no rules, so none of the
    # #124/#129 paths ran. A converging example in this state proves nothing — fail
    # rather than report a hollow PASS (e.g. policy-as-code when no apps carry the
    # tier tags it discovers rules from).
    echo -e "  ${RED}RULE ORDER CHECK ($label): ordered_rule_ids is empty — the example created no rules, so template/update/order behaviour was not exercised${NC}"
    return 1
  fi
  local live
  live=$(curl -s -H "Netskope-Api-Token: $NETSKOPE_API_KEY" "$NETSKOPE_SERVER_URL/policy/npa/rules" \
    | jq -r '[.data[] | (.rule_id // .id) | tostring] | to_entries | .[] | "\(.value) \(.key)"')
  local prev=-1 prev_id="" id pos
  for id in $desired; do
    pos=$(echo "$live" | awk -v id="$id" '$1==id {print $2}')
    if [[ -z "$pos" ]]; then
      echo -e "  ${RED}RULE ORDER CHECK ($label): rule $id not found in live rule list${NC}"
      return 1
    fi
    if (( pos < prev )); then
      echo -e "  ${RED}RULE ORDER CHANGED ($label): rule $id (pos $pos) is above rule $prev_id (pos $prev) — rule_order re-sent on update?${NC}"
      return 1
    fi
    prev=$pos
    prev_id=$id
  done
  echo -e "  ${GREEN}Live rule order matches ordered_rule_ids ($label)${NC}"
  return 0
}

# Resolve the Terraform address of the rule at the top of ordered_rule_ids.
# Used to update ONE rule in isolation: under the #129 bug that rule moves to
# the bottom, which check_live_order_matches detects deterministically. Updating
# every rule at once is not a reliable detector, because the moved rules may land
# in the desired order by chance (apply order is parallel and undefined).
top_rule_address() {
  local top_id
  top_id=$(terraform output -json ordered_rule_ids 2>/dev/null | jq -r '.[0]?' || true)
  [[ -z "$top_id" || "$top_id" == "null" ]] && return 1
  terraform show -json 2>/dev/null | jq -r --arg id "$top_id" \
    '.values.root_module.resources[]? | select(.type=="netskope_npa_rules" and .values.id==$id) | .address' | head -1
}

# Update step, two parts:
#   1. Update only the top rule (targeted apply) and verify the live order is
#      unchanged — the deterministic #129 P2 check.
#   2. Update every rule description, verify the update succeeds (#124), that no
#      drift follows, and that the live order still matches.
run_update_step() {
  local example=$1
  local suffix=" (updated by test harness)"
  local rc=0

  local top_addr
  top_addr=$(top_rule_address || true)
  if [[ -n "$top_addr" ]]; then
    echo "  Update step 1/2: updating only ${top_addr}..."
    if ! TF_VAR_description_suffix="$suffix" terraform apply -auto-approve -input=false -target="$top_addr" > /dev/null 2>&1; then
      echo -e "  ${RED}FAILED: targeted in-place update of ${top_addr}${NC}"
      TF_VAR_description_suffix="$suffix" terraform apply -auto-approve -input=false -target="$top_addr" 2>&1 | tail -40
      return 1
    fi
    if ! check_live_order_matches "after single-rule update"; then
      rc=1
    fi
  else
    echo -e "  ${YELLOW}Could not resolve top rule address — skipping single-rule update check${NC}"
  fi

  echo "  Update step 2/2: appending to every rule description..."
  if ! TF_VAR_description_suffix="$suffix" terraform apply -auto-approve -input=false > /dev/null 2>&1; then
    echo -e "  ${RED}FAILED: in-place update of rules${NC}"
    TF_VAR_description_suffix="$suffix" terraform apply -auto-approve -input=false 2>&1 | tail -40
    return 1
  fi
  echo "  Checking for drift after update..."
  if ! TF_VAR_description_suffix="$suffix" run_drift_check "$example"; then
    rc=1
  fi
  if ! check_live_order_matches "after full update"; then
    rc=1
  fi
  return $rc
}

# ---------------------------------------------------------------------------
# Scale scenario (issues #125 and #129 at realistic rule counts)
# ---------------------------------------------------------------------------
# Runs npa/policy-at-scale with SCALE_RULE_COUNT rules and checks the claims
# from the original reports directly:
#   #125: removing one rule must NOT re-PATCH every rule; the apply must be fast.
#   #129: the converging template apply and a single block-rule update must not
#         move any rule; the template diff must not recur.
# Each terraform invocation is a separate process, which is the same condition
# as a Terraform Cloud run (no in-process provider state survives between steps).

# Count reorder PATCHes in a TF_LOG=DEBUG apply. The provider's SDK logs each
# request at DEBUG; a PATCH to /policy/npa/rules/<id> is either a rule update or
# an order move, so callers compare the count against the expected number of
# rule updates. Verify the pattern on the first run by inspecting the log.
# The SDK logs each request as "Sending HTTP Request" with tflog key=value fields
# (tf_http_req_method, tf_http_req_uri, tf_http_trans_id). One request can
# produce several log lines with different key subsets, so count DISTINCT
# transaction ids among lines that carry the PATCH method. All PATCHes in the
# scale example go to /policy/npa/rules/<id> (rule updates and order moves).
count_rule_patches() {
  local logfile=$1
  local n
  n=$(grep 'tf_http_req_method=PATCH' "$logfile" | grep -o 'tf_http_trans_id=[a-f0-9-]*' | sort -u | wc -l | tr -d ' ')
  if [[ "$n" == "0" ]]; then
    # Fallback if method and trans_id are not on the same line: count PATCH lines.
    n=$(grep -c 'tf_http_req_method=PATCH' "$logfile" || true)
  fi
  echo "$n"
}

# Debug logs from the scale scenario are kept under harness-logs/ (gitignored via
# *.log) so PATCH lines can be inspected when the count disagrees with Terraform's
# own "N changed" summary.
HARNESS_LOG_DIR="$SCRIPT_DIR/../harness-logs"

timed_apply() {
  local label=$1; shift
  mkdir -p "$HARNESS_LOG_DIR"
  local logfile="$HARNESS_LOG_DIR/scale-$(echo "$label" | tr ' ' '-').log"
  local start end
  start=$(date +%s)
  if ! TF_LOG=DEBUG "$@" terraform apply -auto-approve -input=false > "$logfile" 2>&1; then
    end=$(date +%s)
    echo -e "  ${RED}FAILED: $label ($((end-start))s)${NC}"
    # Show the Terraform diagnostics (the box-drawn blocks), not the DEBUG noise.
    grep -vE '^\S+ \[(DEBUG|TRACE|INFO|WARN)\]' "$logfile" | grep -E '^│|^╷|^╵' | head -40
    echo "  (full log kept at $logfile)"
    return 1
  fi
  end=$(date +%s)
  local patches
  patches=$(count_rule_patches "$logfile")
  local changed
  changed=$(grep -oE 'Apply complete! Resources: [0-9]+ added, [0-9]+ changed, [0-9]+ destroyed' "$logfile" | tail -1)
  echo "  $label: $((end-start))s, rule PATCH calls: $patches, $changed"
  # Export for the caller's assertions
  LAST_SECONDS=$((end-start)); LAST_PATCHES=$patches
  return 0
}

run_scale_scenario() {
  local example=$SCALE_EXAMPLE
  local dir="$CODE_DIR/$example"
  local n="${SCALE_RULE_COUNT:-45}"
  local max_noop="${SCALE_MAX_NOOP_SECONDS:-60}"
  local rc=0

  echo -e "\n${YELLOW}=== Scale scenario: $example with $n rules ===${NC}"
  cleanup "$dir"
  cd "$dir"
  setup_tfvars "$dir"
  if ! run_init "$dir"; then return 1; fi
  # terraform.tfvars takes precedence over TF_VAR_*; the example's tfvars pins
  # rule_count, so rewrite that line rather than relying on the env var.
  if grep -q '^rule_count' "$dir/terraform.tfvars"; then
    sed -i.bak "s|^rule_count *=.*|rule_count = $n|" "$dir/terraform.tfvars" && rm -f "$dir/terraform.tfvars.bak"
  else
    echo "rule_count = $n" >> "$dir/terraform.tfvars"
  fi
  echo "  rule_count = $n written to terraform.tfvars"

  echo "  Step 1: create $n rules (serialised by the provider; ~1-2s per rule)..."
  timed_apply "create" || { terraform destroy -auto-approve -input=false >/dev/null 2>&1 || true; return 1; }
  check_live_order_matches "after create" || rc=1

  echo "  Step 2: converging apply (expected: one template update per block rule, no moves)..."
  timed_apply "converging apply" || rc=1
  check_live_order_matches "after converging apply" || rc=1

  echo "  Step 3: no-op apply (expected: 0 changes, 0 PATCHes, < ${max_noop}s)..."
  timed_apply "no-op apply" || rc=1
  if (( LAST_PATCHES > 0 )); then echo -e "  ${RED}#125 REGRESSION: no-op apply sent $LAST_PATCHES PATCHes${NC}"; rc=1; fi
  if (( LAST_SECONDS > max_noop )); then echo -e "  ${RED}#125 REGRESSION: no-op apply took ${LAST_SECONDS}s${NC}"; rc=1; fi

  local mid=$(( n / 2 ))
  echo "  Step 4: remove rule index $mid (expected: 1 destroy, 1 order update, 0 PATCHes, < ${max_noop}s)..."
  timed_apply "remove one rule" env TF_VAR_excluded_rule_indexes="[$mid]" || rc=1
  if (( LAST_PATCHES > 0 )); then echo -e "  ${RED}#125 REGRESSION: removing one rule sent $LAST_PATCHES reorder PATCHes${NC}"; rc=1; fi
  if (( LAST_SECONDS > max_noop )); then echo -e "  ${RED}#125 REGRESSION: removal apply took ${LAST_SECONDS}s${NC}"; rc=1; fi
  TF_VAR_excluded_rule_indexes="[$mid]" check_live_order_matches "after removing one rule" || rc=1

  echo "  Step 5: update ONE block rule (expected: 1 PATCH, no moves)..."
  local top_block
  top_block=$(terraform show -json 2>/dev/null | jq -r '.values.root_module.resources[]? | select(.type=="netskope_npa_rules" and (.address|startswith("netskope_npa_rules.block"))) | .address' | head -1)
  if [[ -n "$top_block" ]]; then
    # timed_apply does not support -target; run directly but still time and count.
    local logfile="$HARNESS_LOG_DIR/scale-single-block-update.log"; local s0; s0=$(date +%s)
    if TF_LOG=DEBUG TF_VAR_excluded_rule_indexes="[$mid]" TF_VAR_description_suffix=" (updated)" terraform apply -auto-approve -input=false -target="$top_block" > "$logfile" 2>&1; then
      echo "  single block-rule update: $(( $(date +%s) - s0 ))s, rule PATCH calls: $(count_rule_patches "$logfile")"
    else
      echo -e "  ${RED}FAILED: single block-rule update${NC}"; grep -E '^│|^╷|^╵' "$logfile" | head -40; rc=1
    fi
    TF_VAR_excluded_rule_indexes="[$mid]" check_live_order_matches "after single block-rule update" || rc=1
  else
    echo -e "  ${YELLOW}Could not resolve a block rule address — skipping single-rule update${NC}"
  fi

  echo "  Step 6: update every rule (expected: $((n-1)) PATCHes, no moves)..."
  timed_apply "update all rules" env TF_VAR_excluded_rule_indexes="[$mid]" TF_VAR_description_suffix=" (updated)" || rc=1
  TF_VAR_excluded_rule_indexes="[$mid]" TF_VAR_description_suffix=" (updated)" check_live_order_matches "after updating all rules" || rc=1

  echo "  Step 7: plan must be empty..."
  if ! TF_VAR_excluded_rule_indexes="[$mid]" TF_VAR_description_suffix=" (updated)" run_drift_check "$example"; then rc=1; fi

  echo "  Destroying..."
  TF_VAR_excluded_rule_indexes="[$mid]" TF_VAR_description_suffix=" (updated)" terraform destroy -auto-approve -input=false >/dev/null 2>&1 || { echo -e "  ${RED}FAILED: destroy${NC}"; rc=1; }
  cleanup "$dir"
  if (( rc == 0 )); then echo -e "  ${GREEN}SCALE SCENARIO PASSED${NC}"; else echo -e "  ${RED}SCALE SCENARIO FAILED${NC}"; fi
  return $rc
}

# Setup tfvars if example file exists.
# When TF_VAR_block_template is set, overwrite the block_template value in the
# copied tfvars — tfvars take precedence over env vars in Terraform's loading
# order, so the env var alone is not enough when a tfvars file is present.
setup_tfvars() {
  local dir=$1
  if [[ -f "$dir/terraform.tfvars.example" ]] && [[ ! -f "$dir/terraform.tfvars" ]]; then
    cp "$dir/terraform.tfvars.example" "$dir/terraform.tfvars"
    echo "  Copied terraform.tfvars.example to terraform.tfvars"
  fi
  if [[ -n "${TF_VAR_block_template:-}" ]] && [[ -f "$dir/terraform.tfvars" ]]; then
    if grep -q "^block_template" "$dir/terraform.tfvars" 2>/dev/null; then
      sed -i.bak "s|^block_template = .*|block_template = \"${TF_VAR_block_template}\"|" "$dir/terraform.tfvars"
      rm -f "$dir/terraform.tfvars.bak"
      echo "  Overrode block_template = \"${TF_VAR_block_template}\" (from TF_VAR_block_template)"
    fi
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
  if [[ "$DEV_OVERRIDE_MODE" == true ]]; then
    echo "  Skipping terraform init (dev_overrides for netskopeoss/netskope in $_tfrc)"
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

  # Converging apply for examples with template-bearing rules (provider >= 0.4.13).
  # The converging PATCH is itself an update, so the rule order is checked right
  # after it — on <= 0.4.12 this PATCH also re-sent rule_order (#129 P2).
  if is_converging "$example"; then
    if ! run_converging_apply "$example"; then
      terraform destroy -auto-approve -input=false 2>/dev/null || true
      return 1
    fi
    if ! check_live_order_matches "after converging apply"; then
      UPDATE_FAILED_EXAMPLES+=("$example")
    fi
  fi

  # Drift check
  if ! run_drift_check "$example"; then
    DRIFT_EXAMPLES+=("$example")
  fi

  # Update step: exercises the update path (#124) and rule position stability (#129).
  # Recorded separately from drift so the summary says what actually failed.
  if is_converging "$example"; then
    if ! run_update_step "$example"; then
      UPDATE_FAILED_EXAMPLES+=("$example")
    fi
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
  export_example_vars

  echo "Testing Terraform examples..."
  echo "Validate only: $VALIDATE_ONLY"
  echo "Debug mode: $DEBUG_MODE"
  echo "Dev override mode: $DEV_OVERRIDE_MODE"

  if [[ "$SCALE_ONLY" == true ]]; then
    if run_scale_scenario; then exit 0; else exit 1; fi
  fi
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
      if missing_required_env "$example"; then
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
  if [[ ${#UPDATE_FAILED_EXAMPLES[@]} -gt 0 ]]; then
    echo -e "${RED}Update/rule-order check failed: ${#UPDATE_FAILED_EXAMPLES[@]}${NC}"
    echo "  ${UPDATE_FAILED_EXAMPLES[*]}"
  fi

  [[ ${#FAILED_EXAMPLES[@]} -gt 0 || ${#DRIFT_EXAMPLES[@]} -gt 0 || ${#UPDATE_FAILED_EXAMPLES[@]} -gt 0 ]] && exit 1
  exit 0
}

main