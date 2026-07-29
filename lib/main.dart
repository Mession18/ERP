import 'package:flutter/material.dart';
import 'package:erp/screens/inventory_screen.dart';
import 'package:erp/screens/customer_screen.dart';
import 'package:erp/screens/order_screen.dart';
import 'package:erp/screens/warehouse_screen.dart';
import 'package:erp/screens/finance_screen.dart';
import 'package:erp/screens/production_screen.dart';
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

  // The lists of screens
  final List<Widget> _screens = [
    const ERPHomeDashboard(),
    const InventoryScreen(),
    const CustomerScreen(),
    const OrderScreen(),
    const WarehouseScreen(),
    const FinanceScreen(),
    const ProductionScreen(),
  ];

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
        minSize: 180, // Allow sidebar to shrink/grow, supports both desktop and mobile
      ),
    );
  }
}

// Initial Landing Home/Dashboard Screen
class ERPHomeDashboard extends StatelessWidget {
  const ERPHomeDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
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
                          "系统已成功连接本地高可用 PostgreSQL 数据库集群（cluster 16 main）。当前处于全功能免登管理员运行模式，已自动配置出入库限制阻断，和物理删除二阶段二次安全验证。在下方可一键查看模块拓扑。",
                          style: TextStyle(color: Colors.white70, height: 1.5, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  const Icon(Icons.analytics, size: 72, color: Colors.blueAccent),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          const Text("企业信息流交互总线图 (模块树 & 联动)", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 16),
          // Interactive module cards
          GridView.count(
            crossAxisCount: MediaQuery.of(context).size.width > 900 ? 3 : 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: 1.5,
            children: [
              _buildMetricSummary(
                context,
                title: "库存货品管理 (Excel表格)",
                desc: "商品编号自动生成及自定义修改。多格式工程图纸（PDF/DWG）一键预览。未完成订单时严格限制下架删除。",
                icon: Icons.inventory_2,
                color: Colors.indigo,
              ),
              _buildMetricSummary(
                context,
                title: "客群管理对账 (买家及卖家)",
                desc: "多角色信息联动管理。与订单总线实时交互。查看该客户下单历史，统计并展示总成交、应收应付金额。",
                icon: Icons.person_add,
                color: Colors.orange,
              ),
              _buildMetricSummary(
                context,
                title: "订单生产总线 (双指标罗盘)",
                desc: "采用双层同心圆环动态指示交付（外圆）与收付款（内圆）的各自进度。联动仓储、财务核销。",
                icon: Icons.shopping_cart,
                color: Colors.purple,
              ),
              _buildMetricSummary(
                context,
                title: "进出库分拨 (仓储实控)",
                desc: "拉取订单内容。出库交付严格阻断超过待交及可用库存，修改交货实录时自动安全还原并对账库存。",
                icon: Icons.local_shipping,
                color: Colors.teal,
              ),
              _buildMetricSummary(
                context,
                title: "财务收支结算 (开票核销)",
                desc: "核对订单付款流水，登记发票代码、扫描件（PDF/JPG）。账目全期支持明细修改与安全平账。",
                icon: Icons.payment,
                color: Colors.green,
              ),
              _buildMetricSummary(
                context,
                title: "排产与工艺调度 (二期预留)",
                desc: "预留的高精密工艺、设备排班、OEE工时控制。Excel排期，并与原料库存及订单算料联动。",
                icon: Icons.handyman,
                color: Colors.brown,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetricSummary(BuildContext context, {required String title, required String desc, required IconData icon, required Color color}) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: color.withOpacity(0.1),
                  child: Icon(icon, color: color),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Expanded(
              child: Text(
                desc,
                style: const TextStyle(fontSize: 12, color: Colors.grey, height: 1.4),
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
