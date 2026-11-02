import { useEffect, useMemo, useRef, useState } from "react";
import { parseDiffFromFile, registerCustomTheme } from "@pierre/diffs";
import { FileDiff } from "@pierre/diffs/react";
import pierreLight from "@pierre/highlights/themes/pierre-light";

registerCustomTheme("review-light", () => Promise.resolve(pierreLight), "zed");
const sideName = (side) => (side === "deletions" ? "old" : "new");
const rowSide = (row) =>
  row.closest("[data-deletions]") || row.dataset.lineType?.includes("deletion")
    ? "old"
    : "new";

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
  onThread,
  onError,
  jump,
}) {
  const container = useRef(null);
  const stroke = useRef([]);
  const [activeStroke, setActiveStroke] = useState([]);
  const [savedStrokes, setSavedStrokes] = useState([]);
  const [selection, setSelection] = useState(null);
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

  function selectLines(range) {
    if (!range || drawing) return;
    setSelection(range);
    if (range.endSide && range.endSide !== range.side) {
      onSelect([
        makeTarget(sideName(range.side), range.start, range.start),
        makeTarget(sideName(range.endSide), range.end, range.end),
      ]);
    } else {
      onSelect([
        makeTarget(
          sideName(range.side),
          Math.min(range.start, range.end),
          Math.max(range.start, range.end),
        ),
      ]);
    }
  }

  function selectText() {
    if (drawing) return;
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
    onSelect([target]);
  }

  const annotations = threads.flatMap((thread) =>
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
        metadata: thread,
      })),
  );

  useEffect(() => {
    setSelection(null);
  }, [file.path, revision, against]);

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
          const marked = targets.some(
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
          targets
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
  }, [file.path, targets, style, expanded]);

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
    onSelect([target]);
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
    >
      <FileDiff
        fileDiff={fileDiff}
        options={options}
        selectedLines={selection}
        lineAnnotations={annotations}
        renderAnnotation={({ metadata }) => (
          <button className="inline-thread" onClick={() => onThread(metadata)}>
            ↳ {metadata.messages[0].body.slice(0, 100)}{" "}
            <span>{metadata.status === "open" ? "讨论" : "已解决"}</span>
          </button>
        )}
      />
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
