"use client";

import { Button } from "@/components/ui/button";
import { vi } from "@/i18n/vi";

/**
 * Nut "Thu lai" o trang offline (T-046). Tai lai toan bo trang (khong
 * dung Link — dieu huong client can RSC fetch, mat mang se loi).
 */
export function OfflineRetryButton() {
  return (
    <Button
      type="button"
      className="mt-6"
      onClick={() => window.location.reload()}
    >
      {vi.pwa.tryAgain}
    </Button>
  );
}
