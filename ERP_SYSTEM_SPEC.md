# 实物精细化制造与进销存 ERP 系统设计与开发规约 (ERP System Specification)

本规约旨在为“以实物精细化管理为核心”的 ERP 系统提供完备的技术方案，涵盖项目启动指南、数据库模型设计、核心业务流（生产物料闭环、批次全链路追溯、出入库联动极简财务）的 API 与架构设计，以及推荐的技术栈方案。

---

## 一、 系统部署与启动指南 (Deployment & Startup)

### 1. 启动后端 (Python FastAPI)
后端存放于 `backend/` 目录下，使用 FastAPI 提供 RESTful API 接口，并采用 SQLAlchemy 作为 ORM 框架连接本地 PostgreSQL 数据库。

#### 前置要求：
* 安装 Python 3.10+
* 运行中的 PostgreSQL 实例（已配置数据库名 `postgres`，用户 `postgres`，密码 `23711375`，地址 `localhost:5432`）

#### 启动步骤（Linux/MacOS/Bash）：
```bash
# 进入项目根目录并安装依赖
pip install -r backend/requirements.txt   # 如果有 requirements.txt
# 或者直接安装核心依赖：
pip install fastapi uvicorn sqlalchemy psycopg2-binary pydantic

# 启动 Uvicorn 后端服务器（监听 8000 端口）
uvicorn backend.main:app --host 0.0.0.0 --port 8000 --reload
```

---

### 2. 启动前端 (Flutter Web/Desktop)
前端使用 Flutter 实现现代化、高响应性的单页应用，兼容手机、平板与桌面视图，预置了免登首页、可调节左右分割面板及 Excel 样式的固定表头可调节表格。

#### 启动步骤：
```bash
# 获取 Flutter 依赖
flutter pub get

# 本地调试运行（在 Chrome 中启动 Web 实例）
flutter run -d chrome --web-port 3000

# 编译 Web 静态资源
flutter build web
```

---

### 3. PowerShell 一键智能连通性检测与启动脚本
为了解决“前端无法直观感知是否成功连上后端、或后端是否连上 PostgreSQL”的问题，我们提供了一个专用的 **PowerShell 启动诊断脚本 (`run_app.ps1`)**。该脚本在 Windows 下直接双击或通过 PowerShell 终端运行，启动前端前会进行多级健康检查，并在遇到断联时输出显式错误提示与排查指南：

#### 诊断机制与代码：
脚本文件 `run_app.ps1` 已经放置于项目根目录下。它的关键流程如下：
1. **第一级：检测 8000 后端端口**。通过建立 TCP 连接，判断 FastAPI 进程是否已在本地启动并监听该端口。
2. **第二级：调用 API 健康检查接口**。发起 HTTP 请求至 `http://localhost:8000/api`。
3. **第三级：数据库连接诊断**。FastAPI 响应中会同时承载其自身的数据库连通性状态。若数据库断联，前端将给出红色的“数据库未就绪”高亮提示。
4. **报错反馈**：如果任何检测失败，脚本会暂停并输出详尽的命令行建议（如：检查 PG 实例服务是否开启、密码是否正确等），引导用户一步步解决。

---

## 二、 系统数据模型设计 (Relational Database Schema)

以下是针对“实物精细化管理”设计的完整实体关联关系与表结构设计。所有主键均采用自增 `INT/BIGINT` 或者是包含高区分度的业务自增编码。

```
                               +------------------+
                               |    BOM_Items     | <-------------------------+
                               +------------------+                           |
                                        | (BOM子件)                           |
                                        v                                     |
+------------------+           +------------------+                  +------------------+
|     Parties      | <-------- |      Items       | <--------------- |    Work_Orders   |
| (往来单位/客商)  |           | (物料/商品档案)  |                  |    (生产工单)    |
+------------------+           +------------------+                  +------------------+
         |                              ^                                     |
         |                              | (批次物料)                           |
         |                              |                                     |
         |                     +------------------+                           |
         | (关联客商)          |   Lot_Records    | <---------+               |
         |                     | (批次号追踪表)   |           |               |
         |                     +------------------+           |               |
         v                              ^                     | (生产消耗)    |
+------------------+                    |                     |               |
|      Orders      |                    |                     |               |
|  (采购/销售订单) |                    |                     |               |
+------------------+                    |                     |               |
         |                              |                     |               |
         v                              |                     v               v
+------------------+           +------------------+      +--------------------------+
|  Stock_Movements | --------> |  Inventory_Ledger|      |  Production_Issue_Logs   |
|  (出入库/调拨单) |           |  (库存收发存台账)|      |  (标准领料/超领/退料单)  |
+------------------+           +------------------+      +--------------------------+
         |                              |
         v                              v
+------------------+           +------------------+
|  Financial_Flows |           |   Bins_Stocks    |
| (极简收付款/应收)|           | (库位库存实物表) |
+------------------+           +------------------+
```

### 1. 往来单位表 (`parties`)
统一管理客户与供应商。支持同一客商双重身份（即既是买家也是卖家）。

| 字段名 | 类型 | 约束 | 描述 |
| :--- | :--- | :--- | :--- |
| `id` | SERIAL | PRIMARY KEY | 主键自增ID |
| `code` | VARCHAR(50) | UNIQUE, NOT NULL | 客商编码 (业务生成，如 PART-0001) |
| `name` | VARCHAR(100) | NOT NULL | 往来单位全称 |
| `is_customer` | BOOLEAN | DEFAULT TRUE | 是否为客户（买家） |
| `is_supplier` | BOOLEAN | DEFAULT FALSE | 是否为供应商（卖家） |
| `credit_limit` | DECIMAL(12,2) | DEFAULT 0.00 | 信用额度 |
| `payment_term` | VARCHAR(100) | | 账期条款 (例如: 月结30天, 现结) |
| `contacts` | JSONB | | 多联系人列表 `[{"name": "张三", "phone": "138..", "role": "采购"}]` |
| `addresses` | JSONB | | 多收发货地址 `[{"address": "A厂区", "type": "收货"}]` |

### 2. 物料/商品档案表 (`items`)
区分成品、半成品、原材料、辅料等，并记录上下限安全库存。

| 字段名 | 类型 | 约束 | 描述 |
| :--- | :--- | :--- | :--- |
| `id` | SERIAL | PRIMARY KEY | 主键自增ID |
| `code` | VARCHAR(50) | UNIQUE, NOT NULL | 物料编码 (如 MAT-10023, PROD-0001) |
| `name` | VARCHAR(100) | NOT NULL | 物料名称 |
| `specs` | VARCHAR(200) | | 规格型号 |
| `unit` | VARCHAR(20) | NOT NULL | 计量单位 (如 个, kg, m) |
| `type` | VARCHAR(20) | NOT NULL | 类型 (`成品`, `半成品`, `原材料`, `辅料`, `工具`) |
| `min_safety_stock`| DECIMAL(12,4) | DEFAULT 0.0000 | 安全库存下限 (触发采购草稿提醒) |
| `max_safety_stock`| DECIMAL(12,4) | DEFAULT 999999 | 安全库存上限 |
| `remarks` | TEXT | | 备注说明 |

### 3. 物料清单 BOM 表 (`boms` & `bom_items`)
多级树状树形结构：表达生产1单位父级物料所需的各个子级物料的配比。

#### 主表 `boms`
| 字段名 | 类型 | 约束 | 描述 |
| :--- | :--- | :--- | :--- |
| `id` | SERIAL | PRIMARY KEY | 主键自增ID |
| `parent_item_id` | INT | FOREIGN KEY (`items.id`) | 产出物料（通常为成品/半成品） |
| `version` | VARCHAR(10) | DEFAULT 'V1.0' | BOM 版本号 |
| `is_active` | BOOLEAN | DEFAULT TRUE | 是否启用当前版本 |

#### 子表明细 `bom_items`
| 字段名 | 类型 | 约束 | 描述 |
| :--- | :--- | :--- | :--- |
| `id` | SERIAL | PRIMARY KEY | 主键自增ID |
| `bom_id` | INT | FOREIGN KEY (`boms.id`) | 关联BOM主表 |
| `child_item_id` | INT | FOREIGN KEY (`items.id`) | 子件物料（原材料/半成品） |
| `standard_quantity`| DECIMAL(12,4)| NOT NULL | 标准用量 (生产1单位父件所需的子件数量) |
| `scrap_rate` | DECIMAL(5,4) | DEFAULT 0.0000 | 预期损耗率 (如 0.02 代表 2% 损耗) |

### 4. 库位实物库存表 (`bins_stocks`)
精细到具体逻辑仓库与三维库位（货架、层、位），并支持按批次号隔离。

* 逻辑仓属性：`QC`（待检仓，不可领料销售）、`Available`（正品仓，自由周转）、`Scrap`（报废仓，坏品隔离）、`LineSide`（线边仓，生产中转）。

| 字段名 | 类型 | 约束 | 描述 |
| :--- | :--- | :--- | :--- |
| `id` | SERIAL | PRIMARY KEY | 主键自增ID |
| `warehouse_type` | VARCHAR(20) | NOT NULL | 仓库类型 (`QC`, `Available`, `Scrap`, `LineSide`) |
| `zone` | VARCHAR(20) | NOT NULL | 区域 (如 ZoneA) |
| `shelf` | VARCHAR(20) | NOT NULL | 货架 (如 Shelf03) |
| `tier` | VARCHAR(20) | NOT NULL | 层 (如 Tier2) |
| `bin_position` | VARCHAR(20) | NOT NULL | 位 (如 Bin05) |
| `item_id` | INT | FOREIGN KEY (`items.id`) | 关联物料ID |
| `lot_id` | INT | FOREIGN KEY (`lot_records.id`) | 关联批次ID (实物批次精细管理) |
| `quantity` | DECIMAL(12,4) | DEFAULT 0.0000 | 物理库位实物数量 (不可小于0) |

### 5. 批次记录表 (`lot_records`)
追踪物料在供应端与制造端的批次追溯属性。

| 字段名 | 类型 | 约束 | 描述 |
| :--- | :--- | :--- | :--- |
| `id` | SERIAL | PRIMARY KEY | 主键自增ID |
| `lot_number` | VARCHAR(100) | UNIQUE, NOT NULL | 唯一批次号 (规则：物料编码+日期+供应商/工单号) |
| `item_id` | INT | FOREIGN KEY (`items.id`) | 关联物料ID |
| `created_date` | TIMESTAMP | DEFAULT CURRENT_TIMESTAMP| 批次生成时间 |
| `supplier_id` | INT | FOREIGN KEY (`parties.id`), NULL| 供应商ID (采购入库批次特有) |
| `work_order_id` | INT | FOREIGN KEY (`work_orders.id`), NULL| 生产工单ID (完工入库批次特有) |

### 6. 库存台账收发存流水表 (`inventory_ledger`)
保存每次变动的历史镜像，支持全量审计、核对与溯源。

| 字段名 | 类型 | 约束 | 描述 |
| :--- | :--- | :--- | :--- |
| `id` | BIGSERIAL | PRIMARY KEY | 主键自增ID |
| `created_at` | TIMESTAMP | DEFAULT CURRENT_TIMESTAMP| 变动精确时间 |
| `operator_id` | INT | NOT NULL | 经办操作员ID |
| `movement_type` | VARCHAR(30) | NOT NULL | 变动类型 (如 采购入库, 生产领料, 超领, 盘盈...) |
| `reference_doc_id`| VARCHAR(100)| NOT NULL | 关联单据编号 (如单号 PO-20260805) |
| `item_id` | INT | FOREIGN KEY (`items.id`) | 物料ID |
| `bin_id` | INT | FOREIGN KEY (`bins_stocks.id`) | 发生变动的库位ID |
| `lot_id` | INT | FOREIGN KEY (`lot_records.id`) | 关联批次ID |
| `quantity_before` | DECIMAL(12,4) | NOT NULL | 变动前该库位该批次数量 |
| `quantity_delta` | DECIMAL(12,4) | NOT NULL | 变动数量 (正数为增，负数为减) |
| `quantity_after` | DECIMAL(12,4) | NOT NULL | 变动后数量 |

---

## 三、 核心业务流与 API 接口设计 (Core Business Flows & API Design)

### 1. 生产物料闭环流程 (Standard vs Excess Issue Loop)
当车间发起工单制造时，物料控制流程如下图所示。通过严格限制在【线边仓】内消耗和补充，保障实物闭环。

```
 [正品仓 / 总仓] (Available)
       |
       | 1. 依据 BOM 标准计算
       |    ---> [标准领料单] 调拨调入
       |
       v
  [线边仓] (Line-Side) <======================+
       |                                     ||
       | 2. 车间消耗 & 制造                   || 3. 超损耗/材料报废
       |    ---> 扣减线边仓库存               ||    ---> [超领单]
       |                                     ||    ---> (强制填报原因+审批)
       v                                     ||
  [成品/半成品] ----------------------------+
       |
       +---> 4. 剩余原材料退回 ---> [退料单] ---> 调拨调回 [正品仓 / 总仓]
       |
       +---> 5. 完工产出入库 ---> [完工入库单] ---> [正品仓] 或 [待检仓]
```

#### API 接口设计：

* **1.1 创建标准领料单 (调拨至线边仓)**
  * **POST** `/api/production/issue/standard`
  * **Payload**:
    ```json
    {
      "work_order_id": 1024,
      "operator_id": 5,
      "items": [
        { "item_id": 45, "lot_id": 12, "quantity": 100.0, "source_bin_id": 1 }
      ]
    }
    ```
  * **逻辑**：扣减 `source_bin_id` 对应的正品仓库存，在 `LineSide`（线边仓）中创建或增加该批次的库存，并向 `inventory_ledger` 记录台账。

* **1.2 申请超领单 (异常超额发料，强控原因)**
  * **POST** `/api/production/issue/excess`
  * **Payload**:
    ```json
    {
      "work_order_id": 1024,
      "operator_id": 5,
      "item_id": 45,
      "quantity": 15.0,
      "scrap_reason": "模具异常导致首件严重划伤报废",
      "approver_id": 1
    }
    ```
  * **逻辑**：进行审批验证。审核通过后，方可将原材料从总仓调拨至线边仓进行消耗，同步记录超领台账。

* **1.3 车间退料单 (线边退库)**
  * **POST** `/api/production/return`
  * **Payload**:
    ```json
    {
      "work_order_id": 1024,
      "operator_id": 5,
      "items": [
        { "item_id": 45, "lot_id": 12, "quantity": 5.0, "target_bin_id": 2 }
      ]
    }
    ```
  * **逻辑**：扣减线边仓物理库存，增加 `target_bin_id`（正品总仓）物理库存。

---

### 2. 批次全链路正反向追溯流程 (Lot Traceability Chain)
追溯的核心思想在于通过“批次号 (Lot Number)”将采购、生产、完工、出库全生命周期的台账记录串联起来。

#### 追溯核心链路架构图：
```
 ┌────────────────┐         ┌──────────────────┐         ┌────────────────┐
 │  采购入库单   │         │ 生产领料/消耗单 │         │  销售发货单   │
 │                │         │                  │         │                │
 │ 记录: 批次号A  ├────────>│ 生产工单(消耗A,  ├────────>│ 记录: 批次号B  │
 │                │         │ 完工产出批次号B) │         │                │
 └────────────────┘         └──────────────────┘         └────────────────┘
```

#### API 接口设计：

* **2.1 正向追溯 (从原材料批次追到最终销售客户)**
  * **GET** `/api/traceability/forward?lot_number=RAW-PVC-20260805-SUPP01`
  * **Response**:
    ```json
    {
      "input_lot": "RAW-PVC-20260805-SUPP01",
      "material_info": { "code": "RAW-PVC", "name": "聚氯乙烯颗粒", "specs": "工业级" },
      "purchase_info": { "doc_no": "PO-20260801", "supplier_name": "宏达化工有限公司", "date": "2026-08-05" },
      "work_orders_involved": [
        {
          "work_order_code": "WO-2026080501",
          "target_item_name": "PVC软管",
          "produced_lots": [
            {
              "lot_number": "PROD-HOSE-20260805-WO01",
              "sales_deliveries": [
                { "delivery_doc_no": "SD-20260806", "customer_name": "美家塑胶制品厂", "quantity": 500.0, "date": "2026-08-06" }
              ]
            }
          ]
        }
      ]
    }
    ```

* **2.2 反向追溯 (从成品批次倒查到最原始的采购单与供应商)**
  * **GET** `/api/traceability/backward?lot_number=PROD-HOSE-20260805-WO01`
  * **Response**:
    ```json
    {
      "produced_lot": "PROD-HOSE-20260805-WO01",
      "product_info": { "code": "PROD-HOSE", "name": "PVC软管", "specs": "DN15" },
      "work_order_info": { "work_order_code": "WO-2026080501", "quantity": 1000.0, "date": "2026-08-05" },
      "raw_materials_used": [
        {
          "item_code": "RAW-PVC",
          "item_name": "聚氯乙烯颗粒",
          "used_lot_number": "RAW-PVC-20260805-SUPP01",
          "purchase_doc_no": "PO-20260801",
          "supplier_name": "宏达化工有限公司"
        }
      ]
    }
    ```

---

### 3. 极简财务联动流程 (Minimalist AR/AP Auto-Generation)
该模块杜绝复杂的成本分摊和复杂的复式记账。财务单据的应收应付记录完全被动地受实物出入库动作触发。

* **业务联动机制**：
  * **销售出库单** `Confirm Delivery` $\rightarrow$ 后端自动在 `financial_ledger` 中追加一条【未核销应收账款】。
  * **采购入库单** `Confirm Warehouse Receipt` $\rightarrow$ 后端自动在 `financial_ledger` 中追加一条【未核销应付账款】。

#### API 接口设计：

* **3.1 资金核销接口 (对账回款)**
  * **POST** `/api/finance/reconcile`
  * **Payload**:
    ```json
    {
      "party_id": 12,
      "reconcile_type": "AR", // AR:应收核销, AP:应付核销
      "amount": 5000.00,
      "payment_method": "银行转账",
      "account_id": 1, // 资金账户
      "associated_delivery_doc": "SD-20260806"
    }
    ```
  * **逻辑**：标记该出入库单对应的账款为已核销或部分核销。累加到对应资金账户余额。

---

## 四、 推荐技术栈方案 (Recommended Technology Stack Architecture)

| 层级 | 推荐技术 | 替代方案 | 选型优势说明 |
| :--- | :--- | :--- | :--- |
| **前端 UI 框架**| **Flutter (Web/Desktop)** | React / Vue | 一套代码完美跨端，多尺寸界面自适应。Canvas 渲染极大提升大规模数据（如 Excel 样式表格）的渲染帧数。 |
| **后端 API 框架**| **FastAPI (Python 3.10+)**| Go (Gin) / Spring Boot| 极速编写原型，内置 Swagger UI 自动生成规范接口文档。异步高性能。 |
| **数据库** | **PostgreSQL (15+)** | MySQL | 天然支持复杂树形查询（如 BOM 树状递归）、JSONB 格式字段（用于扩展联系人和出库地址），对高并发台账事务安全性提供强力保障。 |
| **ORM / 数据交互**| **SQLAlchemy + Alembic** | Tortoise-ORM | 工业级 Python ORM，完善的关系映射与事务控制，Alembic 提供高度可控的数据库结构版本迁移。 |
| **服务部署管理** | **Docker Compose** | Bare-metal PM2 | 一键打包封装 PostgreSQL、FastAPI 容器，解决不同操作系统下部署 Python 运行环境困难的痛点。 |

---

## 五、 PowerShell 智能诊断与排查指南

如果在配置运行过程中，启动脚本 `run_app.ps1` 报告连通性异常，您可以执行以下排查：

1. **“Error 404/500 - API 端口畅通但返回错误”**：
   * 确保 `backend/main.py` 已经存在 `@app.get("/api")` 或 `@app.get("/api/")` 路由并且返回 `200` 状态码（目前该路由已添加，用于连通性心跳握手）。
2. **“Error DB_CONN - 数据库未开启或密码错误”**：
   * 验证 PostgreSQL 服务。在本地终端输入：`psql -U postgres`，输入密码 `23711375`。
   * 如数据库不存在，请先创建。在 `psql` 下执行：`CREATE DATABASE postgres;`（或对应连接名称）。
