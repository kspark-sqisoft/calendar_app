import 'package:flutter/material.dart';

/// 방송 계획 이름 수정 다이얼로그. 저장 시 새 이름 반환, 취소 시 null.
Future<String?> showPlanNameEditDialog(
  BuildContext context, {
  required String initialName,
}) async {
  final controller = TextEditingController(text: initialName);
  controller.selection = TextSelection(
    baseOffset: 0,
    extentOffset: initialName.length,
  );
  return showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('방송 계획 이름 수정'),
      content: TextField(
        controller: controller,
        autofocus: true,
        decoration: const InputDecoration(
          labelText: '이름',
          hintText: '계획 이름을 입력하세요',
          border: OutlineInputBorder(),
        ),
        textCapitalization: TextCapitalization.sentences,
        onSubmitted: (value) {
          final trimmed = value.trim();
          if (trimmed.isNotEmpty) Navigator.of(context).pop(trimmed);
        },
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('취소'),
        ),
        FilledButton(
          onPressed: () {
            final trimmed = controller.text.trim();
            if (trimmed.isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('이름을 입력해 주세요.')),
              );
              return;
            }
            Navigator.of(context).pop(trimmed);
          },
          child: const Text('저장'),
        ),
      ],
    ),
  );
}
