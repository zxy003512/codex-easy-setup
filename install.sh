#!/usr/bin/env bash
# Codex Easy Setup - install the current Codex CLI and manage a small, safe set
# of user-level Codex settings. See README.md for usage and limitations.

if [ -z "${BASH_VERSION:-}" ]; then
  printf '%s\n' 'This script requires Bash. Run: bash install.sh' >&2
  exit 1
fi

set -Eeuo pipefail
IFS=$'\n\t'
umask 077

readonly TOOL_NAME="Codex Easy Setup"
readonly TOOL_ID="codex-easy-setup"
readonly OFFICIAL_CODEX_INSTALL_URL="https://chatgpt.com/codex/install.sh"
readonly PROVIDER_ID="codex_easy"
readonly PROVIDER_ENV_KEY="CODEX_EASY_API_KEY"
readonly CODEX_HOME_DIR="${CODEX_HOME:-$HOME/.codex}"
readonly CONFIG_FILE="$CODEX_HOME_DIR/config.toml"
readonly SECRET_FILE="$CODEX_HOME_DIR/codex-easy-env.sh"
readonly BIN_DIR="$HOME/.local/bin"
readonly APP_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/$TOOL_ID"
readonly INSTALLED_SCRIPT="$APP_DIR/install.sh"
readonly LAUNCHER="$BIN_DIR/codex-setup"
readonly BLOCK_START="# >>> codex-easy-setup >>>"
readonly BLOCK_END="# <<< codex-easy-setup <<<"

CURRENT_MODEL=""
CURRENT_REASONING=""
CURRENT_PROVIDER_NAME=""
CURRENT_BASE_URL=""
CURRENT_SANDBOX=""
CURRENT_NETWORK=""
CURRENT_APPROVAL=""
CURRENT_API_KEY=""

CONFIG_MODEL=""
CONFIG_REASONING=""
CONFIG_PROVIDER_NAME=""
CONFIG_BASE_URL=""
CONFIG_SANDBOX=""
CONFIG_NETWORK=""
CONFIG_APPROVAL=""
CONFIG_API_KEY=""
WRITE_API_KEY=0
MANAGE_MODEL=0
MANAGE_PROVIDER=0
MANAGE_SECURITY=0

color_enabled=0
if [[ -t 1 && -z "${NO_COLOR:-}" ]]; then
  color_enabled=1
fi

paint() {
  local code=$1
  shift
  if [[ $color_enabled -eq 1 ]]; then
    printf '\033[%sm%s\033[0m\n' "$code" "$*" >&2
  else
    printf '%s\n' "$*" >&2
  fi
}

info() { paint "36" "[信息] $*"; }
success() { paint "32" "[完成] $*"; }
warn() { paint "33" "[注意] $*"; }
die() {
  paint "31" "[错误] $*"
  exit 1
}

on_error() {
  local exit_code=$?
  printf '%s\n' "[错误] 脚本在第 $1 行失败（退出码 $exit_code）。API Key 不会显示在日志中。" >&2
  exit "$exit_code"
}
trap 'on_error $LINENO' ERR

if [[ -n "${SUDO_USER:-}" ]]; then
  die "请不要用 sudo 运行本脚本。它会把 Codex 配置写到 root 家目录；请以实际使用 Codex 的账号直接运行。"
fi

require_command() {
  command -v "$1" >/dev/null 2>&1 || die "缺少命令：$1"
}

command_exists() {
  command -v "$1" >/dev/null 2>&1
}

run_privileged() {
  if [[ $(id -u) -eq 0 ]]; then
    "$@"
  elif command_exists sudo; then
    sudo "$@"
  else
    die "系统缺少安装依赖所需的权限。请使用有 sudo 权限的账号重新运行，不要在整条安装命令前加 sudo。"
  fi
}

missing_codex_install_prerequisites() {
  local command_name
  for command_name in mktemp tar awk grep sed find fold; do
    if ! command_exists "$command_name"; then
      return 0
    fi
  done

  if ! command_exists curl && ! command_exists wget; then
    return 0
  fi

  if ! command_exists sha256sum && ! command_exists shasum && ! command_exists openssl; then
    return 0
  fi

  return 1
}

install_base_packages() {
  if command_exists apt-get; then
    run_privileged apt-get update
    run_privileged apt-get install -y ca-certificates curl wget tar gawk coreutils findutils grep sed
  elif command_exists dnf; then
    run_privileged dnf install -y ca-certificates curl wget tar gawk coreutils findutils grep sed
  elif command_exists yum; then
    run_privileged yum install -y ca-certificates curl wget tar gawk coreutils findutils grep sed
  elif command_exists apk; then
    run_privileged apk add --no-cache ca-certificates curl wget tar gawk coreutils findutils grep sed
  elif command_exists zypper; then
    run_privileged zypper --non-interactive install ca-certificates curl wget tar gawk coreutils findutils grep sed
  elif command_exists pacman; then
    run_privileged pacman -S --noconfirm --needed ca-certificates curl wget tar gawk coreutils findutils grep sed
  else
    die "缺少 Codex 安装所需的基础工具，且未识别到 apt、dnf、yum、apk、zypper 或 pacman。请先安装 curl（或 wget）、tar、awk、grep、sed、find、fold 和 sha256sum。"
  fi
}

ensure_codex_install_prerequisites() {
  if ! missing_codex_install_prerequisites; then
    return 0
  fi

  warn "检测到新系统缺少 Codex 安装所需的基础工具，正在通过系统包管理器补齐。"
  install_base_packages

  if missing_codex_install_prerequisites; then
    die "依赖安装后仍缺少必要工具，无法继续安装 Codex。"
  fi
}

ensure_linux_platform() {
  require_command uname
  local os
  local arch
  os=$(uname -s)
  arch=$(uname -m)
  [[ $os == "Linux" ]] || die "本项目面向 Linux 服务器；当前系统是 $os。"
  case $arch in
    x86_64|amd64|aarch64|arm64) ;;
    *) die "官方 Codex 安装器不支持当前 CPU 架构：$arch" ;;
  esac
}

ensure_directories() {
  mkdir -p "$CODEX_HOME_DIR" "$BIN_DIR" "$APP_DIR"
  chmod 700 "$CODEX_HOME_DIR" "$APP_DIR" 2>/dev/null || true
}

download_to_stdout() {
  local url=$1
  if command -v curl >/dev/null 2>&1; then
    curl -fsSL "$url"
  elif command -v wget >/dev/null 2>&1; then
    wget -qO- "$url"
  else
    die "需要 curl 或 wget 才能下载官方 Codex 安装器。"
  fi
}

install_latest_codex() {
  ensure_linux_platform
  ensure_codex_install_prerequisites
  ensure_directories
  info "正在从 OpenAI 官方安装器安装或更新最新版 Codex CLI..."
  download_to_stdout "$OFFICIAL_CODEX_INSTALL_URL" | CODEX_NON_INTERACTIVE=1 CODEX_INSTALL_DIR="$BIN_DIR" sh
  export PATH="$BIN_DIR:$PATH"
  command -v codex >/dev/null 2>&1 || die "官方安装器已结束，但找不到 codex 命令。"
  success "Codex CLI 已就绪：$(codex --version 2>/dev/null || printf '已安装')"
}

strip_managed_block() {
  local file=$1
  local temp
  touch "$file"
  temp=$(mktemp "${file}.XXXXXX")
  awk -v start="$BLOCK_START" -v end="$BLOCK_END" '
    $0 == start { inside = 1; next }
    $0 == end { inside = 0; next }
    !inside { print }
  ' "$file" > "$temp"
  {
    printf '\n%s\n' "$BLOCK_START"
    printf '%s\n' "case \":\$PATH:\" in"
    printf '%s\n' "  *\":\$HOME/.local/bin:\"*) ;;"
    printf '%s\n' "  *) export PATH=\"\$HOME/.local/bin:\$PATH\" ;;"
    printf '%s\n' 'esac'
    if [[ "$CODEX_HOME_DIR" != "$HOME/.codex" ]]; then
      printf 'export CODEX_HOME=%q\n' "$CODEX_HOME_DIR"
    fi
    printf 'if [ -r %q ]; then\n' "$SECRET_FILE"
    printf '  . %q\n' "$SECRET_FILE"
    printf '%s\n' 'fi'
    printf '%s\n' "$BLOCK_END"
  } >> "$temp"
  mv "$temp" "$file"
}

install_shell_startup() {
  strip_managed_block "$HOME/.profile"
  strip_managed_block "$HOME/.bashrc"
  if [[ -f "$HOME/.zshrc" ]]; then
    strip_managed_block "$HOME/.zshrc"
  fi
}

install_manager_command() {
  local source_file=${BASH_SOURCE[0]}
  [[ -f "$source_file" && -r "$source_file" ]] || die "请先将 install.sh 下载为文件，再运行它；不要用 curl | bash。"
  ensure_directories
  cp "$source_file" "$INSTALLED_SCRIPT"
  chmod 700 "$INSTALLED_SCRIPT"
  {
    printf '%s\n' '#!/usr/bin/env bash'
    printf '%s\n' 'set -Eeuo pipefail'
    printf 'manager_script=%q\n' "$INSTALLED_SCRIPT"
    printf '%s\n' "case \"\${1:-}\" in"
    printf '%s\n' "  \"\"|menu|--menu) exec \"\$manager_script\" --menu ;;"
    printf '%s\n' "  update|--update) exec \"\$manager_script\" update ;;"
    printf '%s\n' "  doctor|--doctor) exec \"\$manager_script\" doctor ;;"
    printf '%s\n' "  help|-h|--help) exec \"\$manager_script\" --help ;;"
    printf '%s\n' "  *) exec \"\$manager_script\" --menu ;;"
    printf '%s\n' 'esac'
  } > "$LAUNCHER"
  chmod 700 "$LAUNCHER"
  install_shell_startup
}

is_single_line() {
  [[ $1 != *$'\n'* && $1 != *$'\r'* ]]
}

is_valid_reasoning_effort() {
  [[ $1 =~ ^[A-Za-z0-9][A-Za-z0-9._-]*$ ]]
}

toml_quote() {
  local value=$1
  value=${value//\\/\\\\}
  value=${value//\"/\\\"}
  value=${value//$'\n'/}
  value=${value//$'\r'/}
  printf '"%s"' "$value"
}

write_secret_file() {
  local api_key=$1
  local temp
  is_single_line "$api_key" || die "API Key 不能包含换行符。"
  [[ ! $api_key =~ [[:cntrl:]] ]] || die "API Key 不能包含控制字符。"
  ensure_directories
  temp=$(mktemp "$CODEX_HOME_DIR/.codex-easy-env.XXXXXX")
  {
    printf '%s\n' '# Managed by Codex Easy Setup. Keep this file private.'
    printf 'export %s=%q\n' "$PROVIDER_ENV_KEY" "$api_key"
  } > "$temp"
  chmod 600 "$temp"
  mv "$temp" "$SECRET_FILE"
  chmod 600 "$SECRET_FILE"
  # shellcheck disable=SC1090
  source "$SECRET_FILE"
}

load_secret() {
  CURRENT_API_KEY=""
  if [[ -r "$SECRET_FILE" ]]; then
    # shellcheck disable=SC1090
    source "$SECRET_FILE"
    CURRENT_API_KEY=${!PROVIDER_ENV_KEY:-}
  fi
}

extract_root_value() {
  local key=$1
  [[ -f "$CONFIG_FILE" ]] || return 0
  awk -v key="$key" '
    /^[[:space:]]*\[/ { exit }
    $0 ~ "^[[:space:]]*" key "[[:space:]]*=" {
      value = $0
      sub(/^[^=]*=[[:space:]]*/, "", value)
      sub(/[[:space:]]*(#.*)?$/, "", value)
      sub(/^"/, "", value)
      sub(/"$/, "", value)
      print value
      exit
    }
  ' "$CONFIG_FILE"
}

extract_table_value() {
  local table=$1
  local key=$2
  [[ -f "$CONFIG_FILE" ]] || return 0
  awk -v wanted="[$table]" -v key="$key" '
    function trim(value) {
      sub(/^[[:space:]]+/, "", value)
      sub(/[[:space:]]+$/, "", value)
      return value
    }
    {
      line = $0
      header = trim(line)
      sub(/[[:space:]]*#.*/, "", header)
      header = trim(header)
      if (header ~ /^\[/) {
        if (inside) exit
        if (header == wanted) {
          inside = 1
          next
        }
      }
      if (inside && line ~ "^[[:space:]]*" key "[[:space:]]*=") {
        value = line
        sub(/^[^=]*=[[:space:]]*/, "", value)
        sub(/[[:space:]]*(#.*)?$/, "", value)
        sub(/^"/, "", value)
        sub(/"$/, "", value)
        print value
        exit
      }
    }
  ' "$CONFIG_FILE"
}

load_current_settings() {
  load_secret
  CURRENT_MODEL=$(extract_root_value "model")
  CURRENT_REASONING=$(extract_root_value "model_reasoning_effort")
  CURRENT_SANDBOX=$(extract_root_value "sandbox_mode")
  CURRENT_APPROVAL=$(extract_root_value "approval_policy")
  CURRENT_NETWORK=$(extract_table_value "sandbox_workspace_write" "network_access")
  CURRENT_PROVIDER_NAME=$(extract_table_value "model_providers.$PROVIDER_ID" "name")
  CURRENT_BASE_URL=$(extract_table_value "model_providers.$PROVIDER_ID" "base_url")

  : "${CURRENT_MODEL:=gpt-5.6}"
  : "${CURRENT_REASONING:=medium}"
  : "${CURRENT_SANDBOX:=workspace-write}"
  : "${CURRENT_APPROVAL:=on-request}"
  : "${CURRENT_NETWORK:=true}"
  : "${CURRENT_PROVIDER_NAME:=我的 OpenAI 兼容中转站}"
  : "${CURRENT_BASE_URL:=https://api.openai.com/v1}"
}

ask_text() {
  local variable=$1
  local prompt=$2
  local default_value=$3
  local answer
  while true; do
    if [[ -n "$default_value" ]]; then
      printf '%s [%s]: ' "$prompt" "$default_value" >&2
    else
      printf '%s: ' "$prompt" >&2
    fi
    IFS= read -r answer
    answer=${answer:-$default_value}
    if is_single_line "$answer"; then
      printf -v "$variable" '%s' "$answer"
      return 0
    fi
    warn "请输入单行内容。"
  done
}

ask_secret() {
  local variable=$1
  local prompt=$2
  local input_value
  printf '%s: ' "$prompt" >&2
  IFS= read -r -s input_value
  printf '\n' >&2
  is_single_line "$input_value" || die "API Key 不能包含换行符。"
  printf -v "$variable" '%s' "$input_value"
}

ask_yes_no() {
  local prompt=$1
  local default_value=$2
  local answer
  while true; do
    if [[ $default_value == "y" ]]; then
      printf '%s [Y/n]: ' "$prompt" >&2
    else
      printf '%s [y/N]: ' "$prompt" >&2
    fi
    IFS= read -r answer
    answer=${answer:-$default_value}
    case ${answer,,} in
      y|yes|1|是) return 0 ;;
      n|no|0|否) return 1 ;;
      *) warn "请输入 y 或 n。" ;;
    esac
  done
}

ask_reasoning() {
  local default_value=$1
  local answer
  while true; do
    printf '模型思考强度 none / minimal / low / medium / high / xhigh / max / ultra（也可输入中转站自定义值）[%s]: ' "$default_value" >&2
    IFS= read -r answer
    answer=${answer:-$default_value}
    if is_valid_reasoning_effort "$answer"; then
      CONFIG_REASONING=$answer
      return 0
    fi
    warn "请输入 none、minimal、low、medium、high、xhigh、max、ultra，或中转站给出的不含空格的自定义值。"
  done
}

normalize_base_url() {
  local value=$1
  while [[ $value == */ ]]; do
    value=${value%/}
  done
  printf '%s' "$value"
}

is_valid_base_url() {
  [[ $1 =~ ^https?://[^[:space:]]+$ ]]
}

prompt_security() {
  if ask_yes_no "是否授予 Codex 全部服务器权限？这会关闭沙箱，风险较高" "n"; then
    CONFIG_SANDBOX="danger-full-access"
    CONFIG_NETWORK="true"
  else
    CONFIG_SANDBOX="workspace-write"
    if ask_yes_no "在工作目录隔离模式下允许网络访问？" "y"; then
      CONFIG_NETWORK="true"
    else
      CONFIG_NETWORK="false"
    fi
  fi

  if ask_yes_no "是否让 Codex 执行命令时从不询问？这会允许命令直接执行" "n"; then
    CONFIG_APPROVAL="never"
  else
    CONFIG_APPROVAL="on-request"
  fi
}

prompt_provider_and_model() {
  local answer
  while true; do
    ask_text CONFIG_BASE_URL "API 地址（填 API 根地址，例如 https://example.com/v1，不要填 /responses）" "$CURRENT_BASE_URL"
    CONFIG_BASE_URL=$(normalize_base_url "$CONFIG_BASE_URL")
    if is_valid_base_url "$CONFIG_BASE_URL"; then
      break
    fi
    warn "地址必须以 http:// 或 https:// 开头，且不能包含空格。"
  done

  ask_text CONFIG_PROVIDER_NAME "中转站名称（只用于 Codex 设置展示）" "$CURRENT_PROVIDER_NAME"
  [[ -n "$CONFIG_PROVIDER_NAME" ]] || die "中转站名称不能为空。"

  ask_text CONFIG_MODEL "模型名称" "$CURRENT_MODEL"
  [[ -n "$CONFIG_MODEL" ]] || die "模型名称不能为空。"

  if [[ -n "$CURRENT_API_KEY" ]]; then
    ask_secret answer "API Key（直接回车保留已保存的密钥，输入不回显）"
    if [[ -n "$answer" ]]; then
      CONFIG_API_KEY=$answer
      WRITE_API_KEY=1
    else
      CONFIG_API_KEY=$CURRENT_API_KEY
      WRITE_API_KEY=0
    fi
  else
    ask_secret CONFIG_API_KEY "API Key（输入不回显）"
    [[ -n "$CONFIG_API_KEY" ]] || die "首次配置必须提供 API Key。"
    WRITE_API_KEY=1
  fi

  while true; do
    if ask_yes_no "请求格式是 Responses API 吗？Codex 当前只支持 Responses" "y"; then
      break
    fi
    warn "无法写入 Chat Completions 配置。请使用支持 /v1/responses 的 API 或中转站。"
    if ask_yes_no "是否取消本次接口配置并返回菜单？" "y"; then
      return 1
    fi
  done

  ask_reasoning "$CURRENT_REASONING"
}

filter_existing_config() {
  local root_output=$1
  local tables_output=$2
  [[ -f "$CONFIG_FILE" ]] || return 0
  awk \
    -v root_output="$root_output" \
    -v tables_output="$tables_output" \
    -v manage_model="$MANAGE_MODEL" \
    -v manage_provider="$MANAGE_PROVIDER" \
    -v manage_security="$MANAGE_SECURITY" '
      function trim(value) {
        sub(/^[[:space:]]+/, "", value)
        sub(/[[:space:]]+$/, "", value)
        return value
      }
      {
        original = $0
        header = trim(original)
        sub(/[[:space:]]*#.*/, "", header)
        header = trim(header)
        if (header ~ /^\[/) {
          section = header
          skip_section = 0
          if (manage_security && (section == "[sandbox_workspace_write]" || section ~ /^\[sandbox_workspace_write\./)) {
            skip_section = 1
          }
          if (manage_provider && (section == "[model_providers.codex_easy]" || section ~ /^\[model_providers\.codex_easy\./)) {
            skip_section = 1
          }
        }
        if (skip_section) next
        if (section == "") {
          clean = header
          if (manage_model && (clean ~ /^model[[:space:]]*=/ || clean ~ /^model_reasoning_effort[[:space:]]*=/)) next
          if (manage_provider && clean ~ /^model_provider[[:space:]]*=/) next
          if (manage_security && (clean ~ /^approval_policy[[:space:]]*=/ || clean ~ /^sandbox_mode[[:space:]]*=/ || clean ~ /^default_permissions[[:space:]]*=/)) next
          print original >> root_output
        } else {
          print original >> tables_output
        }
      }
    ' "$CONFIG_FILE"
}

backup_config() {
  [[ -f "$CONFIG_FILE" ]] || return 0
  local stamp
  local backup
  stamp=$(date +%Y%m%d-%H%M%S)
  backup="$CONFIG_FILE.backup.$stamp"
  while [[ -e "$backup" ]]; do
    backup="$CONFIG_FILE.backup.$stamp.$RANDOM"
  done
  cp -p "$CONFIG_FILE" "$backup"
  info "已备份现有配置：$backup"
}

write_config() {
  local root_remaining
  local tables_remaining
  local temp
  ensure_directories
  root_remaining=$(mktemp "$CODEX_HOME_DIR/.codex-easy-root.XXXXXX")
  tables_remaining=$(mktemp "$CODEX_HOME_DIR/.codex-easy-tables.XXXXXX")
  temp=$(mktemp "$CODEX_HOME_DIR/.codex-easy-config.XXXXXX")
  filter_existing_config "$root_remaining" "$tables_remaining"
  backup_config

  {
    printf '%s\n' '# Managed entries below are maintained by Codex Easy Setup.'
    if [[ $MANAGE_MODEL -eq 1 ]]; then
      printf 'model = %s\n' "$(toml_quote "$CONFIG_MODEL")"
      printf 'model_reasoning_effort = %s\n' "$(toml_quote "$CONFIG_REASONING")"
    fi
    if [[ $MANAGE_PROVIDER -eq 1 ]]; then
      printf 'model_provider = %s\n' "$(toml_quote "$PROVIDER_ID")"
    fi
    if [[ $MANAGE_SECURITY -eq 1 ]]; then
      printf 'approval_policy = %s\n' "$(toml_quote "$CONFIG_APPROVAL")"
      printf 'sandbox_mode = %s\n' "$(toml_quote "$CONFIG_SANDBOX")"
    fi
    if [[ -s "$root_remaining" ]]; then
      printf '\n'
      cat "$root_remaining"
    fi
    if [[ -s "$tables_remaining" ]]; then
      printf '\n'
      cat "$tables_remaining"
    fi
    if [[ $MANAGE_SECURITY -eq 1 && $CONFIG_SANDBOX == "workspace-write" ]]; then
      printf '\n[sandbox_workspace_write]\n'
      printf 'network_access = %s\n' "$CONFIG_NETWORK"
    fi
    if [[ $MANAGE_PROVIDER -eq 1 ]]; then
      printf '\n[model_providers.%s]\n' "$PROVIDER_ID"
      printf 'name = %s\n' "$(toml_quote "$CONFIG_PROVIDER_NAME")"
      printf 'base_url = %s\n' "$(toml_quote "$CONFIG_BASE_URL")"
      printf 'env_key = %s\n' "$(toml_quote "$PROVIDER_ENV_KEY")"
      printf 'wire_api = "responses"\n'
    fi
  } > "$temp"

  chmod 600 "$temp"
  mv "$temp" "$CONFIG_FILE"
  rm -f "$root_remaining" "$tables_remaining"
  success "Codex 配置已写入：$CONFIG_FILE"
}

finish_configuration() {
  install_shell_startup
  success "设置完成。新开一个 SSH 终端后可直接运行：codex"
  printf '%s\n' '以后修改设置：codex-setup' >&2
  printf '%s\n' '密钥已单独保存，不会显示在这里。' >&2
}

configure_all_interactive() {
  load_current_settings
  MANAGE_MODEL=1
  MANAGE_PROVIDER=1
  MANAGE_SECURITY=1
  WRITE_API_KEY=0
  info "将依次配置权限、命令确认、API 地址、中转名称、模型、API Key、Responses 和思考强度。"
  prompt_security
  if ! prompt_provider_and_model; then
    warn "本次配置未保存。"
    return 0
  fi
  if [[ $WRITE_API_KEY -eq 1 ]]; then
    write_secret_file "$CONFIG_API_KEY"
  fi
  write_config
  finish_configuration
}

configure_security_interactive() {
  load_current_settings
  MANAGE_MODEL=0
  MANAGE_PROVIDER=0
  MANAGE_SECURITY=1
  prompt_security
  write_config
  finish_configuration
}

configure_provider_interactive() {
  load_current_settings
  MANAGE_MODEL=1
  MANAGE_PROVIDER=1
  MANAGE_SECURITY=0
  WRITE_API_KEY=0
  if ! prompt_provider_and_model; then
    warn "本次配置未保存。"
    return 0
  fi
  if [[ $WRITE_API_KEY -eq 1 ]]; then
    write_secret_file "$CONFIG_API_KEY"
  fi
  write_config
  finish_configuration
}

configure_model_interactive() {
  load_current_settings
  MANAGE_MODEL=1
  MANAGE_PROVIDER=0
  MANAGE_SECURITY=0
  ask_text CONFIG_MODEL "模型名称" "$CURRENT_MODEL"
  [[ -n "$CONFIG_MODEL" ]] || die "模型名称不能为空。"
  ask_reasoning "$CURRENT_REASONING"
  write_config
  finish_configuration
}

replace_api_key_interactive() {
  local new_key
  load_secret
  ask_secret new_key "新的 API Key（输入不回显）"
  [[ -n "$new_key" ]] || die "API Key 不能为空。"
  write_secret_file "$new_key"
  success "API Key 已更新。"
}

show_status() {
  load_current_settings
  printf '\n%s\n' '--- Codex Easy Setup 状态 ---' >&2
  printf '配置文件：%s\n' "$CONFIG_FILE" >&2
  printf '模型：%s\n' "$CURRENT_MODEL" >&2
  printf '思考强度：%s\n' "$CURRENT_REASONING" >&2
  printf '中转地址：%s\n' "$CURRENT_BASE_URL" >&2
  printf '中转名称：%s\n' "$CURRENT_PROVIDER_NAME" >&2
  printf '沙箱：%s\n' "$CURRENT_SANDBOX" >&2
  printf '命令确认：%s\n' "$CURRENT_APPROVAL" >&2
  if [[ -n "$CURRENT_API_KEY" ]]; then
    printf '%s\n' 'API Key：已保存（不显示）' >&2
  else
    printf '%s\n' 'API Key：未发现由本工具保存的密钥' >&2
  fi
  if command -v codex >/dev/null 2>&1; then
    printf 'Codex：%s\n' "$(codex --version 2>/dev/null || printf '已安装')" >&2
  else
    printf '%s\n' 'Codex：未在当前 PATH 中找到；请重新登录 SSH 后再试。' >&2
  fi
  printf '%s\n\n' '------------------------------' >&2
}

doctor() {
  local failed=0
  info "检查本地安装和配置..."
  if missing_codex_install_prerequisites; then
    warn "更新 Codex 所需的基础工具不完整；重新运行 install.sh 会尝试自动补齐。"
    failed=1
  else
    success "Codex 安装所需的基础工具齐全。"
  fi
  if [[ -x "$LAUNCHER" ]]; then
    success "管理命令存在：$LAUNCHER"
  else
    warn "未找到管理命令。请重新运行项目中的 install.sh。"
    failed=1
  fi
  if [[ -f "$CONFIG_FILE" ]]; then
    success "配置文件存在：$CONFIG_FILE"
  else
    warn "未找到 config.toml。"
    failed=1
  fi
  if [[ -f "$SECRET_FILE" ]]; then
    if command -v stat >/dev/null 2>&1 && [[ $(stat -c '%a' "$SECRET_FILE" 2>/dev/null || printf '000') == "600" ]]; then
      success "API Key 文件权限为 600。"
    else
      warn "无法确认 API Key 文件权限；建议执行 codex-setup 后重新保存密钥。"
    fi
  else
    warn "未找到 API Key 文件。"
    failed=1
  fi
  if command -v codex >/dev/null 2>&1; then
    success "Codex CLI 可执行：$(codex --version 2>/dev/null || printf '已安装')"
  else
    warn "当前 shell 找不到 codex；请重新登录 SSH，或运行 source ~/.bashrc。"
    failed=1
  fi
  if [[ $failed -eq 0 ]]; then
    success "基础检查通过。该检查不会向 API 发送请求，也不会消耗额度。"
  else
    warn "发现上述问题。"
  fi
}

configure_noninteractive() {
  : "${CODEX_EASY_BASE_URL:?CODEX_EASY_BASE_URL is required}"
  : "${CODEX_EASY_PROVIDER_NAME:?CODEX_EASY_PROVIDER_NAME is required}"
  : "${CODEX_EASY_MODEL:?CODEX_EASY_MODEL is required}"
  : "${CODEX_EASY_API_KEY:?CODEX_EASY_API_KEY is required}"
  : "${CODEX_EASY_REASONING_EFFORT:=medium}"
  : "${CODEX_EASY_SANDBOX_MODE:=workspace-write}"
  : "${CODEX_EASY_APPROVAL_POLICY:=on-request}"
  : "${CODEX_EASY_NETWORK_ACCESS:=true}"
  : "${CODEX_EASY_RESPONSES_API:=yes}"

  is_valid_base_url "$CODEX_EASY_BASE_URL" || die "CODEX_EASY_BASE_URL 必须是 http(s) 地址。"
  is_single_line "$CODEX_EASY_PROVIDER_NAME" || die "CODEX_EASY_PROVIDER_NAME 不能包含换行符。"
  is_single_line "$CODEX_EASY_MODEL" || die "CODEX_EASY_MODEL 不能包含换行符。"
  is_valid_reasoning_effort "$CODEX_EASY_REASONING_EFFORT" || die "无效的 CODEX_EASY_REASONING_EFFORT。"
  case $CODEX_EASY_SANDBOX_MODE in read-only|workspace-write|danger-full-access) ;; *) die "无效的 CODEX_EASY_SANDBOX_MODE。" ;; esac
  case $CODEX_EASY_APPROVAL_POLICY in untrusted|on-request|never) ;; *) die "无效的 CODEX_EASY_APPROVAL_POLICY。" ;; esac
  case $CODEX_EASY_NETWORK_ACCESS in true|false) ;; *) die "CODEX_EASY_NETWORK_ACCESS 必须是 true 或 false。" ;; esac
  case ${CODEX_EASY_RESPONSES_API,,} in y|yes|true|1) ;; *) die "Codex 只支持 Responses API。" ;; esac

  load_current_settings
  MANAGE_MODEL=1
  MANAGE_PROVIDER=1
  MANAGE_SECURITY=1
  CONFIG_BASE_URL=$(normalize_base_url "$CODEX_EASY_BASE_URL")
  CONFIG_PROVIDER_NAME=$CODEX_EASY_PROVIDER_NAME
  CONFIG_MODEL=$CODEX_EASY_MODEL
  CONFIG_API_KEY=$CODEX_EASY_API_KEY
  CONFIG_REASONING=$CODEX_EASY_REASONING_EFFORT
  CONFIG_SANDBOX=$CODEX_EASY_SANDBOX_MODE
  CONFIG_APPROVAL=$CODEX_EASY_APPROVAL_POLICY
  CONFIG_NETWORK=$CODEX_EASY_NETWORK_ACCESS
  WRITE_API_KEY=1
  write_secret_file "$CONFIG_API_KEY"
  write_config
  install_shell_startup
}

show_help() {
  cat >&2 <<'EOF'
用法：
  bash install.sh                 安装或更新 Codex，然后启动完整交互配置
  codex-setup                     打开修改菜单
  codex-setup update              从 OpenAI 官方安装器更新 Codex CLI
  codex-setup doctor              检查本地安装和配置，不发送 API 请求
  bash install.sh --non-interactive
                                  供自动化和测试使用，需要 CODEX_EASY_* 环境变量
EOF
}

main_menu() {
  while true; do
    printf '\n%s\n' "=== $TOOL_NAME ===" >&2
    printf '%s\n' '1) 重新运行完整配置向导' >&2
    printf '%s\n' '2) 只修改权限和命令确认' >&2
    printf '%s\n' '3) 修改 API 地址、中转名称、模型、密钥和思考强度' >&2
    printf '%s\n' '4) 只修改模型和思考强度' >&2
    printf '%s\n' '5) 只更换 API Key' >&2
    printf '%s\n' '6) 更新到最新版 Codex CLI' >&2
    printf '%s\n' '7) 查看当前设置' >&2
    printf '%s\n' '8) 运行基础检查' >&2
    printf '%s\n' '0) 退出' >&2
    printf '请选择: ' >&2
    local choice
    IFS= read -r choice
    case $choice in
      1) configure_all_interactive ;;
      2) configure_security_interactive ;;
      3) configure_provider_interactive ;;
      4) configure_model_interactive ;;
      5) replace_api_key_interactive ;;
      6) install_latest_codex ;;
      7) show_status ;;
      8) doctor ;;
      0|'') return 0 ;;
      *) warn "请输入 0 到 8。" ;;
    esac
  done
}

main() {
  case ${1:-install} in
    install)
      install_latest_codex
      install_manager_command
      configure_all_interactive
      ;;
    --menu|menu)
      main_menu
      ;;
    update|--update)
      install_latest_codex
      ;;
    doctor|--doctor)
      doctor
      ;;
    --non-interactive)
      configure_noninteractive
      ;;
    -h|--help|help)
      show_help
      ;;
    *)
      die "未知参数：$1。运行 bash install.sh --help 查看用法。"
      ;;
  esac
}

main "$@"
