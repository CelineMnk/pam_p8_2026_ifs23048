// lib/features/todos/todos_detail_screen.dart

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../core/constants/route_constants.dart';
import '../../data/models/todo_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/todo_provider.dart';
import '../../shared/widgets/app_snackbar.dart';

class TodosDetailScreen extends StatefulWidget {
  const TodosDetailScreen({super.key, required this.todoId});
  final String todoId;

  @override
  State<TodosDetailScreen> createState() => _TodosDetailScreenState();
}

class _TodosDetailScreenState extends State<TodosDetailScreen> {
  TodoModel? _todo;
  bool _loading = true;
  String _error = '';

  @override
  void initState() {
    super.initState();
    _loadTodo();
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
        if (result.success) { _todo = result.data; }
        else { _error = result.message; }
      });
    }
  }

  Future<void> _toggleDone() async {
    final todo  = _todo;
    final token = context.read<AuthProvider>().authToken;
    if (todo == null || token == null) return;

    final result = await context.read<TodoProvider>().updateTodo(
      authToken:   token,
      todoId:      todo.id,
      title:       todo.title,
      description: todo.description,
      isDone:      !todo.isDone,
    );

    if (mounted) {
      AppSnackbar.show(context, result.message,
          isSuccess: result.success);
      if (result.success) {
        await _loadTodo();
        context.read<TodoProvider>().loadStats(authToken: token);
      }
    }
  }

  Future<void> _delete() async {
    final token = context.read<AuthProvider>().authToken;
    if (token == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16)),
        title: const Text('Hapus Todo'),
        content: const Text('Yakin ingin menghapus todo ini?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final result = await context.read<TodoProvider>()
          .deleteTodo(authToken: token, todoId: widget.todoId);
      if (mounted) {
        AppSnackbar.show(context, result.message,
            isSuccess: result.success);
        if (result.success) {
          context.read<TodoProvider>().loadStats(authToken: token);
          context.pop();
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme       = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        title: const Text('Detail Todo'),
        backgroundColor: colorScheme.primary,
        foregroundColor: Colors.white,
        actions: [
          if (_todo != null) ...[
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              onPressed: () async {
                await context.push(
                    RouteConstants.todosEdit(widget.todoId));
                _loadTodo();
              },
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline_rounded),
              onPressed: _delete,
            ),
          ],
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error.isNotEmpty
          ? Center(
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
      )
          : _buildContent(theme, colorScheme),
    );
  }

  Widget _buildContent(ThemeData theme, ColorScheme colorScheme) {
    final todo = _todo!;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Cover image
          if (todo.urlCover != null)
            Image.network(
              todo.urlCover!,
              width: double.infinity,
              height: 220,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                height: 220,
                color: colorScheme.surfaceVariant,
                child: const Icon(Icons.image_not_supported,
                    size: 64),
              ),
            )
          else
            Container(
              height: 120,
              width: double.infinity,
              color: colorScheme.primaryContainer.withOpacity(0.3),
              child: Icon(Icons.task_alt_rounded,
                  size: 64, color: colorScheme.primary),
            ),

          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Status badge
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: todo.isDone
                        ? Colors.green.withOpacity(0.12)
                        : Colors.orange.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: todo.isDone
                          ? Colors.green.withOpacity(0.4)
                          : Colors.orange.withOpacity(0.4),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        todo.isDone
                            ? Icons.check_circle_rounded
                            : Icons.radio_button_unchecked_rounded,
                        size: 16,
                        color: todo.isDone
                            ? Colors.green : Colors.orange,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        todo.isDone ? 'Selesai' : 'Belum Selesai',
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: todo.isDone
                              ? Colors.green : Colors.orange,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Judul
                Text(todo.title,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    )),
                const SizedBox(height: 12),

                // Deskripsi
                Text('Deskripsi',
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    )),
                const SizedBox(height: 8),
                Text(todo.description,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      height: 1.6,
                      color: colorScheme.onSurface,
                    )),
                const SizedBox(height: 24),

                // Info
                _InfoRow(
                    icon: Icons.calendar_today_outlined,
                    label: 'Dibuat',
                    value: todo.createdAt),
                const SizedBox(height: 8),
                _InfoRow(
                    icon: Icons.update_rounded,
                    label: 'Diperbarui',
                    value: todo.updatedAt),
                const SizedBox(height: 32),

                // Tombol toggle
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _toggleDone,
                    icon: Icon(todo.isDone
                        ? Icons.undo_rounded
                        : Icons.check_rounded),
                    label: Text(todo.isDone
                        ? 'Tandai Belum Selesai'
                        : 'Tandai Selesai'),
                    style: FilledButton.styleFrom(
                      backgroundColor: todo.isDone
                          ? Colors.orange : Colors.green,
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
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });
  final IconData icon;
  final String label, value;

  @override
  Widget build(BuildContext context) {
    final theme       = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Row(
      children: [
        Icon(icon, size: 18, color: colorScheme.outline),
        const SizedBox(width: 8),
        Text('$label: ',
            style: theme.textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            )),
        Expanded(
          child: Text(value,
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              )),
        ),
      ],
    );
  }
}