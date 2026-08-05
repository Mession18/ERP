import 'package:flutter/material.dart';

class DoubleConfirmDialog extends StatelessWidget {
  final String title;
  final String content;
  final String requiredWord;

  const DoubleConfirmDialog({
    Key? key,
    required this.title,
    required this.content,
    this.requiredWord = "确定",
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.warning_amber_rounded, color: Colors.redAccent, size: 28),
          const SizedBox(width: 8),
          Expanded(child: Text(title)),
        ],
      ),
      content: Text(
        content,
        style: const TextStyle(fontSize: 14, color: Colors.black87),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text("取消"),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red,
            foregroundColor: Colors.white,
          ),
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text("确认删除"),
        ),
      ],
    );
  }
}
