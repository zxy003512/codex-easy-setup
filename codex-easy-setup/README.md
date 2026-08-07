# Codex Easy Setup

面向不熟悉 Linux 命令的用户：一条命令安装最新版 OpenAI Codex CLI，并用中文逐项配置常用的 `~/.codex/config.toml` 设置。

它使用 OpenAI 官方的独立安装器，不需要你自行安装 Node.js、npm 或 sudo。

## 上传到 GitHub 后怎么安装

把本项目上传为 GitHub 仓库后，将下面的 `<你的 GitHub 用户名>` 和仓库名替换为实际值，在 Linux 服务器的 SSH 终端完整粘贴一行即可：

```bash
curl -fsSL https://raw.githubusercontent.com/<你的GitHub用户名>/codex-easy-setup/main/install.sh -o /tmp/codex-easy-setup.sh && bash /tmp/codex-easy-setup.sh && rm -f /tmp/codex-easy-setup.sh
```

请保持这种“先下载为文件、再运行”的写法，不要改成 `curl | bash`。安装完成后脚本需要把自身保存为后续的 `codex-setup` 管理命令。

不要在这条命令前加 `sudo`。本工具按当前登录账号写入配置和 API Key；只有你平时运行 `codex` 的那个账号才能正确读取它们。

脚本会依次询问：

- 是否授予完整服务器权限
- 是否让 Codex 执行命令时从不询问
- API 根地址，可填 OpenAI 兼容中转站地址
- 中转站名称、模型名称、API Key
- 接口是否兼容 Responses API
- 模型思考强度：`minimal`、`low`、`medium`、`high`、`xhigh`

首次完成后，新开一个 SSH 终端，直接输入 `codex` 即可使用。

也可以先克隆仓库再运行：

```bash
git clone https://github.com/<你的GitHub用户名>/codex-easy-setup.git && bash codex-easy-setup/install.sh
```

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

## 本地测试

不安装 Codex 的情况下，可在 Linux 或 WSL 中运行：

```bash
bash tests/run.sh
```

测试会在临时 HOME 目录中验证脚本语法、配置写入、备份和密钥文件权限。

仓库还带有 GitHub Actions 工作流；上传后每次推送都会在 Ubuntu 上自动运行同一套测试。
