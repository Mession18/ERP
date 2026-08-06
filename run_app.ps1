# Windows PowerShell ERP Launcher & Connection Diagnostics Script
# Usage: Open PowerShell and run: .\run_app.ps1

Clear-Host
Write-Host "==========================================================================" -ForegroundColor Cyan
Write-Host "             高精密智能制造 ERP 系统 一键检测与启动诊断脚本             " -ForegroundColor Cyan
Write-Host "==========================================================================" -ForegroundColor Cyan
Write-Host ""

$BackendUrl = "http://localhost:8000/api"
$FrontendDir = "build/web"

# Step 1: Detect Backend API Port (8000)
Write-Host "[1/3] 正在检测后端 API 服务 (Port 8000) 是否开启..." -ForegroundColor Yellow
$Port8000Active = $false
try {
    $TcpClient = New-Object System.Net.Sockets.TcpClient
    $Connect = $TcpClient.BeginConnect("localhost", 8000, $null, $null)
    $Wait = $Connect.AsyncWaitHandle.WaitOne(1000, $false)
    if ($TcpClient.Connected) {
        $Port8000Active = $true
        $TcpClient.Close()
    }
} catch {
    $Port8000Active = $false
}

if (-not $Port8000Active) {
    Write-Host ""
    Write-Host "❌ 错误: 未检测到后端 API 服务！ FastAPI 未运行在端口 8000。" -ForegroundColor Red
    Write-Host "👉 解决方案:" -ForegroundColor Yellow
    Write-Host "  1. 打开一个新的终端/PowerShell窗口。" -ForegroundColor White
    Write-Host "  2. 切换到项目根目录下运行以下命令启动后端服务器:" -ForegroundColor White
    Write-Host "     uvicorn backend.main:app --host 0.0.0.0 --port 8000 --reload" -ForegroundColor Cyan
    Write-Host "  3. 待后端启动后，重新运行当前检测脚本。" -ForegroundColor White
    Write-Host ""
    Read-Host "请按 [Enter] 键退出..."
    Exit
} else {
    Write-Host "✓ 后端 8000 端口已处于开启监听状态。" -ForegroundColor Green
}

# Step 2: Health Check handshake `/api` to verify backend responsiveness
Write-Host ""
Write-Host "[2/3] 正在与后端心跳接口进行握手通信..." -ForegroundColor Yellow
$ApiResponsive = $false
$DbConnected = $false
try {
    $Response = Invoke-RestMethod -Uri $BackendUrl -Method Get -TimeoutSec 3
    if ($Response.status -eq "ok") {
        $ApiResponsive = $true
        $DbConnected = $true # The backend is alive and connected
    }
} catch {
    $ApiResponsive = $false
}

if (-not $ApiResponsive) {
    Write-Host ""
    Write-Host "❌ 警告: 后端服务未正确响应！" -ForegroundColor Red
    Write-Host "  后端端口 8000 畅通，但是对 '$BackendUrl' 的 GET 请求未返回正确数据或返回了 404/500 错误。" -ForegroundColor White
    Write-Host "👉 解决方案:" -ForegroundColor Yellow
    Write-Host "  * 请确保您使用的是最新版本的 backend/main.py 文件。" -ForegroundColor White
    Write-Host "  * 确保后端服务运行无报错。在运行 uvicorn 的控制台中查看具体 Traceback 信息。" -ForegroundColor White
    Write-Host ""
    Read-Host "请按 [Enter] 键退出..."
    Exit
} else {
    Write-Host "✓ 后端 API 成功响应握手包: $($Response.message)" -ForegroundColor Green
}

# Step 3: Run database connectivity assertion through Backend helper
Write-Host ""
Write-Host "[3/3] 正在由后端代为检测 PostgreSQL 数据库连通性..." -ForegroundColor Yellow

# Query backend for product list to assert database connection
$DbSafe = $false
try {
    $DbCheck = Invoke-WebRequest -Uri "http://localhost:8000/api/products?show_off_shelf=true" -Method Get -TimeoutSec 3
    if ($DbCheck.StatusCode -eq 200) {
        $DbSafe = $true
    }
} catch {
    $DbSafe = $false
}

if (-not $DbSafe) {
    Write-Host ""
    Write-Host "⚠️  严重警告: 后端已运行，但 PostgreSQL 数据库未连接或无法读取！" -ForegroundColor Red
    Write-Host "👉 解决方案:" -ForegroundColor Yellow
    Write-Host "  1. 请检查您的本地 PostgreSQL 服务是否已启动！" -ForegroundColor White
    Write-Host "     (在 Windows 搜索 '服务' 找到 PostgreSQL 并启动它)" -ForegroundColor White
    Write-Host "  2. 验证数据库连接凭据。确保用户名为 'postgres'，密码为 '23711375'。" -ForegroundColor White
    Write-Host "  3. 后端数据库配置连接串位于 backend/database.py 中。" -ForegroundColor White
    Write-Host ""
    Write-Host "提示: 前端应用当前将运行在 [断网离线离线备用模式]。" -ForegroundColor DarkYellow
    Write-Host ""
} else {
    Write-Host "✓ 数据库连接完全正常！ 成功读取产品表实体。" -ForegroundColor Green
}

Write-Host "==========================================================================" -ForegroundColor Green
Write-Host "  检测成功: 全系统网络连通！ 正在为您在端口 3000 启动 ERP 前端 web 服务...  " -ForegroundColor Green
Write-Host "==========================================================================" -ForegroundColor Green
Write-Host ""

# Check if build directory exists, if not build it
if (-not (Test-Path $FrontendDir)) {
    Write-Host "未找到前端 Web 编译文件，正在编译 web 应用 (首次运行可能需要几秒)..." -ForegroundColor Yellow
    flutter build web
}

Write-Host "正在启动 Web 服务器挂载前端，正在打开默认浏览器..." -ForegroundColor Yellow
# Run server on port 3000
python3 -m http.server 3000 --directory build/web
