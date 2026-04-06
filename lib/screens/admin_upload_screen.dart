import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:play_store_app/config/api_config.dart';
import '../providers/auth_provider.dart';
import '../models/app_model.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:convert';

class AdminUploadScreen extends StatefulWidget {
  final AppModel? app;

  const AdminUploadScreen({super.key, this.app});

  @override
  State<AdminUploadScreen> createState() => _AdminUploadScreenState();
}

class _AdminUploadScreenState extends State<AdminUploadScreen>
    with SingleTickerProviderStateMixin {
  final nameController = TextEditingController();
  final descController = TextEditingController();
  final versionController = TextEditingController();
  final sizeController = TextEditingController();
  final developerController = TextEditingController();
  final ratedForController = TextEditingController();
  final packageController = TextEditingController();
  String selectedCategory = "Productivity";

  PlatformFile? iconFile;
  List<PlatformFile> screenshotFiles = [];
  PlatformFile? apkFile;
  PlatformFile? windowsFile;
  PlatformFile? linuxFile;

  bool uploading = false;
  bool get isEdit => widget.app != null;

  static const _purple = Color(0xFF6A1B9A);

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
      begin: const Offset(0, 0.05),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut));
    _animCtrl.forward();

    if (isEdit) {
      nameController.text = widget.app!.name;
      descController.text = widget.app!.description;
      versionController.text = widget.app!.version ?? "";
      sizeController.text = widget.app!.size ?? "";
      developerController.text = widget.app!.developer ?? "";
      ratedForController.text = widget.app!.ratedFor ?? "";
      packageController.text = widget.app!.packageName;
    }
  }

  @override
  void dispose() {
    nameController.dispose();
    descController.dispose();
    versionController.dispose();
    sizeController.dispose();
    developerController.dispose();
    ratedForController.dispose();
    packageController.dispose();
    _animCtrl.dispose();
    super.dispose();
  }

  Future<void> pickIcon() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      withData: true,
    );
    if (result != null) setState(() => iconFile = result.files.first);
  }

  Future<void> pickScreenshots() async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: FileType.image,
      withData: true,
    );
    if (result != null && result.files.isNotEmpty) {
      setState(() => screenshotFiles = result.files);
    }
  }

  Future<void> pickApk() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['apk'],
      withData: true,
    );
    if (result != null) setState(() => apkFile = result.files.first);
  }

  Future<void> pickWindowsFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['exe'],
      withData: true,
    );

    if (result != null) {
      setState(() => windowsFile = result.files.first);
    }
  }

  Future<void> pickLinuxFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['deb', 'appimage'],
      withData: true,
    );

    if (result != null) {
      setState(() => linuxFile = result.files.first);
    }
  }

  Future<void> submit() async {
    final auth = context.read<AuthProvider>();
    final token = auth.token;
    if (token == null) return;

    if (packageController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Package name is required"),
          backgroundColor: Color(0xFFE53935),
        ),
      );
      return;
    }

    setState(() => uploading = true);

    final uri = isEdit
        ? Uri.parse("${ApiConfig.baseUrl}/api/admin/apps/${widget.app!.id}")
        : Uri.parse("${ApiConfig.baseUrl}/api/admin/apps");

    final request = http.MultipartRequest(isEdit ? "PUT" : "POST", uri);
    request.headers["Authorization"] = "Bearer $token";

    request.fields["name"] = nameController.text;
    request.fields["description"] = descController.text;
    request.fields["version"] = versionController.text;
    request.fields["category"] = selectedCategory;
    request.fields["size"] = sizeController.text;
    request.fields["developer"] = developerController.text;
    request.fields["rated_for"] = ratedForController.text;
    request.fields["package_name"] = packageController.text;
    if (!isEdit) {
      request.fields["version_code"] = "1";
    }

    if (iconFile != null) {
      if (kIsWeb) {
        request.files.add(
          http.MultipartFile.fromBytes(
            "icon",
            iconFile!.bytes!,
            filename: iconFile!.name,
          ),
        );
      } else {
        request.files.add(
          await http.MultipartFile.fromPath("icon", iconFile!.path!),
        );
      }
    }

    for (final file in screenshotFiles) {
      if (kIsWeb) {
        request.files.add(
          http.MultipartFile.fromBytes(
            "screenshots",
            file.bytes!,
            filename: file.name,
          ),
        );
      } else {
        request.files.add(
          await http.MultipartFile.fromPath("screenshots", file.path!),
        );
      }
    }

    if (apkFile != null) {
      if (kIsWeb) {
        request.files.add(
          http.MultipartFile.fromBytes(
            "apk",
            apkFile!.bytes!,
            filename: apkFile!.name,
          ),
        );
      } else {
        request.files.add(
          await http.MultipartFile.fromPath("apk", apkFile!.path!),
        );
      }
    }
    if (windowsFile != null) {
      if (kIsWeb) {
        request.files.add(
          http.MultipartFile.fromBytes(
            "windows",
            windowsFile!.bytes!,
            filename: windowsFile!.name,
          ),
        );
      } else {
        request.files.add(
          await http.MultipartFile.fromPath("windows", windowsFile!.path!),
        );
      }
    }

    if (linuxFile != null) {
      if (kIsWeb) {
        request.files.add(
          http.MultipartFile.fromBytes(
            "linux",
            linuxFile!.bytes!,
            filename: linuxFile!.name,
          ),
        );
      } else {
        request.files.add(
          await http.MultipartFile.fromPath("linux", linuxFile!.path!),
        );
      }
    }

    final response = await request.send();
    final responseBody = await response.stream.bytesToString();
    setState(() => uploading = false);

    if (!mounted) return;

    if (response.statusCode == 200 || response.statusCode == 201) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isEdit ? "App updated successfully" : "App uploaded successfully",
          ),
          backgroundColor: _purple,
        ),
      );
      Navigator.pop(context, true);
    } else {
      String message = "Operation failed";
      try {
        final data = json.decode(responseBody);
        message = data["error"] ?? message;
      } catch (_) {}
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: const Color(0xFFE53935),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;

    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F0),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF1A1A1A)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: _purple..withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(9),
              ),
              child: Icon(
                isEdit ? Icons.edit_rounded : Icons.cloud_upload_rounded,
                color: _purple,
                size: 18,
              ),
            ),
            const SizedBox(width: 10),
            Text(
              isEdit ? "Edit App" : "Upload App",
              style: const TextStyle(
                color: Color(0xFF1A1A1A),
                fontWeight: FontWeight.w700,
                fontSize: 18,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0xFFE8F5E9),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Text(
                "ADMIN",
                style: TextStyle(
                  color: _purple,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ],
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(height: 1, color: Colors.grey.shade100),
        ),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: FadeTransition(
            opacity: _fadeAnim,
            child: SlideTransition(
              position: _slideAnim,
              child: Container(
                width: width > 900 ? 780 : double.infinity,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      blurRadius: 30,
                      offset: const Offset(0, 10),
                      color: _purple..withValues(alpha: 0.07),
                    ),
                    BoxShadow(
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                      color: Colors.black..withValues(alpha: 0.05),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header stripe
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 28,
                        vertical: 22,
                      ),
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Color(0xFF6A1B9A), // main purple
                            Color(0xFF4A148C), // darker purple
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(24),
                          topRight: Radius.circular(24),
                        ),
                      ),
                      child: Text(
                        isEdit
                            ? "Update the app details below"
                            : "Fill in the app details to publish",
                        style: TextStyle(
                          color: Colors.white..withValues(alpha: 0.92),
                          fontSize: 13,
                        ),
                      ),
                    ),

                    Padding(
                      padding: const EdgeInsets.all(28),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // ── App Info section ────────────────────────
                          _sectionHeader(
                            Icons.info_outline_rounded,
                            "App Info",
                          ),
                          const SizedBox(height: 16),

                          _buildLabel("App Name"),
                          const SizedBox(height: 8),
                          _buildField(
                            nameController,
                            "provide a name for the app",
                          ),
                          const SizedBox(height: 18),

                          _buildLabel("Description"),
                          const SizedBox(height: 8),
                          _buildField(
                            descController,
                            "Describe what the app does...",
                            maxLines: 3,
                          ),
                          const SizedBox(height: 18),

                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _buildLabel("Version"),
                                    const SizedBox(height: 8),
                                    _buildField(
                                      versionController,
                                      "e.g. 1.0.0",
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _buildLabel("Size"),
                                    const SizedBox(height: 8),
                                    _buildField(
                                      sizeController,
                                      "enter size with unit",
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 18),

                          _buildLabel("Developer"),
                          const SizedBox(height: 8),
                          _buildField(developerController, "e.g. Acme Corp"),
                          const SizedBox(height: 18),
                          const SizedBox(height: 18),

                          _buildLabel("Category"),
                          const SizedBox(height: 8),

                          DropdownButtonFormField<String>(
                            value: selectedCategory,
                            decoration: InputDecoration(
                              filled: true,
                              fillColor: const Color(0xFFF5FAF6),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: Colors.grey.shade200,
                                ),
                              ),
                            ),
                            items:
                                [
                                  "Productivity",
                                  "Tools",
                                  "Education",
                                  "Utility",
                                  "Social",
                                ].map((category) {
                                  return DropdownMenuItem<String>(
                                    value: category,
                                    child: Text(category),
                                  );
                                }).toList(),
                            onChanged: (value) {
                              setState(() {
                                selectedCategory = value!;
                              });
                            },
                          ),

                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _buildLabel("Rated For"),
                                    const SizedBox(height: 8),
                                    _buildField(
                                      ratedForController,
                                      "e.g. 3+, 12+",
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _buildLabel("Package Name *"),
                                    const SizedBox(height: 8),
                                    _buildField(
                                      packageController,
                                      "enter the package name (unique identifier)",
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 32),
                          Divider(color: Colors.grey.shade100),
                          const SizedBox(height: 24),

                          // ── Assets section ───────────────────────────
                          _sectionHeader(Icons.perm_media_rounded, "Assets"),
                          const SizedBox(height: 16),

                          Row(
                            children: [
                              Expanded(
                                child: _assetButton(
                                  icon: Icons.image_rounded,
                                  label: "Pick Icon",
                                  onPressed: uploading ? null : pickIcon,
                                  selected: iconFile != null,
                                  selectedLabel: "Icon selected",
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: _assetButton(
                                  icon: Icons.photo_library_rounded,
                                  label: "Pick Screenshots",
                                  onPressed: uploading ? null : pickScreenshots,
                                  selected: screenshotFiles.isNotEmpty,
                                  selectedLabel:
                                      "${screenshotFiles.length} selected",
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          _assetButton(
                            icon: Icons.android_rounded,
                            label: "Pick APK File",
                            onPressed: uploading ? null : pickApk,
                            selected: apkFile != null,
                            selectedLabel: apkFile?.name ?? "APK selected",
                            fullWidth: true,
                          ),
                          const SizedBox(height: 14),

                          _assetButton(
                            icon: Icons.window,
                            label: "Pick Windows (.exe)",
                            onPressed: uploading ? null : pickWindowsFile,
                            selected: windowsFile != null,
                            selectedLabel:
                                windowsFile?.name ?? "Windows selected",
                            fullWidth: true,
                          ),

                          const SizedBox(height: 14),

                          _assetButton(
                            icon: Icons.code,
                            label: "Pick Linux (.deb/.appimage)",
                            onPressed: uploading ? null : pickLinuxFile,
                            selected: linuxFile != null,
                            selectedLabel: linuxFile?.name ?? "Linux selected",
                            fullWidth: true,
                          ),

                          const SizedBox(height: 32),

                          // ── Submit ───────────────────────────────────
                          SizedBox(
                            width: double.infinity,
                            height: 52,
                            child: ElevatedButton(
                              onPressed: uploading ? null : submit,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _purple,
                                foregroundColor: Colors.white,
                                disabledBackgroundColor: _purple.withValues(
                                  alpha: 0.5,
                                ),
                                elevation: 0,
                                shadowColor: Colors.transparent,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              child: uploading
                                  ? const SizedBox(
                                      height: 22,
                                      width: 22,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2.5,
                                        color: Colors.white,
                                      ),
                                    )
                                  : Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          isEdit
                                              ? Icons.save_rounded
                                              : Icons.cloud_upload_rounded,
                                          size: 20,
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          isEdit
                                              ? "Save Changes"
                                              : "Publish App",
                                          style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w700,
                                            letterSpacing: 0.3,
                                          ),
                                        ),
                                      ],
                                    ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _sectionHeader(IconData icon, String label) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            color: const Color(0xFF6A1B9A).withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: const Color(0xFF6A1B9A), size: 16),
        ),
        const SizedBox(width: 10),
        Text(
          label,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: Color(0xFF1A1A1A),
          ),
        ),
      ],
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

  Widget _buildField(
    TextEditingController ctrl,
    String hint, {
    int maxLines = 1,
  }) {
    return TextField(
      controller: ctrl,
      maxLines: maxLines,
      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
        filled: true,
        fillColor: const Color(0xFFF5FAF6),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 13,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade200),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade200),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF6A1B9A), width: 1.8),
        ),
      ),
    );
  }

  Widget _assetButton({
    required IconData icon,
    required String label,
    required VoidCallback? onPressed,
    required bool selected,
    required String selectedLabel,
    bool fullWidth = false,
  }) {
    return SizedBox(
      width: fullWidth ? double.infinity : null,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: selected
              ? const Color(0xFF6A1B9A)
              : const Color(0xFF424242),
          backgroundColor: selected
              ? const Color(0xFF6A1B9A).withValues(alpha: 0.05)
              : const Color(0xFFF5FAF6),
          side: BorderSide(
            color: selected
                ? const Color(0xFF6A1B9A).withValues(alpha: 0.5)
                : Colors.grey.shade200,
            width: selected ? 1.5 : 1,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              selected ? Icons.check_circle_rounded : icon,
              size: 18,
              color: selected ? const Color(0xFF6A1B9A) : Colors.grey.shade500,
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                selected ? selectedLabel : label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: selected
                      ? const Color(0xFF6A1B9A)
                      : Colors.grey.shade600,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
