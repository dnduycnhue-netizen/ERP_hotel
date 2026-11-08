import { Suspense } from "react";
import { redirect } from "next/navigation";
import { Button } from "@/components/ui/button";
import { vi } from "@/i18n/vi";
import { createClient } from "@/lib/supabase/server";
import { setInitialPassword } from "./actions";

function getErrorMessage(errorCode: string | undefined) {
  switch (errorCode) {
    case "password_too_short":
      return vi.auth.passwordErrors.tooShort;
    case "password_mismatch":
      return vi.auth.passwordErrors.mismatch;
    case "update_failed":
      return vi.auth.passwordErrors.updateFailed;
    default:
      return null;
  }
}

export default function SetPasswordPage({
  searchParams,
}: {
  searchParams: Promise<{ error?: string | string[] }>;
}) {
  return (
    <Suspense
      fallback={
        <main className="flex min-h-screen items-center justify-center px-6">
          <p className="text-sm text-muted-foreground">{vi.common.loading}</p>
        </main>
      }
    >
      <SetPasswordContent searchParams={searchParams} />
    </Suspense>
  );
}

async function SetPasswordContent({
  searchParams,
}: {
  searchParams: Promise<{ error?: string | string[] }>;
}) {
  const supabase = await createClient();
  const { data, error } = await supabase.auth.getUser();
  if (error && error.name !== "AuthSessionMissingError") {
    throw error;
  }
  if (!data.user) {
    redirect("/login");
  }

  const params = await searchParams;
  const errorCode = typeof params.error === "string" ? params.error : undefined;
  const errorMessage = getErrorMessage(errorCode);

  return (
    <main className="flex min-h-screen items-center justify-center bg-muted/40 px-4 py-10">
      <section className="w-full max-w-md rounded-xl border bg-card p-6 shadow-sm sm:p-8">
        <p className="text-sm font-semibold text-primary">{vi.appName}</p>
        <h1 className="mt-3 text-2xl font-semibold">
          {vi.auth.setPasswordTitle}
        </h1>
        <p className="mt-2 text-sm leading-6 text-muted-foreground">
          {vi.auth.setPasswordDescription}
        </p>

        {errorMessage ? (
          <p
            className="mt-5 rounded-md border border-destructive/30 bg-destructive/10 p-3 text-sm text-destructive"
            role="alert"
          >
            {errorMessage}
          </p>
        ) : null}

        <form action={setInitialPassword} className="mt-6 space-y-4">
          <div className="space-y-2">
            <label className="text-sm font-medium" htmlFor="password">
              {vi.auth.passwordLabel}
            </label>
            <input
              autoComplete="new-password"
              className="h-10 w-full rounded-md border bg-background px-3 text-sm outline-none focus-visible:ring-2 focus-visible:ring-ring"
              id="password"
              minLength={12}
              name="password"
              required
              type="password"
            />
          </div>
          <div className="space-y-2">
            <label className="text-sm font-medium" htmlFor="confirmPassword">
              {vi.auth.confirmPasswordLabel}
            </label>
            <input
              autoComplete="new-password"
              className="h-10 w-full rounded-md border bg-background px-3 text-sm outline-none focus-visible:ring-2 focus-visible:ring-ring"
              id="confirmPassword"
              minLength={12}
              name="confirmPassword"
              required
              type="password"
            />
          </div>
          <Button className="h-10 w-full" type="submit">
            {vi.auth.setPasswordAction}
          </Button>
        </form>
      </section>
    </main>
  );
}
