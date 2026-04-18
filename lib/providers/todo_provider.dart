// lib/providers/todo_provider.dart

import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import '../data/models/api_response_model.dart';
import '../data/models/todo_model.dart';
import '../data/services/todo_repository.dart';

enum TodoFilter { all, done, undone }
enum TodoStatus { initial, loading, loaded, error }

class TodoProvider extends ChangeNotifier {
  TodoProvider({TodoRepository? repository})
      : _repository = repository ?? TodoRepository();

  final TodoRepository _repository;

  // ── State ─────────────────────────────────────
  TodoStatus  _status       = TodoStatus.initial;
  List<TodoModel> _todos    = [];
  String _errorMessage      = '';
  TodoFilter _filter        = TodoFilter.all;

  // Paginasi
  int  _currentPage  = 1;
  final int _perPage = 10;
  bool _hasMore      = true;
  bool _isLoadingMore = false;

  // Statistik (semua todo untuk Home)
  List<TodoModel> _allTodos    = [];
  bool            _statsLoading = false;

  // ── Getters ───────────────────────────────────
  TodoStatus  get status        => _status;
  String      get errorMessage  => _errorMessage;
  TodoFilter  get filter        => _filter;
  bool        get hasMore       => _hasMore;
  bool        get isLoadingMore => _isLoadingMore;
  bool        get statsLoading  => _statsLoading;

  List<TodoModel> get todos {
    switch (_filter) {
      case TodoFilter.done:   return _todos.where((t) => t.isDone).toList();
      case TodoFilter.undone: return _todos.where((t) => !t.isDone).toList();
      case TodoFilter.all:    return _todos;
    }
  }

  // Statistik
  int    get totalCount  => _allTodos.length;
  int    get doneCount   => _allTodos.where((t) => t.isDone).length;
  int    get undoneCount => _allTodos.where((t) => !t.isDone).length;
  double get donePercent => totalCount == 0 ? 0 : doneCount / totalCount;

  // ── Filter ────────────────────────────────────
  void setFilter(TodoFilter filter) {
    _filter = filter;
    notifyListeners();
  }

  // ── Load halaman pertama ──────────────────────
  Future<void> loadTodos({
    required String authToken,
    String search = '',
  }) async {
    _status      = TodoStatus.loading;
    _currentPage = 1;
    _hasMore     = true;
    _todos       = [];
    notifyListeners();

    final result = await _repository.getTodos(
      authToken: authToken,
      search: search,
      page: 1,
      perPage: _perPage,
    );

    if (result.success && result.data != null) {
      _todos   = result.data!;
      _hasMore = result.data!.length == _perPage;
      _status  = TodoStatus.loaded;
    } else {
      _errorMessage = result.message;
      _status       = TodoStatus.error;
    }
    notifyListeners();
  }

  // ── Load halaman berikutnya (infinite scroll) ─
  Future<void> loadMoreTodos({
    required String authToken,
    String search = '',
  }) async {
    if (_isLoadingMore || !_hasMore) return;

    _isLoadingMore = true;
    notifyListeners();

    _currentPage++;
    final result = await _repository.getTodos(
      authToken: authToken,
      search: search,
      page: _currentPage,
      perPage: _perPage,
    );

    if (result.success && result.data != null) {
      _todos.addAll(result.data!);
      _hasMore = result.data!.length == _perPage;
    } else {
      _currentPage--;
      _hasMore = false;
    }

    _isLoadingMore = false;
    notifyListeners();
  }

  // ── Load semua todo untuk statistik Home ──────
  Future<void> loadStats({required String authToken}) async {
    _statsLoading = true;
    notifyListeners();

    final result = await _repository.getAllTodos(authToken: authToken);
    if (result.success && result.data != null) {
      _allTodos = result.data!;
    }
    _statsLoading = false;
    notifyListeners();
  }

  // ── CRUD ──────────────────────────────────────
  Future<ApiResponse<String>> createTodo({
    required String authToken,
    required String title,
    required String description,
  }) async {
    return _repository.createTodo(
        authToken: authToken, title: title, description: description);
  }

  Future<ApiResponse<TodoModel>> getTodoById({
    required String authToken,
    required String todoId,
  }) async {
    return _repository.getTodoById(authToken: authToken, todoId: todoId);
  }

  Future<ApiResponse<void>> updateTodo({
    required String authToken,
    required String todoId,
    required String title,
    required String description,
    required bool isDone,
  }) async {
    return _repository.updateTodo(
      authToken: authToken,
      todoId: todoId,
      title: title,
      description: description,
      isDone: isDone,
    );
  }

  Future<ApiResponse<void>> updateTodoCover({
    required String authToken,
    required String todoId,
    File? imageFile,
    Uint8List? imageBytes,
    String imageFilename = 'cover.jpg',
  }) async {
    return _repository.updateTodoCover(
      authToken: authToken,
      todoId: todoId,
      imageFile: imageFile,
      imageBytes: imageBytes,
      imageFilename: imageFilename,
    );
  }

  Future<ApiResponse<void>> deleteTodo({
    required String authToken,
    required String todoId,
  }) async {
    return _repository.deleteTodo(authToken: authToken, todoId: todoId);
  }

  void clear() {
    _todos       = [];
    _allTodos    = [];
    _status      = TodoStatus.initial;
    _currentPage = 1;
    _hasMore     = true;
    notifyListeners();
  }
}