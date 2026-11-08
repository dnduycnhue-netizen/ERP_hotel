"use server";

import { redirect } from "next/navigation";
import { createClient } from "@/lib/supabase/server";

export async function setInitialPassword(formData: FormData) {
  const password = formData.get("password");
  const confirmPassword = formData.get("confirmPassword");

  if (typeof password !== "string" || password.length < 12) {
    redirect("/set-password?error=password_too_short");
  }
  if (typeof confirmPassword !== "string" || password !== confirmPassword) {
    redirect("/set-password?error=password_mismatch");
  }

  const supabase = await createClient();
  const { data: userData, error: userError } = await supabase.auth.getUser();
  if (userError && userError.name !== "AuthSessionMissingError") {
    throw userError;
  }
  if (!userData.user) {
    redirect("/login");
  }

  const { error } = await supabase.auth.updateUser({ password });
  if (error) {
    console.error("Unable to set the account's initial password.", error);
    redirect("/set-password?error=update_failed");
  }

  redirect("/");
}
