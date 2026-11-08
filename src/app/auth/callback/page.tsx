"use client";

import { useEffect, useState } from "react";
import Link from "next/link";
import { buttonVariants } from "@/components/ui/button";
import { vi } from "@/i18n/vi";
import { createClient } from "@/lib/supabase/client";

export default function AuthCallbackPage() {
  const [failed, setFailed] = useState(false);

  useEffect(() => {
    let active = true;

    async function completeSignIn() {
      const currentUrl = new URL(window.location.href);
      const callbackError =
        currentUrl.searchParams.get("error_description") ??
        currentUrl.searchParams.get("error");

      if (callbackError) {
        if (active) setFailed(true);
        return;
      }

      const supabase = createClient();
      const code = currentUrl.searchParams.get("code");
      const hashParams = new URLSearchParams(currentUrl.hash.slice(1));
      const accessToken = hashParams.get("access_token");
      const refreshToken = hashParams.get("refresh_token");
      let sessionAvailable = false;

      if (accessToken && refreshToken) {
        const { data, error } = await supabase.auth.setSession({
          access_token: accessToken,
          refresh_token: refreshToken,
        });
        if (error) {
          if (active) setFailed(true);
          return;
        }
        sessionAvailable = Boolean(data.session);
      } else if (code) {
        const { data, error } =
          await supabase.auth.exchangeCodeForSession(code);
        if (error) {
          if (active) setFailed(true);
          return;
        }
        sessionAvailable = Boolean(data.session);
      }

      if (!sessionAvailable) {
        if (active) setFailed(true);
        return;
      }

      const nextPath =
        hashParams.get("type") === "invite" ||
        currentUrl.searchParams.get("type") === "invite"
          ? "/set-password"
          : "/";
      window.location.replace(nextPath);
    }

    void completeSignIn();

    return () => {
      active = false;
    };
  }, []);

  return (
    <main className="flex min-h-screen items-center justify-center bg-muted/40 px-4 py-10">
      <section className="w-full max-w-md rounded-xl border bg-card p-6 text-center shadow-sm sm:p-8">
        <p className="text-sm font-semibold text-primary">{vi.appName}</p>
        <h1 className="mt-3 text-xl font-semibold">
          {failed ? vi.auth.callbackErrorTitle : vi.auth.callbackTitle}
        </h1>
        <p className="mt-2 text-sm leading-6 text-muted-foreground">
          {failed ? vi.auth.callbackErrorDescription : vi.common.loading}
        </p>
        {failed ? (
          <Link className={buttonVariants({ className: "mt-6" })} href="/login">
            {vi.auth.loginTitle}
          </Link>
        ) : null}
      </section>
    </main>
  );
}
