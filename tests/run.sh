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

cat > "$TEST_HOME/.bashrc" <<'EOF'
export TEST_USER_SETTING=preserved
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

if grep -F 'test-key-123' "$CONFIG_FILE" >/dev/null; then
  printf '%s\n' 'API Key must not be written to config.toml.' >&2
  exit 1
fi

if ! compgen -G "$CONFIG_FILE.backup.*" >/dev/null; then
  printf '%s\n' 'Expected config backup was not created.' >&2
  exit 1
fi

if [[ $(uname -s) == Linux* ]]; then
  if [[ $(stat -c '%a' "$SECRET_FILE") != '600' ]]; then
    printf '%s\n' 'API Key file is not mode 600.' >&2
    exit 1
  fi
fi

assert_contains 'export CODEX_EASY_API_KEY=test-key-123' "$SECRET_FILE"
assert_contains '# >>> codex-easy-setup >>>' "$TEST_HOME/.bashrc"
assert_contains 'export TEST_USER_SETTING=preserved' "$TEST_HOME/.bashrc"
if ! grep -F 'update|--update' "$ROOT_DIR/install.sh" >/dev/null; then
  printf '%s\n' 'Launcher update dispatch is missing.' >&2
  exit 1
fi
if ! grep -F 'doctor|--doctor' "$ROOT_DIR/install.sh" >/dev/null; then
  printf '%s\n' 'Launcher doctor dispatch is missing.' >&2
  exit 1
fi

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

if ! compgen -G "$TEST_HOME/.bashrc.codex-easy-setup.backup.*" >/dev/null; then
  printf '%s\n' 'Expected Shell startup backup was not created.' >&2
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

DEFAULT_TEST_HOME="$TEMP_DIR/default-model-home"
DEFAULT_TEST_CODEX_HOME="$DEFAULT_TEST_HOME/.codex"
HOME="$DEFAULT_TEST_HOME" \
CODEX_HOME="$DEFAULT_TEST_CODEX_HOME" \
CODEX_EASY_BASE_URL="https://relay.example.test/v1" \
CODEX_EASY_PROVIDER_NAME="Test Relay" \
CODEX_EASY_MODEL="gpt-5.6" \
CODEX_EASY_API_KEY="test-key-default" \
CODEX_EASY_REASONING_EFFORT="" \
bash "$ROOT_DIR/install.sh" --non-interactive >/dev/null

assert_contains 'model_reasoning_effort = "low"' "$DEFAULT_TEST_CODEX_HOME/config.toml"

assert_supported_reasoning_effort() {
  local effort=$1
  HOME="$TEST_HOME" \
  CODEX_HOME="$TEST_CODEX_HOME" \
  CODEX_EASY_BASE_URL="https://relay.example.test/v1" \
  CODEX_EASY_PROVIDER_NAME="Test Relay" \
  CODEX_EASY_MODEL="test-model-$effort" \
  CODEX_EASY_API_KEY="test-key-123" \
  CODEX_EASY_REASONING_EFFORT="$effort" \
  bash "$ROOT_DIR/install.sh" --non-interactive >/dev/null
  assert_contains "model_reasoning_effort = \"$effort\"" "$CONFIG_FILE"
}

for effort in none minimal low medium high xhigh max ultra relay-custom; do
  assert_supported_reasoning_effort "$effort"
done

assert_invalid_reasoning_effort() {
  local effort=$1
  local exit_code
  set +e
  HOME="$TEST_HOME" \
  CODEX_HOME="$TEST_CODEX_HOME" \
  CODEX_EASY_BASE_URL="https://relay.example.test/v1" \
  CODEX_EASY_PROVIDER_NAME="Test Relay" \
  CODEX_EASY_MODEL="test-model-invalid-$effort" \
  CODEX_EASY_API_KEY="test-key-123" \
  CODEX_EASY_REASONING_EFFORT="$effort" \
  bash "$ROOT_DIR/install.sh" --non-interactive >/dev/null 2>&1
  exit_code=$?
  set -e
  if [[ $exit_code -eq 0 ]]; then
    printf 'Unsupported reasoning effort was accepted: %s\n' "$effort" >&2
    exit 1
  fi
}

assert_invalid_reasoning_effort 'invalid effort'

set +e
HOME="$TEST_HOME" \
CODEX_HOME="$TEST_CODEX_HOME" \
CODEX_EASY_BASE_URL="http://relay.example.test/v1" \
CODEX_EASY_PROVIDER_NAME="Test Relay" \
CODEX_EASY_MODEL="test-model-insecure-url" \
CODEX_EASY_API_KEY="test-key-123" \
CODEX_EASY_REASONING_EFFORT="high" \
bash "$ROOT_DIR/install.sh" --non-interactive >/dev/null 2>&1
INSECURE_URL_EXIT=$?
set -e

if [[ $INSECURE_URL_EXIT -eq 0 ]]; then
  printf '%s\n' 'Insecure HTTP API URL was accepted.' >&2
  exit 1
fi

assert_contains 'model = "test-model-relay-custom"' "$CONFIG_FILE"
assert_contains 'model_reasoning_effort = "relay-custom"' "$CONFIG_FILE"

MARKER_TEST_HOME="$TEMP_DIR/marker-test-home"
MARKER_TEST_CODEX_HOME="$MARKER_TEST_HOME/.codex"
mkdir -p "$MARKER_TEST_HOME"
cat > "$MARKER_TEST_HOME/.bashrc" <<'EOF'
export BEFORE_MARKER=1
# >>> codex-easy-setup >>>
export MUST_NOT_BE_REMOVED=1
EOF

set +e
HOME="$MARKER_TEST_HOME" \
CODEX_HOME="$MARKER_TEST_CODEX_HOME" \
CODEX_EASY_BASE_URL="https://relay.example.test/v1" \
CODEX_EASY_PROVIDER_NAME="Test Relay" \
CODEX_EASY_MODEL="test-model-marker" \
CODEX_EASY_API_KEY="test-key-marker" \
CODEX_EASY_REASONING_EFFORT="medium" \
bash "$ROOT_DIR/install.sh" --non-interactive >/dev/null 2>&1
MARKER_EXIT=$?
set -e

if [[ $MARKER_EXIT -eq 0 ]]; then
  printf '%s\n' 'Malformed Shell startup marker was accepted.' >&2
  exit 1
fi

assert_contains 'export BEFORE_MARKER=1' "$MARKER_TEST_HOME/.bashrc"
assert_contains 'export MUST_NOT_BE_REMOVED=1' "$MARKER_TEST_HOME/.bashrc"
if [[ -e "$MARKER_TEST_HOME/.profile" ]]; then
  printf '%s\n' 'Shell startup files were partially modified after marker validation failed.' >&2
  exit 1
fi

FAKE_BIN="$TEMP_DIR/fake-bin"
FAKE_INSTALL_LOG="$TEMP_DIR/fake-codex-installs.log"
FULL_INSTALL_LOG="$TEMP_DIR/full-install.log"
mkdir -p "$FAKE_BIN"

cat > "$FAKE_BIN/uname" <<'EOF'
#!/usr/bin/env bash
case ${1:-} in
  -s) printf '%s\n' 'Linux' ;;
  -m) printf '%s\n' 'x86_64' ;;
  *) /usr/bin/uname "$@" ;;
esac
EOF
chmod 700 "$FAKE_BIN/uname"

cat > "$FAKE_BIN/curl" <<'EOF'
#!/usr/bin/env bash
output_file=${!#}
cat > "$output_file" <<'INSTALLER'
#!/bin/sh
set -eu
mkdir -p "$CODEX_INSTALL_DIR"
if [ -n "${CODEX_EASY_TEST_INSTALL_LOG:-}" ]; then
  printf '%s\n' 'installed' >> "$CODEX_EASY_TEST_INSTALL_LOG"
fi
cat > "$CODEX_INSTALL_DIR/codex" <<'CODEX'
#!/bin/sh
if [ "${1:-}" = "--version" ]; then
  printf '%s\n' 'codex test'
fi
CODEX
chmod 700 "$CODEX_INSTALL_DIR/codex"
INSTALLER
EOF
chmod 700 "$FAKE_BIN/curl"

if ! printf '%s\n' n y n 'https://relay.example.test/v1' 'Test Relay' 'test-model-launcher' 'test-key-launcher' y xhigh |
  HOME="$TEST_HOME" \
  CODEX_HOME="$TEST_CODEX_HOME" \
  CODEX_EASY_TEST_INSTALL_LOG="$FAKE_INSTALL_LOG" \
  PATH="$FAKE_BIN:$PATH" \
  bash "$ROOT_DIR/install.sh" >"$FULL_INSTALL_LOG" 2>&1; then
  cat "$FULL_INSTALL_LOG" >&2
  exit 1
fi

assert_contains 'model_reasoning_effort = "xhigh"' "$CONFIG_FILE"

HOME="$TEST_HOME" \
CODEX_HOME="$TEST_CODEX_HOME" \
CODEX_EASY_TEST_INSTALL_LOG="$FAKE_INSTALL_LOG" \
PATH="$FAKE_BIN:$TEST_HOME/.local/bin:$PATH" \
"$TEST_HOME/.local/bin/codex-setup" update >/dev/null

HOME="$TEST_HOME" \
CODEX_HOME="$TEST_CODEX_HOME" \
PATH="$FAKE_BIN:$TEST_HOME/.local/bin:$PATH" \
"$TEST_HOME/.local/bin/codex-setup" doctor >/dev/null

if [[ $(wc -l < "$FAKE_INSTALL_LOG") -ne 2 ]]; then
  printf '%s\n' 'codex-setup update did not invoke the installer exactly once.' >&2
  exit 1
fi

printf '%s\n' 'All Codex Easy Setup tests passed.'
