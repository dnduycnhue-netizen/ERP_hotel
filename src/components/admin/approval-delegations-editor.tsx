"use client";

import { useState } from "react";
import { useRouter } from "next/navigation";
import { EmptyState } from "@/components/common/empty-state";
import { Button } from "@/components/ui/button";
import type {
  ApprovalApprovers,
  ApprovalDelegation,
} from "@/features/admin/configuration-data";
import {
  deleteApprovalDelegationAction,
  saveApprovalDelegationAction,
} from "@/features/procurement/actions";
import { vi } from "@/i18n/vi";

/**
 * Quản lý ủy quyền duyệt (C9 — trước đây chỉ có RPC + action, không có UI).
 * Người được ủy quyền chỉ duyệt được bước của người ủy quyền khi ủy quyền
 * còn hạn và cùng phạm vi (property_id null = toàn chuỗi). Quyền quản trị:
 * `admin.approval_rules.manage` (trang đã chặn từ phía server).
 */
export function ApprovalDelegationsEditor({
  orgId,
  propertyId,
  properties,
  users,
  initialDelegations,
}: {
  orgId: string;
  propertyId: string | null;
  properties: { id: string; name: string }[];
  users: ApprovalApprovers["users"];
  initialDelegations: ApprovalDelegation[];
}) {
  const router = useRouter();
  const [editing, setEditing] = useState<ApprovalDelegation | null>(null);
  const [fromUser, setFromUser] = useState("");
  const [toUser, setToUser] = useState("");
  const [scopePropertyId, setScopePropertyId] = useState(propertyId ?? "");
  const [validFrom, setValidFrom] = useState("");
  const [validTo, setValidTo] = useState("");
  const [reason, setReason] = useState("");
  const [saving, setSaving] = useState(false);
  const [deletingId, setDeletingId] = useState<string | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [notice, setNotice] = useState<string | null>(null);

  function resetForm() {
    setEditing(null);
    setFromUser("");
    setToUser("");
    setScopePropertyId(propertyId ?? "");
    setValidFrom("");
    setValidTo("");
    setReason("");
  }

  function editDelegation(delegation: ApprovalDelegation) {
    setEditing(delegation);
    setFromUser(delegation.from_user);
    setToUser(delegation.to_user);
    setScopePropertyId(delegation.property_id ?? "");
    setValidFrom(delegation.valid_from);
    setValidTo(delegation.valid_to);
    setReason(delegation.reason ?? "");
    setError(null);
    setNotice(null);
  }

  async function submit(event: React.FormEvent<HTMLFormElement>) {
    event.preventDefault();
    setSaving(true);
    setError(null);
    setNotice(null);
    const result = await saveApprovalDelegationAction({
      orgId,
      id: editing?.id,
      fromUser,
      toUser,
      propertyId: scopePropertyId === "" ? null : scopePropertyId,
      validFrom,
      validTo,
      reason: reason === "" ? null : reason,
    });
    setSaving(false);
    if (!result.ok) {
      setError(result.error);
      return;
    }
    resetForm();
    setNotice(vi.admin.configDelegationSaved);
    router.refresh();
  }

  async function deleteDelegation(delegationId: string) {
    if (!window.confirm(vi.admin.configDelegationDeleteConfirm)) return;
    setDeletingId(delegationId);
    setError(null);
    setNotice(null);
    const result = await deleteApprovalDelegationAction({
      orgId,
      delegationId,
    });
    setDeletingId(null);
    if (!result.ok) {
      setError(result.error);
      return;
    }
    setNotice(vi.admin.configDelegationDeleted);
    router.refresh();
  }

  const userName = (userId: string) => {
    const user = users.find((item) => item.id === userId);
    if (!user) return vi.common.noData;
    return user.employee_code
      ? `${user.name} (${user.employee_code})`
      : user.name;
  };

  const propertyName = (id: string | null) =>
    id === null
      ? vi.admin.configDelegationChain
      : (properties.find((property) => property.id === id)?.name ??
        vi.common.noData);

  return (
    <div className="space-y-4">
      <form
        onSubmit={(event) => void submit(event)}
        className="grid gap-4 rounded-lg border bg-card p-4 sm:grid-cols-2"
      >
        <label className="grid gap-1 text-sm">
          <span>{vi.admin.configDelegationFromUser}</span>
          <select
            required
            value={fromUser}
            onChange={(event) => setFromUser(event.target.value)}
            className="h-9 rounded-md border bg-background px-3"
          >
            <option value="">{vi.admin.configDelegationSelectUser}</option>
            {users.map((user) => (
              <option key={user.id} value={user.id}>
                {user.name}
                {user.employee_code ? ` (${user.employee_code})` : ""}
              </option>
            ))}
          </select>
        </label>
        <label className="grid gap-1 text-sm">
          <span>{vi.admin.configDelegationToUser}</span>
          <select
            required
            value={toUser}
            onChange={(event) => setToUser(event.target.value)}
            className="h-9 rounded-md border bg-background px-3"
          >
            <option value="">{vi.admin.configDelegationSelectUser}</option>
            {users.map((user) => (
              <option key={user.id} value={user.id}>
                {user.name}
                {user.employee_code ? ` (${user.employee_code})` : ""}
              </option>
            ))}
          </select>
        </label>
        <label className="grid gap-1 text-sm">
          <span>{vi.admin.configDelegationProperty}</span>
          <select
            value={scopePropertyId}
            onChange={(event) => setScopePropertyId(event.target.value)}
            className="h-9 rounded-md border bg-background px-3"
          >
            <option value="">{vi.admin.configDelegationChain}</option>
            {properties.map((property) => (
              <option key={property.id} value={property.id}>
                {property.name}
              </option>
            ))}
          </select>
        </label>
        <label className="grid gap-1 text-sm">
          <span>{vi.admin.configDelegationReason}</span>
          <input
            value={reason}
            onChange={(event) => setReason(event.target.value)}
            className="h-9 rounded-md border bg-background px-3"
            autoComplete="off"
          />
        </label>
        <label className="grid gap-1 text-sm">
          <span>{vi.admin.configDelegationValidFrom}</span>
          <input
            required
            type="date"
            value={validFrom}
            onChange={(event) => setValidFrom(event.target.value)}
            className="h-9 rounded-md border bg-background px-3"
          />
        </label>
        <label className="grid gap-1 text-sm">
          <span>{vi.admin.configDelegationValidTo}</span>
          <input
            required
            type="date"
            value={validTo}
            onChange={(event) => setValidTo(event.target.value)}
            className="h-9 rounded-md border bg-background px-3"
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
          <Button type="submit" disabled={saving || users.length === 0}>
            {saving
              ? vi.common.loading
              : editing
                ? vi.admin.configDelegationSave
                : vi.admin.configDelegationAdd}
          </Button>
          {editing ? (
            <Button type="button" variant="outline" onClick={resetForm}>
              {vi.common.cancel}
            </Button>
          ) : null}
        </div>
      </form>
      {initialDelegations.length === 0 ? (
        <EmptyState title={vi.admin.configDelegationEmpty} />
      ) : (
        <div className="overflow-x-auto rounded-lg border">
          <table className="w-full text-sm">
            <thead>
              <tr className="border-b bg-muted/50 text-left">
                <th className="px-3 py-2 font-medium">
                  {vi.admin.configDelegationFromUser}
                </th>
                <th className="px-3 py-2 font-medium">
                  {vi.admin.configDelegationToUser}
                </th>
                <th className="px-3 py-2 font-medium">
                  {vi.admin.configDelegationProperty}
                </th>
                <th className="px-3 py-2 font-medium">
                  {vi.admin.configDelegationValidFrom}
                </th>
                <th className="px-3 py-2 font-medium">
                  {vi.admin.configDelegationValidTo}
                </th>
                <th className="px-3 py-2 font-medium">
                  {vi.admin.configDelegationReason}
                </th>
                <th className="px-3 py-2" aria-label="Thao tác" />
              </tr>
            </thead>
            <tbody>
              {initialDelegations.map((delegation) => (
                <tr key={delegation.id} className="border-b last:border-0">
                  <td className="px-3 py-2">
                    {userName(delegation.from_user)}
                  </td>
                  <td className="px-3 py-2">{userName(delegation.to_user)}</td>
                  <td className="px-3 py-2">
                    {propertyName(delegation.property_id)}
                  </td>
                  <td className="px-3 py-2">{delegation.valid_from}</td>
                  <td className="px-3 py-2">{delegation.valid_to}</td>
                  <td className="px-3 py-2">{delegation.reason ?? "—"}</td>
                  <td className="px-3 py-2 text-right whitespace-nowrap">
                    <Button
                      type="button"
                      variant="outline"
                      size="sm"
                      onClick={() => editDelegation(delegation)}
                    >
                      {vi.admin.configDelegationEdit}
                    </Button>{" "}
                    <Button
                      type="button"
                      variant="outline"
                      size="sm"
                      disabled={deletingId === delegation.id}
                      onClick={() => void deleteDelegation(delegation.id)}
                    >
                      {vi.admin.configDelegationDelete}
                    </Button>
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
