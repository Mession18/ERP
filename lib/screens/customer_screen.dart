import 'package:flutter/material.dart';
import 'package:erp/services/api_service.dart';
import 'package:erp/widgets/excel_table.dart';
import 'package:erp/widgets/resizable_panel.dart';
import 'package:erp/widgets/double_confirm_dialog.dart';

class CustomerScreen extends StatefulWidget {
  const CustomerScreen({Key? key}) : super(key: key);

  @override
  _CustomerScreenState createState() => _CustomerScreenState();
}

class _CustomerScreenState extends State<CustomerScreen> {
  List<Map<String, dynamic>> _customers = [];
  Map<String, dynamic>? _selectedCustomer;
  Map<String, dynamic>? _selectedCustomerDetails; // Stores deep fetch result
  bool _isLoading = false;
  bool _isDetailsLoading = false;

  // Search states
  final TextEditingController _searchController = TextEditingController();
  bool _isAdvancedSearch = false;
  final TextEditingController _advNameController = TextEditingController();
  final TextEditingController _advContactController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchCustomers();
  }

  Future<void> _fetchCustomers() async {
    setState(() => _isLoading = true);
    try {
      final list = await ApiService.getCustomers(
        search: _isAdvancedSearch ? null : _searchController.text.trim(),
        name: _isAdvancedSearch ? _advNameController.text.trim() : null,
        contactPerson: _isAdvancedSearch ? _advContactController.text.trim() : null,
      );
      setState(() {
        _customers = list;
        if (_selectedCustomer != null) {
          // If a customer was selected, update its reference
          final updated = list.cast<Map<String, dynamic>?>().firstWhere((c) => c?["id"] == _selectedCustomer!["id"], orElse: () => null);
          if (updated != null) {
            _selectedCustomer = updated;
            _fetchDetails(updated["id"]);
          }
        }
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("获取客户信息失败: $e")));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchDetails(int id) async {
    setState(() => _isDetailsLoading = true);
    try {
      final details = await ApiService.getCustomerDetails(id);
      setState(() {
        _selectedCustomerDetails = details;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("获取客户详细信息失败: $e")));
    } finally {
      setState(() => _isDetailsLoading = false);
    }
  }

  void _showAddOrEditCustomerDialog({Map<String, dynamic>? customer}) {
    final bool isEdit = customer != null;
    final formKey = GlobalKey<FormState>();
    final codeController = TextEditingController(text: customer?["code"] ?? "");
    final nameController = TextEditingController(text: customer?["name"] ?? "");
    final contactController = TextEditingController(text: customer?["contact_person"] ?? "");
    final phoneController = TextEditingController(text: customer?["contact_phone"] ?? "");
    final addressController = TextEditingController(text: customer?["address"] ?? "");
    final logoController = TextEditingController(text: customer?["logo_url"] ?? "");

    String customerType = customer?["type"] ?? "买家";

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(isEdit ? "修改客户资料" : "新建客户信息"),
              content: Container(
                width: 480,
                child: Form(
                  key: formKey,
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        DropdownButtonFormField<String>(
                          value: customerType,
                          decoration: const InputDecoration(
                            labelText: "客户类型 *",
                            border: OutlineInputBorder(),
                          ),
                          items: const [
                            DropdownMenuItem(value: "买家", child: Text("买家")),
                            DropdownMenuItem(value: "卖家", child: Text("卖家")),
                          ],
                          onChanged: (val) {
                            if (val != null) {
                              setDialogState(() {
                                customerType = val;
                              });
                            }
                          },
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: codeController,
                          decoration: const InputDecoration(
                            labelText: "客户编号 (不填则自动生成)",
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: nameController,
                          decoration: const InputDecoration(
                            labelText: "客户名 *",
                            border: OutlineInputBorder(),
                          ),
                          validator: (v) => (v == null || v.trim().isEmpty) ? "客户名必填" : null,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: contactController,
                          decoration: const InputDecoration(
                            labelText: "联系人",
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: phoneController,
                          decoration: const InputDecoration(
                            labelText: "联系电话",
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: addressController,
                          decoration: const InputDecoration(
                            labelText: "地址",
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: logoController,
                          decoration: const InputDecoration(
                            labelText: "商标/Logo 网址",
                            border: OutlineInputBorder(),
                          ),
                        ),
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
                          "type": customerType,
                          "name": nameController.text.trim(),
                          "code": codeController.text.trim(),
                          "contact_person": contactController.text.trim(),
                          "contact_phone": phoneController.text.trim(),
                          "address": addressController.text.trim(),
                          "logo_url": logoController.text.trim()
                        };

                        if (isEdit) {
                          await ApiService.updateCustomer(customer["id"], body);
                        } else {
                          await ApiService.createCustomer(body);
                        }
                        Navigator.of(context).pop();
                        _fetchCustomers();
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(isEdit ? "修改成功" : "创建成功")));
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

  Future<void> _deleteCustomer(Map<String, dynamic> customer) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => DoubleConfirmDialog(
        title: "确定删除客户「${customer['name']}」吗？",
        content: "警告：只能在跟该客户没有任何交易往来/订单的前提下才可以进行物理删除！",
      ),
    );

    if (confirm == true) {
      try {
        await ApiService.deleteCustomer(customer["id"]);
        setState(() {
          _selectedCustomer = null;
          _selectedCustomerDetails = null;
        });
        _fetchCustomers();
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("删除成功")));
      } catch (err) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text("删除受阻"),
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
    // Excel columns
    final excelCols = [
      ExcelColumn(label: "客户编号", width: 120),
      ExcelColumn(label: "客户类型", width: 90),
      ExcelColumn(label: "客户名", width: 180),
      ExcelColumn(label: "联系人", width: 110),
      ExcelColumn(label: "联系方式", width: 120),
      ExcelColumn(label: "地址", width: 180),
      ExcelColumn(label: "进行中订单数", width: 110),
      ExcelColumn(label: "待收(付)款金额", width: 120),
    ];

    final List<List<Widget>> excelRows = _customers.map((c) {
      final isSelected = _selectedCustomer?["id"] == c["id"];
      return <Widget>[
        InkWell(
          onTap: () {
            setState(() {
              _selectedCustomer = c;
            });
            _fetchDetails(c["id"]);
          },
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(isSelected ? Icons.check_circle : Icons.radio_button_off, size: 14, color: isSelected ? Colors.green : Colors.grey),
              const SizedBox(width: 4),
              Text(c["code"], style: const TextStyle(fontFamily: "monospace", color: Colors.indigo, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: c["type"] == "买家" ? Colors.blue[50] : Colors.orange[50],
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            c["type"],
            style: TextStyle(color: c["type"] == "买家" ? Colors.blue[800] : Colors.orange[800], fontSize: 11, fontWeight: FontWeight.bold),
          ),
        ),
        Text(c["name"], overflow: TextOverflow.ellipsis),
        Text(c["contact_person"] ?? "", overflow: TextOverflow.ellipsis),
        Text(c["contact_phone"] ?? "", overflow: TextOverflow.ellipsis),
        Text(c["address"] ?? "", overflow: TextOverflow.ellipsis),
        Text(c["ongoing_orders_count"].toString(), style: const TextStyle(fontWeight: FontWeight.bold)),
        Text(
          "￥${c['pending_amount'].toStringAsFixed(2)}",
          style: TextStyle(
            color: c['pending_amount'] > 0 ? (c["type"] == "买家" ? Colors.red : Colors.green) : Colors.black87,
            fontWeight: FontWeight.bold,
          ),
        ),
      ];
    }).toList();

    // Table view
    Widget tableView = ExcelTable(
      columns: excelCols,
      rowCount: _customers.length,
      rows: excelRows,
      headerActions: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            Expanded(
              child: AnimatedCrossFade(
                firstChild: TextField(
                  controller: _searchController,
                  onChanged: (v) => _fetchCustomers(),
                  decoration: InputDecoration(
                    hintText: "模糊搜索客户信息...",
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
                        controller: _advNameController,
                        onChanged: (v) => _fetchCustomers(),
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
                        controller: _advContactController,
                        onChanged: (v) => _fetchCustomers(),
                        decoration: const InputDecoration(
                          hintText: "按联系人检索",
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
              label: Text(_isAdvancedSearch ? "普通搜索" : "高级搜索"),
              onPressed: () {
                setState(() {
                  _isAdvancedSearch = !_isAdvancedSearch;
                  _searchController.clear();
                  _advNameController.clear();
                  _advContactController.clear();
                  _fetchCustomers();
                });
              },
            ),
            const SizedBox(width: 12),
            ElevatedButton.icon(
              icon: const Icon(Icons.add),
              label: const Text("新建客户"),
              onPressed: () => _showAddOrEditCustomerDialog(),
            ),
          ],
        ),
      ),
    );

    // Detail panel
    Widget detailPanel = _selectedCustomer == null
        ? const Center(
            child: Text(
              "在左侧选择客户或点击编号查看关联订单历史",
              style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic),
            ),
          )
        : _isDetailsLoading
            ? const Center(child: CircularProgressIndicator())
            : _selectedCustomerDetails == null
                ? const Center(child: Text("加载详情失败"))
                : Padding(
                    padding: const EdgeInsets.all(16),
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              if (_selectedCustomerDetails!["logo_url"] != null && _selectedCustomerDetails!["logo_url"].isNotEmpty)
                                ClipOval(
                                  child: Image.network(
                                    _selectedCustomerDetails!["logo_url"],
                                    width: 48,
                                    height: 48,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => const Icon(Icons.business, size: 48),
                                  ),
                                )
                              else
                                const Icon(Icons.business, size: 48, color: Colors.blue),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _selectedCustomerDetails!["name"],
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                                    ),
                                    Text(
                                      "客户类型: ${_selectedCustomerDetails!['type']}",
                                      style: const TextStyle(color: Colors.grey, fontSize: 13),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.close),
                                onPressed: () => setState(() {
                                  _selectedCustomer = null;
                                  _selectedCustomerDetails = null;
                                }),
                              ),
                            ],
                          ),
                          const Divider(),
                          ListTile(
                            dense: true,
                            title: const Text("客户编号"),
                            subtitle: Text(_selectedCustomerDetails!["code"], style: const TextStyle(fontFamily: "monospace", fontWeight: FontWeight.bold, fontSize: 14)),
                          ),
                          ListTile(
                            dense: true,
                            title: const Text("联系人 & 联系电话"),
                            subtitle: Text("${_selectedCustomerDetails!['contact_person'] ?? '无'} | ${_selectedCustomerDetails!['contact_phone'] ?? '无'}"),
                          ),
                          ListTile(
                            dense: true,
                            title: const Text("联系地址"),
                            subtitle: Text(_selectedCustomerDetails!["address"] ?? "无"),
                          ),
                          const Divider(),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              _buildMetricCard("进行中订单", _selectedCustomerDetails!["ongoing_orders_count"].toString(), Colors.blue),
                              _buildMetricCard("待收付款", "￥${_selectedCustomerDetails!['pending_amount'].toStringAsFixed(2)}", Colors.red),
                              _buildMetricCard("总成交额", "￥${_selectedCustomerDetails!['total_deal_amount'].toStringAsFixed(2)}", Colors.green),
                            ],
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            "关联订单历史记录:",
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          if ((_selectedCustomerDetails!["order_history"] as List).isEmpty)
                            const Text("该客户暂无订单往来记录", style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic))
                          else
                            ListView.separated(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: (_selectedCustomerDetails!["order_history"] as List).length,
                              separatorBuilder: (_, __) => const Divider(),
                              itemBuilder: (context, index) {
                                final o = _selectedCustomerDetails!["order_history"][index];
                                final bool isOngoing = o["status"] == "进行中";

                                return ListTile(
                                  dense: true,
                                  title: Text("【${o['order_code']}】${o['product_name']}"),
                                  subtitle: Text("规格: ${o['specs']} | 数量: ${o['quantity']} | 金额: ￥${o['amount'].toStringAsFixed(2)}"),
                                  trailing: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: isOngoing ? Colors.orange[50] : Colors.green[50],
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          o["status"],
                                          style: TextStyle(color: isOngoing ? Colors.orange[800] : Colors.green[800], fontSize: 10, fontWeight: FontWeight.bold),
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text("交付进度: ${o['progress'].toStringAsFixed(1)}%", style: const TextStyle(fontSize: 10, color: Colors.grey)),
                                    ],
                                  ),
                                );
                              },
                            ),
                          const SizedBox(height: 24),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  icon: const Icon(Icons.edit),
                                  label: const Text("修改信息"),
                                  onPressed: () => _showAddOrEditCustomerDialog(customer: _selectedCustomerDetails),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.red[50],
                                    foregroundColor: Colors.red,
                                    elevation: 0,
                                  ),
                                  icon: const Icon(Icons.delete),
                                  label: const Text("删除客户"),
                                  onPressed: () => _deleteCustomer(_selectedCustomerDetails!),
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
        first: Card(
          margin: const EdgeInsets.all(12),
          elevation: 2,
          child: tableView,
        ),
        second: Card(
          margin: const EdgeInsets.only(top: 12, bottom: 12, right: 12),
          elevation: 2,
          child: detailPanel,
        ),
        direction: Axis.horizontal,
        initialRatio: 0.68,
        minSize: 300,
      ),
      floatingActionButton: FloatingActionButton(
        mini: true,
        backgroundColor: Colors.indigo,
        onPressed: _fetchCustomers,
        child: const Icon(Icons.refresh, color: Colors.white),
      ),
    );
  }

  Widget _buildMetricCard(String label, String value, Color color) {
    return Expanded(
      child: Card(
        color: color.withOpacity(0.05),
        elevation: 0,
        shape: RoundedRectangleBorder(
          side: BorderSide(color: color.withOpacity(0.2)),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
          child: Column(
            children: [
              Text(label, style: const TextStyle(fontSize: 10, color: Colors.black54)),
              const SizedBox(height: 4),
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontWeight: FontWeight.bold, color: color, fontSize: 13),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
