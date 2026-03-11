import 'package:calendar_app/creta/creta_book.dart';
import 'package:calendar_app/creta/creta_repository.dart';
import 'package:calendar_app/extensions/string_color_extension.dart';
import 'package:calendar_app/main.dart';
import 'package:flutter/material.dart';

class CretaPage extends StatefulWidget {
  const CretaPage({super.key});

  @override
  State<CretaPage> createState() => _CretaPageState();
}

class _CretaPageState extends State<CretaPage> {
  final List<CretaBook> _books = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadBooks();
  }

  Future<void> _loadBooks() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await CretaRepository.instance.getAll();
      logger.d('creta books: $list'.toCyan);
      if (mounted) {
        setState(() {
          _books.clear();
          _books.addAll(list);
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  Future<void> _createBook() async {
    final name = await _showBookDialog(name: '새 크레타북');
    if (name == null || name.isEmpty || !mounted) return;
    try {
      final book = await CretaRepository.instance.insert(
        CretaBook(name: name.trim()),
      );
      if (mounted) {
        setState(() => _books.insert(0, book));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('생성 실패: $e')));
      }
    }
  }

  Future<void> _editBook(CretaBook book) async {
    final name = await _showBookDialog(name: book.name);
    if (name == null || !mounted) return;
    if (name.isEmpty) return;
    try {
      final updated = book.copyWith(name: name.trim());
      await CretaRepository.instance.update(updated);
      if (mounted) {
        setState(() {
          final i = _books.indexWhere((b) => b.id == book.id);
          if (i >= 0) _books[i] = updated;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('수정 실패: $e')));
      }
    }
  }

  Future<void> _deleteBook(CretaBook book) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('크레타북 삭제'),
        content: Text('"${book.name}"을(를) 삭제하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('삭제'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await CretaRepository.instance.delete(book);
      if (mounted) {
        setState(() => _books.removeWhere((b) => b.id == book.id));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('삭제 실패: $e')));
      }
    }
  }

  Future<String?> _showBookDialog({String? name}) async {
    final controller = TextEditingController(text: name ?? '');
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(name == null ? '크레타북 만들기' : '크레타북 수정'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: '이름',
            hintText: '크레타북 이름',
          ),
          onSubmitted: (_) => Navigator.of(context).pop(controller.text),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text),
            child: const Text('저장'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('크레타북')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(_error!, textAlign: TextAlign.center),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: _loadBooks,
                    child: const Text('다시 시도'),
                  ),
                ],
              ),
            )
          : _books.isEmpty
          ? Center(
              child: Text(
                '크레타북이 없습니다.\n아래 + 버튼으로 추가하세요.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            )
          : ListView.builder(
              itemCount: _books.length,
              itemBuilder: (context, index) {
                final book = _books[index];
                return ListTile(
                  leading: const CircleAvatar(child: Icon(Icons.menu_book)),
                  title: Text(book.name),
                  subtitle: Text(
                    _formatDate(book.createdAt),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  onTap: () => _editBook(book),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () => _deleteBook(book),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _createBook,
        child: const Icon(Icons.add),
      ),
    );
  }

  String _formatDate(DateTime d) {
    return '${d.year}.${d.month.toString().padLeft(2, '0')}.${d.day.toString().padLeft(2, '0')}';
  }
}
