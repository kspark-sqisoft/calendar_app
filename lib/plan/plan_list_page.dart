import 'package:calendar_app/plan/broadcast_plan.dart';
import 'package:calendar_app/plan/broadcast_devices_dialog.dart';
import 'package:calendar_app/plan/plan_edit_dialog.dart';
import 'package:calendar_app/plan/plan_preview_dialog.dart';
import 'package:calendar_app/plan/plan_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// 방송 계획 목록 + 새로 만들기
class PlanListPage extends ConsumerStatefulWidget {
  const PlanListPage({super.key});

  @override
  ConsumerState<PlanListPage> createState() => _PlanListPageState();
}

class _PlanListPageState extends ConsumerState<PlanListPage> {
  List<BroadcastPlan> _plans = [];
  bool _loading = true;
  String? _error;
  bool _wasCurrent = false;

  @override
  void initState() {
    super.initState();
  }

  /// 목록이 현재 화면일 때마다 새로고침 (첫 진입 + 뒤로 가기 후)
  void _scheduleReloadWhenCurrent() {
    final isCurrent = ModalRoute.of(context)?.isCurrent ?? false;
    if (isCurrent && !_wasCurrent) {
      _wasCurrent = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _load();
      });
    } else if (!isCurrent) {
      _wasCurrent = false;
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await PlanRepository.instance.getAll();
      if (mounted) {
        setState(() {
          _plans = list;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = e.toString();
        });
      }
    }
  }

  Future<void> _createPlan() async {
    final result = await context.push<BroadcastPlan?>('/plans/new');
    if (result != null && result.id != null && mounted) {
      context.push('/plans/${result.id}');
    } else if (mounted) {
      _load();
    }
  }

  String _formatDateRange(DateTime min, DateTime max) {
    return '${min.year}.${min.month}.${min.day} ~ ${max.year}.${max.month}.${max.day}';
  }

  Future<void> _editPlan(BroadcastPlan plan) async {
    final updated = await showPlanEditDialog(context, plan: plan);
    if (updated == null || !mounted) return;
    try {
      await PlanRepository.instance.update(updated);
      if (mounted) _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('수정 실패: $e')),
        );
      }
    }
  }

  Future<void> _broadcastPlan(BroadcastPlan plan) async {
    final selectedIds = await showBroadcastDevicesDialog(context: context, plan: plan);
    if (selectedIds == null || !mounted) return;
    try {
      final updated = plan.copyWith(deviceIds: selectedIds);
      await PlanRepository.instance.update(updated);
      if (mounted) {
        _load();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              selectedIds.isEmpty
                  ? '지정 디바이스를 해제했습니다.'
                  : '${selectedIds.length}개 디바이스에 방송하도록 지정했습니다.',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('저장 실패: $e')),
        );
      }
    }
  }

  Future<void> _deletePlan(BroadcastPlan plan) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('방송 계획 삭제'),
        content: Text(
          '"${plan.name}"과(와) 포함된 모든 일정이 삭제됩니다. 계속하시겠습니까?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('삭제'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await PlanRepository.instance.delete(plan);
      if (mounted) _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('삭제 실패: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    _scheduleReloadWhenCurrent();
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surfaceContainerLowest,
      appBar: AppBar(
        title: const Text('방송 계획'),
        centerTitle: true,
        elevation: 0,
        scrolledUnderElevation: 1,
        backgroundColor: colorScheme.surface,
      ),
      body: _loading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 40,
                    height: 40,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    '불러오는 중…',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            )
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: colorScheme.errorContainer.withValues(alpha: 0.5),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.error_outline_rounded,
                            size: 48,
                            color: colorScheme.error,
                          ),
                        ),
                        const SizedBox(height: 24),
                        Text(
                          '목록을 불러오지 못했습니다.',
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: colorScheme.onSurface,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _error!,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                          textAlign: TextAlign.center,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 24),
                        FilledButton.icon(
                          onPressed: _load,
                          icon: const Icon(Icons.refresh_rounded, size: 20),
                          label: const Text('다시 시도'),
                        ),
                      ],
                    ),
                  ),
                )
              : _plans.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(28),
                              decoration: BoxDecoration(
                                color: colorScheme.primaryContainer.withValues(alpha: 0.6),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.calendar_month_rounded,
                                size: 56,
                                color: colorScheme.onPrimaryContainer,
                              ),
                            ),
                            const SizedBox(height: 28),
                            Text(
                              '방송 계획이 없습니다',
                              style: theme.textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: colorScheme.onSurface,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '새 계획을 만들고 일정을 관리해 보세요.',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 28),
                            FilledButton.icon(
                              onPressed: _createPlan,
                              icon: const Icon(Icons.add_rounded, size: 22),
                              label: const Text('방송 계획 새로 만들기'),
                              style: FilledButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _load,
                      color: colorScheme.primary,
                      child: ListView.builder(
                        padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
                        itemCount: _plans.length,
                        itemBuilder: (context, index) {
                          final plan = _plans[index];
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Material(
                              color: colorScheme.surfaceContainerLow,
                              borderRadius: BorderRadius.circular(16),
                              elevation: 0,
                              shadowColor: Colors.transparent,
                              child: InkWell(
                                onTap: plan.id != null
                                    ? () => context.push('/plans/${plan.id}')
                                    : null,
                                borderRadius: BorderRadius.circular(16),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 48,
                                        height: 48,
                                        decoration: BoxDecoration(
                                          color: colorScheme.primaryContainer,
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Icon(
                                          Icons.schedule_rounded,
                                          color: colorScheme.onPrimaryContainer,
                                          size: 26,
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              plan.name,
                                              style: theme.textTheme.titleMedium?.copyWith(
                                                fontWeight: FontWeight.w600,
                                                color: colorScheme.onSurface,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              _formatDateRange(plan.minDate, plan.maxDate),
                                              style: theme.textTheme.bodySmall?.copyWith(
                                                color: colorScheme.onSurfaceVariant,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      FilledButton.icon(
                                        onPressed: () => showPlanPreviewDialog(context, plan: plan),
                                        icon: const Icon(Icons.preview_rounded, size: 20),
                                        label: const Text('미리보기'),
                                        style: FilledButton.styleFrom(
                                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                                          minimumSize: const Size(0, 44),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          backgroundColor: colorScheme.primaryContainer,
                                          foregroundColor: colorScheme.onPrimaryContainer,
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      FilledButton.icon(
                                        onPressed: () => _broadcastPlan(plan),
                                        icon: const Icon(Icons.cast_rounded, size: 20),
                                        label: const Text('방송 하기'),
                                        style: FilledButton.styleFrom(
                                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                                          minimumSize: const Size(0, 44),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          backgroundColor: colorScheme.tertiaryContainer,
                                          foregroundColor: colorScheme.onTertiaryContainer,
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      IconButton(
                                        icon: Icon(
                                          Icons.edit_outlined,
                                          color: colorScheme.primary,
                                          size: 22,
                                        ),
                                        onPressed: () => _editPlan(plan),
                                        tooltip: '편집',
                                        style: IconButton.styleFrom(
                                          backgroundColor: colorScheme.primaryContainer.withValues(alpha: 0.5),
                                        ),
                                      ),
                                      IconButton(
                                        icon: Icon(
                                          Icons.delete_outline_rounded,
                                          color: colorScheme.error,
                                          size: 22,
                                        ),
                                        onPressed: () => _deletePlan(plan),
                                        tooltip: '삭제',
                                        style: IconButton.styleFrom(
                                          backgroundColor: colorScheme.errorContainer.withValues(alpha: 0.5),
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      Icon(
                                        Icons.chevron_right_rounded,
                                        color: colorScheme.onSurfaceVariant,
                                        size: 24,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
      floatingActionButton: _plans.isNotEmpty
          ? FloatingActionButton.extended(
              onPressed: _createPlan,
              icon: const Icon(Icons.add_rounded),
              label: const Text('새로 만들기'),
              backgroundColor: colorScheme.primaryContainer,
              foregroundColor: colorScheme.onPrimaryContainer,
              elevation: 2,
            )
          : null,
    );
  }
}
