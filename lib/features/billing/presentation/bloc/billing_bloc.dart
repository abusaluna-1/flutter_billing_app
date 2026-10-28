import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/data/hive_database.dart';
import '../../../../core/usecase/usecase.dart';
import '../../../../core/utils/printer_helper.dart';
import '../../../product/domain/entities/product.dart';
import '../../../product/domain/usecases/product_usecases.dart';
import '../../../transaction/domain/entities/transaction.dart';
import '../../../transaction/domain/usecases/transaction_usecases.dart';
import '../../domain/entities/cart_item.dart';

part 'billing_event.dart';
part 'billing_state.dart';

class BillingBloc extends Bloc<BillingEvent, BillingState> {
  final GetProductByBarcodeUseCase getProductByBarcodeUseCase;
  final GenerateTransactionNumberUseCase? generateTransactionNumberUseCase;
  final SaveTransactionUseCase? saveTransactionUseCase;

  BillingBloc({
    required this.getProductByBarcodeUseCase,
    this.generateTransactionNumberUseCase,
    this.saveTransactionUseCase,
  }) : super(const BillingState()) {
    on<ScanBarcodeEvent>(_onScanBarcode);
    on<AddProductToCartEvent>(_onAddProductToCart);
    on<RemoveProductFromCartEvent>(_onRemoveProductFromCart);
    on<UpdateQuantityEvent>(_onUpdateQuantity);
    on<ClearCartEvent>(_onClearCart);
    on<CompleteCheckoutEvent>(_onCompleteCheckout);
    on<PrintReceiptEvent>(_onPrintReceipt);
  }

  Future<void> _onScanBarcode(
      ScanBarcodeEvent event, Emitter<BillingState> emit) async {
    final result = await getProductByBarcodeUseCase(event.barcode);
    result.fold(
      (failure) =>
          emit(state.copyWith(error: 'Produk tidak ditemukan: ${event.barcode}')),
      (product) {
        add(AddProductToCartEvent(product));
      },
    );
  }

  void _onAddProductToCart(
      AddProductToCartEvent event, Emitter<BillingState> emit) {
    if (state.isSavingCheckout) return;
    // Clear error when adding
    final cleanState = state.copyWith(error: null);

    final existingIndex = cleanState.cartItems
        .indexWhere((item) => item.product.id == event.product.id);
    if (existingIndex >= 0) {
      final existingItem = cleanState.cartItems[existingIndex];
      final backendItems = List<CartItem>.from(cleanState.cartItems);
      backendItems[existingIndex] =
          existingItem.copyWith(quantity: existingItem.quantity + 1);
      emit(cleanState.copyWith(cartItems: backendItems, error: null));
    } else {
      final newItem = CartItem(product: event.product);
      emit(cleanState.copyWith(
          cartItems: [...cleanState.cartItems, newItem], error: null));
    }
  }

  void _onRemoveProductFromCart(
      RemoveProductFromCartEvent event, Emitter<BillingState> emit) {
    if (state.isSavingCheckout) return;
    final updatedList = state.cartItems
        .where((item) => item.product.id != event.productId)
        .toList();
    emit(state.copyWith(cartItems: updatedList));
  }

  void _onUpdateQuantity(
      UpdateQuantityEvent event, Emitter<BillingState> emit) {
    if (state.isSavingCheckout) return;
    if (event.quantity <= 0) {
      add(RemoveProductFromCartEvent(event.productId));
      return;
    }

    final index = state.cartItems
        .indexWhere((item) => item.product.id == event.productId);
    if (index >= 0) {
      final items = List<CartItem>.from(state.cartItems);
      items[index] = items[index].copyWith(quantity: event.quantity);
      emit(state.copyWith(cartItems: items));
    }
  }

  void _onClearCart(ClearCartEvent event, Emitter<BillingState> emit) {
    if (state.isSavingCheckout) return;
    emit(const BillingState());
  }

  Future<void> _onCompleteCheckout(
      CompleteCheckoutEvent event, Emitter<BillingState> emit) async {
    if (state.isSavingCheckout) return;
    if (state.cartItems.isEmpty) {
      emit(state.copyWith(error: 'Keranjang masih kosong.', clearError: false));
      return;
    }
    if (event.customerName.trim().isEmpty) {
      emit(state.copyWith(
          error: 'Nama customer wajib diisi.', clearError: false));
      return;
    }
    if (event.adminName.trim().isEmpty) {
      emit(state.copyWith(
          error: 'Nama admin/kasir wajib diisi.', clearError: false));
      return;
    }
    if (event.amountPaid < 0 ||
        event.amountPaid > state.checkoutTotalAmount ||
        event.paymentMethod.trim().isEmpty) {
      emit(state.copyWith(
          error: 'Nominal atau metode pembayaran tidak valid.',
          clearError: false));
      return;
    }
    final generateNumber = generateTransactionNumberUseCase;
    final saveTransaction = saveTransactionUseCase;
    if (generateNumber == null || saveTransaction == null) {
      emit(state.copyWith(
          error: 'Penyimpanan transaksi belum dikonfigurasi.',
          clearError: false));
      return;
    }
    final checkoutItems = List<CartItem>.unmodifiable(state.cartItems);

    emit(state.copyWith(
        error: null, clearError: true, isSavingCheckout: true));

    try {
      await HiveDatabase.settingsBox.put(
          'active_admin_name', event.adminName.trim());
      final numberResult =
          await generateNumber(NoParams());
      final transactionNumber = numberResult.fold<String?>(
        (failure) => null,
        (value) => value,
      );

      if (transactionNumber == null) {
        final message = numberResult.fold(
          (failure) => failure.message,
          (_) => 'Gagal membuat nomor transaksi.',
        );
        emit(state.copyWith(
            error: message,
            clearError: false,
            isSavingCheckout: false));
        return;
      }

      final createdAt = DateTime.now();
      var transaction = Transaction.fromCart(
        id: const Uuid().v4(),
        transactionNumber: transactionNumber,
        createdAt: createdAt,
        customerName: event.customerName,
        customerPhone: event.customerPhone,
        adminName: event.adminName,
        cartItems: checkoutItems,
      );
      if (event.amountPaid > 0) {
        transaction = transaction.addPayment(PaymentRecord(
          id: const Uuid().v4(),
          transactionId: transaction.id,
          amount: event.amountPaid,
          paidAt: createdAt,
          method: event.paymentMethod.trim(),
          adminName: event.adminName.trim(),
        ));
      }

      final saveResult = await saveTransaction(transaction);
      final saveError = saveResult.fold<String?>(
        (failure) => failure.message,
        (_) => null,
      );
      if (saveError != null) {
        emit(state.copyWith(
            error: saveError,
            clearError: false,
            isSavingCheckout: false));
        return;
      }

      emit(BillingState(completedTransactionNumber: transactionNumber));
    } catch (error) {
      emit(state.copyWith(
          error: 'Checkout gagal: $error',
          clearError: false,
          isSavingCheckout: false));
    }
  }

  Future<void> _onPrintReceipt(
      PrintReceiptEvent event, Emitter<BillingState> emit) async {
    final printerHelper = PrinterHelper();

    if (!printerHelper.isConnected) {
      final savedMac = HiveDatabase.settingsBox.get('printer_mac');
      if (savedMac != null) {
        final connected = await printerHelper.connect(savedMac);
        if (!connected) {
          emit(state.copyWith(
              error: 'Gagal menyambung otomatis ke printer!', clearError: false));
          emit(state.copyWith(clearError: true));
          return;
        }
      } else {
        emit(state.copyWith(
            error: 'Printer belum tersambung dan belum ada printer tersimpan!',
            clearError: false));
        emit(state.copyWith(clearError: true));
        return;
      }
    }

    emit(state.copyWith(
        isPrinting: true, printSuccess: false, clearError: true));

    try {
      final items = state.cartItems
          .map((item) => {
                'name': item.product.name,
                'qty': item.quantity,
                'price': item.product.price,
                'total': item.total,
              })
          .toList();

      await printerHelper.printReceipt(
          shopName: event.shopName,
          address1: event.address1,
          address2: event.address2,
          phone: event.phone,
          items: items,
          total: state.totalAmount,
          footer: event.footer);

      emit(state.copyWith(isPrinting: false, printSuccess: true));
    } catch (e) {
      emit(state.copyWith(
          isPrinting: false, error: 'Gagal mencetak: $e', clearError: false));
      // Reset error instantly avoids sticky error
      emit(state.copyWith(clearError: true));
    }
  }
}
