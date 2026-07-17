#!/usr/bin/env bash
#
# Audit the Bubbler codebase with Semgrep security rules.
#
# Usage (from any directory):
#   ./scripts/semgrep_audit.sh
#   ./scripts/semgrep_audit.sh --all-severities
#   ./scripts/semgrep_audit.sh --json reports/semgrep.json
#   ./scripts/semgrep_audit.sh --sarif reports/semgrep.sarif
#   ./scripts/semgrep_audit.sh --no-fail
#
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# These registry packs cover high-confidence vulnerabilities, the OWASP Top 10,
# and accidentally committed credentials. Override with a comma-separated list.
DEFAULT_CONFIGS="p/default,p/security-audit,p/owasp-top-ten,p/secrets"
CONFIGS="${SEMGREP_CONFIGS:-$DEFAULT_CONFIGS}"

FAIL_ON_FINDINGS=true
ALL_SEVERITIES=false
OUTPUT_FORMAT="text"
OUTPUT_FILE=""

usage() {
  cat <<'EOF'
Run a Semgrep security audit of the Bubbler repository.

Options:
  --all-severities   Include INFO findings (default: WARNING and ERROR)
  --json PATH        Write a JSON report to PATH
  --sarif PATH       Write a SARIF report to PATH (for code-scanning tools)
  --no-fail          Exit successfully even when vulnerabilities are found
  -h, --help         Show this help

Environment:
  SEMGREP_CONFIGS    Comma-separated rule packs or config paths.
                     Default: p/default,p/security-audit,p/owasp-top-ten,p/secrets

Any arguments after "--" are passed directly to "semgrep scan".

Examples:
  ./scripts/semgrep_audit.sh
  ./scripts/semgrep_audit.sh --json reports/semgrep.json
  ./scripts/semgrep_audit.sh -- --exclude backend/tests/fixtures
  SEMGREP_CONFIGS=p/default,p/secrets ./scripts/semgrep_audit.sh
EOF
}

fail() {
  printf 'error: %s\n' "$*" >&2
  exit 2
}

extra_args=()
while [[ $# -gt 0 ]]; do
  case "$1" in
    --all-severities)
      ALL_SEVERITIES=true
      shift
      ;;
    --json | --sarif)
      [[ $# -ge 2 ]] || fail "$1 requires an output path"
      OUTPUT_FORMAT="${1#--}"
      OUTPUT_FILE="$2"
      shift 2
      ;;
    --no-fail)
      FAIL_ON_FINDINGS=false
      shift
      ;;
    -h | --help)
      usage
      exit 0
      ;;
    --)
      shift
      extra_args=("$@")
      break
      ;;
    *)
      fail "unknown option: $1 (use -- before raw Semgrep arguments)"
      ;;
  esac
done

command -v semgrep >/dev/null 2>&1 || fail \
  "Semgrep is not installed. Install it with 'brew install semgrep' or 'python3 -m pip install semgrep'."

config_args=()
IFS=',' read -r -a config_list <<<"$CONFIGS"
for config in "${config_list[@]}"; do
  [[ -n "$config" ]] && config_args+=(--config "$config")
done
[[ ${#config_args[@]} -gt 0 ]] || fail "SEMGREP_CONFIGS did not contain a rule pack"

severity_args=(--severity WARNING --severity ERROR)
if $ALL_SEVERITIES; then
  severity_args=(--severity INFO --severity WARNING --severity ERROR)
fi

failure_args=()
if $FAIL_ON_FINDINGS; then
  failure_args=(--error)
fi

output_args=()
if [[ -n "$OUTPUT_FILE" ]]; then
  output_dir="$(dirname "$OUTPUT_FILE")"
  [[ "$output_dir" == "." ]] || mkdir -p "$output_dir"
  case "$OUTPUT_FORMAT" in
    json) output_args=(--json --output "$OUTPUT_FILE") ;;
    sarif) output_args=(--sarif --output "$OUTPUT_FILE") ;;
  esac
fi

printf 'Semgrep security audit\n'
printf '  target:  %s\n' "$ROOT"
printf '  configs: %s\n' "$CONFIGS"
printf '  levels:  %s\n' "$($ALL_SEVERITIES && printf 'INFO, WARNING, ERROR' || printf 'WARNING, ERROR')"
[[ -z "$OUTPUT_FILE" ]] || printf '  report:  %s\n' "$OUTPUT_FILE"
printf '\n'

# macOS ships Bash 3.2: with `set -u`, expanding an empty array as
# "${arr[@]}" is an unbound-variable error. Use ${arr[@]+"${arr[@]}"} instead.
exec semgrep scan \
  "${config_args[@]}" \
  "${severity_args[@]}" \
  ${failure_args[@]+"${failure_args[@]}"} \
  ${output_args[@]+"${output_args[@]}"} \
  --metrics=off \
  --exclude .git \
  --exclude .venv \
  --exclude venv \
  --exclude node_modules \
  --exclude DerivedData \
  --exclude .build \
  --exclude build \
  --exclude dist \
  ${extra_args[@]+"${extra_args[@]}"} \
  "$ROOT"
