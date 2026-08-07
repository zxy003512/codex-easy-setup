# Codex Easy Setup

给不熟悉 Linux 命令的用户准备的一键配置工具。

它会安装最新版 OpenAI Codex CLI，并用中文逐项询问常用设置：服务器权限、命令确认、API 地址、中转站名称、模型、API Key 和思考强度。以后只需运行一个命令，就能再次打开设置菜单。

不需要自行安装 Node.js 或 npm。推荐在新建的 Ubuntu LTS 云服务器上使用。

## 当前 OpenAI 模型建议

默认模型名是 `gpt-5.6`。它是当前官方旗舰模型 `gpt-5.6-sol` 的别名；如果你的中转站不支持这个别名，请按中转站提供的模型列表填写。

| 模型 | 适合场景 | 默认思考强度 | 当前可选思考强度 |
| --- | --- | --- | --- |
| `gpt-5.6` / `gpt-5.6-sol` | 最复杂的编程、研究和高要求任务 | `low` | `low`、`medium`、`high`、`xhigh`、`max`、`ultra` |
| `gpt-5.6-terra` | 日常开发和通用任务 | `medium` | `low`、`medium`、`high`、`xhigh`、`max`、`ultra` |
| `gpt-5.6-luna` | 明确、重复、追求速度或成本的任务 | `medium` | `low`、`medium`、`high`、`xhigh`、`max` |

模型目录会随 Codex 版本、账户权限和中转站而变化。脚本会给 OpenAI 已知模型显示对应提示；使用其他模型时，按服务商写明的模型名和思考强度填写即可。

## 第一次安装

1. 在云服务商后台获取服务器公网 IP、登录账号和密码或 SSH 密钥。
2. 在 Windows PowerShell 中连接服务器。账号不一定是 `root`，请以云服务商后台显示的账号为准。

   ```powershell
   ssh root@你的服务器公网IP
   ```

3. 登录后，完整粘贴这一行并回车：

   ```bash
   ( tmp="$(mktemp)" && trap 'rm -f "$tmp"' EXIT && curl -fsSL https://raw.githubusercontent.com/zxy003512/codex-easy-setup/main/install.sh -o "$tmp" && bash "$tmp" )
   ```

   这条命令会先安全地下载脚本到私有临时文件，再运行它；不要在前面加 `sudo`。

4. 如果服务器没有 `curl`，使用这一行：

   ```bash
   ( tmp="$(mktemp)" && trap 'rm -f "$tmp"' EXIT && wget -qO "$tmp" https://raw.githubusercontent.com/zxy003512/codex-easy-setup/main/install.sh && bash "$tmp" )
   ```

首次运行会自动补齐 Codex 官方安装器所需的基础工具。极简系统若同时没有 `curl` 和 `wget`，建议改用 Ubuntu LTS 镜像后重新执行，步骤最少也最稳定。

配置完成后执行：

```bash
source ~/.bashrc && codex
```

以后新开 SSH 终端时，直接输入 `codex` 即可。

## 安装时会问什么

- 是否授予 Codex 完整服务器权限。默认不授予。
- 是否让 Codex 执行命令时从不询问。默认仍会询问。
- API 根地址。必须是 `https://` 地址，例如 `https://example.com/v1`。
- 中转站名称、模型名称和 API Key。
- 中转站是否明确支持 Responses API，也就是 `/v1/responses`。
- 模型思考强度。脚本识别 `none`、`minimal`、`low`、`medium`、`high`、`xhigh`、`max`、`ultra`，也接受中转站明确提供的不含空格的自定义值。

Codex 的自定义模型提供方目前只支持 Responses API。如果中转站只支持 Chat Completions，脚本会停止配置，不会写入一个看似成功但实际不可用的设置。

不要把“脚本能写入”理解为“每个模型都支持”。例如当前 `gpt-5.6-sol` 和 `gpt-5.6-terra` 支持 `max`、`ultra`，`gpt-5.6-luna` 支持到 `max`；较早模型和第三方中转站可用范围可能更小。

## 以后修改设置

```bash
codex-setup
```

菜单可以分别修改权限、API 地址、中转站、模型、思考强度和 API Key。

常用命令：

```bash
codex-setup update
codex-setup doctor
```

`update` 会使用 OpenAI 官方安装器更新 Codex CLI。`doctor` 只检查本地安装、配置和文件权限，不会发送 API 请求或消耗额度。

## 安全提示

- 不要在安装命令前加 `sudo`。脚本会把配置写入当前登录用户的家目录；只有这个用户能正常使用它。
- API Key 不会写进 `config.toml`，而是单独保存在 `~/.codex/codex-easy-env.sh`，权限为 `600`。
- 只填写你信任的 API 服务或中转站。该服务会收到 API Key，以及 Codex 发送给它的代码和请求内容。
- `danger-full-access` 加 `approval_policy = "never"` 会允许 Codex 在当前 Linux 账号权限范围内直接执行高风险命令。除非服务器只由你管理且你理解后果，否则保持默认选项。

## 会写入哪些文件

- `~/.codex/config.toml`：Codex 用户配置。已有文件会先创建时间戳备份，无关设置会保留。
- `~/.codex/codex-easy-env.sh`：API Key，权限为 `600`。
- `~/.local/bin/codex-setup`：后续设置菜单命令。
- `~/.local/share/codex-easy-setup/install.sh`：菜单实际运行的脚本副本。
- `~/.profile`、`~/.bashrc`，以及存在时的 `~/.zshrc`：只添加带边界标记的小区块，用来设置 PATH 和加载 API Key。

写入 Shell 启动文件前，脚本会校验已有边界标记；标记不完整或重复时会停止，不会覆盖你的原有配置。替换已有区块前会创建同目录备份。

## 上传到 GitHub

手动上传时，请上传本目录**里面**的文件和文件夹，不要额外套一层 `codex-easy-setup/` 目录。请同时上传隐藏的 `.github` 文件夹；其中的 GitHub Actions 工作流会在每次推送后运行测试。

如果你把仓库改名或转移到其他账号，请把上面两条安装命令中的 GitHub 地址改成新的仓库地址。

## 本地测试

在 Linux 或 WSL 中运行：

```bash
bash tests/run.sh
```

测试在临时 HOME 目录中运行，不会安装真实 Codex，也不会写入你的 API Key。它会验证配置写入、备份、密钥权限、输入校验和菜单启动流程。

## 官方资料

- [Codex 官方安装器](https://chatgpt.com/codex/install.sh)
- [最新模型指南](https://developers.openai.com/api/docs/guides/latest-model.md)
- [Codex 当前模型目录](https://github.com/openai/codex/blob/main/codex-rs/models-manager/models.json)
- [Codex 配置参考](https://learn.chatgpt.com/docs/config-file/config-reference)
- [自定义模型提供方](https://learn.chatgpt.com/docs/config-file/config-advanced#custom-model-providers)
- [审批与沙箱设置](https://learn.chatgpt.com/docs/agent-approvals-security#sandbox-and-approvals)
