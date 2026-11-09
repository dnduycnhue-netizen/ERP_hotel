"use client";

import { useState } from "react";
import { useRouter } from "next/navigation";
import { EmptyState } from "@/components/common/empty-state";
import { Button } from "@/components/ui/button";
import {
  deleteApprovalRuleAction,
  saveApprovalRuleAction,
} from "@/features/admin/configuration-actions";
import type {
  ApprovalApprovers,
  ApprovalRule,
} from "@/features/admin/configuration-data";
import { vi } from "@/i18n/vi";

export function ApprovalRulesEditor({
  orgId,
  propertyId,
  initialRules,
  approvers,
}: {
  orgId: string;
  propertyId: string | null;
  initialRules: ApprovalRule[];
  approvers: ApprovalApprovers;
}) {
  const router = useRouter();
  const [editing, setEditing] = useState<ApprovalRule | null>(null);
  const [docType, setDocType] = useState("");
  const [minAmount, setMinAmount] = useState("0");
  const [maxAmount, setMaxAmount] = useState("");
  const [step, setStep] = useState(1);
  const [approverKind, setApproverKind] = useState<"role" | "user">("role");
  const [approverId, setApproverId] = useState("");
  const [requiredPerm, setRequiredPerm] = useState("po.approve");
  const [itemGroupId, setItemGroupId] = useState("");
  const [condition, setCondition] = useState("{}");
  const [saving, setSaving] = useState(false);
  const [deletingId, setDeletingId] = useState<string | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [notice, setNotice] = useState<string | null>(null);

  function resetForm() {
    setEditing(null);
    setDocType("");
    setMinAmount("0");
    setMaxAmount("");
    setStep(1);
    setApproverKind("role");
    setApproverId("");
    setRequiredPerm("po.approve");
    setItemGroupId("");
    setCondition("{}");
  }

  function editRule(rule: ApprovalRule) {
    setEditing(rule);
    setDocType(rule.doc_type);
    setMinAmount(rule.min_amount);
    setMaxAmount(rule.max_amount ?? "");
    setStep(rule.step);
    setApproverKind(rule.approver_user_id ? "user" : "role");
    setApproverId(rule.approver_user_id ?? rule.approver_role_id ?? "");
    setRequiredPerm(rule.required_perm);
    setItemGroupId(rule.item_group_id ?? "");
    setCondition(JSON.stringify(rule.condition, null, 2));
    setError(null);
    setNotice(null);
  }

  async function submit(event: React.FormEvent<HTMLFormElement>) {
    event.preventDefault();
    setSaving(true);
    setError(null);
    setNotice(null);
    const result = await saveApprovalRuleAction({
      id: editing?.id ?? null,
      orgId,
      propertyId,
      docType,
      minAmount,
      maxAmount,
      itemGroupId,
      condition,
      step,
      approverRoleId: approverKind === "role" ? approverId || null : null,
      approverUserId: approverKind === "user" ? approverId || null : null,
      requiredPerm,
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
    const result = await deleteApprovalRuleAction(ruleId);
    setDeletingId(null);
    if (!result.ok) {
      setError(result.error);
      return;
    }
    setNotice(vi.admin.configRuleDeleted);
    router.refresh();
  }

  const approverName = (rule: ApprovalRule) =>
    rule.approver_role_name ??
    approvers.users.find((user) => user.id === rule.approver_user_id)?.name ??
    vi.common.noData;

  return (
    <div className="space-y-6">
      {approvers.roles.length === 0 && approvers.users.length === 0 ? (
        <EmptyState title={vi.admin.configApproverRequired} />
      ) : null}
      <form
        onSubmit={(event) => void submit(event)}
        className="grid gap-4 rounded-lg border bg-card p-4 sm:grid-cols-2"
      >
        <label className="grid gap-1 text-sm">
          <span>{vi.admin.configDocType}</span>
          <input
            required
            value={docType}
            onChange={(event) => setDocType(event.target.value)}
            className="h-9 rounded-md border bg-background px-3"
            autoComplete="off"
          />
        </label>
        <label className="grid gap-1 text-sm">
          <span>{vi.admin.configStep}</span>
          <input
            required
            type="number"
            min="1"
            max="100"
            step="1"
            value={step}
            onChange={(event) => setStep(Number(event.target.value))}
            className="h-9 rounded-md border bg-background px-3"
          />
        </label>
        <label className="grid gap-1 text-sm">
          <span>{vi.admin.configMinAmount}</span>
          <input
            required
            inputMode="decimal"
            value={minAmount}
            onChange={(event) => setMinAmount(event.target.value)}
            className="h-9 rounded-md border bg-background px-3"
          />
        </label>
        <label className="grid gap-1 text-sm">
          <span>{vi.admin.configMaxAmount}</span>
          <input
            inputMode="decimal"
            value={maxAmount}
            onChange={(event) => setMaxAmount(event.target.value)}
            className="h-9 rounded-md border bg-background px-3"
          />
        </label>
        <label className="grid gap-1 text-sm">
          <span>{vi.admin.configApproverType}</span>
          <select
            value={approverKind}
            onChange={(event) => {
              setApproverKind(event.target.value as "role" | "user");
              setApproverId("");
            }}
            className="h-9 rounded-md border bg-background px-3"
          >
            <option value="role">{vi.admin.configApproverRole}</option>
            <option value="user">{vi.admin.configApproverUser}</option>
          </select>
        </label>
        <label className="grid gap-1 text-sm">
          <span>
            {approverKind === "role"
              ? vi.admin.configApproverRole
              : vi.admin.configApproverUser}
          </span>
          <select
            required
            value={approverId}
            onChange={(event) => setApproverId(event.target.value)}
            className="h-9 rounded-md border bg-background px-3"
          >
            <option value="">{vi.admin.selectRole}</option>
            {approverKind === "role"
              ? approvers.roles.map((role) => (
                  <option key={role.id} value={role.id}>
                    {role.name}
                  </option>
                ))
              : approvers.users.map((user) => (
                  <option key={user.id} value={user.id}>
                    {user.name}
                    {user.employee_code ? ` (${user.employee_code})` : ""}
                  </option>
                ))}
          </select>
        </label>
        <label className="grid gap-1 text-sm">
          <span>{vi.admin.configRequiredPermission}</span>
          <input
            required
            value={requiredPerm}
            onChange={(event) => setRequiredPerm(event.target.value)}
            className="h-9 rounded-md border bg-background px-3 font-mono text-xs"
          />
        </label>
        <label className="grid gap-1 text-sm">
          <span>{vi.admin.configItemGroup}</span>
          <input
            value={itemGroupId}
            onChange={(event) => setItemGroupId(event.target.value)}
            className="h-9 rounded-md border bg-background px-3 font-mono text-xs"
          />
        </label>
        <label className="grid gap-1 text-sm sm:col-span-2">
          <span>{vi.admin.configCondition}</span>
          <textarea
            rows={3}
            value={condition}
            onChange={(event) => setCondition(event.target.value)}
            className="rounded-md border bg-background px-3 py-2 font-mono text-xs"
          />
        </label>
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
          <Button
            type="submit"
            disabled={
              saving ||
              (approvers.roles.length === 0 && approvers.users.length === 0)
            }
          >
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
                  {vi.admin.configDocType}
                </th>
                <th className="px-4 py-3 font-medium">
                  {vi.admin.configMinAmount}
                </th>
                <th className="px-4 py-3 font-medium">{vi.admin.configStep}</th>
                <th className="px-4 py-3 font-medium">
                  {vi.admin.configApproverType}
                </th>
                <th className="px-4 py-3 font-medium">{vi.common.actions}</th>
              </tr>
            </thead>
            <tbody>
              {initialRules.map((rule) => (
                <tr key={rule.id} className="border-b last:border-0">
                  <td className="px-4 py-3 font-mono text-xs">
                    {rule.doc_type}
                  </td>
                  <td className="px-4 py-3">
                    {rule.min_amount} – {rule.max_amount ?? vi.common.noData}
                  </td>
                  <td className="px-4 py-3">{rule.step}</td>
                  <td className="px-4 py-3">{approverName(rule)}</td>
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
