import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() => runApp(const TaskNestApp());

class TaskNestApp extends StatelessWidget {
  const TaskNestApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'TaskNest',
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.indigo,
      ),
      home: const TaskHomePage(),
    );
  }
}

class Task {
  Task({required this.title, this.isDone = false});

  final String title;
  bool isDone;

  Map<String, dynamic> toJson() => {
    'title': title,
    'isDone': isDone,
  };

  static Task fromJson(Map<String, dynamic> json) => Task(
    title: (json['title'] ?? '') as String,
    isDone: (json['isDone'] ?? false) as bool,
  );
}

enum TaskFilter { all, active, done }

class TaskHomePage extends StatefulWidget {
  const TaskHomePage({super.key});

  @override
  State<TaskHomePage> createState() => _TaskHomePageState();
}

class _TaskHomePageState extends State<TaskHomePage> {
  static const String _storageKey = 'task_nest_tasks_v1';

  final _controller = TextEditingController();
  final List<Task> _tasks = [];
  TaskFilter _filter = TaskFilter.all;

  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadTasks();
  }

  Future<void> _loadTasks() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_storageKey);

      if (raw == null || raw.trim().isEmpty) {
        setState(() => _isLoading = false);
        return;
      }

      final decoded = jsonDecode(raw);
      if (decoded is! List) {
        setState(() => _isLoading = false);
        return;
      }

      final loaded = decoded
          .whereType<Map>()
          .map((m) => Task.fromJson(Map<String, dynamic>.from(m)))
          .toList();

      setState(() {
        _tasks
          ..clear()
          ..addAll(loaded);
        _isLoading = false;
      });
    } catch (_) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _saveTasks() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = jsonEncode(_tasks.map((t) => t.toJson()).toList());
    await prefs.setString(_storageKey, raw);
  }

  Future<void> _addTask() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _tasks.insert(0, Task(title: text));
    });

    _controller.clear();
    FocusScope.of(context).unfocus();
    await _saveTasks();
  }

  Future<void> _toggleDone(Task task, bool? value) async {
    setState(() {
      task.isDone = value ?? false;
    });
    await _saveTasks();
  }

  Future<void> _deleteTask(Task task) async {
    setState(() {
      _tasks.remove(task);
    });
    await _saveTasks();
  }

  Future<void> _clearAll() async {
    setState(() {
      _tasks.clear();
    });
    await _saveTasks();
  }

  List<Task> get _visibleTasks {
    switch (_filter) {
      case TaskFilter.all:
        return _tasks;
      case TaskFilter.active:
        return _tasks.where((t) => !t.isDone).toList();
      case TaskFilter.done:
        return _tasks.where((t) => t.isDone).toList();
    }
  }

  int get _doneCount => _tasks.where((t) => t.isDone).length;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tasks = _visibleTasks;

    return Scaffold(
      appBar: AppBar(
        title: const Text('TaskNest'),
        centerTitle: true,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Center(child: Text('$_doneCount/${_tasks.length}')),
          ),
          PopupMenuButton<String>(
            onSelected: (value) async {
              if (value == 'clear') {
                await _clearAll();
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: 'clear',
                child: Text('Clear all'),
              ),
            ],
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    onSubmitted: (_) => _addTask(),
                    decoration: const InputDecoration(
                      labelText: 'Add a task',
                      hintText: 'e.g., Study Flutter for 20 minutes',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                FilledButton(
                  onPressed: _addTask,
                  child: const Text('Add'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: Wrap(
                spacing: 8,
                children: [
                  ChoiceChip(
                    label: const Text('All'),
                    selected: _filter == TaskFilter.all,
                    onSelected: (_) => setState(() => _filter = TaskFilter.all),
                  ),
                  ChoiceChip(
                    label: const Text('Active'),
                    selected: _filter == TaskFilter.active,
                    onSelected: (_) =>
                        setState(() => _filter = TaskFilter.active),
                  ),
                  ChoiceChip(
                    label: const Text('Done'),
                    selected: _filter == TaskFilter.done,
                    onSelected: (_) =>
                        setState(() => _filter = TaskFilter.done),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _tasks.isEmpty
                  ? const Center(
                child: Text(
                  'No tasks yet. Add your first one ✅',
                  style: TextStyle(fontSize: 16),
                ),
              )
                  : tasks.isEmpty
                  ? const Center(
                child: Text('Nothing here for this filter.'),
              )
                  : ListView.separated(
                itemCount: tasks.length,
                separatorBuilder: (_, __) =>
                const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final task = tasks[index];

                  return Dismissible(
                    key: ValueKey('${task.title}-$index'),
                    direction: DismissDirection.endToStart,
                    onDismissed: (_) => _deleteTask(task),
                    background: Container(
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.only(right: 16),
                      child: const Icon(Icons.delete),
                    ),
                    child: Card(
                      child: ListTile(
                        leading: Checkbox(
                          value: task.isDone,
                          onChanged: (v) => _toggleDone(task, v),
                        ),
                        title: Text(
                          task.title,
                          style: TextStyle(
                            decoration: task.isDone
                                ? TextDecoration.lineThrough
                                : null,
                          ),
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => _deleteTask(task),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
