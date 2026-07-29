import 'package:flutter/material.dart';

class DoubleConfirmDialog extends StatefulWidget {
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
  _DoubleConfirmDialogState createState() => _DoubleConfirmDialogState();
}

class _DoubleConfirmDialogState extends State<DoubleConfirmDialog> {
  final TextEditingController _controller = TextEditingController();
  double _sliderVal = 0.0;
  bool _isWordMatch = false;
  bool _isSliderPassed = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(() {
      setState(() {
        _isWordMatch = _controller.text.trim() == widget.requiredWord;
      });
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool canDelete = _isWordMatch && _isSliderPassed;

    return AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.warning, color: Colors.red),
          const SizedBox(width: 8),
          Text(widget.title),
        ],
      ),
      content: SingleChildScrollView(
        child: ListBody(
          children: [
            Text(widget.content),
            const SizedBox(height: 16),
            const Text(
              "第一步：请输入「确定」以确认操作：",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _controller,
              decoration: InputDecoration(
                hintText: "输入 '${widget.requiredWord}'",
                border: const OutlineInputBorder(),
                isDense: true,
                suffixIcon: _isWordMatch
                    ? const Icon(Icons.check_circle, color: Colors.green)
                    : null,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              "第二步：请向右滑动滑块进行二次确认：",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Slider(
                    value: _sliderVal,
                    min: 0.0,
                    max: 100.0,
                    activeColor: Colors.red,
                    onChanged: (val) {
                      setState(() {
                        _sliderVal = val;
                        _isSliderPassed = val >= 95.0;
                      });
                    },
                    onChangeEnd: (val) {
                      if (val < 95.0) {
                        setState(() {
                          _sliderVal = 0.0;
                          _isSliderPassed = false;
                        });
                      }
                    },
                  ),
                ),
                Text(
                  _isSliderPassed ? "验证通过" : "${_sliderVal.toInt()}%",
                  style: TextStyle(
                    color: _isSliderPassed ? Colors.green : Colors.grey,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text("取消"),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: canDelete ? Colors.red : Colors.grey[400],
            foregroundColor: Colors.white,
          ),
          onPressed: canDelete ? () => Navigator.of(context).pop(true) : null,
          child: const Text("确认删除"),
        ),
      ],
    );
  }
}
