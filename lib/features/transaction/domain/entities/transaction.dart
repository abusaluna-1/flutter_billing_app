import 'package:equatable/equatable.dart';

import '../../../billing/domain/entities/cart_item.dart';
import '../../../product/domain/entities/product.dart';

class CustomerSnapshot extends Equatable {
  final String name;
  final String phone;

  const CustomerSnapshot({this.name = '', this.phone = ''});

  CustomerSnapshot copyWith({String? name, String? phone}) {
    return CustomerSnapshot(
      name: name ?? this.name,
      phone: phone ?? this.phone,
    );
  }

  factory CustomerSnapshot.fromJson(Map<String, dynamic> json) {
    return CustomerSnapshot(
      name: (json['name'] ?? '').toString(),
      phone: (json['phone'] ?? '').toString(),
    );
  }

  Map<String, dynamic> toJson() => {'name': name, 'phone': phone};

  @override
  List<Object?> get props => [name, phone];
}

class AdminSnapshot extends Equatable {
  final String name;

  const AdminSnapshot({this.name = ''});

  AdminSnapshot copyWith({String? name}) => AdminSnapshot(name: name ?? this.name);

  factory AdminSnapshot.fromJson(Map<String, dynamic> json) {
    return AdminSnapshot(name: (json['name'] ?? '').toString());
  }

  Map<String, dynamic> toJson() => {'name': name};

  @override
  List<Object?> get props => [name];
}

enum TransactionStatus {
  pending,
  partial,
  paid,
}

extension TransactionStatusX on TransactionStatus {
  String get value => switch (this) {
        TransactionStatus.pending => 'pending',
        TransactionStatus.partial => 'partial',
        TransactionStatus.paid => 'paid',
      };

  String get label => switch (this) {
        TransactionStatus.pending => 'Belum Dibayar',
        TransactionStatus.partial => 'DP',
        TransactionStatus.paid => 'Lunas',
      };

  static TransactionStatus fromValue(String? value) {
    switch (value) {
      case 'partial':
        return TransactionStatus.partial;
      case 'paid':
        return TransactionStatus.paid;
      case 'pending':
      default:
        return TransactionStatus.pending;
    }
  }
}

class TransactionItem extends Equatable {
  final String id;
  final String name;
  final String type;
  final String? masterRef;
  final String? barcode;
  final String? unit;
  final int price;
  final int quantity;
  final int subtotal;

  const TransactionItem({
    required this.id,
    required this.name,
    required this.type,
    this.masterRef,
    this.barcode,
    this.unit,
    required this.price,
    required this.quantity,
    required this.subtotal,
  });

  static TransactionItem fromProduct(Product product, {int quantity = 1}) {
    final q = quantity <= 0 ? 1 : quantity;
    return TransactionItem(
      id: product.id,
      name: product.name,
      type: product.isService ? 'service' : 'product',
      masterRef: product.id,
      barcode: product.barcode.isNotEmpty ? product.barcode : null,
      unit: product.isService ? 'Pekerjaan' : null,
      price: product.price.round(),
      quantity: q,
      subtotal: product.price.round() * q,
    );
  }

  static TransactionItem fromCartItem(CartItem item) {
    final product = item.product;
    return TransactionItem.fromProduct(product, quantity: item.quantity);
  }

  TransactionItem copyWith({
    String? id,
    String? name,
    String? type,
    String? masterRef,
    String? barcode,
    String? unit,
    int? price,
    int? quantity,
    int? subtotal,
  }) {
    return TransactionItem(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      masterRef: masterRef ?? this.masterRef,
      barcode: barcode ?? this.barcode,
      unit: unit ?? this.unit,
      price: price ?? this.price,
      quantity: quantity ?? this.quantity,
      subtotal: subtotal ?? this.subtotal,
    );
  }

  factory TransactionItem.fromJson(Map<String, dynamic> json) {
    return TransactionItem(
      id: (json['id'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      type: (json['type'] ?? 'product').toString(),
      masterRef: json['masterRef']?.toString(),
      barcode: json['barcode']?.toString(),
      unit: json['unit']?.toString(),
      price: _toInt(json['price']),
      quantity: _toInt(json['quantity']),
      subtotal: _toInt(json['subtotal']),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'type': type,
        'masterRef': masterRef,
        'barcode': barcode,
        'unit': unit,
        'price': price,
        'quantity': quantity,
        'subtotal': subtotal,
      };

  @override
  List<Object?> get props => [
        id,
        name,
        type,
        masterRef,
        barcode,
        unit,
        price,
        quantity,
        subtotal,
      ];
}

class PaymentRecord extends Equatable {
  final String id;
  final String transactionId;
  final int amount;
  final DateTime paidAt;
  final String method;
  final String adminName;

  const PaymentRecord({
    required this.id,
    required this.transactionId,
    required this.amount,
    required this.paidAt,
    required this.method,
    required this.adminName,
  });

  factory PaymentRecord.fromJson(Map<String, dynamic> json) {
    return PaymentRecord(
      id: (json['id'] ?? '').toString(),
      transactionId: (json['transactionId'] ?? '').toString(),
      amount: _toInt(json['amount']),
      paidAt: _parseDateTime(json['paidAt']),
      method: (json['method'] ?? 'Tunai').toString(),
      adminName: (json['adminName'] ?? '').toString(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'transactionId': transactionId,
        'amount': amount,
        'paidAt': paidAt.toIso8601String(),
        'method': method,
        'adminName': adminName,
      };

  @override
  List<Object?> get props => [id, transactionId, amount, paidAt, method, adminName];
}

class Transaction extends Equatable {
  final String id;
  final String transactionNumber;
  final DateTime createdAt;
  final CustomerSnapshot customer;
  final String adminName;
  final List<TransactionItem> items;
  final int subtotal;
  final int discount;
  final int grandTotal;
  final TransactionStatus status;
  final List<PaymentRecord> payments;
  final int totalPaid;
  final int remainingBalance;

  const Transaction({
    required this.id,
    required this.transactionNumber,
    required this.createdAt,
    this.customer = const CustomerSnapshot(),
    this.adminName = '',
    this.items = const [],
    this.subtotal = 0,
    this.discount = 0,
    this.grandTotal = 0,
    this.status = TransactionStatus.pending,
    this.payments = const [],
    this.totalPaid = 0,
    this.remainingBalance = 0,
  });

  static Transaction fromCart({
    required String id,
    required String transactionNumber,
    required DateTime createdAt,
    required String customerName,
    required String customerPhone,
    required String adminName,
    required List<CartItem> cartItems,
    int discount = 0,
  }) {
    final items = cartItems.map(TransactionItem.fromCartItem).toList();
    final subtotal = items.fold<int>(0, (sum, item) => sum + item.subtotal);
    final grandTotal = subtotal - discount;
    final status = _computeStatus(grandTotal, 0);

    return Transaction(
      id: id,
      transactionNumber: transactionNumber,
      createdAt: createdAt,
      customer: CustomerSnapshot(name: customerName.trim(), phone: customerPhone.trim()),
      adminName: adminName.trim(),
      items: items,
      subtotal: subtotal,
      discount: discount,
      grandTotal: grandTotal,
      status: status,
      totalPaid: 0,
      remainingBalance: grandTotal,
    );
  }

  Transaction copyWith({
    String? id,
    String? transactionNumber,
    DateTime? createdAt,
    CustomerSnapshot? customer,
    String? adminName,
    List<TransactionItem>? items,
    int? subtotal,
    int? discount,
    int? grandTotal,
    TransactionStatus? status,
    List<PaymentRecord>? payments,
    int? totalPaid,
    int? remainingBalance,
  }) {
    final mutablePayments = payments ?? this.payments;
    final effectiveTotalPaid = totalPaid ?? mutablePayments.fold<int>(0, (sum, payment) => sum + payment.amount);
    final targetGrandTotal = grandTotal ?? this.grandTotal;
    final effectiveRemaining = remainingBalance ?? (targetGrandTotal - effectiveTotalPaid);
    final nextStatus = status ?? _computeStatus(targetGrandTotal, effectiveTotalPaid);

    return Transaction(
      id: id ?? this.id,
      transactionNumber: transactionNumber ?? this.transactionNumber,
      createdAt: createdAt ?? this.createdAt,
      customer: customer ?? this.customer,
      adminName: adminName ?? this.adminName,
      items: items ?? this.items,
      subtotal: subtotal ?? this.subtotal,
      discount: discount ?? this.discount,
      grandTotal: targetGrandTotal,
      status: nextStatus,
      payments: mutablePayments,
      totalPaid: effectiveTotalPaid,
      remainingBalance: effectiveRemaining,
    );
  }

  Transaction addPayment(PaymentRecord payment) {
    if (payments.any((p) => p.id == payment.id) ||
        payment.amount <= 0 ||
        payment.transactionId != id ||
        payment.amount > remainingBalance) {
      return this;
    }

    final updated = [...payments, payment];
    final totalPaid = updated.fold<int>(0, (sum, item) => sum + item.amount);
    final remaining = grandTotal - totalPaid;
    return copyWith(
      payments: updated,
      totalPaid: totalPaid,
      remainingBalance: remaining,
      status: _computeStatus(grandTotal, totalPaid),
    );
  }

  factory Transaction.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'];
    final items = <TransactionItem>[];
    if (rawItems is List) {
      for (final item in rawItems) {
        if (item is Map) {
          items.add(TransactionItem.fromJson(Map<String, dynamic>.from(item)));
        }
      }
    }

    final rawPayments = json['payments'];
    final payments = <PaymentRecord>[];
    if (rawPayments is List) {
      for (final item in rawPayments) {
        if (item is Map) {
          payments.add(PaymentRecord.fromJson(Map<String, dynamic>.from(item)));
        }
      }
    }

    final grandTotal = _toInt(json['grandTotal']);
    final totalPaid = _toInt(json['totalPaid']);
    final statusValue = json['status'];

    return Transaction(
      id: (json['id'] ?? '').toString(),
      transactionNumber: (json['transactionNumber'] ?? '').toString(),
      createdAt: _parseDateTime(json['createdAt']),
      customer: CustomerSnapshot.fromJson(Map<String, dynamic>.from(json['customer'] ?? {})),
      adminName: (json['adminName'] ?? '').toString(),
      items: items,
      subtotal: _toInt(json['subtotal']),
      discount: _toInt(json['discount']),
      grandTotal: grandTotal,
      status: TransactionStatusX.fromValue(statusValue?.toString()),
      payments: payments,
      totalPaid: totalPaid,
      remainingBalance: _toInt(json['remainingBalance']),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'transactionNumber': transactionNumber,
        'createdAt': createdAt.toIso8601String(),
        'customer': customer.toJson(),
        'adminName': adminName,
        'items': items.map((item) => item.toJson()).toList(),
        'subtotal': subtotal,
        'discount': discount,
        'grandTotal': grandTotal,
        'status': status.value,
        'payments': payments.map((item) => item.toJson()).toList(),
        'totalPaid': totalPaid,
        'remainingBalance': remainingBalance,
      };

  @override
  List<Object?> get props => [
        id,
        transactionNumber,
        createdAt,
        customer,
        adminName,
        items,
        subtotal,
        discount,
        grandTotal,
        status,
        payments,
        totalPaid,
        remainingBalance,
      ];
}

TransactionStatus _computeStatus(int grandTotal, int totalPaid) {
  final remaining = grandTotal - totalPaid;
  if (remaining <= 0) return TransactionStatus.paid;
  if (totalPaid > 0) return TransactionStatus.partial;
  return TransactionStatus.pending;
}

int _toInt(dynamic value) {
  if (value is int) return value;
  if (value is double) return value.round();
  if (value is String) return int.tryParse(value) ?? 0;
  return 0;
}

DateTime _parseDateTime(dynamic value) {
  if (value is DateTime) return value;
  if (value is String && value.isNotEmpty) {
    return DateTime.tryParse(value) ?? DateTime.now();
  }
  if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
  return DateTime.now();
}
