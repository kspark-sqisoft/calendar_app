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

  late final TextEditingController _fromYear;
  late final TextEditingController _fromMonth;
  late final TextEditingController _fromDay;
  late final TextEditingController _fromHour;
  late final TextEditingController _fromMinute;
  late final TextEditingController _toYear;
  late final TextEditingController _toMonth;
  late final TextEditingController _toDay;
  late final TextEditingController _toHour;
  late final TextEditingController _toMinute;

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

  /// 드롭다운은 _recurrenceLabels 키만 사용. FREQ=WEEKLY;BYDAY=TU 등은 'FREQ=WEEKLY'로 매핑.
  String? get _recurrenceDropdownValue {
    if (_recurrenceRule == null || _recurrenceRule!.isEmpty) return null;
    if (_recurrenceLabels.containsKey(_recurrenceRule)) return _recurrenceRule;
    if (_recurrenceRule!.startsWith('FREQ=WEEKLY')) return 'FREQ=WEEKLY';
    if (_recurrenceRule!.startsWith('FREQ=DAILY')) return 'FREQ=DAILY';
    if (_recurrenceRule!.startsWith('FREQ=MONTHLY')) return 'FREQ=MONTHLY';
    return null;
  }

  /// Syncfusion은 FREQ=WEEKLY에 BYDAY 필요. 시작일 요일로 보완.
  static String? _normalizeRecurrenceRule(String? rule, DateTime startDate) {
    if (rule == null || rule.isEmpty) return rule;
    if (rule == 'FREQ=WEEKLY' || (rule.startsWith('FREQ=WEEKLY') && !rule.contains('BYDAY'))) {
      const List<String> byDay = ['MO', 'TU', 'WE', 'TH', 'FR', 'SA', 'SU'];
      final String day = byDay[startDate.weekday - 1];
      return rule == 'FREQ=WEEKLY' ? 'FREQ=WEEKLY;BYDAY=$day' : '$rule;BYDAY=$day';
    }
    return rule;
  }

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
    _fromYear = TextEditingController(text: '${_from.year}');
    _fromMonth = TextEditingController(text: '${_from.month}');
    _fromDay = TextEditingController(text: '${_from.day}');
    _fromHour = TextEditingController(text: '${_from.hour}');
    _fromMinute = TextEditingController(text: '${_from.minute}');
    _toYear = TextEditingController(text: '${_to.year}');
    _toMonth = TextEditingController(text: '${_to.month}');
    _toDay = TextEditingController(text: '${_to.day}');
    _toHour = TextEditingController(text: '${_to.hour}');
    _toMinute = TextEditingController(text: '${_to.minute}');
  }

  void _syncFromToFields() {
    _fromYear.text = '${_from.year}';
    _fromMonth.text = '${_from.month}';
    _fromDay.text = '${_from.day}';
    _fromHour.text = '${_from.hour}';
    _fromMinute.text = '${_from.minute}';
    _toYear.text = '${_to.year}';
    _toMonth.text = '${_to.month}';
    _toDay.text = '${_to.day}';
    _toHour.text = '${_to.hour}';
    _toMinute.text = '${_to.minute}';
  }

  int? _parseInt(String s, int min, int max) {
    final n = int.tryParse(s.trim());
    if (n == null || n < min || n > max) return null;
    return n;
  }

  bool _isValidDate(int y, int m, int d) {
    final dt = DateTime(y, m, d);
    return dt.year == y && dt.month == m && dt.day == d;
  }

  /// 입력 필드에서만 파싱. state(_from/_to)는 건드리지 않음. 저장 시 직접 사용.
  DateTime? _parseFromFromFields() {
    final y = _parseInt(_fromYear.text, 2000, 2100);
    final m = _parseInt(_fromMonth.text, 1, 12);
    final d = _parseInt(_fromDay.text, 1, 31);
    final h = _parseInt(_fromHour.text, 0, 23);
    final min = _parseInt(_fromMinute.text, 0, 59);
    if (y == null || m == null || d == null || h == null || min == null)
      return null;
    if (!_isValidDate(y, m, d)) return null;
    return DateTime(y, m, d, h, min);
  }

  DateTime? _parseToFromFields() {
    final y = _parseInt(_toYear.text, 2000, 2100);
    final m = _parseInt(_toMonth.text, 1, 12);
    final d = _parseInt(_toDay.text, 1, 31);
    final h = _parseInt(_toHour.text, 0, 23);
    final min = _parseInt(_toMinute.text, 0, 59);
    if (y == null || m == null || d == null || h == null || min == null)
      return null;
    if (!_isValidDate(y, m, d)) return null;
    return DateTime(y, m, d, h, min);
  }

  bool _applyFromFields() {
    final y = _parseInt(_fromYear.text, 2000, 2100);
    final m = _parseInt(_fromMonth.text, 1, 12);
    final d = _parseInt(_fromDay.text, 1, 31);
    final h = _parseInt(_fromHour.text, 0, 23);
    final min = _parseInt(_fromMinute.text, 0, 59);
    if (y == null || m == null || d == null || h == null || min == null)
      return false;
    if (!_isValidDate(y, m, d)) return false;
    final next = DateTime(y, m, d, h, min);
    setState(() {
      _from = next;
      if (_to.isBefore(_from) || _to.isAtSameMomentAs(_from)) {
        _to = _from.add(const Duration(hours: 1));
      }
      _syncFromToFields();
    });
    return true;
  }

  bool _applyToFields() {
    final y = _parseInt(_toYear.text, 2000, 2100);
    final m = _parseInt(_toMonth.text, 1, 12);
    final d = _parseInt(_toDay.text, 1, 31);
    final h = _parseInt(_toHour.text, 0, 23);
    final min = _parseInt(_toMinute.text, 0, 59);
    if (y == null || m == null || d == null || h == null || min == null)
      return false;
    if (!_isValidDate(y, m, d)) return false;
    final next = DateTime(y, m, d, h, min);
    setState(() {
      _to = next;
      if (_to.isBefore(_from)) {
        _from = _to.subtract(const Duration(hours: 1));
      }
      _syncFromToFields();
    });
    return true;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _fromYear.dispose();
    _fromMonth.dispose();
    _fromDay.dispose();
    _fromHour.dispose();
    _fromMinute.dispose();
    _toYear.dispose();
    _toMonth.dispose();
    _toDay.dispose();
    _toHour.dispose();
    _toMinute.dispose();
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
      _syncFromToFields();
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
      _syncFromToFields();
    });
  }

  void _save() {
    // 저장 시 입력 필드에서 바로 파싱해서 사용 (포커스/엔터 없이 Save만 눌러도 반영)
    final from = _parseFromFromFields();
    if (from == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('시작 일시를 올바르게 입력해 주세요.')));
      return;
    }
    final to = _parseToFromFields();
    if (to == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('종료 일시를 올바르게 입력해 주세요.')));
      return;
    }
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('일정 제목을 입력해 주세요.')));
      return;
    }
    if (!to.isAfter(from)) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('종료 시각은 시작 시각보다 뒤여야 합니다.')));
      return;
    }
    final String? normalizedRule =
        _normalizeRecurrenceRule(_recurrenceRule, from);
    final event = Event(
      eventName: name,
      from: from,
      to: to,
      background: _background,
      isAllDay: _isAllDay,
      recurrenceRule: normalizedRule,
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
          constraints: const BoxConstraints(minWidth: 400, maxWidth: 480),
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
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(
                    width: 40,
                    child: Text(
                      '시작',
                      style: TextStyle(fontWeight: FontWeight.w500),
                    ),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.calendar_today, size: 18),
                    label: Text(
                      _formatDateTime(_from),
                      style: const TextStyle(fontSize: 12),
                    ),
                    onPressed: _pickFrom,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Row(
                      children: [
                        _numberField(_fromYear, '년', 60, () {
                          if (!_applyFromFields())
                            setState(() => _syncFromToFields());
                        }),
                        _numberField(_fromMonth, '월', 44, () {
                          if (!_applyFromFields())
                            setState(() => _syncFromToFields());
                        }),
                        _numberField(_fromDay, '일', 44, () {
                          if (!_applyFromFields())
                            setState(() => _syncFromToFields());
                        }),
                        _numberField(_fromHour, '시', 44, () {
                          if (!_applyFromFields())
                            setState(() => _syncFromToFields());
                        }),
                        _numberField(_fromMinute, '분', 44, () {
                          if (!_applyFromFields())
                            setState(() => _syncFromToFields());
                        }),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(
                    width: 40,
                    child: Text(
                      '종료',
                      style: TextStyle(fontWeight: FontWeight.w500),
                    ),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.calendar_today, size: 18),
                    label: Text(
                      _formatDateTime(_to),
                      style: const TextStyle(fontSize: 12),
                    ),
                    onPressed: _pickTo,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Row(
                      children: [
                        _numberField(_toYear, '년', 60, () {
                          if (!_applyToFields())
                            setState(() => _syncFromToFields());
                        }),
                        _numberField(_toMonth, '월', 44, () {
                          if (!_applyToFields())
                            setState(() => _syncFromToFields());
                        }),
                        _numberField(_toDay, '일', 44, () {
                          if (!_applyToFields())
                            setState(() => _syncFromToFields());
                        }),
                        _numberField(_toHour, '시', 44, () {
                          if (!_applyToFields())
                            setState(() => _syncFromToFields());
                        }),
                        _numberField(_toMinute, '분', 44, () {
                          if (!_applyToFields())
                            setState(() => _syncFromToFields());
                        }),
                      ],
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
                value: _recurrenceDropdownValue,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
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
        FilledButton(onPressed: _save, child: const Text('저장')),
      ],
    );
  }

  String _formatDateTime(DateTime dt) {
    return '${dt.month}/${dt.day} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  Widget _numberField(
    TextEditingController controller,
    String label, [
    double width = 50,
    VoidCallback? onComplete,
  ]) {
    return Padding(
      padding: const EdgeInsets.only(right: 4),
      child: SizedBox(
        width: width,
        child: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          textAlign: TextAlign.center,
          maxLength: label == '년' ? 4 : 2,
          decoration: InputDecoration(
            labelText: label,
            counterText: '',
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 8,
              vertical: 10,
            ),
            border: const OutlineInputBorder(),
          ),
          onEditingComplete: onComplete,
        ),
      ),
    );
  }
}
