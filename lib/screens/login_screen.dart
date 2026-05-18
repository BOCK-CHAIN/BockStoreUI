import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import 'register_screen.dart';
import 'home_screen.dart';
import '../theme/bock_colors.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _hexIdCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _obscure = true;

  late AnimationController _animCtrl;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.04),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut));
    _animCtrl.forward();
  }

  @override
  void dispose() {
    _hexIdCtrl.dispose();
    _passwordCtrl.dispose();
    _animCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final auth = context.read<AuthProvider>();
    final error = await auth.login(_hexIdCtrl.text.trim(), _passwordCtrl.text);
    if (!mounted) return;
    if (error == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            auth.isAdmin ? 'Admin login successful' : 'Welcome back',
          ),
          backgroundColor: BockColors.purple,
        ),
      );
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const HomeScreen()),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error), backgroundColor: BockColors.error),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final loading = context.watch<AuthProvider>().loading;
    final width = MediaQuery.of(context).size.width;

    return Scaffold(
      backgroundColor: BockColors.bgDark,
      body: Stack(
        children: [
          // Background glow orbs
          Positioned(
            top: -120,
            right: -80,
            child: _GlowOrb(
              size: 320,
              color: BockColors.purple.withValues(alpha: 0.12),
            ),
          ),
          Positioned(
            bottom: -140,
            left: -100,
            child: _GlowOrb(
              size: 380,
              color: BockColors.purpleDim.withValues(alpha: 0.15),
            ),
          ),

          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
              child: FadeTransition(
                opacity: _fadeAnim,
                child: SlideTransition(
                  position: _slideAnim,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: width > 500 ? 420 : double.infinity,
                    ),
                    child: Column(
                      children: [
                        // Logo / Brand
                        Container(
                          padding: const EdgeInsets.all(18),
                          decoration: BoxDecoration(
                            color: BockColors.purple.withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: BockColors.purple.withValues(alpha: 0.3),
                            ),
                          ),
                          child: const Icon(
                            Icons.storefront_rounded,
                            size: 36,
                            color: BockColors.purpleLight,
                          ),
                        ),
                        const SizedBox(height: 20),
                        const Text(
                          'Bock Store',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                            color: BockColors.textPrimaryDark,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Sign in to continue',
                          style: TextStyle(
                            fontSize: 14,
                            color: BockColors.textSecondaryDark,
                          ),
                        ),

                        const SizedBox(height: 36),

                        // Card
                        Container(
                          decoration: BoxDecoration(
                            color: BockColors.cardDark,
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(color: BockColors.borderDark),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.4),
                                blurRadius: 40,
                                offset: const Offset(0, 16),
                              ),
                            ],
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(28),
                            child: Form(
                              key: _formKey,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _label('Hex ID'),
                                  const SizedBox(height: 8),
                                  TextFormField(
                                    controller: _hexIdCtrl,
                                    style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w500,
                                      color: BockColors.textPrimaryDark,
                                    ),
                                    decoration: _inputDeco(
                                      hint: 'e.g. 7f3a9c21d8',
                                      icon: Icons.badge_rounded,
                                    ),
                                    validator: (v) => (v == null || v.isEmpty)
                                        ? 'Enter your Hex ID'
                                        : null,
                                  ),

                                  const SizedBox(height: 20),
                                  _label('Password'),
                                  const SizedBox(height: 8),
                                  TextFormField(
                                    controller: _passwordCtrl,
                                    obscureText: _obscure,
                                    textInputAction: TextInputAction.done,
                                    onFieldSubmitted: (_) => _submit(),
                                    style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w500,
                                      color: BockColors.textPrimaryDark,
                                    ),
                                    decoration: _inputDeco(
                                      hint: '••••••••',
                                      icon: Icons.lock_rounded,
                                      suffix: IconButton(
                                        icon: Icon(
                                          _obscure
                                              ? Icons.visibility_rounded
                                              : Icons.visibility_off_rounded,
                                          color: BockColors.purpleLight,
                                          size: 20,
                                        ),
                                        onPressed: () => setState(
                                          () => _obscure = !_obscure,
                                        ),
                                      ),
                                    ),
                                    validator: (v) =>
                                        (v == null || v.length < 6)
                                        ? 'Min 6 characters'
                                        : null,
                                  ),

                                  const SizedBox(height: 28),

                                  SizedBox(
                                    width: double.infinity,
                                    height: 52,
                                    child: ElevatedButton(
                                      onPressed: loading ? null : _submit,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: BockColors.purple,
                                        foregroundColor: Colors.white,
                                        disabledBackgroundColor: BockColors
                                            .purple
                                            .withValues(alpha: 0.4),
                                        elevation: 0,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            14,
                                          ),
                                        ),
                                      ),
                                      child: loading
                                          ? const SizedBox(
                                              height: 22,
                                              width: 22,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2.5,
                                                color: Colors.white,
                                              ),
                                            )
                                          : const Text(
                                              'Sign In',
                                              style: TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.w700,
                                                letterSpacing: 0.2,
                                              ),
                                            ),
                                    ),
                                  ),

                                  const SizedBox(height: 20),

                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        "Don't have an account?",
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: BockColors.textSecondaryDark,
                                        ),
                                      ),
                                      TextButton(
                                        onPressed: () => Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) =>
                                                const RegisterScreen(),
                                          ),
                                        ),
                                        style: TextButton.styleFrom(
                                          foregroundColor:
                                              BockColors.purpleLight,
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 6,
                                          ),
                                        ),
                                        child: const Text(
                                          'Register',
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w700,
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
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _label(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 2),
    child: Text(
      text,
      style: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: BockColors.textSecondaryDark,
        letterSpacing: 0.4,
      ),
    ),
  );

  InputDecoration _inputDeco({
    required String hint,
    required IconData icon,
    Widget? suffix,
  }) => InputDecoration(
    hintText: hint,
    hintStyle: TextStyle(
      color: BockColors.textSecondaryDark.withValues(alpha: 0.5),
      fontSize: 14,
    ),
    prefixIcon: Icon(icon, color: BockColors.purple, size: 20),
    suffixIcon: suffix,
    filled: true,
    fillColor: BockColors.surfaceDark,
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: BockColors.borderDark),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: BockColors.borderDark),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: BockColors.purple, width: 1.8),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: BockColors.error, width: 1.5),
    ),
    focusedErrorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: BockColors.error, width: 1.8),
    ),
  );
}

class _GlowOrb extends StatelessWidget {
  final double size;
  final Color color;
  const _GlowOrb({required this.size, required this.color});

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(shape: BoxShape.circle, color: color),
  );
}
