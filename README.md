# codexcontinue

**Codex CLI 卡在 “Selected model is at capacity”？让它等一会儿，自动输入「继续」，而不用你一直盯着终端。**

这是一个适用于 **macOS + iTerm2 + Codex CLI** 的轻量自动续跑监工。它监听正在使用的 iTerm2 会话，只针对 Codex 的**模型容量不足**错误重试，不会因为普通任务结束就乱发“继续”。

[English](README.en.md) · [源代码](capacity_guard.py) · [测试](tests/test_guard.py)

## 它解决什么问题？

你让 Codex 修改代码，任务执行到一半，模型突然提示：

![Codex CLI 的 Selected model is at capacity 报错](assets/codex-capacity-error.png)

> 上图红色报错就是本项目监控的目标。以前你得反复手动输入「继续」；安装后，监工会在确认 Codex 停在空白输入框时，延迟重试。

**工作流程演示（GIF，示意动画，不是真实录屏）：**

![codexcontinue 工作流程演示：发现容量报错、等待、自动续跑、恢复工作、再次报错重新计数](assets/codexcontinue-workflow.gif)

监工只会在 **Codex 仍显示指定容量错误、且输入框为空** 时尝试自动续跑。

**不会切换模型、不会自动批准命令审批、不会自动重开已退出的 Codex**。它不能保证任务最终完成，只负责特定容量错误的有限次数自动续跑。

## 最简单的安装方法：把一句话发给 AI（推荐）

**不懂终端、不会运行 Python 脚本也没关系。** 你只需要使用能够访问这台 Mac 的 AI 助手，例如 Mac 上的 Codex，或者连接了 Remote Desktop Commander 的 ChatGPT。**普通网页 AI 没有本机访问权限时，不能完成真实安装。**

把下面这一整段复制到 AI 对话框：

~~~text
请帮我在当前这台 Mac 上安装 GitHub 开源工具：
https://github.com/twinsshehp/codexcontinue

请先阅读这个仓库的 AI_INSTALL.md 和 AGENTS.md，然后亲自完成检查环境、获取项目、安装依赖、安装后台监工和验证运行状态。你有本地工具就直接操作，不要只给我命令让我手动执行。不要打断我正在运行的 iTerm2 / Codex 任务；不要绕过 macOS 授权。

如果需要我亲自打开 iTerm2 的 Python API 或确认系统权限，请告诉我在哪里点，并等待我操作。安装后请检查服务和启动日志，最后用简短中文告诉我是否成功、是否随 iTerm2 开启与退出，以及仍有哪些限制。
~~~

**安装完成后监工会自动启动。退出 iTerm2（Cmd+Q）时监工也会退出，再打开 iTerm2 时自动启动。你不需要自己输入启动命令，也不需要专门打开监工终端。** GitHub 页面后面的 `launchctl`、`tail` 命令只是开发者的可选检查工具，普通用户可以让 AI 代为执行。

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

## 如何主动停止、恢复或卸载？（支持 AI 对话和脚本）

**主动停止不是退出 iTerm2。** 退出 iTerm2 时监工会暂时停止，下次启动 iTerm2 时恢复；而**主动停止会被记住**，即使关闭/重开 iTerm2，或者重新登录 Mac，也不会悄悄恢复。

### 最简单：直接告诉有本机操作权限的 AI

想停止时发送：

> **帮我停止 codexcontinue 监工，并保持停止状态。不要退出 iTerm2，不要停止 Codex 任务。执行仓库的 scripts/stop.sh，并检查状态。**

想恢复时发送：

> **帮我恢复 codexcontinue 监工，执行仓库的 scripts/start.sh，检查它是否运行。不要重启我的 Codex 任务。**

想知道当前状态时发送：

> **帮我检查 codexcontinue 是正在运行、主动停止，还是等待 iTerm2 启动；顺便查看最近的自动续跑记录。**

AI 必须能访问你的 Mac 才能执行操作。没有本机工具的普通网页 AI 无法代你操作。

### 自己运行脚本（在项目目录）

~~~bash
# 主动停止，并记住停止状态
bash scripts/stop.sh

# 明确恢复监工
bash scripts/start.sh

# 查看状态与最近的自动“继续”记录
bash scripts/status.sh
~~~

- 停止脚本**只停止监工**，不会退出 iTerm2，也不会停止正在执行的 Codex CLI。
- 主动停止后，下次打开 iTerm2 **也保持停止**。
- 恢复脚本会撤销停止标记；如果 iTerm2 还开着，监工立即启动；如果 iTerm2 已关闭，则在下次打开时启动。
- 这与前面提到的“容量报错最多自动重试 5 次”是不同的功能。这里是用户主动暂停监控，必须明确恢复。

**不在项目目录怎么办？** 安装时会把管理脚本复制到固定的本地目录 **~/Library/Application Support/CodexCapacityGuard/scripts/**。即使原来的 Git 仓库被移动或删除，仍然能在这里找到脚本；你也可以直接让 AI 去这个路径执行。

### 彻底卸载（在项目目录）

~~~bash
bash scripts/uninstall.sh
~~~

卸载会停止监工、移除启动配置和已安装的程序；本地运行日志默认保留，方便排查。**卸载与停止不同**：停止保留安装，可以随时恢复。

## 常见问题

**Q：安装完成还要自己启动吗？**

**不用。** 安装脚本已经启动监工，并配置了跟随 iTerm2 启动 / 退出。截图中的 `launchctl` 和 `tail` 命令只是可选检查方式，不是额外安装步骤。

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

### 自动重试 5 次后，人工继续成功，以后还会自动帮忙吗？

**会，但需要看这次“恢复运行”持续多久。** `5 次` 不是永久总额度，而是**同一个 iTerm2 会话的一次连续容量错误状态**的上限。

当前代码的准确行为是：

1. 监工连续发送最多 **5 次** 后，停止针对当前这次连续报错自动发送。
2. 如果你人工输入“继续”，成功离开“容量错误 + 空白输入框”状态，并**持续至少 120 秒**，监工会清除这个会话的旧重试计数。
3. 之后同一会话**再次出现同类容量错误**，会开启新一轮，重新允许最多 5 次自动重试。
4. **如果刚恢复不到 120 秒就再次报错**，不会立刻清零，仍可能沿用之前的剩余次数；如果上一轮已用满 5 次，就需要进一步人工干预。
5. 上述状态重置依赖监工正常运行、且能继续检查到该 iTerm2 的 Codex 前台会话；关闭进程、改变终端或 UI 显示可能影响判断。

**举例：** 自动重试 5 次都失败 → 你人工继续成功 → Codex 正常运行 3 分钟 → 再次容量报错 → **又会有新一轮最多 5 次自动重试**。

### 怎么查看监工实际发送过多少次“继续”？

**不懂终端的用户直接问 AI：**

> 帮我查看 codexcontinue 最近的自动续跑记录。读取 `~/.local/state/codex-capacity-guard/supervisor.log`，告诉我每次发现报错和发送继续的时间、属于第几次重试，以及有没有达到 5 次上限。只读取日志，不要操作我的 Codex 会话。

**熟悉终端的用户：** 在项目目录执行：

~~~bash
bash scripts/status.sh
~~~

该脚本会显示监工是否运行，以及当前日志中最近几次自动发送的记录。

如果只想查看发送“继续”的事件：

~~~bash
grep 'Sent continuation' ~/.local/state/codex-capacity-guard/supervisor.log
~~~

想**实时查看**监工做了什么：

~~~bash
tail -f ~/.local/state/codex-capacity-guard/supervisor.log
~~~

| 日志关键字 | 实际含义 |
| --- | --- |
| `Capacity error on session` | 检测到容量报错，开始等待首轮重试 |
| `Sent continuation: session ... attempt 1/5` | **已尝试向原 iTerm2 会话发送一次继续指令**，此次是第 1 次 |
| `Maximum retries reached` | 当前连续错误已经达到 5 次上限，监工不再自动发送 |
| `Started: Codex CLI only` | 监工服务已启动，并不代表已经发过“继续” |

日志最多保留一个当前文件及两个滚动备份，**不是永久审计数据库**；删除日志或日志滚动会影响可查询的历史。

注意：**“Sent continuation” 只能证明监工向终端发出了输入，不代表 Codex 成功接收、恢复任务或最终完成。** 这些还需要对照 Codex 界面和实际任务结果。

### 它的原理是什么？是一个定时器吗？

它由两个部分组成：

- **macOS LaunchAgent**：负责管理用户级 Python 进程，关闭了 `KeepAlive`，监工退出后不会被无限拉起。它是 macOS 常规的用户级后台服务管理机制。
- **iTerm2 的启动脚本（AutoLaunch.scpt）**：每次打开 iTerm2 时触发 `launchctl kickstart`，启动监工；这是 iTerm2 支持的脚本自动启动方式。
- **Python `asyncio` 循环 + iTerm2 Python API**：监工进程在运行期间每 **5 秒** 检查一次当前 iTerm2 会话。先确认前台程序是 Codex CLI，再读取屏幕；只有符合指定容量报错且输入框为空，才触发退避等待并尝试向**同一个会话**发送续跑指令。

它**不是 `cron` 定时任务，也不是每 5 秒启动一个新的 Python 程序**。一个 Python 进程持续运行，在两次检查之间异步等待。

监工本身不调用 OpenAI 模型，也不会自行消耗 Codex token；但当它发出“继续”后，**Codex 实际继续执行会正常消耗相应模型额度和资源**。

### 它占用多少内存和 CPU？Codex 不工作时还运行吗？

实际在项目作者的一台 Mac 上观察到的监工进程：

- 常驻内存（RSS）约 **22 MB**；
- 一次空闲状态 CPU 取样为 **0.0%**；
- 每 5 秒会访问一次 iTerm2 API，实际占用会随窗口数量、屏幕内容和 Mac 环境变化。

**只要 iTerm2 还开着，监工就会保持运行。** 即使当前没有 Codex 会话也会待命；但退出 iTerm2（例如 Cmd+Q）后，监工会在下一次检查时自行退出，通常不超过 5 秒。**只关闭 iTerm2 的某个窗口、但 App 仍然运行时，不算退出。**

它什么时候退出？**退出 iTerm2、注销当前 macOS 账户、关机或手动停用时都会退出。** 现在已经关闭了 LaunchAgent 的 `KeepAlive`，它不会在 iTerm2 已退出的情况下无限重新启动。重新打开 iTerm2 会通过 `AutoLaunch.scpt` 重新启动监工。异常退出后也不会无限自动重启；需要重新打开 iTerm2 或手动启动。

所以不需要专门关闭监工：**直接退出 iTerm2 就行**；再次打开 iTerm2，会自动启动。也可让有本机权限的 AI 按下面命令手动暂停/恢复。

**Q：为什么不一直重试？**

容量持续不足时，无限重试会浪费资源并导致重复操作。本项目限定最多 5 次，超出后等待人工处理。

## 开发与测试

~~~bash
python3 -m unittest discover -s tests -v
~~~

已通过自动单元测试，覆盖目标报错、普通结束、正在输入、审批弹窗、退避和重试上限。**尚未完成真实容量错误触发 → 自动输入的端到端验证；不能保证百分之百成功。**

使用 [MIT License](LICENSE)。非 OpenAI / iTerm2 官方项目。
