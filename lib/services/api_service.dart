import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  static const String baseUrl = "http://localhost:8000/api";

  // Local fallbacks in case the server is offline or not started - Clean Slate for Physical-Centric WMS/BOM/Traceability
  static List<Map<String, dynamic>> _mockParties = [];
  static List<Map<String, dynamic>> _mockItems = [];
  static List<Map<String, dynamic>> _mockBoms = [];
  static List<Map<String, dynamic>> _mockBinsStocks = [];
  static List<Map<String, dynamic>> _mockLotRecords = [];
  static List<Map<String, dynamic>> _mockOrders = [];
  static List<Map<String, dynamic>> _mockWorkOrders = [];
  static List<Map<String, dynamic>> _mockProductionIssueLogs = [];
  static List<Map<String, dynamic>> _mockFinancialFlows = [];

  // V1 Fallbacks for Backwards Compatibility
  static List<Map<String, dynamic>> _mockProducts = [];
  static List<Map<String, dynamic>> _mockCustomers = [];
  static List<Map<String, dynamic>> _mockDeliveries = [];
  static List<Map<String, dynamic>> _mockFinancials = [];

  static bool isOnline = true;

  // Helper to run a safe network check
  static Future<void> checkConnection() async {
    try {
      final res = await http.get(Uri.parse("$baseUrl/")).timeout(const Duration(milliseconds: 1500));
      if (res.statusCode == 200) {
        isOnline = true;
      } else {
        isOnline = false;
      }
    } catch (_) {
      isOnline = false;
    }
  }

  // ==================== PARTIES API (往来单位) ====================
  static Future<List<Map<String, dynamic>>> getParties({String? search, bool? isCustomer, bool? isSupplier}) async {
    await checkConnection();
    if (isOnline) {
      try {
        var uri = Uri.parse("$baseUrl/parties" +
            (search != null ? "?search=${Uri.encodeComponent(search)}" : "") +
            (isCustomer != null ? (search != null ? "&" : "?") + "is_customer=$isCustomer" : "") +
            (isSupplier != null ? "&is_supplier=$isSupplier" : ""));
        final res = await http.get(uri);
        if (res.statusCode == 200) {
          final List list = jsonDecode(utf8.decode(res.bodyBytes));
          return list.map((e) => e as Map<String, dynamic>).toList();
        }
      } catch (_) {}
    }

    // Fallback
    Iterable<Map<String, dynamic>> filtered = _mockParties;
    if (isCustomer != null) {
      filtered = filtered.where((p) => p["is_customer"] == isCustomer);
    }
    if (isSupplier != null) {
      filtered = filtered.where((p) => p["is_supplier"] == isSupplier);
    }
    if (search != null && search.isNotEmpty) {
      final s = search.toLowerCase();
      filtered = filtered.where((p) =>
          p["code"].toLowerCase().contains(s) ||
          p["name"].toLowerCase().contains(s));
    }
    return filtered.toList();
  }

  static Future<Map<String, dynamic>?> createParty(Map<String, String> data) async {
    await checkConnection();
    if (isOnline) {
      try {
        var req = http.MultipartRequest("POST", Uri.parse("$baseUrl/parties"));
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

    final id = _mockParties.length + 1;
    final newParty = {
      "id": id,
      "code": data["code"] ?? "PART-${id.toString().padLeft(4, '0')}",
      "name": data["name"] ?? "",
      "is_customer": data["is_customer"] == "true",
      "is_supplier": data["is_supplier"] == "true",
      "credit_limit": double.tryParse(data["credit_limit"] ?? "0") ?? 0.0,
      "payment_term": data["payment_term"] ?? "月结30天",
      "contacts": jsonDecode(data["contacts_json"] ?? "[]"),
      "addresses": jsonDecode(data["addresses_json"] ?? "[]"),
    };
    _mockParties.add(newParty);
    return newParty;
  }

  // ==================== ITEMS API (物料档案) ====================
  static Future<List<Map<String, dynamic>>> getItems({String? search, String? type}) async {
    await checkConnection();
    if (isOnline) {
      try {
        var uri = Uri.parse("$baseUrl/items" +
            (search != null ? "?search=${Uri.encodeComponent(search)}" : "") +
            (type != null ? (search != null ? "&" : "?") + "type=${Uri.encodeComponent(type)}" : ""));
        final res = await http.get(uri);
        if (res.statusCode == 200) {
          final List list = jsonDecode(utf8.decode(res.bodyBytes));
          return list.map((e) => e as Map<String, dynamic>).toList();
        }
      } catch (_) {}
    }

    // Fallback
    Iterable<Map<String, dynamic>> filtered = _mockItems;
    if (type != null) {
      filtered = filtered.where((i) => i["type"] == type);
    }
    if (search != null && search.isNotEmpty) {
      final s = search.toLowerCase();
      filtered = filtered.where((i) =>
          i["code"].toLowerCase().contains(s) ||
          i["name"].toLowerCase().contains(s));
    }
    return filtered.toList();
  }

  static Future<Map<String, dynamic>?> createItem(Map<String, String> data) async {
    await checkConnection();
    if (isOnline) {
      try {
        var req = http.MultipartRequest("POST", Uri.parse("$baseUrl/items"));
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

    final id = _mockItems.length + 1;
    final newItem = {
      "id": id,
      "code": data["code"] ?? "MAT-${id.toString().padLeft(4, '0')}",
      "name": data["name"] ?? "",
      "specs": data["specs"] ?? "",
      "unit": data["unit"] ?? "个",
      "type": data["type"] ?? "成品",
      "min_safety_stock": double.tryParse(data["min_safety_stock"] ?? "0") ?? 0.0,
      "max_safety_stock": double.tryParse(data["max_safety_stock"] ?? "99999") ?? 99999.0,
      "remarks": data["remarks"] ?? "",
    };
    _mockItems.add(newItem);
    return newItem;
  }


  // ==================== BILL OF MATERIALS (BOM) API ====================
  static Future<List<Map<String, dynamic>>> getBoms() async {
    await checkConnection();
    if (isOnline) {
      try {
        final res = await http.get(Uri.parse("$baseUrl/boms"));
        if (res.statusCode == 200) {
          final List list = jsonDecode(utf8.decode(res.bodyBytes));
          return list.map((e) => e as Map<String, dynamic>).toList();
        }
      } catch (_) {}
    }
    return _mockBoms;
  }

  static Future<Map<String, dynamic>> getBomTree(int parentItemId) async {
    await checkConnection();
    if (isOnline) {
      try {
        final res = await http.get(Uri.parse("$baseUrl/boms/$parentItemId"));
        if (res.statusCode == 200) {
          return jsonDecode(utf8.decode(res.bodyBytes));
        }
      } catch (_) {}
    }
    return {
      "id": 1,
      "parent_item_id": parentItemId,
      "parent_item_code": "PROD-MOCK",
      "parent_item_name": "离线成品",
      "version": "V1.0",
      "children": []
    };
  }

  static Future<void> createBom(int parentItemId, String version, String childrenJson) async {
    await checkConnection();
    if (isOnline) {
      try {
        var req = http.MultipartRequest("POST", Uri.parse("$baseUrl/boms"));
        req.fields["parent_item_id"] = parentItemId.toString();
        req.fields["version"] = version;
        req.fields["children_json"] = childrenJson;
        var resStream = await req.send();
        var res = await http.Response.fromStream(resStream);
        if (res.statusCode != 200) {
          throw jsonDecode(utf8.decode(res.bodyBytes))["detail"] ?? "BOM formulation configuration failed";
        }
        return;
      } catch (e) {
        if (e is String) rethrow;
      }
    }
  }


  // ==================== WMS WAREHOUSES & STOCKTAKE API ====================
  static Future<List<Map<String, dynamic>>> getWarehouseBins({String? warehouseType, String? search}) async {
    await checkConnection();
    if (isOnline) {
      try {
        var uri = Uri.parse("$baseUrl/warehouses/bins" +
            (warehouseType != null ? "?warehouse_type=$warehouseType" : "") +
            (search != null ? (warehouseType != null ? "&" : "?") + "search=${Uri.encodeComponent(search)}" : ""));
        final res = await http.get(uri);
        if (res.statusCode == 200) {
          final List list = jsonDecode(utf8.decode(res.bodyBytes));
          return list.map((e) => e as Map<String, dynamic>).toList();
        }
      } catch (_) {}
    }
    return _mockBinsStocks;
  }

  static Future<void> adjustStockBin(Map<String, String> data) async {
    await checkConnection();
    if (isOnline) {
      try {
        var req = http.MultipartRequest("POST", Uri.parse("$baseUrl/warehouses/bins"));
        data.forEach((key, value) {
          req.fields[key] = value;
        });
        var resStream = await req.send();
        var res = await http.Response.fromStream(resStream);
        if (res.statusCode != 200) {
          throw jsonDecode(utf8.decode(res.bodyBytes))["detail"] ?? "Stock adjustments failed";
        }
        return;
      } catch (e) {
        if (e is String) rethrow;
      }
    }
  }

  static Future<void> toggleStocktakeLock(String warehouseType, bool isLocked) async {
    await checkConnection();
    if (isOnline) {
      try {
        var req = http.MultipartRequest("POST", Uri.parse("$baseUrl/warehouses/stocktake/lock"));
        req.fields["warehouse_type"] = warehouseType;
        req.fields["is_locked"] = isLocked.toString();
        await req.send();
      } catch (_) {}
    }
  }

  static Future<Map<String, dynamic>> submitBlindStocktake(int binStockId, double observedQuantity) async {
    await checkConnection();
    if (isOnline) {
      try {
        var req = http.MultipartRequest("POST", Uri.parse("$baseUrl/warehouses/stocktake/submit"));
        req.fields["bin_stock_id"] = binStockId.toString();
        req.fields["observed_quantity"] = observedQuantity.toString();
        var resStream = await req.send();
        var res = await http.Response.fromStream(resStream);
        if (res.statusCode == 200) {
          return jsonDecode(utf8.decode(res.bodyBytes));
        }
      } catch (_) {}
    }
    return {"message": "Stocktake completed local fallback", "discrepancy": 0};
  }


  // ==================== LOTS API ====================
  static Future<List<Map<String, dynamic>>> getLots() async {
    await checkConnection();
    if (isOnline) {
      try {
        final res = await http.get(Uri.parse("$baseUrl/lots"));
        if (res.statusCode == 200) {
          final List list = jsonDecode(utf8.decode(res.bodyBytes));
          return list.map((e) => e as Map<String, dynamic>).toList();
        }
      } catch (_) {}
    }
    return _mockLotRecords;
  }

  static Future<Map<String, dynamic>?> recommendFifoBatch(int itemId) async {
    await checkConnection();
    if (isOnline) {
      try {
        final res = await http.get(Uri.parse("$baseUrl/lots/fifo?item_id=$itemId"));
        if (res.statusCode == 200) {
          return jsonDecode(utf8.decode(res.bodyBytes));
        }
      } catch (_) {}
    }
    return null;
  }


  // ==================== WORK ORDERS API ====================
  static Future<List<Map<String, dynamic>>> getWorkOrders() async {
    await checkConnection();
    if (isOnline) {
      try {
        final res = await http.get(Uri.parse("$baseUrl/work_orders"));
        if (res.statusCode == 200) {
          final List list = jsonDecode(utf8.decode(res.bodyBytes));
          return list.map((e) => e as Map<String, dynamic>).toList();
        }
      } catch (_) {}
    }
    return _mockWorkOrders;
  }

  static Future<Map<String, dynamic>?> createWorkOrder(Map<String, String> data) async {
    await checkConnection();
    if (isOnline) {
      try {
        var req = http.MultipartRequest("POST", Uri.parse("$baseUrl/work_orders"));
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
    return null;
  }

  static Future<void> registerProductionIssue(int workOrderId, String type, int itemId, int lotId, double quantity, {String? scrapReason}) async {
    await checkConnection();
    if (isOnline) {
      try {
        var req = http.MultipartRequest("POST", Uri.parse("$baseUrl/work_orders/$workOrderId/issue"));
        req.fields["type"] = type;
        req.fields["item_id"] = itemId.toString();
        req.fields["lot_id"] = lotId.toString();
        req.fields["quantity"] = quantity.toString();
        if (scrapReason != null) {
          req.fields["scrap_reason"] = scrapReason;
        }
        var resStream = await req.send();
        var res = await http.Response.fromStream(resStream);
        if (res.statusCode != 200) {
          throw jsonDecode(utf8.decode(res.bodyBytes))["detail"] ?? "Issue registration failed";
        }
      } catch (e) {
        if (e is String) rethrow;
      }
    }
  }

  static Future<List<Map<String, dynamic>>> getMaterialConsumptionReconciliation(int workOrderId) async {
    await checkConnection();
    if (isOnline) {
      try {
        final res = await http.get(Uri.parse("$baseUrl/work_orders/$workOrderId/consumption"));
        if (res.statusCode == 200) {
          final List list = jsonDecode(utf8.decode(res.bodyBytes));
          return list.map((e) => e as Map<String, dynamic>).toList();
        }
      } catch (_) {}
    }
    return [];
  }


  // ==================== MINIMALIST FINANCIAL FLOWS API ====================
  static Future<List<Map<String, dynamic>>> getFinancialLedger() async {
    await checkConnection();
    if (isOnline) {
      try {
        final res = await http.get(Uri.parse("$baseUrl/finance/flows"));
        if (res.statusCode == 200) {
          final List list = jsonDecode(utf8.decode(res.bodyBytes));
          return list.map((e) => e as Map<String, dynamic>).toList();
        }
      } catch (_) {}
    }
    return _mockFinancialFlows;
  }

  static Future<void> reconcileBillAccount(int partyId, String reconcileType, double amount, String paymentMethod, {String? remarks}) async {
    await checkConnection();
    if (isOnline) {
      try {
        var req = http.MultipartRequest("POST", Uri.parse("$baseUrl/finance/reconcile"));
        req.fields["party_id"] = partyId.toString();
        req.fields["reconcile_type"] = reconcileType;
        req.fields["amount"] = amount.toString();
        req.fields["payment_method"] = paymentMethod;
        if (remarks != null) {
          req.fields["remarks"] = remarks;
        }
        await req.send();
      } catch (_) {}
    }
  }

  static Future<void> createMiscExpenseIncome(String type, double amount, String remarks) async {
    await checkConnection();
    if (isOnline) {
      try {
        var req = http.MultipartRequest("POST", Uri.parse("$baseUrl/finance/flows/misc"));
        req.fields["type"] = type;
        req.fields["amount"] = amount.toString();
        req.fields["remarks"] = remarks;
        await req.send();
      } catch (_) {}
    }
  }

  static Future<Map<String, dynamic>> getReconciledCashBalance() async {
    await checkConnection();
    if (isOnline) {
      try {
        final res = await http.get(Uri.parse("$baseUrl/finance/balance"));
        if (res.statusCode == 200) {
          return jsonDecode(utf8.decode(res.bodyBytes));
        }
      } catch (_) {}
    }
    return {
      "initial_balance": 100000.0,
      "total_receipts": 0.0,
      "total_disbursements": 0.0,
      "current_cash_balance": 100000.0
    };
  }


  // ==================== TRACEABILITY API ====================
  static Future<Map<String, dynamic>?> positiveTraceability(String lotNumber) async {
    await checkConnection();
    if (isOnline) {
      try {
        final res = await http.get(Uri.parse("$baseUrl/traceability/forward?lot_number=${Uri.encodeComponent(lotNumber)}"));
        if (res.statusCode == 200) {
          return jsonDecode(utf8.decode(res.bodyBytes));
        }
      } catch (_) {}
    }
    return null;
  }

  static Future<Map<String, dynamic>?> reverseTraceability(String lotNumber) async {
    await checkConnection();
    if (isOnline) {
      try {
        final res = await http.get(Uri.parse("$baseUrl/traceability/backward?lot_number=${Uri.encodeComponent(lotNumber)}"));
        if (res.statusCode == 200) {
          return jsonDecode(utf8.decode(res.bodyBytes));
        }
      } catch (_) {}
    }
    return null;
  }


  // ==================== V1 BACKWARDS COMPATIBILITY WRAPPERS ====================

  static Future<List<Map<String, dynamic>>> getProducts({bool showOffShelf = false, String? search, String? name, String? specs}) async {
    return getItems(search: search);
  }

  static Future<Map<String, dynamic>?> createProduct(Map<String, String> data) async {
    return createItem(data);
  }

  static Future<Map<String, dynamic>?> updateProduct(int id, Map<String, String> data) async {
    await checkConnection();
    if (isOnline) {
      try {
        var req = http.MultipartRequest("PUT", Uri.parse("$baseUrl/items/$id"));
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
    return null;
  }

  static Future<void> toggleProductStatus(int id, String status) async {}

  static Future<void> deleteProduct(int id) async {
    await checkConnection();
    if (isOnline) {
      try {
        await http.delete(Uri.parse("$baseUrl/items/$id"));
      } catch (_) {}
    }
  }

  static Future<List<Map<String, dynamic>>> getProductHistory(int productId) async {
    return [];
  }

  static Future<List<Map<String, dynamic>>> getCustomers({String? search, String? name, String? contactPerson}) async {
    return getParties(search: search, isCustomer: true);
  }

  static Future<Map<String, dynamic>> getCustomerDetails(int id) async {
    await checkConnection();
    if (isOnline) {
      try {
        final res = await http.get(Uri.parse("$baseUrl/parties/$id"));
        if (res.statusCode == 200) {
          final data = jsonDecode(utf8.decode(res.bodyBytes));
          return {
            ...data,
            "ongoing_orders_count": 0,
            "pending_amount": 0.0,
            "total_deal_amount": 0.0,
            "order_history": []
          };
        }
      } catch (_) {}
    }
    return {};
  }

  static Future<Map<String, dynamic>?> createCustomer(Map<String, String> data) async {
    data["is_customer"] = "true";
    data["is_supplier"] = "false";
    return createParty(data);
  }

  static Future<Map<String, dynamic>?> updateCustomer(int id, Map<String, String> data) async {
    await checkConnection();
    if (isOnline) {
      try {
        var req = http.MultipartRequest("PUT", Uri.parse("$baseUrl/parties/$id"));
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
    return null;
  }

  static Future<void> deleteCustomer(int id) async {
    await checkConnection();
    if (isOnline) {
      try {
        await http.delete(Uri.parse("$baseUrl/parties/$id"));
      } catch (_) {}
    }
  }

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
    return _mockOrders;
  }

  static Future<Map<String, dynamic>> getOrderDetails(int id) async {
    await checkConnection();
    if (isOnline) {
      try {
        final res = await http.get(Uri.parse("$baseUrl/orders/$id"));
        if (res.statusCode == 200) {
          final data = jsonDecode(utf8.decode(res.bodyBytes));
          return {
            ...data,
            "deliveries": [],
            "financials": []
          };
        }
      } catch (_) {}
    }
    return {};
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
        }
      } catch (_) {}
    }
    return null;
  }

  static Future<Map<String, dynamic>?> updateOrder(int id, Map<String, String> data) async {
    return null;
  }

  static Future<void> deleteOrder(int id) async {
    await checkConnection();
    if (isOnline) {
      try {
        await http.delete(Uri.parse("$baseUrl/orders/$id"));
      } catch (_) {}
    }
  }

  static Future<List<Map<String, dynamic>>> getDeliveriesView({bool showAll = false, String? search}) async {
    return [];
  }

  static Future<void> createDelivery(Map<String, String> data) async {}
  static Future<void> updateDelivery(int id, Map<String, String> data) async {}
  static Future<void> deleteDelivery(int id) async {}

  static Future<List<Map<String, dynamic>>> getFinancialsView({bool showAll = false, String? search}) async {
    return [];
  }

  static Future<void> createFinancialRecord(Map<String, String> data) async {}
  static Future<void> updateFinancialRecord(int id, Map<String, String> data) async {}
  static Future<void> deleteFinancialRecord(int id) async {}


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
    return "https://picsum.photos/seed/${filename.hashCode}/300/200";
  }
}
