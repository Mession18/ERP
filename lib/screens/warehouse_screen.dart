import 'package:flutter/material.dart';
import 'package:erp/services/api_service.dart';
import 'package:erp/widgets/excel_table.dart';
import 'package:erp/widgets/resizable_panel.dart';

class WarehouseScreen extends StatefulWidget {
  const WarehouseScreen({Key? key}) : super(key: key);

  @override
  _WarehouseScreenState createState() => _WarehouseScreenState();
}

class _WarehouseScreenState extends State<WarehouseScreen> {
  List<Map<String, dynamic>> _deliveriesView = [];
  Map<String, dynamic>? _selectedItem; // selected item view row
  Map<String, dynamic>? _selectedOrderDetails; // complete order details (to fetch deliveries logs)
  bool _isLoading = false;
  bool _isDetailsLoading = false;

  bool _showAll = false; // toggle completed orders
  final TextEditingController _searchController = TextEditingController();

  // Advanced search states
  bool _isAdvancedSearch = false;
  final TextEditingController _advCustomerController = TextEditingController();
  final TextEditingController _advProductController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchDeliveriesView();
  }

  Future<void> _fetchDeliveriesView() async {
    setState(() => _isLoading = true);
    try {
      final list = await ApiService.getDeliveriesView(
        showAll: _showAll,
        search: _isAdvancedSearch ? null : (_searchController.text.trim().isNotEmpty ? _searchController.text.trim() : null),
      );

      Iterable<Map<String, dynamic>> filtered = list;
      if (_isAdvancedSearch) {
        final cust = _advCustomerController.text.trim().toLowerCase();
        final prod = _advProductController.text.trim().toLowerCase();
        if (cust.isNotEmpty) {
          filtered = filtered.where((d) => d["customer_name"].toLowerCase().contains(cust));
        }
        if (prod.isNotEmpty) {
          filtered = filtered.where((d) => d["product_name"].toLowerCase().contains(prod));
        }
      }

      setState(() {
        _deliveriesView = filtered.toList();
        if (_selectedItem != null) {
          final updated = list.cast<Map<String, dynamic>?>().firstWhere((d) => d?["order_id"] == _selectedItem!["order_id"], orElse: () => null);
          if (updated != null) {
            _selectedItem = updated;
            _fetchOrderDetails(updated["order_id"]);
          } else {
            _selectedItem = null;
            _selectedOrderDetails = null;
          }
        }
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("获取进出库数据失败: $e")));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchOrderDetails(int orderId) async {
    setState(() => _isDetailsLoading = true);
    try {
      final details = await ApiService.getOrderDetails(orderId);
      setState(() {
        _selectedOrderDetails = details;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("获取关联交货流水失败: $e")));
    } finally {
      setState(() => _isDetailsLoading = false);
    }
  }

  Future<String> _selectDate(BuildContext context, String initial) async {
    DateTime initDate = DateTime.tryParse(initial) ?? DateTime.now();
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      return "${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}";
    }
    return initial;
  }

  void _showAddDeliveryDialog() {
    if (_selectedItem == null) return;

    final formKey = GlobalKey<FormState>();
    final qtyController = TextEditingController(text: _selectedItem!["pending_quantity"].toString());
    final remarksController = TextEditingController();
    final dateController = TextEditingController(text: "${DateTime.now().year}-${DateTime.now().month.toString().padLeft(2, '0')}-${DateTime.now().day.toString().padLeft(2, '0')}");

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text("登记新的进出库货品 (${_selectedItem!['type'] == '销售' ? '出库发货' : '入库收货'})"),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text("订单编号: ${_selectedItem!['order_code']}", style: const TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  Text("商品名称: ${_selectedItem!['product_name']} [${_selectedItem!['product_specs']}]"),
                  Text("现有库存: ${_selectedItem!['stock_quantity']} 件"),
                  Text("待交货总数: ${_selectedItem!['pending_quantity']} 件", style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: qtyController,
                    decoration: const InputDecoration(labelText: "本次交付数量 *", border: OutlineInputBorder()),
                    keyboardType: TextInputType.number,
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return "数量必填";
                      final int? val = int.tryParse(v);
                      if (val == null || val <= 0) return "必须为大于0的整数";
                      if (val > _selectedItem!["pending_quantity"]) {
                        return "不可大于待交货数量 (${_selectedItem!['pending_quantity']})";
                      }
                      if (_selectedItem!["type"] == "销售" && val > _selectedItem!["stock_quantity"]) {
                        return "库存不足！最多可交货数量为 ${_selectedItem!['stock_quantity']}";
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: dateController,
                    readOnly: true,
                    decoration: InputDecoration(
                      labelText: "交货录入时间 * (可修改)",
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.calendar_month),
                        onPressed: () async {
                          final d = await _selectDate(context, dateController.text);
                          dateController.text = d;
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: remarksController,
                    decoration: const InputDecoration(labelText: "交货备注/说明", border: OutlineInputBorder()),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text("取消")),
            ElevatedButton(
              onPressed: () async {
                if (formKey.currentState!.validate()) {
                  try {
                    await ApiService.createDelivery({
                      "order_id": _selectedItem!["order_id"].toString(),
                      "quantity": qtyController.text.trim(),
                      "delivery_date": dateController.text.trim(),
                      "remarks": remarksController.text.trim()
                    });
                    Navigator.of(context).pop();
                    _fetchDeliveriesView();
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("进出库交货登记成功！")));
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("录入失败: $e")));
                  }
                }
              },
              child: const Text("保存登记"),
            ),
          ],
        );
      },
    );
  }

  void _showEditLogDialog(Map<String, dynamic> log) {
    final formKey = GlobalKey<FormState>();
    final qtyController = TextEditingController(text: log["quantity"].toString());
    final remarksController = TextEditingController(text: log["remarks"] ?? "");
    final dateController = TextEditingController(text: log["delivery_date"]);

    // Calculate maximum allowed for this log item
    // max_allowed = order.quantity - sum(other_deliveries)
    final otherDels = (_selectedOrderDetails!["deliveries"] as List).where((d) => d["id"] != log["id"]).fold(0, (sum, d) => sum + d["quantity"] as int);
    final maxAllowed = _selectedOrderDetails!["quantity"] - otherDels;

    // Max stock available
    final isSale = _selectedOrderDetails!["type"] == "销售";
    final maxStockAllowed = _selectedItem!["stock_quantity"] + log["quantity"]; // current stock + reverted quantity

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("修改交货明细记录"),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text("关联订单: ${_selectedOrderDetails!['code']}"),
                  Text("交货限期: ${_selectedOrderDetails!['delivery_date']}"),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: qtyController,
                    decoration: InputDecoration(
                      labelText: "交货数量 *",
                      border: const OutlineInputBorder(),
                      helperText: "最大可支持交货: $maxAllowed 件",
                    ),
                    keyboardType: TextInputType.number,
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return "数量必填";
                      final val = int.tryParse(v);
                      if (val == null || val <= 0) return "必须为大于0的整数";
                      if (val > maxAllowed) {
                        return "数量不能超过订单未完成待付上限: $maxAllowed";
                      }
                      if (isSale && val > maxStockAllowed) {
                        return "超出当前可用及退回后的库存总上限: $maxStockAllowed";
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: dateController,
                    readOnly: true,
                    decoration: InputDecoration(
                      labelText: "交货日期",
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.calendar_month),
                        onPressed: () async {
                          final d = await _selectDate(context, dateController.text);
                          dateController.text = d;
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: remarksController,
                    decoration: const InputDecoration(labelText: "修改备注", border: OutlineInputBorder()),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text("取消")),
            IconButton(
              icon: const Icon(Icons.delete_forever, color: Colors.red),
              tooltip: "删除此条流水分账",
              onPressed: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text("确定删除此记录并退回库存吗？"),
                    actions: [
                      TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text("取消")),
                      TextButton(onPressed: () => Navigator.of(context).pop(true), child: const Text("确认")),
                    ],
                  ),
                );
                if (confirm == true) {
                  try {
                    await ApiService.deleteDelivery(log["id"]);
                    Navigator.of(context).pop();
                    _fetchDeliveriesView();
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("已删除流水分账并还原库存")));
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("操作失败: $e")));
                  }
                }
              },
            ),
            ElevatedButton(
              onPressed: () async {
                if (formKey.currentState!.validate()) {
                  try {
                    await ApiService.updateDelivery(log["id"], {
                      "quantity": qtyController.text.trim(),
                      "delivery_date": dateController.text.trim(),
                      "remarks": remarksController.text.trim()
                    });
                    Navigator.of(context).pop();
                    _fetchDeliveriesView();
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("流水记录更新并库存对账成功")));
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("更新失败: $e")));
                  }
                }
              },
              child: const Text("保存修改"),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final excelCols = [
      ExcelColumn(label: "关联订单号", width: 120),
      ExcelColumn(label: "类型", width: 80),
      ExcelColumn(label: "客户名称", width: 160),
      ExcelColumn(label: "商品名称", width: 160),
      ExcelColumn(label: "规格属性", width: 120),
      ExcelColumn(label: "待交付量", width: 90),
      ExcelColumn(label: "已交付量", width: 90),
      ExcelColumn(label: "订单总量", width: 90),
    ];

    final List<List<Widget>> excelRows = _deliveriesView.map((d) {
      final isSelected = _selectedItem?["order_id"] == d["order_id"];
      final isSale = d["type"] == "销售";

      return <Widget>[
        InkWell(
          onTap: () {
            setState(() => _selectedItem = d);
            _fetchOrderDetails(d["order_id"]);
          },
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(isSelected ? Icons.check_circle : Icons.radio_button_off, size: 14, color: isSelected ? Colors.green : Colors.grey),
              const SizedBox(width: 4),
              Text(d["order_code"], style: const TextStyle(fontFamily: "monospace", color: Colors.indigo, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: isSale ? Colors.purple[50] : Colors.teal[50],
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            d["type"],
            style: TextStyle(color: isSale ? Colors.purple[800] : Colors.teal[800], fontSize: 11, fontWeight: FontWeight.bold),
          ),
        ),
        Text(d["customer_name"], overflow: TextOverflow.ellipsis),
        Text(d["product_name"], overflow: TextOverflow.ellipsis),
        Text(d["product_specs"], overflow: TextOverflow.ellipsis),
        Text(d["pending_quantity"].toString(), style: TextStyle(fontWeight: FontWeight.bold, color: d["pending_quantity"] > 0 ? Colors.red : Colors.grey)),
        Text(d["delivered_quantity"].toString(), style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
        Text(d["total_quantity"].toString()),
      ];
    }).toList();

    // Table view
    Widget tableView = ExcelTable(
      columns: excelCols,
      rowCount: _deliveriesView.length,
      rows: excelRows,
      headerActions: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            Expanded(
              child: AnimatedCrossFade(
                firstChild: TextField(
                  controller: _searchController,
                  onChanged: (v) => _fetchDeliveriesView(),
                  decoration: InputDecoration(
                    hintText: "检索待发货出入库订单...",
                    prefixIcon: const Icon(Icons.warehouse),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 8),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
                secondChild: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _advCustomerController,
                        onChanged: (v) => _fetchDeliveriesView(),
                        decoration: const InputDecoration(
                          hintText: "按客户名检索",
                          isDense: true,
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _advProductController,
                        onChanged: (v) => _fetchDeliveriesView(),
                        decoration: const InputDecoration(
                          hintText: "按商品名检索",
                          isDense: true,
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                  ],
                ),
                crossFadeState: _isAdvancedSearch ? CrossFadeState.showSecond : CrossFadeState.showFirst,
                duration: const Duration(milliseconds: 200),
              ),
            ),
            const SizedBox(width: 12),
            TextButton.icon(
              icon: Icon(_isAdvancedSearch ? Icons.close : Icons.tune),
              label: Text(_isAdvancedSearch ? "普通" : "高级"),
              onPressed: () {
                setState(() {
                  _isAdvancedSearch = !_isAdvancedSearch;
                  _searchController.clear();
                  _advCustomerController.clear();
                  _advProductController.clear();
                  _fetchDeliveriesView();
                });
              },
            ),
            const SizedBox(width: 12),
            Row(
              children: [
                const Text("显示隐藏订单 (已结单/已完成)", style: TextStyle(fontSize: 12)),
                Switch(
                  value: _showAll,
                  onChanged: (val) {
                    setState(() {
                      _showAll = val;
                      _fetchDeliveriesView();
                    });
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );

    // Detail panel
    Widget detailPanel = _selectedItem == null
        ? const Center(
            child: Text(
              "在左侧选择待发货/待收货行，并在此录入交割时间与数量",
              style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic),
            ),
          )
        : _isDetailsLoading
            ? const Center(child: CircularProgressIndicator())
            : _selectedOrderDetails == null
                ? const Center(child: Text("加载详情失败"))
                : Padding(
                    padding: const EdgeInsets.all(16),
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  "出入库控制台: ${_selectedItem!['order_code']}",
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.close),
                                onPressed: () => setState(() {
                                  _selectedItem = null;
                                  _selectedOrderDetails = null;
                                }),
                              ),
                            ],
                          ),
                          const Divider(),
                          ListTile(
                            dense: true,
                            title: const Text("关联货品"),
                            subtitle: Text("${_selectedItem!['product_name']} [${_selectedItem!['product_specs']}]"),
                          ),
                          ListTile(
                            dense: true,
                            title: const Text("相关往来客户"),
                            subtitle: Text(_selectedItem!["customer_name"]),
                          ),
                          ListTile(
                            dense: true,
                            title: const Text("对账统计数"),
                            subtitle: Text("订单总数: ${_selectedItem!['total_quantity']} | 已付运: ${_selectedItem!['delivered_quantity']} | 剩余待付: ${_selectedItem!['pending_quantity']}"),
                          ),
                          ListTile(
                            dense: true,
                            title: const Text("可用库存"),
                            subtitle: Text("${_selectedItem!['stock_quantity']} 件", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.blue)),
                          ),
                          const SizedBox(height: 12),
                          if (_selectedItem!["pending_quantity"] > 0)
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.indigo,
                                foregroundColor: Colors.white,
                              ),
                              icon: const Icon(Icons.add_shopping_cart),
                              label: Text("登记新的货品交割 (${_selectedItem!['type'] == '销售' ? '出库发货' : '入库收货'})"),
                              onPressed: _showAddDeliveryDialog,
                            )
                          else
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(color: Colors.green[50], borderRadius: BorderRadius.circular(6)),
                              child: const Row(
                                children: [
                                  Icon(Icons.check_circle, color: Colors.green),
                                  SizedBox(width: 8),
                                  Text("本订单货品已全部交割付运完毕！", style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 13)),
                                ],
                              ),
                            ),
                          const Divider(height: 32),
                          const Text("历史交货明细及库存流水对账:", style: TextStyle(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 8),
                          if ((_selectedOrderDetails!["deliveries"] as List).isEmpty)
                            const Text("该订单尚无任何实际交割流水记录", style: TextStyle(color: Colors.grey, fontSize: 11, fontStyle: FontStyle.italic))
                          else
                            ListView.separated(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: (_selectedOrderDetails!["deliveries"] as List).length,
                              separatorBuilder: (_, __) => const Divider(),
                              itemBuilder: (context, index) {
                                final log = _selectedOrderDetails!["deliveries"][index];

                                return ListTile(
                                  dense: true,
                                  leading: const Icon(Icons.local_shipping, size: 20),
                                  title: Text("交割数量: ${log['quantity']} 件"),
                                  subtitle: Text("交割时间: ${log['delivery_date']}\n说明: ${log['remarks'] ?? '无'}"),
                                  trailing: IconButton(
                                    icon: const Icon(Icons.edit, size: 16, color: Colors.blue),
                                    onPressed: () => _showEditLogDialog(log),
                                  ),
                                );
                              },
                            )
                        ],
                      ),
                    ),
                  );

    return Scaffold(
      body: ResizableSplitPanel(
        first: Card(margin: const EdgeInsets.all(12), elevation: 2, child: tableView),
        second: Card(margin: const EdgeInsets.only(top: 12, bottom: 12, right: 12), elevation: 2, child: detailPanel),
        direction: Axis.horizontal,
        initialRatio: 0.65,
        minSize: 300,
      ),
      floatingActionButton: FloatingActionButton(
        mini: true,
        backgroundColor: Colors.indigo,
        onPressed: _fetchDeliveriesView,
        child: const Icon(Icons.refresh, color: Colors.white),
      ),
    );
  }
}
