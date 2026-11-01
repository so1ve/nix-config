import "./fonts-latin.css";
import "@mantine/core/styles/baseline.css";
import "@mantine/core/styles/default-css-variables.css";
import "@mantine/core/styles/global.css";
import "@mantine/core/styles/ActionIcon.css";
import "@mantine/core/styles/Alert.css";
import "@mantine/core/styles/Badge.css";
import "@mantine/core/styles/Button.css";
import "@mantine/core/styles/Checkbox.css";
import "@mantine/core/styles/CheckboxIndicator.css";
import "@mantine/core/styles/CloseButton.css";
import "@mantine/core/styles/Combobox.css";
import "@mantine/core/styles/Divider.css";
import "@mantine/core/styles/Drawer.css";
import "@mantine/core/styles/Group.css";
import "@mantine/core/styles/Input.css";
import "@mantine/core/styles/Loader.css";
import "@mantine/core/styles/ModalBase.css";
import "@mantine/core/styles/Overlay.css";
import "@mantine/core/styles/Paper.css";
import "@mantine/core/styles/Popover.css";
import "@mantine/core/styles/Progress.css";
import "@mantine/core/styles/Radio.css";
import "@mantine/core/styles/RadioIndicator.css";
import "@mantine/core/styles/ScrollArea.css";
import "@mantine/core/styles/SegmentedControl.css";
import "@mantine/core/styles/Stack.css";
import "@mantine/core/styles/Text.css";
import "@mantine/core/styles/Title.css";
import "@mantine/core/styles/Tooltip.css";
import "@mantine/core/styles/UnstyledButton.css";
import "@mantine/notifications/styles.css";
import {
  ActionIcon,
  Alert,
  Badge,
  Box,
  Button,
  Checkbox,
  Divider,
  Drawer,
  Group,
  Loader,
  MantineProvider,
  Paper,
  Progress,
  Radio,
  ScrollArea,
  SegmentedControl,
  Select,
  Stack,
  Text,
  Textarea,
  Title,
  Tooltip,
  UnstyledButton,
  createTheme,
} from "@mantine/core";
import { useDisclosure, useMediaQuery } from "@mantine/hooks";
import { Notifications, notifications } from "@mantine/notifications";
import { registerCustomTheme } from "@pierre/diffs";
import { MultiFileDiff } from "@pierre/diffs/react";
import pierreLight from "@pierre/highlights/themes/pierre-light";
import {
  Component,
  useCallback,
  useEffect,
  useMemo,
  useRef,
  useState,
} from "react";
import { createRoot } from "react-dom/client";
import "./review.css";

const token = document.querySelector('meta[name="review-token"]').content;

registerCustomTheme(
  "review-light",
  () => Promise.resolve(pierreLight),
  "zed",
);

class AppErrorBoundary extends Component {
  constructor(props) {
    super(props);
    this.state = { error: null };
  }

  static getDerivedStateFromError(error) {
    return { error };
  }

  componentDidCatch(error, info) {
    console.error("Review UI failed to render", error, info);
  }

  render() {
    if (this.state.error) {
      return (
        <div className="fatal-error">
          <h1>审阅界面无法渲染</h1>
          <pre>{this.state.error.stack || this.state.error.message}</pre>
        </div>
      );
    }
    return this.props.children;
  }
}

const STATUS_LABELS = {
  unreviewed: "待审阅",
  reviewing: "审阅中",
  feedback: "待回应",
  revisit: "需复查",
  accepted: "已确认",
  superseded: "已替代",
};
const STATUS_COLORS = {
  unreviewed: "yellow",
  reviewing: "blue",
  feedback: "rust",
  revisit: "orange",
  accepted: "teal",
  superseded: "gray",
};
const KIND_LABELS = {
  question: "问题",
  bug: "缺陷",
  change: "修改",
  note: "备注",
  answer: "回答",
};
const FILE_STATUS_LABELS = {
  added: "新增",
  deleted: "删除",
  modified: "修改",
  renamed: "重命名",
  copied: "复制",
  type_changed: "类型变化",
};
const ANNOTATION_STATUS_LABELS = {
  open: "未解决",
  resolved: "已解决",
  dismissed: "已忽略",
};
const ACTIONABLE_KINDS = new Set(["question", "bug", "change"]);
const DIFF_CSS = `
[data-diffs-header] {
  font-family: var(--review-sans);
  background:
    linear-gradient(90deg, color-mix(in lab, var(--diffs-bg) 96%, #c44932), var(--diffs-bg) 45%);
}

[data-line] {
  border-bottom: 1px solid color-mix(in lab, var(--diffs-bg) 94%, var(--diffs-fg));
}

[data-column-number] {
  border-right-color: color-mix(in lab, var(--diffs-bg) 90%, var(--diffs-fg)) !important;
}

[data-separator="line-info-basic"] {
  background: color-mix(in lab, var(--diffs-bg) 97%, var(--diffs-fg));
}

[data-separator-wrapper] {
  font-size: 11px;
}
`;

const theme = createTheme({
  fontFamily: '"IBM Plex Sans Variable", "Noto Sans SC", sans-serif',
  fontFamilyMonospace:
    '"JetBrains Mono", "SFMono-Regular", Menlo, Consolas, monospace',
  headings: {
    fontFamily:
      '"Iowan Old Style", "Palatino Linotype", Palatino, "Noto Serif SC", Georgia, serif',
    fontWeight: "560",
  },
  primaryColor: "rust",
  primaryShade: 6,
  defaultRadius: "sm",
  colors: {
    rust: [
      "#fcf0ec",
      "#f6ded7",
      "#eebfb2",
      "#e59d8b",
      "#dc7f69",
      "#d3654e",
      "#c44932",
      "#a63b29",
      "#873022",
      "#6f291e",
    ],
  },
  components: {
    Button: {
      defaultProps: { radius: "sm" },
    },
    Badge: {
      defaultProps: { radius: "sm" },
    },
    Paper: {
      defaultProps: { radius: "sm" },
    },
  },
});

function openFeedback(change) {
  return change.annotations.filter(
    (note) =>
      note.status === "open" &&
      note.author === "user" &&
      ACTIONABLE_KINDS.has(note.kind),
  );
}

function shortRef(value) {
  if (!value) return "—";
  return value === "WORKTREE" ? "工作区" : value.slice(0, 9);
}

function signatureFor(state, runtime) {
  return [
    runtime.worktree_fingerprint,
    runtime.branch,
    runtime.head,
    JSON.stringify(runtime.unmapped),
    JSON.stringify(runtime.newer_worktree),
    JSON.stringify(state),
  ].join("|");
}

async function getJSON(path, signal) {
  const response = await fetch(path, {
    headers: { Accept: "application/json" },
    cache: "no-store",
    signal,
  });
  if (!response.ok) {
    const payload = await response.json().catch(() => ({}));
    throw new Error(payload.error || `请求失败 (${response.status})`);
  }
  return response.json();
}

async function mutate(path, body) {
  const response = await fetch(path, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      "X-Review-Token": token,
    },
    body: JSON.stringify(body),
  });
  if (!response.ok) {
    const payload = await response.json().catch(() => ({}));
    throw new Error(payload.error || `操作失败 (${response.status})`);
  }
  return response.json();
}

function reportError(error) {
  notifications.show({
    color: "red",
    title: "操作没有完成",
    message: error.message,
    autoClose: 5200,
  });
}

function App() {
  const [snapshot, setSnapshot] = useState(null);
  const [selection, setSelection] = useState({
    changeId: null,
    revisionId: null,
  });
  const [filter, setFilter] = useState("open");
  const [mode, setMode] = useState("round");
  const [view, setView] = useState("unified");
  const [context, setContext] = useState("3");
  const [filePath, setFilePath] = useState(null);
  const [diff, setDiff] = useState(null);
  const [diffLoading, setDiffLoading] = useState(false);
  const [diffError, setDiffError] = useState("");
  const [diffEpoch, setDiffEpoch] = useState(0);
  const [connection, setConnection] = useState("loading");
  const [composer, setComposer] = useState(null);
  const [replyTo, setReplyTo] = useState(null);
  const [focusedNote, setFocusedNote] = useState(null);
  const [hunkIndex, setHunkIndex] = useState(-1);
  const [mapOpened, mapControls] = useDisclosure(false);
  const [notesOpened, notesControls] = useDisclosure(false);
  const compactInspector = useMediaQuery("(max-width: 1240px)");
  const compactMap = useMediaQuery("(max-width: 900px)");
  const signatureRef = useRef("");
  const viewportRef = useRef(null);

  const loadState = useCallback(
    async ({ forceDiff = false, quiet = false } = {}) => {
      try {
        const payload = await getJSON("/api/state");
        setConnection("live");
        const signature = signatureFor(payload.state, payload.runtime);
        if (signature !== signatureRef.current) {
          signatureRef.current = signature;
          setSnapshot(payload);
          setSelection((previous) => {
            const retained = payload.state.changes.find(
              (change) => change.id === previous.changeId,
            );
            if (
              retained?.revisions.some(
                (revision) => revision.id === previous.revisionId,
              )
            ) {
              return previous;
            }
            const first =
              payload.state.changes.find(
                (change) =>
                  !["accepted", "superseded"].includes(change.status),
              ) || payload.state.changes[0];
            return {
              changeId: first?.id || null,
              revisionId: first?.revisions.at(-1)?.id || null,
            };
          });
        }
        if (forceDiff) setDiffEpoch((value) => value + 1);
        return payload;
      } catch (error) {
        setConnection("error");
        if (!quiet) reportError(error);
        return null;
      }
    },
    [],
  );

  useEffect(() => {
    loadState();
    const timer = window.setInterval(() => {
      if (!document.hidden) loadState({ quiet: true });
    }, 2400);
    const onVisibility = () => {
      if (!document.hidden) loadState({ quiet: true });
    };
    document.addEventListener("visibilitychange", onVisibility);
    return () => {
      window.clearInterval(timer);
      document.removeEventListener("visibilitychange", onVisibility);
    };
  }, [loadState]);

  const change =
    snapshot?.state.changes.find(
      (item) => item.id === selection.changeId,
    ) || null;
  const revision =
    change?.revisions.find(
      (item) => item.id === selection.revisionId,
    ) ||
    change?.revisions.at(-1) ||
    null;
  const file =
    diff?.files.find((item) => item.path === filePath) ||
    diff?.files[0] ||
    null;

  useEffect(() => {
    if (!selection.changeId || !selection.revisionId) {
      setDiff(null);
      return undefined;
    }
    const controller = new AbortController();
    const query = new URLSearchParams({
      change: selection.changeId,
      revision: selection.revisionId,
      mode,
    });
    setDiffLoading(true);
    setDiffError("");
    getJSON(`/api/diff?${query}`, controller.signal)
      .then((payload) => {
        setDiff(payload);
        setFilePath((previous) =>
          payload.files.some((item) => item.path === previous)
            ? previous
            : payload.files[0]?.path || null,
        );
        setHunkIndex(-1);
      })
      .catch((error) => {
        if (error.name !== "AbortError") setDiffError(error.message);
      })
      .finally(() => {
        if (!controller.signal.aborted) setDiffLoading(false);
      });
    return () => controller.abort();
  }, [
    selection.changeId,
    selection.revisionId,
    mode,
    snapshot?.runtime.worktree_fingerprint,
    diffEpoch,
  ]);

  const selectChange = useCallback(
    (changeId, revisionId = null) => {
      const nextChange = snapshot?.state.changes.find(
        (item) => item.id === changeId,
      );
      setSelection({
        changeId,
        revisionId: revisionId || nextChange?.revisions.at(-1)?.id || null,
      });
      setFilePath(null);
      setComposer(null);
      setReplyTo(null);
      setFocusedNote(null);
      setHunkIndex(-1);
      mapControls.close();
    },
    [snapshot, mapControls],
  );

  const selectRevision = useCallback((revisionId) => {
    setSelection((previous) => ({ ...previous, revisionId }));
    setHunkIndex(-1);
  }, []);

  const focusNote = useCallback(
    (note) => {
      setFocusedNote(note.id);
      setReplyTo(null);
      if (compactInspector) notesControls.open();
    },
    [compactInspector, notesControls],
  );

  const openLineComposer = useCallback(
    (range) => {
      if (!file || !range) return;
      const startSide = range.side || "additions";
      const endSide = range.endSide || startSide;
      if (startSide !== endSide) {
        notifications.show({
          color: "orange",
          message: "一条批注只能覆盖同一侧的行，请分别标注删除行和新增行。",
        });
        return;
      }
      const side = startSide === "deletions" ? "old" : "new";
      const start = Math.min(range.start, range.end);
      const end = Math.max(range.start, range.end);
      const lines = (side === "old" ? file.old_text : file.new_text).split(
        "\n",
      );
      setComposer({
        key: `${selection.revisionId}:${file.path}:${side}:${start}:${end}`,
        revision: selection.revisionId,
        side,
        path: file.path,
        start,
        end,
        excerpt: lines
          .slice(Math.max(0, start - 1), end)
          .join("\n")
          .slice(0, 20_000),
        label: `${file.path}:${start}${end === start ? "" : `–${end}`} · ${
          side === "old" ? "旧版" : "新版"
        }`,
      });
      setReplyTo(null);
      setFocusedNote(null);
      if (compactInspector) notesControls.open();
    },
    [compactInspector, file, notesControls, selection.revisionId],
  );

  const openFileComposer = useCallback(
    (changeWide = false) => {
      if (!changeWide && !file) return;
      const path = changeWide ? null : file.path;
      setComposer({
        key: `${selection.revisionId}:${path || "change"}:file`,
        revision: selection.revisionId,
        side: "file",
        path,
        start: null,
        end: null,
        excerpt: "",
        label: path ? `${path} · 文件级批注` : "整个审阅单元",
      });
      setReplyTo(null);
      setFocusedNote(null);
      if (compactInspector) notesControls.open();
    },
    [compactInspector, file, notesControls, selection.revisionId],
  );

  const submitAnnotation = useCallback(
    async (draft) => {
      await mutate("/api/annotations", {
        change: selection.changeId,
        revision: composer.revision,
        kind: draft.kind,
        body: draft.body,
        suggestion: draft.suggestion,
        side: composer.side,
        path: composer.path,
        start: composer.start,
        end: composer.end,
        excerpt: composer.excerpt,
      });
      setComposer(null);
      setFocusedNote(null);
      await loadState();
      notifications.show({
        color: "teal",
        message: "批注已提交，Agent 下次读取时会看到。",
      });
    },
    [composer, loadState, selection.changeId],
  );

  const updateAnnotationStatus = useCallback(
    async (note, status) => {
      try {
        await mutate(`/api/annotations/${encodeURIComponent(note.id)}`, {
          change: selection.changeId,
          action: "status",
          status,
        });
        await loadState();
        notifications.show({
          color: status === "open" ? "orange" : "teal",
          message:
            status === "open" ? "批注已重新打开。" : "批注状态已更新。",
        });
      } catch (error) {
        reportError(error);
      }
    },
    [loadState, selection.changeId],
  );

  const replyAnnotation = useCallback(
    async (note, body, resolve) => {
      await mutate(`/api/annotations/${encodeURIComponent(note.id)}`, {
        change: selection.changeId,
        action: "reply",
        body,
        resolve,
      });
      setReplyTo(null);
      await loadState();
      notifications.show({ color: "teal", message: "回复已保存。" });
    },
    [loadState, selection.changeId],
  );

  const setStatus = useCallback(
    async (status) => {
      try {
        await mutate("/api/status", {
          change: selection.changeId,
          status,
        });
        await loadState();
        notifications.show({ color: "teal", message: "审阅状态已更新。" });
      } catch (error) {
        reportError(error);
      }
    },
    [loadState, selection.changeId],
  );

  const adoptPath = useCallback(
    async (entry) => {
      try {
        const result = await mutate("/api/adopt", {
          path: entry.path,
          old_path: entry.old_path || "",
        });
        const payload = await loadState();
        const nextChange = payload?.state.changes.find(
          (change) => change.id === result.change,
        );
        setSelection({
          changeId: result.change,
          revisionId: nextChange?.revisions.at(-1)?.id || null,
        });
        mapControls.close();
        notifications.show({
          color: "teal",
          message: "已加入审阅单元，请让 Agent 补充原因。",
        });
      } catch (error) {
        reportError(error);
      }
    },
    [loadState, mapControls],
  );

  const annotations = useMemo(() => {
    if (!change || !file || !revision) return [];
    return change.annotations
      .filter((note) => {
        if (note.revision_id !== revision.id) return false;
        if (!note.path) return diff.files[0]?.path === file.path;
        return note.path === file.path || note.path === file.old_path;
      })
      .map((note) => ({
        side: note.side === "old" ? "deletions" : "additions",
        lineNumber: note.side === "file" ? 0 : note.start_line,
        metadata: note,
      }));
  }, [change, diff, file, revision]);

  const renderAnnotation = useCallback(
    (annotation) => (
      <InlineNote note={annotation.metadata} onOpen={focusNote} />
    ),
    [focusNote],
  );

  const diffOptions = useMemo(() => {
    const contextLines = context === "all" ? Infinity : Number(context);
    return {
      theme: "review-light",
      themeType: "light",
      preferredHighlighter: "highlights",
      diffStyle: view,
      diffIndicators: "bars",
      lineDiffType: "word-alt",
      hunkSeparators: "line-info-basic",
      expansionLineCount: Number.isFinite(contextLines)
        ? Math.max(20, contextLines * 4)
        : 200,
      collapsedContextThreshold: Number.isFinite(contextLines)
        ? contextLines
        : 999999,
      expandUnchanged: context === "all",
      lineHoverHighlight: "both",
      enableGutterUtility: true,
      overflow: "scroll",
      unsafeCSS: DIFF_CSS,
      onGutterUtilityClick: openLineComposer,
    };
  }, [context, openLineComposer, view]);

  const oldFile = useMemo(() => {
    if (!file || file.status === "added") return null;
    return {
      name: file.old_path || file.path,
      contents: file.old_text,
      cacheKey: `${revision?.id}:${file.old_path || file.path}:old`,
    };
  }, [file, revision?.id]);

  const newFile = useMemo(() => {
    if (!file || file.status === "deleted") return null;
    return {
      name: file.path,
      contents: file.new_text,
      cacheKey: `${revision?.id}:${file.path}:new`,
    };
  }, [file, revision?.id]);

  const goToHunk = useCallback(
    (direction) => {
      if (!file?.hunks.length || !viewportRef.current) return;
      const nextIndex =
        direction > 0
          ? (hunkIndex + 1) % file.hunks.length
          : (hunkIndex - 1 + file.hunks.length) % file.hunks.length;
      setHunkIndex(nextIndex);
      const hunk = file.hunks[nextIndex];
      const addition = hunk.new_count > 0;
      const line = Math.max(1, addition ? hunk.new_start : hunk.old_start);
      const side = addition ? "additions" : "deletions";
      const host = Array.from(viewportRef.current.children).find(
        (element) => element.shadowRoot,
      );
      const target = host?.shadowRoot
        ?.querySelector(`[data-${side}]`)
        ?.querySelector(`[data-column-number="${line}"]`);
      target?.scrollIntoView({ block: "center", behavior: "smooth" });
    },
    [file, hunkIndex],
  );

  useEffect(() => {
    const onKeyDown = (event) => {
      if (event.key === "Escape") {
        mapControls.close();
        notesControls.close();
        setComposer(null);
        return;
      }
      if (
        ["INPUT", "TEXTAREA", "SELECT"].includes(
          document.activeElement?.tagName,
        ) ||
        event.metaKey ||
        event.ctrlKey
      ) {
        return;
      }
      if (event.key.toLowerCase() === "j") goToHunk(1);
      if (event.key.toLowerCase() === "k") goToHunk(-1);
    };
    document.addEventListener("keydown", onKeyDown);
    return () => document.removeEventListener("keydown", onKeyDown);
  }, [goToHunk, mapControls, notesControls]);

  return (
    <div className="app-shell">
      <Header
        snapshot={snapshot}
        connection={connection}
        onRefresh={() => loadState({ forceDiff: true })}
        onOpenMap={mapControls.open}
        onOpenNotes={notesControls.open}
      />
      <main className="workspace">
        {!compactMap && (
          <aside className="review-map-shell" aria-label="变更地图">
            <ReviewRail
              snapshot={snapshot}
              filter={filter}
              setFilter={setFilter}
              selection={selection}
              onSelect={selectChange}
              onAdopt={adoptPath}
            />
          </aside>
        )}

        <section className="review-main" aria-label="代码差异">
          <ChangeHeader
            change={change}
            revision={revision}
            runtime={snapshot?.runtime}
            loading={!snapshot}
            onStatus={setStatus}
            onSelectChange={selectChange}
            onUseLatest={() => {
              setMode("cumulative");
              selectRevision(change.revisions.at(-1).id);
            }}
          />
          {change && (
            <DiffToolbar
              change={change}
              revision={revision}
              diff={diff}
              mode={mode}
              setMode={setMode}
              view={view}
              setView={setView}
              context={context}
              setContext={setContext}
              filePath={filePath}
              setFilePath={setFilePath}
              onRevision={selectRevision}
              onPreviousHunk={() => goToHunk(-1)}
              onNextHunk={() => goToHunk(1)}
              onFileNote={() => openFileComposer(false)}
            />
          )}
          <Box className="diff-viewport" ref={viewportRef}>
            {!change ? (
              <EmptyDiff
                title={snapshot ? "还没有可审阅的变更" : "正在载入审阅记录"}
                detail={
                  snapshot
                    ? "让 Agent 用语义审阅单元登记改动，或从未归类改动中加入。"
                    : "正在连接本地审阅服务。"
                }
                loading={!snapshot}
              />
            ) : diffLoading ? (
              <EmptyDiff title="正在读取差异" loading />
            ) : diffError ? (
              <Box className="diff-error">
                <Alert color="red" title="无法读取差异">
                  {diffError}
                </Alert>
              </Box>
            ) : !diff?.files.length ? (
              <EmptyDiff
                title="这个比较范围没有文件差异"
                detail="可以切换修订，或切到累计模式查看整个变更。"
              />
            ) : !file ? (
              <EmptyDiff title="选择一个文件" />
            ) : file.binary ? (
              <EmptyDiff
                title="二进制文件"
                detail={`${file.path} 在本次比较中发生变化，但不包含可显示的文本。`}
              />
            ) : (
              <MultiFileDiff
                key={`${revision?.id}:${file.path}:${view}:${context}`}
                oldFile={oldFile}
                newFile={newFile}
                options={diffOptions}
                lineAnnotations={annotations}
                renderAnnotation={renderAnnotation}
                className="pierre-diff"
              />
            )}
          </Box>
        </section>

        {!compactInspector && (
          <aside className="inspector-shell" aria-label="改动原因与批注">
            <Inspector
              change={change}
              revision={revision}
              runtime={snapshot?.runtime}
              loading={!snapshot}
              composer={composer}
              setComposer={setComposer}
              focusedNote={focusedNote}
              replyTo={replyTo}
              setReplyTo={setReplyTo}
              onFocusNote={focusNote}
              onSelectRevision={selectRevision}
              onSelectChange={selectChange}
              onOpenFileComposer={openFileComposer}
              onSubmitAnnotation={submitAnnotation}
              onUpdateAnnotation={updateAnnotationStatus}
              onReply={replyAnnotation}
            />
          </aside>
        )}
      </main>

      <Drawer
        opened={compactMap && mapOpened}
        onClose={mapControls.close}
        position="left"
        size="min(330px, 90vw)"
        padding={0}
        title="变更地图"
        closeButtonProps={{ "aria-label": "关闭变更地图" }}
        overlayProps={{ backgroundOpacity: 0.24, blur: 2 }}
      >
        <ReviewRail
          snapshot={snapshot}
          filter={filter}
          setFilter={setFilter}
          selection={selection}
          onSelect={selectChange}
          onAdopt={adoptPath}
          inDrawer
        />
      </Drawer>

      <Drawer
        opened={compactInspector && notesOpened}
        onClose={notesControls.close}
        position="right"
        size="min(400px, 95vw)"
        padding={0}
        title="原因与批注"
        closeButtonProps={{ "aria-label": "关闭原因与批注" }}
        overlayProps={{ backgroundOpacity: 0.24, blur: 2 }}
      >
        <Inspector
          change={change}
          revision={revision}
          runtime={snapshot?.runtime}
          loading={!snapshot}
          composer={composer}
          setComposer={setComposer}
          focusedNote={focusedNote}
          replyTo={replyTo}
          setReplyTo={setReplyTo}
          onFocusNote={focusNote}
          onSelectRevision={selectRevision}
          onSelectChange={selectChange}
          onOpenFileComposer={openFileComposer}
          onSubmitAnnotation={submitAnnotation}
          onUpdateAnnotation={updateAnnotationStatus}
          onReply={replyAnnotation}
          inDrawer
        />
      </Drawer>
    </div>
  );
}

function Header({
  snapshot,
  connection,
  onRefresh,
  onOpenMap,
  onOpenNotes,
}) {
  const changes =
    snapshot?.state.changes.filter(
      (change) => change.status !== "superseded",
    ) || [];
  const accepted = changes.filter(
    (change) => change.status === "accepted",
  ).length;
  const feedback = changes.reduce(
    (count, change) => count + openFeedback(change).length,
    0,
  );
  const progress = changes.length ? (accepted / changes.length) * 100 : 0;
  return (
    <header className="topbar">
      <div className="identity">
        <span className="brand-mark" aria-hidden="true" />
        <span className="brand">Review</span>
        <span className="identity-rule" aria-hidden="true" />
        <Title order={1}>{snapshot?.state.goal || "正在载入审阅记录"}</Title>
      </div>
      <div className="progress-block" aria-live="polite">
        <div className="progress-copy">
          <span>
            {accepted} / {changes.length} 已确认
          </span>
          <span>{feedback ? `${feedback} 条待回应` : "没有待回应反馈"}</span>
        </div>
        <Progress
          value={progress}
          size={3}
          color="rust"
          aria-label="审阅进度"
        />
      </div>
      <div className="topbar-actions">
        <Button
          className="compact-map-only"
          variant="subtle"
          color="gray"
          size="compact-sm"
          onClick={onOpenMap}
        >
          变更
        </Button>
        <Button
          className="compact-inspector-only"
          variant="subtle"
          color="gray"
          size="compact-sm"
          onClick={onOpenNotes}
        >
          批注
        </Button>
        <Badge
          className={`connection is-${connection}`}
          variant="transparent"
          color={
            connection === "live"
              ? "teal"
              : connection === "error"
                ? "red"
                : "yellow"
          }
          leftSection={<span className="connection-dot" />}
        >
          {connection === "live"
            ? "已连接"
            : connection === "error"
              ? "连接失败"
              : "连接中"}
        </Badge>
        <Tooltip label="刷新审阅状态">
          <ActionIcon
            variant="subtle"
            color="gray"
            aria-label="刷新审阅状态"
            onClick={onRefresh}
          >
            ↻
          </ActionIcon>
        </Tooltip>
      </div>
    </header>
  );
}

function ReviewRail({
  snapshot,
  filter,
  setFilter,
  selection,
  onSelect,
  onAdopt,
  inDrawer = false,
}) {
  if (!snapshot) {
    return (
      <Box className={`review-map ${inDrawer ? "in-drawer" : ""}`}>
        <div className="rail-loading">
          <Loader size="sm" />
          <Text>正在载入变更地图</Text>
        </div>
      </Box>
    );
  }
  const changes =
    filter === "all"
      ? snapshot.state.changes
      : snapshot.state.changes.filter(
          (change) =>
            !["accepted", "superseded"].includes(change.status) ||
            openFeedback(change).length > 0,
        );
  const activeCount = snapshot.state.changes.filter(
    (change) => change.status !== "superseded",
  ).length;
  return (
    <div className={`review-map ${inDrawer ? "in-drawer" : ""}`}>
      <div className="rail-heading">
        <div>
          <Text className="eyebrow">变更地图</Text>
          <Text className="rail-count">
            {activeCount} 个审阅单元
          </Text>
        </div>
        <SegmentedControl
          value={filter}
          onChange={setFilter}
          size="xs"
          aria-label="筛选变更"
          data={[
            { value: "open", label: "待处理" },
            { value: "all", label: "全部" },
          ]}
        />
      </div>
      <ScrollArea className="change-list" type="auto" offsetScrollbars>
        {!changes.length && (
          <Text className="empty-map">
            {filter === "open"
              ? "没有待处理审阅单元。切换到“全部”可以查看历史。"
              : "这个审阅记录里还没有变更。"}
          </Text>
        )}
        {changes.map((change, index) => {
          const pending = openFeedback(change).length;
          const newer = snapshot.runtime.newer_worktree[change.id];
          return (
            <UnstyledButton
              key={change.id}
              className={`change-item status-${change.status} ${
                change.id === selection.changeId ? "is-active" : ""
              }`}
              style={{ "--index": index }}
              onClick={() => onSelect(change.id)}
            >
              <span className="change-item-title">{change.title}</span>
              <span className="change-item-path">
                {change.paths.length === 1
                  ? change.paths[0]
                  : `${change.paths[0]} +${change.paths.length - 1}`}
              </span>
              <span className="change-item-foot">
                <span>
                  {STATUS_LABELS[change.status] || change.status} ·{" "}
                  {change.revisions.length} 次
                </span>
                <span className="change-item-badges">
                  {pending > 0 && (
                    <span className="mini-badge feedback">{pending}</span>
                  )}
                  {newer > 0 && (
                    <span className="mini-badge newer">+{newer}</span>
                  )}
                  {change.status === "superseded" && (
                    <span className="mini-badge">历史</span>
                  )}
                </span>
              </span>
            </UnstyledButton>
          );
        })}
      </ScrollArea>
      {snapshot.runtime.unmapped.length > 0 && (
        <section className="unmapped">
          <div className="section-heading">
            <span>未归类改动</span>
            <span className="count-badge">
              {snapshot.runtime.unmapped.length}
            </span>
          </div>
          <p className="section-note">
            这些工作区改动尚未由 Agent 纳入审阅单元。
          </p>
          {snapshot.runtime.unmapped.map((entry) => (
            <div className="unmapped-item" key={entry.path}>
              <span className="unmapped-path">
                {entry.old_path
                  ? `${entry.old_path} → ${entry.path}`
                  : entry.path}
              </span>
              <div className="unmapped-actions">
                <span className="file-status">
                  {FILE_STATUS_LABELS[entry.status] || entry.status}
                </span>
                <Button
                  variant="transparent"
                  size="compact-xs"
                  onClick={() => onAdopt(entry)}
                >
                  纳入审阅
                </Button>
              </div>
            </div>
          ))}
        </section>
      )}
      <div className="rail-foot">
        <p>{snapshot.state.scope}</p>
        <p>{snapshot.runtime.state_path}</p>
      </div>
    </div>
  );
}

function ChangeHeader({
  change,
  revision,
  runtime,
  loading,
  onStatus,
  onSelectChange,
  onUseLatest,
}) {
  const latestRevision = change?.revisions.at(-1);
  return (
    <header className="change-heading">
      <div className="change-title-row">
        <Text className="eyebrow">
          {loading
            ? "正在载入变更"
            : change
            ? `${STATUS_LABELS[change.status] || change.status} · ${change.id}`
            : "选择一项变更"}
        </Text>
        {change && (
          <div className="change-actions">
            <Select
              aria-label="审阅状态"
              size="xs"
              w={110}
              value={change.status}
              onChange={onStatus}
              allowDeselect={false}
              data={Object.entries(STATUS_LABELS).map(([value, label]) => ({
                value,
                label,
              }))}
            />
          </div>
        )}
      </div>
      <Title order={2}>
        {loading
          ? "正在读取审阅记录"
          : change?.title || "还没有可审阅的变更"}
      </Title>
      {change && (
        <div className="change-meta">
          {change.paths.map((path) => (
            <span key={path}>{path}</span>
          ))}
          {change.superseded_by && (
            <Button
              variant="transparent"
              color="blue"
              size="compact-xs"
              onClick={() => onSelectChange(change.superseded_by)}
            >
              由 {change.superseded_by} 替代
            </Button>
          )}
          {runtime?.newer_worktree[change.id] > 0 &&
            revision?.id !== latestRevision?.id && (
            <Button
              variant="transparent"
              color="orange"
              size="compact-xs"
              onClick={onUseLatest}
            >
              查看累计到最新登记修订
            </Button>
          )}
          {runtime?.newer_worktree[change.id] > 0 &&
            revision?.id === latestRevision?.id && (
              <span className="newer-unpublished">
                之后又有 {runtime.newer_worktree[change.id]} 处未登记变化
              </span>
            )}
        </div>
      )}
    </header>
  );
}

function DiffToolbar({
  change,
  revision,
  diff,
  mode,
  setMode,
  view,
  setView,
  context,
  setContext,
  filePath,
  setFilePath,
  onRevision,
  onPreviousHunk,
  onNextHunk,
  onFileNote,
}) {
  return (
    <div className="diff-toolbar">
      <Select
        aria-label="修订"
        className="revision-select"
        size="xs"
        w={190}
        value={revision?.id}
        onChange={onRevision}
        allowDeselect={false}
        data={change.revisions.map((item) => ({
          value: item.id,
          label: `${item.label} · ${shortRef(item.head)}`,
        }))}
      />
      <SegmentedControl
        size="xs"
        value={mode}
        onChange={setMode}
        aria-label="比较范围"
        data={[
          { value: "round", label: "本轮" },
          { value: "cumulative", label: "累计" },
        ]}
      />
      <Select
        aria-label="文件"
        size="xs"
        className="file-select-wrap"
        w={260}
        value={filePath}
        onChange={setFilePath}
        allowDeselect={false}
        disabled={(diff?.files.length || 0) < 2}
        data={(diff?.files || []).map((file) => ({
          value: file.path,
          label: `${file.old_path ? `${file.old_path} → ` : ""}${file.path}`,
        }))}
      />
      <div className="toolbar-spacer" />
      <Tooltip label="上一个改动块 (K)">
        <Button
          className="hunk-nav"
          variant="subtle"
          color="gray"
          size="compact-xs"
          onClick={onPreviousHunk}
        >
          ↑ 改动
        </Button>
      </Tooltip>
      <Tooltip label="下一个改动块 (J)">
        <Button
          className="hunk-nav"
          variant="subtle"
          color="gray"
          size="compact-xs"
          onClick={onNextHunk}
        >
          ↓ 改动
        </Button>
      </Tooltip>
      <SegmentedControl
        size="xs"
        value={view}
        onChange={setView}
        aria-label="差异视图"
        data={[
          { value: "unified", label: "统一" },
          { value: "split", label: "并排" },
        ]}
      />
      <Select
        aria-label="上下文"
        size="xs"
        className="context-select"
        w={88}
        value={context}
        onChange={setContext}
        allowDeselect={false}
        data={[
          { value: "0", label: "0 行" },
          { value: "3", label: "3 行" },
          { value: "8", label: "8 行" },
          { value: "20", label: "20 行" },
          { value: "all", label: "全部" },
        ]}
      />
      <Button
        className="file-note-button"
        variant="subtle"
        color="gray"
        size="compact-xs"
        onClick={onFileNote}
      >
        文件批注
      </Button>
    </div>
  );
}

function EmptyDiff({ title, detail, loading = false }) {
  return (
    <div className="empty-diff">
      {loading ? <Loader size="sm" /> : <span className="empty-rule" />}
      <h3>{title}</h3>
      {detail && <p>{detail}</p>}
    </div>
  );
}

function InlineNote({ note, onOpen }) {
  return (
    <button
      type="button"
      className={`inline-note kind-${note.kind} ${
        note.status === "resolved" ? "is-resolved" : ""
      }`}
      onClick={(event) => {
        event.stopPropagation();
        onOpen(note);
      }}
    >
      <span className="inline-note-top">
        <span className="inline-note-author">
          {note.author === "user" ? "你" : "Agent"}
        </span>
        <span className="inline-note-kind">
          {KIND_LABELS[note.kind] || note.kind}
        </span>
        {note.start_line && (
          <span className="inline-note-range">
            {note.start_line === note.end_line
              ? `L${note.start_line}`
              : `L${note.start_line}–${note.end_line}`}
          </span>
        )}
      </span>
      <span className="inline-note-body">{note.body}</span>
    </button>
  );
}

function Inspector({
  change,
  revision,
  runtime,
  loading,
  composer,
  setComposer,
  focusedNote,
  replyTo,
  setReplyTo,
  onFocusNote,
  onSelectRevision,
  onSelectChange,
  onOpenFileComposer,
  onSubmitAnnotation,
  onUpdateAnnotation,
  onReply,
  inDrawer = false,
}) {
  const contentRef = useRef(null);
  useEffect(() => {
    if (!focusedNote) return;
    const target = contentRef.current?.querySelector(
      `[data-card-note="${CSS.escape(focusedNote)}"]`,
    );
    target?.scrollIntoView({ block: "center", behavior: "smooth" });
  }, [focusedNote]);

  if (!change) {
    return (
      <div className={`inspector ${inDrawer ? "in-drawer" : ""}`}>
        {loading ? (
          <div className="rail-loading">
            <Loader size="sm" />
            <Text>正在载入审阅上下文</Text>
          </div>
        ) : (
          <Text className="inspector-empty">
            选择一项变更后，这里会显示改动原因、修订历史和反馈。
          </Text>
        )}
      </div>
    );
  }
  return (
    <div className={`inspector ${inDrawer ? "in-drawer" : ""}`}>
      {!inDrawer && (
        <div className="inspector-heading">
          <div>
            <Text className="eyebrow">审阅上下文</Text>
            <Title order={2}>原因与批注</Title>
          </div>
        </div>
      )}
      <ScrollArea
        className="inspector-scroll"
        type="auto"
        offsetScrollbars
        viewportRef={contentRef}
      >
        <div className="inspector-content">
          <Stack gap={0}>
            <ContextBlock title="这项改动" body={change.summary} />
            <ContextBlock title="为什么这样做" body={change.rationale} />
            {change.status === "superseded" && (
              <section className="context-block superseded-note">
                <h3>审阅单元已被替代</h3>
                {change.superseded_by ? (
                  <Button
                    variant="transparent"
                    color="blue"
                    size="compact-xs"
                    onClick={() => onSelectChange(change.superseded_by)}
                  >
                    查看 {change.superseded_by} →
                  </Button>
                ) : (
                  <Text c="dimmed" size="xs">
                    后续改动已由新的审阅单元承接。
                  </Text>
                )}
              </section>
            )}
            <RevisionTimeline
              change={change}
              revision={revision}
              onSelect={onSelectRevision}
            />
            {runtime?.newer_worktree[change.id] > 0 && (
              <Alert
                className="newer-alert"
                color="orange"
                title="工作区有后续变化"
              >
                这次修订之后，工作区又有{" "}
                {runtime.newer_worktree[change.id]} 个相关文件发生变化。
                需要审阅最新代码时，请让 Agent 追加修订或建立新的语义审阅单元。
              </Alert>
            )}
            <AnnotationSection
              change={change}
              focusedNote={focusedNote}
              replyTo={replyTo}
              setReplyTo={setReplyTo}
              onFocusNote={onFocusNote}
              onUpdate={onUpdateAnnotation}
              onReply={onReply}
            />
          </Stack>
          {composer ? (
            <Composer
              key={composer.key}
              composer={composer}
              onCancel={() => setComposer(null)}
              onSubmit={onSubmitAnnotation}
            />
          ) : (
            <div className="inspector-actions">
              <Button
                variant="filled"
                color="rust"
                size="xs"
                onClick={() => onOpenFileComposer(true)}
              >
                新增整体批注
              </Button>
            </div>
          )}
        </div>
      </ScrollArea>
    </div>
  );
}

function ContextBlock({ title, body }) {
  return (
    <section className="context-block">
      <h3>{title}</h3>
      <p>{body || "Agent 还没有补充。"}</p>
    </section>
  );
}

function RevisionTimeline({ change, revision, onSelect }) {
  return (
    <section className="context-block revision-block">
      <h3>修订历史</h3>
      <div className="revision-list">
        {change.revisions.map((item, index) => (
          <UnstyledButton
            key={item.id}
            className={`revision-row ${
              item.id === revision?.id ? "is-active" : ""
            }`}
            onClick={() => onSelect(item.id)}
          >
            <span className="revision-heading">
              <span className="revision-index">{index + 1}</span>
              <span className="revision-label">{item.label}</span>
              <span className="revision-ref">
                {shortRef(item.base)} → {shortRef(item.head)}
              </span>
            </span>
            {item.summary && (
              <span className="revision-summary">{item.summary}</span>
            )}
            {item.reason && (
              <span className="revision-reason">{item.reason}</span>
            )}
          </UnstyledButton>
        ))}
      </div>
    </section>
  );
}

function AnnotationSection({
  change,
  focusedNote,
  replyTo,
  setReplyTo,
  onFocusNote,
  onUpdate,
  onReply,
}) {
  const notes = [...change.annotations].sort((a, b) => {
    if (a.status === "open" && b.status !== "open") return -1;
    if (b.status === "open" && a.status !== "open") return 1;
    return b.updated_at.localeCompare(a.updated_at);
  });
  const pending = notes.filter((note) => note.status === "open").length;
  return (
    <section className="annotation-section">
      <div className="annotation-section-title">
        <h3>批注与反馈</h3>
        <span>{pending ? `${pending} 条未解决` : "已清空"}</span>
      </div>
      {!notes.length && (
        <Text className="inspector-empty">
          在代码行号旁的 + 按钮选择任意行或范围，或添加整体批注。
        </Text>
      )}
      {notes.map((note) => (
        <AnnotationCard
          key={note.id}
          change={change}
          note={note}
          focused={focusedNote === note.id}
          replyOpen={replyTo === note.id}
          setReplyTo={setReplyTo}
          onFocus={onFocusNote}
          onUpdate={onUpdate}
          onReply={onReply}
        />
      ))}
    </section>
  );
}

function AnnotationCard({
  change,
  note,
  focused,
  replyOpen,
  setReplyTo,
  onFocus,
  onUpdate,
  onReply,
}) {
  const location = note.path
    ? note.start_line
      ? `${note.path}:${note.start_line}-${note.end_line} · ${
          note.side === "old" ? "旧" : "新"
        }`
      : `${note.path} · 文件`
    : "整体变更";
  const revision = change.revisions.find(
    (item) => item.id === note.revision_id,
  );
  return (
    <article
      data-card-note={note.id}
      className={`annotation-card by-${note.author} ${
        note.status === "open" ? "" : "is-resolved"
      } ${focused ? "is-focused" : ""}`}
      onClick={() => onFocus(note)}
    >
      <div className="annotation-topline">
        <span className="annotation-author">
          {note.author === "user" ? "你" : "Agent"}
        </span>
        <span className={`annotation-kind kind-${note.kind}`}>
          {KIND_LABELS[note.kind] || note.kind}
        </span>
        <span className="annotation-state">
          {ANNOTATION_STATUS_LABELS[note.status] || note.status}
        </span>
      </div>
      <p className="annotation-location">
        {location} · {revision?.label || note.revision_id}
      </p>
      <p className="annotation-body">{note.body}</p>
      {note.suggestion && (
        <pre className="annotation-suggestion">{note.suggestion}</pre>
      )}
      {note.replies.length > 0 && (
        <div className="reply-list">
          {note.replies.map((reply) => (
            <div className="reply" key={reply.id}>
              <span className="reply-author">
                {reply.author === "user" ? "你" : "Agent"}
              </span>
              <div>{reply.body}</div>
            </div>
          ))}
        </div>
      )}
      {replyOpen && (
        <ReplyForm
          onCancel={() => setReplyTo(null)}
          onReply={(body, resolve) => onReply(note, body, resolve)}
        />
      )}
      <div
        className="annotation-actions"
        onClick={(event) => event.stopPropagation()}
      >
        <Button
          variant="transparent"
          color="gray"
          size="compact-xs"
          onClick={() => setReplyTo(replyOpen ? null : note.id)}
        >
          {replyOpen ? "取消回复" : "回复"}
        </Button>
        <Button
          variant="transparent"
          color={note.status === "open" ? "teal" : "gray"}
          size="compact-xs"
          onClick={() =>
            onUpdate(note, note.status === "open" ? "resolved" : "open")
          }
        >
          {note.status === "open" ? "标记解决" : "重新打开"}
        </Button>
        {note.status === "open" && (
          <Button
            variant="transparent"
            color="gray"
            size="compact-xs"
            onClick={() => onUpdate(note, "dismissed")}
          >
            忽略
          </Button>
        )}
      </div>
    </article>
  );
}

function ReplyForm({ onCancel, onReply }) {
  const [body, setBody] = useState("");
  const [resolve, setResolve] = useState(false);
  const [submitting, setSubmitting] = useState(false);
  return (
    <form
      className="reply-form"
      onClick={(event) => event.stopPropagation()}
      onSubmit={async (event) => {
        event.preventDefault();
        if (!body.trim()) return;
        setSubmitting(true);
        try {
          await onReply(body, resolve);
        } catch (error) {
          reportError(error);
          setSubmitting(false);
        }
      }}
    >
      <Textarea
        size="xs"
        autosize
        minRows={3}
        placeholder="回复这条批注…"
        aria-label="回复内容"
        value={body}
        onChange={(event) => setBody(event.currentTarget.value)}
      />
      <Group justify="space-between">
        <Checkbox
          size="xs"
          label="回复后解决"
          checked={resolve}
          onChange={(event) => setResolve(event.currentTarget.checked)}
        />
        <Group gap="xs">
          <Button
            type="button"
            variant="subtle"
            color="gray"
            size="compact-xs"
            onClick={onCancel}
          >
            取消
          </Button>
          <Button
            type="submit"
            size="compact-xs"
            loading={submitting}
            disabled={!body.trim()}
          >
            发送回复
          </Button>
        </Group>
      </Group>
    </form>
  );
}

function Composer({ composer, onCancel, onSubmit }) {
  const [kind, setKind] = useState("change");
  const [body, setBody] = useState("");
  const [suggestion, setSuggestion] = useState("");
  const [withSuggestion, setWithSuggestion] = useState(false);
  const [submitting, setSubmitting] = useState(false);
  return (
    <Paper className="composer" withBorder>
      <div className="composer-heading">
        <div>
          <Title order={3}>写下你的判断</Title>
          <p className="composer-location">{composer.label}</p>
        </div>
        <ActionIcon
          variant="subtle"
          color="gray"
          size="sm"
          aria-label="关闭批注编辑器"
          onClick={onCancel}
        >
          ×
        </ActionIcon>
      </div>
      <Radio.Group
        value={kind}
        onChange={setKind}
        aria-label="批注类型"
        className="kind-picker"
      >
        <Group gap={4}>
          {[
            ["change", "要修改"],
            ["bug", "有缺陷"],
            ["question", "想问"],
            ["note", "只备注"],
          ].map(([value, label]) => (
            <Radio key={value} value={value} label={label} size="xs" />
          ))}
        </Group>
      </Radio.Group>
      <Textarea
        autosize
        minRows={4}
        placeholder="具体哪里不对？希望怎么改？"
        aria-label="批注内容"
        value={body}
        onChange={(event) => setBody(event.currentTarget.value)}
      />
      {composer.excerpt && (
        <pre className="composer-excerpt">{composer.excerpt}</pre>
      )}
      <Checkbox
        className="suggestion-toggle"
        size="xs"
        label="附带修改建议"
        checked={withSuggestion}
        onChange={(event) => setWithSuggestion(event.currentTarget.checked)}
      />
      {withSuggestion && (
        <Textarea
          className="code-input"
          autosize
          minRows={3}
          placeholder="可选：贴上建议代码"
          aria-label="修改建议"
          value={suggestion}
          onChange={(event) => setSuggestion(event.currentTarget.value)}
        />
      )}
      <Group className="composer-actions" justify="space-between">
        <Text className="composer-hint">
          提交后会直接进入 Agent 的反馈收件箱
        </Text>
        <Button
          size="xs"
          loading={submitting}
          disabled={!body.trim()}
          onClick={async () => {
            if (!body.trim()) return;
            setSubmitting(true);
            try {
              await onSubmit({
                kind,
                body,
                suggestion: withSuggestion ? suggestion : "",
              });
            } catch (error) {
              reportError(error);
              setSubmitting(false);
            }
          }}
        >
          提交批注
        </Button>
      </Group>
    </Paper>
  );
}

createRoot(document.getElementById("root")).render(
  <MantineProvider theme={theme} forceColorScheme="light">
    <AppErrorBoundary>
      <Notifications position="bottom-center" limit={3} />
      <App />
    </AppErrorBoundary>
  </MantineProvider>,
);
