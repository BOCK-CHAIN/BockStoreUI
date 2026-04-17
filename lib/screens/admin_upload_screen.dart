import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:play_store_app/config/api_config.dart';
import '../providers/auth_provider.dart';
import '../models/app_model.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:convert';
import 'package:path/path.dart' as p;

class AdminUploadScreen extends StatefulWidget {
  final AppModel? app;

  const AdminUploadScreen({super.key, this.app});

  @override
  State<AdminUploadScreen> createState() => _AdminUploadScreenState();
}

// Holds one file entry (picked file + editable metadata)
class _FileEntry {
  PlatformFile? platformFile;
  String type;
  TextEditingController labelCtrl;

  _FileEntry({this.platformFile, required this.type, required String label})
      : labelCtrl = TextEditingController(text: label);

  void dispose() => labelCtrl.dispose();
}

class _AdminUploadScreenState extends State<AdminUploadScreen>
    with SingleTickerProviderStateMixin {
  final nameController = TextEditingController();
  final descController = TextEditingController();
  final versionController = TextEditingController();
  final sizeController = TextEditingController();
  final developerController = TextEditingController();
  final developerBioController = TextEditingController(); // ← NEW
  final ratedForController = TextEditingController();
  final packageController = TextEditingController();
  String selectedCategory = "Productivity";

  PlatformFile? iconFile;
  List<PlatformFile> screenshotFiles = [];

  final List<_FileEntry> _fileEntries = [];

  bool uploading = false;
  bool get isEdit => widget.app != null;

  static const _purple = Color(0xFF6A1B9A);

  late AnimationController _animCtrl;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  // ── Helpers ────────────────────────────────────────────────────────────────

  static String _detectType(String filename) {
    final ext = p.extension(filename).toLowerCase().replaceFirst('.', '');
    const map = {
      'apk': 'apk',
      'exe': 'exe',
      'msi': 'exe',
      'sh': 'sh',
      'deb': 'deb',
      'rpm': 'rpm',
      'appimage': 'appimage',
      'dmg': 'dmg',
      'zip': 'zip',
    };
    return map[ext] ?? 'other';
  }

  static String _defaultLabel(String type) {
    const map = {
      'apk': 'Android APK',
      'exe': 'Windows Installer',
      'sh': 'Linux Shell Script',
      'deb': 'Linux Package (.deb)',
      'rpm': 'Linux Package (.rpm)',
      'appimage': 'Linux AppImage',
      'dmg': 'macOS Installer',
      'zip': 'ZIP Archive',
    };
    return map[type] ?? 'Download';
  }

  // ── Lifecycle ──────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600));
    _fadeAnim =
        CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.05),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut));
    _animCtrl.forward();

    if (isEdit) {
      final app = widget.app!;
      nameController.text = app.name;
      descController.text = app.description;
      versionController.text = app.version ?? '';
      sizeController.text = app.size ?? '';
      developerController.text = app.developer ?? '';
      ratedForController.text = app.ratedFor ?? '';
      packageController.text = app.packageName;

      for (final f in app.files) {
        final type = f['type'] as String? ?? 'other';
        _fileEntries.add(_FileEntry(
          type: type,
          label: f['label'] as String? ?? _defaultLabel(type),
        ));
      }
    }
  }

  @override
  void dispose() {
    nameController.dispose();
    descController.dispose();
    versionController.dispose();
    sizeController.dispose();
    developerController.dispose();
    developerBioController.dispose(); // ← NEW
    ratedForController.dispose();
    packageController.dispose();
    _animCtrl.dispose();
    for (final e in _fileEntries) {
      e.dispose();
    }
    super.dispose();
  }

  // ── File picking ───────────────────────────────────────────────────────────

  Future<void> pickIcon() async {
    final r = await FilePicker.platform
        .pickFiles(type: FileType.image, withData: true);
    if (r != null) setState(() => iconFile = r.files.first);
  }

  Future<void> pickScreenshots() async {
    final r = await FilePicker.platform.pickFiles(
        allowMultiple: true, type: FileType.image, withData: true);
    if (r != null && r.files.isNotEmpty) {
      setState(() => screenshotFiles = r.files);
    }
  }

  Future<void> _pickFileForEntry(int index) async {
    final r = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: [
        'apk', 'exe', 'msi', 'sh', 'deb', 'rpm', 'appimage', 'dmg', 'zip',
      ],
      withData: true,
    );
    if (r == null) return;
    final file = r.files.first;
    final type = _detectType(file.name);
    setState(() {
      _fileEntries[index].platformFile = file;
      _fileEntries[index].type = type;
      final label = _fileEntries[index].labelCtrl.text.trim();
      if (label.isEmpty || label == 'Download') {
        _fileEntries[index].labelCtrl.text = _defaultLabel(type);
      }
    });
  }

  void _addFileEntry() =>
      setState(() => _fileEntries.add(_FileEntry(type: 'other', label: '')));

  void _removeFileEntry(int index) {
    _fileEntries[index].dispose();
    setState(() => _fileEntries.removeAt(index));
  }

  // ── Submit ─────────────────────────────────────────────────────────────────

  Future<void> submit() async {
    final auth = context.read<AuthProvider>();
    final token = auth.token;
    if (token == null) return;

    if (packageController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text("Package name is required"),
        backgroundColor: Color(0xFFE53935),
      ));
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
    request.fields["bio"] = developerBioController.text; // ← NEW
    if (!isEdit) request.fields["version_code"] = "1";

    // Icon
    if (iconFile != null) {
      if (kIsWeb) {
        request.files.add(http.MultipartFile.fromBytes(
            "icon", iconFile!.bytes!, filename: iconFile!.name));
      } else {
        request.files
            .add(await http.MultipartFile.fromPath("icon", iconFile!.path!));
      }
    }

    // Screenshots
    for (final f in screenshotFiles) {
      if (kIsWeb) {
        request.files.add(http.MultipartFile.fromBytes(
            "screenshots", f.bytes!, filename: f.name));
      } else {
        request.files.add(
            await http.MultipartFile.fromPath("screenshots", f.path!));
      }
    }

    // Dynamic files
    for (int i = 0; i < _fileEntries.length; i++) {
      final entry = _fileEntries[i];
      request.fields["file_labels[$i]"] = entry.labelCtrl.text.trim();
      request.fields["file_types[$i]"] = entry.type;

      if (entry.platformFile != null) {
        if (kIsWeb) {
          request.files.add(http.MultipartFile.fromBytes(
              "files", entry.platformFile!.bytes!,
              filename: entry.platformFile!.name));
        } else {
          request.files.add(await http.MultipartFile.fromPath(
              "files", entry.platformFile!.path!));
        }
      }
    }

    final response = await request.send();
    final responseBody = await response.stream.bytesToString();
    setState(() => uploading = false);

    if (!mounted) return;

    if (response.statusCode == 200 || response.statusCode == 201) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(isEdit
            ? "App updated successfully"
            : "App uploaded successfully"),
        backgroundColor: _purple,
      ));
      Navigator.pop(context, true);
    } else {
      String message = "Operation failed";
      try {
        final data = json.decode(responseBody);
        message = data["error"] ?? message;
      } catch (_) {}
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(message),
        backgroundColor: const Color(0xFFE53935),
      ));
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────────

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
          icon: const Icon(Icons.arrow_back_rounded,
              color: Color(0xFF1A1A1A)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: _purple.withValues(alpha: 0.10),
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
                fontSize: 18),
          ),
          const SizedBox(width: 8),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: const Color(0xFFE8F5E9),
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Text("ADMIN",
                style: TextStyle(
                    color: _purple,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5)),
          ),
        ]),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(height: 1, color: Colors.grey.shade100),
        ),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding:
              const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
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
                        color: _purple.withValues(alpha: 0.07)),
                    BoxShadow(
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                        color: Colors.black.withValues(alpha: 0.05)),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header stripe
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 28, vertical: 22),
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Color(0xFF6A1B9A), Color(0xFF4A148C)],
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
                            color: Colors.white.withValues(alpha: 0.92),
                            fontSize: 13),
                      ),
                    ),

                    Padding(
                      padding: const EdgeInsets.all(28),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // ── App Info ──────────────────────────────
                          _sectionHeader(
                              Icons.info_outline_rounded, "App Info"),
                          const SizedBox(height: 16),
                          _buildLabel("App Name"),
                          const SizedBox(height: 8),
                          _buildField(nameController,
                              "Provide a name for the app"),
                          const SizedBox(height: 18),
                          _buildLabel("Description"),
                          const SizedBox(height: 8),
                          _buildField(descController,
                              "Describe what the app does...",
                              maxLines: 3),
                          const SizedBox(height: 18),
                          Row(children: [
                            Expanded(
                              child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    _buildLabel("Version"),
                                    const SizedBox(height: 8),
                                    _buildField(
                                        versionController, "e.g. 1.0.0"),
                                  ]),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    _buildLabel("Size"),
                                    const SizedBox(height: 8),
                                    _buildField(
                                        sizeController, "e.g. 24 MB"),
                                  ]),
                            ),
                          ]),
                          const SizedBox(height: 18),
                          _buildLabel("Developer"),
                          const SizedBox(height: 8),
                          _buildField(
                              developerController, "e.g. Acme Corp"),

                          // ── Developer Bio (NEW) ───────────────────
                          const SizedBox(height: 18),
                          _buildLabel("Developer Bio"),
                          const SizedBox(height: 8),
                          _buildField(
                            developerBioController,
                            "Short bio about the developer...",
                            maxLines: 3,
                          ),

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
                                    color: Colors.grey.shade200),
                              ),
                            ),
                            items: [
                              "Productivity",
                              "Tools",
                              "Education",
                              "Utility",
                              "Social"
                            ]
                                .map((c) => DropdownMenuItem(
                                    value: c, child: Text(c)))
                                .toList(),
                            onChanged: (v) =>
                                setState(() => selectedCategory = v!),
                          ),
                          const SizedBox(height: 18),
                          Row(children: [
                            Expanded(
                              child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    _buildLabel("Rated For"),
                                    const SizedBox(height: 8),
                                    _buildField(
                                        ratedForController, "e.g. 3+, 12+"),
                                  ]),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    _buildLabel("Package Name *"),
                                    const SizedBox(height: 8),
                                    _buildField(packageController,
                                        "Unique identifier"),
                                  ]),
                            ),
                          ]),

                          const SizedBox(height: 32),
                          Divider(color: Colors.grey.shade100),
                          const SizedBox(height: 24),

                          // ── Assets ────────────────────────────────
                          _sectionHeader(
                              Icons.perm_media_rounded, "Assets"),
                          const SizedBox(height: 16),
                          Row(children: [
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
                                onPressed:
                                    uploading ? null : pickScreenshots,
                                selected: screenshotFiles.isNotEmpty,
                                selectedLabel:
                                    "${screenshotFiles.length} selected",
                              ),
                            ),
                          ]),

                          const SizedBox(height: 32),
                          Divider(color: Colors.grey.shade100),
                          const SizedBox(height: 24),

                          // ── Downloadable Files ────────────────────
                          _sectionHeader(Icons.folder_zip_outlined,
                              "Downloadable Files"),
                          const SizedBox(height: 16),

                          ..._fileEntries.asMap().entries.map(
                              (e) => _buildFileEntryCard(e.key, e.value)),

                          OutlinedButton.icon(
                            onPressed: uploading ? null : _addFileEntry,
                            icon: const Icon(Icons.add_rounded, size: 18),
                            label: const Text("Add File",
                                style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600)),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: _purple,
                              side: BorderSide(
                                  color: _purple.withValues(alpha: 0.4)),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                              padding: const EdgeInsets.symmetric(
                                  vertical: 12, horizontal: 20),
                            ),
                          ),

                          const SizedBox(height: 32),

                          // ── Submit ────────────────────────────────
                          SizedBox(
                            width: double.infinity,
                            height: 52,
                            child: ElevatedButton(
                              onPressed: uploading ? null : submit,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _purple,
                                foregroundColor: Colors.white,
                                disabledBackgroundColor:
                                    _purple.withValues(alpha: 0.5),
                                elevation: 0,
                                shadowColor: Colors.transparent,
                                shape: RoundedRectangleBorder(
                                    borderRadius:
                                        BorderRadius.circular(14)),
                              ),
                              child: uploading
                                  ? const SizedBox(
                                      height: 22,
                                      width: 22,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2.5,
                                          color: Colors.white),
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
                                              letterSpacing: 0.3),
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

  // ── File entry card ────────────────────────────────────────────────────────

  Widget _buildFileEntryCard(int index, _FileEntry entry) {
    final hasFile = entry.platformFile != null;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF5FAF6),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: hasFile
              ? _purple.withValues(alpha: 0.25)
              : Colors.grey.shade200,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed:
                    uploading ? null : () => _pickFileForEntry(index),
                icon: Icon(
                  hasFile
                      ? Icons.check_circle_rounded
                      : Icons.attach_file_rounded,
                  size: 16,
                  color: hasFile ? _purple : Colors.grey.shade500,
                ),
                label: Text(
                  hasFile ? (entry.platformFile!.name) : "Choose file",
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: hasFile ? _purple : Colors.grey.shade600,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  backgroundColor: hasFile
                      ? _purple.withValues(alpha: 0.05)
                      : Colors.white,
                  side: BorderSide(
                    color: hasFile
                        ? _purple.withValues(alpha: 0.4)
                        : Colors.grey.shade300,
                  ),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(
                      vertical: 10, horizontal: 12),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: _purple.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                entry.type.toUpperCase(),
                style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: _purple),
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: uploading ? null : () => _removeFileEntry(index),
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.close_rounded,
                    size: 16, color: Colors.red.shade400),
              ),
            ),
          ]),
          const SizedBox(height: 10),
          TextField(
            controller: entry.labelCtrl,
            style: const TextStyle(
                fontSize: 13, fontWeight: FontWeight.w500),
            decoration: InputDecoration(
              hintText: "Label  (e.g. Android APK, Windows Installer)",
              hintStyle: TextStyle(
                  color: Colors.grey.shade400, fontSize: 13),
              filled: true,
              fillColor: Colors.white,
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 10),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: Colors.grey.shade200),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: Colors.grey.shade200),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide:
                    const BorderSide(color: _purple, width: 1.5),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Shared UI helpers ──────────────────────────────────────────────────────

  Widget _sectionHeader(IconData icon, String label) {
    return Row(children: [
      Container(
        padding: const EdgeInsets.all(7),
        decoration: BoxDecoration(
          color: const Color(0xFF6A1B9A).withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: const Color(0xFF6A1B9A), size: 16),
      ),
      const SizedBox(width: 10),
      Text(label,
          style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1A1A1A))),
    ]);
  }

  Widget _buildLabel(String text) {
    return Text(text,
        style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Color(0xFF424242),
            letterSpacing: 0.2));
  }

  Widget _buildField(TextEditingController ctrl, String hint,
      {int maxLines = 1}) {
    return TextField(
      controller: ctrl,
      maxLines: maxLines,
      style:
          const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle:
            TextStyle(color: Colors.grey.shade400, fontSize: 14),
        filled: true,
        fillColor: const Color(0xFFF5FAF6),
        contentPadding: const EdgeInsets.symmetric(
            horizontal: 16, vertical: 13),
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
          borderSide: const BorderSide(
              color: Color(0xFF6A1B9A), width: 1.8),
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
              borderRadius: BorderRadius.circular(12)),
          padding: const EdgeInsets.symmetric(
              vertical: 14, horizontal: 16),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              selected ? Icons.check_circle_rounded : icon,
              size: 18,
              color: selected
                  ? const Color(0xFF6A1B9A)
                  : Colors.grey.shade500,
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