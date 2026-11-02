import "./fonts-latin.css";
import "@mantine/core/styles/baseline.css";
import "@mantine/core/styles/default-css-variables.css";
import "@mantine/core/styles/global.css";
import "@mantine/core/styles/UnstyledButton.css";
import "@mantine/core/styles/ActionIcon.css";
import "@mantine/core/styles/Alert.css";
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
import "@mantine/core/styles/ScrollArea.css";
import "@mantine/core/styles/SegmentedControl.css";
import "@mantine/core/styles/Stack.css";
import "@mantine/core/styles/Text.css";
import "@mantine/core/styles/Title.css";
import "@mantine/core/styles/Tooltip.css";
import "@mantine/notifications/styles.css";
import {
  ActionIcon,
  Alert,
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
import { useDisclosure, useLocalStorage } from "@mantine/hooks";
import { Notifications, notifications } from "@mantine/notifications";
import {
  diffAcceptRejectHunk,
  parseDiffFromFile,
  registerCustomTheme,
} from "@pierre/diffs";
import { FileDiff } from "@pierre/diffs/react";
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
const ANNOTATION_KIND_OPTIONS = [
  { value: "change", label: "要修改" },
  { value: "bug", label: "有缺陷" },
  { value: "question", label: "想问" },
  { value: "note", label: "只备注" },
];
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
const DELIVERY_LABELS = {
  queued: "等待送达",
  delivered: "已送达 Agent",
  processing: "Agent 处理中",
  answered: "已回应",
  failed: "送达失败",
};
const LISTENER_LABELS = {
  unconfigured: "未启用实时反馈",
  listening: "实时监听中",
  degraded: "定时接收中",
  paused: "监听已暂停",
  error: "Agent 连接异常",
};
const LISTENER_SHORT_LABELS = {
  unconfigured: "未连接",
  listening: "实时",
  degraded: "定时",
  paused: "暂停",
  error: "异常",
};
const REVIEW_ITEM_LABELS = {
  pending: "待审",
  accepted: "已通过",
  excluded: "已过滤",
};
const MAP_VISIBILITY_KEY = "review-with-me:map-visible";
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

function listenerDetail(listener) {
  const status = listener?.status || "unconfigured";
  if (status === "error") {
    return "无法把反馈送到当前 Agent；请在 Agent 中继续审阅并检查连接。";
  }
  if (status === "degraded") {
    return "即时通知失败，Agent 会定时检查新反馈。";
  }
  if (status === "paused") {
    return "需要继续时，请在 Agent 中恢复审阅。";
  }
  if (listener?.automation_id) {
    return "即时通知和定时兜底均已启用。";
  }
  return "反馈会直接送达当前审阅会话。";
}

function composerDeliveryHint(listener) {
  const status = listener?.status || "unconfigured";
  if (status === "listening") return "提交后会直接通知当前 Agent";
  if (status === "degraded") {
    return "即时通知异常；批注会保存，由 Agent 定时接收";
  }
  if (status === "paused") {
    return "监听已暂停；批注会保存，等你让 Agent 恢复后再处理";
  }
  return "实时通知不可用；批注会保存，由 Agent 定时检查";
}

function reviewDecisions(change, revision) {
  if (!change || !revision) return [];
  return (change.decisions || []).filter(
    (decision) =>
      decision.revision_id === revision.id &&
      decision.status !== "pending",
  );
}

function hunkKey(hunk) {
  return [
    hunk.old_start,
    hunk.old_count,
    hunk.new_start,
    hunk.new_count,
  ].join(":");
}

function findChangeContent(fileDiff, target) {
  for (const [hunkIndex, hunk] of fileDiff.hunks.entries()) {
    let oldLine = hunk.deletionStart;
    let newLine = hunk.additionStart;
    for (const [contentIndex, content] of hunk.hunkContent.entries()) {
      if (content.type === "context") {
        oldLine += content.lines;
        newLine += content.lines;
        continue;
      }
      const oldMatches =
        target.old_count === 0 ||
        (oldLine === target.old_start &&
          content.deletions === target.old_count);
      const newMatches =
        target.new_count === 0 ||
        (newLine === target.new_start &&
          content.additions === target.new_count);
      if (oldMatches && newMatches) {
        return { hunkIndex, contentIndex };
      }
      oldLine += content.deletions;
      newLine += content.additions;
    }
  }
  return null;
}

function decisionForHunk(decisions, path, hunk) {
  return decisions.find(
    (decision) =>
      decision.path === path &&
      decision.scope === "hunk" &&
      decision.hunk &&
      hunkKey(decision.hunk) === hunkKey(hunk),
  );
}

function decisionForFile(decisions, path) {
  return decisions.find(
    (decision) => decision.path === path && decision.scope === "file",
  );
}

function fileReviewState(file, decisions) {
  const fileDecision = decisionForFile(decisions, file.path);
  if (
    fileDecision &&
    ["accepted", "excluded"].includes(fileDecision.status)
  ) {
    return {
      status: fileDecision.status,
      decision: fileDecision,
      pendingHunks: [],
      hunks: file.hunks.map((hunk) => ({
        hunk,
        decision: fileDecision,
        status: fileDecision.status,
        inherited: true,
      })),
    };
  }
  const hunks = file.hunks.map((hunk) => {
    const decision = decisionForHunk(decisions, file.path, hunk);
    return {
      hunk,
      decision,
      status: decision?.status || "pending",
      inherited: false,
    };
  });
  const pendingHunks = hunks.filter((item) => item.status === "pending");
  if (!file.hunks.length) {
    return {
      status:
        fileDecision && fileDecision.status !== "pending"
          ? fileDecision.status
          : "pending",
      decision: fileDecision,
      pendingHunks: fileDecision ? [] : [null],
      hunks,
    };
  }
  if (pendingHunks.length) {
    return { status: "pending", decision: null, pendingHunks, hunks };
  }
  const accepted = hunks.some((item) => item.status === "accepted");
  return {
    status: accepted ? "accepted" : "excluded",
    decision: null,
    pendingHunks,
    hunks,
  };
}

function fileIsPending(file, decisions) {
  return fileReviewState(file, decisions).pendingHunks.length > 0;
}

function pendingFilesFor(diff, change, revision) {
  if (!diff || !change || !revision) return [];
  const decisions = reviewDecisions(change, revision);
  return diff.files.filter((file) => fileIsPending(file, decisions));
}

function reviewTargets(change) {
  return change?.review || {
    pending: 0,
    pending_files: 0,
    complete: false,
  };
}

function changeNeedsAttention(change) {
  if (change.status === "superseded") return false;
  const review = reviewTargets(change);
  if (review.error) return true;
  return review.pending > 0 || openFeedback(change).length > 0;
}

function deliveryNotification(delivery, noun) {
  const state = delivery?.state || "none";
  if (state === "delivered") {
    return {
      color: "teal",
      message: `${noun}已提交，并已通知 Agent。`,
    };
  }
  if (state === "failed") {
    return {
      color: "orange",
      message: `${noun}已保存；即时通知失败，Agent 会定时检查。`,
    };
  }
  if (state === "paused") {
    return {
      color: "orange",
      message: `${noun}已保存；监听恢复后由 Agent 处理。`,
    };
  }
  if (state === "none") {
    return { color: "teal", message: `${noun}已保存。` };
  }
  return {
    color: "orange",
    message: `${noun}已保存，等待 Agent 处理。`,
  };
}

function signatureFor(state, runtime, listener) {
  return [
    runtime.worktree_fingerprint,
    runtime.branch,
    runtime.head,
    JSON.stringify(runtime.unmapped),
    JSON.stringify(runtime.newer_worktree),
    JSON.stringify(listener),
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
  const [fileFilter, setFileFilter] = useState("pending");
  const [diff, setDiff] = useState(null);
  const [diffLoading, setDiffLoading] = useState(false);
  const [diffError, setDiffError] = useState("");
  const [diffEpoch, setDiffEpoch] = useState(0);
  const [connection, setConnection] = useState("loading");
  const [composer, setComposer] = useState(null);
  const [replyTo, setReplyTo] = useState(null);
  const [focusedNote, setFocusedNote] = useState(null);
  const [hunkIndex, setHunkIndex] = useState(-1);
  const [reviewItemBusy, setReviewItemBusy] = useState("");
  const [mapVisible, setMapVisible] = useLocalStorage({
    key: MAP_VISIBILITY_KEY,
    defaultValue: true,
    getInitialValueInEffect: false,
  });
  const [notesOpened, notesControls] = useDisclosure(false);
  const signatureRef = useRef("");
  const viewportRef = useRef(null);

  const openMap = useCallback(() => {
    setMapVisible(true);
  }, [setMapVisible]);

  const openNotes = useCallback(() => {
    notesControls.open();
  }, [notesControls]);

  const toggleMap = useCallback(() => {
    setMapVisible((visible) => !visible);
  }, [setMapVisible]);

  const loadState = useCallback(
    async ({ forceDiff = false, quiet = false } = {}) => {
      try {
        const payload = await getJSON("/api/state");
        setConnection("live");
        const signature = signatureFor(
          payload.state,
          payload.runtime,
          payload.listener,
        );
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
              payload.state.changes.find(changeNeedsAttention) ||
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
  const decisions = useMemo(
    () => reviewDecisions(change, revision),
    [change, revision],
  );
  const pendingFiles = useMemo(
    () => pendingFilesFor(diff, change, revision),
    [change, decisions, diff, revision],
  );
  const visibleFiles =
    fileFilter === "all" ? diff?.files || [] : pendingFiles;
  const file =
    visibleFiles.find((item) => item.path === filePath) ||
    visibleFiles[0] ||
    null;
  const fileState = file ? fileReviewState(file, decisions) : null;
  const navigableHunks = fileState?.pendingHunks || [];
  const reviewChanges =
    snapshot?.state.changes.filter(
      (item) => item.status !== "superseded",
    ) || [];
  const changePosition = reviewChanges.findIndex(
    (item) => item.id === change?.id,
  );
  const previousChange =
    reviewChanges.length > 1
      ? reviewChanges[
          (changePosition - 1 + reviewChanges.length) % reviewChanges.length
        ]
      : null;
  const nextChange =
    reviewChanges.length > 1
      ? reviewChanges[(changePosition + 1) % reviewChanges.length]
      : null;

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

  useEffect(() => {
    if (!visibleFiles.length) {
      if (filePath !== null) setFilePath(null);
      return;
    }
    if (!visibleFiles.some((item) => item.path === filePath)) {
      setFilePath(visibleFiles[0].path);
      setHunkIndex(-1);
    }
  }, [filePath, visibleFiles]);

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
      setFileFilter("pending");
    },
    [snapshot],
  );

  const selectRevision = useCallback((revisionId) => {
    setSelection((previous) => ({ ...previous, revisionId }));
    setHunkIndex(-1);
  }, []);

  const focusNote = useCallback(
    (note) => {
      setFocusedNote(note.id);
      setReplyTo(null);
      openNotes();
    },
    [openNotes],
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
    },
    [file, selection.revisionId],
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
      openNotes();
    },
    [file, openNotes, selection.revisionId],
  );

  const submitAnnotation = useCallback(
    async (draft) => {
      const result = await mutate("/api/annotations", {
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
      notifications.show(deliveryNotification(result.delivery, "批注"));
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
      const result = await mutate(
        `/api/annotations/${encodeURIComponent(note.id)}`,
        {
          change: selection.changeId,
          action: "reply",
          body,
          resolve,
        },
      );
      setReplyTo(null);
      await loadState();
      notifications.show(deliveryNotification(result.delivery, "回复"));
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

  const decideReviewItem = useCallback(
    async ({ targetFile, hunk = null, status }) => {
      if (!targetFile || !selection.changeId || !selection.revisionId) return;
      const busyKey = `${targetFile.path}:${hunk ? hunkKey(hunk) : "file"}`;
      setReviewItemBusy(busyKey);
      try {
        const result = await mutate("/api/review-item", {
          change: selection.changeId,
          revision: selection.revisionId,
          path: targetFile.path,
          scope: hunk ? "hunk" : "file",
          hunk,
          status,
        });
        const payload = await loadState({ forceDiff: true });
        if (!payload) return;
        const nextChange =
          payload.state.changes.find(
            (item) => item.id === selection.changeId,
          ) || change;
        const nextRevision =
          nextChange?.revisions.find(
            (item) => item.id === selection.revisionId,
          ) || nextChange?.revisions.at(-1);
        const nextPendingFiles =
          nextChange && nextRevision && diff
            ? pendingFilesFor(diff, nextChange, nextRevision)
            : [];
        if (nextPendingFiles.length) {
          const retained = nextPendingFiles.find(
            (item) => item.path === targetFile.path,
          );
          setFilePath((retained || nextPendingFiles[0]).path);
          setFileFilter("pending");
        } else {
          const next = payload.state.changes.find(
            (item) =>
              item.id !== selection.changeId && changeNeedsAttention(item),
          );
          if (next) {
            selectChange(next.id);
          } else {
            setFilePath(null);
          }
        }
        const message =
          status === "pending"
            ? "已撤销通过状态。"
            : hunk
              ? "这个改动块已通过。"
              : "这个文件已通过。";
        notifications.show({
          color: "teal",
          message,
        });
        return result;
      } catch (error) {
        reportError(error);
        return null;
      } finally {
        setReviewItemBusy("");
      }
    },
    [
      change,
      diff,
      loadState,
      selectChange,
      selection.changeId,
      selection.revisionId,
    ],
  );

  const stopListening = useCallback(async () => {
    try {
      await mutate("/api/listener/stop", {
        reason: "Stopped by the reviewer in the UI",
      });
      await loadState();
      notifications.show({
        color: "orange",
        message: "已停止监听。需要继续时，请在 Agent 中恢复审阅。",
        autoClose: 6200,
      });
    } catch (error) {
      reportError(error);
    }
  }, [loadState]);

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
        notifications.show({
          color: "teal",
          message: "已加入审阅单元，请让 Agent 补充原因。",
        });
      } catch (error) {
        reportError(error);
      }
    },
    [loadState],
  );

  const annotations = useMemo(() => {
    if (!change || !file || !revision) return [];
    const notes = change.annotations
      .filter((note) => {
        if (note.revision_id !== revision.id) return false;
        if (!note.path) return diff.files[0]?.path === file.path;
        return note.path === file.path || note.path === file.old_path;
      })
      .map((note) => ({
        type: "annotation",
        side: note.side === "old" ? "deletions" : "additions",
        lineNumber: note.side === "file" ? 0 : note.start_line,
        metadata: note,
      }));
    const addInlineComposer = () => {
      if (
        !composer ||
        composer.revision !== revision.id ||
        composer.path !== file.path ||
        composer.side === "file"
      ) {
        return;
      }
      notes.push({
        type: "composer",
        side: composer.side === "old" ? "deletions" : "additions",
        lineNumber: composer.end,
        metadata: { type: "composer", composer },
      });
    };
    if (!fileState) return notes;
    if (fileState.decision?.scope === "file") {
      notes.unshift({
        type: "review",
        side: "additions",
        lineNumber: 0,
        metadata: {
          type: "file-decision",
          file,
          decision: fileState.decision,
        },
      });
      addInlineComposer();
      return notes;
    }
    const reviewNotes = fileState.hunks
      .filter(
        (item) =>
          fileFilter === "all" ||
          item.status === "pending",
      )
      .map((item) => {
        const hunk = item.hunk;
        return {
          type: "review",
          side: hunk.new_count > 0 ? "additions" : "deletions",
          lineNumber:
            hunk.new_count > 0 ? hunk.new_start : hunk.old_start,
          metadata: {
            type: "hunk-decision",
            file,
            hunk,
            decision: item.decision,
            status: item.status,
          },
        };
      });
    addInlineComposer();
    return [...reviewNotes, ...notes];
  }, [change, composer, diff, file, fileFilter, fileState, revision]);

  const renderAnnotation = useCallback(
    (annotation) => {
      if (annotation.metadata?.type === "composer") {
        return (
          <Composer
            key={annotation.metadata.composer.key}
            composer={annotation.metadata.composer}
            listener={snapshot?.listener}
            inline
            onCancel={() => setComposer(null)}
            onSubmit={submitAnnotation}
          />
        );
      }
      if (annotation.metadata?.type === "hunk-decision") {
        const item = annotation.metadata;
        const busy = reviewItemBusy === `${file.path}:${hunkKey(item.hunk)}`;
        return (
          <HunkDecision
            status={item.status}
            decision={item.decision}
            busy={busy}
            onDecide={(status) =>
              decideReviewItem({
                targetFile: file,
                hunk: item.hunk,
                status,
              })
            }
          />
        );
      }
      if (annotation.metadata?.type === "file-decision") {
        const item = annotation.metadata;
        const busy = reviewItemBusy === `${item.file.path}:file`;
        return (
          <HunkDecision
            fileLevel
            status={item.decision.status}
            decision={item.decision}
            busy={busy}
            onDecide={(status) =>
              decideReviewItem({
                targetFile: item.file,
                status,
              })
            }
          />
        );
      }
      return (
        <InlineNote
          note={annotation.metadata}
          onOpen={focusNote}
        />
      );
    },
    [
      decideReviewItem,
      file,
      focusNote,
      reviewItemBusy,
      snapshot?.listener,
      submitAnnotation,
    ],
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
      enableGutterUtility: !composer,
      overflow: "scroll",
      unsafeCSS: DIFF_CSS,
      onGutterUtilityClick: openLineComposer,
    };
  }, [composer, context, openLineComposer, view]);

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

  const parsedFileDiff = useMemo(() => {
    if (!oldFile && !newFile) return null;
    try {
      return parseDiffFromFile(oldFile, newFile);
    } catch (error) {
      console.error("Could not parse the current file diff", error);
      return null;
    }
  }, [newFile, oldFile]);

  const renderedFileDiff = useMemo(() => {
    if (!parsedFileDiff || !fileState || fileFilter === "all") {
      return parsedFileDiff;
    }
    let nextDiff = parsedFileDiff;
    const completed = fileState.hunks.filter(
      (item) => item.status !== "pending",
    );
    if (!completed.length) return nextDiff;
    for (const item of completed) {
      const match = findChangeContent(nextDiff, item.hunk);
      if (!match) continue;
      nextDiff = diffAcceptRejectHunk(nextDiff, match.hunkIndex, {
        type: "accept",
        changeIndex: match.contentIndex,
      });
    }
    return nextDiff;
  }, [fileFilter, fileState, parsedFileDiff]);

  const goToHunk = useCallback(
    (direction) => {
      if (!navigableHunks.length || !viewportRef.current) return;
      const nextIndex =
        direction > 0
          ? (hunkIndex + 1) % navigableHunks.length
          : (hunkIndex - 1 + navigableHunks.length) % navigableHunks.length;
      setHunkIndex(nextIndex);
      const hunk = navigableHunks[nextIndex].hunk;
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
    [hunkIndex, navigableHunks],
  );

  useEffect(() => {
    const onKeyDown = (event) => {
      if (event.key === "Escape") {
        if (composer) {
          setComposer(null);
        } else if (notesOpened) {
          notesControls.close();
        }
        return;
      }
      if (
        ["INPUT", "TEXTAREA", "SELECT"].includes(
          document.activeElement?.tagName,
        ) ||
        document.activeElement?.isContentEditable ||
        event.metaKey ||
        event.ctrlKey
      ) {
        return;
      }
      if (event.key.toLowerCase() === "j") goToHunk(1);
      if (event.key.toLowerCase() === "k") goToHunk(-1);
      if (event.key.toLowerCase() === "m") toggleMap();
      if (event.key.toLowerCase() === "c") {
        if (notesOpened) notesControls.close();
        else openNotes();
      }
    };
    document.addEventListener("keydown", onKeyDown);
    return () => document.removeEventListener("keydown", onKeyDown);
  }, [
    composer,
    goToHunk,
    notesControls,
    notesOpened,
    openNotes,
    toggleMap,
  ]);

  return (
    <div className="app-shell">
      <Header
        snapshot={snapshot}
        connection={connection}
        listener={snapshot?.listener}
        onRefresh={() => loadState({ forceDiff: true })}
        mapVisible={mapVisible}
        onToggleMap={toggleMap}
        onStopListening={stopListening}
      />
      <main className={`workspace ${mapVisible ? "is-map-open" : "is-map-collapsed"}`}>
        <aside className="review-map-pane" aria-label="审阅单元地图">
          {mapVisible ? (
            <ReviewRail
              snapshot={snapshot}
              filter={filter}
              setFilter={setFilter}
              selection={selection}
              onSelect={selectChange}
              onAdopt={adoptPath}
              onCollapse={() => setMapVisible(false)}
            />
          ) : (
            <UnstyledButton
              className="map-rail-toggle"
              onClick={openMap}
              aria-label="展开变更地图"
              aria-expanded="false"
            >
              <span className="map-rail-count">{reviewChanges.length}</span>
              <span className="map-rail-label">变更地图</span>
              <span className="map-rail-chevron" aria-hidden="true">
                ›
              </span>
            </UnstyledButton>
          )}
        </aside>
        <section className="review-main" aria-label="代码差异">
          <ChangeHeader
            change={change}
            revision={revision}
            runtime={snapshot?.runtime}
            loading={!snapshot}
            onStatus={setStatus}
            onSelectChange={selectChange}
            onPreviousChange={() => previousChange && selectChange(previousChange.id)}
            onNextChange={() => nextChange && selectChange(nextChange.id)}
            canNavigate={reviewChanges.length > 1}
            onOpenNotes={openNotes}
            feedbackCount={change ? openFeedback(change).length : 0}
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
              file={file}
              files={visibleFiles}
              pendingFiles={pendingFiles}
              fileState={fileState}
              mode={mode}
              setMode={setMode}
              view={view}
              setView={setView}
              context={context}
              setContext={setContext}
              filePath={filePath}
              setFilePath={setFilePath}
              fileFilter={fileFilter}
              setFileFilter={setFileFilter}
              onRevision={selectRevision}
              onPreviousHunk={() => goToHunk(-1)}
              onNextHunk={() => goToHunk(1)}
              onFileNote={() => openFileComposer(false)}
              onAcceptFile={() =>
                decideReviewItem({
                  targetFile: file,
                  status:
                    fileState?.decision &&
                    fileState.decision.status !== "pending"
                      ? "pending"
                      : "accepted",
                })
              }
              reviewItemBusy={reviewItemBusy}
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
            ) : fileFilter === "pending" && !visibleFiles.length ? (
              <EmptyDiff
                title="这个修订没有待审内容"
                detail="文件和改动块都已处理。切换到“全部文件”可以撤销或查看已过滤内容。"
              />
            ) : !file ? (
              <EmptyDiff title="选择一个文件" />
            ) : file.binary ? (
              <EmptyDiff
                title="二进制文件"
                detail={`${file.path} 在本次比较中发生变化，但不包含可显示的文本。`}
              />
            ) : (
              <FileDiff
                key={`${revision?.id}:${file.path}:${view}:${context}:${fileFilter}`}
                fileDiff={renderedFileDiff}
                options={diffOptions}
                lineAnnotations={annotations}
                renderAnnotation={renderAnnotation}
                className="pierre-diff"
              />
            )}
          </Box>
        </section>
      </main>

      <Drawer
        opened={notesOpened}
        onClose={notesControls.close}
        position="right"
        size="min(500px, 96vw)"
        padding={0}
        title="原因与批注"
        closeButtonProps={{ "aria-label": "关闭原因与批注" }}
        overlayProps={{ backgroundOpacity: 0.12, blur: 0 }}
        transitionProps={{ duration: 160 }}
      >
        <Inspector
          change={change}
          revision={revision}
          runtime={snapshot?.runtime}
          listener={snapshot?.listener}
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
  listener,
  onRefresh,
  mapVisible,
  onToggleMap,
  onStopListening,
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
        <Tooltip label={mapVisible ? "收起变更地图 (M)" : "展开变更地图 (M)"}>
          <button
            type="button"
            className={`topbar-action ${mapVisible ? "is-active" : ""}`}
            onClick={onToggleMap}
            aria-keyshortcuts="M"
            aria-pressed={mapVisible}
          >
            变更地图
            <span className="topbar-count">{changes.length}</span>
          </button>
        </Tooltip>
        <ListenerStatus
          listener={listener}
          onStop={onStopListening}
        />
        <span
          className={`connection-state is-${connection}`}
          title={
            connection === "live"
              ? "审阅服务已连接"
              : connection === "error"
                ? "审阅服务连接失败"
                : "正在连接审阅服务"
          }
        >
          <span className="connection-dot" aria-hidden="true" />
          <span className="connection-label">
            {connection === "live"
              ? "已连接"
              : connection === "error"
                ? "连接失败"
                : "连接中"}
          </span>
        </span>
        <Tooltip label="刷新审阅状态">
          <ActionIcon
            className="refresh-button"
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

function ListenerStatus({ listener, onStop }) {
  const status = listener?.status || "unconfigured";
  const canStop = ["listening", "degraded", "error"].includes(status);
  return (
    <Tooltip
      label={listenerDetail(listener)}
      multiline
      w={280}
      position="bottom-end"
      events={{ hover: true, focus: true, touch: true }}
    >
      <div
        className={`listener-status is-${status}`}
        aria-label={`Agent 监听状态：${LISTENER_LABELS[status] || status}`}
      >
        <span className="listener-status-dot" aria-hidden="true" />
        <span className="listener-status-label">
          {LISTENER_LABELS[status] || status}
        </span>
        <span className="listener-status-short">
          {LISTENER_SHORT_LABELS[status] || "未连接"}
        </span>
        {canStop && (
          <button
            type="button"
            className="listener-stop"
            onClick={onStop}
          >
            停止
          </button>
        )}
      </div>
    </Tooltip>
  );
}

function ReviewRail({
  snapshot,
  filter,
  setFilter,
  selection,
  onSelect,
  onAdopt,
  onCollapse,
}) {
  if (!snapshot) {
    return (
      <Box className="review-map">
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
      : snapshot.state.changes.filter(changeNeedsAttention);
  const activeCount = snapshot.state.changes.filter(
    (change) => change.status !== "superseded",
  ).length;
  return (
    <div className="review-map">
      <div className="rail-heading">
        <div>
          <Text className="eyebrow">变更地图</Text>
          <Text className="rail-count">
            {activeCount} 个审阅单元
          </Text>
        </div>
        <div className="rail-heading-actions">
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
          <Tooltip label="收起地图 (M)">
            <ActionIcon
              variant="subtle"
              color="gray"
              size="sm"
              aria-label="收起变更地图"
              onClick={onCollapse}
            >
              ‹
            </ActionIcon>
          </Tooltip>
        </div>
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
          const review = reviewTargets(change);
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
                  {review.pending
                    ? `${review.pending} 项待审`
                    : review.excluded_items
                      ? `${review.excluded_items} 项已过滤`
                      : `${change.revisions.length} 次`}
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
  onPreviousChange,
  onNextChange,
  canNavigate,
  onOpenNotes,
  feedbackCount,
  onUseLatest,
}) {
  const latestRevision = change?.revisions.at(-1);
  return (
    <header className="change-heading">
      <div className="change-title-row">
        <div className="change-title-copy">
          <Text className="eyebrow">
            {loading
              ? "正在载入变更"
              : change
                ? `${STATUS_LABELS[change.status] || change.status} · ${change.id}`
                : "选择一项变更"}
          </Text>
          <Title order={2}>
            {loading
              ? "正在读取审阅记录"
              : change?.title || "还没有可审阅的变更"}
          </Title>
        </div>
        {change && (
          <div className="change-actions">
            <div className="change-pager" aria-label="审阅单元导航">
              <Button
                variant="subtle"
                color="gray"
                size="compact-xs"
                disabled={!canNavigate}
                onClick={onPreviousChange}
              >
                上一项
              </Button>
              <Button
                variant="subtle"
                color="gray"
                size="compact-xs"
                disabled={!canNavigate}
                onClick={onNextChange}
              >
                下一项
              </Button>
            </div>
            <Button
              className="context-button"
              variant="default"
              color="gray"
              size="compact-xs"
              onClick={onOpenNotes}
              aria-keyshortcuts="C"
            >
              原因与批注
              {feedbackCount > 0 && (
                <span className="context-count">{feedbackCount}</span>
              )}
            </Button>
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
  file,
  files,
  pendingFiles,
  fileState,
  mode,
  setMode,
  view,
  setView,
  context,
  setContext,
  filePath,
  setFilePath,
  fileFilter,
  setFileFilter,
  onRevision,
  onPreviousHunk,
  onNextHunk,
  onFileNote,
  onAcceptFile,
  reviewItemBusy,
}) {
  const decisions = reviewDecisions(change, revision);
  const pendingHunkCount = fileState?.pendingHunks.length || 0;
  const fileDecision = fileState?.decision;
  const fileBusy =
    file && reviewItemBusy === `${file.path}:file`;
  const fileActionLabel = fileDecision
    ? fileDecision.status === "excluded"
      ? "撤销过滤"
      : "撤销通过"
    : fileState?.status === "accepted"
      ? "文件已通过"
      : fileState?.status === "excluded"
        ? "文件已过滤"
        : "通过文件";
  return (
    <div className="diff-toolbar">
      <div className="toolbar-row toolbar-row-primary">
        <Select
          aria-label="修订"
          className="revision-select"
          size="xs"
          w={180}
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
        <SegmentedControl
          size="xs"
          value={fileFilter}
          onChange={setFileFilter}
          aria-label="文件范围"
          data={[
            {
              value: "pending",
              label: `待审 ${pendingFiles.length}`,
            },
            {
              value: "all",
              label: `全部 ${diff?.files.length || 0}`,
            },
          ]}
        />
        <Select
          aria-label="文件"
          size="xs"
          className="file-select-wrap"
          value={filePath}
          onChange={setFilePath}
          allowDeselect={false}
          searchable={files.length > 8}
          disabled={!files.length}
          data={files.map((item) => {
            const status = fileReviewState(item, decisions).status;
            return {
              value: item.path,
              label: `${item.old_path ? `${item.old_path} → ` : ""}${item.path}${
                status === "pending"
                  ? ""
                  : ` · ${REVIEW_ITEM_LABELS[status]}`
              }`,
            };
          })}
        />
      </div>
      <div className="toolbar-row toolbar-row-secondary">
        <span className="hunk-progress">
          {pendingHunkCount
            ? `待审 ${pendingHunkCount} 个改动块`
            : fileState?.status === "excluded"
              ? "文件已过滤"
              : "没有待审改动块"}
        </span>
        <Tooltip label="上一个待审改动块 (K)">
          <Button
            className="hunk-nav"
            variant="subtle"
            color="gray"
            size="compact-xs"
            disabled={!pendingHunkCount}
            onClick={onPreviousHunk}
          >
            ↑ 改动
          </Button>
        </Tooltip>
        <Tooltip label="下一个待审改动块 (J)">
          <Button
            className="hunk-nav"
            variant="subtle"
            color="gray"
            size="compact-xs"
            disabled={!pendingHunkCount}
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
          w={82}
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
        <div className="toolbar-spacer" />
        <Button
          className="file-note-button"
          variant="subtle"
          color="gray"
          size="compact-xs"
          disabled={!file}
          onClick={onFileNote}
        >
          文件批注
        </Button>
        <Button
          className="file-accept-button"
          variant={fileDecision ? "light" : "filled"}
          color={fileDecision ? "gray" : "teal"}
          size="compact-xs"
          disabled={
            !file ||
            (!fileDecision &&
              ["accepted", "excluded"].includes(fileState?.status))
          }
          loading={fileBusy}
          onClick={onAcceptFile}
        >
          {fileActionLabel}
        </Button>
      </div>
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

function HunkDecision({
  status,
  decision,
  busy,
  onDecide,
  fileLevel = false,
}) {
  const terminal = status !== "pending";
  const label = REVIEW_ITEM_LABELS[status] || status;
  return (
    <div className={`hunk-decision is-${status}`}>
      <span className="hunk-decision-copy">
        <span className="hunk-decision-title">
          {fileLevel ? "整个文件" : "改动块"}
        </span>
        <span className={`hunk-decision-state is-${status}`}>{label}</span>
        {decision?.author && (
          <span className="hunk-decision-author">
            {decision.author === "user" ? "你" : "Agent"}
          </span>
        )}
      </span>
      {decision?.reason && (
        <span className="hunk-decision-reason">{decision.reason}</span>
      )}
      <Button
        variant={terminal ? "subtle" : "filled"}
        color={terminal ? "gray" : "teal"}
        size="compact-xs"
        loading={busy}
        onClick={() => onDecide(terminal ? "pending" : "accepted")}
      >
        {terminal ? "撤销" : fileLevel ? "通过文件" : "通过此块"}
      </Button>
    </div>
  );
}

function Inspector({
  change,
  revision,
  runtime,
  listener,
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
              listener={listener}
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
  const delivery = note.delivery;
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
        {delivery && (
          <span className={`delivery-chip is-${delivery.state}`}>
            {DELIVERY_LABELS[delivery.state] || delivery.state}
          </span>
        )}
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
              {reply.delivery && (
                <span className={`delivery-chip is-${reply.delivery.state}`}>
                  {DELIVERY_LABELS[reply.delivery.state] ||
                    reply.delivery.state}
                </span>
              )}
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

function Composer({
  composer,
  listener,
  inline = false,
  onCancel,
  onSubmit,
}) {
  const [kind, setKind] = useState("change");
  const [body, setBody] = useState("");
  const [suggestion, setSuggestion] = useState("");
  const [withSuggestion, setWithSuggestion] = useState(false);
  const [submitting, setSubmitting] = useState(false);
  const bodyRef = useRef(null);
  const deliveryHint = composerDeliveryHint(listener);

  useEffect(() => {
    if (inline) bodyRef.current?.focus();
  }, [inline]);

  const submit = async () => {
    if (!body.trim() || submitting) return;
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
  };

  return (
    <Paper
      component="form"
      className={`composer ${inline ? "is-inline" : ""}`}
      withBorder
      onSubmit={(event) => {
        event.preventDefault();
        submit();
      }}
    >
      <div className="composer-heading">
        <div>
          <Title order={3}>
            {inline ? "添加行批注" : "写下你的判断"}
          </Title>
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
      <SegmentedControl
        fullWidth
        size="xs"
        value={kind}
        onChange={setKind}
        aria-label="批注类型"
        className="composer-kind-picker"
        data={ANNOTATION_KIND_OPTIONS}
      />
      <Textarea
        ref={bodyRef}
        className="composer-body"
        autosize
        minRows={inline ? 3 : 4}
        maxRows={10}
        placeholder="具体哪里不对？希望怎么改？"
        aria-label="批注内容"
        value={body}
        onChange={(event) => setBody(event.currentTarget.value)}
        onKeyDown={(event) => {
          if ((event.metaKey || event.ctrlKey) && event.key === "Enter") {
            event.preventDefault();
            event.currentTarget.form?.requestSubmit();
          }
        }}
      />
      {composer.excerpt && (
        <div className="composer-context">
          <span className="composer-context-label">选中代码</span>
          <pre className="composer-excerpt">{composer.excerpt}</pre>
        </div>
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
      <div className="composer-actions">
        <Text className="composer-hint">{deliveryHint}</Text>
        <Group gap="xs" wrap="nowrap">
          <Button
            type="button"
            variant="subtle"
            color="gray"
            size="xs"
            onClick={onCancel}
          >
            取消
          </Button>
          <Button
            type="submit"
            size="xs"
            loading={submitting}
            disabled={!body.trim()}
            title="提交 (Ctrl/Cmd + Enter)"
          >
            提交批注
          </Button>
        </Group>
      </div>
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
