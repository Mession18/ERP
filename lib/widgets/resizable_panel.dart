import 'package:flutter/material.dart';

class ResizableSplitPanel extends StatefulWidget {
  final Widget first;
  final Widget second;
  final Axis direction;
  final double initialRatio;
  final double minSize;

  const ResizableSplitPanel({
    Key? key,
    required this.first,
    required this.second,
    this.direction = Axis.horizontal,
    this.initialRatio = 0.25,
    this.minSize = 100.0,
  }) : super(key: key);

  @override
  _ResizableSplitPanelState createState() => _ResizableSplitPanelState();
}

class _ResizableSplitPanelState extends State<ResizableSplitPanel> {
  double? _size;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final totalSize = widget.direction == Axis.horizontal
            ? constraints.maxWidth
            : constraints.maxHeight;

        if (_size == null) {
          _size = totalSize * widget.initialRatio;
        }

        // Clamp the size within bounds
        _size = _size!.clamp(widget.minSize, totalSize - widget.minSize);

        final divider = GestureDetector(
          behavior: HitTestBehavior.translucent,
          onHorizontalDragUpdate: widget.direction == Axis.horizontal
              ? (details) {
                  setState(() {
                    _size = (_size! + details.primaryDelta!).clamp(
                      widget.minSize,
                      totalSize - widget.minSize,
                    );
                  });
                }
              : null,
          onVerticalDragUpdate: widget.direction == Axis.vertical
              ? (details) {
                  setState(() {
                    _size = (_size! + details.primaryDelta!).clamp(
                      widget.minSize,
                      totalSize - widget.minSize,
                    );
                  });
                }
              : null,
          child: Container(
            width: widget.direction == Axis.horizontal ? 8 : double.infinity,
            height: widget.direction == Axis.vertical ? 8 : double.infinity,
            color: Colors.grey[300],
            child: Center(
              child: Icon(
                widget.direction == Axis.horizontal
                    ? Icons.drag_indicator
                    : Icons.drag_handle,
                size: 16,
                color: Colors.grey[600],
              ),
            ),
          ),
        );

        if (widget.direction == Axis.horizontal) {
          return Row(
            children: [
              SizedBox(
                width: _size,
                child: widget.first,
              ),
              divider,
              Expanded(
                child: widget.second,
              ),
            ],
          );
        } else {
          return Column(
            children: [
              SizedBox(
                height: _size,
                child: widget.first,
              ),
              divider,
              Expanded(
                child: widget.second,
              ),
            ],
          );
        }
      },
    );
  }
}
