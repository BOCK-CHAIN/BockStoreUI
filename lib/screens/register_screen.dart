import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import 'package:flutter/services.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  final _firstNameCtrl = TextEditingController();
  final _lastNameCtrl = TextEditingController();
  final _dobCtrl = TextEditingController();
  String _gender = "Male";
  bool _obscure = true;

  late AnimationController _animCtrl;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _fadeAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.06),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut));
    _animCtrl.forward();
  }

  @override
  void dispose() {
    _firstNameCtrl.dispose();
    _lastNameCtrl.dispose();
    _dobCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    _animCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final auth = context.read<AuthProvider>();

    final error = await auth.register(
      _firstNameCtrl.text.trim(),
      _lastNameCtrl.text.trim(),
      _emailCtrl.text.trim(),
      _passwordCtrl.text,
      _dobCtrl.text.trim(),
      _gender,
    );

    if (!mounted) return;

    if (error == null) {
      final hexId = context.read<AuthProvider>().lastHexId;

      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF6A1B9A).withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_circle_rounded,
                  color: Color(0xFF6A1B9A),
                  size: 22,
                ),
              ),
              const SizedBox(width: 10),
              const Text(
                "Registration Successful",
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Your Hex ID (use this to login):",
                style: TextStyle(
                  fontWeight: FontWeight.w500,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(
                  vertical: 12,
                  horizontal: 14,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFF5FAF6),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: const Color(0xFF6A1B9A).withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: SelectableText(
                        hexId ?? "",
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.4,
                          color: Color(0xFF6A1B9A),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Material(
                      color: const Color(0xFF6A1B9A).withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(8),
                      child: IconButton(
                        icon: const Icon(
                          Icons.copy_rounded,
                          size: 18,
                          color: Color(0xFF6A1B9A),
                        ),
                        tooltip: "Copy Hex ID",
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: hexId ?? ""));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text("Hex ID copied"),
                              backgroundColor: Color(0xFF6A1B9A),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF8E1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFFFCC02)),
                ),
                child: Row(
                  children: const [
                    Icon(
                      Icons.info_outline_rounded,
                      size: 16,
                      color: Color(0xFFF9A825),
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        "Save this ID — you'll need it to log in.",
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFF795548),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color(0xFF6A1B9A),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.popUntil(context, (route) => route.isFirst);
                },
                child: const Text(
                  "Go to Login",
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                ),
              ),
            ),
          ],
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error),
          backgroundColor: const Color(0xFFE53935),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final loading = context.watch<AuthProvider>().loading;
    final width = MediaQuery.of(context).size.width;

    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F0),
      body: Stack(
        children: [
          Positioned(
            top: -60,
            left: -60,
            child: Container(
              width: 220,
              height: 220,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF6A1B9A).withValues(alpha: 0.09),
              ),
            ),
          ),
          Positioned(
            bottom: -80,
            right: -50,
            child: Container(
              width: 280,
              height: 280,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF6A1B9A).withValues(alpha: 0.06),
              ),
            ),
          ),
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
              child: FadeTransition(
                opacity: _fadeAnim,
                child: SlideTransition(
                  position: _slideAnim,
                  child: Container(
                    width: width > 500 ? 420 : double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(28),
                      boxShadow: [
                        BoxShadow(
                          blurRadius: 40,
                          offset: const Offset(0, 12),
                          color: const Color(
                            0xFF6A1B9A,
                          ).withValues(alpha: 0.08),
                        ),
                        BoxShadow(
                          blurRadius: 20,
                          offset: const Offset(0, 4),
                          color: const Color(
                            0xFF000000,
                          ).withValues(alpha: 0.06),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Header
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                            vertical: 28,
                            horizontal: 32,
                          ),
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              colors: [Color(0xFF6A1B9A), Color(0xFF4A148C)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.only(
                              topLeft: Radius.circular(28),
                              topRight: Radius.circular(28),
                            ),
                          ),
                          child: Column(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.20),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.person_add_rounded,
                                  size: 32,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 12),
                              const Text(
                                'Create Account',
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                  letterSpacing: 0.3,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Join the Bock Store today!',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.white.withValues(alpha: 0.85),
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Form
                        Padding(
                          padding: const EdgeInsets.fromLTRB(28, 28, 28, 28),
                          child: Form(
                            key: _formKey,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Name row
                                Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          _buildLabel('First Name'),
                                          const SizedBox(height: 8),
                                          TextFormField(
                                            controller: _firstNameCtrl,
                                            textCapitalization:
                                                TextCapitalization.words,
                                            style: const TextStyle(
                                              fontSize: 15,
                                              fontWeight: FontWeight.w500,
                                            ),
                                            decoration: _inputDecoration(
                                              hint: 'enter first name',
                                              icon: Icons.person_rounded,
                                            ),
                                            validator: (v) =>
                                                (v == null || v.trim().isEmpty)
                                                ? 'Required'
                                                : null,
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          _buildLabel('Last Name'),
                                          const SizedBox(height: 8),
                                          TextFormField(
                                            controller: _lastNameCtrl,
                                            textCapitalization:
                                                TextCapitalization.words,
                                            style: const TextStyle(
                                              fontSize: 15,
                                              fontWeight: FontWeight.w500,
                                            ),
                                            decoration: _inputDecoration(
                                              hint: 'enter last name',
                                              icon: Icons.person_rounded,
                                            ),
                                            validator: (v) =>
                                                (v == null || v.trim().isEmpty)
                                                ? 'Required'
                                                : null,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 18),

                                _buildLabel('Date of Birth'),
                                const SizedBox(height: 8),
                                TextFormField(
                                  controller: _dobCtrl,
                                  keyboardType: TextInputType.datetime,
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  decoration: _inputDecoration(
                                    hint: 'YYYY-MM-DD',
                                    icon: Icons.calendar_month_rounded,
                                    suffix: IconButton(
                                      icon: const Icon(
                                        Icons.edit_calendar_rounded,
                                        color: Color(0xFF6A1B9A),
                                        size: 20,
                                      ),
                                      onPressed: () async {
                                        DateTime? picked = await showDatePicker(
                                          context: context,
                                          initialDate: DateTime(2000),
                                          firstDate: DateTime(1900),
                                          lastDate: DateTime.now(),
                                          builder: (context, child) => Theme(
                                            data: Theme.of(context).copyWith(
                                              colorScheme:
                                                  const ColorScheme.light(
                                                    primary: Color(0xFF6A1B9A),
                                                  ),
                                            ),
                                            child: child!,
                                          ),
                                        );

                                        if (picked != null) {
                                          setState(() {
                                            _dobCtrl.text =
                                                "${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}";
                                          });
                                        }
                                      },
                                    ),
                                  ),
                                  validator: (value) {
                                    if (value == null || value.trim().isEmpty) {
                                      return "Enter or select DOB";
                                    }

                                    final regex = RegExp(
                                      r'^\d{4}-\d{2}-\d{2}$',
                                    );

                                    if (!regex.hasMatch(value)) {
                                      return "Use format YYYY-MM-DD";
                                    }

                                    try {
                                      DateTime.parse(value);
                                    } catch (_) {
                                      return "Invalid date";
                                    }

                                    return null;
                                  },
                                ),
                                const SizedBox(height: 18),

                                _buildLabel('Gender'),
                                const SizedBox(height: 8),
                                DropdownButtonFormField<String>(
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.black87,
                                  ),
                                  icon: const Icon(
                                    Icons.keyboard_arrow_down_rounded,
                                    color: Color(0xFF6A1B9A),
                                  ),
                                  decoration: _inputDecoration(
                                    hint: 'Select',
                                    icon: Icons.wc_rounded,
                                  ),
                                  items: const [
                                    DropdownMenuItem(
                                      value: "Male",
                                      child: Text("Male"),
                                    ),
                                    DropdownMenuItem(
                                      value: "Female",
                                      child: Text("Female"),
                                    ),
                                    DropdownMenuItem(
                                      value: "Other",
                                      child: Text("Other"),
                                    ),
                                  ],
                                  onChanged: (value) {
                                    setState(() {
                                      _gender = value!;
                                    });
                                  },
                                ),
                                const SizedBox(height: 18),

                                _buildLabel('Email'),
                                const SizedBox(height: 8),
                                TextFormField(
                                  controller: _emailCtrl,
                                  keyboardType: TextInputType.emailAddress,
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  decoration: _inputDecoration(
                                    hint: 'you@example.com',
                                    icon: Icons.email_rounded,
                                  ),
                                  validator: (v) =>
                                      (v == null || !v.contains('@'))
                                      ? 'Enter a valid email'
                                      : null,
                                ),
                                const SizedBox(height: 18),

                                _buildLabel('Password'),
                                const SizedBox(height: 8),
                                TextFormField(
                                  controller: _passwordCtrl,
                                  obscureText: _obscure,
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  decoration: _inputDecoration(
                                    hint: '••••••••',
                                    icon: Icons.lock_rounded,
                                    suffix: IconButton(
                                      icon: Icon(
                                        _obscure
                                            ? Icons.visibility_rounded
                                            : Icons.visibility_off_rounded,
                                        color: const Color(0xFF6A1B9A),
                                        size: 20,
                                      ),
                                      onPressed: () =>
                                          setState(() => _obscure = !_obscure),
                                    ),
                                  ),
                                  validator: (v) => (v == null || v.length < 6)
                                      ? 'Min 6 characters'
                                      : null,
                                ),
                                const SizedBox(height: 18),

                                _buildLabel('Confirm Password'),
                                const SizedBox(height: 8),
                                TextFormField(
                                  controller: _confirmCtrl,
                                  obscureText: _obscure,
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  decoration: _inputDecoration(
                                    hint: '••••••••',
                                    icon: Icons.lock_rounded,
                                  ),
                                  validator: (v) => v != _passwordCtrl.text
                                      ? 'Passwords do not match'
                                      : null,
                                ),
                                const SizedBox(height: 28),

                                SizedBox(
                                  width: double.infinity,
                                  height: 52,
                                  child: ElevatedButton(
                                    onPressed: loading ? null : _submit,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF6A1B9A),
                                      foregroundColor: Colors.white,
                                      disabledBackgroundColor: const Color(
                                        0xFF6A1B9A,
                                      ).withValues(alpha: 0.5),
                                      elevation: 0,
                                      shadowColor: Colors.transparent,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(14),
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
                                            'Create Account',
                                            style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w700,
                                              letterSpacing: 0.4,
                                            ),
                                          ),
                                  ),
                                ),

                                const SizedBox(height: 18),

                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      "Already have an account?",
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: Colors.grey.shade600,
                                      ),
                                    ),
                                    TextButton(
                                      onPressed: () => Navigator.pop(context),
                                      style: TextButton.styleFrom(
                                        foregroundColor: const Color(
                                          0xFF6A1B9A,
                                        ),
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 6,
                                        ),
                                      ),
                                      child: const Text(
                                        'Sign In',
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

  Widget _buildLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: Color(0xFF424242),
        letterSpacing: 0.2,
      ),
    );
  }

  InputDecoration _inputDecoration({
    required String hint,
    required IconData icon,
    Widget? suffix,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
      prefixIcon: Icon(icon, color: const Color(0xFF6A1B9A), size: 20),
      suffixIcon: suffix,
      filled: true,
      fillColor: const Color(0xFFF5FAF6),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: Colors.grey.shade200),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: Colors.grey.shade200),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFF6A1B9A), width: 1.8),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFE53935), width: 1.5),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFE53935), width: 1.8),
      ),
    );
  }
}
