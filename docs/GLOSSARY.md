# Thuật ngữ

| Tiếng Việt | English | Trong code |
|---|---|---|
| Pháp nhân | Legal entity | `legal_entities` |
| Khách sạn | Property | `properties` |
| Bộ phận kinh doanh | Outlet | `outlets` |
| Kho tổng / kho bộ phận / kho tầng / xe đẩy | Main / outlet / floor store / trolley | `warehouses.kind` |
| Kho đang đi đường | In-transit | `kind = 'transit'` |
| Vật tư, nguyên vật liệu (NVL) | Item | `items` |
| Mã tạm | Temporary item code | `items.is_temp` |
| Đơn vị kho / mua / công thức | Stock / purchase / recipe UOM | `stock_uom`, `item_purchase_units`, `recipe_uom` |
| Nhà cung cấp (NCC) | Supplier | `suppliers` |
| Hợp đồng khung | Price agreement | `price_agreements` |
| Giá trần | Ceiling price | `ceiling_prices` |
| Yêu cầu mua hàng | Purchase request (PR) | `purchase_requests` |
| Đơn đặt hàng | Purchase order (PO) | `purchase_orders` |
| Phiếu nhận hàng / nhập kho | Goods receipt (GRN) | `goods_receipts` |
| Nhận hàng mù | Blind receiving | RPC `receiving_*` |
| Trừ bì | Tare | `tare_qty` |
| Đối soát 3 chiều | 3-way match | `invoice_match` |
| Phiếu lĩnh | Requisition | `requisitions` |
| Xuất theo mục đích | Purpose issue | `purpose_issues` |
| Hủy hàng | Waste / spoilage | `waste_reports` |
| Sổ cái kho | Stock ledger | `stock_moves` |
| Bút toán đảo | Reversal | `move_type = 'reversal'` |
| Bình quân gia quyền tức thời | Moving weighted average | `item_costs.avg_cost` |
| Kiểm kê mù | Blind count | `stock_counts`, `v_count_sheet` |
| Thực tế vs Lý thuyết | Actual vs Theoretical (AvT) | `variance_*` |
| Tách biệt nhiệm vụ | Segregation of duties (SoD) | `assert_sod` |
| Tạm ứng | Cash advance | `advances` |
| Bảng kê hàng không hóa đơn | No-invoice purchase listing | `no_invoice_listings` |
| Công nợ NCC | Accounts payable | `ap_ledger` |
| Nghiệm thu | Service acceptance | `service_acceptances` |
| Khoản mục chi phí | Expense category | `expense_categories` |
| Trung tâm chi phí / bộ phận USALI | Cost center | `cost_centers` |
| Chi phí trên đêm phòng bán | CPOR | báo cáo |
| Chuẩn setup phòng | Room setup standard / par card | `room_setup_standards` |
| Đồ miễn phí trong phòng | Complimentary | `item_groups.kind = 'complimentary'` |
| Khóa ngày / khóa kỳ | Day lock / period close | `day_locks`, `accounting_periods` |
