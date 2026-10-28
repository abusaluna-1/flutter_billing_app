import 'package:go_router/go_router.dart';
import '../../features/billing/presentation/pages/home_page.dart';
import '../../features/product/presentation/pages/product_list_page.dart';
import '../../features/product/presentation/pages/add_product_page.dart';
import '../../features/product/presentation/pages/edit_product_page.dart';
import '../../features/shop/presentation/pages/shop_details_page.dart';
import '../../features/settings/presentation/pages/settings_page.dart';
import '../../features/billing/presentation/pages/scanner_page.dart';
import '../../features/billing/presentation/pages/checkout_page.dart';
import '../../features/product/domain/entities/product.dart';
import '../../features/service/domain/entities/service_item.dart';
import '../../features/service/presentation/pages/service_category_page.dart';
import '../../features/service/presentation/pages/service_form_page.dart';
import '../../features/service/presentation/pages/service_list_page.dart';
import '../../features/transaction/presentation/pages/transaction_detail_page.dart';
import '../../features/transaction/presentation/pages/transaction_history_page.dart';
import '../../features/transaction/presentation/pages/transaction_report_page.dart';

final router = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => const HomePage(),
      routes: [
        GoRoute(
          path: 'scanner',
          builder: (context, state) => const ScannerPage(),
        ),
        GoRoute(
          path: 'checkout',
          builder: (context, state) => const CheckoutPage(),
        ),
      ],
    ),
    GoRoute(
      path: '/settings',
      builder: (context, state) => const SettingsPage(),
    ),
    GoRoute(
      path: '/products',
      builder: (context, state) => const ProductListPage(),
      routes: [
        GoRoute(
          path: 'add',
          builder: (context, state) => const AddProductPage(),
        ),
        GoRoute(
          path: 'edit/:id',
          builder: (context, state) {
            final product = state.extra as Product?;
            if (product == null) {
              // If we land here without extra (e.g. deep link), go back to products for now.
              return const ProductListPage();
            }
            return EditProductPage(product: product);
          },
        ),
      ],
    ),
    GoRoute(
      path: '/services',
      builder: (context, state) => const ServiceListPage(),
      routes: [
        GoRoute(
          path: 'form',
          builder: (context, state) =>
              ServiceFormPage(service: state.extra as ServiceItem?),
        ),
        GoRoute(
          path: 'categories',
          builder: (context, state) => const ServiceCategoryPage(),
        ),
      ],
    ),
    GoRoute(
      path: '/shop',
      builder: (context, state) => const ShopDetailsPage(),
    ),
    GoRoute(
      path: '/transactions',
      builder: (context, state) => const TransactionHistoryPage(),
      routes: [
        GoRoute(
          path: ':id',
          builder: (context, state) => TransactionDetailPage(
            transactionId: state.pathParameters['id']!,
          ),
        ),
      ],
    ),
    GoRoute(
      path: '/reports',
      builder: (context, state) => const TransactionReportPage(),
    ),
  ],
);
