from sqlalchemy import Column, Integer, String, Float, Boolean, ForeignKey, JSON, Text
from sqlalchemy.orm import relationship
from backend.database import Base

class Product(Base):
    __tablename__ = "products"

    id = Column(Integer, primary_key=True, index=True)
    code = Column(String, unique=True, index=True, nullable=False)
    name = Column(String, nullable=False)
    specs = Column(String, nullable=False)
    quantity = Column(Integer, default=0, nullable=False)
    image_url = Column(String, nullable=True)
    remarks = Column(String, nullable=True)
    design_images = Column(JSON, default=list, nullable=True) # list of objects/urls
    process_info = Column(Text, nullable=True)
    status = Column(String, default="上架", nullable=False) # "上架" or "下架"

    orders = relationship("Order", back_populates="product")

class Customer(Base):
    __tablename__ = "customers"

    id = Column(Integer, primary_key=True, index=True)
    code = Column(String, unique=True, index=True, nullable=False)
    type = Column(String, nullable=False) # "买家" or "卖家"
    name = Column(String, nullable=False)
    contact_person = Column(String, nullable=True)
    contact_phone = Column(String, nullable=True)
    address = Column(String, nullable=True)
    logo_url = Column(String, nullable=True)

    orders = relationship("Order", back_populates="customer")

class Order(Base):
    __tablename__ = "orders"

    id = Column(Integer, primary_key=True, index=True)
    code = Column(String, unique=True, index=True, nullable=False)
    type = Column(String, nullable=False) # "采购" or "销售"
    customer_id = Column(Integer, ForeignKey("customers.id"), nullable=False)
    product_id = Column(Integer, ForeignKey("products.id"), nullable=False)
    quantity = Column(Integer, nullable=False)
    unit_price = Column(Float, nullable=False)
    order_date = Column(String, nullable=False) # Format: YYYY-MM-DD
    delivery_date = Column(String, nullable=False) # Format: YYYY-MM-DD
    status = Column(String, default="进行中", nullable=False) # "进行中" or "已完成"

    product = relationship("Product", back_populates="orders")
    customer = relationship("Customer", back_populates="orders")
    deliveries = relationship("Delivery", back_populates="order", cascade="all, delete-orphan")
    financials = relationship("FinancialRecord", back_populates="order", cascade="all, delete-orphan")

class Delivery(Base):
    __tablename__ = "deliveries"

    id = Column(Integer, primary_key=True, index=True)
    order_id = Column(Integer, ForeignKey("orders.id"), nullable=False)
    quantity = Column(Integer, nullable=False)
    delivery_date = Column(String, nullable=False) # Format: YYYY-MM-DD (or Date)
    remarks = Column(String, nullable=True)

    order = relationship("Order", back_populates="deliveries")

class FinancialRecord(Base):
    __tablename__ = "financial_records"

    id = Column(Integer, primary_key=True, index=True)
    order_id = Column(Integer, ForeignKey("orders.id"), nullable=False)
    amount = Column(Float, nullable=False)
    payment_date = Column(String, nullable=False) # Format: YYYY-MM-DD
    invoice_no = Column(String, nullable=True)
    invoice_image_url = Column(String, nullable=True)
    is_invoiced = Column(Boolean, default=False, nullable=False)
    remarks = Column(String, nullable=True)

    order = relationship("Order", back_populates="financials")
