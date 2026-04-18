// lib/features/todos/todos_add_screen.dart

import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/todo_provider.dart';
import '../../shared/widgets/app_snackbar.dart';

class TodosAddScreen extends StatefulWidget {
  const TodosAddScreen({super.key});

  @override
  State<TodosAddScreen> createState() => _TodosAddScreenState();
}

class _TodosAddScreenState extends State<TodosAddScreen> {
  final _formKey  = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _descCtrl  = TextEditingController();
  bool _loading    = false;

  File?      _imageFile;
  Uint8List? _imageBytes;
  String?    _imageName;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
        source: ImageSource.gallery, imageQuality: 80);
    if (picked == null) return;

    if (kIsWeb) {
      final bytes = await picked.readAsBytes();
      setState(() {
        _imageBytes = bytes;
        _imageName  = picked.name;
        _imageFile  = null;
      });
    } else {
      setState(() {
        _imageFile  = File(picked.path);
        _imageBytes = null;
        _imageName  = picked.name;
      });
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);

    final auth  = context.read<AuthProvider>();
    final token = auth.authToken;
    if (token == null) return;

    final provider = context.read<TodoProvider>();
    final result   = await provider.createTodo(
      authToken:   token,
      title:       _titleCtrl.text.trim(),
      description: _descCtrl.text.trim(),
    );

    if (result.success && result.data != null && mounted) {
      if (_imageFile != null || _imageBytes != null) {
        await provider.updateTodoCover(
          authToken:     token,
          todoId:        result.data!,
          imageFile:     _imageFile,
          imageBytes:    _imageBytes,
          imageFilename: _imageName ?? 'cover.jpg',
        );
      }
    }

    if (mounted) {
      setState(() => _loading = false);
      AppSnackbar.show(context, result.message,
          isSuccess: result.success);
      if (result.success) context.pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme       = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tambah Todo'),
        backgroundColor: colorScheme.primary,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Gambar cover
              GestureDetector(
                onTap: _pickImage,
                child: Container(
                  width: double.infinity, height: 180,
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceVariant
                        .withOpacity(0.5),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                        color: colorScheme.outlineVariant),
                    image: _imageBytes != null
                        ? DecorationImage(
                        image: MemoryImage(_imageBytes!),
                        fit: BoxFit.cover)
                        : _imageFile != null
                        ? DecorationImage(
                        image: FileImage(_imageFile!),
                        fit: BoxFit.cover)
                        : null,
                  ),
                  child: (_imageBytes == null && _imageFile == null)
                      ? Column(
                    mainAxisAlignment:
                    MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.add_photo_alternate_outlined,
                        size: 48,
                        color: colorScheme.outline,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Tambah Gambar Cover (opsional)',
                        style: theme.textTheme.bodySmall
                            ?.copyWith(
                          color: colorScheme.outline,
                        ),
                      ),
                    ],
                  )
                      : Align(
                    alignment: Alignment.topRight,
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: CircleAvatar(
                        backgroundColor: Colors.black54,
                        radius: 16,
                        child: IconButton(
                          icon: const Icon(Icons.close,
                              size: 14),
                          color: Colors.white,
                          padding: EdgeInsets.zero,
                          onPressed: () => setState(() {
                            _imageFile  = null;
                            _imageBytes = null;
                            _imageName  = null;
                          }),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              Text('Judul Todo',
                  style: theme.textTheme.labelLarge
                      ?.copyWith(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              TextFormField(
                controller: _titleCtrl,
                decoration: _fieldDeco(context,
                    hint: 'Masukkan judul todo'),
                validator: (v) =>
                v?.trim().isEmpty == true
                    ? 'Judul tidak boleh kosong'
                    : null,
              ),
              const SizedBox(height: 20),

              Text('Deskripsi',
                  style: theme.textTheme.labelLarge
                      ?.copyWith(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              TextFormField(
                controller: _descCtrl,
                maxLines: 5,
                decoration: _fieldDeco(context,
                    hint: 'Masukkan deskripsi todo...'),
                validator: (v) =>
                v?.trim().isEmpty == true
                    ? 'Deskripsi tidak boleh kosong'
                    : null,
              ),
              const SizedBox(height: 32),

              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _loading ? null : _submit,
                  icon: _loading
                      ? const SizedBox(
                      width: 18, height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white))
                      : const Icon(Icons.add_task_rounded),
                  label: Text(
                      _loading ? 'Menyimpan...' : 'Tambah Todo'),
                  style: FilledButton.styleFrom(
                    padding:
                    const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

InputDecoration _fieldDeco(BuildContext context,
    {required String hint}) {
  final colorScheme = Theme.of(context).colorScheme;
  return InputDecoration(
    hintText: hint,
    filled: true,
    fillColor: colorScheme.surfaceVariant.withOpacity(0.4),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide.none,
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: colorScheme.outlineVariant),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: colorScheme.primary, width: 2),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: Colors.red),
    ),
  );
}