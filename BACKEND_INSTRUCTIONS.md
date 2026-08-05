# 高可用 ERP 系统部署与独立启动手册 (V1)

本系统采用 **前端 (Flutter Web) 与后端 (Python FastAPI) 彻底解耦** 的微服务架构设计，非常便于后续将 Python 后端独立部署在云端物理服务器或 Docker 容器中。

---

## 1. 数据库配置 (PostgreSQL)

本系统默认连接至以下本地 PostgreSQL 数据库。如果您将数据库部署在外部云服务器上，请直接修改 `backend/database.py` 中的 `DATABASE_URL`。

*   **默认连接串 (V1 指定)**: `postgresql://postgres:23711375@localhost:5432/postgres`
*   **依赖项**: 后端依赖于 `psycopg2-binary` 或 `asyncpg`。

---

## 2. 后端服务端启动 (Python FastAPI)

后端完全独立运行，提供完整的 REST APIs、静态附件文件托管，以及严格的 ERP 商业关联逻辑检验。

### 步骤 A: 安装环境依赖

在后端服务器的控制台中，执行以下指令安装运行环境依赖：

```bash
pip install fastapi uvicorn sqlalchemy psycopg2-binary python-multipart httpx
```

### 步骤 B: 独立开启后端服务

在项目根目录下，运行以下指令开启后端服务。
服务会默认绑定在 `0.0.0.0`，以便局域网或公网设备直接进行 API 交互。

```bash
# 开启服务（绑定在端口 8000）
uvicorn backend.main:app --host 0.0.0.0 --port 8000
```

*   **API 接口文档**: 启动后可在浏览器访问 `http://<服务器IP>:8000/docs` 查看 Swagger 交互式自动文档。
*   **附件存储路径**: 所有的图纸/发票上传文件会安全地存在 `backend/uploads/` 目录下。

---

## 3. 前端客户端构建与运行 (Flutter)

前端基于 Flutter 跨平台框架构建，支持 Web、桌面客户端（Linux/Windows/macOS）以及手机移动端（Android/iOS）。

### 调试模式运行

如果您安装了 Flutter SDK 且已连好真机或模拟器，可直接在根目录下运行：

```bash
# 运行调试
flutter run -d chrome
```

### 生产环境打包并托管 (Web 模式)

如果您需要将前端页面打包并部署在 Nginx、Apache、IIS 或者 CDN 上，可以执行打包命令：

```bash
# 打包编译成静态 Web 文件
flutter build web
```

打包完成后，静态页面会存留在 `build/web/` 目录下。
在本地调试时，您也可以通过简单的 Python HTTP 容器直接独立预览该静态网页：

```bash
# 独立托管静态网页前端（绑定在端口 3000）
python3 -m http.server --directory build/web/ 3000
```

---

## 4. ERP 商业核心流控说明

1.  **首屏控制大屏**:
    控制大屏中的「库存、客群、订单、出入库、财务」指标卡均直接与 PostgreSQL 数据库联动，并支持**一击鼠标点击直接跳转**到对应管理页面。
2.  **安全平账与交付校验**:
    *   **订单已完成标准**: 只有待交付数量 = 0 且 待付款尾款 = 0 元时，订单才判定为「已完成」并支持自动对账流转。
    *   **物理删除保护**: 如果客户或商品曾经参与过任何订单、出库或者财务平账，物理删除按钮将实施强制阻断，只能删除未发生过任何交易的草稿客户或空商品。
3.  **简易化物理删除验证**:
    为减少日常操作的繁复性，删除按钮取消了滑动校验，变更为弹出简洁的高级确认框（Confirm Alert），一键点击确认即可。
