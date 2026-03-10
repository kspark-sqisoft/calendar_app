import 'package:calendar_app/event_data_source.dart';
import 'package:flutter/material.dart';

/// 새 이벤트 생성/편집용 다이얼로그.
/// [existingEvent]가 있으면 수정 모드(기본값 채움), 없으면 [initialFrom]/[initialTo]로 새 이벤트.
Future<Event?> showEventEditDialog({
  required BuildContext context,
  DateTime? initialFrom,
  DateTime? initialTo,
  Event? existingEvent,
}) {
  assert(
    existingEvent != null || (initialFrom != null && initialTo != null),
    'existingEvent 또는 initialFrom/initialTo 필요',
  );
  return showDialog<Event>(
    context: context,
    builder: (context) => _EventEditDialog(
      initialFrom: initialFrom,
      initialTo: initialTo,
      existingEvent: existingEvent,
    ),
  );
}

class _EventEditDialog extends StatefulWidget {
  final DateTime? initialFrom;
  final DateTime? initialTo;
  final Event? existingEvent;

  const _EventEditDialog({
    this.initialFrom,
    this.initialTo,
    this.existingEvent,
  });

  @override
  State<_EventEditDialog> createState() => _EventEditDialogState();
}

class _EventEditDialogState extends State<_EventEditDialog> {
  late final TextEditingController _nameController;
  late DateTime _from;
  late DateTime _to;
  late Color _background;
  late bool _isAllDay;
  String? _recurrenceRule;

  static const List<Color> _colorOptions = [
    Colors.blue,
    Colors.green,
    Colors.amber,
    Colors.red,
    Colors.purple,
    Colors.orange,
    Colors.teal,
    Colors.indigo,
  ];

  static const Map<String?, String> _recurrenceLabels = {
    null: '한 번만',
    'FREQ=DAILY': '매일',
    'FREQ=WEEKLY': '매주',
    'FREQ=MONTHLY': '매월',
  };

  @override
  void initState() {
    super.initState();
    final existing = widget.existingEvent;
    if (existing != null) {
      _nameController = TextEditingController(text: existing.eventName);
      _from = existing.from;
      _to = existing.to;
      _background = existing.background;
      _isAllDay = existing.isAllDay;
      _recurrenceRule = existing.recurrenceRule;
    } else {
      final from = widget.initialFrom!;
      _nameController = TextEditingController(text: '새 일정');
      _from = DateTime(from.year, from.month, from.day, from.hour, 0);
      _to = _from.add(const Duration(hours: 1));
      _background = Colors.blue;
      _isAllDay = false;
      _recurrenceRule = null;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _pickFrom() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _from,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_from),
    );
    if (time == null || !mounted) return;
    setState(() {
      _from = DateTime(date.year, date.month, date.day, time.hour, time.minute);
      if (_to.isBefore(_from) || _to.isAtSameMomentAs(_from)) {
        _to = _from.add(const Duration(hours: 1));
      }
    });
  }

  Future<void> _pickTo() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _to,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_to),
    );
    if (time == null || !mounted) return;
    setState(() {
      _to = DateTime(date.year, date.month, date.day, time.hour, time.minute);
      if (_to.isBefore(_from)) _from = _to.subtract(const Duration(hours: 1));
    });
  }

  void _save() {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('일정 제목을 입력해 주세요.')),
      );
      return;
    }
    if (!_to.isAfter(_from)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('종료 시각은 시작 시각보다 뒤여야 합니다.')),
      );
      return;
    }
    final event = Event(
      eventName: name,
      from: _from,
      to: _to,
      background: _background,
      isAllDay: _isAllDay,
      recurrenceRule: _recurrenceRule,
      recurrenceExceptionDates: widget.existingEvent?.recurrenceExceptionDates,
    );
    Navigator.of(context).pop(event);
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.existingEvent != null;
    return AlertDialog(
      title: Text(isEdit ? '이벤트 수정' : '새 이벤트'),
      content: SingleChildScrollView(
        child: ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 320, maxWidth: 400),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: '제목',
                  border: OutlineInputBorder(),
                ),
                textCapitalization: TextCapitalization.sentences,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  const Text('시작', style: TextStyle(fontWeight: FontWeight.w500)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.calendar_today, size: 18),
                      label: Text(
                        _formatDateTime(_from),
                        style: const TextStyle(fontSize: 13),
                      ),
                      onPressed: _pickFrom,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Text('종료', style: TextStyle(fontWeight: FontWeight.w500)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.calendar_today, size: 18),
                      label: Text(
                        _formatDateTime(_to),
                        style: const TextStyle(fontSize: 13),
                      ),
                      onPressed: _pickTo,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              SwitchListTile(
                title: const Text('종일'),
                value: _isAllDay,
                onChanged: (v) => setState(() => _isAllDay = v),
              ),
              const SizedBox(height: 8),
              const Text('색상', style: TextStyle(fontWeight: FontWeight.w500)),
              const SizedBox(height: 4),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: _colorOptions.map((c) {
                  final selected = _background.value == c.value;
                  return GestureDetector(
                    onTap: () => setState(() => _background = c),
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: c,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: selected ? Colors.black : Colors.grey.shade400,
                          width: selected ? 3 : 1,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
              const Text('반복', style: TextStyle(fontWeight: FontWeight.w500)),
              const SizedBox(height: 4),
              DropdownButtonFormField<String?>(
                value: _recurrenceRule,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                items: _recurrenceLabels.entries.map((e) {
                  return DropdownMenuItem<String?>(
                    value: e.key,
                    child: Text(e.value),
                  );
                }).toList(),
                onChanged: (v) => setState(() => _recurrenceRule = v),
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

  String _formatDateTime(DateTime dt) {
    return '${dt.month}/${dt.day} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}
