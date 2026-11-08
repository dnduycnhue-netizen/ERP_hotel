import Link from "next/link";
import { buttonVariants } from "@/components/ui/button";
import { vi } from "@/i18n/vi";

export default function NotFound() {
  return (
    <main className="flex min-h-screen items-center justify-center px-6 py-10">
      <section className="w-full max-w-lg rounded-xl border bg-card p-6 shadow-sm">
        <p className="text-sm font-semibold text-primary">{vi.appName}</p>
        <h1 className="mt-3 text-xl font-semibold">
          {vi.errors.notFoundTitle}
        </h1>
        <p className="mt-2 text-sm text-muted-foreground">
          {vi.errors.notFoundDescription}
        </p>
        <Link className={buttonVariants({ className: "mt-6" })} href="/">
          {vi.errors.backHome}
        </Link>
      </section>
    </main>
  );
}
