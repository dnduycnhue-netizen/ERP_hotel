#!/usr/bin/env python3
"""Sinh danh sach nha cung cap GIA LAP theo dung mau docs/data-test/mau_ncc.xlsx
(sheet 'Du lieu', 10 cot) de thu man nhap /master/import (loai "Nha cung cap").

Moi ten, ma so thue, so dien thoai, so tai khoan deu GIA — khong phai du lieu
that, KHONG dung cho van hanh. Chay: python3 scripts/gen-supplier-sample.py
"""
import os
import unicodedata
import openpyxl

OUT = os.path.join(os.path.dirname(__file__), "..", "docs", "samples",
                   "suppliers-sample-SYNTHETIC.xlsx")

HEADER = ["Mã", "Tên", "Mã số thuế", "Loại NCC", "Điện thoại", "Địa chỉ",
          "Hạn thanh toán (ngày)", "Ngân hàng", "Số TK", "Chủ TK"]

# (ten, loai, dia chi, han TT, ngan hang | None)
ROWS = [
    ("Công ty TNHH Thực phẩm Mẫu An Phát", "công ty", "Cẩm Châu, Hội An, Quảng Nam", 30, "Vietcombank"),
    ("Công ty TNHH Hải sản Mẫu Biển Xanh", "công ty", "Sơn Trà, Đà Nẵng", 15, "Techcombank"),
    ("Công ty CP Rau củ Mẫu Đà Lạt", "công ty", "Đà Lạt, Lâm Đồng", 30, "BIDV"),
    ("Công ty TNHH Thịt Mẫu Sạch Quảng Nam", "công ty", "Điện Bàn, Quảng Nam", 15, "Agribank"),
    ("Công ty TNHH Đồ uống Mẫu Miền Trung", "công ty", "Hải Châu, Đà Nẵng", 30, "Vietcombank"),
    ("Công ty TNHH Rượu vang Mẫu Phương Nam", "công ty", "Quận 3, TP. Hồ Chí Minh", 45, "ACB"),
    ("Công ty TNHH Bao bì Mẫu Xanh", "công ty", "Thanh Khê, Đà Nẵng", 30, "VietinBank"),
    ("Công ty TNHH Hóa chất vệ sinh Mẫu Sạch", "công ty", "Liên Chiểu, Đà Nẵng", 30, "MB Bank"),
    ("Công ty TNHH Vật tư buồng phòng Mẫu Hội An", "công ty", "Minh An, Hội An, Quảng Nam", 30, "Vietcombank"),
    ("Công ty TNHH Gas và nhiên liệu Mẫu", "công ty", "Duy Xuyên, Quảng Nam", 15, "BIDV"),
    ("Hộ kinh doanh Mẫu Bánh mì Cô Lan", "hộ kinh doanh", "Phố cổ, Hội An, Quảng Nam", 7, None),
    ("Hộ kinh doanh Mẫu Trứng gia cầm Ba Thanh", "hộ kinh doanh", "Điện Ngọc, Quảng Nam", 7, "Agribank"),
    ("Hộ kinh doanh Mẫu Đá viên Hội An", "hộ kinh doanh", "Cẩm Phô, Hội An, Quảng Nam", 7, None),
    ("Hộ kinh doanh Mẫu Gạo Năm Hòa", "hộ kinh doanh", "Duy Vinh, Quảng Nam", 15, "Agribank"),
    ("Mẫu Mua chợ — Rau thơm (cá nhân)", "cá nhân", "Chợ Hội An, Quảng Nam", 0, None),
    ("Mẫu Mua chợ — Cá tươi (cá nhân)", "cá nhân", "Chợ Hội An, Quảng Nam", 0, None),
]


def strip_accents(text: str) -> str:
    """Chu TK ngan hang thuong khong dau (nhu file mau)."""
    text = text.replace("Đ", "D").replace("đ", "d")
    return "".join(
        c for c in unicodedata.normalize("NFD", text) if unicodedata.category(c) != "Mn"
    )


def main() -> None:
    wb = openpyxl.Workbook()
    ws = wb.active
    ws.title = "Du lieu"
    ws.append(HEADER)
    for i, (name, kind, addr, terms, bank) in enumerate(ROWS, start=1):
        code = f"SUP{i:04d}"
        tax = f"09{i:08d}" if kind == "công ty" else None
        phone = f"09000{i:05d}"
        acc = f"000{i:07d}" if bank else None
        holder = strip_accents(name).upper() if bank else None
        ws.append([code, name, tax, kind, phone, addr, terms, bank, acc, holder])
    for col, width in zip("ABCDEFGHIJ", (10, 46, 14, 14, 14, 34, 22, 14, 14, 46)):
        ws.column_dimensions[col].width = width
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    wb.save(OUT)
    print(f"Da ghi {len(ROWS)} nha cung cap gia lap -> {os.path.normpath(OUT)}")


if __name__ == "__main__":
    main()
