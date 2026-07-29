import 'package:flutter/material.dart';

class ExcelColumn {
  final String label;
  double width;

  ExcelColumn({
    required this.label,
    required this.width,
  });
}

class ExcelTable extends StatefulWidget {
  final List<ExcelColumn> columns;
  final int rowCount;
  final List<List<Widget>> rows; // cells for each row. Length must match rowCount and cell length must match columns length.
  final Widget? headerActions;

  const ExcelTable({
    Key? key,
    required this.columns,
    required this.rowCount,
    required this.rows,
    this.headerActions,
  }) : super(key: key);

  @override
  _ExcelTableState createState() => _ExcelTableState();
}

class _ExcelTableState extends State<ExcelTable> {
  final ScrollController _horizontalController = ScrollController();
  final ScrollController _verticalController = ScrollController();

  @override
  void dispose() {
    _horizontalController.dispose();
    _verticalController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Total table width based on columns
    double totalWidth = widget.columns.fold(0.0, (sum, col) => sum + col.width);

    return LayoutBuilder(
      builder: (context, constraints) {
        return Container(
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey[400]!),
            color: Colors.white,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Top Toolbar / Header actions if any
              if (widget.headerActions != null) ...[
                widget.headerActions!,
                Divider(height: 1, color: Colors.grey[400]),
              ],
              // Scrollable areas
              Expanded(
                child: Scrollbar(
                  controller: _horizontalController,
                  thumbVisibility: true,
                  trackVisibility: true,
                  child: SingleChildScrollView(
                    controller: _horizontalController,
                    scrollDirection: Axis.horizontal,
                    child: Container(
                      width: totalWidth,
                      child: Column(
                        children: [
                          // 1. Frozen Header
                          Container(
                            color: Colors.grey[200],
                            height: 40,
                            child: Row(
                              children: widget.columns.asMap().entries.map((entry) {
                                final int index = entry.key;
                                final ExcelColumn col = entry.value;

                                return Container(
                                  width: col.width,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    border: Border(
                                      right: BorderSide(color: Colors.grey[400]!),
                                      bottom: BorderSide(color: Colors.grey[400]!, width: 2),
                                    ),
                                  ),
                                  child: Stack(
                                    children: [
                                      // Label text
                                      Center(
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(horizontal: 4.0),
                                          child: Text(
                                            col.label,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              color: Colors.black87,
                                              fontSize: 13,
                                            ),
                                            textAlign: TextAlign.center,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ),
                                      // Draggable handle to adjust column width
                                      Positioned(
                                        right: 0,
                                        top: 0,
                                        bottom: 0,
                                        width: 8,
                                        child: MouseRegion(
                                          cursor: SystemMouseCursors.resizeLeftRight,
                                          child: GestureDetector(
                                            behavior: HitTestBehavior.translucent,
                                            onHorizontalDragUpdate: (details) {
                                              setState(() {
                                                col.width = (col.width + details.primaryDelta!).clamp(50.0, 500.0);
                                              });
                                            },
                                            child: Container(
                                              color: Colors.transparent,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                          // 2. Rows Scrollable Vertically
                          Expanded(
                            child: Scrollbar(
                              controller: _verticalController,
                              thumbVisibility: true,
                              trackVisibility: true,
                              child: ListView.builder(
                                controller: _verticalController,
                                itemCount: widget.rowCount,
                                itemExtent: 44, // Fixed height for precise calculation
                                itemBuilder: (context, rowIndex) {
                                  final rowCells = widget.rows[rowIndex];
                                  final isEven = rowIndex % 2 == 0;

                                  return Container(
                                    decoration: BoxDecoration(
                                      color: isEven ? Colors.white : Colors.grey[50],
                                      border: Border(
                                        bottom: BorderSide(color: Colors.grey[200]!),
                                      ),
                                    ),
                                    child: Row(
                                      children: rowCells.asMap().entries.map((entry) {
                                        final int index = entry.key;
                                        final Widget cell = entry.value;
                                        final double w = widget.columns[index].width;

                                        return Container(
                                          width: w,
                                          height: 44,
                                          decoration: BoxDecoration(
                                            border: Border(
                                              right: BorderSide(color: Colors.grey[200]!),
                                            ),
                                          ),
                                          alignment: Alignment.center,
                                          padding: const EdgeInsets.symmetric(horizontal: 8),
                                          child: cell,
                                        );
                                      }).toList(),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
