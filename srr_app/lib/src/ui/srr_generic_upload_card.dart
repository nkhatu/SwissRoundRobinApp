// ---------------------------------------------------------------------------
// srr_app/lib/src/ui/srr_generic_upload_card.dart
// ---------------------------------------------------------------------------
// 
// Purpose:
// - Provides shared upload card UI for file actions, stats, and preview tables.
// Architecture:
// - Reusable presentation component for upload workflows across multiple features.
// - Keeps common table/validation rendering logic centralized and composable.
// Author: Neil Khatu
// Copyright (c) The Khatu Family Trust
// 
import 'package:flutter/material.dart';

import 'srr_split_action_button.dart';

class SrrUploadStatItem {
  const SrrUploadStatItem({required this.label, required this.value});

  final String label;
  final String value;
}

class SrrUploadPreviewRow {
  const SrrUploadPreviewRow({
    required this.values,
    required this.isValid,
    this.errors = const <String>[],
    this.isNew = false,
    this.editableRowIndex,
  });

  final List<String> values;
  final bool isValid;
  final List<String> errors;
  final bool isNew;
  final int? editableRowIndex;
}

class SrrGenericUploadCard extends StatelessWidget {
  const SrrGenericUploadCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.uploading,
    required this.applying,
    required this.onUploadPressed,
    required this.onApplyPressed,
    required this.uploadButtonLabel,
    required this.applyButtonLabel,
    required this.templateHeadersText,
    required this.columns,
    required this.previewRows,
    this.contextFields = const <Widget>[],
    this.fileName,
    this.stats = const <SrrUploadStatItem>[],
    this.notes = const <String>[],
    this.uploadError,
    this.applyError,
    this.emptyPreviewMessage = 'No upload parsed yet.',
    this.footer,
    this.onInvalidRowTap,
    this.selectedPreviewRowIndex,
    this.inlineEditor,
    this.previewViewportHeight = 320,
    this.subtitleAsTitleTooltip = false,
    this.templateHeadersAsUploadTooltip = false,
    this.inlineActionsWithContext = false,
    this.notesErrorStyle = false,
    this.showColumnsCard = false,
    this.columnsCardTitle = 'File Headers',
    this.showActionButtons = true,
  });

  final String title;
  final String subtitle;
  final bool uploading;
  final bool applying;
  final VoidCallback? onUploadPressed;
  final VoidCallback? onApplyPressed;
  final String uploadButtonLabel;
  final String applyButtonLabel;
  final String templateHeadersText;
  final List<String> columns;
  final List<SrrUploadPreviewRow> previewRows;
  final List<Widget> contextFields;
  final String? fileName;
  final List<SrrUploadStatItem> stats;
  final List<String> notes;
  final String? uploadError;
  final String? applyError;
  final String emptyPreviewMessage;
  final Widget? footer;
  final ValueChanged<int>? onInvalidRowTap;
  final int? selectedPreviewRowIndex;
  final Widget? inlineEditor;
  final double previewViewportHeight;
  final bool subtitleAsTitleTooltip;
  final bool templateHeadersAsUploadTooltip;
  final bool inlineActionsWithContext;
  final bool notesErrorStyle;
  final bool showColumnsCard;
  final String columnsCardTitle;
  final bool showActionButtons;

  @override
  Widget build(BuildContext context) {
    final uploadActionButton = SizedBox(
      width: 240,
      child: SrrSplitActionButton(
        label: uploading ? 'Uploading...' : uploadButtonLabel,
        variant: SrrSplitActionButtonVariant.outlined,
        leadingIcon: Icons.upload_file,
        onPressed: onUploadPressed,
        maxLines: 2,
      ),
    );
    final uploadAction =
        templateHeadersAsUploadTooltip && templateHeadersText.trim().isNotEmpty
        ? Tooltip(message: templateHeadersText, child: uploadActionButton)
        : uploadActionButton;
    final saveAction = SizedBox(
      width: 240,
      child: SrrSplitActionButton(
        label: applying ? 'Applying...' : applyButtonLabel,
        variant: SrrSplitActionButtonVariant.filled,
        leadingIcon: Icons.playlist_add_check,
        onPressed: onApplyPressed,
        maxLines: 2,
      ),
    );

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            if (subtitleAsTitleTooltip && subtitle.trim().isNotEmpty)
              Wrap(
                alignment: WrapAlignment.center,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 6,
                children: [
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  Tooltip(
                    message: subtitle,
                    child: Icon(
                      Icons.help_outline_rounded,
                      size: 18,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ],
              )
            else
              Text(
                title,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleLarge,
              ),
            const SizedBox(height: 6),
            if (!subtitleAsTitleTooltip && subtitle.trim().isNotEmpty)
              Text(subtitle, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            if (inlineActionsWithContext && contextFields.isNotEmpty)
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 12,
                runSpacing: 12,
                children: showActionButtons
                    ? [...contextFields, uploadAction, saveAction]
                    : [...contextFields],
              )
            else ...[
              if (contextFields.isNotEmpty)
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 12,
                  runSpacing: 12,
                  children: contextFields,
                ),
              if (showActionButtons) ...[
                const SizedBox(height: 10),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 10,
                  runSpacing: 10,
                  children: [uploadAction, saveAction],
                ),
              ],
            ],
            if (!templateHeadersAsUploadTooltip &&
                templateHeadersText.trim().isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(templateHeadersText, textAlign: TextAlign.center),
            ],
            if (fileName != null) ...[
              const SizedBox(height: 8),
              Text('Loaded file: $fileName', textAlign: TextAlign.center),
            ],
            if (stats.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 8,
                runSpacing: 8,
                children: stats
                    .map(
                      (item) =>
                          Chip(label: Text('${item.label}: ${item.value}')),
                    )
                    .toList(growable: false),
              ),
            ],
            if (notes.isNotEmpty) ...[
              const SizedBox(height: 8),
              ...notes.map(
                (entry) => Text(
                  entry,
                  textAlign: TextAlign.center,
                  style: notesErrorStyle
                      ? TextStyle(color: Theme.of(context).colorScheme.error)
                      : null,
                ),
              ),
            ],
            if (uploadError != null) ...[
              const SizedBox(height: 8),
              _InlineError(message: uploadError!),
            ],
            if (applyError != null) ...[
              const SizedBox(height: 8),
              _InlineError(message: applyError!),
            ],
            if (onInvalidRowTap != null &&
                previewRows.any((row) => !row.isValid)) ...[
              const SizedBox(height: 8),
              const Text(
                'Click a highlighted row to edit missing values inline.',
                textAlign: TextAlign.center,
              ),
            ],
            if (showColumnsCard && columns.isNotEmpty) ...[
              const SizedBox(height: 12),
              _ColumnHeadersCard(title: columnsCardTitle, columns: columns),
            ],
            const SizedBox(height: 12),
            _UploadPreviewTable(
              columns: columns,
              rows: previewRows,
              emptyMessage: emptyPreviewMessage,
              onInvalidRowTap: onInvalidRowTap,
              selectedRowIndex: selectedPreviewRowIndex,
              viewportHeight: previewViewportHeight,
            ),
            if (inlineEditor != null) ...[
              const SizedBox(height: 12),
              inlineEditor!,
            ],
            if (footer != null) ...[
              const SizedBox(height: 12),
              Center(child: footer!),
            ],
          ],
        ),
      ),
    );
  }
}

class _ColumnHeadersCard extends StatelessWidget {
  const _ColumnHeadersCard({required this.title, required this.columns});

  final String title;
  final List<String> columns;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: theme.colorScheme.surfaceContainerHighest.withValues(
          alpha: 0.45,
        ),
        border: Border.all(color: theme.dividerColor.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            title,
            textAlign: TextAlign.center,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: columns
                .map((column) => Chip(label: Text(column)))
                .toList(growable: false),
          ),
        ],
      ),
    );
  }
}

class _UploadPreviewTable extends StatefulWidget {
  const _UploadPreviewTable({
    required this.columns,
    required this.rows,
    required this.emptyMessage,
    required this.viewportHeight,
    this.onInvalidRowTap,
    this.selectedRowIndex,
  });

  final List<String> columns;
  final List<SrrUploadPreviewRow> rows;
  final String emptyMessage;
  final ValueChanged<int>? onInvalidRowTap;
  final int? selectedRowIndex;
  final double viewportHeight;

  @override
  State<_UploadPreviewTable> createState() => _UploadPreviewTableState();
}

class _UploadPreviewTableState extends State<_UploadPreviewTable> {
  static const double _defaultIndexColumnWidth = 80;
  static const double _defaultDataColumnWidth = 150;
  static const double _minIndexColumnWidth = 56;
  static const double _minDataColumnWidth = 90;
  static const double _maxColumnWidth = 520;
  static const double _headerHeight = 38;
  static const double _rowHeight = 38;
  static const double _minViewportHeight = 240;
  static const double _maxViewportHeight = 1200;
  static const double _viewportStep = 114;

  late List<double> _columnWidths;
  late double _viewportHeight;

  @override
  void initState() {
    super.initState();
    _columnWidths = _defaultWidths(widget.columns.length);
    _viewportHeight = widget.viewportHeight.clamp(
      _minViewportHeight,
      _maxViewportHeight,
    );
  }

  @override
  void didUpdateWidget(covariant _UploadPreviewTable oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.columns.length != widget.columns.length) {
      _columnWidths = _reconcileWidths(_columnWidths, widget.columns.length);
    }
    if (oldWidget.viewportHeight != widget.viewportHeight &&
        _viewportHeight == oldWidget.viewportHeight) {
      _viewportHeight = widget.viewportHeight.clamp(
        _minViewportHeight,
        _maxViewportHeight,
      );
    }
  }

  List<double> _defaultWidths(int columnCount) {
    return <double>[
      _defaultIndexColumnWidth,
      ...List<double>.filled(columnCount, _defaultDataColumnWidth),
    ];
  }

  List<double> _reconcileWidths(List<double> current, int columnCount) {
    final next = _defaultWidths(columnCount);
    if (current.isNotEmpty) {
      next[0] = current.first;
      for (int i = 0; i < columnCount; i += 1) {
        final currentIndex = i + 1;
        if (currentIndex < current.length) {
          next[currentIndex] = current[currentIndex];
        }
      }
    }
    return next;
  }

  void _resizeColumn(int columnIndex, double delta) {
    if (columnIndex < 0 || columnIndex >= _columnWidths.length) return;
    final minWidth = columnIndex == 0
        ? _minIndexColumnWidth
        : _minDataColumnWidth;
    final current = _columnWidths[columnIndex];
    final resized = (current + delta)
        .clamp(minWidth, _maxColumnWidth)
        .toDouble();
    if ((resized - current).abs() < 0.01) return;
    setState(() {
      _columnWidths[columnIndex] = resized;
    });
  }

  double get _tableWidth =>
      _columnWidths.fold(0, (total, width) => total + width);

  int get _visibleRowsCount =>
      ((_viewportHeight - _headerHeight) / _rowHeight).floor().clamp(1, 999);

  void _resizeViewport(double delta) {
    final resized = (_viewportHeight + delta)
        .clamp(_minViewportHeight, _maxViewportHeight)
        .toDouble();
    if ((resized - _viewportHeight).abs() < 0.01) return;
    setState(() {
      _viewportHeight = resized;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.rows.isEmpty) {
      return Text(widget.emptyMessage, textAlign: TextAlign.center);
    }

    final theme = Theme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.dividerColor.withValues(alpha: 0.5)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            child: SizedBox(
              height: _viewportHeight,
              child: Scrollbar(
                thumbVisibility: true,
                notificationPredicate: (notification) =>
                    notification.metrics.axis == Axis.horizontal,
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: SizedBox(
                    width: _tableWidth,
                    child: Column(
                      children: [
                        Container(
                          height: _headerHeight,
                          color: theme.colorScheme.surfaceContainerHighest
                              .withValues(alpha: 0.45),
                          child: Row(
                            children: [
                              _headerCell(
                                context,
                                '#',
                                columnIndex: 0,
                                width: _columnWidths[0],
                              ),
                              for (int i = 0; i < widget.columns.length; i += 1)
                                _headerCell(
                                  context,
                                  widget.columns[i],
                                  columnIndex: i + 1,
                                  width: _columnWidths[i + 1],
                                ),
                            ],
                          ),
                        ),
                        Divider(
                          height: 1,
                          thickness: 1,
                          color: theme.dividerColor.withValues(alpha: 0.55),
                        ),
                        Expanded(
                          child: Scrollbar(
                            thumbVisibility: true,
                            child: ListView.separated(
                              itemCount: widget.rows.length,
                              separatorBuilder: (context, _) => Divider(
                                height: 1,
                                thickness: 1,
                                color: theme.dividerColor.withValues(
                                  alpha: 0.35,
                                ),
                              ),
                              itemBuilder: (context, index) {
                                final row = widget.rows[index];
                                final isInvalid = !row.isValid;
                                final canEdit =
                                    isInvalid && widget.onInvalidRowTap != null;
                                final targetEditIndex =
                                    row.editableRowIndex ?? index;
                                final isSelected =
                                    canEdit &&
                                    widget.selectedRowIndex != null &&
                                    widget.selectedRowIndex == targetEditIndex;
                                final rowColor = isSelected
                                    ? theme.colorScheme.primaryContainer
                                          .withValues(alpha: 0.55)
                                    : isInvalid
                                    ? theme.colorScheme.errorContainer
                                          .withValues(alpha: 0.65)
                                    : Colors.transparent;

                                return Material(
                                  color: rowColor,
                                  child: InkWell(
                                    onTap: canEdit
                                        ? () => widget.onInvalidRowTap?.call(
                                            targetEditIndex,
                                          )
                                        : null,
                                    child: SizedBox(
                                      height: _rowHeight,
                                      child: Row(
                                        children: [
                                          _indexCell(
                                            context: context,
                                            displayIndex: index + 1,
                                            width: _columnWidths[0],
                                            isNew: row.isNew,
                                            showEditIcon: canEdit,
                                          ),
                                          for (
                                            int column = 0;
                                            column < widget.columns.length;
                                            column++
                                          )
                                            _dataCell(
                                              context,
                                              width: _columnWidths[column + 1],
                                              value: column < row.values.length
                                                  ? row.values[column]
                                                  : '',
                                            ),
                                        ],
                                      ),
                                    ),
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
          ),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(
                  color: theme.dividerColor.withValues(alpha: 0.5),
                ),
              ),
            ),
            child: Wrap(
              alignment: WrapAlignment.center,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 10,
              runSpacing: 8,
              children: [
                IconButton(
                  visualDensity: VisualDensity.compact,
                  tooltip: 'Show fewer rows',
                  onPressed: () => _resizeViewport(-_viewportStep),
                  icon: const Icon(Icons.remove_circle_outline),
                ),
                Text(
                  'Rows visible: $_visibleRowsCount',
                  style: theme.textTheme.bodySmall,
                ),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  tooltip: 'Show more rows',
                  onPressed: () => _resizeViewport(_viewportStep),
                  icon: const Icon(Icons.add_circle_outline),
                ),
                MouseRegion(
                  cursor: SystemMouseCursors.resizeUpDown,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onVerticalDragUpdate: (details) =>
                        _resizeViewport(-details.delta.dy),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.unfold_more_rounded,
                          size: 16,
                          color: theme.colorScheme.primary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Drag to resize',
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _headerCell(
    BuildContext context,
    String value, {
    required int columnIndex,
    required double width,
  }) {
    final theme = Theme.of(context);
    return SizedBox(
      width: width,
      child: Stack(
        children: [
          Positioned.fill(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            right: 0,
            top: 0,
            bottom: 0,
            child: MouseRegion(
              cursor: SystemMouseCursors.resizeColumn,
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onHorizontalDragUpdate: (details) =>
                    _resizeColumn(columnIndex, details.delta.dx),
                child: Container(
                  width: 12,
                  alignment: Alignment.centerRight,
                  child: Container(
                    width: 1,
                    color: theme.dividerColor.withValues(alpha: 0.7),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _dataCell(
    BuildContext context, {
    required double width,
    required String value,
  }) {
    return SizedBox(
      width: width,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Align(
          alignment: Alignment.centerLeft,
          child: Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.left,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
      ),
    );
  }

  Widget _indexCell({
    required BuildContext context,
    required int displayIndex,
    required double width,
    required bool isNew,
    required bool showEditIcon,
  }) {
    final theme = Theme.of(context);
    return SizedBox(
      width: width,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Row(
          children: [
            if (isNew) ...[
              Icon(
                Icons.fiber_new_rounded,
                size: 16,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 4),
            ],
            Text('$displayIndex'),
            const Spacer(),
            if (showEditIcon)
              Icon(
                Icons.edit_outlined,
                size: 15,
                color: theme.colorScheme.primary,
              ),
          ],
        ),
      ),
    );
  }
}

class _InlineError extends StatelessWidget {
  const _InlineError({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: theme.colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: TextStyle(color: theme.colorScheme.onErrorContainer),
      ),
    );
  }
}
