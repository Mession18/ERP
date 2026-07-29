import unittest
from fastapi.testclient import TestClient
from backend.main import app
from backend.database import SessionLocal
from backend.models import Product, Customer, Order, Delivery, FinancialRecord

class TestERPBackend(unittest.TestCase):
    def setUp(self):
        self.client = TestClient(app)
        # Clear database records to ensure repeatable test cases
        db = SessionLocal()
        try:
            db.query(FinancialRecord).delete()
            db.query(Delivery).delete()
            db.query(Order).delete()
            db.query(Product).delete()
            db.query(Customer).delete()
            db.commit()
        finally:
            db.close()

    def test_flow(self):
        # 1. Test basic root
        response = self.client.get("/")
        self.assertEqual(response.status_code, 200)
        self.assertIn("Backend is running", response.json()["message"])

        # 2. Test create product (Inventory)
        prod_data = {
            "name": "测试商品A",
            "specs": "100g/盒",
            "quantity": "50",
            "remarks": "这是一条备注",
            "process_info": "生产工艺说明..."
        }
        response = self.client.post("/api/products", data=prod_data)
        self.assertEqual(response.status_code, 200)
        prod = response.json()
        self.assertEqual(prod["name"], "测试商品A")
        self.assertEqual(prod["code"], "PROD-0001") # auto code
        self.assertEqual(prod["status"], "上架")
        prod_id = prod["id"]

        # 3. Test create customer (buyer)
        cust_data = {
            "type": "买家",
            "name": "北京科技公司",
            "contact_person": "张经理",
            "contact_phone": "13800138000",
            "address": "北京市海淀区科技路"
        }
        response = self.client.post("/api/customers", data=cust_data)
        self.assertEqual(response.status_code, 200)
        cust = response.json()
        self.assertEqual(cust["name"], "北京科技公司")
        self.assertEqual(cust["code"], "CUST-0001")
        cust_id = cust["id"]

        # 4. Test create order (Sales type, qty=10, price=15.5)
        order_data = {
            "type": "销售",
            "customer_id": str(cust_id),
            "product_id": str(prod_id),
            "quantity": "10",
            "unit_price": "15.5",
            "order_date": "2024-05-01",
            "delivery_date": "2024-05-15"
        }
        response = self.client.post("/api/orders", data=order_data)
        self.assertEqual(response.status_code, 200)
        order = response.json()
        self.assertEqual(order["code"], "ORD-0001")
        self.assertEqual(order["status"], "进行中")
        order_id = order["id"]

        # 5. Check off-shelf (下架) constraint: must FAIL because there's an ongoing order
        response = self.client.put(f"/api/products/{prod_id}/status", data={"status": "下架"})
        self.assertEqual(response.status_code, 400)
        self.assertIn("ongoing orders", response.json()["detail"])

        # 6. Check product deletion constraint: must FAIL because it's referenced by an order
        response = self.client.delete(f"/api/products/{prod_id}")
        self.assertEqual(response.status_code, 400)
        self.assertIn("associated orders", response.json()["detail"])

        # 7. Check customer deletion constraint: must FAIL because of related order
        response = self.client.delete(f"/api/customers/{cust_id}")
        self.assertEqual(response.status_code, 400)

        # 8. Test deliver items: cannot exceed pending quantity (which is 10)
        del_data = {
            "order_id": str(order_id),
            "quantity": "12", # exceeds pending 10
            "delivery_date": "2024-05-05",
            "remarks": "送货日志"
        }
        response = self.client.post("/api/deliveries", data=del_data)
        self.assertEqual(response.status_code, 400)

        # 9. Deliver valid quantity: 6 items (sales reduces product stock from 50 to 44)
        del_data["quantity"] = "6"
        response = self.client.post("/api/deliveries", data=del_data)
        self.assertEqual(response.status_code, 200)

        # Verify product quantity decreased
        response = self.client.get(f"/api/products/{prod_id}")
        self.assertEqual(response.json()["quantity"], 44)

        # 10. Financial record: pay 100.0 (total is 10 * 15.5 = 155.0)
        fin_data = {
            "order_id": str(order_id),
            "amount": "100.0",
            "payment_date": "2024-05-06",
            "is_invoiced": "true",
            "invoice_no": "INV-2024001",
            "remarks": "首笔付款"
        }
        response = self.client.post("/api/financials", data=fin_data)
        self.assertEqual(response.status_code, 200)

        # Pay too much (e.g. 100 + 60 = 160, total is 155) -> must fail
        fin_data2 = {
            "order_id": str(order_id),
            "amount": "60.0",
            "payment_date": "2024-05-07"
        }
        response = self.client.post("/api/financials", data=fin_data2)
        self.assertEqual(response.status_code, 400)

if __name__ == "__main__":
    unittest.main()
