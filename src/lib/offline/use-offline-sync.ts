"use client";

import { useEffect, useRef, useSyncExternalStore } from "react";
import {
  addSyncListener,
  ensureOfflineEngine,
  getSyncSnapshot,
  initialSyncState,
  subscribeSync,
  type OfflineSyncState,
  type SyncListener,
} from "./sync";

function getServerSnapshot(): OfflineSyncState {
  return initialSyncState;
}

/**
 * Theo dõi trạng thái mạng + hàng đợi offline (T-025).
 * Listener được giữ qua ref nên component truyền object mới mỗi lần
 * render cũng không đăng ký lại; engine khởi động 1 lần duy nhất.
 */
export function useOfflineSync(listener?: SyncListener): OfflineSyncState {
  const listenerRef = useRef<SyncListener | undefined>(listener);

  useEffect(() => {
    listenerRef.current = listener;
  });

  useEffect(() => {
    ensureOfflineEngine();
    return addSyncListener({
      onRecordSynced: (info) => listenerRef.current?.onRecordSynced?.(info),
      onOverrideSynced: (info) => listenerRef.current?.onOverrideSynced?.(info),
      onPostSynced: (grId) => listenerRef.current?.onPostSynced?.(grId),
    });
  }, []);

  return useSyncExternalStore(
    subscribeSync,
    getSyncSnapshot,
    getServerSnapshot,
  );
}
