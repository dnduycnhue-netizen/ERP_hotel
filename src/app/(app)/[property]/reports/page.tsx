import Link from "next/link";
import { vi } from "@/i18n/vi";
import { REPORT_META } from "@/features/report/definitions";
import { getReportPerms } from "@/features/report/queries";

/** Trang chỉ mục khu Báo cáo (T-044): thẻ từng báo cáo được cấp quyền. */
export default async function ReportsIndexPage({
  params,
}: {
  params: Promise<{ property: string }>;
}) {
  const { property } = await params;
  const perms = await getReportPerms(property);
  const visible = REPORT_META.filter((m) => perms[m.code]);

  return (
    <div className="space-y-4">
      <p className="text-sm text-muted-foreground">{vi.reports.indexHint}</p>
      {visible.length === 0 ? (
        <p className="text-sm text-muted-foreground">
          {vi.reports.noPermission}
        </p>
      ) : (
        <div className="grid gap-4 sm:grid-cols-2">
          {visible.map((m) => (
            <article key={m.code} className="rounded-lg border p-4">
              <h2 className="text-base font-semibold">{m.title}</h2>
              <p className="mt-1 text-sm text-muted-foreground">
                {m.description}
              </p>
              <Link
                href={`/${property}/reports/${m.slug}`}
                className="mt-3 inline-flex h-8 items-center justify-center rounded-lg border border-border bg-background px-2.5 text-sm font-medium hover:bg-muted"
              >
                {vi.reports.viewReport}
              </Link>
            </article>
          ))}
        </div>
      )}
    </div>
  );
}
