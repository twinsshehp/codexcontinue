#!/usr/bin/env python3
"""Render a self-contained README workflow GIF. Developer-only dependency: Pillow."""
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont
import math

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "assets" / "codexcontinue-workflow.gif"
W, H = 1140, 640
BG = "#0c1220"
PANEL = "#121b2b"
SURFACE = "#172338"
WHITE = "#f7f9ff"
MUTED = "#a7b7ce"
RED = "#ff6d76"
GREEN = "#54d4a2"
BLUE = "#6db9ff"
YELLOW = "#ffcf7c"
FONT = "/System/Library/Fonts/Hiragino Sans GB.ttc"
MONO = "/System/Library/Fonts/Supplemental/Menlo.ttc"
if not Path(MONO).exists():
    MONO = FONT

def font(size, bold=False, mono=False):
    return ImageFont.truetype(MONO if mono else FONT, size, index=0)

TITLE = font(37)
HEAD = font(28)
TEXT = font(23)
SMALL = font(20)
MINI = font(18)
CODE = font(19, mono=True)
DOTS = [(85, 570), (335, 570), (585, 570), (835, 570), (1065, 570)]
LABELS = ["触发报错", "确认空输入框", "等待并续跑", "恢复原任务", "下次再次报错"]
SCENES = [
    ("01", "Codex 遇到容量错误", "监控特定错误，不干预正常任务完成", "error", RED),
    ("02", "监工检测等待状态", "确认前台是 Codex，且输入框为空", "check", BLUE),
    ("03", "等待 30 秒后自动续跑", "向同一个 iTerm2 会话发送继续指令", "send", YELLOW),
    ("04", "Codex 恢复执行", "成功恢复后，监工重新进入待命状态", "working", GREEN),
    ("05", "以后再次报错？继续帮你", "离开报错状态满 120 秒，重置重试计数", "reset", BLUE),
]

def rounded(draw, box, fill, radius=22, outline=None, width=1):
    draw.rounded_rectangle(box, radius=radius, fill=fill, outline=outline, width=width)

def base_image(idx, frac):
    im = Image.new("RGB", (W, H), BG)
    d = ImageDraw.Draw(im)
    rounded(d, (24, 20, 1116, 110), PANEL, radius=26)
    d.text((51, 42), "codexcontinue", font=TITLE, fill=WHITE)
    rounded(d, (845, 42, 1090, 86), "#21324b", radius=18)
    d.text((870, 50), "流程动画 · 演示", font=SMALL, fill=BLUE)
    rounded(d, (24, 130, 708, 523), "#0d121b", radius=26, outline="#394559", width=2)
    d.ellipse((50, 155, 67, 172), fill="#fb5e62")
    d.ellipse((78, 155, 95, 172), fill="#eabd56")
    d.ellipse((106, 155, 123, 172), fill="#43c978")
    d.text((150, 152), "Codex CLI  ·  iTerm2", font=SMALL, fill=MUTED)

    # Terminal screen: synthetic demonstration, not a recording.
    rounded(d, (46, 206, 686, 482), "#080b12", radius=15)
    d.text((70, 235), "› 处理尚未完成的开发任务", font=CODE, fill=MUTED)
    mode = SCENES[idx][3]
    if idx < 3 or idx == 4:
        d.text((70, 288), "■ Selected model is at capacity.", font=CODE, fill=RED)
        d.text((92, 319), "Please try a different model.", font=CODE, fill=RED)
        d.text((70, 388), "›", font=HEAD, fill=WHITE)
        if idx == 2:
            count = max(0, int((1-frac)*30))
            d.text((102, 394), "继续上一条未完成任务...", font=TEXT, fill=GREEN)
            d.text((70, 442), f"自动续跑指令提交中  {int(frac*100)}%", font=SMALL, fill=MUTED)
    else:
        d.text((70, 288), "✓ 任务正在继续执行", font=HEAD, fill=GREEN)
        d.text((70, 342), "Working ...", font=CODE, fill=WHITE)
        dots = ("● " * (1 + int(frac*3))).strip()
        d.text((70, 410), dots, font=SMALL, fill=GREEN)

    rounded(d, (734, 130, 1116, 523), PANEL, radius=26, outline="#33435b", width=2)
    no, title, desc, mode, clr = SCENES[idx]
    d.text((764, 160), f"STEP {no} / 05", font=SMALL, fill=BLUE)
    for x, row in enumerate((title[:12],title[12:])):
        if row:
            d.text((764, 214 + x*39), row, font=HEAD, fill=WHITE)
    d.text((764, 315), desc[:16], font=SMALL, fill=MUTED)
    d.text((764, 347), desc[16:], font=SMALL, fill=MUTED)
    if idx == 0:
        d.text((764, 432), "触发条件：容量不足", font=SMALL, fill=RED)
    elif idx == 1:
        d.text((764, 432), "无人工输入 · 无审批弹窗", font=SMALL, fill=BLUE)
    elif idx == 2:
        rounded(d, (764, 416, 1086, 469), "#30334d", 14)
        d.rectangle((764, 416, 764+int(322*frac), 469), fill=YELLOW)
        d.text((777, 425), "自动发送“继续”", font=TEXT, fill="#0c1220" if frac>.35 else WHITE)
    elif idx == 3:
        d.text((764, 432), "状态：继续运行中", font=SMALL, fill=GREEN)
    else:
        d.text((764, 420), "每轮最多 5 次自动重试", font=SMALL, fill=BLUE)
        d.text((764, 452), "超过上限先等待恢复", font=MINI, fill=MUTED)

    # animated progress timeline
    d.line((85, 570, 1065, 570), fill="#39475e", width=6)
    steps_done = idx + frac
    d.line((85, 570, 85 + (1065-85) * min(1, steps_done/4), 570),
           fill=BLUE, width=6)
    for j,(x,y) in enumerate(DOTS):
        c=GREEN if j<idx else (BLUE if j==idx else "#45536a")
        r=12 + (int((math.sin(frac * 2*math.pi)+1)*3) if j==idx else 0)
        d.ellipse((x-r,y-r,x+r,y+r), fill=c)
        bbox=d.textbbox((0,0),LABELS[j],font=MINI)
        tw=bbox[2]
        d.text((x-tw/2, 592), LABELS[j],font=MINI,fill=WHITE if j==idx else MUTED)
    return im

def render():
    OUT.parent.mkdir(parents=True, exist_ok=True)
    frames, durations = [], []
    for idx in range(5):
        for i in range(9):
            frames.append(base_image(idx, i/8))
            durations.append(120 if i<8 else 850)
    # GIF uses palette; make it smaller without external dependencies.
    frames = [frame.quantize(colors=112, method=Image.Quantize.FASTOCTREE)
              for frame in frames]
    frames[0].save(OUT, save_all=True, append_images=frames[1:], duration=durations,
                   loop=0, disposal=2, optimize=True)
    print(f"{OUT}: {len(frames)} frames, {OUT.stat().st_size:,} bytes")

if __name__ == "__main__":
    render()
