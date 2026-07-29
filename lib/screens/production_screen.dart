import 'package:flutter/material.dart';
import 'package:erp/widgets/excel_table.dart';
import 'package:erp/widgets/resizable_panel.dart';

class ProductionScreen extends StatelessWidget {
  const ProductionScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // excel cols
    final excelCols = [
      ExcelColumn(label: "生产批次号", width: 130),
      ExcelColumn(label: "工艺类型", width: 110),
      ExcelColumn(label: "主配料名称", width: 150),
      ExcelColumn(label: "计划投产数", width: 100),
      ExcelColumn(label: "当前排产状态", width: 110),
      ExcelColumn(label: "生产车间主任", width: 110),
      ExcelColumn(label: "开工日期", width: 110),
    ];

    final excelRows = [
      [
        const Text("BATCH-20240501", style: TextStyle(fontFamily: "monospace", fontWeight: FontWeight.bold)),
        const Text("精密机械冷镦"),
        const Text("碳素拉丝钢 A级"),
        const Text("5000 件", style: TextStyle(fontWeight: FontWeight.bold)),
        const Text("排队中", style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold)),
        const Text("毛主任"),
        const Text("2024-05-20"),
      ],
      [
        const Text("BATCH-20240502", style: TextStyle(fontFamily: "monospace", fontWeight: FontWeight.bold)),
        const Text("模压高温硫化"),
        const Text("耐高温天然橡胶"),
        const Text("20000 件", style: TextStyle(fontWeight: FontWeight.bold)),
        const Text("正在生产", style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
        const Text("徐主管"),
        const Text("2024-05-18"),
      ]
    ];

    Widget tableView = ExcelTable(
      columns: excelCols,
      rowCount: excelRows.length,
      rows: excelRows,
      headerActions: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            const Icon(Icons.handyman, color: Colors.blue),
            const SizedBox(width: 8),
            const Text(
              "排产排班工作台 (高级工艺流转系统 - 预留模块)",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
            const Spacer(),
            ElevatedButton.icon(
              icon: const Icon(Icons.add),
              label: const Text("模拟新建排产单"),
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("提示：排产系统为二期建设规划中，当前为交互界面预留展示。")));
              },
            ),
          ],
        ),
      ),
    );

    Widget detailPanel = Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Row(
            children: [
              Icon(Icons.settings_suggest, size: 28, color: Colors.blue),
              SizedBox(width: 8),
              Text(
                "生产管理二期规划",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ],
          ),
          const Divider(),
          const SizedBox(height: 12),
          const Text(
            "排产与排班说明:",
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          ),
          const SizedBox(height: 8),
          const Text(
            "• 本模块将实现直接与库存管理中的“生产工艺等预留后续可添加的信息”以及订单管理中的采购销售计划进行实时联动。\n"
            "• 支持自动拆单与MRP算料（物料需求计划计算），能根据现有库存原料配比一键生成领料单与加工任务单。\n"
            "• 提供设备稼动率（OEE）看板，可调整左右屏宽拖拽查看各个机台负荷情况。",
            style: TextStyle(height: 1.6, fontSize: 13),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            icon: const Icon(Icons.rocket_launch),
            label: const Text("申请升级定制版"),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("已提交系统升级意向！服务经理将在24小时内联系您。")));
            },
          )
        ],
      ),
    );

    return Scaffold(
      body: ResizableSplitPanel(
        first: Card(margin: const EdgeInsets.all(12), elevation: 2, child: tableView),
        second: Card(margin: const EdgeInsets.only(top: 12, bottom: 12, right: 12), elevation: 2, child: detailPanel),
        direction: Axis.horizontal,
        initialRatio: 0.68,
        minSize: 300,
      ),
    );
  }
}
