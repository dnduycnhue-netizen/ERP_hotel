import { vi } from "@/i18n/vi";

export default function Home() {
  return (
    <main className="flex min-h-screen items-center justify-center bg-slate-50 px-6 py-16 text-slate-950">
      <section className="w-full max-w-2xl rounded-2xl border border-slate-200 bg-white p-8 shadow-sm sm:p-12">
        <p className="text-sm font-semibold tracking-wide text-teal-700">
          {vi.appName}
        </p>
        <h1 className="mt-5 text-3xl font-semibold tracking-tight sm:text-4xl">
          {vi.starterTitle}
        </h1>
        <p className="mt-4 text-base leading-7 text-slate-600">
          {vi.starterDescription}
        </p>
        <p className="mt-6 border-t border-slate-200 pt-6 text-sm text-slate-500">
          {vi.starterNextStep}
        </p>
      </section>
    </main>
  );
}
