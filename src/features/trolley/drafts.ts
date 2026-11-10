"use client";

import {
  deleteTrolleyDraft,
  getTrolleyDraft,
  saveTrolleyDraft,
  type TrolleyDraft,
} from "@/lib/offline/db";
import type { TrolleyCleanType, TrolleyShiftName } from "./schemas";

/** Khóa nháp mở ca: theo xe đẩy + tên ca + ngày nghiệp vụ. */
export function trolleyOpenDraftKey(
  propertyId: string,
  trolleyWh: string,
  shift: TrolleyShiftName,
  businessDate: string,
): string {
  return `open:${propertyId}:${trolleyWh}:${shift}:${businessDate}`;
}

/** Khóa nháp đóng ca: theo ca. */
export function trolleyCloseDraftKey(shiftId: string): string {
  return `close:${shiftId}`;
}

export type TrolleyDraftCounts = TrolleyDraft["counts"];
export type TrolleyDraftRoomsDone = TrolleyDraft["roomsDone"];

export async function loadTrolleyDraft(
  key: string,
): Promise<TrolleyDraft | undefined> {
  return getTrolleyDraft(key);
}

export async function saveTrolleyDraftCounts(
  key: string,
  base: Omit<TrolleyDraft, "id" | "key" | "counts" | "roomsDone" | "updatedAt">,
  counts: TrolleyDraftCounts,
  roomsDone: TrolleyDraftRoomsDone,
): Promise<void> {
  await saveTrolleyDraft({
    ...base,
    key,
    counts,
    roomsDone,
    updatedAt: Date.now(),
  });
}

export async function clearTrolleyDraft(key: string): Promise<void> {
  await deleteTrolleyDraft(key);
}

/** Phòng đã dọn trong nháp đóng ca (mặc định checkout). */
export function emptyRoomsDoneRow(): {
  roomId: string;
  cleanType: TrolleyCleanType;
  guests: string;
} {
  return { roomId: "", cleanType: "checkout", guests: "" };
}
