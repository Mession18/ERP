import unittest
from fastapi.testclient import TestClient
from backend.main import app
from backend.database import SessionLocal
from backend.models import Party, Item, BOM, BOMItem, LotRecord, BinStock, InventoryLedger, Order, WorkOrder, ProductionIssueLog, FinancialFlow

class TestERPBackend(unittest.TestCase):
    def setUp(self):
        self.client = TestClient(app)
        # Clear database records to ensure repeatable test cases
        db = SessionLocal()
        try:
            db.query(FinancialFlow).delete()
            db.query(ProductionIssueLog).delete()
            db.query(WorkOrder).delete()
            db.query(Order).delete()
            db.query(InventoryLedger).delete()
            db.query(BinStock).delete()
            db.query(LotRecord).delete()
            db.query(BOMItem).delete()
            db.query(BOM).delete()
            db.query(Item).delete()
            db.query(Party).delete()
            db.commit()
        finally:
            db.close()

    def test_flow(self):
        # 1. Test basic root and health check
        response = self.client.get("/api")
        self.assertEqual(response.status_code, 200)
        self.assertIn("online", response.json()["message"])

        # 2. Create Parties (往来单位)
        party_data = {
            "name": "宏达化工材料厂",
            "is_customer": "false",
            "is_supplier": "true",
            "credit_limit": "50000.0",
            "payment_term": "月结30天",
            "contacts_json": '[{"name": "李经理", "phone": "13911223344", "role": "业务经理"}]',
            "addresses_json": '[{"address": "宏达工业区8号", "type": "发货地"}]'
        }
        response = self.client.post("/api/parties", data=party_data)
        self.assertEqual(response.status_code, 200)
        party = response.json()
        self.assertEqual(party["code"], "PART-0001")
        party_id = party["id"]

        # 3. Create Items (物料档案)
        # Raw material
        item_raw_data = {
            "name": "聚氯乙烯颗粒",
            "specs": "工业级-100kg/袋",
            "unit": "kg",
            "type": "原材料",
            "min_safety_stock": "500",
            "max_safety_stock": "10000",
            "remarks": "注塑基础原料"
        }
        response = self.client.post("/api/items", data=item_raw_data)
        self.assertEqual(response.status_code, 200)
        item_raw = response.json()
        raw_id = item_raw["id"]

        # Finished Product
        item_prod_data = {
            "name": "高压耐磨软管",
            "specs": "DN15-防爆型",
            "unit": "米",
            "type": "成品",
            "min_safety_stock": "100",
            "max_safety_stock": "2000"
        }
        response = self.client.post("/api/items", data=item_prod_data)
        self.assertEqual(response.status_code, 200)
        item_prod = response.json()
        prod_id = item_prod["id"]

        # 4. Create Lot & Stock levels (批次与入库)
        lot_data = {
            "item_id": str(raw_id),
            "lot_number": "RAW-PVC-20260805-SUPP01",
            "supplier_id": str(party_id)
        }
        response = self.client.post("/api/lots", data=lot_data)
        self.assertEqual(response.status_code, 200)
        lot = response.json()
        lot_id = lot["id"]

        # Add physical stock into target bin (Available warehouse)
        stock_data = {
            "warehouse_type": "Available",
            "zone": "ZoneA",
            "shelf": "Shelf03",
            "tier": "Tier2",
            "bin_position": "Bin05",
            "item_id": str(raw_id),
            "lot_id": str(lot_id),
            "quantity_delta": "2000.0",
            "movement_type": "采购入库",
            "reference_doc_id": "PO-20260801"
        }
        response = self.client.post("/api/warehouses/bins", data=stock_data)
        self.assertEqual(response.status_code, 200)

        # 5. Create BOM formulation
        bom_data = {
            "parent_item_id": str(prod_id),
            "version": "V1.0",
            "children_json": '[{"child_item_id": ' + str(raw_id) + ', "standard_quantity": 1.2, "scrap_rate": 0.02}]'
        }
        response = self.client.post("/api/boms", data=bom_data)
        self.assertEqual(response.status_code, 200)

        # 6. Create Work Order (生产工单)
        wo_data = {
            "target_item_id": str(prod_id),
            "quantity": "500.0",
            "plan_start_date": "2026-08-05",
            "plan_end_date": "2026-08-10"
        }
        response = self.client.post("/api/work_orders", data=wo_data)
        self.assertEqual(response.status_code, 200)
        wo = response.json()
        wo_id = wo["id"]

        # 7. Issue Materials (领料与超领)
        # Standard issue:Moves 600kg from Available to LineSide
        issue_data = {
            "type": "标准领料",
            "item_id": str(raw_id),
            "lot_id": str(lot_id),
            "quantity": "600.0"
        }
        response = self.client.post(f"/api/work_orders/{wo_id}/issue", data=issue_data)
        self.assertEqual(response.status_code, 200)

        # Excess issue with forced scrap reason
        excess_data = {
            "type": "超领",
            "item_id": str(raw_id),
            "lot_id": str(lot_id),
            "quantity": "50.0",
            "scrap_reason": "挤出机段温异常偏高造成初始烧胶报废"
        }
        response = self.client.post(f"/api/work_orders/{wo_id}/issue", data=excess_data)
        self.assertEqual(response.status_code, 200)

        # Excess issue WITHOUT forced scrap reason must FAIL
        excess_data_fail = {
            "type": "超领",
            "item_id": str(raw_id),
            "lot_id": str(lot_id),
            "quantity": "20.0"
        }
        response = self.client.post(f"/api/work_orders/{wo_id}/issue", data=excess_data_fail)
        self.assertEqual(response.status_code, 400)

        # 8. Complete Work Order & verify consumption reconciliation
        # Standard consumption = 500成品 * 1.2标准 = 600kg. Actual consumed = 600 standard + 50 excess = 650kg.
        response = self.client.get(f"/api/work_orders/{wo_id}/consumption")
        self.assertEqual(response.status_code, 200)
        recon_list = response.json()
        self.assertEqual(len(recon_list), 1)
        self.assertEqual(recon_list[0]["actual_consumed"], 650.0)

        # 9. Test forward and backward traceability chain loops
        response = self.client.get("/api/traceability/forward", params={"lot_number": "RAW-PVC-20260805-SUPP01"})
        self.assertEqual(response.status_code, 200)
        forward = response.json()
        self.assertEqual(forward["input_lot"], "RAW-PVC-20260805-SUPP01")

        # 10. Finish order and trigger passive billing AR/AP
        order_data = {
            "type": "采购",
            "party_id": str(party_id),
            "item_id": str(raw_id),
            "quantity": "100",
            "unit_price": "2.5",
            "order_date": "2026-08-05",
            "delivery_date": "2026-08-15"
        }
        response = self.client.post("/api/orders", data=order_data)
        self.assertEqual(response.status_code, 200)
        order = response.json()
        order_id = order["id"]

        # Approve and complete
        response = self.client.put(f"/api/orders/{order_id}/status", data={"status": "已完成"})
        self.assertEqual(response.status_code, 200)

        # Check financial flow auto-created passively!
        response = self.client.get("/api/finance/flows")
        self.assertEqual(response.status_code, 200)
        flows = response.json()
        self.assertEqual(len(flows), 1)
        self.assertEqual(flows[0]["type"], "应付")
        self.assertEqual(flows[0]["amount"], 250.0) # 100 * 2.5 = 250

if __name__ == "__main__":
    unittest.main()
