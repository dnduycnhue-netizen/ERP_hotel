import { NextResponse, type NextRequest } from "next/server";
import { getRpcErrorMessage } from "@/i18n/errors.vi";
import { vi } from "@/i18n/vi";
import { getExportDefinition } from "@/features/export/definitions";
import { exportParamsSchema } from "@/features/export/params";
import { callExportRpc } from "@/features/export/rpc";
import { buildExportWorkbook } from "@/features/export/workbook";
import { createClient, getAuthenticatedUser } from "@/lib/supabase/server";

/**
 * GET /api/export/[kind]?entity=<legal_entity_id>&from=yyyy-mm-dd&to=yyyy-mm-dd
 * (T-043) — xuat Excel ke toan. Chi API, khong co UI (nut tai ve thuoc T-044).
 * Route handler dung request.nextUrl nen mac dinh dynamic (khong dung
 * `dynamic = "force-dynamic"` — khong tuong thich voi cacheComponents).
 *
 * - 401 khi chua dang nhap (proxy.ts khong redirect /api/* ve /login).
 * - 403 khi thieu quyen `export.accounting` (kiem tra trong RPC).
 * - 400 khi khoang ngay chua khoa so: loi tieng Viet kem ngay/kỳ chua khoa.
 * - 200 tra file .xlsx (tien/so luong la so Excel that).
 */
export async function GET(
  request: NextRequest,
  context: { params: Promise<{ kind: string }> },
): Promise<NextResponse> {
  const { kind } = await context.params;
  const def = getExportDefinition(kind);
  if (!def) {
    return NextResponse.json({ error: vi.export.unknownKind }, { status: 404 });
  }

  const parsed = exportParamsSchema.safeParse(
    Object.fromEntries(request.nextUrl.searchParams),
  );
  if (!parsed.success) {
    return NextResponse.json(
      { error: vi.export.invalidParams },
      { status: 400 },
    );
  }

  const supabase = await createClient();
  const user = await getAuthenticatedUser(supabase);
  if (!user) {
    return NextResponse.json(
      { error: vi.export.unauthorized },
      { status: 401 },
    );
  }

  const result = await callExportRpc(
    supabase,
    def.rpc,
    parsed.data.entity,
    parsed.data.from,
    parsed.data.to,
  );
  if (!result.ok) {
    return rpcErrorResponse(result);
  }

  const buffer = buildExportWorkbook(def, result.data);
  const filename = `${def.filePrefix}-${result.data.meta.entity_code}-${parsed.data.from}-${parsed.data.to}.xlsx`;
  return new NextResponse(new Uint8Array(buffer), {
    headers: {
      "Content-Type":
        "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
      "Content-Disposition": `attachment; filename="${filename}"`,
      "Cache-Control": "no-store",
    },
  });
}

function rpcErrorResponse(
  result: Extract<Awaited<ReturnType<typeof callExportRpc>>, { ok: false }>,
): NextResponse {
  const { code, detail, sqlstate } = result;
  const fullCode = code && detail ? `${code}:${detail}` : code;
  if (sqlstate === "42501") {
    return NextResponse.json(
      { error: getRpcErrorMessage(fullCode), code },
      { status: 403 },
    );
  }
  if (sqlstate === "22023" || code === "ERR_EXPORT_NOT_LOCKED") {
    return NextResponse.json(
      { error: getRpcErrorMessage(fullCode), code, detail },
      { status: 400 },
    );
  }
  return NextResponse.json(
    { error: vi.export.exportFailed, code },
    { status: 500 },
  );
}
