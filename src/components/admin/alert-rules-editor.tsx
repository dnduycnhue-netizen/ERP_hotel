"use client";

import { useState } from "react";
import { useRouter } from "next/navigation";
import { EmptyState } from "@/components/common/empty-state";
import { Button } from "@/components/ui/button";
import {
  deleteAlertRuleAction,
  saveAlertRuleAction,
} from "@/features/admin/configuration-actions";
import type { AlertRule } from "@/features/admin/configuration-data";
import { vi } from "@/i18n/vi";

const availableChannels = [
  { value: "app", label: vi.admin.configChannelApp },
  { value: "email", label: vi.admin.configChannelEmail },
  { value: "webpush", label: vi.admin.configChannelWebPush },
  { value: "zalo", label: vi.admin.configChannelZalo },
] as const;

export function AlertRulesEditor({
  orgId,
  propertyId,
  initialRules,
}: {
  orgId: string;
  propertyId: string | null;
  initialRules: AlertRule[];
}) {
  const router = useRouter();
  const [editing, setEditing] = useState<AlertRule | null>(null);
  const [code, setCode] = useState("");
  const [threshold, setThreshold] = useState("{}");
  const [channels, setChannels] = useState<AlertRule["channels"]>(["app"]);
  const [urgent, setUrgent] = useState(false);
  const [active, setActive] = useState(true);
  const [saving, setSaving] = useState(false);
  const [deletingId, setDeletingId] = useState<string | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [notice, setNotice] = useState<string | null>(null);

  function resetForm() {
    setEditing(null);
    setCode("");
    setThreshold("{}");
    setChannels(["app"]);
    setUrgent(false);
    setActive(true);
  }

  function editRule(rule: AlertRule) {
    setEditing(rule);
    setCode(rule.code);
    setThreshold(JSON.stringify(rule.threshold, null, 2));
    setChannels(rule.channels);
    setUrgent(rule.urgent);
    setActive(rule.active);
    setError(null);
    setNotice(null);
  }

  function toggleChannel(channel: AlertRule["channels"][number]) {
    setChannels((current) =>
      current.includes(channel)
        ? current.filter((value) => value !== channel)
        : [...current, channel],
    );
    setError(null);
  }

  async function submit(event: React.FormEvent<HTMLFormElement>) {
    event.preventDefault();
    setSaving(true);
    setError(null);
    setNotice(null);
    const result = await saveAlertRuleAction({
      id: editing?.id ?? null,
      orgId,
      propertyId,
      code,
      threshold,
      channels,
      urgent,
      active,
    });
    setSaving(false);
    if (!result.ok) {
      setError(result.error);
      return;
    }
    resetForm();
    setNotice(vi.admin.configRuleSaved);
    router.refresh();
  }

  async function deleteRule(ruleId: string) {
    if (!window.confirm(vi.admin.configRuleDeleteConfirm)) return;
    setDeletingId(ruleId);
    setError(null);
    setNotice(null);
    const result = await deleteAlertRuleAction(ruleId);
    setDeletingId(null);
    if (!result.ok) {
      setError(result.error);
      return;
    }
    setNotice(vi.admin.configRuleDeleted);
    router.refresh();
  }

  return (
    <div className="space-y-6">
      <p className="rounded-md border border-amber-500/40 bg-amber-500/5 p-3 text-sm">
        {vi.admin.configAlertDescription}
      </p>
      <form
        onSubmit={(event) => void submit(event)}
        className="grid gap-4 rounded-lg border bg-card p-4 sm:grid-cols-2"
      >
        <label className="grid gap-1 text-sm">
          <span>{vi.admin.configAlertCode}</span>
          <input
            required
            value={code}
            onChange={(event) => setCode(event.target.value)}
            className="h-9 rounded-md border bg-background px-3 font-mono"
            autoComplete="off"
          />
        </label>
        <label className="grid gap-1 text-sm">
          <span>{vi.admin.configAlertThreshold}</span>
          <textarea
            rows={4}
            value={threshold}
            onChange={(event) => setThreshold(event.target.value)}
            className="rounded-md border bg-background px-3 py-2 font-mono text-xs"
          />
        </label>
        <fieldset className="grid gap-2 text-sm">
          <legend className="font-medium">
            {vi.admin.configAlertChannels}
          </legend>
          {availableChannels.map((channel) => (
            <label key={channel.value} className="flex items-center gap-2">
              <input
                type="checkbox"
                checked={channels.includes(channel.value)}
                onChange={() => toggleChannel(channel.value)}
              />
              {channel.label}
            </label>
          ))}
        </fieldset>
        <div className="grid content-start gap-3 text-sm">
          <label className="flex items-center gap-2">
            <input
              type="checkbox"
              checked={urgent}
              onChange={(event) => setUrgent(event.target.checked)}
            />
            {vi.admin.configAlertUrgent}
          </label>
          <label className="flex items-center gap-2">
            <input
              type="checkbox"
              checked={active}
              onChange={(event) => setActive(event.target.checked)}
            />
            {vi.admin.configAlertActive}
          </label>
        </div>
        {error ? (
          <p role="alert" className="text-sm text-destructive sm:col-span-2">
            {error}
          </p>
        ) : null}
        {notice ? (
          <p role="status" className="text-sm text-primary sm:col-span-2">
            {notice}
          </p>
        ) : null}
        <div className="flex gap-2 sm:col-span-2">
          <Button type="submit" disabled={saving}>
            {saving
              ? vi.common.loading
              : editing
                ? vi.admin.configSaveRule
                : vi.admin.configAddRule}
          </Button>
          {editing ? (
            <Button type="button" variant="outline" onClick={resetForm}>
              {vi.common.cancel}
            </Button>
          ) : null}
        </div>
      </form>

      {initialRules.length === 0 ? (
        <EmptyState title={vi.admin.configRulesEmpty} />
      ) : (
        <div className="overflow-x-auto rounded-lg border bg-card">
          <table className="w-full text-sm">
            <thead>
              <tr className="border-b text-left text-muted-foreground">
                <th className="px-4 py-3 font-medium">
                  {vi.admin.configAlertCode}
                </th>
                <th className="px-4 py-3 font-medium">
                  {vi.admin.configAlertThreshold}
                </th>
                <th className="px-4 py-3 font-medium">
                  {vi.admin.configAlertChannels}
                </th>
                <th className="px-4 py-3 font-medium">
                  {vi.admin.configAlertActive}
                </th>
                <th className="px-4 py-3 font-medium">{vi.common.actions}</th>
              </tr>
            </thead>
            <tbody>
              {initialRules.map((rule) => (
                <tr key={rule.id} className="border-b last:border-0">
                  <td className="px-4 py-3 font-mono text-xs">{rule.code}</td>
                  <td className="max-w-sm px-4 py-3">
                    <pre className="overflow-auto text-xs">
                      {JSON.stringify(rule.threshold)}
                    </pre>
                  </td>
                  <td className="px-4 py-3">
                    {rule.channels
                      .map(
                        (value) =>
                          availableChannels.find(
                            (channel) => channel.value === value,
                          )?.label ?? value,
                      )
                      .join(", ")}
                    {rule.urgent ? ` · ${vi.admin.configAlertUrgent}` : ""}
                  </td>
                  <td className="px-4 py-3">
                    {rule.active ? vi.admin.active : vi.admin.inactive}
                  </td>
                  <td className="px-4 py-3">
                    <div className="flex gap-2">
                      <Button
                        type="button"
                        variant="outline"
                        onClick={() => editRule(rule)}
                      >
                        {vi.admin.configEditRule}
                      </Button>
                      <Button
                        type="button"
                        variant="destructive"
                        disabled={deletingId !== null}
                        onClick={() => void deleteRule(rule.id)}
                      >
                        {deletingId === rule.id
                          ? vi.common.loading
                          : vi.admin.configDeleteRule}
                      </Button>
                    </div>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}
    </div>
  );
}
