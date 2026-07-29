import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:erp/services/api_service.dart';
import 'package:erp/widgets/excel_table.dart';
import 'package:erp/widgets/resizable_panel.dart';
import 'package:erp/widgets/double_confirm_dialog.dart';

class InventoryScreen extends StatefulWidget {
  const InventoryScreen({Key? key}) : super(key: key);

  @override
  _InventoryScreenState createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  List<Map<String, dynamic>> _products = [];
  Map<String, dynamic>? _selectedProduct;
  bool _isLoading = false;

  // Controls
  bool _showOffShelf = false;
  final TextEditingController _searchController = TextEditingController();

  // Advanced search states
  bool _isAdvancedSearch = false;
  final TextEditingController _advNameController = TextEditingController();
  final TextEditingController _advSpecsController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchProducts();
  }

  Future<void> _fetchProducts() async {
    setState(() => _isLoading = true);
    try {
      final data = await ApiService.getProducts(
        showOffShelf: _showOffShelf,
        search: _isAdvancedSearch ? null : _searchController.text.trim(),
        name: _isAdvancedSearch ? _advNameController.text.trim() : null,
        specs: _isAdvancedSearch ? _advSpecsController.text.trim() : null,
      );
      setState(() {
        _products = data;
        if (_selectedProduct != null) {
          // Refresh details of selected
          final updated = data.cast<Map<String, dynamic>?>().firstWhere((p) => p?["id"] == _selectedProduct!["id"], orElse: () => null);
          _selectedProduct = updated;
        }
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("获取库存失败: $e")));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showAddOrEditProductDialog({Map<String, dynamic>? product}) {
    final bool isEdit = product != null;
    final formKey = GlobalKey<FormState>();
    final codeController = TextEditingController(text: product?["code"] ?? "");
    final nameController = TextEditingController(text: product?["name"] ?? "");
    final specsController = TextEditingController(text: product?["specs"] ?? "");
    final qtyController = TextEditingController(text: product?["quantity"]?.toString() ?? "0");
    final remarksController = TextEditingController(text: product?["remarks"] ?? "");
    final processController = TextEditingController(text: product?["process_info"] ?? "");

    List<dynamic> designImages = product != null ? List.from(product["design_images"]) : [];

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(isEdit ? "修改商品信息" : "新建库存商品"),
              content: Container(
                width: 500,
                child: Form(
                  key: formKey,
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        TextFormField(
                          controller: codeController,
                          decoration: const InputDecoration(
                            labelText: "商品编号 (不填则自动生成)",
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: nameController,
                          decoration: const InputDecoration(
                            labelText: "商品名 *",
                            border: OutlineInputBorder(),
                          ),
                          validator: (v) => (v == null || v.trim().isEmpty) ? "商品名必填" : null,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: specsController,
                          decoration: const InputDecoration(
                            labelText: "商品规格 *",
                            border: OutlineInputBorder(),
                          ),
                          validator: (v) => (v == null || v.trim().isEmpty) ? "商品规格必填" : null,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: qtyController,
                          decoration: const InputDecoration(
                            labelText: "初始数量 *",
                            border: OutlineInputBorder(),
                          ),
                          keyboardType: TextInputType.number,
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) return "数量必填";
                            if (int.tryParse(v) == null || int.parse(v) < 0) return "数量必须为大于等于0的整数";
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: remarksController,
                          maxLines: 2,
                          decoration: const InputDecoration(
                            labelText: "备注",
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: processController,
                          maxLines: 3,
                          decoration: const InputDecoration(
                            labelText: "生产工艺说明 (预留)",
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          "商品设计图 / 附件列表:",
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        ...designImages.asMap().entries.map((entry) {
                          final idx = entry.key;
                          final url = entry.value.toString();
                          return ListTile(
                            dense: true,
                            title: Text(url, maxLines: 1, overflow: TextOverflow.ellipsis),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () {
                                setDialogState(() {
                                  designImages.removeAt(idx);
                                });
                              },
                            ),
                          );
                        }).toList(),
                        const SizedBox(height: 8),
                        ElevatedButton.icon(
                          onPressed: () async {
                            final newUrl = await ApiService.uploadFile("design_diagram_${DateTime.now().millisecondsSinceEpoch}.jpg", [1, 2, 3]);
                            setDialogState(() {
                              designImages.add(newUrl);
                            });
                          },
                          icon: const Icon(Icons.upload_file),
                          label: const Text("添加设计图 / 附件 (PDF,DWG,JPG等)"),
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
                          "code": codeController.text.trim(),
                          "name": nameController.text.trim(),
                          "specs": specsController.text.trim(),
                          "quantity": qtyController.text.trim(),
                          "remarks": remarksController.text.trim(),
                          "design_images_json": jsonEncode(designImages),
                          "process_info": processController.text.trim()
                        };

                        if (isEdit) {
                          await ApiService.updateProduct(product["id"], body);
                        } else {
                          await ApiService.createProduct(body);
                        }
                        Navigator.of(context).pop();
                        _fetchProducts();
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(isEdit ? "更新成功" : "创建成功")));
                      } catch (err) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("操作失败: $err")));
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

  Future<void> _deleteProduct(Map<String, dynamic> product) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => DoubleConfirmDialog(
        title: "确定删除商品「${product['name']}」吗？",
        content: "警告：删除后将永久无法找回。只能在没有任何关联订单及交易历史的情况下才能执行此操作！",
      ),
    );

    if (confirm == true) {
      try {
        await ApiService.deleteProduct(product["id"]);
        setState(() {
          _selectedProduct = null;
        });
        _fetchProducts();
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("删除成功")));
      } catch (err) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text("无法删除"),
            content: Text(err.toString()),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text("我知道了"),
              )
            ],
          ),
        );
      }
    }
  }

  Future<void> _toggleStatus(Map<String, dynamic> product, String targetStatus) async {
    try {
      await ApiService.toggleProductStatus(product["id"], targetStatus);
      _fetchProducts();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("商品成功【$targetStatus】")));
    } catch (err) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text("操作被拒绝"),
          content: Text(err.toString()),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text("确定"),
            )
          ],
        ),
      );
    }
  }

  void _showHistoryDialog(Map<String, dynamic> product) async {
    showDialog(
      context: context,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final logs = await ApiService.getProductHistory(product["id"]);
      Navigator.of(context).pop(); // remove loader

      showDialog(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: Text("【${product['name']}】历史进出库记录"),
            content: Container(
              width: 600,
              height: 400,
              child: logs.isEmpty
                  ? const Center(child: Text("暂无历史进出库交易记录"))
                  : ListView.separated(
                      itemCount: logs.length,
                      separatorBuilder: (context, index) => const Divider(),
                      itemBuilder: (context, index) {
                        final log = logs[index];
                        final isSale = log["order_type"] == "销售";
                        return ListTile(
                          leading: Icon(
                            isSale ? Icons.arrow_outward : Icons.call_received,
                            color: isSale ? Colors.red : Colors.green,
                          ),
                          title: Text("${log['customer_name']} | 数量: ${log['quantity']}"),
                          subtitle: Text("日期: ${log['delivery_date']} | 关联订单: ${log['order_code']} [${log['order_type']}]"),
                          trailing: log["remarks"] != null && log["remarks"].isNotEmpty
                              ? Tooltip(message: log["remarks"], child: const Icon(Icons.info_outline))
                              : null,
                        );
                      },
                    ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text("关闭"),
              )
            ],
          );
        },
      );
    } catch (e) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("加载记录失败: $e")));
    }
  }

  @override
  Widget build(BuildContext context) {
    final excelCols = [
      ExcelColumn(label: "商品编号", width: 120),
      ExcelColumn(label: "商品名称", width: 180),
      ExcelColumn(label: "商品规格", width: 150),
      ExcelColumn(label: "库存数量", width: 100),
      ExcelColumn(label: "状态", width: 80),
      ExcelColumn(label: "备注说明", width: 220),
    ];

    final List<List<Widget>> excelRows = _products.map((p) {
      final isSelected = _selectedProduct?["id"] == p["id"];
      return <Widget>[
        // Render first column as clickable inkwell so clicking on ID selects that product!
        InkWell(
          onTap: () {
            setState(() {
              _selectedProduct = p;
            });
          },
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(isSelected ? Icons.check_circle : Icons.radio_button_off, size: 14, color: isSelected ? Colors.green : Colors.grey),
              const SizedBox(width: 4),
              Text(
                p["code"],
                style: const TextStyle(fontFamily: "monospace", fontWeight: FontWeight.bold, color: Colors.indigo),
              ),
            ],
          ),
        ),
        InkWell(
          onTap: () => setState(() => _selectedProduct = p),
          child: Text(p["name"], overflow: TextOverflow.ellipsis),
        ),
        Text(p["specs"], overflow: TextOverflow.ellipsis),
        Text(p["quantity"].toString(), style: const TextStyle(fontWeight: FontWeight.bold)),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: p["status"] == "上架" ? Colors.green[50] : Colors.red[50],
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            p["status"],
            style: TextStyle(color: p["status"] == "上架" ? Colors.green[800] : Colors.red[800], fontSize: 11, fontWeight: FontWeight.bold),
          ),
        ),
        Text(p["remarks"] ?? "", overflow: TextOverflow.ellipsis),
      ];
    }).toList();

    Widget tableView = ExcelTable(
      columns: excelCols,
      rowCount: _products.length,
      rows: excelRows,
      headerActions: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            Expanded(
              child: AnimatedCrossFade(
                firstChild: TextField(
                  controller: _searchController,
                  onChanged: (val) => _fetchProducts(),
                  decoration: InputDecoration(
                    hintText: "输入关键字模糊搜索...",
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
                        onChanged: (val) => _fetchProducts(),
                        decoration: const InputDecoration(
                          hintText: "按商品名检索",
                          isDense: true,
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _advSpecsController,
                        onChanged: (val) => _fetchProducts(),
                        decoration: const InputDecoration(
                          hintText: "按商品规格检索",
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
                  _advSpecsController.clear();
                  _fetchProducts();
                });
              },
            ),
            const SizedBox(width: 12),
            Row(
              children: [
                const Text("显示下架商品", style: TextStyle(fontSize: 12)),
                Switch(
                  value: _showOffShelf,
                  onChanged: (val) {
                    setState(() {
                      _showOffShelf = val;
                      _fetchProducts();
                    });
                  },
                ),
              ],
            ),
            const SizedBox(width: 12),
            ElevatedButton.icon(
              icon: const Icon(Icons.add),
              label: const Text("新建商品"),
              onPressed: () => _showAddOrEditProductDialog(),
            ),
          ],
        ),
      ),
    );

    Widget detailPanel = _selectedProduct == null
        ? const Center(
            child: Text(
              "在左侧选择行或点击商品编号查看详情",
              style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic),
            ),
          )
        : Padding(
            padding: const EdgeInsets.all(16.0),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          _selectedProduct!["name"],
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => setState(() => _selectedProduct = null),
                      ),
                    ],
                  ),
                  const Divider(),
                  ListTile(
                    dense: true,
                    title: const Text("商品编号"),
                    subtitle: Text(_selectedProduct!["code"], style: const TextStyle(fontFamily: "monospace", fontSize: 14, fontWeight: FontWeight.bold)),
                  ),
                  ListTile(
                    dense: true,
                    title: const Text("规格属性"),
                    subtitle: Text(_selectedProduct!["specs"]),
                  ),
                  ListTile(
                    dense: true,
                    title: const Text("当前库存量"),
                    subtitle: Text("${_selectedProduct!['quantity']} 件", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  ),
                  if (_selectedProduct!["remarks"] != null && _selectedProduct!["remarks"].toString().isNotEmpty)
                    ListTile(
                      dense: true,
                      title: const Text("备注说明"),
                      subtitle: Text(_selectedProduct!["remarks"]),
                    ),
                  ListTile(
                    dense: true,
                    title: const Text("生产工艺 (预留)"),
                    subtitle: Text(_selectedProduct!["process_info"] ?? "暂无说明"),
                  ),
                  const SizedBox(height: 12),
                  const Text("图纸 / 附件数量", style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  if (_selectedProduct!["design_images"] == null || (_selectedProduct!["design_images"] as List).isEmpty)
                    const Text("暂无图纸文件", style: TextStyle(color: Colors.grey, fontSize: 12))
                  else
                    Wrap(
                      spacing: 8,
                      children: (_selectedProduct!["design_images"] as List).map((url) {
                        return ActionChip(
                          avatar: const Icon(Icons.insert_drive_file, size: 16),
                          label: const Text("查看设计图纸附件"),
                          onPressed: () {
                            showDialog(
                              context: context,
                              builder: (context) => AlertDialog(
                                title: const Text("设计图纸附件预览"),
                                content: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.attachment, size: 48, color: Colors.blue),
                                    const SizedBox(height: 12),
                                    Text("文件格式: ${url.toString().split('.').last.toUpperCase()}"),
                                    const SizedBox(height: 8),
                                    Text("链接: $url", style: const TextStyle(fontSize: 11, color: Colors.grey)),
                                    const SizedBox(height: 16),
                                    const Text("系统检测：该文件可正常打开与编辑"),
                                  ],
                                ),
                                actions: [
                                  TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text("确定")),
                                ],
                              ),
                            );
                          },
                        );
                      }).toList(),
                    ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.history),
                    label: const Text("查看历史进出库信息"),
                    onPressed: () => _showHistoryDialog(_selectedProduct!),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.edit),
                          label: const Text("修改"),
                          onPressed: () => _showAddOrEditProductDialog(product: _selectedProduct),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: Icon(_selectedProduct!["status"] == "上架" ? Icons.arrow_downward : Icons.arrow_upward),
                          label: Text(_selectedProduct!["status"] == "上架" ? "下架" : "上架"),
                          onPressed: () {
                            final target = _selectedProduct!["status"] == "上架" ? "下架" : "上架";
                            _toggleStatus(_selectedProduct!, target);
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red[50],
                      foregroundColor: Colors.red,
                      elevation: 0,
                    ),
                    icon: const Icon(Icons.delete),
                    label: const Text("物理删除商品"),
                    onPressed: () => _deleteProduct(_selectedProduct!),
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
          child: _isLoading ? const Center(child: CircularProgressIndicator()) : detailPanel,
        ),
        direction: Axis.horizontal,
        initialRatio: 0.70,
        minSize: 300,
      ),
      floatingActionButton: FloatingActionButton(
        mini: true,
        backgroundColor: Colors.indigo,
        onPressed: _fetchProducts,
        child: const Icon(Icons.refresh, color: Colors.white),
      ),
    );
  }
}
