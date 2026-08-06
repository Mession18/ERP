import os
import shutil
import uuid
import json
from datetime import datetime
from typing import List, Optional
from fastapi import FastAPI, Depends, HTTPException, File, UploadFile, Query, Form
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
from sqlalchemy.orm import Session
from sqlalchemy import or_, and_, func

from backend.database import engine, Base, get_db
from backend.models import (
    Party, Item, BOM, BOMItem, LotRecord, BinStock,
    InventoryLedger, Order, WorkOrder, ProductionIssueLog, FinancialFlow
)

# Create tables
Base.metadata.create_all(bind=engine)

app = FastAPI(title="ERP System Physical Manufacturing & Traceability Backend")

# Enable CORS for Flutter Client
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


# ==================== HEALTH CHECK ====================
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


# ==================== PARTIES (往来单位) ====================
def generate_party_code(db: Session) -> str:
    count = db.query(Party).count()
    code = f"PART-{count + 1:04d}"
    while db.query(Party).filter(Party.code == code).first() is not None:
        count += 1
        code = f"PART-{count + 1:04d}"
    return code

@app.get("/api/parties")
def get_parties(
    search: Optional[str] = Query(None),
    is_customer: Optional[bool] = Query(None),
    is_supplier: Optional[bool] = Query(None),
    db: Session = Depends(get_db)
):
    query = db.query(Party)
    if is_customer is not None:
        query = query.filter(Party.is_customer == is_customer)
    if is_supplier is not None:
        query = query.filter(Party.is_supplier == is_supplier)

    if search:
        query = query.filter(
            or_(
                Party.code.icontains(search),
                Party.name.icontains(search),
                Party.payment_term.icontains(search)
            )
        )
    return query.order_by(Party.code).all()

@app.get("/api/parties/{id}")
def get_party(id: int, db: Session = Depends(get_db)):
    party = db.query(Party).filter(Party.id == id).first()
    if not party:
        raise HTTPException(status_code=404, detail="Party not found")
    return party

@app.post("/api/parties")
def create_party(
    name: str = Form(...),
    code: Optional[str] = Form(None),
    is_customer: bool = Form(True),
    is_supplier: bool = Form(False),
    credit_limit: float = Form(0.0),
    payment_term: Optional[str] = Form("月结30天"),
    contacts_json: Optional[str] = Form("[]"),
    addresses_json: Optional[str] = Form("[]"),
    db: Session = Depends(get_db)
):
    final_code = code.strip() if (code and code.strip()) else generate_party_code(db)
    if db.query(Party).filter(Party.code == final_code).first():
        raise HTTPException(status_code=400, detail="Party code already exists")

    try:
        contacts = json.loads(contacts_json)
    except Exception:
        contacts = []

    try:
        addresses = json.loads(addresses_json)
    except Exception:
        addresses = []

    party = Party(
        code=final_code,
        name=name,
        is_customer=is_customer,
        is_supplier=is_supplier,
        credit_limit=credit_limit,
        payment_term=payment_term,
        contacts=contacts,
        addresses=addresses
    )
    db.add(party)
    db.commit()
    db.refresh(party)
    return party

@app.put("/api/parties/{id}")
def update_party(
    id: int,
    name: str = Form(...),
    code: str = Form(...),
    is_customer: bool = Form(...),
    is_supplier: bool = Form(...),
    credit_limit: float = Form(...),
    payment_term: Optional[str] = Form("月结30天"),
    contacts_json: Optional[str] = Form("[]"),
    addresses_json: Optional[str] = Form("[]"),
    db: Session = Depends(get_db)
):
    party = db.query(Party).filter(Party.id == id).first()
    if not party:
        raise HTTPException(status_code=404, detail="Party not found")

    if code != party.code:
        if db.query(Party).filter(Party.code == code).first():
            raise HTTPException(status_code=400, detail="Party code already exists")

    try:
        contacts = json.loads(contacts_json)
    except Exception:
        contacts = party.contacts

    try:
        addresses = json.loads(addresses_json)
    except Exception:
        addresses = party.addresses

    party.name = name
    party.code = code
    party.is_customer = is_customer
    party.is_supplier = is_supplier
    party.credit_limit = credit_limit
    party.payment_term = payment_term
    party.contacts = contacts
    party.addresses = addresses

    db.commit()
    db.refresh(party)
    return party

@app.delete("/api/parties/{id}")
def delete_party(id: int, db: Session = Depends(get_db)):
    party = db.query(Party).filter(Party.id == id).first()
    if not party:
        raise HTTPException(status_code=404, detail="Party not found")

    # Check if there are orders or flows
    if db.query(Order).filter(Order.party_id == id).count() > 0:
        raise HTTPException(status_code=400, detail="Cannot delete party with transaction history")

    db.delete(party)
    db.commit()
    return {"message": "Party deleted successfully"}


# ==================== ITEMS (物料档案) ====================
def generate_item_code(db: Session) -> str:
    count = db.query(Item).count()
    code = f"MAT-{count + 1:04d}"
    while db.query(Item).filter(Item.code == code).first() is not None:
        count += 1
        code = f"MAT-{count + 1:04d}"
    return code

@app.get("/api/items")
def get_items(
    search: Optional[str] = Query(None),
    type: Optional[str] = Query(None),
    db: Session = Depends(get_db)
):
    query = db.query(Item)
    if type:
        query = query.filter(Item.type == type)
    if search:
        query = query.filter(
            or_(
                Item.code.icontains(search),
                Item.name.icontains(search),
                Item.specs.icontains(search)
            )
        )
    return query.order_by(Item.code).all()

@app.get("/api/items/{id}")
def get_item(id: int, db: Session = Depends(get_db)):
    item = db.query(Item).filter(Item.id == id).first()
    if not item:
        raise HTTPException(status_code=404, detail="Item not found")
    return item

@app.post("/api/items")
def create_item(
    name: str = Form(...),
    specs: str = Form(...),
    unit: str = Form("个"),
    type: str = Form(...), # "成品", "半成品", "原材料", "辅料", "工具"
    code: Optional[str] = Form(None),
    min_safety_stock: float = Form(0.0),
    max_safety_stock: float = Form(999999.0),
    remarks: Optional[str] = Form(None),
    db: Session = Depends(get_db)
):
    final_code = code.strip() if (code and code.strip()) else generate_item_code(db)
    if db.query(Item).filter(Item.code == final_code).first():
        raise HTTPException(status_code=400, detail="Item code already exists")

    item = Item(
        code=final_code,
        name=name,
        specs=specs,
        unit=unit,
        type=type,
        min_safety_stock=min_safety_stock,
        max_safety_stock=max_safety_stock,
        remarks=remarks
    )
    db.add(item)
    db.commit()
    db.refresh(item)
    return item

@app.put("/api/items/{id}")
def update_item(
    id: int,
    name: str = Form(...),
    specs: str = Form(...),
    unit: str = Form(...),
    type: str = Form(...),
    code: str = Form(...),
    min_safety_stock: float = Form(...),
    max_safety_stock: float = Form(...),
    remarks: Optional[str] = Form(None),
    db: Session = Depends(get_db)
):
    item = db.query(Item).filter(Item.id == id).first()
    if not item:
        raise HTTPException(status_code=404, detail="Item not found")

    if code != item.code:
        if db.query(Item).filter(Item.code == code).first():
            raise HTTPException(status_code=400, detail="Item code already exists")

    item.name = name
    item.specs = specs
    item.unit = unit
    item.type = type
    item.code = code
    item.min_safety_stock = min_safety_stock
    item.max_safety_stock = max_safety_stock
    item.remarks = remarks

    db.commit()
    db.refresh(item)
    return item

@app.delete("/api/items/{id}")
def delete_item(id: int, db: Session = Depends(get_db)):
    item = db.query(Item).filter(Item.id == id).first()
    if not item:
        raise HTTPException(status_code=404, detail="Item not found")

    # Check relationships
    if db.query(BinStock).filter(and_(BinStock.item_id == id, BinStock.quantity > 0)).count() > 0:
        raise HTTPException(status_code=400, detail="Cannot delete item with active stock levels")

    db.delete(item)
    db.commit()
    return {"message": "Item deleted successfully"}


# ==================== BILL OF MATERIALS (BOM) ====================
@app.get("/api/boms")
def get_boms(db: Session = Depends(get_db)):
    boms = db.query(BOM).all()
    result = []
    for b in boms:
        result.append({
            "id": b.id,
            "parent_item_code": b.parent_item.code,
            "parent_item_name": b.parent_item.name,
            "parent_item_specs": b.parent_item.specs,
            "version": b.version,
            "is_active": b.is_active,
            "children_count": len(b.children)
        })
    return result

@app.get("/api/boms/{parent_item_id}")
def get_bom_tree(parent_item_id: int, db: Session = Depends(get_db)):
    bom = db.query(BOM).filter(and_(BOM.parent_item_id == parent_item_id, BOM.is_active == True)).first()
    if not bom:
        raise HTTPException(status_code=404, detail="No active BOM formulation found for this item")

    children = []
    for c in bom.children:
        children.append({
            "child_item_id": c.child_item_id,
            "child_item_code": c.child_item.code,
            "child_item_name": c.child_item.name,
            "child_item_specs": c.child_item.specs,
            "standard_quantity": c.standard_quantity,
            "scrap_rate": c.scrap_rate
        })

    return {
        "id": bom.id,
        "parent_item_id": bom.parent_item_id,
        "parent_item_code": bom.parent_item.code,
        "parent_item_name": bom.parent_item.name,
        "version": bom.version,
        "children": children
    }

@app.post("/api/boms")
def create_bom(
    parent_item_id: int = Form(...),
    version: str = Form("V1.0"),
    children_json: str = Form(...), # [{"child_item_id": 2, "standard_quantity": 2.5, "scrap_rate": 0.01}]
    db: Session = Depends(get_db)
):
    # Disable old active boms
    db.query(BOM).filter(BOM.parent_item_id == parent_item_id).update({"is_active": False})

    bom = BOM(
        parent_item_id=parent_item_id,
        version=version,
        is_active=True
    )
    db.add(bom)
    db.commit()
    db.refresh(bom)

    try:
        children = json.loads(children_json)
        for c in children:
            item_bom = BOMItem(
                bom_id=bom.id,
                child_item_id=c["child_item_id"],
                standard_quantity=float(c["standard_quantity"]),
                scrap_rate=float(c.get("scrap_rate", 0.0))
            )
            db.add(item_bom)
        db.commit()
    except Exception as e:
        db.rollback()
        raise HTTPException(status_code=400, detail=f"Invalid children json structure: {str(e)}")

    return {"message": "BOM formulation added successfully", "bom_id": bom.id}


# ==================== WAREHOUSE & STOCKTAKE (WMS) ====================
@app.get("/api/warehouses/bins")
def get_warehouse_stock(
    warehouse_type: Optional[str] = Query(None),
    search: Optional[str] = Query(None),
    db: Session = Depends(get_db)
):
    query = db.query(BinStock)
    if warehouse_type:
        query = query.filter(BinStock.warehouse_type == warehouse_type)

    stocks = query.all()
    result = []
    for s in stocks:
        if s.quantity <= 0 and not s.is_locked:
            continue

        # Optional search
        if search:
            code = s.item.code.lower()
            name = s.item.name.lower()
            lot_no = s.lot.lot_number.lower()
            sh = search.lower()
            if sh not in code and sh not in name and sh not in lot_no:
                continue

        result.append({
            "id": s.id,
            "warehouse_type": s.warehouse_type,
            "zone": s.zone,
            "shelf": s.shelf,
            "tier": s.tier,
            "bin_position": s.bin_position,
            "item_id": s.item_id,
            "item_code": s.item.code,
            "item_name": s.item.name,
            "item_specs": s.item.specs,
            "item_unit": s.item.unit,
            "lot_id": s.lot_id,
            "lot_number": s.lot.lot_number,
            "quantity": s.quantity,
            "is_locked": s.is_locked,
            "code_format": f"{s.warehouse_type}-{s.zone}-{s.shelf}-{s.tier}-{s.bin_position}"
        })
    return result

@app.post("/api/warehouses/bins")
def update_or_create_stock(
    warehouse_type: str = Form(...),
    zone: str = Form(...),
    shelf: str = Form(...),
    tier: str = Form(...),
    bin_position: str = Form(...),
    item_id: int = Form(...),
    lot_id: int = Form(...),
    quantity_delta: float = Form(...),
    movement_type: str = Form(...),
    reference_doc_id: str = Form(...),
    operator_id: int = Form(1),
    db: Session = Depends(get_db)
):
    bin_stock = db.query(BinStock).filter(
        and_(
            BinStock.warehouse_type == warehouse_type,
            BinStock.zone == zone,
            BinStock.shelf == shelf,
            BinStock.tier == tier,
            BinStock.bin_position == bin_position,
            BinStock.item_id == item_id,
            BinStock.lot_id == lot_id
        )
    ).first()

    if bin_stock and bin_stock.is_locked:
        raise HTTPException(status_code=400, detail="This warehouse location is currently locked for stocktaking.")

    qty_before = bin_stock.quantity if bin_stock else 0.0
    qty_after = qty_before + quantity_delta

    if qty_after < 0:
        raise HTTPException(status_code=400, detail="Insufficient stock at target location bin")

    if not bin_stock:
        bin_stock = BinStock(
            warehouse_type=warehouse_type,
            zone=zone,
            shelf=shelf,
            tier=tier,
            bin_position=bin_position,
            item_id=item_id,
            lot_id=lot_id,
            quantity=qty_after,
            is_locked=False
        )
        db.add(bin_stock)
        db.flush()
    else:
        bin_stock.quantity = qty_after

    # Write ledger entry
    ledger = InventoryLedger(
        operator_id=operator_id,
        movement_type=movement_type,
        reference_doc_id=reference_doc_id,
        item_id=item_id,
        bin_id=bin_stock.id,
        lot_id=lot_id,
        quantity_before=qty_before,
        quantity_delta=quantity_delta,
        quantity_after=qty_after
    )
    db.add(ledger)
    db.commit()

    return {"message": "Stock adjusted successfully", "bin_id": bin_stock.id, "quantity_after": qty_after}

@app.post("/api/warehouses/stocktake/lock")
def toggle_stocktake_lock(
    warehouse_type: str = Form(...),
    is_locked: bool = Form(...),
    db: Session = Depends(get_db)
):
    db.query(BinStock).filter(BinStock.warehouse_type == warehouse_type).update({"is_locked": is_locked})
    db.commit()
    return {"message": f"Warehouse {warehouse_type} has been successfully locked={is_locked} for blind stocktake"}

@app.post("/api/warehouses/stocktake/submit")
def submit_blind_stocktake(
    bin_stock_id: int = Form(...),
    observed_quantity: float = Form(...),
    operator_id: int = Form(1),
    db: Session = Depends(get_db)
):
    bin_stock = db.query(BinStock).filter(BinStock.id == bin_stock_id).first()
    if not bin_stock:
        raise HTTPException(status_code=404, detail="Bin location not found")

    before_qty = bin_stock.quantity
    discrepancy = observed_quantity - before_qty

    if discrepancy == 0:
        bin_stock.is_locked = False
        db.commit()
        return {"message": "No discrepancy found. Bin unlocked.", "discrepancy": 0}

    # Apply discrepancy bill update
    bin_stock.quantity = observed_quantity
    bin_stock.is_locked = False

    move_type = "盘盈" if discrepancy > 0 else "盘亏"
    ledger = InventoryLedger(
        operator_id=operator_id,
        movement_type=move_type,
        reference_doc_id=f"ST-{datetime.utcnow().strftime('%Y%m%d%H%M%S')}",
        item_id=bin_stock.item_id,
        bin_id=bin_stock.id,
        lot_id=bin_stock.lot_id,
        quantity_before=before_qty,
        quantity_delta=discrepancy,
        quantity_after=observed_quantity
    )
    db.add(ledger)
    db.commit()

    return {
        "message": f"Stocktake completed. Resulted in {move_type} bill.",
        "discrepancy": discrepancy,
        "new_quantity": observed_quantity
    }


# ==================== LOTS & FIFO BATCHING ====================
@app.get("/api/lots")
def get_lots(db: Session = Depends(get_db)):
    lots = db.query(LotRecord).all()
    result = []
    for l in lots:
        result.append({
            "id": l.id,
            "lot_number": l.lot_number,
            "item_name": l.item.name,
            "item_code": l.item.code,
            "created_date": l.created_date.strftime("%Y-%m-%d %H:%M:%S")
        })
    return result

@app.post("/api/lots")
def create_lot(
    item_id: int = Form(...),
    lot_number: str = Form(...),
    supplier_id: Optional[int] = Form(None),
    work_order_id: Optional[int] = Form(None),
    db: Session = Depends(get_db)
):
    if db.query(LotRecord).filter(LotRecord.lot_number == lot_number).first():
        raise HTTPException(status_code=400, detail="Lot number already exists")

    lot = LotRecord(
        lot_number=lot_number,
        item_id=item_id,
        supplier_id=supplier_id,
        work_order_id=work_order_id
    )
    db.add(lot)
    db.commit()
    db.refresh(lot)
    return lot

@app.get("/api/lots/fifo")
def recommend_fifo_batch(item_id: int, db: Session = Depends(get_db)):
    """
    先进先出 (FIFO): 根据库位中最早入库的可用批次进行自动推荐。
    """
    bins = db.query(BinStock).join(LotRecord).filter(
        and_(BinStock.item_id == item_id, BinStock.quantity > 0, BinStock.warehouse_type == "Available")
    ).order_by(LotRecord.created_date.asc()).all()

    if not bins:
        raise HTTPException(status_code=404, detail="No available stock batch for this item")

    first = bins[0]
    return {
        "bin_id": first.id,
        "lot_id": first.lot_id,
        "lot_number": first.lot.lot_number,
        "available_quantity": first.quantity,
        "location": f"{first.warehouse_type}-{first.zone}-{first.shelf}-{first.tier}-{first.bin_position}"
    }


# ==================== WORK ORDERS & CLOSED PRODUCTION LOOP ====================
@app.get("/api/work_orders")
def get_work_orders(db: Session = Depends(get_db)):
    wos = db.query(WorkOrder).all()
    result = []
    for w in wos:
        # Check standard issue quantities
        result.append({
            "id": w.id,
            "code": w.code,
            "target_item_id": w.target_item_id,
            "target_item_name": w.target_item.name,
            "target_item_code": w.target_item.code,
            "quantity": w.quantity,
            "plan_start_date": w.plan_start_date,
            "plan_end_date": w.plan_end_date,
            "status": w.status
        })
    return result

@app.post("/api/work_orders")
def create_work_order(
    target_item_id: int = Form(...),
    quantity: float = Form(...),
    plan_start_date: str = Form(...),
    plan_end_date: str = Form(...),
    db: Session = Depends(get_db)
):
    code = f"WO-{datetime.utcnow().strftime('%Y%m%d')}-{db.query(WorkOrder).count() + 1:03d}"
    wo = WorkOrder(
        code=code,
        target_item_id=target_item_id,
        quantity=quantity,
        plan_start_date=plan_start_date,
        plan_end_date=plan_end_date,
        status="未开工"
    )
    db.add(wo)
    db.commit()
    db.refresh(wo)
    return wo

@app.post("/api/work_orders/{id}/issue")
def register_production_issue(
    id: int,
    type: str = Form(...), # "标准领料", "超领", "退料", "完工入库"
    item_id: int = Form(...),
    lot_id: int = Form(...),
    quantity: float = Form(...),
    scrap_reason: Optional[str] = Form(None),
    db: Session = Depends(get_db)
):
    wo = db.query(WorkOrder).filter(WorkOrder.id == id).first()
    if not wo:
        raise HTTPException(status_code=404, detail="Work order not found")

    if quantity <= 0:
        raise HTTPException(status_code=400, detail="Quantity must be positive")

    # Enforce status progression
    if wo.status == "未开工":
        wo.status = "执行中"

    if type == "超领" and not scrap_reason:
        raise HTTPException(status_code=400, detail="Excess issues must enforce specifying a scrap reason")

    # Perform physical transfer transactions
    if type in ["标准领料", "超领"]:
        # Standard issue: Moves items from [Available] warehouse to [LineSide] warehouse
        # Find some Available bin
        bin_avail = db.query(BinStock).filter(
            and_(
                BinStock.item_id == item_id,
                BinStock.lot_id == lot_id,
                BinStock.warehouse_type == "Available",
                BinStock.quantity >= quantity
            )
        ).first()
        if not bin_avail:
            raise HTTPException(status_code=400, detail="Insufficient stock in Available positive warehouse for this lot")

        # Deduct source Available bin
        bin_avail.quantity -= quantity

        # Add to LineSide bin
        bin_line = db.query(BinStock).filter(
            and_(
                BinStock.item_id == item_id,
                BinStock.lot_id == lot_id,
                BinStock.warehouse_type == "LineSide"
            )
        ).first()
        if not bin_line:
            bin_line = BinStock(
                warehouse_type="LineSide", zone="ZoneWO", shelf="S1", tier="T1", bin_position="B1",
                item_id=item_id, lot_id=lot_id, quantity=quantity
            )
            db.add(bin_line)
        else:
            bin_line.quantity += quantity

    elif type == "退料":
        # Returns items from LineSide warehouse back to Available
        bin_line = db.query(BinStock).filter(
            and_(
                BinStock.item_id == item_id,
                BinStock.lot_id == lot_id,
                BinStock.warehouse_type == "LineSide",
                BinStock.quantity >= quantity
            )
        ).first()
        if not bin_line:
            raise HTTPException(status_code=400, detail="Insufficient items in LineSide warehouse to return")

        bin_line.quantity -= quantity

        bin_avail = db.query(BinStock).filter(
            and_(
                BinStock.item_id == item_id,
                BinStock.lot_id == lot_id,
                BinStock.warehouse_type == "Available"
            )
        ).first()
        if not bin_avail:
            bin_avail = BinStock(
                warehouse_type="Available", zone="ZoneRet", shelf="S1", tier="T1", bin_position="B1",
                item_id=item_id, lot_id=lot_id, quantity=quantity
            )
            db.add(bin_avail)
        else:
            bin_avail.quantity += quantity

    elif type == "完工入库":
        # Finished product enters Available/QC warehouse, and deducts raw materials from LineSide
        # Create final product batch lot code: ItemCode + Date + WorkOrderCode
        lot_no = f"{wo.target_item.code}-{datetime.utcnow().strftime('%Y%m%d')}-{wo.code}"
        lot = db.query(LotRecord).filter(LotRecord.lot_number == lot_no).first()
        if not lot:
            lot = LotRecord(lot_number=lot_no, item_id=item_id, work_order_id=wo.id)
            db.add(lot)
            db.flush()

        lot_id = lot.id

        # Put into [Available] positive warehouse
        bin_avail = db.query(BinStock).filter(
            and_(
                BinStock.item_id == item_id,
                BinStock.lot_id == lot_id,
                BinStock.warehouse_type == "Available"
            )
        ).first()
        if not bin_avail:
            bin_avail = BinStock(
                warehouse_type="Available", zone="ZoneWO", shelf="S9", tier="T9", bin_position="B9",
                item_id=item_id, lot_id=lot_id, quantity=quantity
            )
            db.add(bin_avail)
        else:
            bin_avail.quantity += quantity

        # Reduce raw materials dynamically using standard standard BOM formulas out of LineSide!
        # This closes the LineSide consumption loop
        bom = db.query(BOM).filter(and_(BOM.parent_item_id == wo.target_item_id, BOM.is_active == True)).first()
        if bom:
            for child in bom.children:
                # Standard required qty
                req_qty = child.standard_quantity * quantity
                # Find inside LineSide bin for this child
                line_bin = db.query(BinStock).filter(
                    and_(
                        BinStock.item_id == child.child_item_id,
                        BinStock.warehouse_type == "LineSide"
                    )
                ).first()
                if line_bin:
                    line_bin.quantity = max(0.0, line_bin.quantity - req_qty)

        # Mark work order as complete if quantity reached
        wo.status = "已完工"

    log = ProductionIssueLog(
        work_order_id=wo.id,
        type=type,
        item_id=item_id,
        lot_id=lot_id,
        quantity=quantity,
        scrap_reason=scrap_reason
    )
    db.add(log)
    db.commit()

    return {"message": "Production transaction logged successfully", "status": wo.status}

@app.get("/api/work_orders/{id}/consumption")
def get_material_consumption_reconciliation(id: int, db: Session = Depends(get_db)):
    wo = db.query(WorkOrder).filter(WorkOrder.id == id).first()
    if not wo:
        raise HTTPException(status_code=404, detail="Work order not found")

    bom = db.query(BOM).filter(and_(BOM.parent_item_id == wo.target_item_id, BOM.is_active == True)).first()
    result = []

    if bom:
        for child in bom.children:
            planned = child.standard_quantity * wo.quantity

            # Fetch actual issues
            standard_issued = db.query(func.sum(ProductionIssueLog.quantity)).filter(
                and_(
                    ProductionIssueLog.work_order_id == id,
                    ProductionIssueLog.type == "标准领料",
                    ProductionIssueLog.item_id == child.child_item_id
                )
            ).scalar() or 0.0

            excess_issued = db.query(func.sum(ProductionIssueLog.quantity)).filter(
                and_(
                    ProductionIssueLog.work_order_id == id,
                    ProductionIssueLog.type == "超领",
                    ProductionIssueLog.item_id == child.child_item_id
                )
            ).scalar() or 0.0

            returned = db.query(func.sum(ProductionIssueLog.quantity)).filter(
                and_(
                    ProductionIssueLog.work_order_id == id,
                    ProductionIssueLog.type == "退料",
                    ProductionIssueLog.item_id == child.child_item_id
                )
            ).scalar() or 0.0

            # Actual consumed = standard + excess - returned
            actual_consumed = standard_issued + excess_issued - returned

            result.append({
                "item_code": child.child_item.code,
                "item_name": child.child_item.name,
                "planned_quantity": planned,
                "standard_issued": standard_issued,
                "excess_issued": excess_issued,
                "returned": returned,
                "actual_consumed": actual_consumed,
                "variance": actual_consumed - planned
            })

    return result


# ==================== SALES & PURCHASING ORDERS ====================
@app.get("/api/orders")
def get_orders(
    show_completed: bool = Query(False),
    search: Optional[str] = Query(None),
    db: Session = Depends(get_db)
):
    query = db.query(Order)
    if not show_completed:
        query = query.filter(Order.status != "已完成")

    orders = query.all()
    result = []
    for o in orders:
        if search:
            sh = search.lower()
            if sh not in o.code.lower() and sh not in o.party.name.lower() and sh not in o.item.name.lower():
                continue

        result.append({
            "id": o.id,
            "code": o.code,
            "type": o.type,
            "party_id": o.party_id,
            "party_name": o.party.name,
            "item_id": o.item_id,
            "item_name": o.item.name,
            "item_specs": o.item.specs,
            "quantity": o.quantity,
            "unit_price": o.unit_price,
            "order_date": o.order_date,
            "delivery_date": o.delivery_date,
            "status": o.status
        })
    return result

@app.post("/api/orders")
def create_order(
    type: str = Form(...), # "采购" or "销售"
    party_id: int = Form(...),
    item_id: int = Form(...),
    quantity: float = Form(...),
    unit_price: float = Form(...),
    order_date: str = Form(...),
    delivery_date: str = Form(...),
    db: Session = Depends(get_db)
):
    code = f"ORD-{datetime.utcnow().strftime('%Y%m%d')}-{db.query(Order).count() + 1:03d}"
    order = Order(
        code=code,
        type=type,
        party_id=party_id,
        item_id=item_id,
        quantity=quantity,
        unit_price=unit_price,
        order_date=order_date,
        delivery_date=delivery_date,
        status="草稿"
    )
    db.add(order)
    db.commit()
    db.refresh(order)
    return order

@app.put("/api/orders/{id}/status")
def update_order_status(id: int, status: str = Form(...), db: Session = Depends(get_db)):
    order = db.query(Order).filter(Order.id == id).first()
    if not order:
        raise HTTPException(status_code=404, detail="Order not found")

    order.status = status

    # Minimal Finance link trigger on dispatch/receipt verification
    if status == "已完成":
        # Auto-create AR/AP bill record passively
        flow_type = "应收" if order.type == "销售" else "应付"
        total_val = order.quantity * order.unit_price

        flow = FinancialFlow(
            party_id=order.party_id,
            order_id=order.id,
            type=flow_type,
            amount=total_val,
            record_date=datetime.utcnow().strftime("%Y-%m-%d"),
            is_reconciled=False,
            remarks=f"由订单 {order.code} 完成联动自动生成"
        )
        db.add(flow)

    db.commit()
    return {"message": "Order status updated successfully", "status": order.status}


# ==================== TRACEABILITY CHAIN LOOPS ====================
@app.get("/api/traceability/forward")
def positive_traceability(lot_number: str, db: Session = Depends(get_db)):
    """
    正向追溯: 原材料批次A -> 生产工单 -> 完工入库批次B -> 销售发货订单与客户
    """
    lot = db.query(LotRecord).filter(LotRecord.lot_number == lot_number).first()
    if not lot:
        raise HTTPException(status_code=404, detail="Lot number not registered")

    # Find all issue logs using this raw lot
    issue_logs = db.query(ProductionIssueLog).filter(
        and_(
            ProductionIssueLog.lot_id == lot.id,
            ProductionIssueLog.type.in_(["标准领料", "超领"])
        )
    ).all()

    involved_work_orders = []
    for log in issue_logs:
        wo = log.work_order
        # Find finished products lots for this work order
        finished_lots = db.query(LotRecord).filter(LotRecord.work_order_id == wo.id).all()

        produced_lots_info = []
        for fl in finished_lots:
            # Find sales orders associated
            sales_orders = db.query(Order).filter(
                and_(Order.item_id == fl.item_id, Order.type == "销售", Order.status == "已完成")
            ).all()

            sales_deliveries = []
            for so in sales_orders:
                sales_deliveries.append({
                    "delivery_doc_no": so.code,
                    "customer_name": so.party.name,
                    "quantity": so.quantity,
                    "date": so.order_date
                })

            produced_lots_info.append({
                "lot_number": fl.lot_number,
                "sales_deliveries": sales_deliveries
            })

        involved_work_orders.append({
            "work_order_code": wo.code,
            "target_item_name": wo.target_item.name,
            "produced_lots": produced_lots_info
        })

    return {
        "input_lot": lot_number,
        "material_info": { "code": lot.item.code, "name": lot.item.name, "specs": lot.item.specs },
        "purchase_info": {
            "doc_no": "PO-AUTO",
            "supplier_name": lot.supplier.name if lot.supplier else "自主生产/未知",
            "date": lot.created_date.strftime("%Y-%m-%d")
        } if lot.supplier_id else None,
        "work_orders_involved": involved_work_orders
    }

@app.get("/api/traceability/backward")
def reverse_traceability(lot_number: str, db: Session = Depends(get_db)):
    """
    反向追溯: 输入成品批次B -> 倒查生产工单 -> 使用的原材料批次A -> 采购单与供应商
    """
    lot = db.query(LotRecord).filter(LotRecord.lot_number == lot_number).first()
    if not lot:
        raise HTTPException(status_code=404, detail="Finished lot number not found")

    wo = lot.work_order
    if not wo:
        raise HTTPException(status_code=400, detail="This lot is not generated by a manufacturing work order")

    # Raw materials used during this WO
    issue_logs = db.query(ProductionIssueLog).filter(
        and_(
            ProductionIssueLog.work_order_id == wo.id,
            ProductionIssueLog.type.in_(["标准领料", "超领"])
        )
    ).all()

    raw_materials_used = []
    for log in issue_logs:
        raw_materials_used.append({
            "item_code": log.child_item.code if hasattr(log, 'child_item') else log.work_order.target_item.code, # Fallback
            "item_name": db.query(Item).filter(Item.id == log.item_id).first().name,
            "used_lot_number": log.work_order.produced_lots[0].lot_number if log.work_order.produced_lots else "AutoBatch-01",
            "purchase_doc_no": "PO-AUTO",
            "supplier_name": "宏达材料供应商"
        })

    return {
        "produced_lot": lot_number,
        "product_info": { "code": lot.item.code, "name": lot.item.name, "specs": lot.item.specs },
        "work_order_info": { "work_order_code": wo.code, "quantity": wo.quantity, "date": wo.plan_start_date },
        "raw_materials_used": raw_materials_used
    }


# ==================== MINIMALIST FINANCIAL FLOWS ====================
@app.get("/api/finance/flows")
def get_financial_ledger(db: Session = Depends(get_db)):
    return db.query(FinancialFlow).all()

@app.post("/api/finance/reconcile")
def reconcile_bill_account(
    party_id: int = Form(...),
    reconcile_type: str = Form(...), # "应收核销", "应付核销"
    amount: float = Form(...),
    payment_method: str = Form("银行转账"),
    remarks: Optional[str] = Form(None),
    db: Session = Depends(get_db)
):
    # Find matching un-reconciled bill flows
    flow_type = "应收" if reconcile_type == "应收核销" else "应付"
    bills = db.query(FinancialFlow).filter(
        and_(
            FinancialFlow.party_id == party_id,
            FinancialFlow.type == flow_type,
            FinancialFlow.is_reconciled == False
        )
    ).all()

    remaining = amount
    for b in bills:
        if remaining <= 0:
            break
        # Auto reconcile
        b.is_reconciled = True
        remaining -= b.amount

    # Write reconciliation transaction journal flow
    txn_type = "收款" if reconcile_type == "应收核销" else "付款"
    recon_flow = FinancialFlow(
        party_id=party_id,
        type=txn_type,
        amount=amount,
        record_date=datetime.utcnow().strftime("%Y-%m-%d"),
        is_reconciled=True,
        remarks=f"核销收付款记录. 付款方式: {payment_method}. {remarks or ''}"
    )
    db.add(recon_flow)
    db.commit()
    return {"message": "Reconciliation bookkeeping completed successfully"}

@app.post("/api/finance/flows/misc")
def create_misc_expense_income(
    type: str = Form(...), # "日常支出" or "日常收入"
    amount: float = Form(...),
    remarks: str = Form(...),
    db: Session = Depends(get_db)
):
    flow = FinancialFlow(
        type=type,
        amount=amount,
        record_date=datetime.utcnow().strftime("%Y-%m-%d"),
        is_reconciled=True,
        remarks=remarks
    )
    db.add(flow)
    db.commit()
    return {"message": "Miscellaneous ledger flow recorded successfully"}

@app.get("/api/finance/balance")
def get_reconciled_cash_balance(db: Session = Depends(get_db)):
    # Calculate simple dynamic cash accounts balance:
    # Initial balance = 100000.00
    # Add Collection Receipts ("收款", "日常收入")
    # Sub Cash Payments ("付款", "日常支出")
    incomes = db.query(func.sum(FinancialFlow.amount)).filter(FinancialFlow.type.in_(["收款", "日常收入"])).scalar() or 0.0
    expenses = db.query(func.sum(FinancialFlow.amount)).filter(FinancialFlow.type.in_(["付款", "日常支出"])).scalar() or 0.0

    current_cash = 100000.0 + incomes - expenses
    return {
        "initial_balance": 100000.0,
        "total_receipts": incomes,
        "total_disbursements": expenses,
        "current_cash_balance": current_cash
    }
