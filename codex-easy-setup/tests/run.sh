#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
TEMP_DIR=$(mktemp -d)
TEST_HOME="$TEMP_DIR/home"
TEST_CODEX_HOME="$TEST_HOME/.codex"

cleanup() {
  rm -rf "$TEMP_DIR"
}
trap cleanup EXIT

assert_contains() {
  local expected=$1
  local file=$2
  if ! grep -Fqx "$expected" "$file"; then
    printf 'Expected line not found: %s\nFile: %s\n' "$expected" "$file" >&2
    exit 1
  fi
}

mkdir -p "$TEST_CODEX_HOME"
cat > "$TEST_CODEX_HOME/config.toml" <<'EOF'
check_for_update_on_startup = false

[features]
multi_agent = false

[model_providers]
EOF

bash -n "$ROOT_DIR/install.sh"

HOME="$TEST_HOME" \
CODEX_HOME="$TEST_CODEX_HOME" \
CODEX_EASY_BASE_URL="https://relay.example.test/v1" \
CODEX_EASY_PROVIDER_NAME="Test Relay" \
CODEX_EASY_MODEL="test-model" \
CODEX_EASY_API_KEY="test-key-123" \
CODEX_EASY_REASONING_EFFORT="high" \
CODEX_EASY_SANDBOX_MODE="workspace-write" \
CODEX_EASY_APPROVAL_POLICY="never" \
CODEX_EASY_NETWORK_ACCESS="true" \
bash "$ROOT_DIR/install.sh" --non-interactive

CONFIG_FILE="$TEST_CODEX_HOME/config.toml"
SECRET_FILE="$TEST_CODEX_HOME/codex-easy-env.sh"

assert_contains 'model = "test-model"' "$CONFIG_FILE"
assert_contains 'model_reasoning_effort = "high"' "$CONFIG_FILE"
assert_contains 'model_provider = "codex_easy"' "$CONFIG_FILE"
assert_contains 'approval_policy = "never"' "$CONFIG_FILE"
assert_contains 'sandbox_mode = "workspace-write"' "$CONFIG_FILE"
assert_contains 'network_access = true' "$CONFIG_FILE"
assert_contains '[model_providers.codex_easy]' "$CONFIG_FILE"
assert_contains 'base_url = "https://relay.example.test/v1"' "$CONFIG_FILE"
assert_contains 'env_key = "CODEX_EASY_API_KEY"' "$CONFIG_FILE"
assert_contains 'wire_api = "responses"' "$CONFIG_FILE"
assert_contains 'check_for_update_on_startup = false' "$CONFIG_FILE"
assert_contains '[features]' "$CONFIG_FILE"
assert_contains 'multi_agent = false' "$CONFIG_FILE"
assert_contains '[model_providers]' "$CONFIG_FILE"

if ! compgen -G "$CONFIG_FILE.backup.*" >/dev/null; then
  printf '%s\n' 'Expected config backup was not created.' >&2
  exit 1
fi

if [[ $(stat -c '%a' "$SECRET_FILE") != '600' ]]; then
  printf '%s\n' 'API Key file is not mode 600.' >&2
  exit 1
fi

assert_contains 'export CODEX_EASY_API_KEY=test-key-123' "$SECRET_FILE"
assert_contains '# >>> codex-easy-setup >>>' "$TEST_HOME/.bashrc"

HOME="$TEST_HOME" \
CODEX_HOME="$TEST_CODEX_HOME" \
CODEX_EASY_BASE_URL="https://relay.example.test/v1" \
CODEX_EASY_PROVIDER_NAME="Test Relay" \
CODEX_EASY_MODEL="test-model-v2" \
CODEX_EASY_API_KEY="test-key-123" \
CODEX_EASY_REASONING_EFFORT="xhigh" \
CODEX_EASY_SANDBOX_MODE="danger-full-access" \
CODEX_EASY_APPROVAL_POLICY="on-request" \
bash "$ROOT_DIR/install.sh" --non-interactive

assert_contains 'model = "test-model-v2"' "$CONFIG_FILE"
assert_contains 'model_reasoning_effort = "xhigh"' "$CONFIG_FILE"
assert_contains 'sandbox_mode = "danger-full-access"' "$CONFIG_FILE"
assert_contains 'approval_policy = "on-request"' "$CONFIG_FILE"

if [[ $(grep -Fxc '[model_providers.codex_easy]' "$CONFIG_FILE") -ne 1 ]]; then
  printf '%s\n' 'Custom provider table was duplicated.' >&2
  exit 1
fi

python3 - "$CONFIG_FILE" <<'PY'
import sys
import tomllib

with open(sys.argv[1], "rb") as config_file:
    config = tomllib.load(config_file)

assert config["model"] == "test-model-v2"
assert config["model_provider"] == "codex_easy"
assert config["model_providers"]["codex_easy"]["wire_api"] == "responses"
assert config["features"]["multi_agent"] is False
PY

printf '%s\n' 'All Codex Easy Setup tests passed.'
