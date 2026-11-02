# CLI / action API

`scripts/review.py` 的结果是 JSON，错误写 stderr 并返回非零状态。
记录必须是当前仓库内相对路径。操作在文件锁内原子保存；批量任一操作失败，
整批不写入。不修改 Git index、refs 或提交历史。

## 读取

```sh
python3 <review> show --state .review/auth.json
python3 <review> diff --state .review/auth.json --revision r2 --against r1 --path src/auth.py
python3 <review> inbox --state .review/auth.json
python3 <review> inbox --state .review/auth.json --claim
```

`show` 返回版本、文件状态、改动块、分组、验收条件、讨论与监听状态；
`diff` 还包含文件两侧完整文本。省略 revision 使用最新版，against 默认
`base`（初始化基线），也可选择任意另一版本。

`capture --label '…' [--head COMMIT] [--include path …]` 登记新版本。
相同文本不重复登记；include 可加入范围内未修改的上下文文件。

## 写入

```sh
python3 <review> apply --state .review/auth.json --input actions.json
python3 <review> apply --state .review/auth.json --input - <<'JSON'
[
  {"op":"group","id":"auth","title":"认证与调用方","summary":"实际调用路径与设计理由","paths":["src/auth.py","src/login.py"],"checks":[{"id":"empty","text":"空令牌返回未授权"}]},
  {"op":"comment","kind":"note","body":"这个检查在外部输入进入的位置执行。","targets":[{"path":"src/auth.py","side":"new","start":4,"end":8}]}
]
JSON
```

CLI 作者固定为 agent，浏览器固定为 user，请求不能伪装作者。
操作返回生成的 ID 或结果；数组按顺序执行。

| op | 字段 | 效果 |
| --- | --- | --- |
| capture | label；可选 head, include | 登记版本 |
| group | 可选 id；新建需 title；可更新 summary, paths, checks | 同 ID 更新指定字段；paths / checks 整体替换 |
| ungroup | id | 移除导航分组，不删文件和评论 |
| comment | body；可选 id, kind, revision, against, targets, suggestion | 新讨论；kind 为 question / change / bug / note |
| reply | id, body；可选 resolve | 追加回复，只确认已认领消息 |
| resolve | id, status | open / resolved / dismissed；Agent 先回复 |
| decide | path / paths / targets 三选一, status；可选 revision, block, reason | pending / accepted / excluded；block ID 来自基线比较的 show |
| check | 条件 id, status；可选 revision, reason | pending / passed / failed |
| listen | 可选 thread_id, enabled | 绑定当前聊天或暂停 / 恢复 |
| retry | 可选讨论 id | 失败、已投递未处理、处理中消息重新入队；省略 ID 作用于全部 |

Agent 执行 `decide accepted` 必须有 reason，记录用户已给出的通过指示。
excluded 必须给原因；Agent 登记 check passed 必须说明检查结果或用户指示。
决定对应完整基线差异，不能拿版本之间的块 ID 标记累计代码通过。
`decide targets` 接收下述行选区格式，可跨文件；全部目标必须是 old/new 行选区，
不能混入 side:file。只通过选中的行，不把剩余代码自动算作通过。
show 的 summary 分别给出待审文件、待确认条件、未解决讨论及 complete。

## 标注位置

讨论可关联多文件、多处代码；空 targets 是整体评论。

```json
{
  "op": "comment", "revision": "r2", "against": "base", "kind": "change",
  "body": "这两处的空值处理要保持一致。",
  "targets": [
    {"path":"src/auth.py","side":"new","start":10,"end":12,"quote":"return None"},
    {"path":"src/login.py","side":"old","start":7,"end":7},
    {"path":"tests/auth.py","side":"file"}
  ],
  "suggestion": "return None"
}
```

start/end 为对应一侧的 1-based 闭区间，end 默认 start。
quote 可为部分文字，须出现在指定行内；省略则保存整段代码。side:file 不需行号。
圈画由 UI 生成 `drawing: {points: [[x,y],…], width: 800}`，坐标为选中行区域内
0–1 的位置。width 保存绘制时的代码区域宽度，防止打开讨论面板后圈画横向漂移。
Agent 根据行号与原文理解语义，不猜像素位置代表什么。

## 实时行为

界面 POST `/api/action` 后内容已落盘，服务随即调用 codex queue；失败保留反馈。
停止监听不撤回已进入聊天的消息。`inbox --claim` 暂停时返回空数组，正常认领
同一消息只取得一次。中断后用 retry 恢复，避免无条件重跑处理中工作。

页面 SSE `/api/events` 接收变化通知，再获取 `/api/state`；文件按需从
`/api/file?revision=r2&against=base&path=…` 读取。服务限 loopback；变更请求要求
同源和页面随机令牌。Agent 使用 CLI，无需获取页面令牌。
