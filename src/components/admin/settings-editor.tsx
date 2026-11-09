"use client";

import { useState } from "react";
import { useRouter } from "next/navigation";
import { Button } from "@/components/ui/button";
import { saveSettingAction } from "@/features/admin/configuration-actions";
import type { SettingEntry } from "@/features/admin/configuration-data";
import { vi } from "@/i18n/vi";

const settingRanges: Record<
  SettingEntry["key"],
  { min: string; max: string; step: string }
> = {
  price_spike_pct: { min: "0", max: "1000", step: "0.01" },
  receiving_tolerance_pct: { min: "0", max: "100", step: "0.01" },
  market_advance_deadline_hours: { min: "1", max: "720", step: "1" },
  waste_approval_threshold_vnd: {
    min: "0",
    max: "9999999999999999",
    step: "1",
  },
  count_random_items: { min: "2", max: "3", step: "1" },
  count_variance_threshold_pct: { min: "0", max: "100", step: "0.01" },
  count_without_cc_factor: { min: "0", max: "1", step: "0.01" },
  invoice_price_tolerance_pct: { min: "0", max: "100", step: "0.01" },
};

function sourceLabel(source: SettingEntry["source"]): string {
  switch (source) {
    case "property":
      return vi.admin.configSourceProperty;
    case "organization":
      return vi.admin.configSourceOrganization;
    default:
      return vi.admin.configSourceDefault;
  }
}

export function SettingsEditor({
  orgId,
  propertyId,
  initialEntries,
}: {
  orgId: string;
  propertyId: string | null;
  initialEntries: SettingEntry[];
}) {
  const router = useRouter();
  const [values, setValues] = useState(
    () =>
      Object.fromEntries(
        initialEntries.map(({ key, value }) => [key, value]),
      ) as Record<SettingEntry["key"], string>,
  );
  const [savingKey, setSavingKey] = useState<SettingEntry["key"] | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [notice, setNotice] = useState<string | null>(null);

  async function save(key: SettingEntry["key"]) {
    setSavingKey(key);
    setError(null);
    setNotice(null);
    const result = await saveSettingAction({
      orgId,
      propertyId,
      key,
      value: values[key],
    });
    setSavingKey(null);
    if (!result.ok) {
      setError(result.error);
      return;
    }
    setNotice(vi.admin.configSettingSaved);
    router.refresh();
  }

  return (
    <div className="space-y-4">
      <p className="rounded-md border bg-muted/40 p-3 text-sm text-muted-foreground">
        {vi.admin.configAppliedImmediately}
      </p>
      {error ? (
        <p role="alert" className="text-sm text-destructive">
          {error}
        </p>
      ) : null}
      {notice ? (
        <p role="status" className="text-sm text-primary">
          {notice}
        </p>
      ) : null}
      <div className="overflow-x-auto rounded-lg border bg-card">
        <table className="w-full text-sm">
          <thead>
            <tr className="border-b text-left text-muted-foreground">
              <th className="px-4 py-3 font-medium">{vi.admin.permission}</th>
              <th className="px-4 py-3 font-medium">{vi.admin.configScope}</th>
              <th className="px-4 py-3 font-medium">{vi.common.actions}</th>
            </tr>
          </thead>
          <tbody>
            {initialEntries.map((entry) => {
              const range = settingRanges[entry.key];
              return (
                <tr key={entry.key} className="border-b last:border-0">
                  <td className="px-4 py-3">
                    <label
                      htmlFor={`setting-${entry.key}`}
                      className="font-medium"
                    >
                      {vi.admin.configSettingLabels[entry.key]}
                    </label>
                  </td>
                  <td className="px-4 py-3">
                    <div className="flex items-center gap-2">
                      <input
                        id={`setting-${entry.key}`}
                        type="number"
                        inputMode="decimal"
                        min={range.min}
                        max={range.max}
                        step={range.step}
                        value={values[entry.key] ?? entry.value}
                        onChange={(event) =>
                          setValues((current) => ({
                            ...current,
                            [entry.key]: event.target.value,
                          }))
                        }
                        className="h-9 w-40 rounded-md border bg-background px-3"
                      />
                      <span className="text-muted-foreground">
                        {vi.admin.configSettingUnits[entry.key]}
                      </span>
                      <span className="text-xs text-muted-foreground">
                        {sourceLabel(entry.source)}
                      </span>
                    </div>
                  </td>
                  <td className="px-4 py-3">
                    <Button
                      disabled={savingKey !== null}
                      onClick={() => void save(entry.key)}
                      aria-label={`${vi.common.save}: ${vi.admin.configSettingLabels[entry.key]}`}
                    >
                      {savingKey === entry.key
                        ? vi.common.loading
                        : vi.common.save}
                    </Button>
                  </td>
                </tr>
              );
            })}
          </tbody>
        </table>
      </div>
    </div>
  );
}
