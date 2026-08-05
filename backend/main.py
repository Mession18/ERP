import os
import shutil
import uuid
from datetime import datetime
from typing import List, Optional
from fastapi import FastAPI, Depends, HTTPException, File, UploadFile, Query, Form
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
from sqlalchemy.orm import Session
from sqlalchemy import or_, and_, func

from backend.database import engine, Base, get_db
from backend.models import Product, Customer, Order, Delivery, FinancialRecord

# Create tables
Base.metadata.create_all(bind=engine)

app = FastAPI(title="ERP System Backend")

# Enable CORS for Flutter web/desktop/mobile
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Ensure uploads directory exists and mount it
UPLOAD_DIR = "backend/uploads"
os.makedirs(UPLOAD_DIR, exist_ok=True)
app.mount("/uploads", StaticFiles(directory=UPLOAD_DIR), name="uploads")

@app.get("/")
def read_root():
    return {"status": "ok", "message": "ERP Backend is running"}

@app.get("/api")
@app.get("/api/")
def read_api_root():
    return {"status": "ok", "message": "API is online"}

# ==================== FILE UPLOAD ====================
@app.post("/api/upload")
async def upload_file(file: UploadFile = File(...)):
    try:
        ext = os.path.splitext(file.filename)[1]
        unique_name = f"{uuid.uuid4()}{ext}"
        filepath = os.path.join(UPLOAD_DIR, unique_name)
        with open(filepath, "wb") as buffer:
            shutil.copyfileobj(file.file, buffer)
        file_url = f"/uploads/{unique_name}"
        return {"url": file_url, "filename": file.filename}
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"File upload failed: {str(e)}")


# ==================== INVENTORY (PRODUCTS) ====================
def generate_product_code(db: Session) -> str:
    count = db.query(Product).count()
    code = f"PROD-{count + 1:04d}"
    while db.query(Product).filter(Product.code == code).first() is not None:
        count += 1
        code = f"PROD-{count + 1:04d}"
    return code

@app.get("/api/products")
def get_products(
    show_off_shelf: bool = Query(False),
    search: Optional[str] = Query(None),
    name: Optional[str] = Query(None),
    specs: Optional[str] = Query(None),
    db: Session = Depends(get_db)
):
    query = db.query(Product)

    if not show_off_shelf:
        query = query.filter(Product.status == "上架")

    if search:
        # Fuzzy search
        query = query.filter(
            or_(
                Product.code.icontains(search),
                Product.name.icontains(search),
                Product.specs.icontains(search),
                Product.remarks.icontains(search)
            )
        )
    else:
        # Advanced search
        if name:
            query = query.filter(Product.name.icontains(name))
        if specs:
            query = query.filter(Product.specs.icontains(specs))

    return query.order_by(Product.code).all()

@app.get("/api/products/{id}")
def get_product(id: int, db: Session = Depends(get_db)):
    product = db.query(Product).filter(Product.id == id).first()
    if not product:
        raise HTTPException(status_code=404, detail="Product not found")
    return product

@app.post("/api/products")
def create_product(
    name: str = Form(...),
    specs: str = Form(...),
    quantity: int = Form(0),
    code: Optional[str] = Form(None),
    image_url: Optional[str] = Form(None),
    remarks: Optional[str] = Form(None),
    design_images_json: Optional[str] = Form("[]"),
    process_info: Optional[str] = Form(None),
    db: Session = Depends(get_db)
):
    # Check manual code uniqueness
    final_code = code.strip() if (code and code.strip()) else generate_product_code(db)
    if db.query(Product).filter(Product.code == final_code).first():
        raise HTTPException(status_code=400, detail="Product code already exists")

    import json
    try:
        design_images = json.loads(design_images_json)
    except Exception:
        design_images = []

    product = Product(
        code=final_code,
        name=name,
        specs=specs,
        quantity=quantity,
        image_url=image_url,
        remarks=remarks,
        design_images=design_images,
        process_info=process_info,
        status="上架"
    )
    db.add(product)
    db.commit()
    db.refresh(product)
    return product

@app.put("/api/products/{id}")
def update_product(
    id: int,
    name: str = Form(...),
    specs: str = Form(...),
    quantity: int = Form(...),
    code: str = Form(...),
    image_url: Optional[str] = Form(None),
    remarks: Optional[str] = Form(None),
    design_images_json: Optional[str] = Form("[]"),
    process_info: Optional[str] = Form(None),
    db: Session = Depends(get_db)
):
    product = db.query(Product).filter(Product.id == id).first()
    if not product:
        raise HTTPException(status_code=404, detail="Product not found")

    # Check code uniqueness if changed
    if code != product.code:
        if db.query(Product).filter(Product.code == code).first():
            raise HTTPException(status_code=400, detail="Product code already exists")

    import json
    try:
        design_images = json.loads(design_images_json)
    except Exception:
        design_images = product.design_images

    product.code = code
    product.name = name
    product.specs = specs
    product.quantity = quantity
    product.image_url = image_url
    product.remarks = remarks
    product.design_images = design_images
    product.process_info = process_info

    db.commit()
    db.refresh(product)
    return product

@app.put("/api/products/{id}/status")
def toggle_product_status(id: int, status: str = Form(...), db: Session = Depends(get_db)):
    product = db.query(Product).filter(Product.id == id).first()
    if not product:
        raise HTTPException(status_code=404, detail="Product not found")

    if status not in ["上架", "下架"]:
        raise HTTPException(status_code=400, detail="Invalid status")

    # Constraint: 下架只能在没有正在进行的订单时可以
    if status == "下架":
        ongoing_orders = db.query(Order).filter(
            and_(Order.product_id == id, Order.status == "进行中")
        ).count()
        if ongoing_orders > 0:
            raise HTTPException(
                status_code=400,
                detail="Cannot take product off-shelf because there are ongoing orders using it"
            )

    product.status = status
    db.commit()
    db.refresh(product)
    return product

@app.delete("/api/products/{id}")
def delete_product(id: int, db: Session = Depends(get_db)):
    product = db.query(Product).filter(Product.id == id).first()
    if not product:
        raise HTTPException(status_code=404, detail="Product not found")

    # Constraint: 删除只可以在没有进行中的订单且没有任何曾经的交易历史，交货历史，结账历史的前提下可以
    # Check any orders associated
    any_orders = db.query(Order).filter(Order.product_id == id).count()
    if any_orders > 0:
        raise HTTPException(
            status_code=400,
            detail="Cannot delete product because it has associated orders or transactions."
        )

    db.delete(product)
    db.commit()
    return {"message": "Product deleted successfully"}

@app.get("/api/products/{id}/history")
def get_product_history(id: int, db: Session = Depends(get_db)):
    # Returns all deliveries for this product
    deliveries = db.query(Delivery).join(Order).filter(Order.product_id == id).order_by(Delivery.delivery_date.desc()).all()
    result = []
    for d in deliveries:
        result.append({
            "delivery_id": d.id,
            "order_code": d.order.code,
            "order_type": d.order.type,
            "customer_name": d.order.customer.name,
            "quantity": d.quantity,
            "delivery_date": d.delivery_date,
            "remarks": d.remarks
        })
    return result


# ==================== CUSTOMERS ====================
def generate_customer_code(db: Session) -> str:
    count = db.query(Customer).count()
    code = f"CUST-{count + 1:04d}"
    while db.query(Customer).filter(Customer.code == code).first() is not None:
        count += 1
        code = f"CUST-{count + 1:04d}"
    return code

@app.get("/api/customers")
def get_customers(
    search: Optional[str] = Query(None),
    name: Optional[str] = Query(None),
    contact_person: Optional[str] = Query(None),
    db: Session = Depends(get_db)
):
    query = db.query(Customer)
    if search:
        query = query.filter(
            or_(
                Customer.code.icontains(search),
                Customer.name.icontains(search),
                Customer.contact_person.icontains(search),
                Customer.contact_phone.icontains(search),
                Customer.address.icontains(search)
            )
        )
    else:
        if name:
            query = query.filter(Customer.name.icontains(name))
        if contact_person:
            query = query.filter(Customer.contact_person.icontains(contact_person))

    customers = query.order_by(Customer.code).all()

    # Compute computed fields: 进行中的订单数量，待收（付）款金额
    result = []
    for c in customers:
        # Ongoing orders count
        ongoing_count = db.query(Order).filter(
            and_(Order.customer_id == c.id, Order.status == "进行中")
        ).count()

        # Calculate pending cash
        # For each order: total_val = qty * price
        # paid_val = sum(financials)
        # diff = total_val - paid_val
        orders = db.query(Order).filter(Order.customer_id == c.id).all()
        pending_amount = 0.0
        for o in orders:
            total_amount = o.quantity * o.unit_price
            paid_amount = sum(f.amount for f in o.financials)
            pending_amount += (total_amount - paid_amount)

        result.append({
            "id": c.id,
            "code": c.code,
            "type": c.type,
            "name": c.name,
            "contact_person": c.contact_person,
            "contact_phone": c.contact_phone,
            "address": c.address,
            "logo_url": c.logo_url,
            "ongoing_orders_count": ongoing_count,
            "pending_amount": max(0.0, pending_amount)
        })
    return result

@app.get("/api/customers/{id}")
def get_customer_details(id: int, db: Session = Depends(get_db)):
    c = db.query(Customer).filter(Customer.id == id).first()
    if not c:
        raise HTTPException(status_code=404, detail="Customer not found")

    orders = db.query(Order).filter(Order.customer_id == id).all()

    ongoing_count = 0
    total_deal_amount = 0.0
    pending_amount = 0.0
    order_history = []

    for o in orders:
        total_amount = o.quantity * o.unit_price
        paid_amount = sum(f.amount for f in o.financials)

        total_deal_amount += total_amount
        pending_amount += (total_amount - paid_amount)

        if o.status == "进行中":
            ongoing_count += 1

        # Compute progress values
        del_qty = sum(d.quantity for d in o.deliveries)
        del_pct = (del_qty / o.quantity * 100) if o.quantity > 0 else 0

        order_history.append({
            "order_id": o.id,
            "order_code": o.code,
            "product_name": o.product.name,
            "specs": o.product.specs,
            "quantity": o.quantity,
            "amount": total_amount,
            "progress": del_pct, # delivery progress
            "status": o.status
        })

    return {
        "id": c.id,
        "code": c.code,
        "type": c.type,
        "name": c.name,
        "contact_person": c.contact_person,
        "contact_phone": c.contact_phone,
        "address": c.address,
        "logo_url": c.logo_url,
        "ongoing_orders_count": ongoing_count,
        "pending_amount": max(0.0, pending_amount),
        "total_deal_amount": total_deal_amount,
        "order_history": order_history
    }

@app.post("/api/customers")
def create_customer(
    type: str = Form(...), # "买家" or "卖家"
    name: str = Form(...),
    code: Optional[str] = Form(None),
    contact_person: Optional[str] = Form(None),
    contact_phone: Optional[str] = Form(None),
    address: Optional[str] = Form(None),
    logo_url: Optional[str] = Form(None),
    db: Session = Depends(get_db)
):
    final_code = code.strip() if (code and code.strip()) else generate_customer_code(db)
    if db.query(Customer).filter(Customer.code == final_code).first():
        raise HTTPException(status_code=400, detail="Customer code already exists")

    customer = Customer(
        code=final_code,
        type=type,
        name=name,
        contact_person=contact_person,
        contact_phone=contact_phone,
        address=address,
        logo_url=logo_url
    )
    db.add(customer)
    db.commit()
    db.refresh(customer)
    return customer

@app.put("/api/customers/{id}")
def update_customer(
    id: int,
    type: str = Form(...),
    name: str = Form(...),
    code: str = Form(...),
    contact_person: Optional[str] = Form(None),
    contact_phone: Optional[str] = Form(None),
    address: Optional[str] = Form(None),
    logo_url: Optional[str] = Form(None),
    db: Session = Depends(get_db)
):
    customer = db.query(Customer).filter(Customer.id == id).first()
    if not customer:
        raise HTTPException(status_code=404, detail="Customer not found")

    if code != customer.code:
        if db.query(Customer).filter(Customer.code == code).first():
            raise HTTPException(status_code=400, detail="Customer code already exists")

    customer.type = type
    customer.name = name
    customer.code = code
    customer.contact_person = contact_person
    customer.contact_phone = contact_phone
    customer.address = address
    customer.logo_url = logo_url

    db.commit()
    db.refresh(customer)
    return customer

@app.delete("/api/customers/{id}")
def delete_customer(id: int, db: Session = Depends(get_db)):
    customer = db.query(Customer).filter(Customer.id == id).first()
    if not customer:
        raise HTTPException(status_code=404, detail="Customer not found")

    # Constraint: 在没有任何交付或收付款的前提下可以删除 (meaning no active orders/transactions)
    any_orders = db.query(Order).filter(Order.customer_id == id).count()
    if any_orders > 0:
        raise HTTPException(
            status_code=400,
            detail="Cannot delete customer because they have related orders or transactions."
        )

    db.delete(customer)
    db.commit()
    return {"message": "Customer deleted successfully"}


# ==================== ORDERS ====================
def generate_order_code(db: Session) -> str:
    count = db.query(Order).count()
    code = f"ORD-{count + 1:04d}"
    while db.query(Order).filter(Order.code == code).first() is not None:
        count += 1
        code = f"ORD-{count + 1:04d}"
    return code

@app.get("/api/orders")
def get_orders(
    show_completed: bool = Query(False),
    search: Optional[str] = Query(None),
    db: Session = Depends(get_db)
):
    orders = db.query(Order).order_by(Order.code).all()

    result = []
    for o in orders:
        total_amount = o.quantity * o.unit_price
        del_qty = sum(d.quantity for d in o.deliveries)
        paid_amount = sum(f.amount for f in o.financials)

        delivery_progress = (del_qty / o.quantity * 100) if o.quantity > 0 else 0
        payment_progress = (paid_amount / total_amount * 100) if total_amount > 0 else 0

        pending_delivery = o.quantity - del_qty
        pending_payment = total_amount - paid_amount

        # Orders: Completed when both pending delivery qty and pending financial balance are 0
        is_completed = (pending_delivery <= 0) and (pending_payment <= 0.01)

        new_status = "已完成" if is_completed else "进行中"
        if o.status != new_status:
            o.status = new_status
            db.add(o)
            db.commit()

        if not show_completed and is_completed:
            continue # hide completed

        # Check if the search filter is active
        match = True
        if search:
            s = search.lower()
            match = (
                s in o.code.lower() or
                s in o.type.lower() or
                s in o.customer.name.lower() or
                s in o.product.name.lower() or
                s in o.product.specs.lower()
            )

        if match:
            result.append({
                "id": o.id,
                "code": o.code,
                "type": o.type,
                "customer_name": o.customer.name,
                "product_name": o.product.name,
                "product_specs": o.product.specs,
                "quantity": o.quantity,
                "unit_price": o.unit_price,
                "total_amount": total_amount,
                "delivery_progress": delivery_progress,
                "payment_progress": payment_progress,
                "order_date": o.order_date,
                "delivery_date": o.delivery_date,
                "status": o.status,
                "delivered_quantity": del_qty,
                "paid_amount": paid_amount
            })

    return result

@app.get("/api/orders/{id}")
def get_order_details(id: int, db: Session = Depends(get_db)):
    o = db.query(Order).filter(Order.id == id).first()
    if not o:
        raise HTTPException(status_code=404, detail="Order not found")

    total_amount = o.quantity * o.unit_price
    del_qty = sum(d.quantity for d in o.deliveries)
    paid_amount = sum(f.amount for f in o.financials)

    deliveries_list = []
    for d in o.deliveries:
        deliveries_list.append({
            "id": d.id,
            "quantity": d.quantity,
            "delivery_date": d.delivery_date,
            "remarks": d.remarks
        })

    financials_list = []
    for f in o.financials:
        financials_list.append({
            "id": f.id,
            "amount": f.amount,
            "payment_date": f.payment_date,
            "invoice_no": f.invoice_no,
            "invoice_image_url": f.invoice_image_url,
            "is_invoiced": f.is_invoiced,
            "remarks": f.remarks
        })

    return {
        "id": o.id,
        "code": o.code,
        "type": o.type,
        "customer_id": o.customer_id,
        "customer_name": o.customer.name,
        "customer_contact_person": o.customer.contact_person,
        "customer_contact_phone": o.customer.contact_phone,
        "customer_address": o.customer.address,
        "product_id": o.product_id,
        "product_name": o.product.name,
        "product_specs": o.product.specs,
        "quantity": o.quantity,
        "unit_price": o.unit_price,
        "total_amount": total_amount,
        "order_date": o.order_date,
        "delivery_date": o.delivery_date,
        "status": o.status,
        "delivery_progress": (del_qty / o.quantity * 100) if o.quantity > 0 else 0,
        "payment_progress": (paid_amount / total_amount * 100) if total_amount > 0 else 0,
        "delivered_quantity": del_qty,
        "paid_amount": paid_amount,
        "deliveries": deliveries_list,
        "financials": financials_list
    }

@app.post("/api/orders")
def create_order(
    type: str = Form(...), # "采购" or "销售"
    customer_id: int = Form(...),
    product_id: int = Form(...),
    quantity: int = Form(...),
    unit_price: float = Form(...),
    order_date: str = Form(...),
    delivery_date: str = Form(...),
    code: Optional[str] = Form(None),
    db: Session = Depends(get_db)
):
    if quantity < 0:
        raise HTTPException(status_code=400, detail="Quantity must be >= 0")

    # Check customer & product exist
    if not db.query(Customer).filter(Customer.id == customer_id).first():
        raise HTTPException(status_code=404, detail="Customer not found")
    if not db.query(Product).filter(Product.id == product_id).first():
        raise HTTPException(status_code=404, detail="Product not found")

    final_code = code.strip() if (code and code.strip()) else generate_order_code(db)
    if db.query(Order).filter(Order.code == final_code).first():
        raise HTTPException(status_code=400, detail="Order code already exists")

    order = Order(
        code=final_code,
        type=type,
        customer_id=customer_id,
        product_id=product_id,
        quantity=quantity,
        unit_price=unit_price,
        order_date=order_date,
        delivery_date=delivery_date,
        status="进行中"
    )
    db.add(order)
    db.commit()
    db.refresh(order)
    return order

@app.put("/api/orders/{id}")
def update_order(
    id: int,
    type: str = Form(...),
    customer_id: int = Form(...),
    product_id: int = Form(...),
    quantity: int = Form(...),
    unit_price: float = Form(...),
    order_date: str = Form(...),
    delivery_date: str = Form(...),
    code: str = Form(...),
    status: str = Form(...), # "进行中" or "已完成"
    db: Session = Depends(get_db)
):
    order = db.query(Order).filter(Order.id == id).first()
    if not order:
        raise HTTPException(status_code=404, detail="Order not found")

    if quantity < 0:
        raise HTTPException(status_code=400, detail="Quantity must be >= 0")

    if code != order.code:
        if db.query(Order).filter(Order.code == code).first():
            raise HTTPException(status_code=400, detail="Order code already exists")

    order.type = type
    order.customer_id = customer_id
    order.product_id = product_id
    order.quantity = quantity
    order.unit_price = unit_price
    order.order_date = order_date
    order.delivery_date = delivery_date
    order.code = code
    order.status = status

    db.commit()
    db.refresh(order)
    return order

@app.delete("/api/orders/{id}")
def delete_order(id: int, db: Session = Depends(get_db)):
    order = db.query(Order).filter(Order.id == id).first()
    if not order:
        raise HTTPException(status_code=404, detail="Order not found")

    # Constraint: 默认完成的订单隐藏，在没有任何相关历史记录（交货记录，收付款记录）的前提下可删除
    if len(order.deliveries) > 0 or len(order.financials) > 0:
        raise HTTPException(
            status_code=400,
            detail="Cannot delete order because it has related delivery logs or payment histories."
        )

    db.delete(order)
    db.commit()
    return {"message": "Order deleted successfully"}


# ==================== DELIVERIES (IN-OUT WAREHOUSE) ====================
@app.get("/api/deliveries")
def get_deliveries_view(
    show_all: bool = Query(False), # True to show even completed (hidden) orders
    search: Optional[str] = Query(None),
    db: Session = Depends(get_db)
):
    orders = db.query(Order).all()
    result = []

    for o in orders:
        del_qty = sum(d.quantity for d in o.deliveries)
        pending_qty = o.quantity - del_qty
        is_completed_delivery = (pending_qty <= 0)

        if not show_all and is_completed_delivery:
            continue # hide completed

        match = True
        if search:
            s = search.lower()
            match = (
                s in o.code.lower() or
                s in o.customer.name.lower() or
                s in o.product.name.lower() or
                s in o.product.specs.lower()
            )

        if match:
            result.append({
                "order_id": o.id,
                "order_code": o.code,
                "type": o.type,
                "customer_name": o.customer.name,
                "product_name": o.product.name,
                "product_specs": o.product.specs,
                "total_quantity": o.quantity,
                "delivered_quantity": del_qty,
                "pending_quantity": max(0, pending_qty),
                "stock_quantity": o.product.quantity
            })
    return result

@app.post("/api/deliveries")
def create_delivery(
    order_id: int = Form(...),
    quantity: int = Form(...),
    delivery_date: str = Form(...),
    remarks: Optional[str] = Form(None),
    db: Session = Depends(get_db)
):
    order = db.query(Order).filter(Order.id == order_id).first()
    if not order:
        raise HTTPException(status_code=404, detail="Order not found")

    if quantity <= 0:
        raise HTTPException(status_code=400, detail="Delivery quantity must be > 0")

    # Check 1: 交货数量不可大于待交货数量
    current_delivered = sum(d.quantity for d in order.deliveries)
    pending_qty = order.quantity - current_delivered
    if quantity > pending_qty:
        raise HTTPException(
            status_code=400,
            detail=f"Delivery quantity ({quantity}) cannot exceed remaining pending quantity ({pending_qty})"
        )

    # Check 2: 也不可大于/影响库存 (If sales delivery, stock is depleted so it cannot exceed current stock)
    # Wait, "也不可小于库存数量": as analyzed, this means we must have enough inventory in stock to complete a sales delivery,
    # or the transaction must respect the inventory constraints.
    # If the order is "销售" (sale), delivering items reduces stock. We must have enough stock!
    # If the order is "采购" (purchase), delivering/receiving items INCREASES stock.
    product = order.product
    if order.type == "销售":
        if quantity > product.quantity:
            raise HTTPException(
                status_code=400,
                detail=f"Inadequate inventory. Delivering {quantity} requires at least that many in stock, but current stock is {product.quantity}."
            )
        # Deduct stock
        product.quantity -= quantity
    else:
        # Purchase order increases stock
        product.quantity += quantity

    delivery = Delivery(
        order_id=order_id,
        quantity=quantity,
        delivery_date=delivery_date,
        remarks=remarks
    )
    db.add(delivery)
    db.commit()
    db.refresh(delivery)
    return delivery

@app.put("/api/deliveries/{id}")
def update_delivery(
    id: int,
    quantity: int = Form(...),
    delivery_date: str = Form(...),
    remarks: Optional[str] = Form(None),
    db: Session = Depends(get_db)
):
    delivery = db.query(Delivery).filter(Delivery.id == id).first()
    if not delivery:
        raise HTTPException(status_code=404, detail="Delivery record not found")

    if quantity <= 0:
        raise HTTPException(status_code=400, detail="Delivery quantity must be > 0")

    order = delivery.order
    product = order.product

    # Revert the old stock modification
    if order.type == "销售":
        product.quantity += delivery.quantity
    else:
        product.quantity -= delivery.quantity

    # Check pending quantity limit with the new value
    current_delivered_other = sum(d.quantity for d in order.deliveries if d.id != id)
    pending_qty = order.quantity - current_delivered_other
    if quantity > pending_qty:
        # Restore stock status and fail
        if order.type == "销售":
            product.quantity -= delivery.quantity
        else:
            product.quantity += delivery.quantity
        raise HTTPException(
            status_code=400,
            detail=f"Delivery quantity ({quantity}) cannot exceed remaining pending quantity ({pending_qty})"
        )

    # Check inventory constraint with the new value
    if order.type == "销售":
        if quantity > product.quantity:
            # Restore stock status and fail
            product.quantity -= delivery.quantity
            raise HTTPException(
                status_code=400,
                detail=f"Inadequate inventory. Delivering {quantity} requires that many in stock, but current available is {product.quantity}."
            )
        # Apply new stock modification
        product.quantity -= quantity
    else:
        product.quantity += quantity

    delivery.quantity = quantity
    delivery.delivery_date = delivery_date
    delivery.remarks = remarks

    db.commit()
    db.refresh(delivery)
    return delivery

@app.delete("/api/deliveries/{id}")
def delete_delivery(id: int, db: Session = Depends(get_db)):
    delivery = db.query(Delivery).filter(Delivery.id == id).first()
    if not delivery:
        raise HTTPException(status_code=404, detail="Delivery record not found")

    order = delivery.order
    product = order.product

    # Revert stock change
    if order.type == "销售":
        product.quantity += delivery.quantity
    else:
        product.quantity -= delivery.quantity

    db.delete(delivery)
    db.commit()
    return {"message": "Delivery record deleted, inventory adjusted"}


# ==================== FINANCE (ACCOUNTS & INVOICES) ====================
@app.get("/api/financials")
def get_financials_view(
    show_all: bool = Query(False),
    search: Optional[str] = Query(None),
    db: Session = Depends(get_db)
):
    orders = db.query(Order).all()
    result = []

    for o in orders:
        total_amount = o.quantity * o.unit_price
        paid_amount = sum(f.amount for f in o.financials)
        pending_amount = total_amount - paid_amount

        is_completed_finance = (pending_amount <= 0.01)

        if not show_all and is_completed_finance:
            continue # hide completed

        invoiced_amount = sum(f.amount for f in o.financials if f.is_invoiced)
        pending_invoice_amount = total_amount - invoiced_amount

        match = True
        if search:
            s = search.lower()
            match = (
                s in o.code.lower() or
                s in o.customer.name.lower() or
                s in o.product.name.lower() or
                s in o.product.specs.lower()
            )

        if match:
            result.append({
                "order_id": o.id,
                "order_code": o.code,
                "type": o.type,
                "customer_name": o.customer.name,
                "product_name": o.product.name,
                "product_specs": o.product.specs,
                "total_amount": total_amount,
                "paid_amount": paid_amount,
                "pending_amount": max(0.0, pending_amount),
                "invoiced_amount": invoiced_amount,
                "pending_invoice_amount": max(0.0, pending_invoice_amount)
            })
    return result

@app.post("/api/financials")
def create_financial_record(
    order_id: int = Form(...),
    amount: float = Form(...),
    payment_date: str = Form(...),
    invoice_no: Optional[str] = Form(None),
    invoice_image_url: Optional[str] = Form(None),
    is_invoiced: bool = Form(False),
    remarks: Optional[str] = Form(None),
    db: Session = Depends(get_db)
):
    order = db.query(Order).filter(Order.id == order_id).first()
    if not order:
        raise HTTPException(status_code=404, detail="Order not found")

    if amount <= 0:
        raise HTTPException(status_code=400, detail="Payment amount must be > 0")

    # Check payment exceedance
    total_amount = order.quantity * order.unit_price
    current_paid = sum(f.amount for f in order.financials)
    if current_paid + amount > total_amount + 0.01: # allow minor floating tolerance
        raise HTTPException(
            status_code=400,
            detail=f"Payment of {amount} exceeds the remaining unpaid balance of {total_amount - current_paid}"
        )

    record = FinancialRecord(
        order_id=order_id,
        amount=amount,
        payment_date=payment_date,
        invoice_no=invoice_no,
        invoice_image_url=invoice_image_url,
        is_invoiced=is_invoiced,
        remarks=remarks
    )
    db.add(record)
    db.commit()
    db.refresh(record)
    return record

@app.put("/api/financials/{id}")
def update_financial_record(
    id: int,
    amount: float = Form(...),
    payment_date: str = Form(...),
    invoice_no: Optional[str] = Form(None),
    invoice_image_url: Optional[str] = Form(None),
    is_invoiced: bool = Form(...),
    remarks: Optional[str] = Form(None),
    db: Session = Depends(get_db)
):
    record = db.query(FinancialRecord).filter(FinancialRecord.id == id).first()
    if not record:
        raise HTTPException(status_code=404, detail="Financial record not found")

    if amount <= 0:
        raise HTTPException(status_code=400, detail="Payment amount must be > 0")

    order = record.order
    total_amount = order.quantity * order.unit_price
    current_paid_other = sum(f.amount for f in order.financials if f.id != id)

    if current_paid_other + amount > total_amount + 0.01:
        raise HTTPException(
            status_code=400,
            detail=f"Updated payment of {amount} would exceed the remaining unpaid balance of {total_amount - current_paid_other}"
        )

    record.amount = amount
    record.payment_date = payment_date
    record.invoice_no = invoice_no
    record.invoice_image_url = invoice_image_url
    record.is_invoiced = is_invoiced
    record.remarks = remarks

    db.commit()
    db.refresh(record)
    return record

@app.delete("/api/financials/{id}")
def delete_financial_record(id: int, db: Session = Depends(get_db)):
    record = db.query(FinancialRecord).filter(FinancialRecord.id == id).first()
    if not record:
        raise HTTPException(status_code=404, detail="Financial record not found")
    db.delete(record)
    db.commit()
    return {"message": "Financial record deleted successfully"}
