import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../theme/bock_colors.dart';

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
          backgroundColor: BockColors.cardDark,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: BockColors.purple.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_rounded,
                  color: BockColors.purpleLight,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              const Text(
                'Account Created',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: BockColors.textPrimaryDark,
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Your Hex ID — save this to log in:',
                style: TextStyle(
                  fontSize: 13,
                  color: BockColors.textSecondaryDark,
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(
                  vertical: 12,
                  horizontal: 14,
                ),
                decoration: BoxDecoration(
                  color: BockColors.surfaceDark,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: BockColors.purple.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: SelectableText(
                        hexId ?? '',
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.4,
                          color: BockColors.purpleLight,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.copy_rounded,
                        size: 18,
                        color: BockColors.purpleLight,
                      ),
                      tooltip: 'Copy',
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: hexId ?? ''));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Hex ID copied'),
                            backgroundColor: BockColors.purple,
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF2A1F00),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFF5C4400)),
                ),
                child: Row(
                  children: const [
                    Icon(
                      Icons.info_outline_rounded,
                      size: 15,
                      color: Color(0xFFFFCC02),
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Save this — you\'ll need it every time you log in.',
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFFDDB800),
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
                  backgroundColor: BockColors.purple,
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
                  'Go to Login',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                ),
              ),
            ),
          ],
        ),
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
          Positioned(
            top: -100,
            left: -80,
            child: Container(
              width: 280,
              height: 280,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: BockColors.purple.withValues(alpha: 0.10),
              ),
            ),
          ),
          Positioned(
            bottom: -120,
            right: -60,
            child: Container(
              width: 320,
              height: 320,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: BockColors.purpleDim.withValues(alpha: 0.12),
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
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: width > 500 ? 420 : double.infinity,
                    ),
                    child: Column(
                      children: [
                        // Brand header
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: BockColors.purple.withValues(alpha: 0.12),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: BockColors.purple.withValues(alpha: 0.25),
                            ),
                          ),
                          child: const Icon(
                            Icons.person_add_rounded,
                            size: 32,
                            color: BockColors.purpleLight,
                          ),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Create Account',
                          style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w800,
                            color: BockColors.textPrimaryDark,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Join Bock Store today',
                          style: TextStyle(
                            fontSize: 14,
                            color: BockColors.textSecondaryDark,
                          ),
                        ),

                        const SizedBox(height: 32),

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
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            _label('First Name'),
                                            const SizedBox(height: 8),
                                            TextFormField(
                                              controller: _firstNameCtrl,
                                              textCapitalization:
                                                  TextCapitalization.words,
                                              style: _textStyle,
                                              decoration: _inputDeco(
                                                hint: 'First',
                                                icon: Icons.person_rounded,
                                              ),
                                              validator: (v) =>
                                                  (v == null ||
                                                      v.trim().isEmpty)
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
                                            _label('Last Name'),
                                            const SizedBox(height: 8),
                                            TextFormField(
                                              controller: _lastNameCtrl,
                                              textCapitalization:
                                                  TextCapitalization.words,
                                              style: _textStyle,
                                              decoration: _inputDeco(
                                                hint: 'Last',
                                                icon: Icons.person_rounded,
                                              ),
                                              validator: (v) =>
                                                  (v == null ||
                                                      v.trim().isEmpty)
                                                  ? 'Required'
                                                  : null,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),

                                  const SizedBox(height: 18),
                                  _label('Date of Birth'),
                                  const SizedBox(height: 8),
                                  TextFormField(
                                    controller: _dobCtrl,
                                    keyboardType: TextInputType.datetime,
                                    style: _textStyle,
                                    decoration: _inputDeco(
                                      hint: 'YYYY-MM-DD',
                                      icon: Icons.calendar_month_rounded,
                                      suffix: IconButton(
                                        icon: const Icon(
                                          Icons.edit_calendar_rounded,
                                          color: BockColors.purpleLight,
                                          size: 20,
                                        ),
                                        onPressed: () async {
                                          final picked = await showDatePicker(
                                            context: context,
                                            initialDate: DateTime(2000),
                                            firstDate: DateTime(1900),
                                            lastDate: DateTime.now(),
                                            builder: (context, child) => Theme(
                                              data: Theme.of(context).copyWith(
                                                colorScheme:
                                                    const ColorScheme.dark(
                                                      primary:
                                                          BockColors.purple,
                                                    ),
                                              ),
                                              child: child!,
                                            ),
                                          );
                                          if (picked != null) {
                                            setState(() {
                                              _dobCtrl.text =
                                                  '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
                                            });
                                          }
                                        },
                                      ),
                                    ),
                                    validator: (v) {
                                      if (v == null || v.trim().isEmpty)
                                        return 'Required';
                                      if (!RegExp(
                                        r'^\d{4}-\d{2}-\d{2}$',
                                      ).hasMatch(v))
                                        return 'Use YYYY-MM-DD';
                                      try {
                                        DateTime.parse(v);
                                      } catch (_) {
                                        return 'Invalid date';
                                      }
                                      return null;
                                    },
                                  ),

                                  const SizedBox(height: 18),
                                  _label('Gender'),
                                  const SizedBox(height: 8),
                                  DropdownButtonFormField<String>(
                                    initialValue: _gender,
                                    dropdownColor: BockColors.cardDark,
                                    style: _textStyle,
                                    icon: const Icon(
                                      Icons.keyboard_arrow_down_rounded,
                                      color: BockColors.purpleLight,
                                    ),
                                    decoration: _inputDeco(
                                      hint: 'Select',
                                      icon: Icons.wc_rounded,
                                    ),
                                    items: ['Male', 'Female', 'Other']
                                        .map(
                                          (g) => DropdownMenuItem(
                                            value: g,
                                            child: Text(g),
                                          ),
                                        )
                                        .toList(),
                                    onChanged: (v) =>
                                        setState(() => _gender = v!),
                                  ),

                                  const SizedBox(height: 18),
                                  _label('Email'),
                                  const SizedBox(height: 8),
                                  TextFormField(
                                    controller: _emailCtrl,
                                    keyboardType: TextInputType.emailAddress,
                                    style: _textStyle,
                                    decoration: _inputDeco(
                                      hint: 'you@example.com',
                                      icon: Icons.email_rounded,
                                    ),
                                    validator: (v) =>
                                        (v == null || !v.contains('@'))
                                        ? 'Valid email required'
                                        : null,
                                  ),

                                  const SizedBox(height: 18),
                                  _label('Password'),
                                  const SizedBox(height: 8),
                                  TextFormField(
                                    controller: _passwordCtrl,
                                    obscureText: _obscure,
                                    style: _textStyle,
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

                                  const SizedBox(height: 18),
                                  _label('Confirm Password'),
                                  const SizedBox(height: 8),
                                  TextFormField(
                                    controller: _confirmCtrl,
                                    obscureText: _obscure,
                                    style: _textStyle,
                                    decoration: _inputDeco(
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
                                              'Create Account',
                                              style: TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.w700,
                                                letterSpacing: 0.2,
                                              ),
                                            ),
                                    ),
                                  ),

                                  const SizedBox(height: 18),

                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        'Already have an account?',
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: BockColors.textSecondaryDark,
                                        ),
                                      ),
                                      TextButton(
                                        onPressed: () => Navigator.pop(context),
                                        style: TextButton.styleFrom(
                                          foregroundColor:
                                              BockColors.purpleLight,
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

  static const _textStyle = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w500,
    color: BockColors.textPrimaryDark,
  );

  Widget _label(String text) => Text(
    text,
    style: const TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w600,
      color: BockColors.textSecondaryDark,
      letterSpacing: 0.4,
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
