import 'package:calendar_app/plan/broadcast_plan.dart';
import 'package:calendar_app/plan/plan_repository.dart';
import 'package:flutter/material.dart';

/// 방송 계획 새로 만들기 (이름, minDate, maxDate 지정)
class PlanNewPage extends StatefulWidget {
  const PlanNewPage({super.key});

  @override
  State<PlanNewPage> createState() => _PlanNewPageState();
}

class _PlanNewPageState extends State<PlanNewPage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late DateTime _minDate;
  late DateTime _maxDate;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: '');
    final now = DateTime.now();
    _minDate = DateTime(now.year - 1, 1, 1);
    _maxDate = DateTime(now.year + 2, 12, 31);
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _pickMinDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _minDate,
      firstDate: DateTime(2000),
      lastDate: _maxDate.subtract(const Duration(days: 1)),
    );
    if (date != null && mounted) {
      setState(() {
        _minDate = DateTime(date.year, date.month, date.day);
        if (!_maxDate.isAfter(_minDate)) {
          _maxDate = _minDate.add(const Duration(days: 365));
        }
      });
    }
  }

  Future<void> _pickMaxDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _maxDate,
      firstDate: _minDate.add(const Duration(days: 1)),
      lastDate: DateTime(2100),
    );
    if (date != null && mounted) {
      setState(() {
        _maxDate = DateTime(date.year, date.month, date.day);
      });
    }
  }

  String _formatYMD(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('계획 이름을 입력해 주세요.')),
      );
      return;
    }
    if (!_maxDate.isAfter(_minDate)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('종료일은 시작일보다 뒤여야 합니다.')),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      final plan = BroadcastPlan(
        name: name,
        minDate: _minDate,
        maxDate: _maxDate,
      );
      final saved = await PlanRepository.instance.insert(plan);
      if (!mounted) return;
      Navigator.of(context).pop(saved);
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('저장 실패: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('방송 계획 새로 만들기'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: '계획 이름',
                border: OutlineInputBorder(),
                hintText: '예: 2025년 1월 방송',
              ),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return '이름을 입력해 주세요.';
                return null;
              },
              textCapitalization: TextCapitalization.sentences,
            ),
            const SizedBox(height: 24),
            const Text(
              '캘린더 표시 기간',
              style: TextStyle(fontWeight: FontWeight.w500, fontSize: 16),
            ),
            const SizedBox(height: 8),
            ListTile(
              title: const Text('시작일'),
              subtitle: Text(_formatYMD(_minDate)),
              trailing: const Icon(Icons.calendar_today),
              onTap: _pickMinDate,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
                side: BorderSide(color: Theme.of(context).dividerColor),
              ),
            ),
            const SizedBox(height: 8),
            ListTile(
              title: const Text('종료일'),
              subtitle: Text(_formatYMD(_maxDate)),
              trailing: const Icon(Icons.calendar_today),
              onTap: _pickMaxDate,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
                side: BorderSide(color: Theme.of(context).dividerColor),
              ),
            ),
            const SizedBox(height: 32),
            FilledButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(
                      height: 24,
                      width: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('만들기'),
            ),
          ],
        ),
      ),
    );
  }
}
