"use server";

import { cookies } from "next/headers";
import { redirect } from "next/navigation";
import {
  listAccessibleProperties,
  selectedPropertyCookie,
} from "@/lib/supabase/access";
import { createClient } from "@/lib/supabase/server";

export async function switchProperty(formData: FormData) {
  const propertyIdValue = formData.get("propertyId");
  if (typeof propertyIdValue !== "string") {
    throw new Error("A hotel must be selected.");
  }

  const supabase = await createClient();
  const { data: userData, error: userError } = await supabase.auth.getUser();
  if (userError && userError.name !== "AuthSessionMissingError") {
    throw userError;
  }
  if (!userData.user) {
    redirect("/login");
  }

  const properties = await listAccessibleProperties(supabase);
  const property = properties.find(({ id }) => id === propertyIdValue);
  if (!property) {
    throw new Error("The selected hotel is not accessible.");
  }

  const cookieStore = await cookies();
  cookieStore.set(selectedPropertyCookie, property.id, {
    httpOnly: true,
    maxAge: 60 * 60 * 24 * 365,
    path: "/",
    sameSite: "lax",
    secure: process.env.NODE_ENV === "production",
  });

  redirect(`/${property.id}`);
}
