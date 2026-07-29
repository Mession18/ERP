import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  static const String baseUrl = "http://localhost:8000/api";

  // Local fallbacks in case the server is offline or not started
  static List<Map<String, dynamic>> _mockProducts = [
    {
      "id": 1,
      "code": "PROD-0001",
      "name": "高精度钢制螺丝",
      "specs": "M8*20mm",
      "quantity": 1250,
      "image_url": "",
      "remarks": "汽车引擎配件",
      "design_images": ["https://picsum.photos/200/300"],
      "process_info": "1. 选材：优质碳钢\n2. 冷镦成型\n3. 搓丝\n4. 热处理淬火\n5. 表面镀锌",
      "status": "上架"
    },
    {
      "id": 2,
      "code": "PROD-0002",
      "name": "密封橡胶圈",
      "specs": "OD 45mm * ID 38mm",
      "quantity": 500,
      "image_url": "",
      "remarks": "防水耐高温",
      "design_images": [],
      "process_info": "橡胶模压工艺，180度硫化10分钟",
      "status": "上架"
    },
    {
      "id": 3,
      "code": "PROD-0003",
      "name": "合金轴承",
      "specs": "6204-2RS",
      "quantity": 30,
      "image_url": "",
      "remarks": "静音级转动轴承",
      "design_images": [],
      "process_info": "高精密磨床精加工，装配双面橡胶密封圈",
      "status": "下架"
    }
  ];

  static List<Map<String, dynamic>> _mockCustomers = [
    {
      "id": 1,
      "code": "CUST-0001",
      "type": "买家",
      "name": "上海机械制造集团",
      "contact_person": "陆经理",
      "contact_phone": "13912345678",
      "address": "上海市浦东新区张江高科",
      "logo_url": ""
    },
    {
      "id": 2,
      "code": "CUST-0002",
      "type": "卖家",
      "name": "江阴市精密模具钢厂",
      "contact_person": "韩总",
      "contact_phone": "13588889999",
      "address": "江苏省江阴市工业园区8号",
      "logo_url": ""
    }
  ];

  static List<Map<String, dynamic>> _mockOrders = [
    {
      "id": 1,
      "code": "ORD-0001",
      "type": "销售",
      "customer_id": 1,
      "customer_name": "上海机械制造集团",
      "product_id": 1,
      "product_name": "高精度钢制螺丝",
      "product_specs": "M8*20mm",
      "quantity": 1000,
      "unit_price": 2.50,
      "total_amount": 2500.0,
      "delivery_progress": 60.0,
      "payment_progress": 40.0,
      "order_date": "2024-05-10",
      "delivery_date": "2024-05-25",
      "status": "进行中"
    },
    {
      "id": 2,
      "code": "ORD-0002",
      "type": "采购",
      "customer_id": 2,
      "customer_name": "江阴市精密模具钢厂",
      "product_id": 2,
      "product_name": "密封橡胶圈",
      "product_specs": "OD 45mm * ID 38mm",
      "quantity": 200,
      "unit_price": 1.20,
      "total_amount": 240.0,
      "delivery_progress": 100.0,
      "payment_progress": 100.0,
      "order_date": "2024-04-12",
      "delivery_date": "2024-04-20",
      "status": "已完成"
    }
  ];

  static List<Map<String, dynamic>> _mockDeliveries = [
    {
      "id": 1,
      "order_id": 1,
      "quantity": 600,
      "delivery_date": "2024-05-14",
      "remarks": "第一批送货600只"
    }
  ];

  static List<Map<String, dynamic>> _mockFinancials = [
    {
      "id": 1,
      "order_id": 1,
      "amount": 1000.0,
      "payment_date": "2024-05-12",
      "invoice_no": "INV-2024051201",
      "invoice_image_url": "",
      "is_invoiced": true,
      "remarks": "定金首笔"
    }
  ];

  static bool isOnline = true;

  // Helper to run a safe network check
  static Future<void> checkConnection() async {
    try {
      final res = await http.get(Uri.parse(baseUrl + "/")).timeout(const Duration(milliseconds: 1500));
      if (res.statusCode == 200) {
        isOnline = true;
      } else {
        isOnline = false;
      }
    } catch (_) {
      isOnline = false;
    }
  }

  // ==================== PRODUCTS API ====================
  static Future<List<Map<String, dynamic>>> getProducts({bool showOffShelf = false, String? search, String? name, String? specs}) async {
    await checkConnection();
    if (isOnline) {
      try {
        var uri = Uri.parse("$baseUrl/products?show_off_shelf=$showOffShelf" +
            (search != null ? "&search=${Uri.encodeComponent(search)}" : "") +
            (name != null ? "&name=${Uri.encodeComponent(name)}" : "") +
            (specs != null ? "&specs=${Uri.encodeComponent(specs)}" : ""));
        final res = await http.get(uri);
        if (res.statusCode == 200) {
          final List list = jsonDecode(utf8.decode(res.bodyBytes));
          return list.map((e) => e as Map<String, dynamic>).toList();
        }
      } catch (_) {}
    }

    // Fallback
    Iterable<Map<String, dynamic>> filtered = _mockProducts;
    if (!showOffShelf) {
      filtered = filtered.where((p) => p["status"] == "上架");
    }
    if (search != null && search.isNotEmpty) {
      final s = search.toLowerCase();
      filtered = filtered.where((p) =>
          p["code"].toLowerCase().contains(s) ||
          p["name"].toLowerCase().contains(s) ||
          p["specs"].toLowerCase().contains(s) ||
          (p["remarks"] ?? "").toLowerCase().contains(s));
    } else {
      if (name != null && name.isNotEmpty) {
        filtered = filtered.where((p) => p["name"].toLowerCase().contains(name.toLowerCase()));
      }
      if (specs != null && specs.isNotEmpty) {
        filtered = filtered.where((p) => p["specs"].toLowerCase().contains(specs.toLowerCase()));
      }
    }
    return filtered.toList();
  }

  static Future<Map<String, dynamic>?> createProduct(Map<String, String> data) async {
    await checkConnection();
    if (isOnline) {
      try {
        var req = http.MultipartRequest("POST", Uri.parse("$baseUrl/products"));
        data.forEach((key, value) {
          req.fields[key] = value;
        });
        var resStream = await req.send();
        var res = await http.Response.fromStream(resStream);
        if (res.statusCode == 200) {
          return jsonDecode(utf8.decode(res.bodyBytes));
        }
      } catch (_) {}
    }

    // Mock
    final id = _mockProducts.length + 1;
    final code = data["code"] != null && data["code"]!.trim().isNotEmpty
        ? data["code"]!
        : "PROD-${id.toString().padLeft(4, '0')}";
    final qty = int.tryParse(data["quantity"] ?? "0") ?? 0;

    // Uniqueness
    if (_mockProducts.any((p) => p["code"] == code)) {
      throw "商品编号已存在！";
    }

    final newProd = {
      "id": id,
      "code": code,
      "name": data["name"] ?? "",
      "specs": data["specs"] ?? "",
      "quantity": qty,
      "image_url": data["image_url"] ?? "",
      "remarks": data["remarks"] ?? "",
      "design_images": jsonDecode(data["design_images_json"] ?? "[]"),
      "process_info": data["process_info"] ?? "",
      "status": "上架"
    };
    _mockProducts.add(newProd);
    return newProd;
  }

  static Future<Map<String, dynamic>?> updateProduct(int id, Map<String, String> data) async {
    await checkConnection();
    if (isOnline) {
      try {
        var req = http.MultipartRequest("PUT", Uri.parse("$baseUrl/products/$id"));
        data.forEach((key, value) {
          req.fields[key] = value;
        });
        var resStream = await req.send();
        var res = await http.Response.fromStream(resStream);
        if (res.statusCode == 200) {
          return jsonDecode(utf8.decode(res.bodyBytes));
        } else {
          final err = jsonDecode(utf8.decode(res.bodyBytes));
          throw err["detail"] ?? "修改失败";
        }
      } catch (e) {
        if (e is String) rethrow;
      }
    }

    // Mock
    final idx = _mockProducts.indexWhere((p) => p["id"] == id);
    if (idx != -1) {
      final code = data["code"] ?? _mockProducts[idx]["code"];
      if (code != _mockProducts[idx]["code"] && _mockProducts.any((p) => p["code"] == code)) {
        throw "商品编号已存在！";
      }
      _mockProducts[idx]["code"] = code;
      _mockProducts[idx]["name"] = data["name"] ?? _mockProducts[idx]["name"];
      _mockProducts[idx]["specs"] = data["specs"] ?? _mockProducts[idx]["specs"];
      _mockProducts[idx]["quantity"] = int.tryParse(data["quantity"] ?? "0") ?? _mockProducts[idx]["quantity"];
      _mockProducts[idx]["image_url"] = data["image_url"] ?? _mockProducts[idx]["image_url"];
      _mockProducts[idx]["remarks"] = data["remarks"] ?? _mockProducts[idx]["remarks"];
      _mockProducts[idx]["design_images"] = jsonDecode(data["design_images_json"] ?? "[]");
      _mockProducts[idx]["process_info"] = data["process_info"] ?? _mockProducts[idx]["process_info"];
      return _mockProducts[idx];
    }
    throw "未找到该商品";
  }

  static Future<void> toggleProductStatus(int id, String status) async {
    await checkConnection();
    if (isOnline) {
      try {
        var req = http.MultipartRequest("PUT", Uri.parse("$baseUrl/products/$id/status"));
        req.fields["status"] = status;
        var resStream = await req.send();
        var res = await http.Response.fromStream(resStream);
        if (res.statusCode != 200) {
          final err = jsonDecode(utf8.decode(res.bodyBytes));
          throw err["detail"] ?? "操作失败";
        }
        return;
      } catch (e) {
        if (e is String) rethrow;
        throw "服务器连接失败，无法更新上下架状态";
      }
    }

    // Mock
    if (status == "下架") {
      final hasOngoing = _mockOrders.any((o) => o["product_id"] == id && o["status"] == "进行中");
      if (hasOngoing) {
        throw "无法下架商品！因为该商品仍存在进行中的订单。";
      }
    }
    final idx = _mockProducts.indexWhere((p) => p["id"] == id);
    if (idx != -1) {
      _mockProducts[idx]["status"] = status;
    }
  }

  static Future<void> deleteProduct(int id) async {
    await checkConnection();
    if (isOnline) {
      try {
        final res = await http.delete(Uri.parse("$baseUrl/products/$id"));
        if (res.statusCode != 200) {
          final err = jsonDecode(utf8.decode(res.bodyBytes));
          throw err["detail"] ?? "删除失败";
        }
        return;
      } catch (e) {
        if (e is String) rethrow;
        throw "服务器连接失败，无法删除";
      }
    }

    // Mock
    final hasOrders = _mockOrders.any((o) => o["product_id"] == id);
    if (hasOrders) {
      throw "无法删除商品！因为曾经有过相关订单记录。";
    }
    _mockProducts.removeWhere((p) => p["id"] == id);
  }

  static Future<List<Map<String, dynamic>>> getProductHistory(int productId) async {
    await checkConnection();
    if (isOnline) {
      try {
        final res = await http.get(Uri.parse("$baseUrl/products/$productId/history"));
        if (res.statusCode == 200) {
          final List l = jsonDecode(utf8.decode(res.bodyBytes));
          return l.map((e) => e as Map<String, dynamic>).toList();
        }
      } catch (_) {}
    }

    // Mock
    final prodOrders = _mockOrders.where((o) => o["product_id"] == productId).map((o) => o["id"]).toList();
    final dList = _mockDeliveries.where((d) => prodOrders.contains(d["order_id"])).toList();
    return dList.map((d) {
      final o = _mockOrders.firstWhere((ord) => ord["id"] == d["order_id"]);
      return {
        "delivery_id": d["id"],
        "order_code": o["code"],
        "order_type": o["type"],
        "customer_name": o["customer_name"],
        "quantity": d["quantity"],
        "delivery_date": d["delivery_date"],
        "remarks": d["remarks"] ?? ""
      };
    }).toList();
  }


  // ==================== CUSTOMERS API ====================
  static Future<List<Map<String, dynamic>>> getCustomers({String? search, String? name, String? contactPerson}) async {
    await checkConnection();
    if (isOnline) {
      try {
        var uri = Uri.parse("$baseUrl/customers" +
            (search != null ? "?search=${Uri.encodeComponent(search)}" : "") +
            (name != null ? "?name=${Uri.encodeComponent(name)}" : "") +
            (contactPerson != null ? "?contact_person=${Uri.encodeComponent(contactPerson)}" : ""));
        final res = await http.get(uri);
        if (res.statusCode == 200) {
          final List list = jsonDecode(utf8.decode(res.bodyBytes));
          return list.map((e) => e as Map<String, dynamic>).toList();
        }
      } catch (_) {}
    }

    // Fallback
    Iterable<Map<String, dynamic>> filtered = _mockCustomers;
    if (search != null && search.isNotEmpty) {
      final s = search.toLowerCase();
      filtered = filtered.where((c) =>
          c["code"].toLowerCase().contains(s) ||
          c["name"].toLowerCase().contains(s) ||
          (c["contact_person"] ?? "").toLowerCase().contains(s) ||
          (c["contact_phone"] ?? "").toLowerCase().contains(s) ||
          (c["address"] ?? "").toLowerCase().contains(s));
    } else {
      if (name != null && name.isNotEmpty) {
        filtered = filtered.where((c) => c["name"].toLowerCase().contains(name.toLowerCase()));
      }
      if (contactPerson != null && contactPerson.isNotEmpty) {
        filtered = filtered.where((c) => (c["contact_person"] ?? "").toLowerCase().contains(contactPerson.toLowerCase()));
      }
    }

    return filtered.map((c) {
      final int id = c["id"];
      final ongoingOrdersCount = _mockOrders.where((o) => o["customer_id"] == id && o["status"] == "进行中").length;

      double pendingAmount = 0.0;
      final cOrders = _mockOrders.where((o) => o["customer_id"] == id);
      for (var o in cOrders) {
        final total = o["quantity"] * o["unit_price"];
        final paid = _mockFinancials.where((f) => f["order_id"] == o["id"]).fold<double>(0.0, (sum, f) => sum + (f["amount"] as double));
        pendingAmount += (total - paid);
      }

      return {
        ...c,
        "ongoing_orders_count": ongoingOrdersCount,
        "pending_amount": pendingAmount < 0 ? 0.0 : pendingAmount
      };
    }).toList();
  }

  static Future<Map<String, dynamic>> getCustomerDetails(int id) async {
    await checkConnection();
    if (isOnline) {
      try {
        final res = await http.get(Uri.parse("$baseUrl/customers/$id"));
        if (res.statusCode == 200) {
          return jsonDecode(utf8.decode(res.bodyBytes));
        }
      } catch (_) {}
    }

    // Mock
    final c = _mockCustomers.firstWhere((cust) => cust["id"] == id);
    final cOrders = _mockOrders.where((o) => o["customer_id"] == id).toList();

    int ongoingOrdersCount = 0;
    double totalDealAmount = 0.0;
    double pendingAmount = 0.0;
    List<Map<String, dynamic>> orderHistory = [];

    for (var o in cOrders) {
      final total = o["quantity"] * o["unit_price"];
      final paid = _mockFinancials.where((f) => f["order_id"] == o["id"]).fold<double>(0.0, (sum, f) => sum + (f["amount"] as double));
      final delQty = _mockDeliveries.where((d) => d["order_id"] == o["id"]).fold<int>(0, (sum, d) => sum + (d["quantity"] as int));

      totalDealAmount += total;
      pendingAmount += (total - paid);

      if (o["status"] == "进行中") {
        ongoingOrdersCount += 1;
      }

      orderHistory.add({
        "order_id": o["id"],
        "order_code": o["code"],
        "product_name": o["product_name"],
        "specs": o["product_specs"],
        "quantity": o["quantity"],
        "amount": total,
        "progress": (o["quantity"] > 0 ? (delQty / o["quantity"] * 100) : 0.0),
        "status": o["status"]
      });
    }

    return {
      "id": c["id"],
      "code": c["code"],
      "type": c["type"],
      "name": c["name"],
      "contact_person": c["contact_person"] ?? "",
      "contact_phone": c["contact_phone"] ?? "",
      "address": c["address"] ?? "",
      "logo_url": c["logo_url"] ?? "",
      "ongoing_orders_count": ongoingOrdersCount,
      "pending_amount": pendingAmount < 0 ? 0.0 : pendingAmount,
      "total_deal_amount": totalDealAmount,
      "order_history": orderHistory
    };
  }

  static Future<Map<String, dynamic>?> createCustomer(Map<String, String> data) async {
    await checkConnection();
    if (isOnline) {
      try {
        var req = http.MultipartRequest("POST", Uri.parse("$baseUrl/customers"));
        data.forEach((key, value) {
          req.fields[key] = value;
        });
        var resStream = await req.send();
        var res = await http.Response.fromStream(resStream);
        if (res.statusCode == 200) {
          return jsonDecode(utf8.decode(res.bodyBytes));
        }
      } catch (_) {}
    }

    // Mock
    final id = _mockCustomers.length + 1;
    final code = data["code"] != null && data["code"]!.trim().isNotEmpty
        ? data["code"]!
        : "CUST-${id.toString().padLeft(4, '0')}";

    if (_mockCustomers.any((c) => c["code"] == code)) {
      throw "客户编号已存在！";
    }

    final newCust = {
      "id": id,
      "code": code,
      "type": data["type"] ?? "买家",
      "name": data["name"] ?? "",
      "contact_person": data["contact_person"] ?? "",
      "contact_phone": data["contact_phone"] ?? "",
      "address": data["address"] ?? "",
      "logo_url": data["logo_url"] ?? ""
    };
    _mockCustomers.add(newCust);
    return newCust;
  }

  static Future<Map<String, dynamic>?> updateCustomer(int id, Map<String, String> data) async {
    await checkConnection();
    if (isOnline) {
      try {
        var req = http.MultipartRequest("PUT", Uri.parse("$baseUrl/customers/$id"));
        data.forEach((key, value) {
          req.fields[key] = value;
        });
        var resStream = await req.send();
        var res = await http.Response.fromStream(resStream);
        if (res.statusCode == 200) {
          return jsonDecode(utf8.decode(res.bodyBytes));
        }
      } catch (_) {}
    }

    // Mock
    final idx = _mockCustomers.indexWhere((c) => c["id"] == id);
    if (idx != -1) {
      final code = data["code"] ?? _mockCustomers[idx]["code"];
      if (code != _mockCustomers[idx]["code"] && _mockCustomers.any((c) => c["code"] == code)) {
        throw "客户编号已存在！";
      }
      _mockCustomers[idx]["code"] = code;
      _mockCustomers[idx]["type"] = data["type"] ?? _mockCustomers[idx]["type"];
      _mockCustomers[idx]["name"] = data["name"] ?? _mockCustomers[idx]["name"];
      _mockCustomers[idx]["contact_person"] = data["contact_person"] ?? _mockCustomers[idx]["contact_person"];
      _mockCustomers[idx]["contact_phone"] = data["contact_phone"] ?? _mockCustomers[idx]["contact_phone"];
      _mockCustomers[idx]["address"] = data["address"] ?? _mockCustomers[idx]["address"];
      _mockCustomers[idx]["logo_url"] = data["logo_url"] ?? _mockCustomers[idx]["logo_url"];
      return _mockCustomers[idx];
    }
    throw "未找到该客户";
  }

  static Future<void> deleteCustomer(int id) async {
    await checkConnection();
    if (isOnline) {
      try {
        final res = await http.delete(Uri.parse("$baseUrl/customers/$id"));
        if (res.statusCode != 200) {
          final err = jsonDecode(utf8.decode(res.bodyBytes));
          throw err["detail"] ?? "删除失败";
        }
        return;
      } catch (e) {
        if (e is String) rethrow;
        throw "服务器连接失败，无法删除";
      }
    }

    // Mock
    final hasOrders = _mockOrders.any((o) => o["customer_id"] == id);
    if (hasOrders) {
      throw "无法删除客户！因为存在相关的订单记录。";
    }
    _mockCustomers.removeWhere((c) => c["id"] == id);
  }


  // ==================== ORDERS API ====================
  static Future<List<Map<String, dynamic>>> getOrders({bool showCompleted = false, String? search}) async {
    await checkConnection();
    if (isOnline) {
      try {
        var uri = Uri.parse("$baseUrl/orders?show_completed=$showCompleted" +
            (search != null ? "&search=${Uri.encodeComponent(search)}" : ""));
        final res = await http.get(uri);
        if (res.statusCode == 200) {
          final List list = jsonDecode(utf8.decode(res.bodyBytes));
          return list.map((e) => e as Map<String, dynamic>).toList();
        }
      } catch (_) {}
    }

    // Fallback
    Iterable<Map<String, dynamic>> filtered = _mockOrders;
    if (!showCompleted) {
      filtered = filtered.where((o) => o["status"] == "进行中");
    }
    if (search != null && search.isNotEmpty) {
      final s = search.toLowerCase();
      filtered = filtered.where((o) =>
          o["code"].toLowerCase().contains(s) ||
          o["customer_name"].toLowerCase().contains(s) ||
          o["product_name"].toLowerCase().contains(s) ||
          o["product_specs"].toLowerCase().contains(s));
    }

    return filtered.map((o) {
      final int orderId = o["id"];
      final total = o["quantity"] * o["unit_price"];
      final delQty = _mockDeliveries.where((d) => d["order_id"] == orderId).fold<int>(0, (sum, d) => sum + (d["quantity"] as int));
      final paid = _mockFinancials.where((f) => f["order_id"] == orderId).fold<double>(0.0, (sum, f) => sum + (f["amount"] as double));

      return {
        ...o,
        "delivery_progress": (o["quantity"] > 0 ? (delQty / o["quantity"] * 100) : 0.0),
        "payment_progress": (total > 0 ? (paid / total * 100) : 0.0),
      };
    }).toList();
  }

  static Future<Map<String, dynamic>> getOrderDetails(int id) async {
    await checkConnection();
    if (isOnline) {
      try {
        final res = await http.get(Uri.parse("$baseUrl/orders/$id"));
        if (res.statusCode == 200) {
          return jsonDecode(utf8.decode(res.bodyBytes));
        }
      } catch (_) {}
    }

    // Mock
    final o = _mockOrders.firstWhere((ord) => ord["id"] == id);
    final c = _mockCustomers.firstWhere((cust) => cust["id"] == o["customer_id"]);
    final p = _mockProducts.firstWhere((prod) => prod["id"] == o["product_id"]);

    final total = o["quantity"] * o["unit_price"];
    final deliveries = _mockDeliveries.where((d) => d["order_id"] == id).toList();
    final financials = _mockFinancials.where((f) => f["order_id"] == id).toList();

    final delQty = deliveries.fold<int>(0, (sum, d) => sum + (d["quantity"] as int));
    final paid = financials.fold<double>(0.0, (sum, f) => sum + (f["amount"] as double));

    return {
      "id": o["id"],
      "code": o["code"],
      "type": o["type"],
      "customer_id": o["customer_id"],
      "customer_name": c["name"],
      "customer_contact_person": c["contact_person"] ?? "",
      "customer_contact_phone": c["contact_phone"] ?? "",
      "customer_address": c["address"] ?? "",
      "product_id": o["product_id"],
      "product_name": p["name"],
      "product_specs": p["specs"],
      "quantity": o["quantity"],
      "unit_price": o["unit_price"],
      "total_amount": total,
      "order_date": o["order_date"],
      "delivery_date": o["delivery_date"],
      "status": o["status"],
      "delivery_progress": (o["quantity"] > 0 ? (delQty / o["quantity"] * 100) : 0.0),
      "payment_progress": (total > 0 ? (paid / total * 100) : 0.0),
      "delivered_quantity": delQty,
      "paid_amount": paid,
      "deliveries": deliveries,
      "financials": financials
    };
  }

  static Future<Map<String, dynamic>?> createOrder(Map<String, String> data) async {
    await checkConnection();
    if (isOnline) {
      try {
        var req = http.MultipartRequest("POST", Uri.parse("$baseUrl/orders"));
        data.forEach((key, value) {
          req.fields[key] = value;
        });
        var resStream = await req.send();
        var res = await http.Response.fromStream(resStream);
        if (res.statusCode == 200) {
          return jsonDecode(utf8.decode(res.bodyBytes));
        } else {
          final err = jsonDecode(utf8.decode(res.bodyBytes));
          throw err["detail"] ?? "新建订单失败";
        }
      } catch (e) {
        if (e is String) rethrow;
      }
    }

    // Mock
    final id = _mockOrders.length + 1;
    final code = data["code"] != null && data["code"]!.trim().isNotEmpty
        ? data["code"]!
        : "ORD-${id.toString().padLeft(4, '0')}";

    if (_mockOrders.any((o) => o["code"] == code)) {
      throw "订单编号已存在！";
    }

    final custId = int.parse(data["customer_id"] ?? "0");
    final prodId = int.parse(data["product_id"] ?? "0");
    final qty = int.parse(data["quantity"] ?? "0");
    final price = double.parse(data["unit_price"] ?? "0.0");

    final c = _mockCustomers.firstWhere((cust) => cust["id"] == custId);
    final p = _mockProducts.firstWhere((prod) => prod["id"] == prodId);

    final newOrder = {
      "id": id,
      "code": code,
      "type": data["type"] ?? "销售",
      "customer_id": custId,
      "customer_name": c["name"],
      "product_id": prodId,
      "product_name": p["name"],
      "product_specs": p["specs"],
      "quantity": qty,
      "unit_price": price,
      "total_amount": qty * price,
      "delivery_progress": 0.0,
      "payment_progress": 0.0,
      "order_date": data["order_date"] ?? "",
      "delivery_date": data["delivery_date"] ?? "",
      "status": "进行中"
    };

    _mockOrders.add(newOrder);
    return newOrder;
  }

  static Future<Map<String, dynamic>?> updateOrder(int id, Map<String, String> data) async {
    await checkConnection();
    if (isOnline) {
      try {
        var req = http.MultipartRequest("PUT", Uri.parse("$baseUrl/orders/$id"));
        data.forEach((key, value) {
          req.fields[key] = value;
        });
        var resStream = await req.send();
        var res = await http.Response.fromStream(resStream);
        if (res.statusCode == 200) {
          return jsonDecode(utf8.decode(res.bodyBytes));
        }
      } catch (_) {}
    }

    // Mock
    final idx = _mockOrders.indexWhere((o) => o["id"] == id);
    if (idx != -1) {
      final code = data["code"] ?? _mockOrders[idx]["code"];
      if (code != _mockOrders[idx]["code"] && _mockOrders.any((o) => o["code"] == code)) {
        throw "订单编号已存在！";
      }
      final custId = int.parse(data["customer_id"] ?? _mockOrders[idx]["customer_id"].toString());
      final prodId = int.parse(data["product_id"] ?? _mockOrders[idx]["product_id"].toString());

      final c = _mockCustomers.firstWhere((cust) => cust["id"] == custId);
      final p = _mockProducts.firstWhere((prod) => prod["id"] == prodId);

      _mockOrders[idx]["code"] = code;
      _mockOrders[idx]["type"] = data["type"] ?? _mockOrders[idx]["type"];
      _mockOrders[idx]["customer_id"] = custId;
      _mockOrders[idx]["customer_name"] = c["name"];
      _mockOrders[idx]["product_id"] = prodId;
      _mockOrders[idx]["product_name"] = p["name"];
      _mockOrders[idx]["product_specs"] = p["specs"];
      _mockOrders[idx]["quantity"] = int.parse(data["quantity"] ?? _mockOrders[idx]["quantity"].toString());
      _mockOrders[idx]["unit_price"] = double.parse(data["unit_price"] ?? _mockOrders[idx]["unit_price"].toString());
      _mockOrders[idx]["order_date"] = data["order_date"] ?? _mockOrders[idx]["order_date"];
      _mockOrders[idx]["delivery_date"] = data["delivery_date"] ?? _mockOrders[idx]["delivery_date"];
      _mockOrders[idx]["status"] = data["status"] ?? _mockOrders[idx]["status"];

      _mockOrders[idx]["total_amount"] = _mockOrders[idx]["quantity"] * _mockOrders[idx]["unit_price"];
      return _mockOrders[idx];
    }
    throw "未找到该订单";
  }

  static Future<void> deleteOrder(int id) async {
    await checkConnection();
    if (isOnline) {
      try {
        final res = await http.delete(Uri.parse("$baseUrl/orders/$id"));
        if (res.statusCode != 200) {
          final err = jsonDecode(utf8.decode(res.bodyBytes));
          throw err["detail"] ?? "删除失败";
        }
        return;
      } catch (e) {
        if (e is String) rethrow;
        throw "服务器连接失败，无法删除";
      }
    }

    // Mock
    final hasDelivs = _mockDeliveries.any((d) => d["order_id"] == id);
    final hasFinance = _mockFinancials.any((f) => f["order_id"] == id);
    if (hasDelivs || hasFinance) {
      throw "无法删除订单！因为该订单已经有相关的交付历史或收付款记录。";
    }
    _mockOrders.removeWhere((o) => o["id"] == id);
  }


  // ==================== DELIVERIES API ====================
  static Future<List<Map<String, dynamic>>> getDeliveriesView({bool showAll = false, String? search}) async {
    await checkConnection();
    if (isOnline) {
      try {
        var uri = Uri.parse("$baseUrl/deliveries?show_all=$showAll" +
            (search != null ? "&search=${Uri.encodeComponent(search)}" : ""));
        final res = await http.get(uri);
        if (res.statusCode == 200) {
          final List list = jsonDecode(utf8.decode(res.bodyBytes));
          return list.map((e) => e as Map<String, dynamic>).toList();
        }
      } catch (_) {}
    }

    // Fallback
    Iterable<Map<String, dynamic>> filtered = _mockOrders;
    if (!showAll) {
      filtered = filtered.where((o) => o["status"] == "进行中");
    }
    if (search != null && search.isNotEmpty) {
      final s = search.toLowerCase();
      filtered = filtered.where((o) =>
          o["code"].toLowerCase().contains(s) ||
          o["customer_name"].toLowerCase().contains(s) ||
          o["product_name"].toLowerCase().contains(s) ||
          o["product_specs"].toLowerCase().contains(s));
    }

    return filtered.map((o) {
      final int orderId = o["id"];
      final prod = _mockProducts.firstWhere((p) => p["id"] == o["product_id"]);
      final int delQty = _mockDeliveries.where((d) => d["order_id"] == orderId).fold<int>(0, (sum, d) => sum + (d["quantity"] as int));
      final int pending = o["quantity"] - delQty;

      return {
        "order_id": o["id"],
        "order_code": o["code"],
        "type": o["type"],
        "customer_name": o["customer_name"],
        "product_name": o["product_name"],
        "product_specs": o["product_specs"],
        "total_quantity": o["quantity"],
        "delivered_quantity": delQty,
        "pending_quantity": pending < 0 ? 0 : pending,
        "stock_quantity": prod["quantity"]
      };
    }).toList();
  }

  static Future<void> createDelivery(Map<String, String> data) async {
    await checkConnection();
    if (isOnline) {
      try {
        var req = http.MultipartRequest("POST", Uri.parse("$baseUrl/deliveries"));
        data.forEach((key, value) {
          req.fields[key] = value;
        });
        var resStream = await req.send();
        var res = await http.Response.fromStream(resStream);
        if (res.statusCode != 200) {
          final err = jsonDecode(utf8.decode(res.bodyBytes));
          throw err["detail"] ?? "录入交货失败";
        }
        return;
      } catch (e) {
        if (e is String) rethrow;
        throw "服务器连接失败，交货录入失败";
      }
    }

    // Mock
    final orderId = int.parse(data["order_id"]!);
    final quantity = int.parse(data["quantity"]!);
    final date = data["delivery_date"]!;
    final remarks = data["remarks"] ?? "";

    final order = _mockOrders.firstWhere((o) => o["id"] == orderId);
    final prod = _mockProducts.firstWhere((p) => p["id"] == order["product_id"]);

    final currentDel = _mockDeliveries.where((d) => d["order_id"] == orderId).fold<int>(0, (sum, d) => sum + (d["quantity"] as int));
    final pending = order["quantity"] - currentDel;

    if (quantity > pending) {
      throw "交货数量不能超过待交货数量($pending)！";
    }

    if (order["type"] == "销售") {
      if (quantity > prod["quantity"]) {
        throw "库存不足！当前库存只有 ${prod["quantity"]}，而需要发货 $quantity。";
      }
      prod["quantity"] -= quantity;
    } else {
      prod["quantity"] += quantity;
    }

    _mockDeliveries.add({
      "id": _mockDeliveries.length + 1,
      "order_id": orderId,
      "quantity": quantity,
      "delivery_date": date,
      "remarks": remarks
    });
  }

  static Future<void> updateDelivery(int id, Map<String, String> data) async {
    await checkConnection();
    if (isOnline) {
      try {
        var req = http.MultipartRequest("PUT", Uri.parse("$baseUrl/deliveries/$id"));
        data.forEach((key, value) {
          req.fields[key] = value;
        });
        var resStream = await req.send();
        var res = await http.Response.fromStream(resStream);
        if (res.statusCode != 200) {
          final err = jsonDecode(utf8.decode(res.bodyBytes));
          throw err["detail"] ?? "修改交货记录失败";
        }
        return;
      } catch (e) {
        if (e is String) rethrow;
        throw "服务器连接失败";
      }
    }

    // Mock
    final idx = _mockDeliveries.indexWhere((d) => d["id"] == id);
    if (idx != -1) {
      final dRecord = _mockDeliveries[idx];
      final order = _mockOrders.firstWhere((o) => o["id"] == dRecord["order_id"]);
      final prod = _mockProducts.firstWhere((p) => p["id"] == order["product_id"]);
      final newQty = int.parse(data["quantity"]!);

      // Revert old
      if (order["type"] == "销售") {
        prod["quantity"] += dRecord["quantity"];
      } else {
        prod["quantity"] -= dRecord["quantity"];
      }

      // Check new pending
      final currentDelOther = _mockDeliveries.where((d) => d["order_id"] == order["id"] && d["id"] != id).fold<int>(0, (sum, d) => sum + (d["quantity"] as int));
      final pending = order["quantity"] - currentDelOther;

      if (newQty > pending) {
        // Restore old
        if (order["type"] == "销售") {
          prod["quantity"] -= dRecord["quantity"];
        } else {
          prod["quantity"] += dRecord["quantity"];
        }
        throw "交货数量不能超过待交货数量($pending)！";
      }

      // Check stock
      if (order["type"] == "销售" && newQty > prod["quantity"]) {
        // Restore old
        prod["quantity"] -= dRecord["quantity"];
        throw "库存不足！现有库存只有 ${prod["quantity"]}，不足以发货 $newQty。";
      }

      // Apply new
      if (order["type"] == "销售") {
        prod["quantity"] -= newQty;
      } else {
        prod["quantity"] += newQty;
      }

      _mockDeliveries[idx]["quantity"] = newQty;
      _mockDeliveries[idx]["delivery_date"] = data["delivery_date"]!;
      _mockDeliveries[idx]["remarks"] = data["remarks"] ?? "";
      return;
    }
    throw "未找到该交货记录";
  }

  static Future<void> deleteDelivery(int id) async {
    await checkConnection();
    if (isOnline) {
      try {
        final res = await http.delete(Uri.parse("$baseUrl/deliveries/$id"));
        if (res.statusCode != 200) {
          throw "删除失败";
        }
        return;
      } catch (_) {
        throw "服务器连接失败";
      }
    }

    // Mock
    final idx = _mockDeliveries.indexWhere((d) => d["id"] == id);
    if (idx != -1) {
      final dRecord = _mockDeliveries[idx];
      final order = _mockOrders.firstWhere((o) => o["id"] == dRecord["order_id"]);
      final prod = _mockProducts.firstWhere((p) => p["id"] == order["product_id"]);

      if (order["type"] == "销售") {
        prod["quantity"] += dRecord["quantity"];
      } else {
        prod["quantity"] -= dRecord["quantity"];
      }

      _mockDeliveries.removeAt(idx);
      return;
    }
    throw "未找到该交货记录";
  }


  // ==================== FINANCIALS API ====================
  static Future<List<Map<String, dynamic>>> getFinancialsView({bool showAll = false, String? search}) async {
    await checkConnection();
    if (isOnline) {
      try {
        var uri = Uri.parse("$baseUrl/financials?show_all=$showAll" +
            (search != null ? "&search=${Uri.encodeComponent(search)}" : ""));
        final res = await http.get(uri);
        if (res.statusCode == 200) {
          final List list = jsonDecode(utf8.decode(res.bodyBytes));
          return list.map((e) => e as Map<String, dynamic>).toList();
        }
      } catch (_) {}
    }

    // Fallback
    Iterable<Map<String, dynamic>> filtered = _mockOrders;
    if (!showAll) {
      filtered = filtered.where((o) => o["status"] == "进行中");
    }
    if (search != null && search.isNotEmpty) {
      final s = search.toLowerCase();
      filtered = filtered.where((o) =>
          o["code"].toLowerCase().contains(s) ||
          o["customer_name"].toLowerCase().contains(s) ||
          o["product_name"].toLowerCase().contains(s) ||
          o["product_specs"].toLowerCase().contains(s));
    }

    return filtered.map((o) {
      final int orderId = o["id"];
      final total = o["quantity"] * o["unit_price"];

      final paid = _mockFinancials.where((f) => f["order_id"] == orderId).fold(0.0, (sum, f) => sum + f["amount"]);
      final invoiced = _mockFinancials.where((f) => f["order_id"] == orderId && f["is_invoiced"] == true).fold(0.0, (sum, f) => sum + f["amount"]);

      return {
        "order_id": o["id"],
        "order_code": o["code"],
        "type": o["type"],
        "customer_name": o["customer_name"],
        "product_name": o["product_name"],
        "product_specs": o["product_specs"],
        "total_amount": total,
        "paid_amount": paid,
        "pending_amount": (total - paid) < 0 ? 0.0 : (total - paid),
        "invoiced_amount": invoiced,
        "pending_invoice_amount": (total - invoiced) < 0 ? 0.0 : (total - invoiced)
      };
    }).toList();
  }

  static Future<void> createFinancialRecord(Map<String, String> data) async {
    await checkConnection();
    if (isOnline) {
      try {
        var req = http.MultipartRequest("POST", Uri.parse("$baseUrl/financials"));
        data.forEach((key, value) {
          req.fields[key] = value;
        });
        var resStream = await req.send();
        var res = await http.Response.fromStream(resStream);
        if (res.statusCode != 200) {
          final err = jsonDecode(utf8.decode(res.bodyBytes));
          throw err["detail"] ?? "录入财务记录失败";
        }
        return;
      } catch (e) {
        if (e is String) rethrow;
        throw "服务器连接失败";
      }
    }

    // Mock
    final orderId = int.parse(data["order_id"]!);
    final amount = double.parse(data["amount"]!);
    final date = data["payment_date"]!;
    final isInv = data["is_invoiced"] == "true";
    final invNo = data["invoice_no"] ?? "";
    final imgUrl = data["invoice_image_url"] ?? "";
    final remarks = data["remarks"] ?? "";

    final order = _mockOrders.firstWhere((o) => o["id"] == orderId);
    final total = order["quantity"] * order["unit_price"];
    final currentPaid = _mockFinancials.where((f) => f["order_id"] == orderId).fold(0.0, (sum, f) => sum + f["amount"]);

    if (currentPaid + amount > total + 0.01) {
      throw "录入金额超过订单总未收/付余额 (${total - currentPaid})！";
    }

    _mockFinancials.add({
      "id": _mockFinancials.length + 1,
      "order_id": orderId,
      "amount": amount,
      "payment_date": date,
      "invoice_no": invNo,
      "invoice_image_url": imgUrl,
      "is_invoiced": isInv,
      "remarks": remarks
    });
  }

  static Future<void> updateFinancialRecord(int id, Map<String, String> data) async {
    await checkConnection();
    if (isOnline) {
      try {
        var req = http.MultipartRequest("PUT", Uri.parse("$baseUrl/financials/$id"));
        data.forEach((key, value) {
          req.fields[key] = value;
        });
        var resStream = await req.send();
        var res = await http.Response.fromStream(resStream);
        if (res.statusCode != 200) {
          final err = jsonDecode(utf8.decode(res.bodyBytes));
          throw err["detail"] ?? "修改财务记录失败";
        }
        return;
      } catch (e) {
        if (e is String) rethrow;
        throw "服务器连接失败";
      }
    }

    // Mock
    final idx = _mockFinancials.indexWhere((f) => f["id"] == id);
    if (idx != -1) {
      final fRecord = _mockFinancials[idx];
      final order = _mockOrders.firstWhere((o) => o["id"] == fRecord["order_id"]);
      final amount = double.parse(data["amount"]!);
      final total = order["quantity"] * order["unit_price"];

      final currentPaidOther = _mockFinancials.where((f) => f["order_id"] == order["id"] && f["id"] != id).fold(0.0, (sum, f) => sum + f["amount"]);
      if (currentPaidOther + amount > total + 0.01) {
        throw "金额超过订单总未收/付余额 (${total - currentPaidOther})！";
      }

      _mockFinancials[idx]["amount"] = amount;
      _mockFinancials[idx]["payment_date"] = data["payment_date"]!;
      _mockFinancials[idx]["invoice_no"] = data["invoice_no"] ?? "";
      _mockFinancials[idx]["invoice_image_url"] = data["invoice_image_url"] ?? "";
      _mockFinancials[idx]["is_invoiced"] = data["is_invoiced"] == "true";
      _mockFinancials[idx]["remarks"] = data["remarks"] ?? "";
      return;
    }
    throw "未找到该财务记录";
  }

  static Future<void> deleteFinancialRecord(int id) async {
    await checkConnection();
    if (isOnline) {
      try {
        final res = await http.delete(Uri.parse("$baseUrl/financials/$id"));
        if (res.statusCode != 200) {
          throw "删除失败";
        }
        return;
      } catch (_) {
        throw "服务器连接失败";
      }
    }

    // Mock
    _mockFinancials.removeWhere((f) => f["id"] == id);
  }

  // File Upload Helper
  static Future<String> uploadFile(String filename, List<int> bytes) async {
    await checkConnection();
    if (isOnline) {
      try {
        var req = http.MultipartRequest("POST", Uri.parse("$baseUrl/upload"));
        req.files.add(http.MultipartFile.fromBytes("file", bytes, filename: filename));
        var resStream = await req.send();
        var res = await http.Response.fromStream(resStream);
        if (res.statusCode == 200) {
          final data = jsonDecode(utf8.decode(res.bodyBytes));
          return data["url"];
        }
      } catch (_) {}
    }
    // Mock local placeholder
    return "https://picsum.photos/seed/${filename.hashCode}/300/200";
  }
}
