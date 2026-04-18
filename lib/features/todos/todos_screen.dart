// lib/features/todos/todos_screen.dart

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../core/constants/route_constants.dart';
import '../../data/models/todo_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/todo_provider.dart';
import '../../shared/widgets/app_snackbar.dart';

class TodosScreen extends StatefulWidget {
  const TodosScreen({super.key});

  @override
  State<TodosScreen> createState() => _TodosScreenState();
}

class _TodosScreenState extends State<TodosScreen> {
  final _searchCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  String _search    = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadTodos());
    _scrollCtrl.addListener(_onScroll);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  String? get _token => context.read<AuthProvider>().authToken;

  Future<void> _loadTodos() async {
    final token = _token;
    if (token == null) return;
    await context.read<TodoProvider>()
        .loadTodos(authToken: token, search: _search);
  }

  void _onScroll() {
    if (!_scrollCtrl.hasClients) return;
    final max     = _scrollCtrl.position.maxScrollExtent;
    final current = _scrollCtrl.offset;
    if (current >= max - 200) {
      final provider = context.read<TodoProvider>();
      final token    = _token;
      if (token != null && !provider.isLoadingMore && provider.hasMore) {
        provider.loadMoreTodos(authToken: token, search: _search);
      }
    }
  }

  Future<void> _deleteTodo(TodoModel todo) async {
    final token = _token;
    if (token == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16)),
        title: const Text('Hapus Todo'),
        content: Text('Yakin ingin menghapus "${todo.title}"?'),
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
          .deleteTodo(authToken: token, todoId: todo.id);
      if (mounted) {
        AppSnackbar.show(context, result.message,
            isSuccess: result.success);
        if (result.success) {
          await _loadTodos();
          await context.read<TodoProvider>()
              .loadStats(authToken: token);
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
        title: const Text('Daftar Todo'),
        backgroundColor: colorScheme.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _loadTodos,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final result = await context.push(RouteConstants.todosAdd);
          if (result == true && mounted) {
            await _loadTodos();
            final token = _token;
            if (token != null) {
              context.read<TodoProvider>()
                  .loadStats(authToken: token);
            }
          }
        },
        icon: const Icon(Icons.add_rounded),
        label: const Text('Tambah'),
        backgroundColor: colorScheme.primary,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // ── Search & Filter ──────────────────────
          Container(
            color: colorScheme.primary,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              children: [
                // Search
                TextField(
                  controller: _searchCtrl,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Cari todo...',
                    hintStyle: TextStyle(
                        color: Colors.white.withOpacity(0.7)),
                    prefixIcon: Icon(Icons.search_rounded,
                        color: Colors.white.withOpacity(0.8)),
                    suffixIcon: _search.isNotEmpty
                        ? IconButton(
                      icon: const Icon(Icons.clear,
                          color: Colors.white70),
                      onPressed: () {
                        _searchCtrl.clear();
                        setState(() => _search = '');
                        _loadTodos();
                      },
                    )
                        : null,
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.15),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                  ),
                  onSubmitted: (v) {
                    setState(() => _search = v.trim());
                    _loadTodos();
                  },
                ),
                const SizedBox(height: 10),

                // Filter chips
                Consumer<TodoProvider>(
                  builder: (_, provider, __) =>
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            _FilterChipWidget(
                              label: 'Semua',
                              icon: Icons.list_alt_rounded,
                              selected:
                              provider.filter == TodoFilter.all,
                              onSelected: (_) =>
                                  provider.setFilter(TodoFilter.all),
                            ),
                            const SizedBox(width: 8),
                            _FilterChipWidget(
                              label: 'Selesai',
                              icon: Icons.check_circle_outline_rounded,
                              selected:
                              provider.filter == TodoFilter.done,
                              onSelected: (_) =>
                                  provider.setFilter(TodoFilter.done),
                            ),
                            const SizedBox(width: 8),
                            _FilterChipWidget(
                              label: 'Belum Selesai',
                              icon: Icons.radio_button_unchecked_rounded,
                              selected:
                              provider.filter == TodoFilter.undone,
                              onSelected: (_) =>
                                  provider.setFilter(TodoFilter.undone),
                            ),
                          ],
                        ),
                      ),
                ),
              ],
            ),
          ),

          // ── List ─────────────────────────────────
          Expanded(
            child: Consumer<TodoProvider>(
              builder: (_, provider, __) {
                if (provider.status == TodoStatus.loading) {
                  return const Center(
                      child: CircularProgressIndicator());
                }
                if (provider.status == TodoStatus.error) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.error_outline,
                            size: 64, color: Colors.red),
                        const SizedBox(height: 12),
                        Text(provider.errorMessage),
                        const SizedBox(height: 16),
                        FilledButton(
                            onPressed: _loadTodos,
                            child: const Text('Coba Lagi')),
                      ],
                    ),
                  );
                }

                final todos = provider.todos;
                if (todos.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.inbox_rounded,
                            size: 80,
                            color: colorScheme.outline),
                        const SizedBox(height: 16),
                        Text('Tidak ada todo',
                            style: theme.textTheme.titleMedium
                                ?.copyWith(
                              color: colorScheme.outline,
                            )),
                        const SizedBox(height: 8),
                        Text(
                          'Tambahkan todo baru dengan tombol di bawah',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.outline,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  );
                }

                return RefreshIndicator(
                  onRefresh: _loadTodos,
                  child: ListView.builder(
                    controller: _scrollCtrl,
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
                    itemCount: todos.length +
                        (provider.isLoadingMore ? 1 : 0),
                    itemBuilder: (_, i) {
                      if (i == todos.length) {
                        return const Padding(
                          padding: EdgeInsets.symmetric(vertical: 20),
                          child: Center(
                              child: CircularProgressIndicator()),
                        );
                      }
                      final todo = todos[i];
                      return _TodoCard(
                        todo: todo,
                        onTap: () async {
                          await context.push(
                              RouteConstants.todosDetail(todo.id));
                          _loadTodos();
                        },
                        onEdit: () async {
                          await context.push(
                              RouteConstants.todosEdit(todo.id));
                          _loadTodos();
                        },
                        onDelete: () => _deleteTodo(todo),
                        onToggle: () async {
                          final token = _token;
                          if (token == null) return;
                          await provider.updateTodo(
                            authToken: token,
                            todoId: todo.id,
                            title: todo.title,
                            description: todo.description,
                            isDone: !todo.isDone,
                          );
                          await _loadTodos();
                          await provider.loadStats(authToken: token);
                        },
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ── Widget filter chip ─────────────────────────────────────────────────────────

class _FilterChipWidget extends StatelessWidget {
  const _FilterChipWidget({
    required this.label, required this.icon,
    required this.selected, required this.onSelected,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final ValueChanged<bool> onSelected;

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      avatar: Icon(icon,
          size: 16,
          color: selected ? Colors.white : Colors.white70),
      label: Text(label,
          style: TextStyle(
            color: selected ? Colors.white : Colors.white70,
            fontWeight:
            selected ? FontWeight.bold : FontWeight.normal,
            fontSize: 13,
          )),
      selected: selected,
      onSelected: onSelected,
      selectedColor: Colors.white.withOpacity(0.3),
      backgroundColor: Colors.white.withOpacity(0.1),
      side: BorderSide(
          color: selected ? Colors.white : Colors.white38),
      checkmarkColor: Colors.white,
      showCheckmark: false,
    );
  }
}

// ── Todo card ──────────────────────────────────────────────────────────────────

class _TodoCard extends StatelessWidget {
  const _TodoCard({
    required this.todo, required this.onTap,
    required this.onEdit, required this.onDelete,
    required this.onToggle,
  });

  final TodoModel todo;
  final VoidCallback onTap, onEdit, onDelete, onToggle;

  @override
  Widget build(BuildContext context) {
    final theme       = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: todo.isDone
              ? Colors.green.withOpacity(0.3)
              : colorScheme.outlineVariant,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Tombol toggle status
              GestureDetector(
                onTap: onToggle,
                child: Container(
                  width: 28, height: 28,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: todo.isDone ? Colors.green : Colors.transparent,
                    border: Border.all(
                      color: todo.isDone
                          ? Colors.green : colorScheme.outline,
                      width: 2,
                    ),
                  ),
                  child: todo.isDone
                      ? const Icon(Icons.check, size: 16,
                      color: Colors.white)
                      : null,
                ),
              ),
              const SizedBox(width: 12),

              // Konten
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        if (todo.isDone)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            margin: const EdgeInsets.only(right: 8),
                            decoration: BoxDecoration(
                              color: Colors.green.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text('Selesai',
                                style: theme.textTheme.labelSmall
                                    ?.copyWith(
                                  color: Colors.green,
                                  fontWeight: FontWeight.bold,
                                )),
                          ),
                        Expanded(
                          child: Text(todo.title,
                              style: theme.textTheme.bodyLarge
                                  ?.copyWith(
                                fontWeight: FontWeight.w600,
                                decoration: todo.isDone
                                    ? TextDecoration.lineThrough
                                    : null,
                                decorationColor:
                                colorScheme.outline,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis),
                        ),
                      ],
                    ),
                    if (todo.description.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(todo.description,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 4),

              // Tombol aksi
              Column(
                children: [
                  IconButton(
                    icon: const Icon(Icons.edit_outlined, size: 20),
                    onPressed: onEdit,
                    color: colorScheme.primary,
                    constraints: const BoxConstraints(),
                    padding: const EdgeInsets.all(4),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline_rounded,
                        size: 20),
                    onPressed: onDelete,
                    color: Colors.red,
                    constraints: const BoxConstraints(),
                    padding: const EdgeInsets.all(4),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}