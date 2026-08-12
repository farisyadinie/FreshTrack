import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:http/browser_client.dart';

void main() {
  runApp(const FreshTrackApp());
}

// =====================================================
// APP
// =====================================================

class FreshTrackApp extends StatelessWidget {
  const FreshTrackApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FreshTrack',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFEDF4F0),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF16845F),
        ),
        fontFamily: 'Arial',
      ),
      home: const LoginPage(),
    );
  }
}

// =====================================================
// API SERVICE
// =====================================================

class ApiService {
  static const String baseUrl =
    'https://freshtrack-backend-haum.onrender.com';

  final BrowserClient client = BrowserClient()
    ..withCredentials = true;

  Map<String, dynamic> decode(http.Response response) {
    try {
      final data = jsonDecode(response.body);

      if (data is Map<String, dynamic>) {
        return data;
      }

      return {
        'error': 'Invalid server response',
      };
    } catch (_) {
      return {
        'error': 'Invalid server response',
      };
    }
  }

  // ---------------------------------------------------
  // LOGIN
  // ---------------------------------------------------

  Future<Map<String, dynamic>> login(
    String email,
    String password,
  ) async {
    final response = await client.post(
      Uri.parse('$baseUrl/api/login'),
      headers: {
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'email': email,
        'password': password,
      }),
    );

    final data = decode(response);

    if (response.statusCode != 200) {
      throw Exception(
        data['error'] ?? 'Login failed',
      );
    }

    return data;
  }

  // ---------------------------------------------------
  // REGISTER
  // ---------------------------------------------------

  Future<void> register({
    required String name,
    required String email,
    required String password,
  }) async {
    final response = await client.post(
      Uri.parse('$baseUrl/register'),
      headers: {
        'Content-Type':
            'application/x-www-form-urlencoded',
        'Accept': 'application/json',
      },
      body: {
        'name': name,
        'email': email,
        'password': password,
      },
    );

    if (response.statusCode != 200 &&
        response.statusCode != 201 &&
        response.statusCode != 302) {
      final data = decode(response);
      throw Exception(
        data['error'] ??
            'Unable to create your account. '
                'Please check the email or try again.',
      );
    }
  }

  // ---------------------------------------------------
  // DASHBOARD
  // ---------------------------------------------------

  Future<Map<String, dynamic>> getDashboard() async {
    final response = await client.get(
      Uri.parse('$baseUrl/api/dashboard'),
    );

    final data = decode(response);

    if (response.statusCode != 200) {
      throw Exception(
        data['error'] ?? 'Unable to load dashboard',
      );
    }

    return data;
  }

  // ---------------------------------------------------
  // GET FOODS
  // ---------------------------------------------------

  Future<List<dynamic>> getFoods() async {
    final response = await client.get(
      Uri.parse('$baseUrl/api/foods'),
    );

    final data = decode(response);

    if (response.statusCode != 200) {
      throw Exception(
        data['error'] ?? 'Unable to load foods',
      );
    }

    return data['foods'] ?? [];
  }

  // ---------------------------------------------------
  // ADD FOOD
  // ---------------------------------------------------

  Future<void> addFood({
    required String food,
    required String category,
    required double quantity,
    required String unit,
    required String expiry,
  }) async {
    final response = await client.post(
      Uri.parse('$baseUrl/api/foods'),
      headers: {
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'food': food,
        'category': category,
        'quantity': quantity,
        'unit': unit,
        'expiry': expiry,
      }),
    );

    final data = decode(response);

    if (response.statusCode != 201) {
      throw Exception(
        data['error'] ?? 'Unable to add food',
      );
    }
  }

  // ---------------------------------------------------
  // EDIT FOOD
  // ---------------------------------------------------

  Future<void> editFood({
    required int id,
    required String food,
    required String category,
    required double quantity,
    required String unit,
    required String expiry,
  }) async {
    final response = await client.put(
      Uri.parse('$baseUrl/api/foods/$id'),
      headers: {
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'food': food,
        'category': category,
        'quantity': quantity,
        'unit': unit,
        'expiry': expiry,
      }),
    );

    final data = decode(response);

    if (response.statusCode != 200) {
      throw Exception(
        data['error'] ?? 'Unable to edit food',
      );
    }
  }

  // ---------------------------------------------------
  // USED FOOD
  // ---------------------------------------------------

  Future<Map<String, dynamic>> useOneUnit(int id) async {
    final response = await client.post(
      Uri.parse('$baseUrl/api/foods/$id/use-one'),
    );

    final data = decode(response);

    if (response.statusCode != 200) {
      throw Exception(
        data['error'] ??
            'Unable to update food quantity',
      );
    }

    return data;
  }

  // ---------------------------------------------------
  // DELETE FOOD
  // ---------------------------------------------------

  Future<void> deleteFood(int id) async {
    final response = await client.delete(
      Uri.parse('$baseUrl/api/foods/$id'),
    );

    final data = decode(response);

    if (response.statusCode != 200) {
      throw Exception(
        data['error'] ?? 'Unable to delete food',
      );
    }
  }
}

// =====================================================
// LOGIN PAGE
// =====================================================

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();

  final ApiService api = ApiService();

  bool loading = false;
  String? error;

  Future<void> login() async {
    if (emailController.text.trim().isEmpty ||
        passwordController.text.isEmpty) {
      setState(() {
        error = 'Please enter your email and password.';
      });
      return;
    }

    setState(() {
      loading = true;
      error = null;
    });

    try {
      await api.login(
        emailController.text.trim(),
        passwordController.text,
      );

      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => const DashboardPage(),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      setState(() {
        error = e
            .toString()
            .replaceFirst('Exception: ', '');
      });
    } finally {
      if (mounted) {
        setState(() {
          loading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Container(
            width: 500,
            padding: const EdgeInsets.fromLTRB(
              40,
              45,
              40,
              40,
            ),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.07),
                  blurRadius: 25,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8F5EF),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Center(
                    child: Text(
                      '🥬',
                      style: TextStyle(fontSize: 46),
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                const Text(
                  'FreshTrack',
                  style: TextStyle(
                    fontSize: 34,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF16845F),
                  ),
                ),

                const SizedBox(height: 8),

                const Text(
                  'Track your pantry. Reduce food waste.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey,
                  ),
                ),

                const SizedBox(height: 35),

                TextField(
                  controller: emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                    labelText: 'Email',
                    hintText: 'Enter your email',
                    prefixIcon: const Icon(
                      Icons.email_outlined,
                    ),
                    border: OutlineInputBorder(
                      borderRadius:
                          BorderRadius.circular(12),
                    ),
                  ),
                ),

                const SizedBox(height: 18),

                TextField(
                  controller: passwordController,
                  obscureText: true,
                  onSubmitted: (_) => login(),
                  decoration: InputDecoration(
                    labelText: 'Password',
                    hintText: 'Enter your password',
                    prefixIcon: const Icon(
                      Icons.lock_outline,
                    ),
                    border: OutlineInputBorder(
                      borderRadius:
                          BorderRadius.circular(12),
                    ),
                  ),
                ),

                const SizedBox(height: 18),

                if (error != null)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(13),
                    margin: const EdgeInsets.only(
                      bottom: 18,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius:
                          BorderRadius.circular(10),
                    ),
                    child: Text(
                      error!,
                      style: TextStyle(
                        color: Colors.red.shade700,
                      ),
                    ),
                  ),

                SizedBox(
                  width: double.infinity,
                  height: 55,
                  child: ElevatedButton(
                    onPressed:
                        loading ? null : login,
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                          const Color(0xFF16845F),
                      foregroundColor: Colors.white,
                      shape:
                          RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(12),
                      ),
                    ),
                    child: loading
                        ? const SizedBox(
                            width: 23,
                            height: 23,
                            child:
                                CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2.5,
                            ),
                          )
                        : const Text(
                            'Login',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight:
                                  FontWeight.bold,
                            ),
                          ),
                  ),
                ),

                const SizedBox(height: 14),

                Row(
                  mainAxisAlignment:
                      MainAxisAlignment.center,
                  children: [
                    const Text(
                      "Don't have an account? ",
                      style: TextStyle(
                        color: Colors.grey,
                      ),
                    ),
                    TextButton(
                      onPressed: loading
                          ? null
                          : () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      const RegisterPage(),
                                ),
                              );
                            },
                      child: const Text(
                        'Register',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF16845F),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}


// =====================================================
// REGISTER PAGE
// =====================================================

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() =>
      _RegisterPageState();
}

class _RegisterPageState
    extends State<RegisterPage> {
  final nameController = TextEditingController();
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final confirmPasswordController =
      TextEditingController();

  final ApiService api = ApiService();

  bool loading = false;
  String? error;

  Future<void> register() async {
    final name = nameController.text.trim();
    final email = emailController.text.trim();
    final password = passwordController.text;
    final confirmPassword =
        confirmPasswordController.text;

    if (name.isEmpty ||
        email.isEmpty ||
        password.isEmpty ||
        confirmPassword.isEmpty) {
      setState(() {
        error = 'Please complete all fields.';
      });
      return;
    }

    if (!email.contains('@')) {
      setState(() {
        error = 'Please enter a valid email address.';
      });
      return;
    }

    if (password.length < 4) {
      setState(() {
        error = 'Password must be at least 4 characters.';
      });
      return;
    }

    if (password != confirmPassword) {
      setState(() {
        error = 'Passwords do not match.';
      });
      return;
    }

    setState(() {
      loading = true;
      error = null;
    });

    try {
      await api.register(
        name: name,
        email: email,
        password: password,
      );

      // Registering creates the account, but the API dashboard
      // also needs the new account to be the active API user.
      // Logging in immediately after registration makes sure
      // we do not keep using the previous account/session.
      await api.login(
        email,
        password,
      );

      if (!mounted) return;

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (_) => const DashboardPage(),
        ),
        (route) => false,
      );
    } catch (e) {
      if (!mounted) return;

      setState(() {
        error = e.toString().replaceFirst(
          'Exception: ',
          '',
        );
      });
    } finally {
      if (mounted) {
        setState(() {
          loading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    nameController.dispose();
    emailController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
    super.dispose();
  }

  InputDecoration fieldDecoration({
    required String label,
    required String hint,
    required IconData icon,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: Icon(icon),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Container(
            width: 500,
            padding: const EdgeInsets.fromLTRB(
              40,
              35,
              40,
              32,
            ),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(
                    alpha: 0.07,
                  ),
                  blurRadius: 25,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8F5EF),
                    borderRadius:
                        BorderRadius.circular(18),
                  ),
                  child: const Center(
                    child: Text(
                      '🥬',
                      style: TextStyle(fontSize: 42),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Create Account',
                  style: TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF16845F),
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Start tracking your pantry with FreshTrack.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 15,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 28),
                TextField(
                  controller: nameController,
                  textInputAction: TextInputAction.next,
                  decoration: fieldDecoration(
                    label: 'Name',
                    hint: 'Enter your name',
                    icon: Icons.person_outline,
                  ),
                ),
                const SizedBox(height: 15),
                TextField(
                  controller: emailController,
                  keyboardType:
                      TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  decoration: fieldDecoration(
                    label: 'Email',
                    hint: 'Enter your email',
                    icon: Icons.email_outlined,
                  ),
                ),
                const SizedBox(height: 15),
                TextField(
                  controller: passwordController,
                  obscureText: true,
                  textInputAction: TextInputAction.next,
                  decoration: fieldDecoration(
                    label: 'Password',
                    hint: 'Create a password',
                    icon: Icons.lock_outline,
                  ),
                ),
                const SizedBox(height: 15),
                TextField(
                  controller: confirmPasswordController,
                  obscureText: true,
                  onSubmitted: (_) => register(),
                  decoration: fieldDecoration(
                    label: 'Confirm Password',
                    hint: 'Re-enter your password',
                    icon: Icons.lock_reset_outlined,
                  ),
                ),
                if (error != null) ...[
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(13),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius:
                          BorderRadius.circular(10),
                    ),
                    child: Text(
                      error!,
                      style: TextStyle(
                        color: Colors.red.shade700,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  height: 53,
                  child: ElevatedButton(
                    onPressed:
                        loading ? null : register,
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                          const Color(0xFF16845F),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(12),
                      ),
                    ),
                    child: loading
                        ? const SizedBox(
                            width: 23,
                            height: 23,
                            child:
                                CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2.5,
                            ),
                          )
                        : const Text(
                            'Create Account',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 12),
                TextButton.icon(
                  onPressed: loading
                      ? null
                      : () => Navigator.pop(context),
                  icon: const Icon(
                    Icons.arrow_back,
                    size: 18,
                  ),
                  label: const Text('Back to Login'),
                  style: TextButton.styleFrom(
                    foregroundColor:
                        const Color(0xFF16845F),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}


// =====================================================
// ANIMATED FILTER CARD
// =====================================================

class AnimatedFilterCard extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;

  const AnimatedFilterCard({
    super.key,
    required this.child,
    required this.onTap,
  });

  @override
  State<AnimatedFilterCard> createState() =>
      _AnimatedFilterCardState();
}

class _AnimatedFilterCardState
    extends State<AnimatedFilterCard> {
  bool pressed = false;
  bool hovered = false;

  @override
  Widget build(BuildContext context) {
    final scale = pressed
        ? 0.97
        : hovered
            ? 1.015
            : 1.0;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) {
        setState(() {
          hovered = true;
        });
      },
      onExit: (_) {
        setState(() {
          hovered = false;
        });
      },
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        onTapDown: (_) {
          setState(() {
            pressed = true;
          });
        },
        onTapUp: (_) {
          setState(() {
            pressed = false;
          });
        },
        onTapCancel: () {
          setState(() {
            pressed = false;
          });
        },
        child: AnimatedScale(
          scale: scale,
          duration:
              const Duration(milliseconds: 130),
          curve: Curves.easeOut,
          child: widget.child,
        ),
      ),
    );
  }
}

// =====================================================
// DASHBOARD
// =====================================================

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() =>
      _DashboardPageState();
}

class _DashboardPageState
    extends State<DashboardPage> {
  bool notificationsEnabled = true;
  bool expiryAlertsEnabled = true;
  bool lowStockAlertsEnabled = true;

  int _notificationCount() {
    if (!notificationsEnabled || dashboard == null) {
      return 0;
    }

    final data = dashboard!;
    int count = 0;

    if (expiryAlertsEnabled) {
      count += ((data['expired'] ?? 0) as num).toInt();
      count += ((data['expiring_soon'] ?? 0) as num).toInt();
    }

    if (lowStockAlertsEnabled) {
      count += ((data['low_stock'] ?? 0) as num).toInt();
    }

    return count;
  }

  void _showNotifications() {
    final data = dashboard ?? {};
    final expired =
        ((data['expired'] ?? 0) as num).toInt();
    final expiring =
        ((data['expiring_soon'] ?? 0) as num).toInt();
    final lowStock =
        ((data['low_stock'] ?? 0) as num).toInt();

    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius:
                BorderRadius.circular(18),
          ),
          title: const Row(
            children: [
              Icon(
                Icons.notifications_none_rounded,
                color: Color(0xFF16845F),
              ),
              SizedBox(width: 10),
              Text('Notifications'),
            ],
          ),
          content: SizedBox(
            width: 360,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                if (!notificationsEnabled)
                  const Padding(
                    padding:
                        EdgeInsets.only(bottom: 12),
                    child: Text(
                      'Notifications are turned off in Settings.',
                      style: TextStyle(
                        color: Colors.grey,
                      ),
                    ),
                  ),
                if (notificationsEnabled &&
                    expiryAlertsEnabled &&
                    expired > 0)
                  _notificationTile(
                    Icons.error_outline_rounded,
                    'Food expired',
                    '$expired food item(s) need your attention.',
                    'expired',
                    dialogContext,
                  ),
                if (notificationsEnabled &&
                    expiryAlertsEnabled &&
                    expiring > 0)
                  _notificationTile(
                    Icons.schedule_rounded,
                    'Expiring soon',
                    '$expiring food item(s) are nearing their expiry date.',
                    'expiring',
                    dialogContext,
                  ),
                if (notificationsEnabled &&
                    lowStockAlertsEnabled &&
                    lowStock > 0)
                  _notificationTile(
                    Icons.inventory_2_outlined,
                    'Low stock',
                    '$lowStock food item(s) have low quantity.',
                    'low-stock',
                    dialogContext,
                  ),
                if (_notificationCount() == 0)
                  const Padding(
                    padding: EdgeInsets.symmetric(
                      vertical: 18,
                    ),
                    child: Center(
                      child: Column(
                        children: [
                          Text(
                            '🎉',
                            style: TextStyle(
                              fontSize: 32,
                            ),
                          ),
                          SizedBox(height: 8),
                          Text(
                            'You’re all caught up!',
                            style: TextStyle(
                              fontWeight:
                                  FontWeight.w600,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'No pantry alerts right now.',
                            style: TextStyle(
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () =>
                  Navigator.of(dialogContext).pop(),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  Widget _notificationTile(
    IconData icon,
    String title,
    String message,
    String filter,
    BuildContext dialogContext,
  ) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () {
          Navigator.of(dialogContext).pop();
          setFilter(filter);
        },
        child: Container(
          margin:
              const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFF3F8F5),
            borderRadius:
                BorderRadius.circular(12),
          ),
          child: Row(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              Icon(
                icon,
                color:
                    const Color(0xFF16845F),
                size: 22,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            style:
                                const TextStyle(
                              fontWeight:
                                  FontWeight.w600,
                            ),
                          ),
                        ),
                        const Icon(
                          Icons.arrow_forward_ios,
                          size: 11,
                          color: Colors.grey,
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      message,
                      style:
                          const TextStyle(
                        fontSize: 12,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'View foods',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight:
                            FontWeight.w600,
                        color:
                            Color(0xFF16845F),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showSettings() {
    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (
            dialogContext,
            setDialogState,
          ) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius:
                    BorderRadius.circular(18),
              ),
              title: const Row(
                children: [
                  Icon(
                    Icons.settings_outlined,
                    color: Color(0xFF16845F),
                  ),
                  SizedBox(width: 10),
                  Text('Settings'),
                ],
              ),
              content: SizedBox(
                width: 380,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SwitchListTile(
                      contentPadding:
                          EdgeInsets.zero,
                      title: const Text(
                        'Notifications',
                      ),
                      subtitle: const Text(
                        'Show pantry alerts',
                      ),
                      value: notificationsEnabled,
                      activeColor:
                          const Color(0xFF16845F),
                      onChanged: (value) {
                        setDialogState(() {
                          notificationsEnabled =
                              value;
                        });
                        setState(() {});
                      },
                    ),
                    const Divider(height: 1),
                    SwitchListTile(
                      contentPadding:
                          EdgeInsets.zero,
                      title: const Text(
                        'Expiry alerts',
                      ),
                      subtitle: const Text(
                        'Expired and expiring-soon food',
                      ),
                      value: expiryAlertsEnabled,
                      activeColor:
                          const Color(0xFF16845F),
                      onChanged:
                          notificationsEnabled
                              ? (value) {
                                  setDialogState(() {
                                    expiryAlertsEnabled =
                                        value;
                                  });
                                  setState(() {});
                                }
                              : null,
                    ),
                    const Divider(height: 1),
                    SwitchListTile(
                      contentPadding:
                          EdgeInsets.zero,
                      title: const Text(
                        'Low stock alerts',
                      ),
                      subtitle: const Text(
                        'Food with low quantity',
                      ),
                      value: lowStockAlertsEnabled,
                      activeColor:
                          const Color(0xFF16845F),
                      onChanged:
                          notificationsEnabled
                              ? (value) {
                                  setDialogState(() {
                                    lowStockAlertsEnabled =
                                        value;
                                  });
                                  setState(() {});
                                }
                              : null,
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () =>
                      Navigator.of(
                        dialogContext,
                      ).pop(),
                  child: const Text('Done'),
                ),
              ],
            );
          },
        );
      },
    );
  }


  final ApiService api = ApiService();

  Map<String, dynamic>? dashboard;
  List<dynamic> foods = [];

  bool loading = true;
  String? error;

  // Active dashboard filter:
  // all, expired, expiring, low-stock
  String activeFilter = 'all';

  @override
  void initState() {
    super.initState();
    loadDashboard();
  }

  // ---------------------------------------------------
  // LOAD DATA
  // ---------------------------------------------------

  Future<void> loadDashboard() async {
    setState(() {
      loading = true;
      error = null;
    });

    try {
      final dashboardData =
          await api.getDashboard();

      final foodData =
          await api.getFoods();

      if (!mounted) return;

      setState(() {
        dashboard = dashboardData;
        foods = foodData;
        loading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        error = e
            .toString()
            .replaceFirst('Exception: ', '');
        loading = false;
      });
    }
  }

  // ---------------------------------------------------
  // DASHBOARD FILTER
  // ---------------------------------------------------

  List<Map<String, dynamic>> get filteredFoods {
    final activeFoods = foods
        .map(
          (food) => Map<String, dynamic>.from(food),
        )
        .toList();

    if (activeFilter == 'all') {
      return activeFoods;
    }

    final today = DateTime.now();
    final todayOnly = DateTime(
      today.year,
      today.month,
      today.day,
    );

    return activeFoods.where((food) {
      final expiryText =
          food['expiry']?.toString() ?? '';

      final expiryDate = DateTime.tryParse(
        expiryText,
      );

      if (expiryDate == null) {
        return false;
      }

      final expiryOnly = DateTime(
        expiryDate.year,
        expiryDate.month,
        expiryDate.day,
      );

      final daysUntil =
          expiryOnly.difference(todayOnly).inDays;

      final quantity =
          double.tryParse(
                food['quantity'].toString(),
              ) ??
              0;

      switch (activeFilter) {
        case 'expired':
          return daysUntil < 0;

        case 'expiring':
          return daysUntil >= 0 &&
              daysUntil <= 3;

        case 'low-stock':
          return quantity <= 2 &&
              daysUntil > 3;

        default:
          return true;
      }
    }).toList();
  }

  String filterTitle() {
    switch (activeFilter) {
      case 'expired':
        return 'Expired Foods';
      case 'expiring':
        return 'Expiring Soon';
      case 'low-stock':
        return 'Low Stock';
      default:
        return 'Your Pantry';
    }
  }

  Widget buildEmptyPantryState() {
    final bool hasFilter = activeFilter != 'all';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(35),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        children: [
          const Text(
            '🌱',
            style: TextStyle(fontSize: 45),
          ),
          const SizedBox(height: 10),
          Text(
            hasFilter
                ? 'No ${filterTitle().toLowerCase()} found.'
                : 'Your pantry is empty.',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w500,
            ),
          ),
          if (hasFilter) ...[
            const SizedBox(height: 8),
            const Text(
              'Try another filter or view all foods.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey,
              ),
            ),
          ],
        ],
      ),
    );
  }

  void setFilter(String filter) {
    setState(() {
      activeFilter = filter;
    });
  }

  // ---------------------------------------------------
  // FOOD ICON
  // ---------------------------------------------------

  String unitDisplay(String unit) {
    switch (unit.toLowerCase()) {
      case 'pcs':
        return 'pieces';
      case 'pc':
        return 'piece';
      case 'kg':
        return 'kilograms';
      case 'g':
        return 'grams';
      case 'l':
        return 'litres';
      case 'ml':
        return 'millilitres';
      case 'pack':
        return 'packs';
      case 'bottle':
        return 'bottles';
      case 'box':
        return 'boxes';
      default:
        return unit;
    }
  }

  String foodIcon(String category) {
    switch (category.toLowerCase()) {
      case 'dairy':
        return '🥛';
      case 'fruits':
        return '🍎';
      case 'vegetables':
        return '🥦';
      case 'grains':
        return '🌾';
      case 'meat':
        return '🥩';
      case 'seafood':
        return '🐟';
      case 'frozen':
        return '🧊';
      case 'snacks':
        return '🍪';
      case 'beverages':
        return '🥤';
      case 'bakery':
        return '🥐';
      case 'condiments':
        return '🫙';
      default:
        return '📦';
    }
  }

  // ---------------------------------------------------
  // UNIT DISPLAY
  // ---------------------------------------------------

  // ---------------------------------------------------
  // STATUS
  // ---------------------------------------------------

  String foodStatus(Map<String, dynamic> food) {
    final expiry =
        food['expiry']?.toString() ?? '';

    try {
      final expiryDate =
          DateTime.parse(expiry);

      final today = DateTime.now();

      final difference = DateTime(
        expiryDate.year,
        expiryDate.month,
        expiryDate.day,
      ).difference(
        DateTime(
          today.year,
          today.month,
          today.day,
        ),
      ).inDays;

      if (difference < 0) {
        return 'Expired';
      }

      if (difference <= 3) {
        return 'Expiring Soon';
      }

      final quantity =
          double.tryParse(
                food['quantity'].toString(),
              ) ??
              0;

      if (quantity <= 2) {
        return 'Low Stock';
      }

      return 'Good';
    } catch (_) {
      return 'Good';
    }
  }

  // ---------------------------------------------------
  // STATUS COLOR
  // ---------------------------------------------------

  Color statusColor(String status) {
    switch (status) {
      case 'Expired':
        return Colors.red;
      case 'Expiring Soon':
        return Colors.orange;
      case 'Low Stock':
        return Colors.amber.shade800;
      default:
        return const Color(0xFF16845F);
    }
  }

  // ---------------------------------------------------
  // OVERVIEW CARD
  // ---------------------------------------------------

  Widget overviewCard({
    required String title,
    required dynamic value,
    required String icon,
    String? subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 13,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: const Color(0xFFE8F5EF),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(
                icon,
                style: const TextStyle(
                  fontSize: 23,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.grey,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '$value',
                  style: const TextStyle(
                    fontSize: 25,
                    height: 1.05,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF16845F),
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11,
                      height: 1.1,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------
  // FOOD CARD
  // ---------------------------------------------------

  Widget foodCard(
    Map<String, dynamic> food,
  ) {
    final category =
        food['category']?.toString() ?? '';

    final name =
        food['food']?.toString() ?? '';

    final quantity =
        food['quantity']?.toString() ?? '0';

    final unit =
        food['unit']?.toString() ?? '';

    final expiry =
        food['expiry']?.toString() ?? '';

    final status =
        foodStatus(food);

    final statusColorValue =
        statusColor(status);

    final id =
        int.tryParse(
      food['id'].toString(),
    );

    return Container(
      margin: const EdgeInsets.only(bottom: 9),
      padding: const EdgeInsets.fromLTRB(
        12,
        10,
        10,
        10,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(17),
        border: Border.all(
          color: Colors.black.withValues(alpha: 0.035),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.025),
            blurRadius: 9,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: const Color(0xFFE8F5EF),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(
                foodIcon(category),
                style: const TextStyle(fontSize: 25),
              ),
            ),
          ),

          const SizedBox(width: 10),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 3),

                Text(
                  '$category • $quantity ${unitDisplay(unit)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                  ),
                ),

                const SizedBox(height: 4),

                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: statusColorValue.withValues(
                      alpha: 0.10,
                    ),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    status,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: statusColorValue,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(width: 8),

          SizedBox(
            width: 112,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                const Text(
                  'Expires',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey,
                  ),
                ),

                const SizedBox(height: 3),

                Text(
                  expiry,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: statusColorValue,
                  ),
                ),

                const SizedBox(height: 5),

                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    IconButton(
                      tooltip: 'Edit',
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                        minWidth: 29,
                        minHeight: 29,
                      ),
                      onPressed: id == null
                          ? null
                          : () async {
                              await showDialog(
                                context: context,
                                builder: (_) => FoodDialog(
                                  api: api,
                                  existingFood: food,
                                ),
                              );

                              loadDashboard();
                            },
                      icon: const Icon(
                        Icons.edit_outlined,
                        size: 18,
                      ),
                    ),

                    IconButton(
                      tooltip: 'Use 1 unit',
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                        minWidth: 32,
                        minHeight: 32,
                      ),
                      onPressed: id == null
                          ? null
                          : () async {
                              await useOneFoodUnit(food);
                            },
                      icon: const Icon(
                        Icons.check_circle_outline,
                        size: 18,
                      ),
                    ),

                    IconButton(
                      tooltip: 'Delete',
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                        minWidth: 32,
                        minHeight: 32,
                      ),
                      onPressed: id == null
                          ? null
                          : () async {
                              await removeFood(id);
                            },
                      icon: const Icon(
                        Icons.delete_outline,
                        size: 20,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------
  // MARK USED
  // ---------------------------------------------------

  Future<void> useOneFoodUnit(
      Map<String, dynamic> food) async {
    final id = food['id'] as int;
    final quantity =
        (food['quantity'] as num?)?.toDouble() ?? 0;

    if (quantity <= 0) return;

    try {
      final result =
          await api.useOneUnit(id);

      if (!mounted) return;

      await loadDashboard();

      final remaining =
          (result['quantity'] as num?)?.toDouble() ??
              (quantity - 1);

      final displayRemaining =
          remaining % 1 == 0
              ? remaining.toInt().toString()
              : remaining.toString();

      ScaffoldMessenger.of(context)
          .showSnackBar(
        SnackBar(
          content: Text(
            remaining <= 0
                ? '${food['food']} is now used up.'
                : 'Used 1 ${unitDisplay(food['unit'] ?? '')}. '
                    '$displayRemaining remaining.',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(
        SnackBar(
          content: Text(
            e.toString().replaceFirst(
              'Exception: ',
              '',
            ),
          ),
        ),
      );
    }
  }

  // ---------------------------------------------------
  // DELETE
  // ---------------------------------------------------

  Future<void> removeFood(int id) async {
    final confirm =
        await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title:
              const Text('Delete food?'),
          content: const Text(
            'This food will be permanently removed from your pantry.',
          ),
          actions: [
            TextButton(
              onPressed: () =>
                  Navigator.pop(
                context,
                false,
              ),
              child:
                  const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () =>
                  Navigator.pop(
                context,
                true,
              ),
              style:
                  ElevatedButton.styleFrom(
                backgroundColor:
                    Colors.red,
                foregroundColor:
                    Colors.white,
              ),
              child:
                  const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirm != true) return;

    try {
      await api.deleteFood(id);

      if (!mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(
        const SnackBar(
          content:
              Text('Food deleted.'),
        ),
      );

      await loadDashboard();
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(
        SnackBar(
          content: Text(
            e
                .toString()
                .replaceFirst(
                  'Exception: ',
                  '',
                ),
          ),
        ),
      );
    }
  }

  // ---------------------------------------------------
  // OPEN ADD FOOD
  // ---------------------------------------------------

  Future<void> addFood() async {
    await showDialog(
      context: context,
      builder: (_) => FoodDialog(
        api: api,
      ),
    );

    await loadDashboard();
  }

  // ---------------------------------------------------
  // PANTRY FILTER HEADER
  // ---------------------------------------------------

  Widget pantryFilterHeader() {
    final hasFilter = activeFilter != 'all';

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F5EF),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.inventory_2_outlined,
                  size: 21,
                  color: Color(0xFF16845F),
                ),
              ),
              const SizedBox(width: 11),
              Flexible(
                child: Text(
                  filterTitle(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
        if (hasFilter)
          TextButton.icon(
            onPressed: () => setFilter('all'),
            icon: const Icon(
              Icons.close,
              size: 17,
            ),
            label: const Text(
              'Back',
            ),
            style: TextButton.styleFrom(
              foregroundColor:
                  const Color(0xFF16845F),
              padding: const EdgeInsets.symmetric(
                horizontal: 8,
              ),
            ),
          )
        else
          ElevatedButton.icon(
            onPressed: addFood,
            icon: const Icon(
              Icons.add,
              size: 19,
            ),
            label: const Text(
              'Add Food',
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor:
                  const Color(0xFF16845F),
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(
                horizontal: 17,
                vertical: 13,
              ),
              shape: RoundedRectangleBorder(
                borderRadius:
                    BorderRadius.circular(12),
              ),
            ),
          ),
      ],
    );
  }

  // ---------------------------------------------------
  // DRAWER
  // ---------------------------------------------------

  Widget buildDrawer() {
    return Drawer(
      child: SafeArea(
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding:
                  const EdgeInsets.all(25),
              decoration:
                  const BoxDecoration(
                color:
                    Color(0xFFE8F5EF),
              ),
              child: const Row(
                children: [
                  Text(
                    '🥬',
                    style:
                        TextStyle(
                      fontSize: 35,
                    ),
                  ),

                  SizedBox(width: 12),

                  Text(
                    'FreshTrack',
                    style:
                        TextStyle(
                      fontSize: 23,
                      fontWeight:
                          FontWeight.bold,
                      color:
                          Color(0xFF16845F),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 10),

            ListTile(
              leading:
                  const Icon(
                Icons.dashboard_outlined,
              ),
              title:
                  const Text('Dashboard'),
              selected: true,
              selectedColor:
                  const Color(0xFF16845F),
              onTap: () {
                Navigator.pop(context);
              },
            ),

            ListTile(
              leading:
                  const Icon(
                Icons.inventory_2_outlined,
              ),
              title:
                  const Text('My Pantry'),
              onTap: () {
                Navigator.pop(context);

                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        PantryPage(
                      api: api,
                    ),
                  ),
                ).then((_) {
                  loadDashboard();
                });
              },
            ),

            ListTile(
              leading:
                  const Icon(
                Icons.add_circle_outline,
              ),
              title:
                  const Text('Add Food'),
              onTap: () async {
                Navigator.pop(context);
                await addFood();
              },
            ),

            const Spacer(),

            const Divider(),

            ListTile(
              leading:
                  const Icon(
                Icons.logout,
              ),
              title:
                  const Text('Logout'),
              onTap: () {
                Navigator.pop(context);

                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        const LoginPage(),
                  ),
                  (route) => false,
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------
  // ERROR SCREEN
  // ---------------------------------------------------

  Widget buildError() {
    return Scaffold(
      body: Center(
        child: Container(
          width: 500,
          margin:
              const EdgeInsets.all(24),
          padding:
              const EdgeInsets.all(35),
          decoration:
              BoxDecoration(
            color: Colors.white,
            borderRadius:
                BorderRadius.circular(20),
          ),
          child: Column(
            mainAxisSize:
                MainAxisSize.min,
            children: [
              const Text(
                '⚠️',
                style:
                    TextStyle(
                  fontSize: 50,
                ),
              ),

              const SizedBox(height: 15),

              const Text(
                'Unable to load FreshTrack',
                textAlign:
                    TextAlign.center,
                style:
                    TextStyle(
                  fontSize: 24,
                  fontWeight:
                      FontWeight.bold,
                ),
              ),

              const SizedBox(height: 15),

              Text(
                error ??
                    'Unknown error',
                textAlign:
                    TextAlign.center,
                style:
                    const TextStyle(
                  color: Colors.grey,
                ),
              ),

              const SizedBox(height: 22),

              ElevatedButton.icon(
                onPressed:
                    loadDashboard,
                icon:
                    const Icon(
                  Icons.refresh,
                ),
                label:
                    const Text(
                  'Try Again',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------
  // FRESH TRACK IMPACT CARD
  // ---------------------------------------------------

  Widget impactCard({
    required dynamic wasteAvoidance,
    required dynamic usedFoods,
  }) {
    final impactText =
        wasteAvoidance == null
            ? '0%'
            : '$wasteAvoidance%';

    void showImpactDetails() {
      showDialog<void>(
        context: context,
        builder: (dialogContext) {
          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius:
                  BorderRadius.circular(18),
            ),
            title: const Row(
              children: [
                Text(
                  '🌱',
                  style: TextStyle(
                    fontSize: 25,
                  ),
                ),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'FreshTrack Impact',
                  ),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  impactText,
                  style: const TextStyle(
                    fontSize: 30,
                    fontWeight:
                        FontWeight.bold,
                    color:
                        Color(0xFF16845F),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '$usedFoods used before expiry',
                ),
                const SizedBox(height: 16),
                const Text(
                  'You’re making a difference! 🌱',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight:
                        FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Every food used before expiry helps reduce unnecessary waste.',
                ),
                const SizedBox(height: 14),
                Text(
                  'Used before expiry: $usedFoods',
                ),
                Text(
                  'Expired: ${dashboard?['expired'] ?? 0}',
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () =>
                    Navigator.of(
                      dialogContext,
                    ).pop(),
                child:
                    const Text('Close'),
              ),
            ],
          );
        },
      );
    }

    return AnimatedFilterCard(
      onTap: showImpactDetails,
      child: Container(
        width: 315,
        padding: const EdgeInsets.symmetric(
          horizontal: 19,
          vertical: 15,
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius:
              BorderRadius.circular(17),
          boxShadow: [
            BoxShadow(
              color:
                  Colors.black.withValues(
                alpha: 0.04,
              ),
              blurRadius: 11,
              offset:
                  const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color:
                    const Color(0xFFE8F5EF),
                borderRadius:
                    BorderRadius.circular(12),
              ),
              child: const Center(
                child: Text(
                  '🌱',
                  style: TextStyle(
                    fontSize: 24,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'FreshTrack Impact',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight:
                                FontWeight.w600,
                          ),
                        ),
                      ),
                      const Icon(
                        Icons.arrow_forward_ios,
                        size: 12,
                        color: Colors.grey,
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Row(
                    crossAxisAlignment:
                        CrossAxisAlignment
                            .baseline,
                    textBaseline:
                        TextBaseline.alphabetic,
                    children: [
                      Text(
                        impactText,
                        style: const TextStyle(
                          fontSize: 27,
                          fontWeight:
                              FontWeight.bold,
                          color:
                              Color(0xFF16845F),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '$usedFoods used before expiry',
                          maxLines: 1,
                          overflow:
                              TextOverflow.ellipsis,
                          style:
                              const TextStyle(
                            fontSize: 11,
                            color:
                                Colors.grey,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    'View impact details',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight:
                          FontWeight.w500,
                      color:
                          Color(0xFF16845F),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------
  // BUILD
  // ---------------------------------------------------

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Scaffold(
        body: Center(
          child:
              CircularProgressIndicator(
            color:
                Color(0xFF16845F),
          ),
        ),
      );
    }

    if (error != null) {
      return buildError();
    }

    final name =
        dashboard?['name'] ?? '';

    final totalFoods =
        dashboard?['total_foods'] ?? 0;

    final expiringSoon =
        dashboard?['expiring_soon'] ?? 0;

    final expired =
        dashboard?['expired'] ?? 0;

    final lowStock =
        dashboard?['low_stock'] ?? 0;

    final usedFoods =
        dashboard?['used_foods'] ?? 0;

    final wasteAvoidance =
        dashboard?['waste_avoidance'];

    return Scaffold(
      drawer: buildDrawer(),

      // =================================================
      // HEADER
      // =================================================

      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        toolbarHeight: 70,

        leading: Builder(
          builder: (context) {
            return IconButton(
              icon: const Icon(
                Icons.menu,
                size: 28,
              ),
              onPressed: () {
                Scaffold.of(context)
                    .openDrawer();
              },
            );
          },
        ),

        titleSpacing: 0,

        title: const Row(
          children: [
            Text(
              '🥬',
              style:
                  TextStyle(
                fontSize: 30,
              ),
            ),

            SizedBox(width: 10),

            Text(
              'FreshTrack',
              style:
                  TextStyle(
                fontSize: 23,
                fontWeight:
                    FontWeight.bold,
                color:
                    Color(0xFF16845F),
              ),
            ),
          ],
        ),

        actions: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  IconButton(
                    tooltip: 'Notifications',
                    onPressed: _showNotifications,
                    icon: const Icon(
                      Icons.notifications_none_rounded,
                    ),
                  ),
                  if (_notificationCount() > 0)
                    Positioned(
                      right: 5,
                      top: 3,
                      child: Container(
                        padding:
                            const EdgeInsets.symmetric(
                          horizontal: 5,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color:
                              const Color(0xFFD9534F),
                          borderRadius:
                              BorderRadius.circular(10),
                        ),
                        child: Text(
                          _notificationCount().toString(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight:
                                FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              IconButton(
                tooltip: 'Settings',
                onPressed: _showSettings,
                icon: const Icon(
                  Icons.settings_outlined,
                ),
              ),

          IconButton(
            tooltip: 'Refresh',
            onPressed:
                loadDashboard,
            icon:
                const Icon(
              Icons.refresh,
              size: 25,
            ),
          ),

          const SizedBox(width: 10),
        ],
      ),

      // =================================================
      // BODY
      // =================================================

      body: RefreshIndicator(
        color:
            const Color(0xFF16845F),
        onRefresh:
            loadDashboard,
        child: LayoutBuilder(
          builder: (
            context,
            constraints,
          ) {
            int columns = 1;

            if (constraints.maxWidth >=
                1100) {
              columns = 4;
            } else if (constraints.maxWidth >=
                650) {
              columns = 2;
            }

            return SingleChildScrollView(
              physics:
                  const AlwaysScrollableScrollPhysics(),
              padding:
                  EdgeInsets.symmetric(
                horizontal:
                    constraints.maxWidth >
                            1000
                        ? 28
                        : 20,
                vertical: 30,
              ),
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  // GREETING + FRESH TRACK IMPACT

                  if (constraints.maxWidth >= 850)
                    Row(
                      crossAxisAlignment:
                          CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Hi, $name! 👋',
                                style: TextStyle(
                                  fontSize:
                                      constraints.maxWidth > 1100
                                          ? 34
                                          : 30,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                "Here's what's happening in your pantry.",
                                style: TextStyle(
                                  fontSize: 17,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 20),
                        impactCard(
                          wasteAvoidance: wasteAvoidance,
                          usedFoods: usedFoods,
                        ),
                      ],
                    )
                  else
                    Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Hi, $name! 👋',
                          style: const TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          "Here's what's happening in your pantry.",
                          style: TextStyle(
                            fontSize: 17,
                            color: Colors.grey,
                          ),
                        ),
                        const SizedBox(height: 16),
                        impactCard(
                          wasteAvoidance: wasteAvoidance,
                          usedFoods: usedFoods,
                        ),
                      ],
                    ),

                  const SizedBox(height: 24),

                  // =================================================
                  // CARDS
                  // =================================================

                  GridView.count(
                    crossAxisCount:
                        columns,
                    shrinkWrap: true,
                    physics:
                        const NeverScrollableScrollPhysics(),
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,

                    // KEEP THE WORKING RATIO
                    childAspectRatio:
                        columns == 1
                            ? 3.7
                            : 2.85,

                    children: [
                      AnimatedFilterCard(
                        onTap: () => setFilter('all'),
                        child: overviewCard(
                          title:
                              'Total Foods',
                          value:
                              totalFoods,
                          icon:
                              '🧺',
                          subtitle:
                              'Items in your pantry',
                        ),
                      ),

                      AnimatedFilterCard(
                        onTap: () => setFilter('expiring'),
                        child: overviewCard(
                          title:
                              'Expiring Soon',
                          value:
                              expiringSoon,
                          icon:
                              '⏰',
                          subtitle:
                              'Within 3 days',
                        ),
                      ),

                      AnimatedFilterCard(
                        onTap: () => setFilter('expired'),
                        child: overviewCard(
                          title:
                              'Expired',
                          value:
                              expired,
                          icon:
                              '⚠️',
                          subtitle:
                              'Needs attention',
                        ),
                      ),

                      AnimatedFilterCard(
                        onTap: () => setFilter('low-stock'),
                        child: overviewCard(
                          title:
                              'Low Stock',
                          value:
                              lowStock,
                          icon:
                              '📦',
                          subtitle:
                              'Restock soon',
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 14),

                  Center(
                    child: Container(
                      padding:
                          const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color:
                            const Color(0xFFE8F5EF),
                        borderRadius:
                            BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize:
                            MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.touch_app_outlined,
                            size: 17,
                            color:
                                Color(0xFF16845F),
                          ),
                          const SizedBox(width: 7),
                          Text(
                            activeFilter == 'all'
                                ? 'Tap a card to filter your pantry'
                                : 'Filter applied to your pantry',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight:
                                  FontWeight.w600,
                              color:
                                  Color(0xFF16845F),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // =================================================
                  // PANTRY OVERVIEW
                  // =================================================

                  const Text(
                    'Pantry Overview',
                    style: TextStyle(
                      fontSize: 25,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 18),

                  // =================================================
                  // PANTRY
                  // =================================================

                  pantryFilterHeader(),

                  const SizedBox(height: 18),

                  if (filteredFoods.isEmpty)
                    buildEmptyPantryState()
                  else
                    ...filteredFoods.map(
                      (food) => foodCard(food),
                    ),

                  const SizedBox(height: 30),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

// =====================================================
// PANTRY PAGE
// =====================================================

class PantryPage extends StatefulWidget {
  final ApiService api;

  const PantryPage({
    super.key,
    required this.api,
  });

  @override
  State<PantryPage> createState() =>
      _PantryPageState();
}

class _PantryPageState
    extends State<PantryPage> {
  List<dynamic> foods = [];

  bool loading = true;
  String? error;

  final TextEditingController searchController =
      TextEditingController();

  String searchQuery = '';

  List<Map<String, dynamic>> get searchedFoods {
    final query = searchQuery.trim().toLowerCase();

    final list = foods
        .map(
          (food) => Map<String, dynamic>.from(food),
        )
        .toList();

    if (query.isEmpty) {
      return list;
    }

    return list.where((food) {
      final name =
          food['food']?.toString().toLowerCase() ?? '';
      final category =
          food['category']?.toString().toLowerCase() ?? '';
      final unit =
          food['unit']?.toString().toLowerCase() ?? '';

      return name.contains(query) ||
          category.contains(query) ||
          unit.contains(query);
    }).toList();
  }

  @override
  void initState() {
    super.initState();
    loadFoods();
  }

  Future<void> loadFoods() async {
    setState(() {
      loading = true;
      error = null;
    });

    try {
      final result =
          await widget.api.getFoods();

      if (!mounted) return;

      setState(() {
        foods = result;
        loading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        error = e
            .toString()
            .replaceFirst(
              'Exception: ',
              '',
            );
        loading = false;
      });
    }
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  String unitDisplay(String unit) {
    switch (unit.toLowerCase()) {
      case 'pcs':
        return 'pieces';
      case 'pc':
        return 'piece';
      case 'kg':
        return 'kilograms';
      case 'g':
        return 'grams';
      case 'l':
        return 'litres';
      case 'ml':
        return 'millilitres';
      case 'pack':
        return 'packs';
      case 'bottle':
        return 'bottles';
      case 'box':
        return 'boxes';
      default:
        return unit;
    }
  }

  String foodIcon(String category) {
    switch (category.toLowerCase()) {
      case 'dairy':
        return '🥛';
      case 'fruits':
        return '🍎';
      case 'vegetables':
        return '🥦';
      case 'grains':
        return '🌾';
      case 'meat':
        return '🥩';
      case 'seafood':
        return '🐟';
      case 'frozen':
        return '🧊';
      case 'snacks':
        return '🍪';
      case 'beverages':
        return '🥤';
      case 'bakery':
        return '🥐';
      case 'condiments':
        return '🫙';
      default:
        return '📦';
    }
  }

  String status(Map<String, dynamic> food) {
    final expiry =
        food['expiry']?.toString() ?? '';

    try {
      final expiryDate =
          DateTime.parse(expiry);

      final now = DateTime.now();

      final days = DateTime(
        expiryDate.year,
        expiryDate.month,
        expiryDate.day,
      ).difference(
        DateTime(
          now.year,
          now.month,
          now.day,
        ),
      ).inDays;

      if (days < 0) {
        return 'Expired';
      }

      if (days <= 3) {
        return 'Expiring Soon';
      }

      final quantity =
          double.tryParse(
                food['quantity'].toString(),
              ) ??
              0;

      if (quantity <= 2) {
        return 'Low Stock';
      }

      return 'Good';
    } catch (_) {
      return 'Good';
    }
  }

  Color statusColor(String value) {
    switch (value) {
      case 'Expired':
        return Colors.red;
      case 'Expiring Soon':
        return Colors.orange;
      case 'Low Stock':
        return Colors.amber.shade800;
      default:
        return const Color(0xFF16845F);
    }
  }

  Future<void> addFood() async {
    await showDialog(
      context: context,
      builder: (_) => FoodDialog(
        api: widget.api,
      ),
    );

    await loadFoods();
  }

  Future<void> editFood(
    Map<String, dynamic> food,
  ) async {
    await showDialog(
      context: context,
      builder: (_) => FoodDialog(
        api: widget.api,
        existingFood: food,
      ),
    );

    await loadFoods();
  }

  Future<void> useOneFoodUnit(
      Map<String, dynamic> food) async {
    final id = food['id'] as int;
    final quantity =
        (food['quantity'] as num?)?.toDouble() ?? 0;

    if (quantity <= 0) return;

    try {
      final result =
          await widget.api.useOneUnit(id);

      if (!mounted) return;

      await loadFoods();

      final remaining =
          (result['quantity'] as num?)?.toDouble() ??
              (quantity - 1);

      final displayRemaining =
          remaining % 1 == 0
              ? remaining.toInt().toString()
              : remaining.toString();

      ScaffoldMessenger.of(context)
          .showSnackBar(
        SnackBar(
          content: Text(
            remaining <= 0
                ? '${food['food']} is now used up.'
                : 'Used 1 ${unitDisplay(food['unit'] ?? '')}. '
                    '$displayRemaining remaining.',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(
        SnackBar(
          content: Text(
            e.toString().replaceFirst(
              'Exception: ',
              '',
            ),
          ),
        ),
      );
    }
  }

  Future<void> deleteFood(int id) async {
    final confirmed =
        await showDialog<bool>(
      context: context,
      builder: (context) =>
          AlertDialog(
        title:
            const Text('Delete food?'),
        content: const Text(
          'This food will be permanently removed.',
        ),
        actions: [
          TextButton(
            onPressed: () =>
                Navigator.pop(
              context,
              false,
            ),
            child:
                const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () =>
                Navigator.pop(
              context,
              true,
            ),
            style:
                ElevatedButton.styleFrom(
              backgroundColor:
                  Colors.red,
              foregroundColor:
                  Colors.white,
            ),
            child:
                const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) {
      return;
    }

    try {
      await widget.api.deleteFood(id);

      if (!mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(
        const SnackBar(
          content:
              Text('Food deleted.'),
        ),
      );

      await loadFoods();
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(
        SnackBar(
          content: Text(
            e
                .toString()
                .replaceFirst(
                  'Exception: ',
                  '',
                ),
          ),
        ),
      );
    }
  }

  Widget foodTile(
    Map<String, dynamic> food,
  ) {
    final id =
        int.tryParse(
      food['id'].toString(),
    );

    final name =
        food['food']?.toString() ?? '';

    final category =
        food['category']?.toString() ?? '';

    final quantity =
        food['quantity']?.toString() ?? '';

    final unit =
        food['unit']?.toString() ?? '';

    final expiry =
        food['expiry']?.toString() ?? '';

    final currentStatus =
        status(food);

    final color =
        statusColor(currentStatus);

    return Container(
      margin: const EdgeInsets.only(bottom: 7),
      padding: const EdgeInsets.fromLTRB(
        10,
        8,
        8,
        8,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: Colors.black.withValues(alpha: 0.035),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.025),
            blurRadius: 9,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: const Color(0xFFE8F5EF),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Center(
              child: Text(
                foodIcon(category),
                style: const TextStyle(fontSize: 22),
              ),
            ),
          ),

          const SizedBox(width: 9),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 3),

                Text(
                  '$category • $quantity ${unitDisplay(unit)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 10.5,
                    color: Colors.grey,
                  ),
                ),

                const SizedBox(height: 5),

                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    currentStatus,
                    style: TextStyle(
                      color: color,
                      fontSize: 9.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(width: 7),

          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const Text(
                'Expires',
                style: TextStyle(
                  fontSize: 9.5,
                  color: Colors.grey,
                ),
              ),

              const SizedBox(height: 3),

              Text(
                expiry,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),

              const SizedBox(height: 4),

              PopupMenuButton<String>(
                tooltip: 'Food actions',
                padding: EdgeInsets.zero,
                icon: const Icon(
                  Icons.more_horiz,
                  size: 22,
                ),
                onSelected: (value) async {
                  if (id == null) return;

                  if (value == 'edit') {
                    await editFood(food);
                  }

                  if (value == 'used') {
                    await useOneFoodUnit(food);
                  }

                  if (value == 'delete') {
                    await deleteFood(id);
                  }
                },
                itemBuilder:
                    (context) => const [
                  PopupMenuItem(
                    value: 'edit',
                    child: Row(
                      children: [
                        Icon(Icons.edit_outlined),
                        SizedBox(width: 10),
                        Text('Edit'),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'used',
                    child: Row(
                      children: [
                        Icon(Icons.check_circle_outline),
                        SizedBox(width: 10),
                        Text('Use 1'),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(Icons.delete_outline),
                        SizedBox(width: 10),
                        Text('Delete'),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final visibleFoods = searchedFoods;

    return Scaffold(
      backgroundColor:
          const Color(0xFFEDF4F0),

      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        title: const Row(
          children: [
            Text(
              '🥬',
              style: TextStyle(fontSize: 29),
            ),
            SizedBox(width: 10),
            Text(
              'My Pantry',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Color(0xFF16845F),
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh pantry',
            onPressed: loadFoods,
            icon: const Icon(Icons.refresh),
          ),
          const SizedBox(width: 8),
        ],
      ),

      floatingActionButton:
          FloatingActionButton.extended(
        onPressed: addFood,
        backgroundColor:
            const Color(0xFF16845F),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Add Food'),
      ),

      body: loading
          ? const Center(
              child: CircularProgressIndicator(
                color: Color(0xFF16845F),
              ),
            )
          : error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          '⚠️',
                          style: TextStyle(fontSize: 45),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          error!,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 15),
                        ElevatedButton.icon(
                          onPressed: loadFoods,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Try Again'),
                        ),
                      ],
                    ),
                  ),
                )
              : Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                        20,
                        20,
                        20,
                        10,
                      ),
                      child: TextField(
                        controller: searchController,
                        onChanged: (value) {
                          setState(() {
                            searchQuery = value;
                          });
                        },
                        decoration: InputDecoration(
                          hintText: 'Search your pantry...',
                          prefixIcon: const Icon(
                            Icons.search,
                          ),
                          suffixIcon:
                              searchQuery.isNotEmpty
                                  ? IconButton(
                                      tooltip: 'Clear search',
                                      onPressed: () {
                                        searchController.clear();
                                        setState(() {
                                          searchQuery = '';
                                        });
                                      },
                                      icon: const Icon(
                                        Icons.close,
                                      ),
                                    )
                                  : null,
                          filled: true,
                          fillColor: Colors.white,
                          contentPadding:
                              const EdgeInsets.symmetric(
                            vertical: 14,
                            horizontal: 14,
                          ),
                          border: OutlineInputBorder(
                            borderRadius:
                                BorderRadius.circular(14),
                            borderSide: BorderSide.none,
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius:
                                BorderRadius.circular(14),
                            borderSide: BorderSide(
                              color: Colors.black
                                  .withValues(alpha: 0.05),
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius:
                                BorderRadius.circular(14),
                            borderSide: const BorderSide(
                              color: Color(0xFF16845F),
                              width: 1.4,
                            ),
                          ),
                        ),
                      ),
                    ),

                    Expanded(
                      child: foods.isEmpty
                          ? const Center(
                              child: Column(
                                mainAxisSize:
                                    MainAxisSize.min,
                                children: [
                                  Text(
                                    '🌱',
                                    style: TextStyle(
                                      fontSize: 55,
                                    ),
                                  ),
                                  SizedBox(height: 12),
                                  Text(
                                    'Your pantry is empty.',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight:
                                          FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : visibleFoods.isEmpty
                              ? Center(
                                  child: Padding(
                                    padding:
                                        const EdgeInsets.all(
                                      24,
                                    ),
                                    child: Column(
                                      mainAxisSize:
                                          MainAxisSize.min,
                                      children: [
                                        const Text(
                                          '🔎',
                                          style: TextStyle(
                                            fontSize: 42,
                                          ),
                                        ),
                                        const SizedBox(
                                            height: 10),
                                        const Text(
                                          'No food found.',
                                          style: TextStyle(
                                            fontSize: 18,
                                            fontWeight:
                                                FontWeight.w600,
                                          ),
                                        ),
                                        const SizedBox(
                                            height: 5),
                                        Text(
                                          'Try another food name or category.',
                                          textAlign:
                                              TextAlign.center,
                                          style: TextStyle(
                                            color:
                                                Colors.grey.shade600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                )
                              : RefreshIndicator(
                                  color:
                                      const Color(0xFF16845F),
                                  onRefresh: loadFoods,
                                  child: ListView.builder(
                                    padding:
                                        const EdgeInsets.fromLTRB(
                                      20,
                                      8,
                                      20,
                                      100,
                                    ),
                                    itemCount:
                                        visibleFoods.length,
                                    itemBuilder:
                                        (context, index) {
                                      return foodTile(
                                        visibleFoods[index],
                                      );
                                    },
                                  ),
                                ),
                    ),
                  ],
                ),
    );
  }

}

// =====================================================
// ADD / EDIT FOOD DIALOG
// =====================================================

class FoodDialog extends StatefulWidget {
  final ApiService api;
  final Map<String, dynamic>?
      existingFood;

  const FoodDialog({
    super.key,
    required this.api,
    this.existingFood,
  });

  @override
  State<FoodDialog> createState() =>
      _FoodDialogState();
}

class _FoodDialogState
    extends State<FoodDialog> {
  late TextEditingController
      foodController;

  late TextEditingController
      quantityController;

  late TextEditingController
      expiryController;

  String? category;
  String unit = 'pcs';

  bool saving = false;
  String? error;

  final List<String> categories = [
    'Dairy',
    'Fruits',
    'Vegetables',
    'Grains',
    'Meat',
    'Seafood',
    'Frozen',
    'Snacks',
    'Beverages',
    'Bakery',
    'Condiments',
    'Other',
  ];

  final List<String> units = [
    'pcs',
    'kg',
    'g',
    'L',
    'ml',
    'pack',
    'bottle',
    'box',
  ];

  bool get isEditing =>
      widget.existingFood != null;

  @override
  void initState() {
    super.initState();

    final food =
        widget.existingFood;

    foodController =
        TextEditingController(
      text: food?['food']?.toString() ??
          '',
    );

    quantityController =
        TextEditingController(
      text: food?['quantity']
              ?.toString() ??
          '',
    );

    expiryController =
        TextEditingController(
      text: food?['expiry']?.toString() ??
          '',
    );

    if (food != null) {
      final savedCategory =
          food['category']?.toString();

      final savedUnit =
          food['unit']?.toString();

      if (savedCategory != null &&
          categories.contains(
            savedCategory,
          )) {
        category = savedCategory;
      }

      if (savedUnit != null &&
          units.contains(savedUnit)) {
        unit = savedUnit;
      }
    }
  }

  @override
  void dispose() {
    foodController.dispose();
    quantityController.dispose();
    expiryController.dispose();
    super.dispose();
  }

  Future<void> chooseExpiry() async {
    DateTime initial =
        DateTime.now();

    if (expiryController
        .text
        .isNotEmpty) {
      try {
        initial = DateTime.parse(
          expiryController.text,
        );
      } catch (_) {}
    }

    final picked =
        await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );

    if (picked == null) return;

    final month =
        picked.month
            .toString()
            .padLeft(2, '0');

    final day =
        picked.day
            .toString()
            .padLeft(2, '0');

    expiryController.text =
        '${picked.year}-$month-$day';
  }

  Future<void> save() async {
    final food =
        foodController.text.trim();

    final quantity =
        double.tryParse(
      quantityController.text
          .trim(),
    );

    final expiry =
        expiryController.text.trim();

    if (food.isEmpty) {
      setState(() {
        error =
            'Please enter a food name.';
      });
      return;
    }

    if (category == null) {
      setState(() {
        error =
            'Please select a category.';
      });
      return;
    }

    if (quantity == null ||
        quantity <= 0) {
      setState(() {
        error =
            'Please enter a valid quantity.';
      });
      return;
    }

    if (expiry.isEmpty) {
      setState(() {
        error =
            'Please select an expiry date.';
      });
      return;
    }

    setState(() {
      saving = true;
      error = null;
    });

    try {
      if (isEditing) {
        final id =
            int.tryParse(
          widget.existingFood!['id']
              .toString(),
        );

        if (id == null) {
          throw Exception(
            'Invalid food ID.',
          );
        }

        await widget.api.editFood(
          id: id,
          food: food,
          category: category!,
          quantity: quantity,
          unit: unit,
          expiry: expiry,
        );
      } else {
        await widget.api.addFood(
          food: food,
          category: category!,
          quantity: quantity,
          unit: unit,
          expiry: expiry,
        );
      }

      if (!mounted) return;

      Navigator.pop(context);

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(
        SnackBar(
          content: Text(
            isEditing
                ? 'Food updated successfully.'
                : 'Food added successfully.',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      setState(() {
        error = e
            .toString()
            .replaceFirst(
              'Exception: ',
              '',
            );
        saving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      scrollable: true,
      insetPadding: const EdgeInsets.symmetric(
        horizontal: 18,
        vertical: 20,
      ),
      title: Text(
        isEditing
            ? 'Edit Food'
            : 'Add Food',
      ),

      content: SizedBox(
        width: 450,

        child: SingleChildScrollView(
          child: Column(
            mainAxisSize:
                MainAxisSize.min,
            children: [
              TextField(
                controller:
                    foodController,
                decoration:
                    const InputDecoration(
                  labelText:
                      'Food name',
                  hintText:
                      'e.g. Apples',
                  prefixIcon:
                      Icon(
                    Icons
                        .restaurant_outlined,
                  ),
                  border:
                      OutlineInputBorder(),
                ),
              ),

              const SizedBox(
                height: 15,
              ),

              DropdownButtonFormField<String>(
                value: category,
                decoration:
                    const InputDecoration(
                  labelText:
                      'Category',
                  hintText:
                      'Select category',
                  border:
                      OutlineInputBorder(),
                ),
                items:
                    categories.map(
                  (item) {
                    return DropdownMenuItem<String>(
                      value: item,
                      child:
                          Text(item),
                    );
                  },
                ).toList(),
                onChanged:
                    (value) {
                  setState(() {
                    category =
                        value;
                  });
                },
              ),

              const SizedBox(
                height: 15,
              ),

              Row(
                children: [
                  Expanded(
                    child:
                        TextField(
                      controller: quantityController,
                      keyboardType:
                          const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: InputDecoration(
                        labelText: 'Quantity',
                        prefixIcon: const Icon(
                          Icons.inventory_2_outlined,
                        ),
                        suffixIcon:
                            PopupMenuButton<String>(
                          tooltip: 'Choose quantity',
                          icon: const Icon(
                            Icons.arrow_drop_down,
                          ),
                          onSelected: (value) {
                            quantityController.text = value;
                            setState(() {});
                          },
                          itemBuilder: (context) {
                            const suggestions = <String>[
                              '1',
                              '2',
                              '3',
                              '4',
                              '5',
                              '6',
                              '7',
                              '8',
                              '9',
                              '10',
                              '12',
                              '15',
                              '20',
                              '25',
                              '50',
                              '100',
                            ];

                            return suggestions.map(
                              (value) => PopupMenuItem<String>(
                                value: value,
                                child: Text(value),
                              ),
                            ).toList();
                          },
                        ),
                        border: const OutlineInputBorder(),
                      ),
                    ),
                  ),

                  const SizedBox(
                    width: 8,
                  ),

                  Expanded(
                    child:
                        DropdownButtonFormField<String>(
                      value: unit,
                      decoration:
                          const InputDecoration(
                        labelText:
                            'Unit',
                        border:
                            OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem<String>(
                          value: 'pcs',
                          child: Text('Pieces'),
                        ),
                        DropdownMenuItem<String>(
                          value: 'kg',
                          child: Text('Kilograms'),
                        ),
                        DropdownMenuItem<String>(
                          value: 'g',
                          child: Text('Grams'),
                        ),
                        DropdownMenuItem<String>(
                          value: 'L',
                          child: Text('Litres'),
                        ),
                        DropdownMenuItem<String>(
                          value: 'ml',
                          child: Text('Millilitres'),
                        ),
                        DropdownMenuItem<String>(
                          value: 'pack',
                          child: Text('Packs'),
                        ),
                        DropdownMenuItem<String>(
                          value: 'bottle',
                          child: Text('Bottles'),
                        ),
                        DropdownMenuItem<String>(
                          value: 'box',
                          child: Text('Boxes'),
                        ),
                      ],
                      onChanged:
                          (value) {
                        if (value ==
                            null) {
                          return;
                        }

                        setState(() {
                          unit = value;
                        });
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Type a value or tap the arrow to choose.',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey,
                  ),
                ),
              ),

              const SizedBox(
                height: 15,
              ),

              TextField(
                controller:
                    expiryController,
                readOnly: true,
                onTap:
                    chooseExpiry,
                decoration:
                    const InputDecoration(
                  labelText:
                      'Expiry date',
                  hintText:
                      'YYYY-MM-DD',
                  prefixIcon:
                      Icon(
                    Icons
                        .calendar_today_outlined,
                  ),
                  border:
                      OutlineInputBorder(),
                ),
              ),

              if (error != null) ...[
                const SizedBox(
                  height: 15,
                ),

                Container(
                  width:
                      double.infinity,
                  padding:
                      const EdgeInsets
                          .all(
                    12,
                  ),
                  decoration:
                      BoxDecoration(
                    color:
                        Colors.red.shade50,
                    borderRadius:
                        BorderRadius
                            .circular(
                      10,
                    ),
                  ),
                  child: Text(
                    error!,
                    style:
                        TextStyle(
                      color:
                          Colors.red.shade700,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),

      actions: [
        TextButton(
          onPressed: saving
              ? null
              : () =>
                  Navigator.pop(
                context,
              ),
          child:
              const Text('Cancel'),
        ),

        ElevatedButton(
          onPressed:
              saving ? null : save,
          style:
              ElevatedButton.styleFrom(
            backgroundColor:
                const Color(
              0xFF16845F,
            ),
            foregroundColor:
                Colors.white,
          ),
          child: saving
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child:
                      CircularProgressIndicator(
                    color:
                        Colors.white,
                    strokeWidth: 2,
                  ),
                )
              : Text(
                  isEditing
                      ? 'Save Changes'
                      : 'Add Food',
                ),
        ),
      ],
    );
  }
}