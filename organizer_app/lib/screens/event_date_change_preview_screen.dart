import 'package:flutter/material.dart';

import '../foundation/app_error.dart';
import '../services/supabase_service.dart';

class EventDateChangePreviewScreen extends StatefulWidget {
  final Map<String, dynamic> event;
  const EventDateChangePreviewScreen({super.key, required this.event});

  @override
  State<EventDateChangePreviewScreen> createState() =>
      _EventDateChangePreviewScreenState();
}

class _EventDateChangePreviewScreenState
    extends State<EventDateChangePreviewScreen> {
  bool _loading = false;
  bool _submitting = false;
  Map<String, dynamic>? _previewData;
  String? _errorMessage;

  // Selected Target Inputs
  bool _isExactMode = true;
  DateTime? _targetExactDate;
  int? _targetExpectedYear;
  int? _targetExpectedMonth;

  @override
  void initState() {
    super.initState();
    // Initialize with current event date details
    _isExactMode = widget.event['exact_date'] != null;
    if (_isExactMode) {
      _targetExactDate = DateTime.parse(widget.event['exact_date'] as String);
    } else {
      _targetExpectedYear = widget.event['expected_year'] as int?;
      _targetExpectedMonth = widget.event['expected_month'] as int?;
    }
    _loadPreview();
  }

  Future<void> _loadPreview() async {
    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    try {
      final data = await SupabaseService.instance.previewEventDateChange(
        eventId: widget.event['id'] as String,
        targetExactDate: _isExactMode ? _targetExactDate : null,
        targetExpectedYear: !_isExactMode ? _targetExpectedYear : null,
        targetExpectedMonth: !_isExactMode ? _targetExpectedMonth : null,
      );
      setState(() {
        _previewData = data;
        _loading = false;
      });
    } catch (e) {
      final failure = await SupabaseService.instance.handleOperationalError(e);
      setState(() {
        _errorMessage = failure.message;
        _loading = false;
      });
    }
  }

  Future<void> _commitChange() async {
    if (_previewData == null) return;
    setState(() {
      _submitting = true;
      _errorMessage = null;
    });

    try {
      final fingerprint = _previewData!['impact_fingerprint'] as String;
      final result = await SupabaseService.instance.commitEventDateChange(
        eventId: widget.event['id'] as String,
        targetExactDate: _isExactMode ? _targetExactDate : null,
        targetExpectedYear: !_isExactMode ? _targetExpectedYear : null,
        targetExpectedMonth: !_isExactMode ? _targetExpectedMonth : null,
        impactFingerprint: fingerprint,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Cập nhật ngày sự kiện thành công!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, result);
      }
    } catch (e) {
      setState(() {
        _submitting = false;
      });

      final failure = await SupabaseService.instance.handleOperationalError(e);
      if (failure.kind == AppErrorKind.staleImpact) {
        _showStaleImpactDialog();
      } else {
        setState(() {
          _errorMessage = failure.message;
        });
      }
    }
  }

  void _showStaleImpactDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext ctx) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1E293B),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Row(
            children: [
              Icon(
                Icons.warning_amber_rounded,
                color: Colors.orangeAccent,
                size: 28,
              ),
              SizedBox(width: 8),
              Text(
                'Dữ liệu đã thay đổi',
                style: TextStyle(color: Colors.white),
              ),
            ],
          ),
          content: const Text(
            'Không gian lập kế hoạch đã được chỉnh sửa bởi một thành viên khác kể từ khi bạn mở xem trước này. Vui lòng tải lại trang xem trước để kiểm tra lại tác động trước khi lưu.',
            style: TextStyle(color: Colors.white70),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                _loadPreview();
              },
              child: const Text(
                'Tải lại xem trước',
                style: TextStyle(color: Colors.blueAccent),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _selectDate() async {
    final initialDate = _targetExactDate ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2025),
      lastDate: DateTime(2035),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Colors.pinkAccent,
              onPrimary: Colors.white,
              surface: Color(0xFF1E293B),
              onSurface: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _targetExactDate = picked;
      });
      _loadPreview();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        title: const Text(
          'Xem trước đổi ngày',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFF1E293B),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Event Info Card
              _buildEventInfoCard(),
              const SizedBox(height: 16),

              // Inputs Section
              _buildTargetInputSection(),
              const SizedBox(height: 24),

              // Error Message
              if (_errorMessage != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.redAccent.withOpacity(0.1),
                    border: Border.all(
                      color: Colors.redAccent.withOpacity(0.3),
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _errorMessage!,
                    style: const TextStyle(color: Colors.redAccent),
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Loading indicator or Preview content
              if (_loading)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 40.0),
                    child: CircularProgressIndicator(color: Colors.pinkAccent),
                  ),
                )
              else if (_previewData != null)
                _buildPreviewDetails()
              else
                const Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 40.0),
                    child: Text(
                      'Vui lòng chọn ngày để xem trước tác động',
                      style: TextStyle(color: Colors.white38),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: _buildBottomActions(),
    );
  }

  Widget _buildEventInfoCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.event['name'] as String,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.calendar_today, size: 16, color: Colors.white54),
              const SizedBox(width: 6),
              Text(
                widget.event['exact_date'] != null
                    ? 'Ngày hiện tại: ${widget.event['exact_date']}'
                    : 'Tháng dự kiến: Tháng ${widget.event['expected_month']}/${widget.event['expected_year']}',
                style: const TextStyle(color: Colors.white70),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTargetInputSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Chọn ngày / tháng mới',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 12),
          // Precision mode selector
          Row(
            children: [
              Expanded(
                child: ChoiceChip(
                  label: const Center(child: Text('Ngày chính xác')),
                  selected: _isExactMode,
                  selectedColor: Colors.pinkAccent,
                  backgroundColor: const Color(0xFF0F172A),
                  labelStyle: TextStyle(
                    color: _isExactMode ? Colors.white : Colors.white70,
                  ),
                  onSelected: (val) {
                    setState(() {
                      _isExactMode = true;
                      _targetExactDate ??= DateTime.now();
                    });
                    _loadPreview();
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ChoiceChip(
                  label: const Center(child: Text('Tháng dự kiến')),
                  selected: !_isExactMode,
                  selectedColor: Colors.pinkAccent,
                  backgroundColor: const Color(0xFF0F172A),
                  labelStyle: TextStyle(
                    color: !_isExactMode ? Colors.white : Colors.white70,
                  ),
                  onSelected: (val) {
                    setState(() {
                      _isExactMode = false;
                      _targetExpectedYear ??= DateTime.now().year;
                      _targetExpectedMonth ??= DateTime.now().month;
                    });
                    _loadPreview();
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Input fields
          if (_isExactMode)
            InkWell(
              onTap: _selectDate,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F172A),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.white10),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _targetExactDate != null
                          ? '${_targetExactDate!.day}/${_targetExactDate!.month}/${_targetExactDate!.year}'
                          : 'Chọn ngày',
                      style: const TextStyle(color: Colors.white, fontSize: 16),
                    ),
                    const Icon(Icons.calendar_month, color: Colors.pinkAccent),
                  ],
                ),
              ),
            )
          else
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<int>(
                    dropdownColor: const Color(0xFF1E293B),
                    value: _targetExpectedMonth,
                    decoration: const InputDecoration(
                      labelText: 'Tháng',
                      labelStyle: TextStyle(color: Colors.white54),
                      fillColor: Color(0xFF0F172A),
                      filled: true,
                      border: OutlineInputBorder(),
                    ),
                    items: List.generate(12, (index) => index + 1)
                        .map(
                          (m) => DropdownMenuItem(
                            value: m,
                            child: Text(
                              'Tháng $m',
                              style: const TextStyle(color: Colors.white),
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (val) {
                      setState(() {
                        _targetExpectedMonth = val;
                      });
                      _loadPreview();
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<int>(
                    dropdownColor: const Color(0xFF1E293B),
                    value: _targetExpectedYear,
                    decoration: const InputDecoration(
                      labelText: 'Năm',
                      labelStyle: TextStyle(color: Colors.white54),
                      fillColor: Color(0xFF0F172A),
                      filled: true,
                      border: OutlineInputBorder(),
                    ),
                    items:
                        List.generate(
                              10,
                              (index) => DateTime.now().year + index,
                            )
                            .map(
                              (y) => DropdownMenuItem(
                                value: y,
                                child: Text(
                                  '$y',
                                  style: const TextStyle(color: Colors.white),
                                ),
                              ),
                            )
                            .toList(),
                    onChanged: (val) {
                      setState(() {
                        _targetExpectedYear = val;
                      });
                      _loadPreview();
                    },
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildPreviewDetails() {
    final recalculated = List<dynamic>.from(
      _previewData!['recalculated_tasks'] ?? [],
    );
    final preserved = List<dynamic>.from(
      _previewData!['preserved_tasks'] ?? [],
    );
    final unresolved = List<dynamic>.from(
      _previewData!['unresolved_tasks'] ?? [],
    );
    final absoluteCount =
        (_previewData!['absolute_tasks_unchanged_count'] ?? 0) as int;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Headers stats
        _buildStatsBar(
          recalculated.length,
          absoluteCount,
          preserved.length,
          unresolved.length,
        ),
        const SizedBox(height: 16),

        // Unresolved tasks list (Precision Loss Warning)
        if (unresolved.isNotEmpty) ...[
          _buildUnresolvedList(unresolved),
          const SizedBox(height: 16),
        ],

        // Recalculated list
        if (recalculated.isNotEmpty) ...[
          _buildRecalculatedList(recalculated),
          const SizedBox(height: 16),
        ],

        // Informational: Absolute tasks remain unchanged (calendar-fixed)
        if (absoluteCount > 0) ...[
          _buildAbsoluteTasksInfo(absoluteCount),
          const SizedBox(height: 16),
        ],

        // Preserved tasks (Completed history)
        if (preserved.isNotEmpty) ...[
          _buildPreservedList(preserved),
          const SizedBox(height: 16),
        ],
      ],
    );
  }

  Widget _buildStatsBar(
    int recalc,
    int absolute,
    int preserved,
    int unresolved,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B).withOpacity(0.5),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Wrap(
        spacing: 16,
        runSpacing: 8,
        alignment: WrapAlignment.spaceEvenly,
        children: [
          _buildStatItem('$recalc', 'Thay đổi', Colors.pinkAccent),
          if (absolute > 0)
            _buildStatItem('$absolute', 'Cố định', Colors.blueAccent),
          _buildStatItem('$preserved', 'Giữ nguyên', Colors.green),
          if (unresolved > 0)
            _buildStatItem('$unresolved', 'Bị gỡ hạn', Colors.redAccent),
        ],
      ),
    );
  }

  Widget _buildStatItem(String count, String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          '$count $label',
          style: const TextStyle(color: Colors.white70, fontSize: 13),
        ),
      ],
    );
  }

  Widget _buildUnresolvedList(List<dynamic> list) {
    return Card(
      color: Colors.redAccent.withOpacity(0.05),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.redAccent.withOpacity(0.2)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(
                  Icons.warning_amber_rounded,
                  color: Colors.redAccent,
                  size: 20,
                ),
                SizedBox(width: 6),
                Text(
                  'Cảnh báo mất mốc ngày chốt',
                  style: TextStyle(
                    color: Colors.redAccent,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            const Text(
              'Các công việc mẫu tương đối sau đây sẽ bị xóa ngày chốt dương lịch do chuyển sang tháng dự kiến:',
              style: TextStyle(color: Colors.white70, fontSize: 12),
            ),
            const Divider(color: Colors.redAccent, height: 16, thickness: 0.1),
            ...list.map(
              (task) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 4.0),
                child: Row(
                  children: [
                    const Icon(
                      Icons.arrow_right,
                      size: 14,
                      color: Colors.redAccent,
                    ),
                    Expanded(
                      child: Text(
                        '${task['name']} (Offset: ${task['date_offset']} ngày)',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecalculatedList(List<dynamic> list) {
    return _buildSectionContainer(
      title: 'Công việc sẽ tự động cập nhật hạn chót',
      icon: Icons.sync_rounded,
      iconColor: Colors.pinkAccent,
      children: list.map((task) {
        final oldDate = task['old_resolved_deadline_at'] != null
            ? (task['old_resolved_deadline_at'] as String)
            : 'Không có';
        final newDate = task['new_resolved_deadline_at'] != null
            ? (task['new_resolved_deadline_at'] as String)
            : 'Chưa rõ';

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 6.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  task['name'] as String,
                  style: const TextStyle(color: Colors.white70, fontSize: 14),
                ),
              ),
              Row(
                children: [
                  Text(
                    oldDate,
                    style: const TextStyle(
                      color: Colors.white38,
                      fontSize: 12,
                      decoration: TextDecoration.lineThrough,
                    ),
                  ),
                  const Icon(
                    Icons.arrow_forward,
                    size: 12,
                    color: Colors.pinkAccent,
                  ),
                  Text(
                    newDate,
                    style: const TextStyle(
                      color: Colors.pinkAccent,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  /// Informational card: USER_ABSOLUTE tasks are calendar-fixed and will not
  /// be shifted or adjusted regardless of the event date transition.
  Widget _buildAbsoluteTasksInfo(int count) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.blueAccent.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blueAccent.withOpacity(0.2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.lock_outline, color: Colors.blueAccent, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$count công việc có hạn cố định',
                  style: const TextStyle(
                    color: Colors.blueAccent,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Các công việc này gắn hạn theo lịch thực (USER_ABSOLUTE) và sẽ không bị thay đổi dù sự kiện đổi ngày hay chuyển độ chính xác.',
                  style: TextStyle(color: Colors.white54, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPreservedList(List<dynamic> list) {
    return _buildSectionContainer(
      title: 'Công việc đã hoàn thành (Bảo lưu mốc)',
      icon: Icons.lock_clock,
      iconColor: Colors.green,
      children: list.map((task) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  task['name'] as String,
                  style: const TextStyle(
                    color: Colors.white38,
                    fontSize: 13,
                    decoration: TextDecoration.lineThrough,
                  ),
                ),
              ),
              Text(
                task['resolved_deadline_at'] != null
                    ? (task['resolved_deadline_at'] as String)
                    : 'Không có hạn',
                style: const TextStyle(color: Colors.green, fontSize: 12),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildSectionContainer({
    required String title,
    required IconData icon,
    required Color iconColor,
    required List<Widget> children,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: iconColor, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
          const Divider(color: Colors.white10, height: 20),
          ...children,
        ],
      ),
    );
  }

  Widget _buildBottomActions() {
    return Container(
      color: const Color(0xFF1E293B),
      padding: const EdgeInsets.all(16),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.white10),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onPressed: _submitting ? null : () => Navigator.pop(context),
                child: const Text('Hủy', style: TextStyle(color: Colors.white)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.pinkAccent,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onPressed: (_previewData == null || _submitting || _loading)
                    ? null
                    : _commitChange,
                child: _submitting
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Text(
                        'Lưu thay đổi',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
