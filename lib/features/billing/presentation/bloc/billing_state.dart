part of 'billing_bloc.dart';

class BillingState extends Equatable {
  final List<CartItem> cartItems;
  final String? error;
  final bool isPrinting;
  final bool printSuccess;
  final bool isSavingCheckout;
  final String? completedTransactionNumber;

  const BillingState({
    this.cartItems = const [],
    this.error,
    this.isPrinting = false,
    this.printSuccess = false,
    this.isSavingCheckout = false,
    this.completedTransactionNumber,
  });

  double get totalAmount => cartItems.fold(0, (sum, item) => sum + item.total);
  int get checkoutTotalAmount => cartItems.fold<int>(
        0,
        (sum, item) => sum + item.product.price.round() * item.quantity,
      );

  BillingState copyWith({
    List<CartItem>? cartItems,
    String? error,
    bool clearError = false,
    bool? isPrinting,
    bool? printSuccess,
    bool? isSavingCheckout,
    String? completedTransactionNumber,
  }) {
    return BillingState(
      cartItems: cartItems ?? this.cartItems,
      error: clearError ? null : (error ?? this.error),
      isPrinting: isPrinting ?? this.isPrinting,
      printSuccess: printSuccess ?? this.printSuccess,
      isSavingCheckout: isSavingCheckout ?? this.isSavingCheckout,
      completedTransactionNumber:
          completedTransactionNumber ?? this.completedTransactionNumber,
    );
  }

  @override
  List<Object?> get props => [
        cartItems,
        error,
        isPrinting,
        printSuccess,
        isSavingCheckout,
        completedTransactionNumber,
      ];
}
