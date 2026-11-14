import { ArrowDown } from "lucide-react";
import { FitToWidth } from "@/components/help/fit-to-width";
import { vi } from "@/i18n/vi";
import type { FlowDiagram, FlowNode } from "@/i18n/help/types";
import { cn } from "@/lib/utils";

/** Kích thước ô lưới (px). */
const CW = 150; // chiều rộng cột
const NW = 134; // chiều rộng ô
const NH = 70; // chiều cao ô
const LH = 116; // chiều cao hàng bơi
const LABEL_W = 116; // cột tên hàng bơi

/** Bảng màu theo hàng bơi (viền trái ô + nền nhạt tên hàng). */
const LANE_STYLES = [
  { bar: "border-l-blue-500", chip: "bg-blue-500/10 text-blue-700 dark:text-blue-300", dot: "bg-blue-500" },
  { bar: "border-l-emerald-500", chip: "bg-emerald-500/10 text-emerald-700 dark:text-emerald-300", dot: "bg-emerald-500" },
  { bar: "border-l-violet-500", chip: "bg-violet-500/10 text-violet-700 dark:text-violet-300", dot: "bg-violet-500" },
  { bar: "border-l-amber-500", chip: "bg-amber-500/10 text-amber-700 dark:text-amber-300", dot: "bg-amber-500" },
  { bar: "border-l-rose-500", chip: "bg-rose-500/10 text-rose-700 dark:text-rose-300", dot: "bg-rose-500" },
  { bar: "border-l-teal-500", chip: "bg-teal-500/10 text-teal-700 dark:text-teal-300", dot: "bg-teal-500" },
];
const laneStyle = (i: number) => LANE_STYLES[i % LANE_STYLES.length];

function center(n: FlowNode): { x: number; y: number } {
  return { x: LABEL_W + n.col * CW + CW / 2, y: n.lane * LH + LH / 2 };
}

type Pt = { x: number; y: number };
type Path = { d: string; lx: number; ly: number; anchor: "middle" | "start" };

/** Chuyển danh sách điểm (chỉ đi ngang/dọc) thành chuỗi path H/V và vị trí nhãn trên đoạn dài nhất. */
function toPath(pts: Pt[]): Path {
  let d = `M ${pts[0].x} ${pts[0].y}`;
  let best = { len: -1, i: 0 };
  for (let k = 1; k < pts.length; k++) {
    const a = pts[k - 1];
    const b = pts[k];
    d += a.y === b.y ? ` H ${b.x}` : ` V ${b.y}`;
    const len = Math.abs(b.x - a.x) + Math.abs(b.y - a.y);
    if (len > best.len) best = { len, i: k };
  }
  const a = pts[best.i - 1];
  const b = pts[best.i];
  if (a.y === b.y) {
    return { d, lx: (a.x + b.x) / 2, ly: a.y - 6, anchor: "middle" };
  }
  return { d, lx: a.x + 6, ly: (a.y + b.y) / 2, anchor: "start" };
}

/** Đường nối giữa hai ô: thẳng, gấp khúc, hoặc vòng ngược (nét đứt). */
export function edgePath(a: FlowNode, b: FlowNode): Path {
  const A = center(a);
  const B = center(b);
  if (b.col > a.col) {
    const sx = A.x + NW / 2;
    const ex = B.x - NW / 2;
    if (a.lane === b.lane) {
      return toPath([
        { x: sx, y: A.y },
        { x: ex, y: A.y },
      ]);
    }
    const mx = ex - 14 > sx ? ex - 14 : (sx + ex) / 2;
    return toPath([
      { x: sx, y: A.y },
      { x: mx, y: A.y },
      { x: mx, y: B.y },
      { x: ex, y: B.y },
    ]);
  }
  if (b.col === a.col && a.lane !== b.lane) {
    const down = b.lane > a.lane;
    return toPath([
      { x: A.x, y: A.y + (down ? NH / 2 : -NH / 2) },
      { x: A.x, y: B.y + (down ? -NH / 2 : NH / 2) },
    ]);
  }
  // Vòng ngược (quay lại bước trước): đi xuống dưới rồi lên.
  const yy = Math.max(A.y, B.y) + NH / 2 + 18;
  return toPath([
    { x: A.x, y: A.y + NH / 2 },
    { x: A.x, y: yy },
    { x: B.x, y: yy },
    { x: B.x, y: B.y + NH / 2 },
  ]);
}

function NodeBox({ n, lanes }: { n: FlowNode; lanes: string[] }) {
  const { x, y } = center(n);
  const kind = n.kind ?? "step";
  const style = laneStyle(n.lane);
  return (
    <div
      className="absolute"
      style={{ left: x - NW / 2, top: y - NH / 2, width: NW, height: NH }}
      title={`${lanes[n.lane] ?? ""}: ${n.label}`}
    >
      <div
        className={cn(
          "flex h-full w-full flex-col items-center justify-center gap-0.5 px-2 py-1 text-center text-xs leading-tight shadow-sm",
          kind === "step" && cn("rounded-lg border border-l-4 bg-card", style.bar),
          kind === "system" &&
            "rounded-lg border border-dashed bg-muted/40 text-muted-foreground",
          kind === "decision" &&
            "rounded-xl border-2 border-amber-400 bg-amber-50 font-medium text-amber-900 dark:bg-amber-950/40 dark:text-amber-100",
          kind === "start" &&
            "rounded-full border-2 border-emerald-500 bg-emerald-50 font-medium text-emerald-900 dark:bg-emerald-950/40 dark:text-emerald-100",
          kind === "end" &&
            "rounded-full border-2 border-slate-500 bg-slate-100 font-medium text-slate-900 dark:bg-slate-800 dark:text-slate-100",
        )}
      >
        {kind === "decision" ? (
          <span aria-hidden className="text-sm leading-none">
            ◇
          </span>
        ) : null}
        <span className="line-clamp-4">{n.label}</span>
        {n.status ? (
          <span className="rounded-full bg-primary/10 px-1.5 py-px text-[10px] font-semibold text-primary">
            {n.status}
          </span>
        ) : null}
      </div>
    </div>
  );
}

/** Danh sách dọc cho màn hình nhỏ: cùng thông tin, theo thứ tự thời gian. */
function MobileFlow({ d }: { d: FlowDiagram }) {
  const ordered = [...d.nodes].sort((a, b) => a.col - b.col || a.lane - b.lane);
  const byId = new Map(d.nodes.map((n) => [n.id, n]));
  return (
    <ol className="space-y-0">
      {ordered.map((n, i) => {
        const outs = d.edges.filter((e) => e.from === n.id);
        const kind = n.kind ?? "step";
        const style = laneStyle(n.lane);
        return (
          <li key={n.id} className="flex flex-col items-stretch">
            <div
              className={cn(
                "rounded-lg border p-3 text-sm",
                kind === "decision" &&
                  "border-2 border-amber-400 bg-amber-50 text-amber-900 dark:bg-amber-950/40 dark:text-amber-100",
                kind === "system" && "border-dashed bg-muted/40",
                (kind === "start" || kind === "end") && "border-2 border-slate-400 bg-slate-50 dark:bg-slate-800",
                kind === "step" && "bg-card",
              )}
            >
              <span
                className={cn(
                  "mb-1 inline-block rounded-full px-2 py-0.5 text-[11px] font-medium",
                  style.chip,
                )}
              >
                {d.lanes[n.lane]}
              </span>
              <p className="font-medium">
                {kind === "decision" ? "◇ " : ""}
                {n.label}
              </p>
              {n.status ? (
                <span className="mt-1 inline-block rounded-full bg-primary/10 px-2 py-0.5 text-[11px] font-semibold text-primary">
                  {n.status}
                </span>
              ) : null}
              {outs.length > 1 || outs.some((e) => e.label) ? (
                <ul className="mt-2 space-y-1 border-t pt-2 text-xs text-muted-foreground">
                  {outs.map((e) => (
                    <li key={`${e.from}-${e.to}`}>
                      <span
                        className={cn(
                          "font-semibold",
                          e.tone === "bad" ? "text-destructive" : "text-foreground",
                        )}
                      >
                        {e.label ?? vi.help.flowNext}
                      </span>
                      {" → "}
                      {byId.get(e.to)?.label}
                    </li>
                  ))}
                </ul>
              ) : null}
            </div>
            {i < ordered.length - 1 ? (
              <ArrowDown
                className="mx-auto my-1 size-4 text-muted-foreground"
                aria-hidden
              />
            ) : null}
          </li>
        );
      })}
    </ol>
  );
}

/**
 * Sơ đồ luồng nghiệp vụ dạng "hàng bơi": mỗi hàng là một người/bộ phận, ô
 * xếp theo thứ tự thời gian từ trái sang phải, mũi tên nối bước, hình thoi
 * vàng là điểm rẽ nhánh, nét đứt đỏ là nhánh từ chối/quay lại. Màn hình
 * rộng vẽ sơ đồ; màn hình nhỏ chuyển thành danh sách dọc cùng nội dung.
 */
export function WorkflowDiagram({ diagram }: { diagram: FlowDiagram }) {
  const cols = Math.max(...diagram.nodes.map((n) => n.col)) + 1;
  const W = LABEL_W + cols * CW;
  const H = diagram.lanes.length * LH + 20;
  const byId = new Map(diagram.nodes.map((n) => [n.id, n]));

  return (
    <figure className="space-y-2">
      <figcaption className="text-sm font-semibold">{diagram.title}</figcaption>

      <div className="hidden rounded-xl border bg-background p-2 md:block">
        <FitToWidth width={W} height={H}>
        <div className="relative" style={{ width: W, height: H }}>
          {/* Hàng bơi */}
          {diagram.lanes.map((name, i) => (
            <div
              key={name}
              className={cn(
                "absolute inset-x-0 border-b",
                i % 2 === 0 ? "bg-muted/30" : "bg-transparent",
              )}
              style={{ top: i * LH, height: LH }}
            >
              <div
                className={cn(
                  "absolute top-1/2 left-2 flex -translate-y-1/2 items-center gap-1.5 rounded-md px-2 py-1 text-[11px] font-semibold",
                  laneStyle(i).chip,
                )}
                style={{ width: LABEL_W - 14 }}
              >
                <span className={cn("size-2 shrink-0 rounded-full", laneStyle(i).dot)} aria-hidden />
                <span className="leading-tight">{name}</span>
              </div>
            </div>
          ))}

          {/* Mũi tên */}
          <svg
            className="absolute inset-0 text-muted-foreground"
            width={W}
            height={H}
            aria-hidden
          >
            <defs>
              <marker id="arrow-ok" viewBox="0 0 10 10" refX="9" refY="5" markerWidth="7" markerHeight="7" orient="auto-start-reverse">
                <path d="M 0 0 L 10 5 L 0 10 z" fill="currentColor" />
              </marker>
              <marker id="arrow-bad" viewBox="0 0 10 10" refX="9" refY="5" markerWidth="7" markerHeight="7" orient="auto-start-reverse">
                <path d="M 0 0 L 10 5 L 0 10 z" className="fill-destructive" />
              </marker>
            </defs>
            {diagram.edges.map((e) => {
              const a = byId.get(e.from);
              const b = byId.get(e.to);
              if (!a || !b) return null;
              const p = edgePath(a, b);
              const bad = e.tone === "bad";
              return (
                <g key={`${e.from}-${e.to}-${e.label ?? ""}`}>
                  <path
                    d={p.d}
                    fill="none"
                    strokeWidth={1.6}
                    strokeDasharray={bad ? "5 4" : undefined}
                    className={bad ? "stroke-destructive" : "stroke-current"}
                    markerEnd={`url(#arrow-${bad ? "bad" : "ok"})`}
                  />
                  {e.label ? (
                    <text
                      x={p.lx}
                      y={p.ly}
                      textAnchor={p.anchor}
                      fontSize={10}
                      fontWeight={600}
                      paintOrder="stroke"
                      strokeWidth={4}
                      className={cn(
                        "stroke-background",
                        bad ? "fill-destructive" : "fill-foreground",
                      )}
                    >
                      {e.label}
                    </text>
                  ) : null}
                </g>
              );
            })}
          </svg>

          {/* Các ô */}
          {diagram.nodes.map((n) => (
            <NodeBox key={n.id} n={n} lanes={diagram.lanes} />
          ))}
        </div>
        </FitToWidth>
      </div>

      <div className="md:hidden">
        <MobileFlow d={diagram} />
      </div>
    </figure>
  );
}
