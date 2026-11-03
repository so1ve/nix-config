import { useEffect, useMemo, useRef, useState } from "react";
import { Button, Menu } from "@mantine/core";
import { parseDiffFromFile, registerCustomTheme } from "@pierre/diffs";
import { FileDiff } from "@pierre/diffs/react";
import pierreLight from "@pierre/highlights/themes/pierre-light";

registerCustomTheme("review-light", () => Promise.resolve(pierreLight), "zed");
const sideName = (side) => (side === "deletions" ? "old" : "new");
const rowSide = (row) =>
  row.closest("[data-deletions]") || row.dataset.lineType?.includes("deletion")
    ? "old"
    : "new";
const reviewLabels = {
  pending: "待审",
  accepted: "已通过",
  excluded: "已排除",
  feedback: "待回应",
};

export function CodeCanvas({
  file,
  revision,
  against,
  style,
  expanded,
  drawing,
  setDrawing,
  targets,
  threads,
  onSelect,
  hasDraft,
  review,
  busy,
  onDecide,
  onThread,
  onError,
  jump,
}) {
  const container = useRef(null);
  const stroke = useRef([]);
  const [activeStroke, setActiveStroke] = useState([]);
  const [savedStrokes, setSavedStrokes] = useState([]);
  const [selection, setSelection] = useState(null);
  const [menu, setMenu] = useState(null);
  const markedTargets = useMemo(
    () => [...targets, ...(menu?.targets || [])],
    [targets, menu?.targets],
  );
  const currentSelection = useRef([]);
  const root = () =>
    container.current?.querySelector("diffs-container")?.shadowRoot;
  const rows = () =>
    [...(root()?.querySelectorAll("[data-line]") || [])].filter((row) =>
      row.closest("code"),
    );
  const fileDiff = useMemo(
    () =>
      parseDiffFromFile(
        file.old ? { name: file.old_path, contents: file.old.text } : null,
        file.new ? { name: file.path, contents: file.new.text } : null,
      ),
    [file.path, file.old?.text, file.new?.text, file.old_path],
  );

  function makeTarget(side, start, end, quote) {
    const lines = file[side]?.text?.split(/\r?\n/) || [];
    start = Math.max(1, Math.min(start, lines.length));
    end = Math.max(start, Math.min(end, lines.length));
    return {
      path: file.path,
      side,
      start,
      end,
      quote: quote ?? lines.slice(start - 1, end).join("\n"),
    };
  }

  function showActions(selectedTargets, point, blocks) {
    if (!blocks) currentSelection.current = selectedTargets;
    const last = selectedTargets.at(-1);
    const row = rows().find(
      (r) => rowSide(r) === last.side && Number(r.dataset.line) === last.end,
    );
    const box =
      row?.getBoundingClientRect() || container.current.getBoundingClientRect();
    setMenu({
      targets: selectedTargets,
      blocks:
        blocks ||
        file.blocks.filter((block) =>
          selectedTargets.some(
            (target) =>
              block[`${target.side}_count`] > 0 &&
              target.start <
                block[`${target.side}_start`] + block[`${target.side}_count`] &&
              target.end >= block[`${target.side}_start`],
          ),
        ),
      blockOnly: !!blocks,
      keyboard: point?.keyboard || false,
      x: Math.max(
        8,
        Math.min(point?.x ?? box.left + 60, window.innerWidth - 16),
      ),
      y: Math.max(8, Math.min(point?.y ?? box.bottom, window.innerHeight - 16)),
    });
  }

  function selectLines(range) {
    if (!range || drawing) return;
    setSelection(range);
    if (range.endSide && range.endSide !== range.side) {
      showActions([
        makeTarget(sideName(range.side), range.start, range.start),
        makeTarget(sideName(range.endSide), range.end, range.end),
      ]);
    } else {
      showActions([
        makeTarget(
          sideName(range.side),
          Math.min(range.start, range.end),
          Math.max(range.start, range.end),
        ),
      ]);
    }
  }

  function textSelection() {
    const selected = root()?.getSelection?.() || window.getSelection();
    if (!selected || selected.isCollapsed || !selected.toString().trim())
      return;
    const startRow = selected.anchorNode?.parentElement?.closest("[data-line]");
    const endRow = selected.focusNode?.parentElement?.closest("[data-line]");
    if (
      !startRow ||
      !endRow ||
      startRow.getRootNode() !== root() ||
      rowSide(startRow) !== rowSide(endRow)
    )
      return;
    const start = Math.min(
      Number(startRow.dataset.line),
      Number(endRow.dataset.line),
    );
    const end = Math.max(
      Number(startRow.dataset.line),
      Number(endRow.dataset.line),
    );
    const target = makeTarget(rowSide(startRow), start, end);
    const quote = selected.toString();
    // Some browsers include gutter text in a cross-row selection.
    if (target.quote.includes(quote)) target.quote = quote;
    return { target, range: selected.getRangeAt(0) };
  }

  function selectText(event) {
    if (drawing || event.button === 2) return;
    if (
      event.nativeEvent
        .composedPath()
        .some((element) => element?.matches?.("button, [role=menu]"))
    )
      return;
    const selected = textSelection();
    if (!selected) return;
    const box = selected.range.getBoundingClientRect();
    setSelection(null);
    showActions([selected.target], {
      x: event.clientX ?? box.left,
      y: event.clientY ?? box.bottom,
    });
  }

  function contextMenu(event) {
    if (drawing) return;
    const row = event.nativeEvent
      .composedPath()
      .find((element) => element?.matches?.("[data-line]"));
    if (!row) return;
    event.preventDefault();
    const side = rowSide(row);
    const line = Number(row.dataset.line);
    const text = textSelection();
    const selected = text ? [text.target] : currentSelection.current;
    const inSelection = selected.some(
      (target) =>
        target.side === side && line >= target.start && line <= target.end,
    );
    showActions(inSelection ? selected : [makeTarget(side, line, line)], {
      x: event.clientX,
      y: event.clientY,
    });
  }

  function blockTargets(block) {
    return ["old", "new"]
      .filter((side) => block[`${side}_count`] > 0)
      .map((side) =>
        makeTarget(
          side,
          block[`${side}_start`],
          block[`${side}_start`] + block[`${side}_count`] - 1,
        ),
      );
  }

  const annotations = useMemo(
    () => [
      ...file.blocks.map((block, index) => {
        const side = block.new_count ? "new" : "old";
        return {
          side: side === "old" ? "deletions" : "additions",
          lineNumber: block[`${side}_start`] - 1,
          metadata: { kind: "block", block, index },
        };
      }),
      ...(against === "base" ? review?.decision.regions || [] : []).map(
        (region) => ({
          side: region.side === "old" ? "deletions" : "additions",
          lineNumber: region.end,
          metadata: { kind: "region", region },
        }),
      ),
      ...threads.flatMap((thread) =>
        thread.targets
          .filter(
            (target) =>
              target.path === file.path &&
              thread.revision === revision &&
              thread.against === against,
          )
          .map((target) => ({
            side: target.side === "old" ? "deletions" : "additions",
            lineNumber: target.side === "file" ? 0 : target.end,
            metadata: { kind: "thread", thread },
          })),
      ),
    ],
    [file.blocks, file.path, against, revision, review, threads],
  );

  useEffect(() => {
    setSelection(null);
    setMenu(null);
    currentSelection.current = [];
  }, [file.path, revision, against]);

  useEffect(() => {
    setMenu(null);
  }, [style, expanded]);

  useEffect(() => {
    if (drawing) setMenu(null);
  }, [drawing]);

  useEffect(() => {
    const scroller = container.current.closest(".diff-scroll");
    const close = () => setMenu(null);
    scroller.addEventListener("scroll", close);
    window.addEventListener("resize", close);
    return () => {
      scroller.removeEventListener("scroll", close);
      window.removeEventListener("resize", close);
    };
  }, []);

  useEffect(() => {
    const element = container.current;
    if (!element) return;
    let frame;
    const measure = () => {
      cancelAnimationFrame(frame);
      frame = requestAnimationFrame(() => {
        const origin = element.getBoundingClientRect();
        const visible = rows();
        for (const row of visible) {
          const marked = markedTargets.some(
            (target) =>
              target.path === file.path &&
              target.side === rowSide(row) &&
              Number(row.dataset.line) >= target.start &&
              Number(row.dataset.line) <= target.end,
          );
          row.style.boxShadow = marked
            ? "inset 3px 0 #3272d9, inset 0 0 0 999px #4488dd12"
            : "";
        }
        setSavedStrokes(
          markedTargets
            .filter((target) => target.path === file.path && target.drawing)
            .flatMap((target) => {
              const selected = visible.filter(
                (row) =>
                  rowSide(row) === target.side &&
                  Number(row.dataset.line) >= target.start &&
                  Number(row.dataset.line) <= target.end,
              );
              if (!selected.length) return [];
              const boxes = selected.map((row) => row.getBoundingClientRect());
              const left = Math.min(...boxes.map((b) => b.left));
              const top = Math.min(...boxes.map((b) => b.top));
              const width = Math.max(...boxes.map((b) => b.right)) - left;
              const height = Math.max(...boxes.map((b) => b.bottom)) - top;
              return [
                target.drawing.points
                  .map(
                    ([x, y]) =>
                      `${left - origin.left + x * (target.drawing.width ?? width)},${top - origin.top + y * height}`,
                  )
                  .join(" "),
              ];
            }),
        );
      });
    };
    const resize = new ResizeObserver(measure);
    resize.observe(element);
    const observer = new MutationObserver(measure);
    if (root()) observer.observe(root(), { childList: true, subtree: true });
    element.addEventListener("scroll", measure, true);
    measure();
    return () => {
      cancelAnimationFrame(frame);
      resize.disconnect();
      observer.disconnect();
      element.removeEventListener("scroll", measure, true);
    };
  }, [file.path, markedTargets, style, expanded]);

  useEffect(() => {
    if (!jump || jump.path !== file.path) return;
    const row = rows().find(
      (r) => Number(r.dataset.line) === jump.start && rowSide(r) === jump.side,
    );
    row?.scrollIntoView({ block: "center", behavior: "instant" });
    setSelection({
      start: jump.start,
      end: jump.end,
      side: jump.side === "old" ? "deletions" : "additions",
    });
  }, [jump]);

  function pointer(event) {
    const box = container.current.getBoundingClientRect();
    return [event.clientX - box.left, event.clientY - box.top];
  }

  function finishDrawing(event) {
    if (!stroke.current.length) return;
    const points = [...stroke.current, pointer(event)];
    stroke.current = [];
    setActiveStroke([]);
    setDrawing(false);
    const origin = container.current.getBoundingClientRect();
    const top = Math.min(...points.map((p) => p[1])) + origin.top;
    const bottom = Math.max(...points.map((p) => p[1])) + origin.top;
    const x = points[0][0] + origin.left;
    const candidates = rows().filter((row) => {
      const b = row.getBoundingClientRect();
      return b.bottom > top && b.top < bottom && x >= b.left && x <= b.right;
    });
    if (!candidates.length) {
      onError("请在代码文字上圈画；也可以拖选行号后标注。");
      return;
    }
    const side = rowSide(candidates[0]);
    const selected = candidates.filter((r) => rowSide(r) === side);
    const numbers = selected.map((r) => Number(r.dataset.line));
    const boxes = selected.map((r) => r.getBoundingClientRect());
    const left = Math.min(...boxes.map((b) => b.left)) - origin.left;
    const y = Math.min(...boxes.map((b) => b.top)) - origin.top;
    const width = Math.max(...boxes.map((b) => b.right)) - origin.left - left;
    const height = Math.max(...boxes.map((b) => b.bottom)) - origin.top - y;
    const clamp = (n) => Math.max(0, Math.min(1, n));
    const target = makeTarget(side, Math.min(...numbers), Math.max(...numbers));
    target.drawing = {
      width,
      points: points
        .filter((_, i) => i % Math.ceil(points.length / 1900) === 0)
        .map(([px, py]) => [
          clamp((px - left) / width),
          clamp((py - y) / height),
        ]),
    };
    showActions([target], { x: event.clientX, y: event.clientY });
  }

  const options = useMemo(
    () => ({
      theme: "review-light",
      themeType: "light",
      preferredHighlighter: "highlights",
      diffStyle: style,
      diffIndicators: "bars",
      lineDiffType: "word-alt",
      hunkSeparators: "line-info-basic",
      expandUnchanged: expanded,
      expansionLineCount: 20,
      lineHoverHighlight: "both",
      overflow: "scroll",
      enableLineSelection: true,
      enableGutterUtility: true,
      onLineSelectionEnd: selectLines,
      onGutterUtilityClick: selectLines,
      unsafeCSS:
        ":host{--diffs-font-size:13px;--diffs-line-height:24px} [data-diffs-header]{display:none} [data-line-annotation]{font-family:system-ui,sans-serif}",
    }),
    [style, expanded, drawing, file, onSelect],
  );

  return (
    <div
      className={`code-canvas ${drawing ? "drawing" : ""}`}
      ref={container}
      onPointerUp={selectText}
      onPointerDown={(event) => {
        if (event.button === 0 && !event.shiftKey)
          currentSelection.current = [];
      }}
      onContextMenu={contextMenu}
      onKeyUp={(event) => {
        if (event.key === "Shift") selectText(event);
      }}
      tabIndex={0}
      aria-label="代码差异"
    >
      <FileDiff
        fileDiff={fileDiff}
        options={options}
        selectedLines={selection}
        lineAnnotations={annotations}
        renderAnnotation={({ metadata }) => {
          if (metadata.kind === "thread") {
            const thread = metadata.thread;
            return (
              <button
                className="inline-thread"
                onClick={() => onThread(thread)}
              >
                ↳ {thread.messages[0].body.slice(0, 100)}{" "}
                <span>{thread.status === "open" ? "讨论" : "已解决"}</span>
              </button>
            );
          }
          if (metadata.kind === "region") {
            const region = metadata.region;
            return (
              <div className="inline-region">
                <span>
                  {region.side === "old" ? "旧" : "新"} {region.start}–
                  {region.end} 行
                </span>
                <span className={`status status-${region.status}`}>
                  {reviewLabels[region.status]}
                </span>
                {region.reason && <span>{region.reason}</span>}
                {region.status !== "pending" && (
                  <Button
                    size="compact-xs"
                    variant="subtle"
                    disabled={busy}
                    onClick={() =>
                      onDecide("pending", {
                        targets: [
                          makeTarget(region.side, region.start, region.end),
                        ],
                      })
                    }
                  >
                    重新审阅选区
                  </Button>
                )}
              </div>
            );
          }
          const { block, index } = metadata;
          const status =
            against === "base"
              ? review?.blocks.find((b) => b.id === block.id)?.review_status ||
                "pending"
              : "pending";
          const reason =
            against === "base"
              ? review?.decision.blocks?.[block.id]?.reason
              : null;
          return (
            <div className="inline-block" aria-label={`改动块 ${index + 1}`}>
              <span className="block-location">
                改动块 {index + 1} ·{" "}
                {block.new_count
                  ? `新 ${block.new_start}–${block.new_start + block.new_count - 1}`
                  : `旧 ${block.old_start}–${block.old_start + block.old_count - 1}`}{" "}
                行
              </span>
              {against === "base" && (
                <span className={`status status-${status}`}>
                  {reviewLabels[status]}
                </span>
              )}
              <div className="actions">
                <Button
                  size="compact-xs"
                  variant="subtle"
                  disabled={
                    busy ||
                    against !== "base" ||
                    (status === "pending" &&
                      review?.review_status === "feedback")
                  }
                  onClick={() =>
                    onDecide(status === "pending" ? "accepted" : "pending", {
                      blocks: [block],
                    })
                  }
                >
                  {status === "pending" ? "通过此块" : "重新审阅此块"}
                </Button>
                <Button
                  size="compact-xs"
                  variant="subtle"
                  onClick={(event) => {
                    const box = event.currentTarget.getBoundingClientRect();
                    showActions(
                      blockTargets(block),
                      {
                        x: box.left,
                        y: box.bottom,
                        keyboard: event.detail === 0,
                      },
                      [block],
                    );
                  }}
                  aria-label={`改动块 ${index + 1} 的更多操作`}
                >
                  更多
                </Button>
              </div>
              {reason && <small className="block-reason">{reason}</small>}
            </div>
          );
        }}
      />
      <Menu
        opened={!!menu}
        onChange={(opened) => {
          if (!opened) setMenu(null);
        }}
        position="bottom-start"
        offset={6}
        shadow="md"
        width={260}
        withinPortal
        trapFocus={menu?.keyboard || false}
        returnFocus={false}
        menuItemTabIndex={0}
        withInitialFocusPlaceholder={false}
        transitionProps={{ duration: 0 }}
      >
        <Menu.Target>
          <span
            className="code-menu-anchor"
            style={{ left: menu?.x || 0, top: menu?.y || 0 }}
          />
        </Menu.Target>
        <Menu.Dropdown
          aria-label="代码审阅操作"
          onPointerUp={(event) => event.stopPropagation()}
          style={{ maxHeight: "calc(100dvh - 16px)", overflowY: "auto" }}
        >
          {menu && (
            <>
              {!menu.blockOnly && (
                <>
                  <Menu.Label>
                    {menu.targets
                      .map(
                        (t) =>
                          `${t.side === "old" ? "旧" : "新"} ${t.start}${t.end === t.start ? "" : `–${t.end}`} 行`,
                      )
                      .join("、")}
                  </Menu.Label>
                  <Menu.Item onClick={() => onSelect(menu.targets)}>
                    {hasDraft ? "替换当前标注" : "评论选区"}
                  </Menu.Item>
                  {hasDraft && (
                    <Menu.Item onClick={() => onSelect(menu.targets, true)}>
                      添加到当前标注
                    </Menu.Item>
                  )}
                  <Menu.Item
                    disabled={
                      busy ||
                      against !== "base" ||
                      review?.review_status === "feedback"
                    }
                    onClick={() =>
                      onDecide("accepted", { targets: menu.targets })
                    }
                  >
                    仅通过所选行
                  </Menu.Item>
                  <Menu.Item
                    disabled={busy || against !== "base"}
                    onClick={() =>
                      onDecide("excluded", { targets: menu.targets })
                    }
                  >
                    排除所选行…
                  </Menu.Item>
                  <Menu.Item
                    disabled={busy || against !== "base"}
                    onClick={() =>
                      onDecide("pending", { targets: menu.targets })
                    }
                  >
                    重新审阅所选行
                  </Menu.Item>
                </>
              )}
              {!!menu.blocks.length && (
                <>
                  {!menu.blockOnly && <Menu.Divider />}
                  <Menu.Label>
                    {menu.blocks.length === 1
                      ? `所在改动块 ${file.blocks.findIndex((b) => b.id === menu.blocks[0].id) + 1}`
                      : `选区涉及 ${menu.blocks.length} 个改动块`}
                  </Menu.Label>
                  <Menu.Item
                    onClick={() => onSelect(menu.blocks.flatMap(blockTargets))}
                  >
                    评论
                    {menu.blocks.length === 1
                      ? "整个改动块"
                      : `这 ${menu.blocks.length} 个改动块`}
                  </Menu.Item>
                  {menu.blockOnly && hasDraft && (
                    <Menu.Item onClick={() => onSelect(menu.targets, true)}>
                      添加到当前标注
                    </Menu.Item>
                  )}
                  <Menu.Item
                    disabled={
                      busy ||
                      against !== "base" ||
                      review?.review_status === "feedback"
                    }
                    onClick={() =>
                      onDecide("accepted", { blocks: menu.blocks })
                    }
                  >
                    通过
                    {menu.blocks.length === 1
                      ? "整个改动块"
                      : `这 ${menu.blocks.length} 个改动块`}
                  </Menu.Item>
                  <Menu.Item
                    disabled={busy || against !== "base"}
                    onClick={() =>
                      onDecide("excluded", { blocks: menu.blocks })
                    }
                  >
                    排除
                    {menu.blocks.length === 1
                      ? "整个改动块"
                      : `这 ${menu.blocks.length} 个改动块`}
                    …
                  </Menu.Item>
                  <Menu.Item
                    disabled={busy || against !== "base"}
                    onClick={() => onDecide("pending", { blocks: menu.blocks })}
                  >
                    重新审阅
                    {menu.blocks.length === 1
                      ? "整个改动块"
                      : `这 ${menu.blocks.length} 个改动块`}
                  </Menu.Item>
                </>
              )}
              {against !== "base" && (
                <Menu.Label>切回完整改动后可标记通过</Menu.Label>
              )}
            </>
          )}
        </Menu.Dropdown>
      </Menu>
      <svg
        className={`drawing-layer ${drawing ? "active" : ""}`}
        aria-label={drawing ? "在代码上拖动圈画" : "圈画标注"}
        onPointerDown={(event) => {
          if (!drawing) return;
          event.currentTarget.setPointerCapture(event.pointerId);
          stroke.current = [pointer(event)];
          setActiveStroke(stroke.current);
        }}
        onPointerMove={(event) => {
          if (!stroke.current.length) return;
          stroke.current.push(pointer(event));
          setActiveStroke([...stroke.current]);
        }}
        onPointerUp={finishDrawing}
        onPointerCancel={() => {
          stroke.current = [];
          setActiveStroke([]);
          setDrawing(false);
        }}
      >
        {savedStrokes.map((points, i) => (
          <polyline key={i} points={points} />
        ))}
        {!!activeStroke.length && (
          <polyline points={activeStroke.map((p) => p.join(",")).join(" ")} />
        )}
      </svg>
    </div>
  );
}
