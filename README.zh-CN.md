# Codex Capacity Guard（Codex 容量错误自动监工）

这是一个非官方开源工具，用于监控 **macOS iTerm2 中运行的 Codex CLI**。

当 Codex 出现下面的报错，并回到空白输入框：

~~~text
Selected model is at capacity. Please try a different model.
~~~

监工会等待一段时间，自动向**原来的 iTerm2 会话**发送一条“继续执行”的指令，不会替换模型，也不会点击命令审批选项。

[English README](README.md)

## 主要功能

- 每 5 秒检查 iTerm2 中正在运行 Codex CLI 的会话。
- 只处理特定的模型容量错误，不把正常完成当成卡住。
- 首次等待 30 秒，后续间隔依次为 60、120、240、300 秒；同一轮容量错误最多自动重试 5 次。
- 发送指令前会再次检查屏幕，避免打扰正在工作或正在输入的终端。
- 保留重试状态和本地日志。
- 使用 macOS LaunchAgent 在登录后自动启动，无须保持单独监工窗口。
- 无需修改 Codex Hooks，无需配置 OpenAI API Key。

**注意：** 基于终端屏幕内容判断属于启发式方案，可能漏检或误判。当前已完成模拟测试及 iTerm2 API 读取验证，**尚未通过真实容量报错到自动输入的完整端到端测试**。无法恢复已经退出的 Codex 进程。

## 环境要求

- macOS
- [iTerm2](https://iterm2.com/)，在 **Settings → General → Magic** 开启 **Enable Python API**
- 直接在 iTerm2 中运行的 Codex CLI（前台程序为 codex）
- Python 3.10 或更新版本、venv 和 pip
- 首次安装需要联网下载 Python 依赖

不支持：Apple Terminal、Codex 桌面 App、ChatGPT 网页聊天，或不属于 iTerm2 的 tmux 会话。

## 安装

~~~bash
git clone https://github.com/twinsshehp/codex-capacity-guard.git
cd codex-capacity-guard
bash scripts/install.sh
~~~

安装完成后保持 iTerm2 开着即可，无需重启已有的 Codex 任务。

## 查看监工状态

~~~bash
launchctl print gui/$(id -u)/com.peakmain.codex-capacity-guard

tail -f ~/.local/state/codex-capacity-guard/supervisor.log

tail -f ~/.local/state/codex-capacity-guard/service.stderr.log
~~~

日志中出现 Started 代表已启动。出现 Sent continuation 代表已尝试向某个会话发送继续指令。

## 自动发送的默认指令

> Continue the previous unfinished task. Check the work already done first; do not repeat completed steps. Stop and ask the user if approval is needed.

可以在 LaunchAgent 的 EnvironmentVariables 中设置 **CAPACITY_GUARD_MESSAGE** 替换为中文单行指令，并重新加载服务。

## 暂停、恢复和卸载

~~~bash
# 暂停监工
launchctl bootout gui/$(id -u)/com.peakmain.codex-capacity-guard

# 恢复监工
launchctl bootstrap gui/$(id -u) \
  "$HOME/Library/LaunchAgents/com.peakmain.codex-capacity-guard.plist"

# 卸载（默认保留日志）
bash scripts/uninstall.sh
~~~

## 运行测试

~~~bash
python3 -m unittest discover -s tests -v
~~~

测试覆盖：目标报错识别、非目标错误、用户已输入文本、审批弹窗、正在执行状态、历史屏幕内容、指数退避、5 次上限及重置逻辑。

## 安全和局限性

- 监工会向 iTerm2 终端发送真实输入，请先阅读源码并在非关键任务中测试。
- 不能保证任务真正完成；没有对项目代码执行自动验收。
- 如果用户恰好在发送瞬间输入，仍存在很小的竞争窗口。
- Codex UI 改版可能导致监工检测不到错误。
- 仅处理当前可见屏幕中的容量报错；后台进程崩溃不在支持范围内。
- 不会自动点击允许执行、删除或发布相关审批。
- 不是 OpenAI 或 iTerm2 官方产品。

开源协议：**MIT**。
