// lib/features/todos/todos_edit_screen.dart

import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../data/models/todo_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/todo_provider.dart';
import '../../shared/widgets/app_snackbar.dart';

class TodosEditScreen extends StatefulWidget {
  const TodosEditScreen({super.key, required this.todoId});
  final String todoId;

  @override
  State<TodosEditScreen> createState() => _TodosEditScreenState();
}

class _TodosEditScreenState extends State<TodosEditScreen> {
  final _formKey   = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _descCtrl  = TextEditingController();

  TodoModel? _todo;
  bool _loading        = true;
  bool _saving         = false;
  bool _isDone         = false;
  String _error        = '';

  File?      _imageFile;
  Uint8List? _imageBytes;
  String?    _imageName;

  @override
  void initState() {
    super.initState();
    _loadTodo();
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadTodo() async {
    setState(() { _loading = true; _error = ''; });
    final token = context.read<AuthProvider>().authToken;
    if (token == null) return;

    final result = await context.read<TodoProvider>().getTodoById(
      authToken: token, todoId: widget.todoId,
    );

    if (mounted) {
      setState(() {
        _loading = false;
        if (result.success && result.data != null) {
          _todo         = result.data;
          _titleCtrl.text = _todo!.title;
          _descCtrl.text  = _todo!.description;
          _isDone         = _todo!.isDone;
        } else {
          _error = result.message;
        }
      });
    }
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

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    final auth     = context.read<AuthProvider>();
    final token    = auth.authToken;
    final provider = context.read<TodoProvider>();
    if (token == null) return;

    // Update data todo
    final result = await provider.updateTodo(
      authToken:   token,
      todoId:      widget.todoId,
      title:       _titleCtrl.text.trim(),
      description: _descCtrl.text.trim(),
      isDone:      _isDone,
    );

    // Upload cover baru jika ada
    if (result.success && (_imageFile != null || _imageBytes != null)
        && mounted) {
      await provider.updateTodoCover(
        authToken:     token,
        todoId:        widget.todoId,
        imageFile:     _imageFile,
        imageBytes:    _imageBytes,
        imageFilename: _imageName ?? 'cover.jpg',
      );
    }

    if (mounted) {
      setState(() => _saving = false);
      AppSnackbar.show(context, result.message,
          isSuccess: result.success);
      if (result.success) {
        provider.loadStats(authToken: token);
        context.pop(true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme       = Theme.of(context);
    final colorScheme = theme.colorScheme;

    if (_loading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Edit Todo'),
          backgroundColor: colorScheme.primary,
          foregroundColor: Colors.white,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_error.isNotEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Edit Todo')),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline,
                  size: 64, color: Colors.red),
              const SizedBox(height: 12),
              Text(_error),
              const SizedBox(height: 16),
              FilledButton(
                  onPressed: _loadTodo,
                  child: const Text('Coba Lagi')),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Todo'),
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
              // Cover picker
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
                        : (_todo?.urlCover != null)
                        ? DecorationImage(
                        image: NetworkImage(
                            _todo!.urlCover!),
                        fit: BoxFit.cover)
                        : null,
                  ),
                  child: (_imageBytes == null &&
                      _imageFile == null &&
                      _todo?.urlCover == null)
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
                      Text('Tambah Gambar Cover',
                          style: theme.textTheme.bodySmall
                              ?.copyWith(
                            color: colorScheme.outline,
                          )),
                    ],
                  )
                      : Align(
                    alignment: Alignment.topRight,
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius:
                          BorderRadius.circular(8),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.edit, size: 14,
                                color: Colors.white),
                            SizedBox(width: 4),
                            Text('Ganti',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                )),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Judul
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

              // Deskripsi
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
              const SizedBox(height: 20),

              // Toggle status
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 4),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceVariant
                      .withOpacity(0.4),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: colorScheme.outlineVariant),
                ),
                child: SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Tandai Selesai'),
                  subtitle: Text(
                    _isDone ? 'Todo ini sudah selesai'
                        : 'Todo ini belum selesai',
                  ),
                  value: _isDone,
                  onChanged: (v) => setState(() => _isDone = v),
                  secondary: Icon(
                    _isDone
                        ? Icons.check_circle_rounded
                        : Icons.radio_button_unchecked_rounded,
                    color: _isDone ? Colors.green : colorScheme.outline,
                  ),
                ),
              ),
              const SizedBox(height: 32),

              // Tombol simpan
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _saving ? null : _save,
                  icon: _saving
                      ? const SizedBox(
                      width: 18, height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white))
                      : const Icon(Icons.save_rounded),
                  label: Text(
                      _saving ? 'Menyimpan...' : 'Simpan Perubahan'),
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