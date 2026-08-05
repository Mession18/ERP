import 'package:flutter/material.dart';
import 'package:erp/screens/inventory_screen.dart';
import 'package:erp/screens/customer_screen.dart';
import 'package:erp/screens/order_screen.dart';
import 'package:erp/screens/warehouse_screen.dart';
import 'package:erp/screens/finance_screen.dart';
import 'package:erp/screens/production_screen.dart';
import 'package:erp/services/api_service.dart';
import 'package:erp/widgets/resizable_panel.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '高精密智能制造 ERP 生产控制台',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.indigo,
          primary: Colors.indigo,
          secondary: Colors.blueAccent,
        ),
        useMaterial3: true,
        fontFamily: 'Segoe UI',
        scaffoldBackgroundColor: const Color(0xFFF4F6F9),
      ),
      home: const MainERPContainer(),
    );
  }
}

class MainERPContainer extends StatefulWidget {
  const MainERPContainer({super.key});

  @override
  State<MainERPContainer> createState() => _MainERPContainerState();
}

class _MainERPContainerState extends State<MainERPContainer> {
  int _activeMenuIndex = 0;

  void _onNavigate(int index) {
    setState(() {
      _activeMenuIndex = index;
    });
  }

  // The lists of screens
  late List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    _screens = [
      ERPHomeDashboard(onNavigate: _onNavigate),
      const InventoryScreen(),
      const CustomerScreen(),
      const OrderScreen(),
      const WarehouseScreen(),
      const FinanceScreen(),
      const ProductionScreen(),
    ];
  }

  final List<String> _menuLabels = [
    "首屏控制台",
    "库存管理",
    "客户管理",
    "订单管理",
    "进出库管理",
    "财务管理",
    "生产管理 (预留)",
  ];

  final List<IconData> _menuIcons = [
    Icons.dashboard,
    Icons.warehouse,
    Icons.people,
    Icons.shopping_bag,
    Icons.local_shipping,
    Icons.account_balance_wallet,
    Icons.handyman,
  ];

  @override
  Widget build(BuildContext context) {
    // Navigation Sidebar View
    Widget sidebar = Container(
      color: const Color(0xFF1E1E2F),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Logo & Title
          Container(
            padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
            color: const Color(0xFF151521),
            child: Row(
              children: [
                const Icon(Icons.rocket_launch, color: Colors.blueAccent, size: 28),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text(
                        "智能制造ERP",
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          letterSpacing: 1.1,
                        ),
                      ),
                      Text(
                        "v1.0.0 控制总线",
                        style: TextStyle(
                          color: Colors.grey,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // User / System Info (Reserved Login Panel)
          Container(
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF2B2B40),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const CircleAvatar(
                  backgroundColor: Colors.blueAccent,
                  radius: 16,
                  child: Icon(Icons.person, color: Colors.white, size: 16),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "管理员 (免登模式)",
                        style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                        overflow: TextOverflow.ellipsis,
                      ),
                      GestureDetector(
                        onTap: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text("提示：当前已开机直达。登录认证接口已预留，可在系统设置中开启。")),
                          );
                        },
                        child: const Text(
                          "预留登录/登出通道",
                          style: TextStyle(color: Colors.blueAccent, fontSize: 10, decoration: TextDecoration.underline),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(color: Color(0xFF2B2B40)),
          // Navigation menus
          Expanded(
            child: ListView.builder(
              itemCount: _menuLabels.length,
              itemBuilder: (context, index) {
                final bool isActive = _activeMenuIndex == index;
                return InkWell(
                  onTap: () {
                    setState(() {
                      _activeMenuIndex = index;
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      color: isActive ? Colors.indigo.withOpacity(0.2) : Colors.transparent,
                      border: Border(
                        left: BorderSide(
                          color: isActive ? Colors.blueAccent : Colors.transparent,
                          width: 4,
                        ),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          _menuIcons[index],
                          color: isActive ? Colors.blueAccent : Colors.grey,
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          _menuLabels[index],
                          style: TextStyle(
                            color: isActive ? Colors.white : Colors.grey[400],
                            fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                            fontSize: 13.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          // Footer
          Container(
            padding: const EdgeInsets.all(16),
            color: const Color(0xFF151521),
            child: const Text(
              "© 2024 高精工业集团",
              style: TextStyle(color: Colors.grey, fontSize: 10),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );

    // Sidebar and main content split using resizable panel
    return Scaffold(
      body: ResizableSplitPanel(
        first: sidebar,
        second: Column(
          children: [
            // Topbar
            Container(
              height: 56,
              color: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Text(
                    _menuLabels[_activeMenuIndex],
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const Spacer(),
                  // Indicators
                  Tooltip(
                    message: "安全物理删除二次验证已开通",
                    child: Row(
                      children: const [
                        Icon(Icons.shield, color: Colors.green, size: 18),
                        SizedBox(width: 4),
                        Text("二次验证开通", style: TextStyle(color: Colors.green, fontSize: 12)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Tooltip(
                    message: "界面左右调节拖拽条已启用",
                    child: Row(
                      children: const [
                        Icon(Icons.unfold_more, color: Colors.blueAccent, size: 18),
                        SizedBox(width: 4),
                        Text("全端适配栏", style: TextStyle(color: Colors.blueAccent, fontSize: 12)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            // Workspace Screen area
            Expanded(
              child: IndexedStack(
                index: _activeMenuIndex,
                children: _screens,
              ),
            ),
          ],
        ),
        direction: Axis.horizontal,
        initialRatio: 0.20,
        minSize: 180,
      ),
    );
  }
}

// Initial Landing Home/Dashboard Screen with Live Database Summaries and Click Navigation
class ERPHomeDashboard extends StatefulWidget {
  final Function(int) onNavigate;
  const ERPHomeDashboard({super.key, required this.onNavigate});

  @override
  State<ERPHomeDashboard> createState() => _ERPHomeDashboardState();
}

class _ERPHomeDashboardState extends State<ERPHomeDashboard> {
  bool _loading = true;

  // Real database stats
  int _totalStock = 0;
  int _activeStockCount = 0;
  int _inactiveStockCount = 0;

  int _totalCustomers = 0;
  int _buyersCount = 0;
  int _sellersCount = 0;

  int _completedOrders = 0;
  int _ongoingOrders = 0;
  int _todayOrders = 0;

  int _todayDeliveredCount = 0;
  int _pendingDeliveriesCount = 0;

  double _totalTransactionAmount = 0.0;
  double _totalPendingCollection = 0.0;
  double _totalPendingInvoice = 0.0;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    setState(() => _loading = true);
    try {
      // 1. Load products
      final prods = await ApiService.getProducts(showOffShelf: true);
      int tStock = 0;
      int activeP = 0;
      int inactiveP = 0;
      for (var p in prods) {
        tStock += (p["quantity"] as int);
        if (p["status"] == "上架") {
          activeP++;
        } else {
          inactiveP++;
        }
      }

      // 2. Load customers
      final custs = await ApiService.getCustomers();
      int buyers = 0;
      int sellers = 0;
      for (var c in custs) {
        if (c["type"] == "买家") {
          buyers++;
        } else {
          sellers++;
        }
      }

      // 3. Load orders
      final ords = await ApiService.getOrders(showCompleted: true);
      int compO = 0;
      int ongO = 0;
      int todayO = 0;
      final todayStr = "${DateTime.now().year}-${DateTime.now().month.toString().padLeft(2, '0')}-${DateTime.now().day.toString().padLeft(2, '0')}";

      for (var o in ords) {
        if (o["status"] == "已完成") {
          compO++;
        } else {
          ongO++;
        }
        if (o["order_date"] == todayStr) {
          todayO++;
        }
      }

      // 4. Load warehouse / deliveries
      final delsView = await ApiService.getDeliveriesView(showAll: true);
      int pendingD = 0;
      int todayDel = 0;
      for (var d in delsView) {
        pendingD += (d["pending_quantity"] as int);
      }
      // Sum today deliveries from orders deep log
      for (var o in ords) {
        final details = await ApiService.getOrderDetails(o["id"]);
        final delList = details["deliveries"] as List;
        for (var d in delList) {
          if (d["delivery_date"] == todayStr) {
            todayDel += (d["quantity"] as int);
          }
        }
      }

      // 5. Load financials
      final finsView = await ApiService.getFinancialsView(showAll: true);
      double totalTx = 0.0;
      double pendingColl = 0.0;
      double pendingInv = 0.0;
      for (var f in finsView) {
        totalTx += (f["total_amount"] as double);
        pendingColl += (f["pending_amount"] as double);
        pendingInv += (f["pending_invoice_amount"] as double);
      }

      setState(() {
        _totalStock = tStock;
        _activeStockCount = activeP;
        _inactiveStockCount = inactiveP;
        _totalCustomers = custs.length;
        _buyersCount = buyers;
        _sellersCount = sellers;
        _completedOrders = compO;
        _ongoingOrders = ongO;
        _todayOrders = todayO;
        _pendingDeliveriesCount = pendingD;
        _todayDeliveredCount = todayDel;
        _totalTransactionAmount = totalTx;
        _totalPendingCollection = pendingColl;
        _totalPendingInvoice = pendingInv;
      });
    } catch (_) {}
    setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Banner card
            Card(
              color: Colors.indigo[900],
              elevation: 4,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text(
                            "欢迎使用高精密智能制造 ERP 生产控制总线",
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20),
                          ),
                          SizedBox(height: 8),
                          Text(
                            "系统已连接本地高可用 PostgreSQL 数据库。当前处于全功能免登运行模式，各模块之间已自动配置出入库平账校验及物理删除双重保护。点击下方模块即可切换到对应管理工作台页面。",
                            style: TextStyle(color: Colors.white70, height: 1.5, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    IconButton(
                      icon: const Icon(Icons.sync_outlined, size: 48, color: Colors.blueAccent),
                      onPressed: _loadStats,
                      tooltip: "刷新全局数据库统计",
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("数据大屏工作台 (支持一击跳转)", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                if (_loading) const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
              ],
            ),
            const SizedBox(height: 16),
            // Interactive module cards
            GridView.count(
              crossAxisCount: MediaQuery.of(context).size.width > 900 ? 3 : 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: 1.4,
              children: [
                _buildClickableCard(
                  title: "库存货品管理",
                  subDetails: "总库存件数: $_totalStock\n在架商品数: $_activeStockCount\n下架隐藏数: $_inactiveStockCount",
                  icon: Icons.inventory_2,
                  color: Colors.indigo,
                  onTap: () => widget.onNavigate(1),
                ),
                _buildClickableCard(
                  title: "客群对账管理",
                  subDetails: "总客户数量: $_totalCustomers\n其中买家: $_buyersCount 个\n其中供应商: $_sellersCount 个",
                  icon: Icons.people,
                  color: Colors.orange,
                  onTap: () => widget.onNavigate(2),
                ),
                _buildClickableCard(
                  title: "订单生产总线",
                  subDetails: "进行中订单: $_ongoingOrders\n已结清完成: $_completedOrders\n今日新增量: $_todayOrders",
                  icon: Icons.shopping_cart,
                  color: Colors.purple,
                  onTap: () => widget.onNavigate(3),
                ),
                _buildClickableCard(
                  title: "进出库分拨对账",
                  subDetails: "今日已交货: $_todayDeliveredCount 件\n未交付待处理: $_pendingDeliveriesCount 批次",
                  icon: Icons.local_shipping,
                  color: Colors.teal,
                  onTap: () => widget.onNavigate(4),
                ),
                _buildClickableCard(
                  title: "财务清账核销",
                  subDetails: "总交易额: ￥${_totalTransactionAmount.toStringAsFixed(2)}\n待收付款: ￥${_totalPendingCollection.toStringAsFixed(2)}\n待开发票: ￥${_totalPendingInvoice.toStringAsFixed(2)}",
                  icon: Icons.payment,
                  color: Colors.green,
                  onTap: () => widget.onNavigate(5),
                ),
                _buildClickableCard(
                  title: "排产与工艺调度",
                  subDetails: "二期排期预留模块\n冷镦成型、高温硫化车间\n设备负荷及 MRP 物料领用排班",
                  icon: Icons.handyman,
                  color: Colors.brown,
                  onTap: () => widget.onNavigate(6),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildClickableCard({required String title, required String subDetails, required IconData icon, required Color color, required VoidCallback onTap}) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: color.withOpacity(0.1),
                    child: Icon(icon, color: color, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.black87),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const Icon(Icons.arrow_forward_ios, size: 12, color: Colors.grey),
                ],
              ),
              const SizedBox(height: 12),
              Expanded(
                child: Text(
                  subDetails,
                  style: const TextStyle(fontSize: 12, color: Colors.black54, height: 1.5, fontFamily: "monospace"),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
