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

## 安装教程（从零开始）

### 第一步：在 iTerm2 开启 Python API

打开 **iTerm2 → Settings（设置） → General（通用） → Magic**，找到 Python API 设置：

![iTerm2 的 General → Magic → Enable Python API 设置](assets/iterm2-python-api.png)

1. 勾选 **Enable Python API**，如上图。
2. 下拉框保持 **Allow all apps to connect**；也可以按安全需求选更严格的方式（严格授权可能需要额外批准）。
3. 如果 iTerm2 弹出连接权限窗口，请按需允许。
4. **一般不需要重启 iTerm2 或已有的 Codex 任务。**

### 第二步：下载并安装

在 iTerm2 的新标签页复制下面的三行命令：

~~~bash
git clone https://github.com/twinsshehp/codexcontinue.git
cd codexcontinue
bash scripts/install.sh
~~~

安装脚本会：创建独立 Python 虚拟环境、安装 iTerm2 Python API 客户端、注册 macOS **LaunchAgent** 并启动后台监工。

前提：macOS 已安装 **Python 3.10+**（带 venv、pip）。首次安装需要联网下载依赖。

### 第三步：确认监工启动成功

~~~bash
launchctl print gui/$(id -u)/com.peakmain.codex-capacity-guard
~~~

输出出现 **state = running** 表示后台服务正在运行。

查看监工日志：

~~~bash
tail -f ~/.local/state/codex-capacity-guard/supervisor.log
~~~

- **Started: Codex CLI only**：已启动
- **Capacity error on session**：发现目标报错
- **Sent continuation**：尝试向 Codex 输入续跑指令

启动成功不等于真实的自动续跑已经验证成功，需要结合 Codex 界面和日志确认。

### 第四步：正常使用 Codex

~~~bash
codex
~~~

你在 iTerm2 中照常运行 Codex 即可。监工不需要单独的终端窗口，也不需要每次手动启动；macOS 用户登录后会自动尝试启动监工。

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

## 如何停止、重启、卸载？

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
