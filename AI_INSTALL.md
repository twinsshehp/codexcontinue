# AI 安装操作说明 / AI installation playbook

这份文档用于有本机操作能力的 AI 编程助手（如运行在 Mac 上的 Codex CLI、或连接了 Remote Desktop Commander 等本机工具的 ChatGPT）。不要要求不懂终端的用户复制、执行命令；在获得用户授权后，由助手自行完成安装和验证。

## 目标

将 [codexcontinue](https://github.com/twinsshehp/codexcontinue) 安装到用户当前 Mac：监测 iTerm2 中 Codex CLI 的 `Selected model is at capacity` 报错，在安全检查后默认只提交 `继续` + Enter，并按有限次数自动重试。

### 绝对不要做的事

- 不运行 `sudo`、不绕过 macOS TCC 权限、不擅自修改安全设置。
- 不擅自结束、重启用户正在使用的 iTerm2、Codex CLI 或其他服务。
- 不自动启用 Codex `--yolo` 或改变模型、Codex Hooks、审批策略。
- **不修改用户的 `~/.codex/AGENTS.md`、`~/.codex/config.toml`、全局 Skill 或任何已有 Codex 配置**，不要为了让 Codex “认识” codexcontinue 而注入全局指令。`AGENTS.md` 只位于这个 GitHub 仓库内，供安装时阅读。
- 不在已存在的仓库里直接覆盖未提交的用户修改。
- 不泄露本机环境变量、API Key、日志、令牌等内容。
- 未验证成功时，不得对用户说“已经安装成功”。

## AI 安装流程

1. **确认操作能力。** 判断自己是否真的有权限操作用户的**本地 macOS**（终端/文件工具），而不是仅有云端浏览器。没有权限则说明需要连接受支持的本地工具；不要仅返回一段让用户复制的命令并声称任务完成。
2. **检查环境，避免重复安装。** 检查 macOS、iTerm2 是否安装、是否已经运行 Codex CLI、Python ≥3.10 是否有 `venv`/`pip`，以及是否已有 LaunchAgent `com.peakmain.codex-capacity-guard`。已有运行中的服务时先只读检查；若版本需要替换，会短暂重启监工但不应重启 Codex。先告知用户。不要覆盖他人已有的 AutoLaunch.scpt。
3. **确认 Python API。** 检查 iTerm2 → Settings → General → Magic → `Enable Python API`。如未开启，让用户**亲自勾选**，参考截图 [assets/iterm2-python-api.png](assets/iterm2-python-api.png)。授权弹窗也让用户自行确认。不要代替用户绕过授权。
4. **确认仓库可信、代码来源正确。** GitHub 地址必须为 `https://github.com/twinsshehp/codexcontinue`；先查看 README 和 `scripts/install.sh`。在用户指定的项目目录中使用仓库（如无指定，选择新的独立目录，避免冲突），不要覆盖已有本地更改。
5. **安装。** 环境和权限可用后，从该仓库执行 `bash scripts/install.sh`。这个脚本会自己创建虚拟环境、注册 macOS LaunchAgent（KeepAlive=false），并安装 iTerm2 AutoLaunch.scpt。安装时会自动启动；退出 iTerm2 后监工退出，再打开 iTerm2 时自动启动。**安装完成后不需要用户再执行启动命令。**
6. **健康检查。** 从固定安装目录运行 `bash "$HOME/Library/Application Support/CodexCapacityGuard/scripts/status.sh"`，确认服务处于 `running`，并且 `~/.local/state/codex-capacity-guard/supervisor.log` 出现 `Started`。如果 API 无法连接，看 `service.stderr.log`，明确告知用户问题和最小必要授权，修复后重验。
7. **报告结果。** 简洁地告诉用户“已安装、当前正常运行，并且与 iTerm2 同步启动/退出”，或者“仍需你打开 Python API / 连接本机终端”。说明**还未由真实模型容量错误验证完整自动续跑流程**时不能说已经证明端到端恢复。
8. **不要制造容量报错。** 默认只做安装、状态及单元测试，绝不往用户现有 Codex 会话里发送测试“继续”；只有用户明确同意才做实际交互测试。

## AI 停止 / 恢复 / 查看状态（不依赖仓库路径）

**codexcontinue 是后台监工，不是一个必须在进程列表中出现为 codexcontinue 的进程。** 实际服务标签为 `com.peakmain.codex-capacity-guard`，Python 脚本运行在安装目录；管理时无需按名称搜索进程或修改 Codex 配置。

**安装后的固定位置**，不论最初安装在哪个 Git 仓库目录，管理脚本都位于：

~~~bash
CONTROL_DIR="$HOME/Library/Application Support/CodexCapacityGuard/scripts"
bash "$CONTROL_DIR/stop.sh"     # 停止：直到用户明确恢复
bash "$CONTROL_DIR/start.sh"    # 恢复
bash "$CONTROL_DIR/status.sh"   # 查询，不改变状态
~~~

- 用户说 **“停止 codexcontinue”**：从固定路径执行 stop.sh，再执行 status.sh 验证。**不要**关闭 iTerm2 / Codex，不要在下次启动时擅自恢复。
- 用户说 **“恢复 codexcontinue”**：执行固定路径的 start.sh，再执行 status.sh；如果 iTerm2 已关闭则等待下一次打开。
- 用户说 **“查看状态、记录”**：只执行固定路径的 status.sh。
- **禁止猜测用户克隆了仓库的具体路径。** 如果固定目录不存在，应报告“未安装或安装不完整”，不要悄悄重新安装。
- 不要硬编码用户的 macOS 用户名。用 `$HOME` 定位主目录。安装程序会复制控制脚本到此位置；即使源仓库移动，控制仍可使用。
- 停止标记保存于 `$HOME/Library/Application Support/CodexCapacityGuard/disabled`；用户明确恢复后才能清除。

## 供 AI 使用的命令（用户无需复制）

检查当前服务（不需要进入 Git 仓库）：

~~~bash
bash "$HOME/Library/Application Support/CodexCapacityGuard/scripts/status.sh"
~~~

验证源代码逻辑：
```bash
python3 -m unittest discover -s tests -v
```

安装（确认授权与无覆盖风险之后）：
```bash
bash scripts/install.sh
```

主动停止（固定安装路径）：

~~~bash
bash "$HOME/Library/Application Support/CodexCapacityGuard/scripts/stop.sh"
bash "$HOME/Library/Application Support/CodexCapacityGuard/scripts/status.sh"
~~~

恢复（固定安装路径）：

~~~bash
bash "$HOME/Library/Application Support/CodexCapacityGuard/scripts/start.sh"
bash "$HOME/Library/Application Support/CodexCapacityGuard/scripts/status.sh"
~~~

卸载（仅用户明确要求时；不依赖仓库路径）：
```bash
bash "$HOME/Library/Application Support/CodexCapacityGuard/scripts/uninstall.sh"
```

## 故障分流

| 现象 | 处理 |
| --- | --- |
| AI 无法访问本机文件或终端 | 请求用户启用/连接本机操作工具，不能假装已经安装 |
| Python API 未启用或弹出权限窗口 | 指引用户点击授权，截图见 README |
| `launchctl` 没有 running | 如果 iTerm2 已退出，这属于预期；若 iTerm2 正在运行则查看 stderr / plist 后再确认 |
| 服务 running 但没有 Started 日志 | 检查 Python 环境和 iTerm2 API 连接情况 |
| Started 已出现但没有自动继续 | 这是基于当前屏幕的精确容量错误匹配，先核对 Codex 当前 UI 和日志 |
| 已有运行中的监工 | 先检查版本与配置，不要无确认停止用户服务 |
| 已被用户主动停止 | AI 不得擅自恢复；用户明确说“恢复”时才执行 start.sh |

## 安全提示

- 监工对终端拥有发送文本的能力。只允许用户信任的本机 AI 及项目执行安装。
- 本项目不要求用户提供 OpenAI API Key。
- 当前仅支持 iTerm2 中的 Codex CLI。无法保证恢复进程退出、断电、网络断开或所有样式变化后的报错。
