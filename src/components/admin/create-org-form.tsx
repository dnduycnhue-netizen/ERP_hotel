"use client";

import { useState } from "react";
import { useRouter } from "next/navigation";
import { Button } from "@/components/ui/button";
import { createOrgAction } from "@/features/admin/actions";
import { vi } from "@/i18n/vi";

/**
 * Tạo tổ chức → pháp nhân → khách sạn trong 1 màn (C5): 3 khối nhập liên
 * tiếp, validate bằng Zod dùng chung (createOrgSchema), gọi RPC
 * admin_org_create qua createOrgAction. Tạo xong chuyển tới trang chi
 * tiết để gán nhanh vai trò và làm các bước tiếp theo.
 */
export function CreateOrgForm() {
  const router = useRouter();
  const [orgName, setOrgName] = useState("");
  const [legalCode, setLegalCode] = useState("");
  const [legalName, setLegalName] = useState("");
  const [taxCode, setTaxCode] = useState("");
  const [accountingRegime, setAccountingRegime] = useState<"TT99" | "TT133">(
    "TT99",
  );
  const [costingMethod, setCostingMethod] = useState<"moving_avg" | "fifo">(
    "moving_avg",
  );
  const [propertyCode, setPropertyCode] = useState("");
  const [propertyName, setPropertyName] = useState("");
  const [address, setAddress] = useState("");
  const [sodProfile, setSodProfile] = useState<"with_cc" | "without_cc">(
    "with_cc",
  );
  const [roomsCount, setRoomsCount] = useState("0");
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState<string | null>(null);

  async function handleSubmit(event: React.FormEvent) {
    event.preventDefault();
    setSaving(true);
    setError(null);
    const parsedRooms = Number.parseInt(roomsCount, 10);
    const result = await createOrgAction({
      orgName,
      legalCode,
      legalName,
      taxCode,
      accountingRegime,
      costingMethod,
      propertyCode,
      propertyName,
      address,
      sodProfile,
      roomsCount: Number.isNaN(parsedRooms) ? 0 : parsedRooms,
    });
    setSaving(false);
    if (!result.ok) {
      setError(result.error);
      return;
    }
    router.push(`/admin/organizations/${result.data.org_id}`);
  }

  return (
    <form onSubmit={handleSubmit} className="space-y-6">
      <fieldset className="space-y-4">
        <legend className="text-base font-semibold">
          {vi.admin.orgSection}
        </legend>
        <label className="block space-y-1 text-sm">
          <span className="font-medium">{vi.admin.orgName}</span>
          <input
            value={orgName}
            onChange={(event) => setOrgName(event.target.value)}
            required
            autoComplete="off"
            className="h-9 w-full rounded-md border bg-background px-3"
          />
        </label>
      </fieldset>

      <fieldset className="space-y-4">
        <legend className="text-base font-semibold">
          {vi.admin.legalSection}
        </legend>
        <div className="grid gap-4 sm:grid-cols-2">
          <label className="block space-y-1 text-sm">
            <span className="font-medium">{vi.admin.legalCode}</span>
            <input
              value={legalCode}
              onChange={(event) =>
                setLegalCode(event.target.value.toUpperCase())
              }
              required
              autoComplete="off"
              className="h-9 w-full rounded-md border bg-background px-3 font-mono uppercase"
            />
          </label>
          <label className="block space-y-1 text-sm">
            <span className="font-medium">{vi.admin.legalName}</span>
            <input
              value={legalName}
              onChange={(event) => setLegalName(event.target.value)}
              required
              autoComplete="off"
              className="h-9 w-full rounded-md border bg-background px-3"
            />
          </label>
          <label className="block space-y-1 text-sm">
            <span className="font-medium">{vi.admin.taxCodeOptional}</span>
            <input
              value={taxCode}
              onChange={(event) => setTaxCode(event.target.value)}
              autoComplete="off"
              className="h-9 w-full rounded-md border bg-background px-3 font-mono"
            />
          </label>
          <label className="block space-y-1 text-sm">
            <span className="font-medium">{vi.admin.accountingRegime}</span>
            <select
              value={accountingRegime}
              onChange={(event) =>
                setAccountingRegime(event.target.value as "TT99" | "TT133")
              }
              className="h-9 w-full rounded-md border bg-background px-3"
            >
              <option value="TT99">{vi.admin.accountingTT99}</option>
              <option value="TT133">{vi.admin.accountingTT133}</option>
            </select>
          </label>
        </div>
        <label className="block space-y-1 text-sm">
          <span className="font-medium">{vi.admin.costingMethod}</span>
          <select
            value={costingMethod}
            onChange={(event) =>
              setCostingMethod(event.target.value as "moving_avg" | "fifo")
            }
            className="h-9 w-full rounded-md border bg-background px-3"
          >
            <option value="moving_avg">{vi.admin.costingMovingAvg}</option>
            <option value="fifo">{vi.admin.costingFifo}</option>
          </select>
          {costingMethod === "fifo" ? (
            <span className="block text-xs text-muted-foreground">
              {vi.admin.costingFifoHint}
            </span>
          ) : null}
        </label>
      </fieldset>

      <fieldset className="space-y-4">
        <legend className="text-base font-semibold">
          {vi.admin.propertySection}
        </legend>
        <div className="grid gap-4 sm:grid-cols-2">
          <label className="block space-y-1 text-sm">
            <span className="font-medium">{vi.admin.propertyCode}</span>
            <input
              value={propertyCode}
              onChange={(event) =>
                setPropertyCode(event.target.value.toUpperCase())
              }
              required
              autoComplete="off"
              className="h-9 w-full rounded-md border bg-background px-3 font-mono uppercase"
            />
          </label>
          <label className="block space-y-1 text-sm">
            <span className="font-medium">{vi.admin.propertyName}</span>
            <input
              value={propertyName}
              onChange={(event) => setPropertyName(event.target.value)}
              required
              autoComplete="off"
              className="h-9 w-full rounded-md border bg-background px-3"
            />
          </label>
          <label className="block space-y-1 text-sm">
            <span className="font-medium">{vi.admin.address}</span>
            <input
              value={address}
              onChange={(event) => setAddress(event.target.value)}
              autoComplete="off"
              className="h-9 w-full rounded-md border bg-background px-3"
            />
          </label>
          <label className="block space-y-1 text-sm">
            <span className="font-medium">{vi.admin.roomsCount}</span>
            <input
              type="number"
              min={0}
              step={1}
              value={roomsCount}
              onChange={(event) => setRoomsCount(event.target.value)}
              className="h-9 w-full rounded-md border bg-background px-3"
            />
          </label>
        </div>
        <label className="block space-y-1 text-sm">
          <span className="font-medium">{vi.admin.sodProfile}</span>
          <select
            value={sodProfile}
            onChange={(event) =>
              setSodProfile(event.target.value as "with_cc" | "without_cc")
            }
            className="h-9 w-full rounded-md border bg-background px-3"
          >
            <option value="with_cc">{vi.admin.sodWithCc}</option>
            <option value="without_cc">{vi.admin.sodWithoutCc}</option>
          </select>
        </label>
      </fieldset>

      {error ? (
        <p role="alert" className="text-sm text-destructive">
          {error}
        </p>
      ) : null}
      <Button type="submit" disabled={saving}>
        {saving ? vi.common.loading : vi.admin.createOrgSubmit}
      </Button>
    </form>
  );
}
