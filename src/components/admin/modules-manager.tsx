"use client";

import { useState, useTransition } from "react";
import { Button } from "@/components/ui/button";
import { setPropertyModuleAction } from "@/features/admin/module-actions";
import { vi } from "@/i18n/vi";
import type { ModuleId, PropertyModules } from "@/lib/modules";

export type ModulesRow = {
  property_id: string;
  code: string;
  name: string;
} & PropertyModules;

const t = vi.admin.modules;

const MODULE_LABELS: { id: ModuleId; label: string; hint: string }[] = [
  { id: "hk_frontdesk", label: t.hkFrontdesk, hint: t.hkFrontdeskHint },
  { id: "restaurant", label: t.restaurant, hint: t.restaurantHint },
];

export function ModulesManager({ rows }: { rows: ModulesRow[] }) {
  const [state, setState] = useState(rows);
  const [message, setMessage] = useState<string | null>(null);
  const [pending, startTransition] = useTransition();

  function toggle(row: ModulesRow, module: ModuleId) {
    const next = !row[module];
    if (!next && !window.confirm(t.confirmOff)) {
      return;
    }
    startTransition(async () => {
      const result = await setPropertyModuleAction({
        propertyId: row.property_id,
        module,
        enabled: next,
      });
      if (result.ok) {
        setState((current) =>
          current.map((r) =>
            r.property_id === row.property_id ? { ...r, [module]: next } : r,
          ),
        );
        setMessage(t.saved);
      } else {
        setMessage(result.error);
      }
    });
  }

  return (
    <div className="space-y-4">
      {message ? (
        <p role="status" className="text-sm text-muted-foreground">
          {message}
        </p>
      ) : null}
      <div className="overflow-x-auto rounded-lg border">
        <table className="w-full min-w-[560px] text-sm">
          <thead className="bg-muted/50 text-left">
            <tr>
              <th className="p-2">{t.property}</th>
              {MODULE_LABELS.map((m) => (
                <th key={m.id} className="p-2">
                  {m.label}
                  <span className="block text-xs font-normal text-muted-foreground">
                    {m.hint}
                  </span>
                </th>
              ))}
            </tr>
          </thead>
          <tbody>
            {state.map((row) => (
              <tr key={row.property_id} className="border-t">
                <td className="p-2 font-medium">
                  {row.name}
                  <span className="block font-mono text-xs text-muted-foreground">
                    {row.code}
                  </span>
                </td>
                {MODULE_LABELS.map((m) => (
                  <td key={m.id} className="p-2">
                    <span
                      className={
                        row[m.id]
                          ? "mr-3 text-emerald-600"
                          : "mr-3 text-muted-foreground"
                      }
                    >
                      {row[m.id] ? t.on : t.off}
                    </span>
                    <Button
                      variant="outline"
                      size="sm"
                      disabled={pending}
                      onClick={() => toggle(row, m.id)}
                    >
                      {row[m.id] ? t.turnOff : t.turnOn}
                    </Button>
                  </td>
                ))}
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </div>
  );
}
