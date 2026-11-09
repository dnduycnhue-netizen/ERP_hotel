import type { Metadata } from "next";
import { Suspense } from "react";
import { redirect } from "next/navigation";
import { Button } from "@/components/ui/button";
import { vi } from "@/i18n/vi";
import { createClient, getAuthenticatedUser } from "@/lib/supabase/server";
import { signIn } from "./actions";

export const metadata: Metadata = {
  title: vi.auth.loginTitle,
};

function getErrorMessage(errorCode: string | undefined) {
  switch (errorCode) {
    case "invalid_input":
      return vi.auth.errors.invalidInput;
    case "invalid_credentials":
      return vi.auth.errors.invalidCredentials;
    case "inactive_account":
      return vi.auth.errors.inactiveAccount;
    case "account_not_ready":
      return vi.auth.errors.accountNotReady;
    case "service_error":
      return vi.auth.errors.serviceError;
    default:
      return null;
  }
}

export default function LoginPage({
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
      <LoginContent searchParams={searchParams} />
    </Suspense>
  );
}

async function LoginContent({
  searchParams,
}: {
  searchParams: Promise<{ error?: string | string[] }>;
}) {
  const supabase = await createClient();
  const user = await getAuthenticatedUser(supabase);
  if (user) {
    redirect("/");
  }

  const params = await searchParams;
  const errorCode = typeof params.error === "string" ? params.error : undefined;
  const errorMessage = getErrorMessage(errorCode);

  return (
    <main className="flex min-h-screen items-center justify-center bg-muted/40 px-4 py-10">
      <section className="w-full max-w-md rounded-xl border bg-card p-6 shadow-sm sm:p-8">
        <p className="text-sm font-semibold text-primary">{vi.appName}</p>
        <h1 className="mt-3 text-2xl font-semibold tracking-tight">
          {vi.auth.loginTitle}
        </h1>
        <p className="mt-2 text-sm leading-6 text-muted-foreground">
          {vi.auth.loginDescription}
        </p>

        {errorMessage ? (
          <p
            className="mt-5 rounded-md border border-destructive/30 bg-destructive/10 p-3 text-sm text-destructive"
            role="alert"
          >
            {errorMessage}
          </p>
        ) : null}

        <form action={signIn} className="mt-6 space-y-4">
          <div className="space-y-2">
            <label className="text-sm font-medium" htmlFor="email">
              {vi.auth.emailLabel}
            </label>
            <input
              autoComplete="username"
              className="h-10 w-full rounded-md border bg-background px-3 text-sm outline-none focus-visible:ring-2 focus-visible:ring-ring"
              id="email"
              name="email"
              required
              type="email"
            />
          </div>
          <div className="space-y-2">
            <label className="text-sm font-medium" htmlFor="password">
              {vi.auth.passwordLabel}
            </label>
            <input
              autoComplete="current-password"
              className="h-10 w-full rounded-md border bg-background px-3 text-sm outline-none focus-visible:ring-2 focus-visible:ring-ring"
              id="password"
              name="password"
              required
              type="password"
            />
          </div>
          <Button className="h-10 w-full" type="submit">
            {vi.auth.signIn}
          </Button>
        </form>
      </section>
    </main>
  );
}
