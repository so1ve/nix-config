---
name: mixcut-pipeline
description: 一套自带脚本的踩点混剪流水线（ffmpeg + Python，不开剪辑软件）：下载素材，做镜头、运动和节拍分析，按拍写剪辑表，一条命令完成生成、校验、组装和渲染，并提供看帧审片的工具（封面见 mixcut-cover）。在任何项目里搭建、修改、校验或渲染混剪时使用。
---

# 混剪流水线

所有脚本都在本 skill 的 `scripts/` 目录里。剪辑审美见 `mixcut-craft`，素材归属见 `mixcut-story-attribution`，封面见 `mixcut-cover`。

## 用法约定

- 在**项目根目录**运行。脚本读写的都是相对路径：`src/`、`analysis/`、`catalog/`、`edl…/`、`build/`、`out/`、`music/`。
- 下文用 `$S` 表示本 skill 的 `scripts` 目录（加载 skill 时给出的目录下），先 `S=<本 skill 目录>/scripts`。脚本只读写项目里的相对路径，skill 目录可以是只读的。
- 运行环境：`$S/env.sh <命令…>` 进入 nix shell，里面有 ffmpeg-full、yt-dlp、python（librosa、opencv、pillow、numpy、scipy、matplotlib）。不要假设系统里有 ffmpeg。Python 一律用 `python3 -I`。
- 渲染、批量分析这类长任务放后台，用 Monitor 等结束标记，不要轮询。
- 临时图片放进新的 `mktemp -d` 目录。自动模式会拦截覆盖已有文件的 `ffmpeg -y`，也会拦截删除项目里已有的文件（需要用户点名批准）。

## 新项目的目录

| 路径 | 内容 | 谁来写 |
|---|---|---|
| `src/<id>.mkv` | 源视频 | `fetch.sh <youtube-id>`，或自己放进来 |
| `catalog/footage.tsv` | 素材目录：`id  era  kind  title`（era 是发布时期） | 手写 |
| `catalog/banned.tsv` | 全局禁用清单：`src  shot  原因`，shot 写 `*` 表示禁用整个视频。对所有剪辑生效，只放用户明确否掉的镜头 | 手写，会被校验强制执行 |
| `catalog/banned_<规则>.tsv` | 按剪辑选用的禁用清单，格式同上，例如"只放主线"的剪辑把角色剧情列进 `banned_mainline.tsv`。剪辑表在 `banned` 里声明 | 手写，可以不建 |
| `catalog/scenes/<id>.md` | 场景记录：按源视频秒数写场景、人物、可用性（格式见 `mixcut-story-attribution`） | 读完一个视频就写 |
| `catalog/characters.md` | 人物档案：每人一节（`## 名字`），外观、确认依据、`- ref:` 参考框（`whois.py` 读） | 认出一个人就写 |
| `catalog/top_text.txt` | 画面顶部也有文字的源视频 id，每行一个 | 手写，可以不建 |
| `music/<song>.wav` | BGM | 自备 |
| `analysis/…` | 镜头、缩略图、标签、运动、哈希、节拍网格 | 下面的分析脚本 |

## 流程

| 步骤 | 命令 | 产出 |
|---|---|---|
| 1. 下载 | `$S/fetch.sh <youtube-id>`（≤1080p，优先 60 fps） | `src/<id>.mkv` |
| 2. 镜头检测 | `$S/analyze_all.sh`（调用 `shots.py`） | `analysis/shots/<id>.json`（边界和画面 crop）、`thumbs/`、`sheets/` |
| 3. 镜头标签（可选） | 让视觉模型按联系表写 `analysis/tags/<id>.json`：每镜 `use`、`desc`、`text`、`energy`、`beauty` 等 | 只当索引；`framing`、`edl_check`、`peaksheet` 会读 `use` 和 `text` |
| 4. 运动分析 | `python3 -I $S/motion.py <id>…` | `analysis/motion/<id>.json`：30 fps 的光流强度、方向、运动重心、亮度 |
| 5. 查重哈希 | `python3 -I $S/phash.py` | `analysis/phash.json` |
| 6. 节拍网格 | `python3 -I $S/beatgrid.py music/song.wav analysis/grid_song.json [period phase]` | 恒定 BPM 网格、小节、乐句 |
| 7. 歌曲结构 | `python3 -I $S/song_energy.py music/song.wav analysis/grid_song.json`；要看段落图用 `music_analysis.py` | 每小节响度和低频 |
| 8. 读素材 | `python3 -I $S/scenes.py <id>…`，再看它出的读片图，细节用 `strips.py out.jpg 12 <id>:all`；认人用 `whois.py`（见下） | `analysis/scenes/<id>.json` 和读片图；`catalog/scenes/<id>.md` 骨架，看完补上场景和人物 |
| 9. 写剪辑表 | 手写 spec（见下）。写好后、渲染前，用 `strips.py out.jpg 5 <part>.json:0-31`（每次 32 镜）逐镜看入出点 | `edl…/<cut>_spec.json` |
| 10. 出片 | `$S/make_cut.sh <spec.json> <out.mp4> [--draft]` | 成片 |

关于第 8 步（读素材）：

- `scenes.py` 把镜头按颜色连续性归成场景，每个场景一行，出读片图。它还标出黑场、白闪，以及和别的视频（或同一视频不相邻处）是同一画面的镜头：先用哈希筛，再用画面相关性确认。官方 PV 常复用过场，同一画面用两次会被 `dupes.py` 抓到，读素材时就该知道。
- 字幕和界面图形在缩略图上太小，检测不可靠，脚本不标。看读片图时自己记进场景记录的"可用性"。
- `whois.py "<名字>" out.jpg [src…]`：按 `catalog/characters.md` 里此人的 `- ref: <src> <秒> <x>,<y>,<w>,<h>`（有效画面里的比例框，框脸和头发），用颜色构成在全部素材里粗筛候选镜头，出"参考 | 候选"对照图。穿着相近的人会混进来，结果只是候选，必须看图确认，确认后写进场景记录和人物档案。
- 场景记录、人物档案的写法见 `mixcut-story-attribution`。

关于第 6 步：

- 不传 period/phase 时，脚本会比较多个倍数的候选速度，选得分最高的一个，同时写出 `<out>.click.wav`（叠了节拍器的试听文件）。
- 两倍、三分之二这类速度歧义，单靠算法分不清。务必请用户听 click 文件确认。不对就手动传入 period 和 phase 重跑（实例：Warriors 是 78 BPM，算法容易认成 117；WE ARE EMPIRE 是 110 BPM，算法曾认成 73）。
- 我自己听不到声音。

第 10 步 `make_cut.sh` 会依次执行：
1. `build_part.py`：spec → 片段表；
2. `framing.py`：把原片字幕裁出 2.39:1 画面；
3. `edl_check.py`：节拍网格、镜头边界、禁用清单，以及同一段源画面是否用了两次（本片段内和同目录其他片段，按源时间区间判断；同一个长镜头的不同时刻可以分开用）；
4. `dupes.py`：画面近似重复；
5. `assemble.py`：组装渲染 EDL `<part>.render.json`；
6. `render.py`：渲染。

任何一步报错都会停下来。多段剪辑（几个 part 首尾相接）用 `assemble.py out.json music.wav part…` 手动组装，再调用 `render.py`。

## 剪辑表（spec）

```json
{"group": "cut", "grid": "analysis/grid_song.json", "out": "edl/cut.json", "music": "music/song.wav",
 "banned": ["catalog/banned_mainline.tsv"], "start_beat": 0, "start": 0.0,
 "clips": [[beats, "src", shot, off, speed, {"look": "steel", "push": 0.05, "note": "..."}], ...]}
```

- `banned`：可选，这个剪辑额外遵守的禁用清单，叠加在全局 `catalog/banned.tsv` 之上。同一批素材的不同剪辑可以有不同规则：主线历程剪辑禁用角色剧情，角色个人向剪辑却要用它。
- `beats`：片段长度，最细到 1/8 拍。`end` 可选，用于在最后一拍之后直接结束。
- `off` 决定从镜头的哪里开始：
  - `shot` 写 `null` 时，`off` 是源视频里的绝对秒数（直接抄条带上标的时间），脚本自己找它所在的镜头。看帧选入点时用这种写法；
  - 秒数，相对镜头开头；
  - `"peak"`（运动最强帧）或 `"flash"`（最亮帧），配合 fx 里的 `land`（峰值落在片段第几拍，0 表示落在剪点）；
  - `null`：居中。
- 出点 = 入点 + 片段时长 × speed。检测到的"镜头"里常藏着几个子镜头（官方过场快切很多），出点不能跨进下一个子镜头。
- fx 键（详见 `render.py` 开头）：

  | 键 | 作用 |
  |---|---|
  | look | 调色，键名见 `render.py` 的 LOOKS |
  | push | 慢推 |
  | punch | 缩放冲击 |
  | shake | `{amp, decay}` 衰减震屏 |
  | impact | `{n, mode}` 冲击帧，mode 为 negate/white/mono |
  | rgb | 色散 |
  | ramp | `{at, to}` 中途变速 |
  | freeze | `{at, push}` 定格 |
  | open | 从细缝展开 |
  | flash / fade_in / fade_out / flash_out | 白场、黑场淡入淡出 |

  pos_y 和 zoom 由 framing 自动设置。
- 改 spec 时用脚本按 note 匹配整行替换。最后一行后面不能有逗号。
- 报 "needs Xs of a Ys shot"：降低 speed，或换一个更长的镜头。

## 渲染

- 每个片段单独渲染，按内容哈希缓存在 `build/clips/`，最后拼接、混音、编码。只改几镜时几分钟就能重出。`--clips-only` 只填缓存，可以用来检查改动有没有影响其他片段。
- `--draft`：veryfast / crf 26，用于审片。最终版：slow / crf 16，码率上限 25 Mbps，1080p60，AAC 320k。
- 画面区 1920×804（2.39:1），上下各 138 px 黑边。拼接画面的宽高必须是偶数（yuv420p）。
- 音频在最后 0.4 s 淡出，片尾硬切不会爆音。
- 帧率处理（"卡顿"的来源）：
  - 官方上传的 60 fps 视频常常是 30 fps 内容、每帧存两遍。`render.py` 逐片段检测，先去掉重复帧，按真实的 30 fps 处理。
  - 原速片段保持素材自己的节奏，不插帧；放慢的片段才用运动补偿插帧（minterpolate），而且只在真实帧之间插。
  - 每个片段只喂入它所在镜头的帧：插帧和帧率转换会读出点之后的一帧，镜头末尾不截断就会把下一镜混进来，表现为一闪的噪点或残影。不够的帧用最后一帧补足。
  - 插帧在快速动作上会拉扯变形。动作镜头尽量用原速或不低于 0.6 的速度；0.5 以下只给几乎静止的画面。
- 每个剪点都是硬切，没有转场效果（原因见 `mixcut-craft`）。

## 看帧审片

| 脚本 | 用途 |
|---|---|
| `shotsheet.py out_dir src…` | 每镜一帧，按视频浏览，核对归属 |
| `peaksheet.py out.jpg src:shot,shot …` | 运动峰值帧，带方向箭头、速度、亮度；挑张力镜头。环境变量 COLS、CW 控制列数和格宽 |
| `strips.py out.jpg n spec…` | 逐帧条带。spec 可以是 `src:shot`、`src:t0:t1`、`src:all`（整片，每行 n 秒，读故事用）、`part.json:a-b`（片段表第 a 到 b 镜，每镜一行，渲染前逐镜检查）。找精确入出点，发现隐藏的剪切 |
| `matchcut.py out.jpg "A池" "B池" [n]` | 章节衔接候选；池写作 `src` 或 `src:shot+shot`。只排除全局禁用，按剪辑的禁用由你选池时避开，`edl_check` 兜底 |
| `framesheet.py video out.jpg cols t…` | 在成片剪点前后抽帧复查 |
| `video_sheet.py video edl prefix` | 每个片段中点的分镜表 |
| `findframe.py ref.png video…` | 根据截图找它在哪个视频、哪一秒 |

图片用 Read 查看。一张图别超过约 200 格，否则看不清。

封面见 `mixcut-cover` skill。

## 已知的坑

- 自动检测的镜头边界不能精确到帧：叠化和快切会被合成一个镜头，镜头最后一帧可能已经属于下一镜。
- 视觉标签（`analysis/tags`）由模型生成，不可靠：标成"无字幕"的镜头可能有字幕。字幕裁切按整个视频判断，不按单镜标签。
- 音乐视频（EP、MV）常叠着界面图形（准星、面板、进度条、HUD 圆环）和烧录歌词，镜头结尾还会有故障风过场。选用前逐帧看清。
- 官方过场常把前半段原样重播，用 dupes 查。
- 有些源视频的 crop 宽度超出画面，要用 `min(cw, width − cx)` 夹紧；现有脚本都已处理。
- 在 `sh -c` 里写 ffmpeg drawtext 很容易转义出错，图上的标签改用 PIL 画。
- 我听不到音频：节拍网格要请用户听 click 文件确认，成片卡点也要请用户试听。
