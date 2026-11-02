---
name: review-with-me
description: 带用户审查代码修改：在本地差异界面自由选区、圈画、跨文件评论，把反馈实时送回当前 Agent，保留版本与审阅进度。用于“带我审查”、交互式代码审阅、处理界面反馈和继续上次审阅。
---

# Review With Me

把用户选中的代码、反馈和 Agent 的修改连成一个可继续的审阅过程。
默认使用中文。审什么、哪些内容需要通过、通过到哪里，以用户要求为准。

入口是本技能的 `scripts/review.py`，下面用 `<review>` 代替其路径。
从被审仓库的根目录运行，记录使用相对路径，如 `.review/auth.json`。
Python 标准库即可运行；前端已打包，使用时不安装 npm 依赖。

## 开始与继续

先读仓库指令，确认用户指定的基线和范围。不要把整个仓库自动当成审阅范围。
检查是否已有对应记录；继续已有审阅时先 `show`，不要重建或覆盖记录。

```sh
python3 <review> init --state .review/auth.json \
  --title '登录身份与调用路径' --base origin/main --paths src/auth tests/auth
python3 <review> capture --state .review/auth.json --label '首次实现'
python3 <review> show --state .review/auth.json
```

`--base` 在初始化时解析为固定 commit；`capture` 默认读取当前工作区，
包括范围内未被忽略的新文件。`--head <commit>` 可登记已提交版本。
需要讨论未修改的上下文文件时，用 `capture --include path/to/file` 加入。
范围内所有改动始终可见；分组只是导航，不会把未分组文件藏起来。

按用户要判断的行为分组，说明实际调用路径、改了什么、为什么需要这样改。
不要为每个文件机械建一个组。只有用户关心的验收条件才放进 `checks`。

```sh
python3 <review> apply --state .review/auth.json --input - <<'JSON'
{
  "op": "group", "id": "identity", "title": "登录返回身份",
  "summary": "authenticate 返回身份；login 和服务调用方据此处理成功与失败。",
  "paths": ["src/auth/identity.py", "src/auth/login.py"],
  "checks": [{"id": "empty-token", "text": "空令牌保持未授权响应"}]
}
JSON
```

## 实时连接

每份记录绑定当前聊天。优先使用 `CODEX_THREAD_ID`；缺失时用可用的聊天工具
确认当前聊天，不要猜另一个聊天的 ID。不要新建聊天代替当前审阅。

```sh
python3 <review> apply --state .review/auth.json --input - <<JSON
{"op":"listen","thread_id":"$CODEX_THREAD_ID","enabled":true}
JSON
python3 <review> serve --state .review/auth.json --port 0
```

由 Agent 用独立后台进程或持久终端会话启动服务；若工具会清理终端子进程，使用
`nohup` 或 `subprocess.Popen(start_new_session=True)` 并将输出写入审阅目录的服务日志。
读取输出的 `Review frontend: http://127.0.0.1:…`，
验证 `/api/state`，再把可点击链接给用户。不要只给启动命令让用户操作。
同一记录通过进程锁限制为一个服务；重复 `serve` 返回现有地址。
地址失效时先恢复服务，再给链接。需要本机网络访问权限时申请具体权限。

界面提交后先持久保存，再立即用本机 `codex queue --thread … --message …` 投递。
Agent 正在执行任务时，消息进入同一聊天的队列；不能把“已投递”说成“已经处理”。
页面通过事件流接收回复、审阅决定和新版本，不依赖定时自动化。
投递失败展示原因并保留反馈；修复连接后用 `retry` 或界面的“重新投递”。

用户暂停反馈后不再投递新消息，也不认领新工作。重启服务不自动恢复。
只有用户点击“恢复反馈”或明确要求继续时才能恢复。迁移旧记录时，如果存在旧版
心跳自动化，通过自动化工具停用对应那一条，避免继续调用已移除的旧入口。

## 处理用户反馈

收到界面消息后先检查 `show` 的 `listener.enabled`，再认领一次：

```sh
python3 <review> inbox --state .review/auth.json --claim
```

事件给出讨论 ID、版本、对比基线、全部选区、原文、圈画点、建议代码和对话。
反馈可关联多个文件、旧侧/新侧、多行或部分文字。一起阅读这些位置，不要只处理
第一个选区。`targets: []` 是本次审阅的整体反馈。

1. 用 `diff --revision … --against … --path …` 读取用户当时看到的代码，
   同时查看当前源码。旧标注不会自动挪到新代码上。
2. 回答问题，或按要求修改代码。审阅不额外授权提交、发布、重建系统等行为。
3. 代码变化后先 `capture --label '这轮改了什么'`。新版本只重置变化文件的
   审阅决定；未变文件保持进度，旧版本与讨论继续可读。
4. `reply` 解释处理结果。确实处理完才 `resolve`，不要用关闭讨论代替回答。

```sh
python3 <review> apply --state .review/auth.json --input - <<'JSON'
{"op":"reply","id":"讨论 ID","body":"空令牌仍返回 None；调用方在新版本中返回 401。","resolve":true}
JSON
```

回复只确认当前回合认领过的反馈，新到的消息等待下一轮。
中断后的 `processing` 反馈用 `retry` 明确重投，再认领；不要无限重复修改。

## 调整范围和通过要求

CLI 与界面共用 `apply` 操作；支持单条对象和原子批量数组。
具体字段和例子见 [references/api.md](references/api.md)，操作前按需阅读。

- `group` / `ungroup`：调整行为分组、路径、验收条件；不删除文件和评论。
- `comment`：添加 Agent 解释、行内说明、跨文件标注或建议代码。
- `decide`：逐文件、逐块或任意行选区设为 `pending`、`accepted`、`excluded`。
- `check`：登记用户要求的验收条件及结果。
- `reply` / `resolve`：回复、解决、重新打开讨论。
- `listen` / `retry`：暂停、恢复、重投反馈。

通过由用户决定。用户明确说“这几个通过”时，可登记对应范围，在 `reason` 写清
该指示；不能因为 Agent 写完代码或测试通过就替用户全量通过。验收条件若是
可执行的检查，可按实际结果登记并说明。排除必须给原因，始终可见且可撤销，
不等于通过。未解决的问题阻止对应文件通过。不要为进度数字排除生产代码或关闭评论。

## 界面与迁移

使用 Mantine 控件和 Pierre Diffs。左侧文件导航，中间差异，右侧按需讨论：
拖选行号、Shift 扩展、文字选择、圈画、多处/跨文件标注、建议代码、回复和解决；
可筛选文件、对比已登记版本、展开上下文、逐文件/块审阅和查看通过条件。
草稿与阅读位置保存在浏览器；已提交内容保存在仓库内记录中。

旧 v2/v3 JSON 不自动覆盖。需要继续旧记录时：

```sh
python3 <review> import --from .review/old.json --state .review/current.json
```

导入读取旧记录引用的 Git 对象，保留历史代码、评论和有效的文件/块决定。
旧记录及其 Git refs 不删除。导入后检查版本与未解决反馈，再绑定当前聊天；
旧投递队列不自动重发。不可用的历史引用直接报错，不能伪造旧代码。

## 维护验证

从技能目录运行：

```sh
python3 -m unittest discover -s scripts/tests -v
npm --prefix scripts/web-src run build
```

仅在前端源码变化后打包。测试使用既有 Git 历史的临时克隆，不创建 commit。
界面改动还须实测选区、圈画、发送、Agent 回复、新版本、窄屏和键盘操作。
