"use server";

import { revalidatePath } from "next/cache";
import { redirect } from "next/navigation";
import { createClient } from "@/lib/supabase/server";

async function signOutAndRedirect(errorCode: string): Promise<never> {
  const supabase = await createClient();
  const { error } = await supabase.auth.signOut();
  if (error) {
    console.error(
      "Unable to clear the session after a rejected sign-in.",
      error,
    );
    throw error;
  }

  redirect(`/login?error=${errorCode}`);
}

export async function signIn(formData: FormData) {
  const emailValue = formData.get("email");
  const passwordValue = formData.get("password");
  const email = typeof emailValue === "string" ? emailValue.trim() : "";
  const password = typeof passwordValue === "string" ? passwordValue : "";

  if (!email.includes("@") || password.length === 0) {
    redirect("/login?error=invalid_input");
  }

  const supabase = await createClient();
  const { data, error } = await supabase.auth.signInWithPassword({
    email,
    password,
  });

  if (error?.code === "invalid_credentials") {
    redirect("/login?error=invalid_credentials");
  }
  if (error) {
    console.error("The sign-in request failed.", error);
    redirect("/login?error=service_error");
  }
  if (!data.user) {
    redirect("/login?error=invalid_credentials");
  }

  const { data: profile, error: profileError } = await supabase
    .from("profiles")
    .select("active")
    .eq("id", data.user.id)
    .maybeSingle();

  if (profileError) {
    console.error("Unable to verify the profile after sign-in.", profileError);
    await signOutAndRedirect("service_error");
  }

  if (!profile) {
    return signOutAndRedirect("account_not_ready");
  }

  if (!profile.active) {
    return signOutAndRedirect("inactive_account");
  }

  // Xóa cache layout để menu/quyền của tài khoản trước không còn (B-22).
  revalidatePath("/", "layout");
  redirect("/");
}

export async function signOut() {
  const supabase = await createClient();
  const { error } = await supabase.auth.signOut();
  if (error) {
    console.error("Unable to sign out.", error);
    throw error;
  }

  revalidatePath("/", "layout");
  redirect("/login");
}
