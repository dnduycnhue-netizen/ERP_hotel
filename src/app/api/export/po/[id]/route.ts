import { createHash } from "node:crypto";
import { NextResponse, type NextRequest } from "next/server";
import { getRpcErrorMessage } from "@/i18n/errors.vi";
import { vi } from "@/i18n/vi";
import { buildPoPdf, isPoPdfData } from "@/features/export/poPdf";
import { callJsonRpc } from "@/features/export/rpc";
import { createClient, getAuthenticatedUser } from "@/lib/supabase/server";

/**
 * CONTRACT (C3) cho workstream C4 — man /{property}/finance/export:
 *
 * GET /api/export/po/[id] — [id] la uuid cua purchase_orders.
 * - 400 khi [id] khong phai uuid.
 * - 401 khi chua dang nhap (proxy.ts khong redirect /api/* ve /login).
 * - 403 khi thieu quyen `po.view` (hoac po.create/po.approve/po.close)
 *   hoac `po.view_price` (PDF gui NCC bat buoc co gia).
 * - 404 khi khong tim thay PO.
 * - 200 tra file PDF: Content-Type application/pdf, ten file
 *   `PO-<doc_no>.pdf` (chi chua [A-Za-z0-9._-]).
 * - Moi lan xuat thanh cong ghi 1 dong vao bang `export_batches`
 *   (kind='po-pdf', ref_type='purchase_order', ref_id=<po id>,
 *   file_hash=sha256 hex cua file, exported_by, exported_at) va danh
 *   dau `purchase_orders.export_status='exported'`.
 * URL nay KHONG doi sau khi C3 ban giao.
 *
 * Route handler dung request.nextUrl/params nen mac dinh dynamic (khong
 * dung `dynamic = "force-dynamic"` — khong tuong thich voi
 * cacheComponents).
 */

const UUID_RE =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

function sanitizeFilename(value: string): string {
  return value.replace(/[^A-Za-z0-9._-]/g, "-");
}

export async function GET(
  _request: NextRequest,
  context: { params: Promise<{ id: string }> },
): Promise<NextResponse> {
  const { id } = await context.params;
  if (!UUID_RE.test(id)) {
    return NextResponse.json({ error: vi.export.invalidPoId }, { status: 400 });
  }

  const supabase = await createClient();
  const user = await getAuthenticatedUser(supabase);
  if (!user) {
    return NextResponse.json(
      { error: vi.export.unauthorized },
      { status: 401 },
    );
  }

  const result = await callJsonRpc(supabase, "export_po_data", {
    p_po_id: id,
  });
  if (!result.ok) {
    if (result.sqlstate === "42501") {
      return NextResponse.json(
        { error: getRpcErrorMessage(result.code), code: result.code },
        { status: 403 },
      );
    }
    if (result.code === "ERR_INVALID_STATUS") {
      return NextResponse.json(
        { error: vi.export.poNotFound, code: result.code },
        { status: 404 },
      );
    }
    return NextResponse.json(
      { error: vi.export.pdfFailed, code: result.code },
      { status: 500 },
    );
  }
  if (!isPoPdfData(result.data)) {
    return NextResponse.json({ error: vi.export.pdfFailed }, { status: 500 });
  }

  let buffer: Buffer;
  try {
    buffer = await buildPoPdf(result.data);
  } catch {
    return NextResponse.json({ error: vi.export.pdfFailed }, { status: 500 });
  }

  // Ghi log xuat TRUOC khi tra file: file khong bao gio duoc tra ma
  // khong co dong export_batches (chong xuat trung, M09).
  const fileHash = createHash("sha256").update(buffer).digest("hex");
  const recordResult = await callJsonRpc(supabase, "export_batch_record", {
    p_kind: "po-pdf",
    p_ref_type: "purchase_order",
    p_ref_ids: [id],
    p_file_hash: fileHash,
    p_note: null,
  });
  if (!recordResult.ok) {
    return NextResponse.json(
      { error: vi.export.exportRecordFailed, code: recordResult.code },
      { status: 500 },
    );
  }

  const filename = `PO-${sanitizeFilename(result.data.po.doc_no)}.pdf`;
  return new NextResponse(new Uint8Array(buffer), {
    headers: {
      "Content-Type": "application/pdf",
      "Content-Disposition": `attachment; filename="${filename}"`,
      "Cache-Control": "no-store",
    },
  });
}
