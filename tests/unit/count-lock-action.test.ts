import { describe, expect, it, vi } from "vitest";

const rpc = vi.fn();
vi.mock("server-only", () => ({}));
vi.mock("@/lib/supabase/server", () => ({
  createClient: async () => ({ rpc }),
}));

import { lockCountAction } from "@/features/count/actions";

describe("lockCountAction (R3-N1)", () => {
  it("gui p_reasons voi khoa snake_case cho RPC count_lock", async () => {
    rpc.mockResolvedValue({ data: { ok: true }, error: null });
    const countId = "c8e54061-4627-47a2-8061-3fefa1608c8e";
    const lineId = "11111111-1111-4111-8111-111111111111";
    await lockCountAction({
      countId,
      reasons: [{ lineId, reasonCode: "other", explanation: "Kiem lai" }],
    });
    const [fn, args] = rpc.mock.calls[0];
    expect(fn).toBe("count_lock");
    expect(args.p_reasons).toEqual([
      { line_id: lineId, reason_code: "other", explanation: "Kiem lai" },
    ]);
  });
});
