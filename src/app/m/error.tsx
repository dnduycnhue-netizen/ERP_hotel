"use client";

import { useEffect } from "react";
import { Button } from "@/components/ui/button";
import { vi } from "@/i18n/vi";

export default function MobileError({
  error,
  reset,
}: {
  error: Error & { digest?: string };
  reset: () => void;
}) {
  useEffect(() => {
    console.error("An application route failed to render.", error);
  }, [error]);

  return (
    <main className="flex min-h-screen items-center justify-center px-6 py-10">
      <section className="w-full max-w-lg rounded-xl border bg-card p-6 shadow-sm">
        <h1 className="text-xl font-semibold">{vi.errors.pageTitle}</h1>
        <p className="mt-2 text-sm text-muted-foreground">
          {vi.errors.pageDescription}
        </p>
        <Button className="mt-6" onClick={reset}>
          {vi.common.tryAgain}
        </Button>
      </section>
    </main>
  );
}
