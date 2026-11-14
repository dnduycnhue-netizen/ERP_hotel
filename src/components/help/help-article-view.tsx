import Link from "next/link";
import { ArrowUpRight, Info, ShieldCheck, TriangleAlert } from "lucide-react";
import { InlineText } from "@/components/help/inline-text";
import type { HelpArticle, HelpBlock, HelpTone } from "@/i18n/help/types";
import { vi } from "@/i18n/vi";
import { cn } from "@/lib/utils";

const TONE: Record<HelpTone, { cls: string; Icon: typeof Info }> = {
  info: {
    cls: "border-blue-200 bg-blue-50 text-blue-900 dark:border-blue-900/50 dark:bg-blue-950/40 dark:text-blue-100",
    Icon: Info,
  },
  warn: {
    cls: "border-amber-200 bg-amber-50 text-amber-900 dark:border-amber-900/50 dark:bg-amber-950/40 dark:text-amber-100",
    Icon: TriangleAlert,
  },
  rule: {
    cls: "border-emerald-200 bg-emerald-50 text-emerald-900 dark:border-emerald-900/50 dark:bg-emerald-950/40 dark:text-emerald-100",
    Icon: ShieldCheck,
  },
};

function Block({
  block,
  propertyId,
}: {
  block: HelpBlock;
  propertyId: string;
}) {
  switch (block.t) {
    case "h":
      return (
        <h2 className="mt-6 text-lg font-semibold tracking-tight">
          {block.text}
        </h2>
      );
    case "p":
      return (
        <p className="text-sm leading-relaxed text-muted-foreground">
          <InlineText text={block.text} />
        </p>
      );
    case "ul":
      return (
        <ul className="list-disc space-y-1.5 pl-5 text-sm leading-relaxed text-muted-foreground">
          {block.items.map((item) => (
            <li key={item}>
              <InlineText text={item} />
            </li>
          ))}
        </ul>
      );
    case "steps":
      return (
        <ol className="space-y-3">
          {block.items.map((step, i) => (
            <li key={step.text} className="flex gap-3">
              <span className="mt-0.5 flex size-6 shrink-0 items-center justify-center rounded-full bg-primary/10 text-xs font-semibold text-primary">
                {i + 1}
              </span>
              <div className="min-w-0 space-y-1 text-sm leading-relaxed">
                {step.who ? (
                  <p className="text-xs font-medium tracking-wide text-primary uppercase">
                    {step.who}
                  </p>
                ) : null}
                <p className="text-muted-foreground">
                  <InlineText text={step.text} />
                </p>
                {step.href ? (
                  <Link
                    href={`/${propertyId}${step.href}`}
                    className="inline-flex items-center gap-1 text-xs font-medium text-primary hover:underline"
                  >
                    {vi.help.openScreen}
                    <ArrowUpRight className="size-3" aria-hidden />
                  </Link>
                ) : null}
              </div>
            </li>
          ))}
        </ol>
      );
    case "note": {
      const { cls, Icon } = TONE[block.tone];
      return (
        <div
          className={cn("flex gap-2.5 rounded-lg border p-3 text-sm", cls)}
          role="note"
        >
          <Icon className="mt-0.5 size-4 shrink-0" aria-hidden />
          <p className="leading-relaxed">
            <InlineText text={block.text} />
          </p>
        </div>
      );
    }
    case "table":
      return (
        <div className="overflow-x-auto rounded-lg border">
          <table className="w-full text-sm">
            <thead className="bg-muted/40 text-left">
              <tr>
                {block.head.map((h) => (
                  <th
                    key={h}
                    className="px-3 py-2 text-xs font-semibold tracking-wide text-muted-foreground uppercase"
                  >
                    {h}
                  </th>
                ))}
              </tr>
            </thead>
            <tbody>
              {block.rows.map((row) => (
                <tr key={row.join("|")} className="border-t align-top">
                  {row.map((cell, i) => (
                    <td
                      key={`${i}-${cell}`}
                      className="px-3 py-2 text-muted-foreground"
                    >
                      <InlineText text={cell} />
                    </td>
                  ))}
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      );
  }
}

/** Hiển thị 1 bài hướng dẫn (server component). */
export function HelpArticleView({
  article,
  propertyId,
}: {
  article: HelpArticle;
  propertyId: string;
}) {
  return (
    <article className="max-w-3xl space-y-3">
      {article.blocks.map((block, i) => (
        <Block key={i} block={block} propertyId={propertyId} />
      ))}
    </article>
  );
}
