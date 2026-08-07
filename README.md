# Codex Easy Setup

面向不熟悉 Linux 命令的用户：一条命令安装最新版 OpenAI Codex CLI，并用中文逐项配置常用的 `~/.codex/config.toml` 设置。

它使用 OpenAI 官方的独立安装器，不需要你自行安装 Node.js 或 npm。遇到全新系统缺少下载、校验或解压工具时，脚本会识别 `apt`、`dnf`、`yum`、`apk`、`zypper`、`pacman` 并自动补齐；仅在安装这些系统依赖时才会按需调用 `sudo`。

## GitHub 仓库文件位置

`install.sh` 必须位于 GitHub 仓库根目录，最终结构应当是：

```text
codex-easy-setup/
├── install.sh
├── README.md
├── LICENSE
├── tests/run.sh
└── .github/workflows/test.yml
```

如果 GitHub 仓库页面显示多了一层同名的 `codex-easy-setup/` 目录，根地址下载会找不到 `install.sh`。上传这次修改时，请把本地项目目录（也就是包含 `install.sh` 的那一层）**里面的文件和文件夹**上传到 GitHub 仓库根目录，不要把整个外层文件夹再套进去。确认根目录出现 `install.sh` 后，再删除旧的内层 `codex-easy-setup/` 目录即可。

在完成移动前，旧目录中的临时下载地址是 `https://raw.githubusercontent.com/zxy003512/codex-easy-setup/main/codex-easy-setup/install.sh`；移动完成后请使用下面的根目录地址。

## 新服务器上怎么安装

登录 Linux 服务器的 SSH 终端后，直接完整粘贴下面这一行：

```bash
(curl -fsSL https://raw.githubusercontent.com/zxy003512/codex-easy-setup/main/install.sh -o /tmp/codex-easy-setup.sh 2>/dev/null || curl -fsSL https://raw.githubusercontent.com/zxy003512/codex-easy-setup/main/codex-easy-setup/install.sh -o /tmp/codex-easy-setup.sh) && bash /tmp/codex-easy-setup.sh && rm -f /tmp/codex-easy-setup.sh
```

请保持这种“先下载为文件、再运行”的写法，不要改成 `curl | bash`。安装完成后脚本需要把自身保存为后续的 `codex-setup` 管理命令。

不要在这条命令前加 `sudo`。本工具按当前登录账号写入配置和 API Key；只有你平时运行 `codex` 的那个账号才能正确读取它们。若基础工具缺失，脚本会单独请求 `sudo` 密码来安装依赖；直接以 root 登录的服务器则不需要 sudo。

如果第一行提示 `curl: command not found`，先试这个同样的一键命令：

```bash
(wget -qO /tmp/codex-easy-setup.sh https://raw.githubusercontent.com/zxy003512/codex-easy-setup/main/install.sh || wget -qO /tmp/codex-easy-setup.sh https://raw.githubusercontent.com/zxy003512/codex-easy-setup/main/codex-easy-setup/install.sh) && bash /tmp/codex-easy-setup.sh && rm -f /tmp/codex-easy-setup.sh
```

极少数极简镜像既没有 `curl` 也没有 `wget` 时，复制下面整段即可。它只会先安装 `curl` 和证书，随后项目脚本会继续检查其余基础工具：

```bash
bash -c 'set -e; root_url="https://raw.githubusercontent.com/zxy003512/codex-easy-setup/main/install.sh"; nested_url="https://raw.githubusercontent.com/zxy003512/codex-easy-setup/main/codex-easy-setup/install.sh"; out=/tmp/codex-easy-setup.sh; as_root(){ if [ "$(id -u)" -eq 0 ]; then "$@"; elif command -v sudo >/dev/null 2>&1; then sudo "$@"; else printf "%s\n" "需要 root 或 sudo 权限来安装 curl。" >&2; exit 1; fi; }; download(){ curl -fsSL "$root_url" -o "$out" 2>/dev/null || curl -fsSL "$nested_url" -o "$out"; }; if command -v curl >/dev/null 2>&1; then download; elif command -v wget >/dev/null 2>&1; then wget -qO "$out" "$root_url" || wget -qO "$out" "$nested_url"; else if command -v apt-get >/dev/null 2>&1; then as_root apt-get update && as_root apt-get install -y curl ca-certificates; elif command -v dnf >/dev/null 2>&1; then as_root dnf install -y curl ca-certificates; elif command -v yum >/dev/null 2>&1; then as_root yum install -y curl ca-certificates; elif command -v apk >/dev/null 2>&1; then as_root apk add --no-cache curl ca-certificates; elif command -v zypper >/dev/null 2>&1; then as_root zypper --non-interactive install curl ca-certificates; elif command -v pacman >/dev/null 2>&1; then as_root pacman -S --noconfirm --needed curl ca-certificates; else printf "%s\n" "未识别系统包管理器，无法自动安装 curl。" >&2; exit 1; fi; download; fi; bash "$out"; rm -f "$out"'
```

服务器需要能访问 `raw.githubusercontent.com`、`chatgpt.com`、`releases.openai.com`；官方安装器在需要时也会回退访问 GitHub Releases。若服务商防火墙、地区网络或公司策略拦截这些地址，任何安装脚本都无法绕过，`codex-setup doctor` 会帮助确认本机安装状态。

支持常见 Linux x86_64 和 ARM64 云服务器。脚本需要 Bash，以及 `curl`/`wget` 或可识别的系统包管理器；常规 Ubuntu、Debian、CentOS/RHEL 系、Alpine、openSUSE、Arch 云镜像均在自动依赖补齐范围内。

## 租完服务器后的实际操作

如果云服务商让你选择系统，优先选 Ubuntu LTS。服务器不需要图形界面。

1. 在云服务商后台找到服务器的公网 IP、登录账号和密码或 SSH 密钥。
2. 在 Windows 打开 PowerShell，执行下面的命令。大多数服务商使用 `root`；如果后台写的是 `ubuntu`、`debian` 或其他账号名，就替换掉 `root`。

   ```powershell
   ssh root@你的服务器公网IP
   ```

   第一次连接看到主机指纹确认时输入 `yes`，随后输入服务器密码。密码输入时屏幕不会显示字符，这是正常的。
3. 登录成功后，复制上一节的安装命令并粘贴到 SSH 终端。脚本会开始中文提问；API Key 输入不会回显。
4. 配置完成后执行：

   ```bash
   source ~/.bashrc && codex
   ```

   此时直接用中文告诉 Codex 你要做什么即可。
5. 以后重新登录服务器后，直接输入 `codex`。想修改中转、模型、权限、思考强度或 API Key 时，只输入：

   ```bash
   codex-setup
   ```

脚本会依次询问：

- 是否授予完整服务器权限
- 是否让 Codex 执行命令时从不询问
- API 根地址，可填 OpenAI 兼容中转站地址
- 中转站名称、模型名称、API Key
- 接口是否兼容 Responses API
- 模型思考强度：`none`、`minimal`、`low`、`medium`、`high`、`xhigh`、`max`、`ultra`，也可填中转站明确要求的自定义值

API Key 通过隐藏输入读取，不会写进 GitHub 仓库或 `config.toml`。它会只保存在服务器的 `~/.codex/codex-easy-env.sh` 中，文件权限为 `600`。

> 当前 Codex CLI 已内置 `none`、`minimal`、`low`、`medium`、`high`、`xhigh`、`max`、`ultra` 等思考强度，且允许模型声明额外值。`xhigh`、`max`、`ultra` 或自定义值是否可用，仍取决于所选模型和中转站是否真正支持对应的 Responses API 参数。

首次完成后，新开一个 SSH 终端，直接输入 `codex` 即可使用。也可以在当前终端执行 `source ~/.bashrc && codex`。

## 以后修改配置

安装完成后只需运行：

```bash
codex-setup
```

它会显示菜单，可分别修改权限、接口与中转、模型与思考强度，或只替换 API Key。

常用命令：

```bash
codex-setup update
codex-setup doctor
```

`update` 会再次调用 OpenAI 官方安装器，将 Codex CLI 更新到最新版。`doctor` 只检查安装和文件权限，不会发送 API 请求或消耗额度。

## 会写入哪些文件

- `~/.codex/config.toml`：Codex 用户级配置。已有文件会先创建 `config.toml.backup.时间戳` 备份；无关设置会保留。
- `~/.codex/codex-easy-env.sh`：API Key，权限设为 `600`，不写入 TOML。
- `~/.local/bin/codex-setup`：后续配置菜单命令。
- `~/.local/share/codex-easy-setup/install.sh`：菜单实际运行的脚本副本。
- `~/.profile`、`~/.bashrc`，以及存在时的 `~/.zshrc`：只添加一个带明确边界标记的小区块，用来将 `~/.local/bin` 加入 PATH 并载入 API Key。

## 兼容性与限制

本项目配置的是带 Bearer API Key 的 OpenAI 兼容服务。你的 API 或中转站必须支持 Responses API，例如其根地址为 `https://example.com/v1`，Codex 能在其下请求 `/responses`。

当前 Codex 的自定义模型提供方只支持 `wire_api = "responses"`。如果中转站只支持 Chat Completions，本工具会停止配置，而不会写出一个无效的伪配置。

## 权限提醒

当你同时选择：

- `danger-full-access`（完整服务器权限）
- `approval_policy = "never"`（永不询问）

Codex 可以在该 Linux 账号权限范围内直接执行命令，包括删除文件、安装软件和修改系统配置。这适合你明确理解风险、且服务器只由自己管理的场景；脚本默认不会替你开启这两个高风险选项。

不要把 `~/.codex/codex-easy-env.sh` 上传到 GitHub，也不要把 API Key 粘贴到公开问题、日志或截图里。

## 依据的官方资料

- [Codex 官方安装器](https://chatgpt.com/codex/install.sh)
- [Codex 配置基础](https://learn.chatgpt.com/docs/config-file/config-basic)
- [自定义模型提供方](https://learn.chatgpt.com/docs/config-file/config-advanced#custom-model-providers)
- [审批与沙箱设置](https://learn.chatgpt.com/docs/agent-approvals-security#sandbox-and-approvals)
- [Codex 当前发布版的思考强度实现](https://github.com/openai/codex/blob/rust-v0.147.0/codex-rs/protocol/src/openai_models.rs)

## 本地测试

不安装 Codex 的情况下，可在 Linux 或 WSL 中运行：

```bash
bash tests/run.sh
```

测试会在临时 HOME 目录中验证脚本语法、配置写入、备份和密钥文件权限。

仓库还带有 GitHub Actions 工作流；上传后每次推送都会在 Ubuntu 上自动运行同一套测试。
