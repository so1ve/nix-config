import "@mantine/core/styles.css";
import "./fonts-latin.css";
import {
  Alert,
  Button,
  Checkbox,
  Drawer,
  MantineProvider,
  Modal,
  SegmentedControl,
  Textarea,
  TextInput,
  createTheme,
} from "@mantine/core";
import { useMediaQuery } from "@mantine/hooks";
import { Component, useCallback, useEffect, useRef, useState } from "react";
import { createRoot } from "react-dom/client";
import { CodeCanvas } from "./CodeCanvas";
import "./review.css";

const token = document.querySelector('meta[name="review-token"]').content;
const statuses = {
  pending: "待审",
  feedback: "待回应",
  accepted: "已通过",
  excluded: "已排除",
};
const deliveries = {
  queued: "已保存 · 等待投递",
  delivered: "已投递到当前聊天",
  processing: "Agent 处理中",
  answered: "Agent 已回复",
  failed: "投递失败",
};
const kinds = {
  question: "提问",
  change: "要求修改",
  bug: "指出问题",
  note: "备注",
};

async function api(url, action, signal) {
  const response = await fetch(
    url,
    action
      ? {
          method: "POST",
          headers: {
            "Content-Type": "application/json",
            "X-Review-Token": token,
          },
          body: JSON.stringify(action),
          signal,
        }
      : { signal },
  );
  const data = await response.json();
  if (!response.ok)
    throw new Error(data.error || `请求失败：${response.status}`);
  return data;
}
function targetLabel(target) {
  return `${target.path}${target.side === "file" ? "" : ` · ${target.side === "old" ? "旧" : "新"} ${target.start}${target.end !== target.start ? `–${target.end}` : ""} 行`}`;
}
function Empty({ children }) {
  return <div className="empty-state">{children}</div>;
}
function Status({ value }) {
  return (
    <span className={`status status-${value}`}>{statuses[value] || value}</span>
  );
}

class ErrorBoundary extends Component {
  state = { error: null };
  static getDerivedStateFromError(error) {
    return { error };
  }
  render() {
    return this.state.error ? (
      <Empty>
        <h1>界面遇到错误</h1>
        <p>{this.state.error.message}</p>
        <Button onClick={() => window.location.reload()}>重新载入</Button>
      </Empty>
    ) : (
      this.props.children
    );
  }
}

function App() {
  const [data, setData] = useState(null);
  const [revision, setRevision] = useState("");
  const [against, setAgainst] = useState("base");
  const [path, setPath] = useState("");
  const [file, setFile] = useState(null);
  const [groupId, setGroupId] = useState("");
  const [search, setSearch] = useState("");
  const [filter, setFilter] = useState("all");
  const [style, setStyle] = useState("unified");
  const [expanded, setExpanded] = useState(false);
  const [panel, setPanel] = useState(false);
  const [nav, setNav] = useState(false);
  const [draft, setDraft] = useState(null);
  const [drawing, setDrawing] = useState(false);
  const [focused, setFocused] = useState(null);
  const [jump, setJump] = useState(null);
  const [error, setError] = useState("");
  const [fileError, setFileError] = useState("");
  const [connected, setConnected] = useState(false);
  const [busy, setBusy] = useState(false);
  const [exclude, setExclude] = useState(null);
  const [excludeReason, setExcludeReason] = useState("");
  const [allThreads, setAllThreads] = useState(false);
  const [help, setHelp] = useState(false);
  const [linePicker, setLinePicker] = useState(null);
  const narrow = useMediaQuery("(max-width: 950px)");
  const fetchSequence = useRef(0);
  const restored = useRef(false);
  const draftKey = data
    ? `rwm:draft:${data.repo}:${data.title}:${data.base}`
    : null;
  const selectionKey = data
    ? `rwm:position:${data.repo}:${data.title}:${data.base}`
    : null;
  const query = new URLSearchParams({
    against,
    ...(revision ? { revision } : {}),
  }).toString();

  const refresh = useCallback(async () => {
    const seq = ++fetchSequence.current;
    try {
      const value = await api(`/api/state?${query}`);
      if (seq !== fetchSequence.current) return;
      setData(value);
      if (!revision && value.revision) setRevision(value.revision);
      setError("");
    } catch (err) {
      if (seq === fetchSequence.current) setError(err.message);
    }
  }, [query, revision]);

  useEffect(() => {
    refresh();
  }, [refresh]);
  useEffect(() => {
    const events = new EventSource("/api/events");
    events.onopen = () => setConnected(true);
    events.onmessage = () => {
      setConnected(true);
      refresh();
    };
    events.onerror = () => setConnected(false);
    return () => events.close();
  }, [refresh]);
  useEffect(() => {
    if (!data || restored.current) return;
    restored.current = true;
    try {
      const saved = JSON.parse(localStorage.getItem(selectionKey) || "null");
      if (saved) {
        setPath(saved.path);
        if (data.revisions.some((r) => r.id === saved.revision))
          setRevision(saved.revision);
        if (
          saved.against === "base" ||
          data.revisions.some((r) => r.id === saved.against)
        )
          setAgainst(saved.against);
      }
      const savedDraft = JSON.parse(localStorage.getItem(draftKey) || "null");
      if (savedDraft) {
        setDraft(savedDraft);
        setPanel(true);
      }
    } catch {
      /* Browser storage can be unavailable; the review itself is on disk. */
    }
  }, [data, draftKey, selectionKey]);
  useEffect(() => {
    if (!draftKey) return;
    try {
      draft
        ? localStorage.setItem(draftKey, JSON.stringify(draft))
        : localStorage.removeItem(draftKey);
    } catch {
      /* Keep the in-memory draft. */
    }
  }, [draft, draftKey]);
  useEffect(() => {
    if (!selectionKey) return;
    try {
      localStorage.setItem(
        selectionKey,
        JSON.stringify({ path, revision, against }),
      );
    } catch {
      /* Navigation still works without browser storage. */
    }
  }, [path, revision, against, selectionKey]);

  const group = data?.groups.find((g) => g.id === groupId);
  const visibleFiles =
    data?.files.filter(
      (f) =>
        (!group || group.paths.includes(f.path)) &&
        f.path.toLowerCase().includes(search.toLowerCase()) &&
        (filter === "all" ||
          (filter === "pending"
            ? ["pending", "feedback"].includes(f.review_status)
            : f.review_status === filter)),
    ) || [];
  const selectedMeta = data?.files.find((f) => f.path === path);
  const relevantGroups =
    data?.groups.filter((g) => g.paths.includes(path)) || [];
  const discussions =
    data?.threads.filter(
      (t) =>
        allThreads ||
        !t.targets.length ||
        t.targets.some((a) => a.path === path),
    ) || [];
  const currentThreads =
    data?.threads.filter(
      (t) => t.revision === revision && t.against === against,
    ) || [];
  const selectedTargets = [
    ...(draft?.revision === revision && draft?.against === against
      ? draft.targets
      : []),
    ...(focused?.revision === revision && focused?.against === against
      ? focused.targets
      : []),
  ];
  const openCount =
    data?.threads.filter((t) => t.status === "open").length || 0;

  useEffect(() => {
    if (data?.revision === revision)
      setPath((current) =>
        data.files.some((f) => f.path === current)
          ? current
          : visibleFiles[0]?.path || data.files[0]?.path || "",
      );
  }, [data, revision]);
  useEffect(() => {
    if (!path || !data?.revision) {
      setFile(null);
      return;
    }
    const controller = new AbortController();
    setFile(null);
    setFileError("");
    api(
      `/api/file?${query}&path=${encodeURIComponent(path)}`,
      null,
      controller.signal,
    )
      .then(setFile)
      .catch((err) => {
        if (err.name !== "AbortError") setFileError(err.message);
      });
    return () => controller.abort();
  }, [path, query, data?.revision]);

  async function action(value) {
    setBusy(true);
    try {
      await api("/api/action", value);
      await refresh();
      return true;
    } catch (err) {
      setError(err.message);
      return false;
    } finally {
      setBusy(false);
    }
  }

  const selectTargets = useCallback(
    (newTargets) => {
      setDraft((old) => {
        if (old && (old.revision !== revision || old.against !== against)) {
          setError("草稿属于另一个版本。请先发送或放弃草稿，再标注这个版本。");
          return old;
        }
        const combined = [...(old?.targets || [])];
        for (const target of newTargets) {
          if (
            !combined.some(
              (existing) => JSON.stringify(existing) === JSON.stringify(target),
            )
          )
            combined.push(target);
        }
        return {
          revision,
          against,
          body: "",
          kind: "question",
          suggestion: "",
          ...old,
          targets: combined,
        };
      });
      setPanel(true);
    },
    [revision, against],
  );

  function showThread(thread, target = thread.targets[0]) {
    setFocused(thread);
    setPanel(true);
    setRevision(thread.revision);
    setAgainst(thread.against);
    if (target) {
      setPath(target.path);
      setExpanded(true);
      setJump({ ...target });
    }
    requestAnimationFrame(() =>
      document
        .getElementById(`thread-${thread.id}`)
        ?.scrollIntoView({ block: "nearest" }),
    );
  }
  function changeFile(value) {
    setPath(value);
    setNav(false);
    setDrawing(false);
    setJump(null);
  }
  function moveFile(offset) {
    const index = visibleFiles.findIndex((f) => f.path === path);
    if (visibleFiles.length)
      changeFile(
        visibleFiles[
          (index + offset + visibleFiles.length) % visibleFiles.length
        ].path,
      );
  }
  function decide(status, block) {
    const value = {
      op: "decide",
      revision,
      path,
      status,
      ...(block !== undefined ? { block } : {}),
    };
    if (status === "excluded") {
      setExclude(value);
      setExcludeReason("");
    } else action(value);
  }
  async function decideSelection(status) {
    const value = {
      op: "decide",
      revision: draft.revision,
      against: draft.against,
      targets: draft.targets,
      status,
    };
    if (status === "excluded") {
      setExclude(value);
      setExcludeReason("");
    } else if (await action(value)) setDraft(null);
  }

  useEffect(() => {
    const keys = (event) => {
      if (
        event.target.closest("input,textarea,select,[contenteditable=true]") ||
        event.ctrlKey ||
        event.metaKey ||
        event.altKey
      )
        return;
      if (event.key === "?") setHelp(true);
      if (event.key === "j") moveFile(1);
      if (event.key === "k") moveFile(-1);
      if (event.key === "c" && path) selectTargets([{ path, side: "file" }]);
      if (event.key === "Escape") setDrawing(false);
    };
    window.addEventListener("keydown", keys);
    return () => window.removeEventListener("keydown", keys);
  });

  const navigation = (
    <>
      <div className="nav-controls">
        <TextInput
          label="查找文件"
          placeholder="搜索路径…"
          value={search}
          onChange={(e) => setSearch(e.target.value)}
        />
        <label className="field-label">
          审查范围
          <select value={groupId} onChange={(e) => setGroupId(e.target.value)}>
            <option value="">全部文件</option>
            {data?.groups.map((g) => (
              <option key={g.id} value={g.id}>
                {g.title}
              </option>
            ))}
          </select>
        </label>
        <label className="field-label">
          显示
          <select value={filter} onChange={(e) => setFilter(e.target.value)}>
            <option value="all">全部状态</option>
            <option value="pending">待审与待回应</option>
            <option value="accepted">已通过</option>
            <option value="excluded">已排除</option>
          </select>
        </label>
      </div>
      <div className="file-list" aria-label="文件列表">
        {visibleFiles.map((f) => (
          <button
            key={f.path}
            className={`file-link ${path === f.path ? "selected" : ""}`}
            aria-current={path === f.path ? "page" : undefined}
            onClick={() => changeFile(f.path)}
          >
            <span className={`file-symbol ${f.status}`} aria-hidden="true">
              {f.status === "added"
                ? "+"
                : f.status === "deleted"
                  ? "−"
                  : f.status === "renamed"
                    ? "→"
                    : "◇"}
            </span>
            <span className="file-name">
              {f.path.split("/").at(-1)}
              <small>
                {f.path.includes("/")
                  ? f.path.slice(0, f.path.lastIndexOf("/"))
                  : "仓库根目录"}
              </small>
            </span>
            <Status value={f.review_status} />
          </button>
        ))}
        {!visibleFiles.length && <Empty>没有匹配的文件</Empty>}
      </div>
      <div className="nav-footer">
        {visibleFiles.length} 个文件
        <Button
          variant="subtle"
          size="compact-sm"
          onClick={() => setHelp(true)}
        >
          快捷键
        </Button>
      </div>
    </>
  );

  const conversation = (
    <div className="conversation">
      <div className="panel-heading">
        <h2>讨论</h2>
        <Button
          variant="subtle"
          size="compact-sm"
          onClick={() => setPanel(false)}
        >
          关闭
        </Button>
      </div>
      {draft && (
        <form
          className="composer"
          onSubmit={async (event) => {
            event.preventDefault();
            if (await action({ op: "comment", ...draft })) {
              setDraft(null);
              setFocused(null);
            }
          }}
        >
          <div className="composer-title">
            新标注 <span>{draft.revision}</span>
          </div>
          <ul className="target-list">
            {draft.targets.map((t, i) => (
              <li key={i}>
                <span>
                  {targetLabel(t)}
                  {t.drawing && " · 圈画"}
                </span>
                <button
                  type="button"
                  aria-label={`移除选区 ${i + 1}`}
                  onClick={() =>
                    setDraft({
                      ...draft,
                      targets: draft.targets.filter((_, index) => i !== index),
                    })
                  }
                >
                  ×
                </button>
              </li>
            ))}
          </ul>
          {!draft.targets.length && <p className="muted">本次审阅的整体反馈</p>}
          {!!draft.targets.length &&
            draft.targets.every((t) => t.side !== "file") &&
            draft.against === "base" && (
              <div className="actions">
                <Button
                  variant="default"
                  size="xs"
                  disabled={busy}
                  onClick={() => decideSelection("accepted")}
                >
                  通过所选区域
                </Button>
                <Button
                  variant="subtle"
                  size="xs"
                  disabled={busy}
                  onClick={() => decideSelection("excluded")}
                >
                  排除所选区域
                </Button>
              </div>
            )}
          <label className="field-label">
            反馈类型
            <select
              value={draft.kind}
              onChange={(e) => setDraft({ ...draft, kind: e.target.value })}
            >
              {Object.entries(kinds).map(([key, label]) => (
                <option key={key} value={key}>
                  {label}
                </option>
              ))}
            </select>
          </label>
          <Textarea
            label="反馈内容"
            placeholder="你希望怎么改，或哪里需要解释？"
            autosize
            minRows={3}
            value={draft.body}
            onChange={(e) => setDraft({ ...draft, body: e.target.value })}
            required
          />
          <details>
            <summary>建议代码</summary>
            <Textarea
              aria-label="建议代码"
              autosize
              minRows={3}
              value={draft.suggestion}
              onChange={(e) =>
                setDraft({ ...draft, suggestion: e.target.value })
              }
              className="code-input"
            />
          </details>
          <p className="delivery-hint">
            {data?.listener.enabled
              ? "提交后立即投递到当前聊天。可继续选择其他位置。"
              : "监听已暂停，反馈会保存，恢复后投递。"}
          </p>
          <div className="actions">
            <Button type="submit" loading={busy} disabled={!draft.body.trim()}>
              发送给 Agent
            </Button>
            <Button variant="subtle" onClick={() => setDraft(null)}>
              放弃草稿
            </Button>
          </div>
        </form>
      )}
      <div className="discussion-filter">
        <Checkbox
          label="查看所有文件的讨论"
          checked={allThreads}
          onChange={(e) => setAllThreads(e.target.checked)}
        />
        <Button
          size="compact-sm"
          variant="subtle"
          onClick={() => selectTargets([])}
        >
          整体反馈
        </Button>
      </div>
      <div className="threads">
        {discussions.map((thread) => (
          <Thread
            key={thread.id}
            thread={thread}
            focused={focused?.id === thread.id}
            revision={revision}
            onLocate={(target) => {
              showThread(thread, target);
              if (narrow && target) setPanel(false);
            }}
            action={action}
            busy={busy}
          />
        ))}
        {!discussions.length && (
          <Empty>还没有讨论。选中代码或点击“文件评论”即可开始。</Empty>
        )}
      </div>
    </div>
  );

  return (
    <div className="app">
      <header className="app-header">
        <div className="brand">
          Review <span>with me</span>
        </div>
        <h1>{data?.title || "正在读取审阅…"}</h1>
        <div className="header-actions">
          <span
            className={`connection ${connected ? "online" : "offline"}`}
            role="status"
          >
            {connected ? "页面实时同步" : "连接中断 · 正在重连"}
          </span>
          {data?.listener.thread_id && (
            <Button
              variant="default"
              size="xs"
              onClick={() =>
                action({ op: "listen", enabled: !data.listener.enabled })
              }
            >
              {data.listener.enabled ? "暂停反馈" : "恢复反馈"}
            </Button>
          )}
          <Button variant="default" size="xs" onClick={() => setPanel(!panel)}>
            讨论 {openCount || ""}
          </Button>
        </div>
      </header>
      {error && (
        <Alert
          color="red"
          title="操作未完成"
          withCloseButton
          onClose={() => setError("")}
        >
          {error}
          <Button size="compact-xs" variant="subtle" onClick={refresh}>
            重新读取
          </Button>
        </Alert>
      )}
      {data?.listener.error && (
        <Alert color="red" title="反馈投递失败">
          {data.listener.error}
          <Button
            size="compact-xs"
            variant="subtle"
            onClick={() => action({ op: "retry" })}
          >
            重新投递
          </Button>
        </Alert>
      )}
      {data && !data.listener.thread_id && (
        <div className="notice">
          尚未连接 Agent。标注会保存在本地；请让当前聊天连接这份审阅。
        </div>
      )}
      {data?.revisions.at(-1)?.id !== revision &&
        data?.revisions.length > 0 && (
          <div className="new-version">
            Agent 已更新到 {data.revisions.at(-1).id} ·{" "}
            {data.revisions.at(-1).label}
            <Button
              size="compact-sm"
              onClick={() => {
                setAgainst(revision);
                setRevision(data.revisions.at(-1).id);
              }}
            >
              查看这轮修改
            </Button>
          </div>
        )}
      <div className={`workspace ${panel && !narrow ? "with-discussion" : ""}`}>
        {!narrow && <aside className="navigation">{navigation}</aside>}
        <main className="main">
          <div className="review-toolbar">
            {narrow && (
              <Button variant="default" size="xs" onClick={() => setNav(true)}>
                文件
              </Button>
            )}
            <label>
              版本
              <select
                aria-label="审阅版本"
                value={revision}
                onChange={(e) => {
                  setRevision(e.target.value);
                  setAgainst("base");
                }}
              >
                {data?.revisions.map((r) => (
                  <option value={r.id} key={r.id}>
                    {r.id} · {r.label}
                  </option>
                ))}
              </select>
            </label>
            <label>
              对比
              <select
                aria-label="对比版本"
                value={against}
                onChange={(e) => setAgainst(e.target.value)}
              >
                <option value="base">最初基线</option>
                {data?.revisions
                  .filter((r) => r.id !== revision)
                  .map((r) => (
                    <option value={r.id} key={r.id}>
                      {r.id} · {r.label}
                    </option>
                  ))}
              </select>
            </label>
            <div className="toolbar-spacer" />
            {!narrow && (
              <SegmentedControl
                size="xs"
                aria-label="差异布局"
                value={style}
                onChange={setStyle}
                data={[
                  { value: "unified", label: "合并" },
                  { value: "split", label: "并排" },
                ]}
              />
            )}
          </div>
          {!!relevantGroups.length && (
            <div className="group-context">
              {relevantGroups.map((g) => (
                <details key={g.id} open={groupId === g.id}>
                  <summary>
                    {g.title}
                    {!!g.checks.length && (
                      <span>
                        {
                          g.checks.filter(
                            (c) => data.checks[c.id]?.status === "passed",
                          ).length
                        }
                        /{g.checks.length} 条通过条件
                      </span>
                    )}
                  </summary>
                  {g.summary && <p>{g.summary}</p>}
                  {g.checks.map((c) => (
                    <div className="check-row" key={c.id}>
                      <Checkbox
                        label={c.text}
                        checked={data.checks[c.id]?.status === "passed"}
                        disabled={busy}
                        onChange={(e) =>
                          action({
                            op: "check",
                            revision,
                            id: c.id,
                            status: e.target.checked ? "passed" : "pending",
                          })
                        }
                      />
                      {data.checks[c.id]?.reason && (
                        <small>{data.checks[c.id].reason}</small>
                      )}
                    </div>
                  ))}
                </details>
              ))}
            </div>
          )}
          {selectedMeta && (
            <div className="file-heading">
              <div>
                <h2>{path}</h2>
                {selectedMeta.status === "renamed" && (
                  <small>原路径：{selectedMeta.old_path}</small>
                )}
                <Status value={selectedMeta.review_status} />
              </div>
              <div className="actions">
                <Button
                  variant="default"
                  size="xs"
                  onClick={() => selectTargets([{ path, side: "file" }])}
                >
                  文件评论
                </Button>
                <Button
                  size="xs"
                  variant={drawing ? "filled" : "default"}
                  onClick={() => setDrawing(!drawing)}
                  disabled={
                    !file || file.old?.text === null || file.new?.text === null
                  }
                >
                  {drawing ? "结束圈画" : "圈画"}
                </Button>
                <Button
                  size="xs"
                  variant="default"
                  onClick={() => decide("excluded")}
                  disabled={busy || against !== "base"}
                >
                  排除
                </Button>
                <Button
                  size="xs"
                  onClick={() =>
                    decide(
                      selectedMeta.review_status === "accepted" ||
                        selectedMeta.review_status === "excluded"
                        ? "pending"
                        : "accepted",
                    )
                  }
                  disabled={
                    busy ||
                    against !== "base" ||
                    selectedMeta.review_status === "feedback"
                  }
                >
                  {["accepted", "excluded"].includes(selectedMeta.review_status)
                    ? "重新审阅"
                    : "通过文件"}
                </Button>
              </div>
            </div>
          )}
          {selectedMeta?.decision.reason && (
            <div className="notice">{selectedMeta.decision.reason}</div>
          )}
          <div className="canvas-tools">
            <span>
              {drawing
                ? "在代码上拖动圈画，松开后填写反馈。Esc 退出。"
                : "拖选行号或文字以标注；可连续选择多处。"}
            </span>
            <div className="actions">
              <button
                disabled={!file}
                onClick={() =>
                  setLinePicker({
                    side: file?.new?.text ? "new" : "old",
                    start: 1,
                    end: 1,
                  })
                }
              >
                按行号选择
              </button>
              <button onClick={() => setExpanded(!expanded)}>
                {expanded ? "收起未修改代码" : "展开完整文件"}
              </button>
            </div>
          </div>
          {against !== "base" && (
            <div className="notice">
              正在查看两个版本之间的差异。
              <button onClick={() => setAgainst("base")}>
                回到完整改动以标记通过
              </button>
            </div>
          )}
          <div className="diff-scroll" key={`${path}:${revision}:${against}`}>
            {fileError ? (
              <Empty>
                <p>{fileError}</p>
                <Button
                  onClick={() => {
                    setPath("");
                    refresh();
                  }}
                >
                  重试
                </Button>
              </Empty>
            ) : !path ? (
              <Empty>
                {data?.revisions.length
                  ? "这个范围没有文件差异。"
                  : "还没有审阅版本。请让 Agent 登记这次修改。"}
              </Empty>
            ) : !file ? (
              <Empty>正在读取文件…</Empty>
            ) : file.old?.text === null || file.new?.text === null ? (
              <Empty>
                {file.old?.notice || file.new?.notice}
                <p>仍可进行文件评论、排除或通过。</p>
              </Empty>
            ) : (
              <CodeCanvas
                file={file}
                revision={revision}
                against={against}
                style={narrow ? "unified" : style}
                expanded={expanded}
                drawing={drawing}
                setDrawing={setDrawing}
                targets={selectedTargets}
                threads={currentThreads}
                onSelect={selectTargets}
                onThread={showThread}
                onError={setError}
                jump={jump}
              />
            )}
            {!!file?.blocks.length && (
              <div className="block-list">
                <h3>逐块审阅</h3>
                {file.blocks.map((block, i) => {
                  const decision = selectedMeta?.decision.blocks?.[block.id];
                  const blockStatus =
                    selectedMeta?.blocks.find((b) => b.id === block.id)
                      ?.review_status || "pending";
                  const side = block.new_count ? "new" : "old";
                  const start = block[`${side}_start`];
                  return (
                    <div className="block-row" key={block.id}>
                      <button
                        onClick={() => {
                          setExpanded(true);
                          setJump({
                            path,
                            side,
                            start,
                            end: start + block[`${side}_count`] - 1,
                          });
                        }}
                      >
                        第 {i + 1} 块 · {side === "new" ? "新" : "旧"} {start}{" "}
                        行
                      </button>
                      <Status value={blockStatus} />
                      {decision?.reason && <small>{decision.reason}</small>}
                      <Button
                        size="compact-xs"
                        variant="subtle"
                        onClick={() =>
                          decide(
                            blockStatus !== "pending" ? "pending" : "accepted",
                            block.id,
                          )
                        }
                        disabled={
                          busy ||
                          against !== "base" ||
                          selectedMeta?.review_status === "feedback"
                        }
                      >
                        {blockStatus !== "pending" ? "撤销" : "通过"}
                      </Button>
                      <Button
                        size="compact-xs"
                        variant="subtle"
                        onClick={() => decide("excluded", block.id)}
                        disabled={busy || against !== "base"}
                      >
                        排除
                      </Button>
                    </div>
                  );
                })}
              </div>
            )}
            {!!selectedMeta?.decision.regions?.length && (
              <div className="region-list">
                <h3>选区审阅记录</h3>
                {selectedMeta.decision.regions.map((region, i) => (
                  <div className="block-row" key={i}>
                    <span>
                      {region.side === "old" ? "旧" : "新"} {region.start}–
                      {region.end} 行
                    </span>
                    <Status value={region.status} />
                    {region.reason && <small>{region.reason}</small>}
                    <Button
                      size="compact-xs"
                      variant="subtle"
                      disabled={
                        busy ||
                        against !== "base" ||
                        region.status === "pending"
                      }
                      onClick={() =>
                        action({
                          op: "decide",
                          revision,
                          targets: [
                            {
                              path,
                              side: region.side,
                              start: region.start,
                              end: region.end,
                            },
                          ],
                          status: "pending",
                        })
                      }
                    >
                      重新审阅
                    </Button>
                  </div>
                ))}
              </div>
            )}
          </div>
          <footer className="review-footer">
            <span>
              {data?.files.filter((f) => f.review_status === "accepted")
                .length || 0}{" "}
              / {data?.files.length || 0} 文件通过 ·{" "}
              {data?.files.filter((f) => f.review_status === "excluded")
                .length || 0}{" "}
              已排除
              {data?.summary?.pending_checks
                ? ` · ${data.summary.pending_checks} 条条件待确认`
                : ""}
            </span>
            <div className="actions">
              <Button
                variant="subtle"
                size="compact-sm"
                onClick={() => moveFile(-1)}
                disabled={!visibleFiles.length}
              >
                上一个
              </Button>
              <Button
                variant="subtle"
                size="compact-sm"
                onClick={() => moveFile(1)}
                disabled={!visibleFiles.length}
              >
                下一个 →
              </Button>
            </div>
          </footer>
        </main>
        {panel && !narrow && (
          <aside className="discussion-pane">{conversation}</aside>
        )}
      </div>
      <Drawer
        opened={narrow && nav}
        closeButtonProps={{ "aria-label": "关闭文件导航" }}
        onClose={() => setNav(false)}
        title="审阅文件"
        size="min(340px, 90vw)"
      >
        {navigation}
      </Drawer>
      <Drawer
        opened={narrow && panel}
        closeButtonProps={{ "aria-label": "关闭讨论" }}
        onClose={() => setPanel(false)}
        position="right"
        title="讨论与标注"
        size="min(430px, 95vw)"
      >
        {conversation}
      </Drawer>
      <Modal
        opened={!!exclude}
        closeButtonProps={{ "aria-label": "关闭排除设置" }}
        onClose={() => setExclude(null)}
        title="排除审阅内容"
        centered
      >
        <form
          onSubmit={async (event) => {
            event.preventDefault();
            if (await action({ ...exclude, reason: excludeReason })) {
              if (exclude.targets) setDraft(null);
              setExclude(null);
            }
          }}
        >
          <p className="modal-path">
            {exclude?.path || exclude?.targets.map(targetLabel).join("；")}
          </p>
          <Textarea
            label="排除原因"
            required
            autoFocus
            value={excludeReason}
            onChange={(e) => setExcludeReason(e.target.value)}
          />
          <div className="actions modal-actions">
            <Button
              type="submit"
              loading={busy}
              disabled={!excludeReason.trim()}
            >
              排除
            </Button>
            <Button variant="default" onClick={() => setExclude(null)}>
              取消
            </Button>
          </div>
        </form>
      </Modal>
      <Modal
        opened={!!linePicker}
        closeButtonProps={{ "aria-label": "关闭行号选择" }}
        onClose={() => setLinePicker(null)}
        title="选择代码行"
        centered
      >
        {linePicker && (
          <form
            onSubmit={(event) => {
              event.preventDefault();
              const lines = file?.[linePicker.side]?.text?.split(/\r?\n/) || [];
              if (
                linePicker.end < linePicker.start ||
                linePicker.end > lines.length
              ) {
                setError("行号超出范围，请重新选择。");
                return;
              }
              selectTargets([
                {
                  path,
                  ...linePicker,
                  quote: lines
                    .slice(linePicker.start - 1, linePicker.end)
                    .join("\n"),
                },
              ]);
              setLinePicker(null);
            }}
          >
            <label className="field-label">
              代码版本
              <select
                value={linePicker.side}
                onChange={(e) =>
                  setLinePicker({ ...linePicker, side: e.target.value })
                }
              >
                <option value="new">修改后</option>
                <option value="old">修改前</option>
              </select>
            </label>
            <TextInput
              type="number"
              min={1}
              required
              label="起始行"
              value={linePicker.start}
              onChange={(e) =>
                setLinePicker({ ...linePicker, start: Number(e.target.value) })
              }
            />
            <TextInput
              type="number"
              min={1}
              required
              label="结束行"
              value={linePicker.end}
              onChange={(e) =>
                setLinePicker({ ...linePicker, end: Number(e.target.value) })
              }
            />
            <Button className="modal-actions" type="submit">
              添加选区
            </Button>
          </form>
        )}
      </Modal>
      <Modal
        opened={help}
        closeButtonProps={{ "aria-label": "关闭操作帮助" }}
        onClose={() => setHelp(false)}
        title="审阅操作"
        centered
      >
        <dl className="shortcuts">
          <dt>选择代码</dt>
          <dd>拖选行号或文字。Shift + 点击行号可以扩展选区。</dd>
          <dt>圈画</dt>
          <dd>点击“圈画”，在代码文字上拖动；松开后填写反馈。</dd>
          <dt>多处标注</dt>
          <dd>草稿打开时继续选择其他位置，支持跨文件。</dd>
          <dt>J / K</dt>
          <dd>下一个 / 上一个文件</dd>
          <dt>C</dt>
          <dd>评论当前文件</dd>
          <dt>Esc</dt>
          <dd>退出圈画</dd>
        </dl>
      </Modal>
    </div>
  );
}

function Thread({ thread, focused, revision, onLocate, action, busy }) {
  const [body, setBody] = useState("");
  const [replying, setReplying] = useState(false);
  return (
    <article
      id={`thread-${thread.id}`}
      className={`thread ${focused ? "focused" : ""} ${thread.status !== "open" ? "resolved" : ""}`}
    >
      <div className="thread-heading">
        <strong>{kinds[thread.kind]}</strong>
        <span>
          {thread.status === "open"
            ? "未解决"
            : thread.status === "resolved"
              ? "已解决"
              : "已忽略"}
        </span>
        <button onClick={() => onLocate()}>
          {thread.revision}
          {thread.revision !== revision ? " · 旧版本" : ""}
        </button>
      </div>
      {thread.targets.map((t, i) => (
        <div className="thread-target" key={i}>
          <button onClick={() => onLocate(t)}>
            {targetLabel(t)}
            {t.drawing && " · 圈画"}
          </button>
          {t.quote && <pre>{t.quote}</pre>}
        </div>
      ))}
      {thread.messages.map((m) => (
        <div key={m.id} className={`message ${m.author}`}>
          <div className="message-author">
            {m.author === "agent" ? "Agent" : "你"}
            <time>
              {new Date(m.created * 1000).toLocaleTimeString([], {
                hour: "2-digit",
                minute: "2-digit",
              })}
            </time>
          </div>
          <p>{m.body}</p>
          {m.delivery && (
            <span className={`delivery ${m.delivery}`} role="status">
              {deliveries[m.delivery]}
            </span>
          )}
          {m.error && <p className="message-error">{m.error}</p>}
          {m.delivery === "failed" && (
            <Button
              size="compact-xs"
              variant="subtle"
              onClick={() => action({ op: "retry", id: thread.id })}
            >
              重新投递
            </Button>
          )}
        </div>
      ))}
      {thread.suggestion && (
        <details>
          <summary>建议代码</summary>
          <pre>{thread.suggestion}</pre>
        </details>
      )}
      <div className="actions">
        <Button
          size="compact-sm"
          variant="subtle"
          onClick={() => setReplying(!replying)}
        >
          回复
        </Button>
        <Button
          size="compact-sm"
          variant="subtle"
          disabled={busy}
          onClick={() =>
            action({
              op: "resolve",
              id: thread.id,
              status: thread.status === "open" ? "resolved" : "open",
            })
          }
        >
          {thread.status === "open" ? "标为已解决" : "重新打开"}
        </Button>
      </div>
      {replying && (
        <form
          onSubmit={async (event) => {
            event.preventDefault();
            if (await action({ op: "reply", id: thread.id, body })) {
              setBody("");
              setReplying(false);
            }
          }}
        >
          <Textarea
            label="回复内容"
            autosize
            minRows={2}
            value={body}
            onChange={(e) => setBody(e.target.value)}
            required
          />
          <Button
            type="submit"
            size="xs"
            loading={busy}
            disabled={!body.trim()}
          >
            发送回复
          </Button>
        </form>
      )}
    </article>
  );
}

const theme = createTheme({
  primaryColor: "blue",
  fontFamily:
    '"IBM Plex Sans Variable", -apple-system, BlinkMacSystemFont, "Segoe UI", "Noto Sans CJK SC", sans-serif',
  defaultRadius: "sm",
  headings: { fontFamily: "inherit" },
});
createRoot(document.getElementById("root")).render(
  <MantineProvider theme={theme}>
    <ErrorBoundary>
      <App />
    </ErrorBoundary>
  </MantineProvider>,
);
