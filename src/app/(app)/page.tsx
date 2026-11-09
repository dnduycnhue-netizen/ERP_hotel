import { cookies } from "next/headers";
import { redirect } from "next/navigation";
import { Button } from "@/components/ui/button";
import { vi } from "@/i18n/vi";
import {
  listAccessibleProperties,
  selectedPropertyCookie,
} from "@/lib/supabase/access";
import { createClient, getAuthenticatedUser } from "@/lib/supabase/server";
import { signOut } from "../(auth)/login/actions";

export default async function HomePage() {
  const supabase = await createClient();
  const user = await getAuthenticatedUser(supabase);
  if (!user) {
    redirect("/login");
  }

  const properties = await listAccessibleProperties(supabase);

  if (properties.length === 0) {
    return (
      <main className="flex min-h-[70vh] items-center justify-center">
        <section className="w-full max-w-lg rounded-xl border bg-card p-6 shadow-sm sm:p-8">
          <h1 className="text-xl font-semibold">{vi.property.noAccessTitle}</h1>
          <p className="mt-2 text-sm leading-6 text-muted-foreground">
            {vi.property.noAccessDescription}
          </p>
          <form action={signOut} className="mt-6">
            <Button type="submit">{vi.auth.signOut}</Button>
          </form>
        </section>
      </main>
    );
  }

  const cookieStore = await cookies();
  const preferredPropertyId = cookieStore.get(selectedPropertyCookie)?.value;
  const property =
    properties.find(({ id }) => id === preferredPropertyId) ?? properties[0];

  redirect(`/${property.id}`);
}
