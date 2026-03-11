import 'package:calendar_app/plan/broadcast_plan.dart';
import 'package:flutter/material.dart';

/// 방송 계획 편집 (이름, minDate, maxDate). 저장 시 수정된 계획 반환, 취소 시 null.
Future<BroadcastPlan?> showPlanEditDialog(
  BuildContext context, {
  required BroadcastPlan plan,
}) async {
  return showDialog<BroadcastPlan>(
    context: context,
    builder: (context) => _PlanEditDialog(plan: plan),
  );
}

class _PlanEditDialog extends StatefulWidget {
  const _PlanEditDialog({required this.plan});

  final BroadcastPlan plan;

  @override
  State<_PlanEditDialog> createState() => _PlanEditDialogState();
}

class _PlanEditDialogState extends State<_PlanEditDialog> {
  late final TextEditingController _nameController;
  late DateTime _minDate;
  late DateTime _maxDate;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.plan.name);
    _minDate = widget.plan.minDate;
    _maxDate = widget.plan.maxDate;
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

  void _save() {
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
    final updated = widget.plan.copyWith(
      name: name,
      minDate: _minDate,
      maxDate: _maxDate,
    );
    Navigator.of(context).pop(updated);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('방송 계획 편집'),
      content: SingleChildScrollView(
        child: ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 280, maxWidth: 400),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: '계획 이름',
                  border: OutlineInputBorder(),
                  hintText: '예: 2025년 1월 방송',
                ),
                textCapitalization: TextCapitalization.sentences,
              ),
              const SizedBox(height: 20),
              const Text(
                '캘린더 표시 기간',
                style: TextStyle(
                  fontWeight: FontWeight.w500,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: _pickMinDate,
                icon: const Icon(Icons.calendar_today, size: 18),
                label: Text(_formatYMD(_minDate)),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: _pickMaxDate,
                icon: const Icon(Icons.calendar_today, size: 18),
                label: Text(_formatYMD(_maxDate)),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('취소'),
        ),
        FilledButton(
          onPressed: _save,
          child: const Text('저장'),
        ),
      ],
    );
  }
}
