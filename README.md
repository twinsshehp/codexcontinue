# codexcontinue

**Codex CLI 卡在 “Selected model is at capacity”？让它等一会儿，自动输入「继续」，而不用你一直盯着终端。**

这是一个适用于 **macOS + iTerm2 + Codex CLI** 的轻量自动续跑监工。它监听正在使用的 iTerm2 会话，只针对 Codex 的**模型容量不足**错误重试，不会因为普通任务结束就乱发“继续”。

[English](README.en.md) · [源代码](capacity_guard.py) · [测试](tests/test_guard.py)

## 它解决什么问题？

你让 Codex 修改代码，任务执行到一半，模型突然提示：

![Codex CLI 的 Selected model is at capacity 报错](assets/codex-capacity-error.png)

> 上图红色报错就是本项目监控的目标。以前你得反复手动输入「继续」；安装后，监工会在确认 Codex 停在空白输入框时，延迟重试。

**运行流程：**

~~~text
你在 iTerm2 正常运行 Codex CLI
        ↓
出现 Selected model is at capacity
        ↓
监工识别报错，并确认 Codex 等待输入
        ↓
等待 30 秒 → 向原会话自动输入继续执行指令
        ↓
如果再次遇到容量错误 → 延长等待并重试（最多 5 次）
~~~

**不会切换模型、不会自动批准命令审批、不会自动重开已退出的 Codex**。它不能保证任务最终完成，只负责特定容量错误的有限次数自动续跑。

## 最简单的安装方法：把一句话发给 AI（推荐）

**不懂终端、不会运行 Python 脚本也没关系。** 你只需要使用能够访问这台 Mac 的 AI 助手，例如 Mac 上的 Codex，或者连接了 Remote Desktop Commander 的 ChatGPT。**普通网页 AI 没有本机访问权限时，不能完成真实安装。**

把下面这一整段复制到 AI 对话框：

~~~text
请帮我在当前这台 Mac 上安装 GitHub 开源工具：
https://github.com/twinsshehp/codexcontinue

请先阅读这个仓库的 AI_INSTALL.md 和 AGENTS.md，然后亲自完成检查环境、获取项目、安装依赖、安装后台监工和验证运行状态。你有本地工具就直接操作，不要只给我命令让我手动执行。不要打断我正在运行的 iTerm2 / Codex 任务；不要绕过 macOS 授权。

如果需要我亲自打开 iTerm2 的 Python API 或确认系统权限，请告诉我在哪里点，并等待我操作。安装后请检查服务和启动日志，最后用简短中文告诉我是否成功、是否登录后自动运行，以及仍有哪些限制。
~~~

**安装完成以后，监工会自动启动，并在每次登录 Mac 后自动尝试运行。你不需要自己输入启动命令，不需要专门打开监工终端。** GitHub 页面后面的 `launchctl`、`tail` 命令只是开发者的可选检查工具，普通用户可以让 AI 代为执行。

### 唯一可能需要你亲自点击的设置

首次使用时，macOS / iTerm2 可能要求你授权。请打开 **iTerm2 → Settings → General → Magic**，勾选 **Enable Python API**（见图），授权提示由你自己决定是否允许：

![iTerm2 中启用 Python API 的位置](assets/iterm2-python-api.png)

这样 AI 就可以在已授权的范围内继续安装和验证。不需要为了安装监工而退出正在执行的 Codex。

### AI 应该反馈什么？

AI 会根据 [AI 安装操作说明](AI_INSTALL.md) 依次进行检查和验证。最后应告诉你 **已安装且正在运行**，或者明确指出**还需要你授权 / 缺少什么依赖**。只要后台服务启动，并不代表已经用真实的模型容量错误完成端到端测试；AI 不应夸大验证结果。

## 手动安装（可选，给熟悉命令行的用户）

没有可操作本机的 AI 助手，或者你更喜欢自己安装，也可以在 Mac 的 iTerm2 中运行：

~~~bash
git clone https://github.com/twinsshehp/codexcontinue.git
cd codexcontinue
bash scripts/install.sh
~~~

需要 **Python 3.10+**（包含 `venv`、`pip`）以及首次安装时的网络连接。脚本会创建独立 Python 环境、安装 iTerm2 API 客户端、注册 macOS LaunchAgent，并**立即尝试启动监工**，无须再运行第二条启动命令。

### 可选：检查安装状态

**这一步不是安装必需步骤。** 如果想自己检查：

~~~bash
bash scripts/status.sh
~~~

脚本会给出「后台运行中」「已找到启动日志」「错误日志」等结果。AI 安装时也会自己执行这一步。

熟悉 macOS 的开发者还可以直接查看：

~~~bash
launchctl print gui/$(id -u)/com.peakmain.codex-capacity-guard
tail -f ~/.local/state/codex-capacity-guard/supervisor.log
~~~

日志里 `Started` 代表监工已启动；`Sent continuation` 代表监工向某个 Codex 会话尝试发送了续跑指令。**后者也不保证任务已完成。**

## 监工规则

| 项目 | 行为 |
| --- | --- |
| 检测频率 | 每 5 秒查看 iTerm2 中的 Codex 屏幕 |
| 触发条件 | 出现指定容量错误，且 Codex 输入框为空 |
| 第一次等待 | 30 秒 |
| 后续重试间隔 | 60、120、240、300 秒 |
| 最大重试次数 | 同一次连续报错最多 5 次 |
| 正常任务结束 | 不干预 |
| 审批弹窗 / 用户正在输入 | 不发送 |
| 自动切换模型 | 不支持，也不会擅自切换 |
| 适用范围 | macOS iTerm2 内的 Codex CLI |

默认自动发送一条英语指令，要求 Codex 检查先前进度后继续执行，避免重复已完成操作。你也可以在 LaunchAgent 的 **EnvironmentVariables** 里添加 **CAPACITY_GUARD_MESSAGE** 自定义单行文本，重载后生效。

## 停止、重启、卸载（也可以直接让 AI 操作）

暂停监工：

~~~bash
launchctl bootout gui/$(id -u)/com.peakmain.codex-capacity-guard
~~~

恢复运行：

~~~bash
launchctl bootstrap gui/$(id -u) \
  "$HOME/Library/LaunchAgents/com.peakmain.codex-capacity-guard.plist"
~~~

彻底卸载（在项目目录运行）：

~~~bash
bash scripts/uninstall.sh
~~~

卸载会停止监工并删除安装文件；本地运行日志默认保留，方便排查。

## 常见问题

**Q：安装完成还要自己启动吗？**

**不用。** 安装脚本已经启动后台服务，并配置了登录后自动运行。截图中的 `launchctl` 和 `tail` 命令只是可选检查方式，不是额外安装步骤。

**Q：我不会编程，也不会用终端怎么办？**

复制上面的 AI 安装提示词给一个拥有本机终端/文件操作权限的 AI，授权提示需要自己点击；剩下的安装、检测都交给 AI。

**Q：我已经开启 Python API，为什么没自动继续？**

先检查后台状态、日志是否有 Started；容量报错必须仍在 iTerm2 的当前可见屏幕。仅滚动历史中的旧报错不会触发。Codex UI 改版也可能影响识别。

**Q：Codex 桌面 App、Apple Terminal 或 ChatGPT 网页能用吗？**

目前不支持。本项目依赖 iTerm2 Python API。

**Q：会修改原来的 Codex Hooks 吗？**

不会。容量错误不一定触发 Stop Hook，所以这里使用外部屏幕监测方式。

**Q：有安全风险吗？**

监工会向真实终端发送文本。虽然只识别特定错误、检查空白输入框、不批准权限操作，但依然存在极小概率误判或与用户输入竞争的情况；建议先在非关键任务上验证。

**Q：为什么不一直重试？**

容量持续不足时，无限重试会浪费资源并导致重复操作。本项目限定最多 5 次，超出后等待人工处理。

## 开发与测试

~~~bash
python3 -m unittest discover -s tests -v
~~~

已通过自动单元测试，覆盖目标报错、普通结束、正在输入、审批弹窗、退避和重试上限。**尚未完成真实容量错误触发 → 自动输入的端到端验证；不能保证百分之百成功。**

使用 [MIT License](LICENSE)。非 OpenAI / iTerm2 官方项目。
