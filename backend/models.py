from sqlalchemy import Column, Integer, String, Float, Boolean, ForeignKey, JSON, Text, DateTime
from sqlalchemy.orm import relationship
from datetime import datetime
from backend.database import Base

class Party(Base):
    """
    往来单位 (Parties): 统一存储客商信息，支持客户与供应商双重身份。
    """
    __tablename__ = "parties"

    id = Column(Integer, primary_key=True, index=True)
    code = Column(String, unique=True, index=True, nullable=False)
    name = Column(String, nullable=False)
    is_customer = Column(Boolean, default=True, nullable=False)
    is_supplier = Column(Boolean, default=False, nullable=False)
    credit_limit = Column(Float, default=0.0, nullable=False)
    payment_term = Column(String, default="月结30天", nullable=True)
    contacts = Column(JSON, default=list, nullable=True)   # [{"name": "张三", "phone": "138..", "role": "采购"}]
    addresses = Column(JSON, default=list, nullable=True)  # [{"address": "A厂区", "type": "收货"}]

    orders = relationship("Order", back_populates="party")
    lot_records = relationship("LotRecord", back_populates="supplier")
    financial_flows = relationship("FinancialFlow", back_populates="party")


class Item(Base):
    """
    物料/商品档案 (Items/Materials): 区分成品、半成品、原材料、辅料、工具。
    """
    __tablename__ = "items"

    id = Column(Integer, primary_key=True, index=True)
    code = Column(String, unique=True, index=True, nullable=False)
    name = Column(String, nullable=False)
    specs = Column(String, nullable=False)
    unit = Column(String, default="个", nullable=False)
    type = Column(String, nullable=False) # "成品", "半成品", "原材料", "辅料", "工具"
    min_safety_stock = Column(Float, default=0.0, nullable=False)
    max_safety_stock = Column(Float, default=999999.0, nullable=False)
    remarks = Column(Text, nullable=True)

    # Relationships
    boms_as_parent = relationship("BOM", back_populates="parent_item")
    bom_items_as_child = relationship("BOMItem", back_populates="child_item")
    bin_stocks = relationship("BinStock", back_populates="item")
    lot_records = relationship("LotRecord", back_populates="item")
    ledger_entries = relationship("InventoryLedger", back_populates="item")
    orders = relationship("Order", back_populates="item")


class BOM(Base):
    """
    物料清单 BOM (Bill of Materials) 头部
    """
    __tablename__ = "boms"

    id = Column(Integer, primary_key=True, index=True)
    parent_item_id = Column(Integer, ForeignKey("items.id"), nullable=False)
    version = Column(String, default="V1.0", nullable=False)
    is_active = Column(Boolean, default=True, nullable=False)

    parent_item = relationship("Item", back_populates="boms_as_parent")
    children = relationship("BOMItem", back_populates="bom", cascade="all, delete-orphan")


class BOMItem(Base):
    """
    BOM 子表明细
    """
    __tablename__ = "bom_items"

    id = Column(Integer, primary_key=True, index=True)
    bom_id = Column(Integer, ForeignKey("boms.id"), nullable=False)
    child_item_id = Column(Integer, ForeignKey("items.id"), nullable=False)
    standard_quantity = Column(Float, nullable=False)  # 生产1单位父件所需的子件标准数量
    scrap_rate = Column(Float, default=0.0, nullable=False)  # 预期损耗率 (如 0.02)

    bom = relationship("BOM", back_populates="children")
    child_item = relationship("Item", back_populates="bom_items_as_child")


class LotRecord(Base):
    """
    批次管理与追踪 (Lot Control)
    """
    __tablename__ = "lot_records"

    id = Column(Integer, primary_key=True, index=True)
    lot_number = Column(String, unique=True, index=True, nullable=False)
    item_id = Column(Integer, ForeignKey("items.id"), nullable=False)
    created_date = Column(DateTime, default=datetime.utcnow, nullable=False)

    # 批次来源
    supplier_id = Column(Integer, ForeignKey("parties.id"), nullable=True)
    work_order_id = Column(Integer, ForeignKey("work_orders.id"), nullable=True)

    item = relationship("Item", back_populates="lot_records")
    supplier = relationship("Party", back_populates="lot_records")
    work_order = relationship("WorkOrder", back_populates="produced_lots")
    bin_stocks = relationship("BinStock", back_populates="lot")
    ledger_entries = relationship("InventoryLedger", back_populates="lot")


class BinStock(Base):
    """
    三维库位库存实物表: 精确到具体库位、特定批次、特定物料的库存。
    库位编码格式: 仓库ID - 区域 - 货架 - 层 - 位
    """
    __tablename__ = "bins_stocks"

    id = Column(Integer, primary_key=True, index=True)
    warehouse_type = Column(String, nullable=False) # "QC" (待检), "Available" (正品), "Scrap" (废品), "LineSide" (线边)
    zone = Column(String, nullable=False)      # 区域 (Zone)
    shelf = Column(String, nullable=False)     # 货架 (Shelf)
    tier = Column(String, nullable=False)      # 层 (Tier)
    bin_position = Column(String, nullable=False) # 位 (Bin)

    item_id = Column(Integer, ForeignKey("items.id"), nullable=False)
    lot_id = Column(Integer, ForeignKey("lot_records.id"), nullable=False)
    quantity = Column(Float, default=0.0, nullable=False)
    is_locked = Column(Boolean, default=False, nullable=False) # 盘点锁仓标志

    item = relationship("Item", back_populates="bin_stocks")
    lot = relationship("LotRecord", back_populates="bin_stocks")
    ledger_entries = relationship("InventoryLedger", back_populates="bin")


class InventoryLedger(Base):
    """
    库存台账收发存流水表: 记录每一次库存变动的历史镜像
    """
    __tablename__ = "inventory_ledger"

    id = Column(Integer, primary_key=True, index=True)
    created_at = Column(DateTime, default=datetime.utcnow, nullable=False)
    operator_id = Column(Integer, default=1, nullable=False) # 操作人ID
    movement_type = Column(String, nullable=False) # "采购入库", "生产领料", "超领", "生产退料", "完工入库", "销售出库", "盘盈", "盘亏"
    reference_doc_id = Column(String, nullable=False) # 关联单据ID或单号

    item_id = Column(Integer, ForeignKey("items.id"), nullable=False)
    bin_id = Column(Integer, ForeignKey("bins_stocks.id"), nullable=False)
    lot_id = Column(Integer, ForeignKey("lot_records.id"), nullable=False)

    quantity_before = Column(Float, nullable=False)
    quantity_delta = Column(Float, nullable=False) # 变动数量
    quantity_after = Column(Float, nullable=False)

    item = relationship("Item", back_populates="ledger_entries")
    bin = relationship("BinStock", back_populates="ledger_entries")
    lot = relationship("LotRecord", back_populates="ledger_entries")


class Order(Base):
    """
    销售与采购订单: 统一状态机 draft -> approved -> executing -> partially_fulfilled -> completed -> closed
    """
    __tablename__ = "orders"

    id = Column(Integer, primary_key=True, index=True)
    code = Column(String, unique=True, index=True, nullable=False)
    type = Column(String, nullable=False) # "采购" or "销售"
    party_id = Column(Integer, ForeignKey("parties.id"), nullable=False)
    item_id = Column(Integer, ForeignKey("items.id"), nullable=False)
    quantity = Column(Float, nullable=False)
    unit_price = Column(Float, nullable=False)
    order_date = Column(String, nullable=False)
    delivery_date = Column(String, nullable=False)
    status = Column(String, default="草稿", nullable=False) # "草稿", "待审批", "执行中", "部分履约", "已完成", "已关闭"

    party = relationship("Party", back_populates="orders")
    item = relationship("Item", back_populates="orders")
    financial_flows = relationship("FinancialFlow", back_populates="order")


class WorkOrder(Base):
    """
    生产工单 (Work Orders)
    """
    __tablename__ = "work_orders"

    id = Column(Integer, primary_key=True, index=True)
    code = Column(String, unique=True, index=True, nullable=False)
    target_item_id = Column(Integer, ForeignKey("items.id"), nullable=False)
    quantity = Column(Float, nullable=False)
    plan_start_date = Column(String, nullable=False)
    plan_end_date = Column(String, nullable=False)
    status = Column(String, default="未开工", nullable=False) # "未开工", "执行中", "已完工", "已关闭"

    target_item = relationship("Item")
    produced_lots = relationship("LotRecord", back_populates="work_order")
    issue_logs = relationship("ProductionIssueLog", back_populates="work_order")


class ProductionIssueLog(Base):
    """
    标准领料、超领、退料、完工单据
    """
    __tablename__ = "production_issue_logs"

    id = Column(Integer, primary_key=True, index=True)
    work_order_id = Column(Integer, ForeignKey("work_orders.id"), nullable=False)
    type = Column(String, nullable=False) # "标准领料", "超领", "退料", "完工入库"
    item_id = Column(Integer, ForeignKey("items.id"), nullable=False)
    lot_id = Column(Integer, ForeignKey("lot_records.id"), nullable=False)
    quantity = Column(Float, nullable=False)
    operation_date = Column(DateTime, default=datetime.utcnow, nullable=False)
    scrap_reason = Column(String, nullable=True) # 超领强制填写的报废原因
    operator_id = Column(Integer, default=1, nullable=False)

    work_order = relationship("WorkOrder", back_populates="issue_logs")


class FinancialFlow(Base):
    """
    极简财务往来与资金流水: 自动生成应收、应付账款并进行核销
    """
    __tablename__ = "financial_flows"

    id = Column(Integer, primary_key=True, index=True)
    party_id = Column(Integer, ForeignKey("parties.id"), nullable=True)
    order_id = Column(Integer, ForeignKey("orders.id"), nullable=True)
    type = Column(String, nullable=False) # "应收", "应付", "收款", "付款", "日常支出", "日常收入"
    amount = Column(Float, nullable=False)
    record_date = Column(String, nullable=False) # Format: YYYY-MM-DD
    invoice_no = Column(String, nullable=True)
    invoice_image_url = Column(String, nullable=True)
    is_reconciled = Column(Boolean, default=False, nullable=False) # 是否已核销完毕
    remarks = Column(Text, nullable=True)

    party = relationship("Party", back_populates="financial_flows")
    order = relationship("Order", back_populates="financial_flows")
