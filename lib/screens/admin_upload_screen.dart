import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:play_store_app/config/api_config.dart';
import '../providers/auth_provider.dart';
import '../models/app_model.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:convert';
import 'package:path/path.dart' as p;
import '../services/api_service.dart';
import '../theme/bock_colors.dart';

class AdminUploadScreen extends StatefulWidget {
  final AppModel? app;
  const AdminUploadScreen({super.key, this.app});

  @override
  State<AdminUploadScreen> createState() => _AdminUploadScreenState();
}

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
  final developerBioController = TextEditingController();
  final ratedForController = TextEditingController();
  final packageController = TextEditingController();
  String selectedCategory = 'Productivity';

  PlatformFile? iconFile;
  List<PlatformFile> screenshotFiles = [];
  final List<_FileEntry> _fileEntries = [];

  bool uploading = false;
  bool get isEdit => widget.app != null;

  late AnimationController _animCtrl;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

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

  static String _mimeType(String filename) {
    final ext = p.extension(filename).toLowerCase().replaceFirst('.', '');
    const map = {
      'apk': 'application/vnd.android.package-archive',
      'exe': 'application/x-msdownload',
      'msi': 'application/x-msi',
      'sh': 'application/x-sh',
      'deb': 'application/vnd.debian.binary-package',
      'rpm': 'application/x-rpm',
      'appimage': 'application/x-executable',
      'dmg': 'application/x-apple-diskimage',
      'zip': 'application/zip',
      'png': 'image/png',
      'jpg': 'image/jpeg',
      'jpeg': 'image/jpeg',
      'webp': 'image/webp',
    };
    return map[ext] ?? 'application/octet-stream';
  }

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _fadeAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
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
        _fileEntries.add(
          _FileEntry(
            type: type,
            label: f['label'] as String? ?? _defaultLabel(type),
          ),
        );
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
    developerBioController.dispose();
    ratedForController.dispose();
    packageController.dispose();
    _animCtrl.dispose();
    for (final e in _fileEntries) {
      e.dispose();
    }
    super.dispose();
  }

  Future<void> pickIcon() async {
    final r = await FilePicker.platform.pickFiles(
      type: FileType.image,
      withData: true,
    );
    if (r != null) setState(() => iconFile = r.files.first);
  }

  Future<void> pickScreenshots() async {
    final r = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: FileType.image,
      withData: true,
    );
    if (r != null && r.files.isNotEmpty)
      setState(() => screenshotFiles = r.files);
  }

  Future<void> _pickFileForEntry(int index) async {
    final r = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: [
        'apk',
        'exe',
        'msi',
        'sh',
        'deb',
        'rpm',
        'appimage',
        'dmg',
        'zip',
      ],
      withData: true,
    );
    if (r == null) return;
    final file = r.files.first;
    final type = _detectType(file.name);
    setState(() {
      _fileEntries[index].platformFile = file;
      _fileEntries[index].type = type;
      if (_fileEntries[index].labelCtrl.text.trim().isEmpty) {
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

  Future<void> submit() async {
    final auth = context.read<AuthProvider>();
    final token = auth.token;
    if (token == null) return;

    if (packageController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Package name is required'),
          backgroundColor: BockColors.error,
        ),
      );
      return;
    }

    setState(() => uploading = true);

    try {
      final uri = isEdit
          ? Uri.parse('${ApiConfig.baseUrl}/api/admin/apps/${widget.app!.id}')
          : Uri.parse('${ApiConfig.baseUrl}/api/admin/apps');

      String? iconUrl;
      if (iconFile != null) {
        final mime = _mimeType(iconFile!.name);
        final presigned = await ApiService.getPresignedUrl(
          fileName: iconFile!.name,
          fileType: mime,
          folder: 'icons',
          token: token,
        );
        iconUrl = await ApiService.uploadFileToS3(
          uploadUrl: presigned['uploadUrl'],
          fileUrl: presigned['fileUrl'],
          fileBytes: iconFile!.bytes!,
          fileType: mime,
        );
      }

      final screenshotUrls = <String>[];
      for (final f in screenshotFiles) {
        final mime = _mimeType(f.name);
        final presigned = await ApiService.getPresignedUrl(
          fileName: f.name,
          fileType: mime,
          folder: 'screenshots',
          token: token,
        );
        screenshotUrls.add(
          await ApiService.uploadFileToS3(
            uploadUrl: presigned['uploadUrl'],
            fileUrl: presigned['fileUrl'],
            fileBytes: f.bytes!,
            fileType: mime,
          ),
        );
      }

      final fileUrls = <String>[];
      final fileLabels = <String>[];
      final fileTypes = <String>[];

      for (final entry in _fileEntries) {
        // FIX: skip entries that have no new file picked (existing files in
        // edit mode) — sending an empty URL crashes the backend
        if (entry.platformFile == null) continue;

        final mime = _mimeType(entry.platformFile!.name);
        final presigned = await ApiService.getPresignedUrl(
          fileName: entry.platformFile!.name,
          fileType: mime,
          folder: 'apps',
          token: token,
        );
        final uploadedUrl = await ApiService.uploadFileToS3(
          uploadUrl: presigned['uploadUrl'],
          fileUrl: presigned['fileUrl'],
          fileBytes: entry.platformFile!.bytes!,
          fileType: mime,
        );

        fileUrls.add(uploadedUrl);
        fileLabels.add(entry.labelCtrl.text.trim());
        fileTypes.add(entry.type);
      }

      final body = <String, dynamic>{
        'name': nameController.text,
        'description': descController.text,
        'version': versionController.text,
        'category': selectedCategory,
        'size': sizeController.text,
        'developer': developerController.text,
        'rated_for': ratedForController.text,
        'package_name': packageController.text,
        'bio': developerBioController.text,
        if (!isEdit) 'version_code': '1',
        if (iconUrl != null) 'icon_url': iconUrl,
        if (screenshotUrls.isNotEmpty) 'screenshot_urls': screenshotUrls,
        if (fileUrls.isNotEmpty) 'file_urls': fileUrls,
        if (fileLabels.isNotEmpty) 'file_labels': fileLabels,
        if (fileTypes.isNotEmpty) 'file_types': fileTypes,
      };

      final headers = {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      };
      final response = isEdit
          ? await http.put(uri, headers: headers, body: jsonEncode(body))
          : await http.post(uri, headers: headers, body: jsonEncode(body));

      if (!mounted) return;

      if (response.statusCode == 200 || response.statusCode == 201) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isEdit
                  ? 'App updated successfully'
                  : 'App published successfully',
            ),
            backgroundColor: BockColors.purple,
          ),
        );
        Navigator.pop(context, true);
      } else {
        String message = 'Operation failed';
        try {
          message = json.decode(response.body)['error'] ?? message;
        } catch (_) {}
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message), backgroundColor: BockColors.error),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Upload error: $e'),
          backgroundColor: BockColors.error,
        ),
      );
    } finally {
      if (mounted) setState(() => uploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;

    return Scaffold(
      backgroundColor: BockColors.bgDark,
      appBar: AppBar(
        backgroundColor: BockColors.surfaceDark,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_rounded,
            color: BockColors.textPrimaryDark,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: BockColors.purple.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(9),
                border: Border.all(
                  color: BockColors.purple.withValues(alpha: 0.2),
                ),
              ),
              child: Icon(
                isEdit ? Icons.edit_rounded : Icons.cloud_upload_rounded,
                color: BockColors.purpleLight,
                size: 16,
              ),
            ),
            const SizedBox(width: 10),
            Text(
              isEdit ? 'Edit App' : 'Upload App',
              style: const TextStyle(
                color: BockColors.textPrimaryDark,
                fontWeight: FontWeight.w700,
                fontSize: 17,
              ),
            ),
          ],
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(height: 1, color: BockColors.borderDark),
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
                  color: BockColors.cardDark,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: BockColors.borderDark),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.35),
                      blurRadius: 30,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 16,
                      ),
                      decoration: BoxDecoration(
                        color: BockColors.purple.withValues(alpha: 0.12),
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(20),
                          topRight: Radius.circular(20),
                        ),
                        border: Border(
                          bottom: BorderSide(color: BockColors.borderDark),
                        ),
                      ),
                      child: Text(
                        isEdit
                            ? 'Update the app details below'
                            : 'Fill in the app details to publish',
                        style: const TextStyle(
                          color: BockColors.textSecondaryDark,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _sectionHeader(
                            Icons.info_outline_rounded,
                            'App Info',
                          ),
                          const SizedBox(height: 16),
                          _label('App Name'),
                          const SizedBox(height: 8),
                          _field(nameController, 'App name'),
                          const SizedBox(height: 16),
                          _label('Description'),
                          const SizedBox(height: 8),
                          _field(
                            descController,
                            'Describe what the app does...',
                            maxLines: 3,
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _label('Version'),
                                    const SizedBox(height: 8),
                                    _field(versionController, 'e.g. 1.0.0'),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _label('Size'),
                                    const SizedBox(height: 8),
                                    _field(sizeController, 'e.g. 24 MB'),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          _label('Developer'),
                          const SizedBox(height: 8),
                          _field(developerController, 'e.g. Acme Corp'),
                          const SizedBox(height: 16),
                          _label('Developer Bio'),
                          const SizedBox(height: 8),
                          _field(
                            developerBioController,
                            'Short bio...',
                            maxLines: 2,
                          ),
                          const SizedBox(height: 16),
                          _label('Category'),
                          const SizedBox(height: 8),
                          DropdownButtonFormField<String>(
                            initialValue: selectedCategory,
                            dropdownColor: BockColors.cardDark,
                            style: const TextStyle(
                              fontSize: 14,
                              color: BockColors.textPrimaryDark,
                            ),
                            decoration: InputDecoration(
                              filled: true,
                              fillColor: BockColors.surfaceDark,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: BockColors.borderDark,
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: BockColors.borderDark,
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(
                                  color: BockColors.purple,
                                  width: 1.8,
                                ),
                              ),
                            ),
                            items:
                                [
                                      'Productivity',
                                      'Tools',
                                      'Education',
                                      'Utility',
                                      'Social',
                                    ]
                                    .map(
                                      (c) => DropdownMenuItem(
                                        value: c,
                                        child: Text(c),
                                      ),
                                    )
                                    .toList(),
                            onChanged: (v) =>
                                setState(() => selectedCategory = v!),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _label('Rated For'),
                                    const SizedBox(height: 8),
                                    _field(ratedForController, 'e.g. 3+'),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _label('Package Name *'),
                                    const SizedBox(height: 8),
                                    _field(
                                      packageController,
                                      'Unique identifier',
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 28),
                          Divider(color: BockColors.borderDark),
                          const SizedBox(height: 20),

                          _sectionHeader(Icons.perm_media_rounded, 'Assets'),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: _assetBtn(
                                  icon: Icons.image_rounded,
                                  label: 'Pick Icon',
                                  onTap: uploading ? null : pickIcon,
                                  selected: iconFile != null,
                                  selectedLabel: 'Icon selected',
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _assetBtn(
                                  icon: Icons.photo_library_rounded,
                                  label: 'Screenshots',
                                  onTap: uploading ? null : pickScreenshots,
                                  selected: screenshotFiles.isNotEmpty,
                                  selectedLabel:
                                      '${screenshotFiles.length} selected',
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 28),
                          Divider(color: BockColors.borderDark),
                          const SizedBox(height: 20),

                          _sectionHeader(
                            Icons.folder_zip_outlined,
                            'Downloadable Files',
                          ),
                          const SizedBox(height: 16),

                          ..._fileEntries.asMap().entries.map(
                            (e) => _fileEntryCard(e.key, e.value),
                          ),

                          OutlinedButton.icon(
                            onPressed: uploading ? null : _addFileEntry,
                            icon: const Icon(Icons.add_rounded, size: 16),
                            label: const Text(
                              'Add File',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: BockColors.purpleLight,
                              side: BorderSide(
                                color: BockColors.purple.withValues(alpha: 0.4),
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              padding: const EdgeInsets.symmetric(
                                vertical: 12,
                                horizontal: 20,
                              ),
                            ),
                          ),

                          const SizedBox(height: 28),

                          SizedBox(
                            width: double.infinity,
                            height: 52,
                            child: ElevatedButton(
                              onPressed: uploading ? null : submit,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: BockColors.purple,
                                foregroundColor: Colors.white,
                                disabledBackgroundColor: BockColors.purple
                                    .withValues(alpha: 0.4),
                                elevation: 0,
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
                                              ? 'Save Changes'
                                              : 'Publish App',
                                          style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w700,
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

  Widget _fileEntryCard(int index, _FileEntry entry) {
    final hasFile = entry.platformFile != null;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: BockColors.surfaceDark,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: hasFile
              ? BockColors.purple.withValues(alpha: 0.3)
              : BockColors.borderDark,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: uploading ? null : () => _pickFileForEntry(index),
                  icon: Icon(
                    hasFile
                        ? Icons.check_circle_rounded
                        : Icons.attach_file_rounded,
                    size: 16,
                    color: hasFile
                        ? BockColors.purpleLight
                        : BockColors.textSecondaryDark,
                  ),
                  label: Text(
                    hasFile ? entry.platformFile!.name : 'Choose file',
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: hasFile
                          ? BockColors.purpleLight
                          : BockColors.textSecondaryDark,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    backgroundColor: hasFile
                        ? BockColors.purple.withValues(alpha: 0.08)
                        : Colors.transparent,
                    side: BorderSide(
                      color: hasFile
                          ? BockColors.purple.withValues(alpha: 0.4)
                          : BockColors.borderDark,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: const EdgeInsets.symmetric(
                      vertical: 10,
                      horizontal: 12,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: BockColors.purple.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: BockColors.purple.withValues(alpha: 0.2),
                  ),
                ),
                child: Text(
                  entry.type.toUpperCase(),
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: BockColors.purpleLight,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: uploading ? null : () => _removeFileEntry(index),
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: BockColors.error.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.close_rounded,
                    size: 16,
                    color: BockColors.error.withValues(alpha: 0.8),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          TextField(
            controller: entry.labelCtrl,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: BockColors.textPrimaryDark,
            ),
            decoration: InputDecoration(
              hintText: 'Label (e.g. Android APK)',
              hintStyle: TextStyle(
                color: BockColors.textSecondaryDark.withValues(alpha: 0.5),
                fontSize: 13,
              ),
              filled: true,
              fillColor: BockColors.cardDark,
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 10,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: BockColors.borderDark),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: BockColors.borderDark),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(
                  color: BockColors.purple,
                  width: 1.5,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionHeader(IconData icon, String label) => Row(
    children: [
      Container(
        padding: const EdgeInsets.all(7),
        decoration: BoxDecoration(
          color: BockColors.purple.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: BockColors.purple.withValues(alpha: 0.2)),
        ),
        child: Icon(icon, color: BockColors.purpleLight, size: 16),
      ),
      const SizedBox(width: 10),
      Text(
        label,
        style: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w700,
          color: BockColors.textPrimaryDark,
        ),
      ),
    ],
  );

  Widget _label(String text) => Text(
    text,
    style: const TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w600,
      color: BockColors.textSecondaryDark,
      letterSpacing: 0.3,
    ),
  );

  Widget _field(TextEditingController ctrl, String hint, {int maxLines = 1}) =>
      TextField(
        controller: ctrl,
        maxLines: maxLines,
        style: const TextStyle(fontSize: 14, color: BockColors.textPrimaryDark),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(
            color: BockColors.textSecondaryDark.withValues(alpha: 0.5),
            fontSize: 14,
          ),
          filled: true,
          fillColor: BockColors.surfaceDark,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 12,
          ),
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
        ),
      );

  Widget _assetBtn({
    required IconData icon,
    required String label,
    required VoidCallback? onTap,
    required bool selected,
    required String selectedLabel,
  }) {
    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        foregroundColor: selected
            ? BockColors.purpleLight
            : BockColors.textSecondaryDark,
        backgroundColor: selected
            ? BockColors.purple.withValues(alpha: 0.08)
            : Colors.transparent,
        side: BorderSide(
          color: selected
              ? BockColors.purple.withValues(alpha: 0.4)
              : BockColors.borderDark,
          width: selected ? 1.5 : 1,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            selected ? Icons.check_circle_rounded : icon,
            size: 18,
            color: selected
                ? BockColors.purpleLight
                : BockColors.textSecondaryDark,
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              selected ? selectedLabel : label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: selected
                    ? BockColors.purpleLight
                    : BockColors.textSecondaryDark,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
