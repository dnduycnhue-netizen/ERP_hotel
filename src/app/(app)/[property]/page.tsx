import { vi } from "@/i18n/vi";

export default function PropertyHome() {
  return (
    <section className="rounded-xl border bg-card p-6 shadow-sm sm:p-8">
      <p className="text-sm font-medium text-primary">
        {vi.property.dashboard}
      </p>
      <h1 className="mt-2 text-2xl font-semibold tracking-tight">
        {vi.property.welcome}
      </h1>
      <p className="mt-3 text-sm leading-6 text-muted-foreground">
        {vi.property.dashboardDescription}
      </p>
    </section>
  );
}
