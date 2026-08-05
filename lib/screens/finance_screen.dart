import 'package:flutter/material.dart';
import 'package:erp/services/api_service.dart';
import 'package:erp/widgets/excel_table.dart';
import 'package:erp/widgets/resizable_panel.dart';

class FinanceScreen extends StatefulWidget {
  const FinanceScreen({Key? key}) : super(key: key);

  @override
  _FinanceScreenState createState() => _FinanceScreenState();
}

class _FinanceScreenState extends State<FinanceScreen> {
  List<Map<String, dynamic>> _financialsView = [];
  Map<String, dynamic>? _selectedItem; // selected item view row
  Map<String, dynamic>? _selectedOrderDetails; // complete order details (to fetch payment logs)
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
    _fetchFinancialsView();
  }

  Future<void> _fetchFinancialsView() async {
    setState(() => _isLoading = true);
    try {
      final list = await ApiService.getFinancialsView(
        showAll: _showAll,
        search: _isAdvancedSearch ? null : (_searchController.text.trim().isNotEmpty ? _searchController.text.trim() : null),
      );

      Iterable<Map<String, dynamic>> filtered = list;
      if (_isAdvancedSearch) {
        final cust = _advCustomerController.text.trim().toLowerCase();
        final prod = _advProductController.text.trim().toLowerCase();
        if (cust.isNotEmpty) {
          filtered = filtered.where((f) => f["customer_name"].toLowerCase().contains(cust));
        }
        if (prod.isNotEmpty) {
          filtered = filtered.where((f) => f["product_name"].toLowerCase().contains(prod));
        }
      }

      setState(() {
        _financialsView = filtered.toList();
        if (_selectedItem != null) {
          final updated = list.cast<Map<String, dynamic>?>().firstWhere((f) => f?["order_id"] == _selectedItem!["order_id"], orElse: () => null);
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
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("获取财务结算数据失败: $e")));
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
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("获取关联财务收支明细失败: $e")));
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

  void _showAddPaymentDialog() {
    if (_selectedItem == null) return;

    final formKey = GlobalKey<FormState>();
    final amountController = TextEditingController(text: _selectedItem!["pending_amount"].toString());
    final remarksController = TextEditingController();
    final invoiceNoController = TextEditingController();
    final invoiceImgController = TextEditingController();
    final dateController = TextEditingController(text: "${DateTime.now().year}-${DateTime.now().month.toString().padLeft(2, '0')}-${DateTime.now().day.toString().padLeft(2, '0')}");
    bool isInvoiced = false;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final isSale = _selectedItem!["type"] == "销售";
            return AlertDialog(
              title: Text("登记财务流水 (${isSale ? '登记收款入账' : '登记付款核销'})"),
              content: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text("关联订单号: ${_selectedItem!['order_code']}", style: const TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 6),
                      Text("往来客户: ${_selectedItem!['customer_name']}"),
                      Text("订单总额: ￥${_selectedItem!['total_amount'].toStringAsFixed(2)}"),
                      Text("未付余款: ￥${_selectedItem!['pending_amount'].toStringAsFixed(2)}", style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: amountController,
                        decoration: const InputDecoration(labelText: "本次流水平账金额 (元) *", border: OutlineInputBorder()),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return "金额必填";
                          final double? val = double.tryParse(v);
                          if (val == null || val <= 0) return "请输入大于0的正确金额";
                          if (val > _selectedItem!["pending_amount"] + 0.01) {
                            return "超出订单剩余平账限额 (${_selectedItem!['pending_amount']})";
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: dateController,
                        readOnly: true,
                        decoration: InputDecoration(
                          labelText: "收/付款日期 *",
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
                      CheckboxListTile(
                        title: const Text("是否同步开具/索取发票附件"),
                        value: isInvoiced,
                        onChanged: (val) {
                          if (val != null) {
                            setDialogState(() => isInvoiced = val);
                          }
                        },
                        controlAffinity: ListTileControlAffinity.leading,
                        contentPadding: EdgeInsets.zero,
                      ),
                      if (isInvoiced) ...[
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: invoiceNoController,
                          decoration: const InputDecoration(labelText: "发票号码 *", border: OutlineInputBorder()),
                          validator: (v) => (v == null || v.trim().isEmpty) ? "发票号码必填" : null,
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: invoiceImgController,
                                decoration: const InputDecoration(labelText: "发票扫描件/图片网址", border: OutlineInputBorder()),
                              ),
                            ),
                            const SizedBox(width: 8),
                            ElevatedButton(
                              onPressed: () async {
                                final newUrl = await ApiService.uploadFile("invoice_${DateTime.now().millisecondsSinceEpoch}.jpg", [1, 2, 3]);
                                setDialogState(() {
                                  invoiceImgController.text = newUrl;
                                });
                              },
                              child: const Text("上传"),
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: remarksController,
                        decoration: const InputDecoration(labelText: "收付款流水备注", border: OutlineInputBorder()),
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
                        await ApiService.createFinancialRecord({
                          "order_id": _selectedItem!["order_id"].toString(),
                          "amount": amountController.text.trim(),
                          "payment_date": dateController.text.trim(),
                          "is_invoiced": isInvoiced.toString(),
                          "invoice_no": invoiceNoController.text.trim(),
                          "invoice_image_url": invoiceImgController.text.trim(),
                          "remarks": remarksController.text.trim()
                        });
                        Navigator.of(context).pop();
                        _fetchFinancialsView();
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("财务收付款登记流水录入对账成功！")));
                      } catch (e) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("登记失败: $e")));
                      }
                    }
                  },
                  child: const Text("保存流水分账"),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showEditLogDialog(Map<String, dynamic> log) {
    final formKey = GlobalKey<FormState>();
    final amountController = TextEditingController(text: log["amount"].toString());
    final remarksController = TextEditingController(text: log["remarks"] ?? "");
    final invoiceNoController = TextEditingController(text: log["invoice_no"] ?? "");
    final invoiceImgController = TextEditingController(text: log["invoice_image_url"] ?? "");
    final dateController = TextEditingController(text: log["payment_date"]);
    bool isInvoiced = log["is_invoiced"] == true;

    // max_allowed = order.total_amount - sum(other_financials)
    final double totalAmount = _selectedOrderDetails!["total_amount"];
    final double otherFinancialsTotal = (_selectedOrderDetails!["financials"] as List).where((f) => f["id"] != log["id"]).fold(0.0, (sum, f) => sum + f["amount"] as double);
    final double maxAllowed = totalAmount - otherFinancialsTotal;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text("编辑收付款明细记录"),
              content: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text("关联订单号: ${_selectedOrderDetails!['code']}"),
                      Text("订单总结算额: ￥${totalAmount.toStringAsFixed(2)}"),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: amountController,
                        decoration: InputDecoration(
                          labelText: "金额 (元) *",
                          border: const OutlineInputBorder(),
                          helperText: "最大可修改对账上线: ￥${maxAllowed.toStringAsFixed(2)}",
                        ),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return "金额必填";
                          final val = double.tryParse(v);
                          if (val == null || val <= 0) return "请输入大于0的正确金额";
                          if (val > maxAllowed + 0.01) {
                            return "超出订单剩余允许的对账上限: ￥${maxAllowed.toStringAsFixed(2)}";
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: dateController,
                        readOnly: true,
                        decoration: InputDecoration(
                          labelText: "结算流转时间 *",
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
                      CheckboxListTile(
                        title: const Text("是否同步开具/索取发票附件"),
                        value: isInvoiced,
                        onChanged: (val) {
                          if (val != null) {
                            setDialogState(() => isInvoiced = val);
                          }
                        },
                        controlAffinity: ListTileControlAffinity.leading,
                        contentPadding: EdgeInsets.zero,
                      ),
                      if (isInvoiced) ...[
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: invoiceNoController,
                          decoration: const InputDecoration(labelText: "发票号码 *", border: OutlineInputBorder()),
                          validator: (v) => (v == null || v.trim().isEmpty) ? "发票号码必填" : null,
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: invoiceImgController,
                                decoration: const InputDecoration(labelText: "发票图片网址", border: OutlineInputBorder()),
                              ),
                            ),
                            const SizedBox(width: 8),
                            ElevatedButton(
                              onPressed: () async {
                                final newUrl = await ApiService.uploadFile("invoice_${DateTime.now().millisecondsSinceEpoch}.jpg", [1, 2, 3]);
                                setDialogState(() {
                                  invoiceImgController.text = newUrl;
                                });
                              },
                              child: const Text("上传"),
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: remarksController,
                        decoration: const InputDecoration(labelText: "对账说明", border: OutlineInputBorder()),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text("取消")),
                IconButton(
                  icon: const Icon(Icons.delete_forever, color: Colors.red),
                  tooltip: "彻底删除此笔财务流水",
                  onPressed: () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text("确定删除此账期流水记录吗？"),
                        actions: [
                          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text("取消")),
                          TextButton(onPressed: () => Navigator.of(context).pop(true), child: const Text("删除")),
                        ],
                      ),
                    );
                    if (confirm == true) {
                      try {
                        await ApiService.deleteFinancialRecord(log["id"]);
                        Navigator.of(context).pop();
                        _fetchFinancialsView();
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("已删除流水分账")));
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
                        await ApiService.updateFinancialRecord(log["id"], {
                          "amount": amountController.text.trim(),
                          "payment_date": dateController.text.trim(),
                          "is_invoiced": isInvoiced.toString(),
                          "invoice_no": invoiceNoController.text.trim(),
                          "invoice_image_url": invoiceImgController.text.trim(),
                          "remarks": remarksController.text.trim()
                        });
                        Navigator.of(context).pop();
                        _fetchFinancialsView();
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("流水账单对账修改成功")));
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
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final excelCols = [
      ExcelColumn(label: "关联订单号", width: 120),
      ExcelColumn(label: "类型", width: 80),
      ExcelColumn(label: "客户名称", width: 150),
      ExcelColumn(label: "商品名称", width: 150),
      ExcelColumn(label: "规格", width: 110),
      ExcelColumn(label: "待结金额(元)", width: 110),
      ExcelColumn(label: "已结金额(元)", width: 110),
      ExcelColumn(label: "已开发票金额", width: 110),
      ExcelColumn(label: "待开发票金额", width: 110),
      ExcelColumn(label: "总成交金额", width: 110),
    ];

    final List<List<Widget>> excelRows = _financialsView.map((f) {
      final isSelected = _selectedItem?["order_id"] == f["order_id"];
      final isSale = f["type"] == "销售";

      return <Widget>[
        InkWell(
          onTap: () {
            setState(() => _selectedItem = f);
            _fetchOrderDetails(f["order_id"]);
          },
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(isSelected ? Icons.check_circle : Icons.radio_button_off, size: 14, color: isSelected ? Colors.green : Colors.grey),
              const SizedBox(width: 4),
              Text(f["order_code"], style: const TextStyle(fontFamily: "monospace", color: Colors.indigo, fontWeight: FontWeight.bold)),
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
            f["type"],
            style: TextStyle(color: isSale ? Colors.purple[800] : Colors.teal[800], fontSize: 11, fontWeight: FontWeight.bold),
          ),
        ),
        Text(f["customer_name"], overflow: TextOverflow.ellipsis),
        Text(f["product_name"], overflow: TextOverflow.ellipsis),
        Text(f["product_specs"], overflow: TextOverflow.ellipsis),
        Text("￥${f['pending_amount'].toStringAsFixed(2)}", style: TextStyle(fontWeight: FontWeight.bold, color: f['pending_amount'] > 0 ? Colors.red : Colors.grey)),
        Text("￥${f['paid_amount'].toStringAsFixed(2)}", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
        Text("￥${f['invoiced_amount'].toStringAsFixed(2)}"),
        Text("￥${f['pending_invoice_amount'].toStringAsFixed(2)}"),
        Text("￥${f['total_amount'].toStringAsFixed(2)}", style: const TextStyle(fontWeight: FontWeight.bold)),
      ];
    }).toList();

    // Table view
    Widget tableView = ExcelTable(
      columns: excelCols,
      rowCount: _financialsView.length,
      rows: excelRows,
      headerActions: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            Expanded(
              child: AnimatedCrossFade(
                firstChild: TextField(
                  controller: _searchController,
                  onChanged: (v) => _fetchFinancialsView(),
                  decoration: InputDecoration(
                    hintText: "检索待收付款财务结算订单...",
                    prefixIcon: const Icon(Icons.attach_money),
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
                        onChanged: (v) => _fetchFinancialsView(),
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
                        onChanged: (v) => _fetchFinancialsView(),
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
                  _fetchFinancialsView();
                });
              },
            ),
            const SizedBox(width: 12),
            Row(
              children: [
                const Text("显示已结清完成订单", style: TextStyle(fontSize: 12)),
                Switch(
                  value: _showAll,
                  onChanged: (val) {
                    setState(() {
                      _showAll = val;
                      _fetchFinancialsView();
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
              "在左侧选择需要收付记账、或者开具核销发票的行进行深度财务控制",
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
                                  "财务清账控制台: ${_selectedItem!['order_code']}",
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
                            title: const Text("买家 / 卖家客户名称"),
                            subtitle: Text(_selectedItem!["customer_name"]),
                          ),
                          ListTile(
                            dense: true,
                            title: const Text("结算对账概况"),
                            subtitle: Text("订单总数: ${_selectedOrderDetails!['quantity']} | 单价: ￥${_selectedOrderDetails!['unit_price']} | 总核销额: ￥${_selectedItem!['total_amount'].toStringAsFixed(2)}"),
                          ),
                          ListTile(
                            dense: true,
                            title: const Text("清账状态进度"),
                            subtitle: Text("未结付尾款: ￥${_selectedItem!['pending_amount'].toStringAsFixed(2)} | 已平款项: ￥${_selectedItem!['paid_amount'].toStringAsFixed(2)}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.red)),
                          ),
                          const SizedBox(height: 12),
                          if (_selectedItem!["pending_amount"] > 0.01)
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.indigo,
                                foregroundColor: Colors.white,
                              ),
                              icon: const Icon(Icons.payment),
                              label: Text("登记财务流水流转 (${_selectedItem!['type'] == '销售' ? '收款入账' : '付款核销'})"),
                              onPressed: _showAddPaymentDialog,
                            )
                          else
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(color: Colors.green[50], borderRadius: BorderRadius.circular(6)),
                              child: const Row(
                                children: [
                                  Icon(Icons.check_circle, color: Colors.green),
                                  SizedBox(width: 8),
                                  Text("本订单对应全部资金款项均已结清！", style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 13)),
                                ],
                              ),
                            ),
                          const Divider(height: 32),
                          const Text("历史流水分账与发票核对:", style: TextStyle(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 8),
                          if ((_selectedOrderDetails!["financials"] as List).isEmpty)
                            const Text("该订单暂无任何流水分账记录", style: TextStyle(color: Colors.grey, fontSize: 11, fontStyle: FontStyle.italic))
                          else
                            ListView.separated(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: (_selectedOrderDetails!["financials"] as List).length,
                              separatorBuilder: (_, __) => const Divider(),
                              itemBuilder: (context, index) {
                                final log = _selectedOrderDetails!["financials"][index];

                                return ListTile(
                                  dense: true,
                                  leading: Icon(log["is_invoiced"] == true ? Icons.receipt_long : Icons.payment_outlined, color: Colors.blue),
                                  title: Text("结算金额: ￥${log['amount'].toStringAsFixed(2)} 元"),
                                  subtitle: Text("结算时间: ${log['payment_date']}\n发票状态: ${log['is_invoiced'] ? '发票已开 [' + log['invoice_no'] + ']' : '暂无发票附件'}"),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      if (log["is_invoiced"] == true && log["invoice_image_url"] != null && log["invoice_image_url"].toString().isNotEmpty)
                                        IconButton(
                                          icon: const Icon(Icons.picture_as_pdf, color: Colors.red, size: 18),
                                          tooltip: "查看发票图片/PDF附件",
                                          onPressed: () {
                                            showDialog(
                                              context: context,
                                              builder: (context) => AlertDialog(
                                                title: const Text("发票扫描件预览"),
                                                content: Column(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    const Icon(Icons.cloud_done, size: 48, color: Colors.green),
                                                    const SizedBox(height: 12),
                                                    Text("发票号码: ${log['invoice_no']}"),
                                                    Text("附件地址: ${log['invoice_image_url']}", style: const TextStyle(fontSize: 10, color: Colors.grey)),
                                                  ],
                                                ),
                                                actions: [TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text("确定"))],
                                              ),
                                            );
                                          },
                                        ),
                                      IconButton(
                                        icon: const Icon(Icons.edit, size: 16, color: Colors.blue),
                                        onPressed: () => _showEditLogDialog(log),
                                      ),
                                    ],
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
        onPressed: _fetchFinancialsView,
        child: const Icon(Icons.refresh, color: Colors.white),
      ),
    );
  }
}
