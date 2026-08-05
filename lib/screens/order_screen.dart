import 'package:flutter/material.dart';
import 'package:erp/services/api_service.dart';
import 'package:erp/widgets/excel_table.dart';
import 'package:erp/widgets/resizable_panel.dart';
import 'package:erp/widgets/double_confirm_dialog.dart';

class OrderScreen extends StatefulWidget {
  const OrderScreen({Key? key}) : super(key: key);

  @override
  _OrderScreenState createState() => _OrderScreenState();
}

class _OrderScreenState extends State<OrderScreen> {
  List<Map<String, dynamic>> _orders = [];
  Map<String, dynamic>? _selectedOrder;
  Map<String, dynamic>? _selectedOrderDetails;
  bool _isLoading = false;
  bool _isDetailsLoading = false;

  bool _showCompleted = false;
  final TextEditingController _searchController = TextEditingController();

  // Advanced search states
  bool _isAdvancedSearch = false;
  final TextEditingController _advCustomerController = TextEditingController();
  final TextEditingController _advProductController = TextEditingController();

  // Pickers for dialogs
  List<Map<String, dynamic>> _availableProducts = [];
  List<Map<String, dynamic>> _availableCustomers = [];

  @override
  void initState() {
    super.initState();
    _fetchOrders();
    _loadLookups();
  }

  Future<void> _fetchOrders() async {
    setState(() => _isLoading = true);
    try {
      final list = await ApiService.getOrders(
        showCompleted: _showCompleted,
        search: _isAdvancedSearch ? null : (_searchController.text.trim().isNotEmpty ? _searchController.text.trim() : null),
      );

      Iterable<Map<String, dynamic>> filtered = list;
      if (_isAdvancedSearch) {
        final cust = _advCustomerController.text.trim().toLowerCase();
        final prod = _advProductController.text.trim().toLowerCase();
        if (cust.isNotEmpty) {
          filtered = filtered.where((o) => o["customer_name"].toLowerCase().contains(cust));
        }
        if (prod.isNotEmpty) {
          filtered = filtered.where((o) => o["product_name"].toLowerCase().contains(prod));
        }
      }

      setState(() {
        _orders = filtered.toList();
        if (_selectedOrder != null) {
          final updated = _orders.cast<Map<String, dynamic>?>().firstWhere((o) => o?["id"] == _selectedOrder!["id"], orElse: () => null);
          if (updated != null) {
            _selectedOrder = updated;
            _fetchDetails(updated["id"]);
          }
        }
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("获取订单列表失败: $e")));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadLookups() async {
    try {
      final prods = await ApiService.getProducts(showOffShelf: true);
      final custs = await ApiService.getCustomers();
      setState(() {
        _availableProducts = prods;
        _availableCustomers = custs;
      });
    } catch (_) {}
  }

  Future<void> _fetchDetails(int id) async {
    setState(() => _isDetailsLoading = true);
    try {
      final details = await ApiService.getOrderDetails(id);
      setState(() {
        _selectedOrderDetails = details;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("获取订单详情失败: $e")));
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

  void _showAddOrEditOrderDialog({Map<String, dynamic>? order}) {
    final bool isEdit = order != null;
    final formKey = GlobalKey<FormState>();

    final codeController = TextEditingController(text: order?["code"] ?? "");
    final qtyController = TextEditingController(text: order?["quantity"]?.toString() ?? "0");
    final priceController = TextEditingController(text: order?["unit_price"]?.toString() ?? "0.0");
    final orderDateController = TextEditingController(text: order?["order_date"] ?? "2024-05-15");
    final deliveryDateController = TextEditingController(text: order?["delivery_date"] ?? "2024-06-15");

    String orderType = order?["type"] ?? "销售";
    int? selectedCustId = order?["customer_id"];
    int? selectedProdId = order?["product_id"];
    String orderStatus = order?["status"] ?? "进行中";

    // Prefill specs if we edit or when we select product
    String productSpecsDisplay = "";
    if (isEdit) {
      productSpecsDisplay = order["product_specs"] ?? "";
    }

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(isEdit ? "修改订单资料" : "新建订单信息"),
              content: Container(
                width: 500,
                child: Form(
                  key: formKey,
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        DropdownButtonFormField<String>(
                          value: orderType,
                          decoration: const InputDecoration(labelText: "进/销类型 *", border: OutlineInputBorder()),
                          items: const [
                            DropdownMenuItem(value: "采购", child: Text("采购")),
                            DropdownMenuItem(value: "销售", child: Text("销售")),
                          ],
                          onChanged: (val) {
                            if (val != null) {
                              setDialogState(() => orderType = val);
                            }
                          },
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: codeController,
                          decoration: const InputDecoration(labelText: "订单编号 (不填则自动生成)", border: OutlineInputBorder()),
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<int>(
                          value: selectedCustId,
                          decoration: const InputDecoration(labelText: "客户选择 *", border: OutlineInputBorder()),
                          items: _availableCustomers.map((c) {
                            return DropdownMenuItem<int>(
                              value: c["id"],
                              child: Text("[${c['code']}] ${c['name']}"),
                            );
                          }).toList(),
                          validator: (v) => v == null ? "请选择客户" : null,
                          onChanged: (val) => setDialogState(() => selectedCustId = val),
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<int>(
                          value: selectedProdId,
                          decoration: const InputDecoration(labelText: "对应商品 *", border: OutlineInputBorder()),
                          items: _availableProducts.map((p) {
                            return DropdownMenuItem<int>(
                              value: p["id"],
                              child: Text("[${p['code']}] ${p['name']}"),
                            );
                          }).toList(),
                          validator: (v) => v == null ? "请选择商品" : null,
                          onChanged: (val) {
                            if (val != null) {
                              final pObj = _availableProducts.firstWhere((p) => p["id"] == val);
                              setDialogState(() {
                                selectedProdId = val;
                                productSpecsDisplay = pObj["specs"];
                              });
                            }
                          },
                        ),
                        if (productSpecsDisplay.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text("商品规格: $productSpecsDisplay", style: const TextStyle(fontSize: 12, color: Colors.indigo, fontWeight: FontWeight.bold)),
                        ],
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: qtyController,
                          decoration: const InputDecoration(labelText: "数量 * (需大于等于0)", border: OutlineInputBorder()),
                          keyboardType: TextInputType.number,
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) return "数量必填";
                            if (int.tryParse(v) == null || int.parse(v) < 0) return "数量需为大于等于0的整数";
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: priceController,
                          decoration: const InputDecoration(labelText: "单价 (元) *", border: OutlineInputBorder()),
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) return "单价必填";
                            if (double.tryParse(v) == null || double.parse(v) < 0) return "单价有误";
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: orderDateController,
                          readOnly: true,
                          decoration: InputDecoration(
                            labelText: "下单时间 *",
                            border: const OutlineInputBorder(),
                            suffixIcon: IconButton(
                              icon: const Icon(Icons.calendar_month),
                              onPressed: () async {
                                final d = await _selectDate(context, orderDateController.text);
                                setDialogState(() => orderDateController.text = d);
                              },
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: deliveryDateController,
                          readOnly: true,
                          decoration: InputDecoration(
                            labelText: "交货时间 *",
                            border: const OutlineInputBorder(),
                            suffixIcon: IconButton(
                              icon: const Icon(Icons.calendar_month),
                              onPressed: () async {
                                final d = await _selectDate(context, deliveryDateController.text);
                                setDialogState(() => deliveryDateController.text = d);
                              },
                            ),
                          ),
                        ),
                        if (isEdit) ...[
                          const SizedBox(height: 12),
                          DropdownButtonFormField<String>(
                            value: orderStatus,
                            decoration: const InputDecoration(labelText: "订单状态", border: OutlineInputBorder()),
                            items: const [
                              DropdownMenuItem(value: "进行中", child: Text("进行中")),
                              DropdownMenuItem(value: "已完成", child: Text("已完成")),
                            ],
                            onChanged: (val) {
                              if (val != null) {
                                setDialogState(() => orderStatus = val);
                              }
                            },
                          ),
                        ]
                      ],
                    ),
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text("取消"),
                ),
                ElevatedButton(
                  onPressed: () async {
                    if (formKey.currentState!.validate()) {
                      try {
                        final body = {
                          "type": orderType,
                          "customer_id": selectedCustId.toString(),
                          "product_id": selectedProdId.toString(),
                          "quantity": qtyController.text.trim(),
                          "unit_price": priceController.text.trim(),
                          "order_date": orderDateController.text.trim(),
                          "delivery_date": deliveryDateController.text.trim(),
                          "code": codeController.text.trim(),
                        };

                        if (isEdit) {
                          body["status"] = orderStatus;
                          await ApiService.updateOrder(order["id"], body);
                        } else {
                          await ApiService.createOrder(body);
                        }
                        Navigator.of(context).pop();
                        _fetchOrders();
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(isEdit ? "更新成功" : "创建成功")));
                      } catch (err) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("保存失败: $err")));
                      }
                    }
                  },
                  child: const Text("保存"),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _deleteOrder(Map<String, dynamic> order) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => DoubleConfirmDialog(
        title: "确定彻底删除订单「${order['code']}」吗？",
        content: "警告：只能在没有任何相关的实际出入库发货记录、以及没有相关的任何财务收付款流水记录的前提下才可以执行删除！",
      ),
    );

    if (confirm == true) {
      try {
        await ApiService.deleteOrder(order["id"]);
        setState(() {
          _selectedOrder = null;
          _selectedOrderDetails = null;
        });
        _fetchOrders();
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("订单删除成功")));
      } catch (err) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text("拒绝删除"),
            content: Text(err.toString()),
            actions: [
              TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text("确定")),
            ],
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final excelCols = [
      ExcelColumn(label: "订单编号", width: 120),
      ExcelColumn(label: "采购/销售", width: 90),
      ExcelColumn(label: "客户名称", width: 150),
      ExcelColumn(label: "商品名称", width: 150),
      ExcelColumn(label: "规格", width: 110),
      ExcelColumn(label: "数量", width: 80),
      ExcelColumn(label: "单价(元)", width: 80),
      ExcelColumn(label: "总金额", width: 100),
      ExcelColumn(label: "双重进度指示器", width: 110),
      ExcelColumn(label: "下单日期", width: 110),
      ExcelColumn(label: "交货限期", width: 110),
    ];

    final List<List<Widget>> excelRows = _orders.map((o) {
      final isSelected = _selectedOrder?["id"] == o["id"];
      final isSale = o["type"] == "销售";

      return <Widget>[
        InkWell(
          onTap: () {
            setState(() => _selectedOrder = o);
            _fetchDetails(o["id"]);
          },
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(isSelected ? Icons.check_circle : Icons.radio_button_off, size: 14, color: isSelected ? Colors.green : Colors.grey),
              const SizedBox(width: 4),
              Text(o["code"], style: const TextStyle(fontFamily: "monospace", color: Colors.indigo, fontWeight: FontWeight.bold)),
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
            o["type"],
            style: TextStyle(color: isSale ? Colors.purple[800] : Colors.teal[800], fontSize: 11, fontWeight: FontWeight.bold),
          ),
        ),
        Text(o["customer_name"], overflow: TextOverflow.ellipsis),
        Text(o["product_name"], overflow: TextOverflow.ellipsis),
        Text(o["product_specs"], overflow: TextOverflow.ellipsis),
        Text(o["quantity"].toString(), style: const TextStyle(fontWeight: FontWeight.bold)),
        Text("￥${o['unit_price'].toStringAsFixed(2)}"),
        Text("￥${o['total_amount'].toStringAsFixed(2)}", style: const TextStyle(fontWeight: FontWeight.bold)),
        // "进度（用两个圈展示进度，里边是收（付）款进度，外边是商品交付货进度）"
        _buildConcentricProgress(
          deliveryPct: o["delivery_progress"],
          paymentPct: o["payment_progress"],
          deliveredQty: (o["delivered_quantity"] as num?)?.toDouble() ?? 0.0,
          totalQty: (o["quantity"] as num).toDouble(),
          paidAmt: (o["paid_amount"] as num?)?.toDouble() ?? 0.0,
          totalAmt: (o["total_amount"] as num).toDouble(),
        ),
        Text(o["order_date"]),
        Text(o["delivery_date"]),
      ];
    }).toList();

    // Table
    Widget tableView = ExcelTable(
      columns: excelCols,
      rowCount: _orders.length,
      rows: excelRows,
      headerActions: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            Expanded(
              child: AnimatedCrossFade(
                firstChild: TextField(
                  controller: _searchController,
                  onChanged: (v) => _fetchOrders(),
                  decoration: InputDecoration(
                    hintText: "按编号、客户、商品或规格检索订单...",
                    prefixIcon: const Icon(Icons.search, size: 20),
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
                        onChanged: (v) => _fetchOrders(),
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
                        onChanged: (v) => _fetchOrders(),
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
                  _fetchOrders();
                });
              },
            ),
            const SizedBox(width: 12),
            Row(
              children: [
                const Text("显示已完成订单", style: TextStyle(fontSize: 12)),
                Switch(
                  value: _showCompleted,
                  onChanged: (val) {
                    setState(() {
                      _showCompleted = val;
                      _fetchOrders();
                    });
                  },
                ),
              ],
            ),
            const SizedBox(width: 12),
            ElevatedButton.icon(
              icon: const Icon(Icons.add),
              label: const Text("新建订单"),
              onPressed: () => _showAddOrEditOrderDialog(),
            ),
          ],
        ),
      ),
    );

    // Detail Panel
    Widget detailPanel = _selectedOrder == null
        ? const Center(
            child: Text(
              "在左侧选择行以查看订单深度交互面板",
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
                              Text(
                                "订单详情: ${_selectedOrderDetails!['code']}",
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                              ),
                              IconButton(
                                icon: const Icon(Icons.close),
                                onPressed: () => setState(() {
                                  _selectedOrder = null;
                                  _selectedOrderDetails = null;
                                }),
                              )
                            ],
                          ),
                          const Divider(),
                          ListTile(
                            dense: true,
                            title: const Text("类型 / 状态"),
                            subtitle: Text("${_selectedOrderDetails!['type']} | 状态: ${_selectedOrderDetails!['status']}", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
                          ),
                          ListTile(
                            dense: true,
                            title: const Text("相关客户"),
                            subtitle: Text("${_selectedOrderDetails!['customer_name']} (联系人: ${_selectedOrderDetails!['customer_contact_person'] ?? '无'} | ${_selectedOrderDetails!['customer_contact_phone'] ?? '无'})\n送货地址: ${_selectedOrderDetails!['customer_address'] ?? '无'}"),
                          ),
                          ListTile(
                            dense: true,
                            title: const Text("商品详情规格"),
                            subtitle: Text("产品: ${_selectedOrderDetails!['product_name']} [${_selectedOrderDetails!['product_specs']}]"),
                          ),
                          ListTile(
                            dense: true,
                            title: const Text("总额 & 数量"),
                            subtitle: Text("数量: ${_selectedOrderDetails!['quantity']} | 单价: ￥${_selectedOrderDetails!['unit_price'].toStringAsFixed(2)} | 总金额: ￥${_selectedOrderDetails!['total_amount'].toStringAsFixed(2)}", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.indigo, fontSize: 13)),
                          ),
                          ListTile(
                            dense: true,
                            title: const Text("日期期限"),
                            subtitle: Text("开单日期: ${_selectedOrderDetails!['order_date']} | 交付截至: ${_selectedOrderDetails!['delivery_date']}"),
                          ),
                          const Divider(),
                          const Text("双重进度占比:", style: TextStyle(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              Column(
                                children: [
                                  _buildConcentricProgress(
                                    deliveryPct: _selectedOrderDetails!["delivery_progress"],
                                    paymentPct: _selectedOrderDetails!["payment_progress"],
                                    size: 80.0,
                                    deliveredQty: (_selectedOrderDetails!["delivered_quantity"] as num?)?.toDouble() ?? 0.0,
                                    totalQty: (_selectedOrderDetails!["quantity"] as num).toDouble(),
                                    paidAmt: (_selectedOrderDetails!["paid_amount"] as num?)?.toDouble() ?? 0.0,
                                    totalAmt: (_selectedOrderDetails!["total_amount"] as num).toDouble(),
                                  ),
                                  const SizedBox(height: 8),
                                  const Text("双同心圆进度指示", style: TextStyle(fontSize: 10, color: Colors.grey)),
                                ],
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text("• 交付进度(外圆): ${_selectedOrderDetails!['delivered_quantity']} / ${_selectedOrderDetails!['quantity']} (${_selectedOrderDetails!['delivery_progress'].toStringAsFixed(1)}%)", style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold, fontSize: 11)),
                                  const SizedBox(height: 4),
                                  Text("• 收付进度(内圆): ￥${_selectedOrderDetails!['paid_amount'].toStringAsFixed(2)} / ￥${_selectedOrderDetails!['total_amount'].toStringAsFixed(2)} (${_selectedOrderDetails!['payment_progress'].toStringAsFixed(1)}%)", style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 11)),
                                ],
                              ),
                            ],
                          ),
                          const Divider(),
                          // List Historical logs
                          const Text("交货历史记录列表:", style: TextStyle(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 8),
                          if ((_selectedOrderDetails!["deliveries"] as List).isEmpty)
                            const Text("尚无交货及出入库纪录", style: TextStyle(color: Colors.grey, fontSize: 11, fontStyle: FontStyle.italic))
                          else
                            ...(_selectedOrderDetails!["deliveries"] as List).map((d) {
                              return Card(
                                elevation: 0,
                                color: Colors.grey[50],
                                margin: const EdgeInsets.only(bottom: 6),
                                child: ListTile(
                                  dense: true,
                                  title: Text("交货日期: ${d['delivery_date']} | 数量: ${d['quantity']}"),
                                  subtitle: d["remarks"] != null && d["remarks"].isNotEmpty ? Text("备注: ${d['remarks']}") : null,
                                ),
                              );
                            }).toList(),
                          const SizedBox(height: 12),
                          const Text("财务收付款历史流水分账:", style: TextStyle(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 8),
                          if ((_selectedOrderDetails!["financials"] as List).isEmpty)
                            const Text("尚无任何款项往来流水", style: TextStyle(color: Colors.grey, fontSize: 11, fontStyle: FontStyle.italic))
                          else
                            ...(_selectedOrderDetails!["financials"] as List).map((f) {
                              return Card(
                                elevation: 0,
                                color: Colors.grey[50],
                                margin: const EdgeInsets.only(bottom: 6),
                                child: ListTile(
                                  dense: true,
                                  title: Text("收款日期: ${f['payment_date']} | 金额: ￥${f['amount'].toStringAsFixed(2)}"),
                                  subtitle: Text("发票: ${f['is_invoiced'] ? '已开 [${f['invoice_no']}]' : '未开'}"),
                                ),
                              );
                            }).toList(),
                          const SizedBox(height: 24),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  icon: const Icon(Icons.edit),
                                  label: const Text("修改"),
                                  onPressed: () => _showAddOrEditOrderDialog(order: _selectedOrderDetails),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.red[50],
                                    foregroundColor: Colors.red,
                                    elevation: 0,
                                  ),
                                  icon: const Icon(Icons.delete),
                                  label: const Text("物理删除"),
                                  onPressed: () => _deleteOrder(_selectedOrderDetails!),
                                ),
                              ),
                            ],
                          ),
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
        onPressed: _fetchOrders,
        child: const Icon(Icons.refresh, color: Colors.white),
      ),
    );
  }

  Widget _buildConcentricProgress({
    required double deliveryPct,
    required double paymentPct,
    double size = 32.0,
    double? deliveredQty,
    double? totalQty,
    double? paidAmt,
    double? totalAmt,
  }) {
    // Standardize bounds
    final dPct = (deliveryPct / 100.0).clamp(0.0, 1.0);
    final pPct = (paymentPct / 100.0).clamp(0.0, 1.0);

    final dQtyText = deliveredQty != null && totalQty != null
        ? "${deliveredQty.toInt()} / ${totalQty.toInt()}"
        : "${(deliveryPct).toStringAsFixed(0)}%";
    final pAmtText = paidAmt != null && totalAmt != null
        ? "￥${paidAmt.toStringAsFixed(2)} / ￥${totalAmt.toStringAsFixed(2)}"
        : "${(paymentPct).toStringAsFixed(0)}%";

    final tooltipMsg = "交付进度(外圆): $dQtyText (${deliveryPct.toStringAsFixed(1)}%)\n收付进度(内圆): $pAmtText (${paymentPct.toStringAsFixed(1)}%)";

    return Tooltip(
      message: tooltipMsg,
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E2F).withOpacity(0.95),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blueAccent.withOpacity(0.5)),
      ),
      padding: const EdgeInsets.all(12),
      textStyle: const TextStyle(color: Colors.white, fontSize: 12),
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Outer circle for delivery progress (blue)
            SizedBox(
              width: size,
              height: size,
              child: CircularProgressIndicator(
                value: dPct,
                strokeWidth: size > 40 ? 5.0 : 3.0,
                backgroundColor: Colors.blue.withOpacity(0.1),
                color: Colors.blue,
              ),
            ),
            // Inner circle for payment progress (red)
            SizedBox(
              width: size * 0.65,
              height: size * 0.65,
              child: CircularProgressIndicator(
                value: pPct,
                strokeWidth: size > 40 ? 4.0 : 2.5,
                backgroundColor: Colors.red.withOpacity(0.1),
                color: Colors.red,
              ),
            ),
            if (size > 40)
              Text(
                "${(dPct * 100).toInt()}%",
                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
              ),
          ],
        ),
      ),
    );
  }
}
