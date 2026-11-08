import { vi } from "@/i18n/vi";

export default function AppLoading() {
  return (
    <main
      aria-busy="true"
      aria-live="polite"
      className="flex min-h-screen items-center justify-center px-6"
    >
      <p className="text-sm text-muted-foreground">{vi.common.loading}</p>
    </main>
  );
}
