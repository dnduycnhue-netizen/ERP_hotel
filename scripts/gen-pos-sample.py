#!/usr/bin/env python3
"""Sinh file xuat POS GIA LAP (synthetic) de thiet ke import (Q34/Q168).

KHONG phai du lieu that, KHONG nap vao database. Cot va dinh dang la GIA DINH
cua Claude Code cho toi khi co file xuat that tu POS cua khach san — khi do
sua script/schema theo file that. Hat giong co dinh => ket qua lap lai duoc.
Dung: python3 scripts/gen-pos-sample.py > docs/samples/pos-export-sample-SYNTHETIC.csv
"""
import csv, random, sys

random.seed(20261112)
MENU = [  # (ma mon = recipes.code, ten, don gia VND)
    ("ALA-01", "Rau muống trộn tôm thịt", 95000), ("ALA-02", "Tôm Chiên Giòn", 145000),
    ("ALA-03", "Bánh mì nhồi thịt bò nướng", 120000), ("ALA-04", "Súp Hải Sản Tóc Tiên", 110000),
    ("ALA-05", "Sườn heo xào chua ngọt", 135000), ("ALA-06", "Cà tím tay cầm", 85000),
]
DATES = ["2026-11-10", "2026-11-11", "2026-11-12"]
SHIFTS = [("morning", 7, 14), ("evening", 17, 22)]
w = csv.writer(sys.stdout, lineterminator="\n")
w.writerow(["bill_no", "business_date", "shift", "time", "outlet", "item_code",
            "item_name", "qty", "unit_price", "amount", "payment"])
bill = 0
for d in DATES:
    for shift, h0, h1 in SHIFTS:
        for _ in range(random.randint(6, 10)):
            bill += 1
            t = f"{random.randint(h0, h1 - 1):02d}:{random.randint(0, 59):02d}"
            pay = random.choice(["cash", "card", "room_charge"])
            for code, name, price in random.sample(MENU, random.randint(1, 4)):
                q = random.randint(1, 3)
                w.writerow([f"B{d.replace('-', '')}-{bill:04d}", d, shift, t, "RESTAURANT",
                            code, name, q, price, q * price, pay])
