"use client";

import { useEffect, useRef, useState, type ReactNode } from "react";

/** Thu nhỏ nội dung có kích thước cố định cho vừa chiều rộng khung (tối thiểu `minScale`, dưới đó thì cuộn ngang). */
export function FitToWidth({
  width,
  height,
  minScale = 0.62,
  children,
}: {
  width: number;
  height: number;
  minScale?: number;
  children: ReactNode;
}) {
  const ref = useRef<HTMLDivElement>(null);
  const [scale, setScale] = useState(1);

  useEffect(() => {
    const el = ref.current;
    if (!el) return;
    const update = () => {
      setScale(Math.max(minScale, Math.min(1, el.clientWidth / width)));
    };
    update();
    const ro = new ResizeObserver(update);
    ro.observe(el);
    return () => ro.disconnect();
  }, [width, minScale]);

  return (
    <div ref={ref} className="w-full overflow-x-auto">
      <div style={{ height: height * scale, width: width * scale }}>
        <div
          style={{
            width,
            height,
            transform: `scale(${scale})`,
            transformOrigin: "top left",
          }}
        >
          {children}
        </div>
      </div>
    </div>
  );
}
