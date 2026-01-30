import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'dart:ui';
import 'dart:async';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'firebase_options.dart';
import 'models/merchant.dart';
import 'models/customer.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/role_blocked_screen.dart';
import 'screens/onboarding/onboarding_screen.dart';
import 'screens/billing/billing_screen.dart';
import 'screens/validate_redemption_screen.dart';
import 'services/auth_service.dart';
import 'services/fcm_service.dart';
import 'services/onboarding_service.dart';
import 'utils/role_validator.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  
  // Crashlytics integration
  FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;
  PlatformDispatcher.instance.onError = (error, stack) {
    FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
    return true;
  };
  
  // Set custom keys for observability
  await FirebaseCrashlytics.instance.setCustomKey('environment', kDebugMode ? 'dev' : 'prod');
  await FirebaseCrashlytics.instance.setCustomKey('appVersion', '1.0.0');
  await FirebaseCrashlytics.instance.setCustomKey('role', 'merchant');
  
  // Set up FCM background message handler
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  
  runApp(const UrbanPointsMerchantApp());
}

class UrbanPointsMerchantApp extends StatelessWidget {
  const UrbanPointsMerchantApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Urban Points - Merchant',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF0066CC),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
      ),
      routes: {
        '/billing': (context) => const BillingScreen(),
      },
      home: FutureBuilder<bool>(
        future: OnboardingService.shouldShowOnboarding(),
        builder: (context, onboardingSnapshot) {
          if (onboardingSnapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }

          if (onboardingSnapshot.data == true) {
            return const OnboardingScreen();
          }

          return StreamBuilder<User?>(
            stream: FirebaseAuth.instance.authStateChanges(),
            builder: (context, authSnapshot) {
              if (authSnapshot.connectionState == ConnectionState.waiting) {
                return const Scaffold(
                  body: Center(
                    child: CircularProgressIndicator(),
                  ),
                );
              }
              
              if (authSnapshot.hasData) {
                return AuthValidator(
                  user: authSnapshot.data!,
                  child: const MerchantHomePage(),
                );
              }
              
              return const LoginScreen();
            },
          );
        },
      ),
    );
  }
}

// Auth Validator Widget - Validates role before showing home screen
class AuthValidator extends StatefulWidget {
  final User user;
  final Widget child;

  const AuthValidator({
    super.key,
    required this.user,
    required this.child,
  });

  @override
  State<AuthValidator> createState() => _AuthValidatorState();
}

class _AuthValidatorState extends State<AuthValidator> {
  bool _isValidating = true;
  String? _errorMessage;
  RoleValidationResult? _result;
  final _authService = AuthService();
  late final _roleValidator = RoleValidator(_authService);

  @override
  void initState() {
    super.initState();
    _validateRole();
  }

  Future<void> _validateRole() async {
    try {
      // Validate role with timeout
      final result = await _roleValidator
          .validateForMerchantApp()
          .timeout(
            const Duration(seconds: 7),
            onTimeout: () => RoleValidationResult(
              isValid: false,
              reason: 'Validation timeout',
              shouldSignOut: true,
            ),
          );

      if (!mounted) return;

      setState(() {
        _isValidating = false;
        _result = result;
        _errorMessage = result.reason;
      });
    } catch (e) {
      if (!mounted) return;
      
      setState(() {
        _isValidating = false;
        _result = RoleValidationResult(
          isValid: false,
          reason: 'Failed to validate account: ${e.toString()}',
          shouldSignOut: true,
        );
        _errorMessage = 'Failed to validate account: ${e.toString()}';
      });
      
      if (kDebugMode) {
        debugPrint('Auth validation error: $e');
      }
    }
  }

  Future<void> _handleError() async {
    // Sign out user on validation failure
    await FirebaseAuth.instance.signOut();
  }

  @override
  Widget build(BuildContext context) {
    if (_isValidating) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Validating account...'),
            ],
          ),
        ),
      );
    }

    final result = _result;
    if (result == null || !result.isValid) {
      // Show role blocked screen if role is invalid
      if (_errorMessage?.contains('for merchants only') == true || 
          _errorMessage?.contains('Invalid role') == true) {
        return RoleBlockedScreen(
          reason: _errorMessage ?? 'Invalid role for merchant app',
        );
      }
      
      // For other errors, show error and sign out
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 64, color: Colors.red),
                const SizedBox(height: 16),
                const Text(
                  'Account Validation Failed',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  _errorMessage ?? 'Unknown error',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _handleError,
                  child: const Text('Sign Out'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return widget.child;
  }
}

class MerchantHomePage extends StatefulWidget {
  const MerchantHomePage({super.key});

  @override
  State<MerchantHomePage> createState() => _MerchantHomePageState();
}

class _MerchantHomePageState extends State<MerchantHomePage> {
  int _selectedIndex = 0;
  Merchant? _currentMerchant;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadMerchantData();
    _initializeFCM();
  }
  
  Future<void> _initializeFCM() async {
    final fcmService = FCMService();
    await fcmService.initialize();
    // Subscribe to all_merchants topic for broadcast notifications
    await fcmService.subscribeToTopic('all_merchants');
  }

  Future<void> _loadMerchantData() async {
    try {
      // ✅ FIX: Use current authenticated user's UID instead of limit(1)
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
        return;
      }

      final doc = await FirebaseFirestore.instance
          .collection('merchants')
          .doc(currentUser.uid)
          .get();

      if (doc.exists && mounted) {
        setState(() {
          _currentMerchant = Merchant.fromFirestore(
            doc.data()!,
            doc.id,
          );
          _isLoading = false;
        });
      } else if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> pages = [
      DashboardPage(merchant: _currentMerchant),
      const ValidateTransactionPage(),
      const CustomersPage(),
      MerchantProfilePage(merchant: _currentMerchant),
    ];

    return Scaffold(
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : pages[_selectedIndex],
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _currentMerchant != null
            ? () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ValidateRedemptionScreen(
                      merchantId: _currentMerchant!.id,
                    ),
                  ),
                );
              }
            : null, // Disable button if no merchant loaded
        icon: const Icon(Icons.qr_code_scanner),
        label: const Text('Validate'),
        backgroundColor: const Color(0xFF0066CC),
        foregroundColor: Colors.white,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
          NavigationDestination(
            icon: Icon(Icons.qr_code_scanner_outlined),
            selectedIcon: Icon(Icons.qr_code_scanner),
            label: 'Validate',
          ),
          NavigationDestination(
            icon: Icon(Icons.people_outline),
            selectedIcon: Icon(Icons.people),
            label: 'Customers',
          ),
          NavigationDestination(
            icon: Icon(Icons.store_outlined),
            selectedIcon: Icon(Icons.store),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}

class DashboardPage extends StatelessWidget {
  final Merchant? merchant;

  const DashboardPage({super.key, this.merchant});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Merchant Dashboard'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildMerchantCard(),
            const SizedBox(height: 24),
            _buildStatsGrid(),
            const SizedBox(height: 24),
            Text(
              'Recent Reservations',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            _buildRecentReservations(),
          ],
        ),
      ),
    );
  }

  Widget _buildMerchantCard() {
    if (merchant == null) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    return Card(
      elevation: 4,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: const LinearGradient(
            colors: [Color(0xFF0066CC), Color(0xFF0099FF)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(
                      merchant!.imageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return const Icon(Icons.store, size: 32);
                      },
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        merchant!.name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        merchant!.cuisine,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                const Icon(Icons.star, color: Colors.amber, size: 20),
                const SizedBox(width: 4),
                Text(
                  '${merchant!.rating}/5.0',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 16),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${merchant!.pointsRate}x Points Rate',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsGrid() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('reservations')
          .where('merchant_id', isEqualTo: merchant?.id ?? '')
          .snapshots(),
      builder: (context, snapshot) {
        final totalReservations = snapshot.hasData ? snapshot.data!.docs.length : 0;
        final pendingReservations = snapshot.hasData
            ? snapshot.data!.docs
                .where((doc) => (doc.data() as Map<String, dynamic>)['status'] == 'pending')
                .length
            : 0;

        return GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          children: [
            _buildStatCard(
              'Total Reservations',
              totalReservations.toString(),
              Icons.event,
              Colors.blue,
            ),
            _buildStatCard(
              'Pending',
              pendingReservations.toString(),
              Icons.pending,
              Colors.orange,
            ),
            _buildStatCard(
              'Rating',
              '${merchant?.rating ?? 0.0}',
              Icons.star,
              Colors.amber,
            ),
            _buildStatCard(
              'Points Rate',
              '${merchant?.pointsRate ?? 1}x',
              Icons.trending_up,
              Colors.green,
            ),
          ],
        );
      },
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 32, color: color),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                color: Colors.grey,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentReservations() {
    if (merchant == null) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Center(child: Text('No merchant data')),
        ),
      );
    }

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('reservations')
          .where('merchant_id', isEqualTo: merchant!.id)
          .limit(5)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Card(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            ),
          );
        }

        final reservations = snapshot.data!.docs;

        if (reservations.isEmpty) {
          return const Card(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: Text('No reservations yet')),
            ),
          );
        }

        return Column(
          children: reservations.map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: _getStatusColor(data['status']),
                  child: Icon(
                    _getStatusIcon(data['status']),
                    color: Colors.white,
                  ),
                ),
                title: Text('Party of ${data['party_size']}'),
                subtitle: Text(
                  data['reservation_date'] ?? 'No date',
                  style: const TextStyle(fontSize: 12),
                ),
                trailing: Chip(
                  label: Text(
                    data['status'] ?? 'pending',
                    style: const TextStyle(fontSize: 11),
                  ),
                  backgroundColor: _getStatusColor(data['status']).withValues(alpha: 0.1),
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }

  Color _getStatusColor(String? status) {
    switch (status) {
      case 'confirmed':
        return Colors.green;
      case 'cancelled':
        return Colors.red;
      case 'completed':
        return Colors.blue;
      default:
        return Colors.orange;
    }
  }

  IconData _getStatusIcon(String? status) {
    switch (status) {
      case 'confirmed':
        return Icons.check_circle;
      case 'cancelled':
        return Icons.cancel;
      case 'completed':
        return Icons.done_all;
      default:
        return Icons.pending;
    }
  }
}

class ValidateTransactionPage extends StatefulWidget {
  const ValidateTransactionPage({super.key});

  @override
  State<ValidateTransactionPage> createState() => _ValidateTransactionPageState();
}

class _ValidateTransactionPageState extends State<ValidateTransactionPage> {
  final _amountController = TextEditingController();
  Customer? _selectedCustomer;

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Validate Transaction'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    const Icon(
                      Icons.qr_code_scanner,
                      size: 64,
                      color: Color(0xFF0066CC),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Scan Customer QR Code',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Or manually select customer below',
                      style: TextStyle(color: Colors.grey),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      onPressed: () {
                        // QR Scanner would go here
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('QR Scanner not implemented in web demo'),
                          ),
                        );
                      },
                      icon: const Icon(Icons.qr_code_scanner),
                      label: const Text('Scan QR Code'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 32,
                          vertical: 16,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Manual Transaction',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 16),
                    _buildCustomerSelector(),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _amountController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Transaction Amount (LBP)',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.payments),
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (_selectedCustomer != null && _amountController.text.isNotEmpty)
                      _buildTransactionPreview(),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _selectedCustomer != null &&
                                _amountController.text.isNotEmpty
                            ? _processTransaction
                            : null,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: const Text('Process Transaction'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCustomerSelector() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('customers')
          .where('is_active', isEqualTo: true)
          .limit(10)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const CircularProgressIndicator();
        }

        final customers = snapshot.data!.docs
            .map((doc) => Customer.fromFirestore(
                  doc.data() as Map<String, dynamic>,
                  doc.id,
                ))
            .toList();

        return DropdownButtonFormField<Customer>(
          decoration: const InputDecoration(
            labelText: 'Select Customer',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.person),
          ),
          value: _selectedCustomer,
          items: customers.map((customer) {
            return DropdownMenuItem(
              value: customer,
              child: Text('${customer.name} (${customer.pointsBalance} pts)'),
            );
          }).toList(),
          onChanged: (customer) {
            setState(() {
              _selectedCustomer = customer;
            });
          },
        );
      },
    );
  }

  Widget _buildTransactionPreview() {
    final amount = int.tryParse(_amountController.text) ?? 0;
    final pointsToEarn = (amount * 0.01).round(); // 1% back as points

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.green.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.green),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Customer:'),
              Text(
                _selectedCustomer!.name,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const Divider(),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Current Balance:'),
              Text(
                '${_selectedCustomer!.pointsBalance} pts',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const Divider(),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Points to Earn:'),
              Text(
                '+$pointsToEarn pts',
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Colors.green,
                ),
              ),
            ],
          ),
          const Divider(),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('New Balance:'),
              Text(
                '${_selectedCustomer!.pointsBalance + pointsToEarn} pts',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.green,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _processTransaction() {
    // In a real app, this would update Firestore
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Transaction processed for ${_selectedCustomer!.name}',
        ),
        backgroundColor: Colors.green,
      ),
    );
    
    setState(() {
      _selectedCustomer = null;
      _amountController.clear();
    });
  }
}

class CustomersPage extends StatelessWidget {
  const CustomersPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Customers'),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('customers')
            .where('is_active', isEqualTo: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final customers = snapshot.data!.docs
              .map((doc) => Customer.fromFirestore(
                    doc.data() as Map<String, dynamic>,
                    doc.id,
                  ))
              .toList();

          if (customers.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.people_outlined, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text('No customers yet'),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: customers.length,
            itemBuilder: (context, index) {
              final customer = customers[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: const Color(0xFF0066CC),
                    child: Text(
                      customer.name.isNotEmpty
                          ? customer.name[0].toUpperCase()
                          : 'U',
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                  title: Text(
                    customer.name,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        customer.email,
                        style: const TextStyle(fontSize: 12),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${customer.tier} • LBP ${NumberFormat('#,###').format(customer.totalSpentLbp)}',
                        style: const TextStyle(fontSize: 11),
                      ),
                    ],
                  ),
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '${customer.pointsBalance}',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0066CC),
                        ),
                      ),
                      const Text(
                        'points',
                        style: TextStyle(fontSize: 10, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class MerchantProfilePage extends StatelessWidget {
  final Merchant? merchant;

  const MerchantProfilePage({super.key, this.merchant});

  @override
  Widget build(BuildContext context) {
    if (merchant == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Merchant Profile'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.network(
                merchant!.imageUrl,
                height: 200,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    height: 200,
                    color: Colors.grey[300],
                    child: const Icon(Icons.store, size: 64),
                  );
                },
              ),
            ),
            const SizedBox(height: 24),
            Text(
              merchant!.name,
              style: Theme.of(context).textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              merchant!.cuisine,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Colors.grey[600],
                  ),
            ),
            const SizedBox(height: 24),
            _buildInfoCard(
              context,
              'Business Information',
              [
                _buildInfoRow(Icons.location_on, 'Address', merchant!.address),
                _buildInfoRow(Icons.phone, 'Phone', merchant!.phone),
                _buildInfoRow(Icons.star, 'Rating', '${merchant!.rating}/5.0'),
                _buildInfoRow(
                  Icons.trending_up,
                  'Points Rate',
                  '${merchant!.pointsRate}x',
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildInfoCard(
              context,
              'Location',
              [
                _buildInfoRow(
                  Icons.map,
                  'Coordinates',
                  '${merchant!.latitude.toStringAsFixed(4)}, ${merchant!.longitude.toStringAsFixed(4)}',
                ),
                _buildInfoRow(
                  Icons.calendar_today,
                  'Member Since',
                  DateFormat('MMM dd, yyyy').format(merchant!.createdAt),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.subscriptions),
                label: const Text('Subscription & Billing'),
                onPressed: () {
                  Navigator.of(context).pushNamed('/billing');
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard(BuildContext context, String title, List<Widget> children) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, size: 20, color: const Color(0xFF0066CC)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                  ),
                ),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
