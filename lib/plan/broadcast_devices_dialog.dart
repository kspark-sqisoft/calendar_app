import 'package:calendar_app/device/device.dart';
import 'package:calendar_app/device/device_repository.dart';
import 'package:calendar_app/plan/broadcast_plan.dart';
import 'package:calendar_app/plan/plan_repository.dart';
import 'package:flutter/material.dart';

/// 방송 계획에 지정할 디바이스를 멀티 선택하는 다이얼로그.
/// 이미 다른 계획에 지정된 디바이스는 비활성화·취소선·해당 계획명 표시.
Future<List<int>?> showBroadcastDevicesDialog({
  required BuildContext context,
  required BroadcastPlan plan,
}) async {
  return showDialog<List<int>>(
    context: context,
    builder: (context) => _BroadcastDevicesDialog(plan: plan),
  );
}

class _BroadcastDevicesDialog extends StatefulWidget {
  const _BroadcastDevicesDialog({required this.plan});

  final BroadcastPlan plan;

  @override
  State<_BroadcastDevicesDialog> createState() => _BroadcastDevicesDialogState();
}

class _BroadcastDevicesDialogState extends State<_BroadcastDevicesDialog> {
  List<Device> _devices = [];
  List<BroadcastPlan> _plans = [];
  bool _loading = true;
  late Set<int> _selectedIds;

  @override
  void initState() {
    super.initState();
    _selectedIds = Set.from(widget.plan.deviceIds);
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final devices = await DeviceRepository.instance.getAll();
      final plans = await PlanRepository.instance.getAll();
      if (mounted) {
        setState(() {
          _devices = devices;
          _plans = plans;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// 이 디바이스가 현재 편집 중인 계획이 아닌 다른 계획에 지정돼 있으면 그 계획 반환.
  BroadcastPlan? _planUsingDevice(int deviceId) {
    for (final p in _plans) {
      if (p.id != widget.plan.id && p.deviceIds.contains(deviceId)) return p;
    }
    return null;
  }

  void _toggle(int? deviceId) {
    if (deviceId == null) return;
    setState(() {
      if (_selectedIds.contains(deviceId)) {
        _selectedIds.remove(deviceId);
      } else {
        _selectedIds.add(deviceId);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return AlertDialog(
      title: const Text('방송할 디바이스 선택'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 320, maxWidth: 420, maxHeight: 400),
        child: _loading
            ? const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              )
            : _devices.isEmpty
                ? Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: Text(
                      '등록된 디바이스가 없습니다. 디바이스 메뉴에서 먼저 디바이스를 추가해 주세요.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  )
                : SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          '"${widget.plan.name}"에 방송할 디바이스를 선택하세요. (여러 개 선택 가능)',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 16),
                        ..._devices.map((device) {
                          final id = device.id;
                          final assignedPlan = id != null ? _planUsingDevice(id) : null;
                          final isTaken = assignedPlan != null;
                          final selected = id != null && _selectedIds.contains(id);
                          return CheckboxListTile(
                            value: selected,
                            onChanged: isTaken ? null : (_) => _toggle(id),
                            title: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  device.name,
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    decoration: isTaken ? TextDecoration.lineThrough : null,
                                    decorationColor: colorScheme.onSurfaceVariant,
                                    color: isTaken ? colorScheme.onSurfaceVariant : null,
                                  ),
                                ),
                                if (isTaken) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    '이미 지정됨: ${assignedPlan.name}',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: colorScheme.primary,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            secondary: Icon(
                              Icons.phone_android_rounded,
                              color: isTaken ? colorScheme.onSurfaceVariant : colorScheme.primary,
                              size: 22,
                            ),
                            controlAffinity: ListTileControlAffinity.leading,
                          );
                        }),
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
          onPressed: _loading || _devices.isEmpty
              ? null
              : () => Navigator.of(context).pop(_selectedIds.toList()..sort()),
          child: const Text('확인'),
        ),
      ],
    );
  }
}
