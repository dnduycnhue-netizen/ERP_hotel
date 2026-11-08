import type { ReactNode } from "react";
import { Suspense } from "react";
import { redirect } from "next/navigation";
import { Button } from "@/components/ui/button";
import { vi } from "@/i18n/vi";
import { createClient } from "@/lib/supabase/server";
import { signOut } from "../(auth)/login/actions";
import AppLoading from "./loading";

export default function AppLayout({
  children,
}: Readonly<{ children: ReactNode }>) {
  return (
    <Suspense fallback={<AppLoading />}>
      <AuthenticatedApp>{children}</AuthenticatedApp>
    </Suspense>
  );
}

async function AuthenticatedApp({
  children,
}: Readonly<{ children: ReactNode }>) {
  const supabase = await createClient();
  const { data: userData, error: userError } = await supabase.auth.getUser();
  if (userError && userError.name !== "AuthSessionMissingError") {
    throw userError;
  }
  if (!userData.user) {
    redirect("/login");
  }

  const { data: profile, error: profileError } = await supabase
    .from("profiles")
    .select("active")
    .eq("id", userData.user.id)
    .maybeSingle();

  if (profileError) {
    console.error("Unable to verify the current profile.", profileError);
    throw profileError;
  }

  if (!profile?.active) {
    return (
      <main className="flex min-h-screen items-center justify-center bg-muted/40 px-4 py-10">
        <section className="w-full max-w-lg rounded-xl border bg-card p-6 shadow-sm sm:p-8">
          <h1 className="text-xl font-semibold">
            {vi.auth.accountUnavailable}
          </h1>
          <p className="mt-2 text-sm leading-6 text-muted-foreground">
            {vi.auth.accountUnavailableDescription}
          </p>
          <form action={signOut} className="mt-6">
            <Button type="submit">{vi.auth.signOut}</Button>
          </form>
        </section>
      </main>
    );
  }

  return children;
}
