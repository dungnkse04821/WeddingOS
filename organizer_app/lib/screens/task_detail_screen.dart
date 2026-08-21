import 'package:flutter/material.dart';
import '../models/task_model.dart';
import '../services/supabase_service.dart';

class TaskDetailScreen extends StatefulWidget {
  final TaskModel task;
  final List<Map<String, dynamic>> events;
  final List<Map<String, dynamic>> members;

  const TaskDetailScreen({
    super.key,
    required this.task,
    required this.events,
    required this.members,
  });

  @override
  State<TaskDetailScreen> createState() => _TaskDetailScreenState();
}

class _TaskDetailScreenState extends State<TaskDetailScreen> {
  late final TextEditingController _nameController;
  late String _status;
  late String _side;
  late String _deadlineIntent;
  String? _assigneeId;
  String? _eventId;
  int? _dateOffset;
  DateTime? _customOverrideDate;

  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.task.name);
    _status = widget.task.status;
    _side = widget.task.side;
    _deadlineIntent = widget.task.deadlineIntent;
    _assigneeId = widget.task.assigneeWeddingMemberId;
    _eventId = widget.task.weddingEventId;
    _dateOffset = widget.task.dateOffset;
    _customOverrideDate = widget.task.customOverrideDate;
  }

  Future<void> _handleSave() async {
    if (_nameController.text.trim().isEmpty) return;

    setState(() {
      _saving = true;
    });

    try {
      final nameChanged = _nameController.text.trim() != widget.task.name;
      final statusChanged = _status != widget.task.status;
      final sideChanged = _side != widget.task.side;
      final assigneeChanged = _assigneeId != widget.task.assigneeWeddingMemberId;
      final intentChanged = _deadlineIntent != widget.task.deadlineIntent;
      final offsetChanged = _dateOffset != widget.task.dateOffset;
      final dateChanged = _customOverrideDate != widget.task.customOverrideDate;
      final eventChanged = _eventId != widget.task.weddingEventId;

      final coreFieldModified = nameChanged || sideChanged || assigneeChanged || intentChanged || offsetChanged || dateChanged || eventChanged;

      // Build updates map for Class-B update
      final Map<String, dynamic> updates = {
        'name': _nameController.text.trim(),
        'status': _status,
        'side': _side,
        'deadline_intent': _deadlineIntent,
        'assignee_wedding_member_id': _assigneeId,
        'wedding_event_id': _deadlineIntent == 'USER_RELATIVE' || _deadlineIntent == 'SYSTEM_RELATIVE' ? _eventId : null,
        'date_offset': _deadlineIntent == 'USER_RELATIVE' || _deadlineIntent == 'SYSTEM_RELATIVE' ? _dateOffset : null,
        'custom_override_date': _deadlineIntent == 'USER_ABSOLUTE' ? _customOverrideDate?.toIso8601String().split('T').first : null,
      };

      await SupabaseService.instance.client
          .from('tasks')
          .update(updates)
          .eq('id', widget.task.id);

      // Determine activation event type to notify user
      String? triggerMessage;
      if (statusChanged) {
        if (_status == 'COMPLETED') {
          triggerMessage = 'TASK_COMPLETED';
        } else if (_status == 'IN_PROGRESS') {
          triggerMessage = 'TASK_STARTED';
        } else if (_status == 'CANCELLED') {
          triggerMessage = 'SUGGESTION_REMOVED';
        }
      } else if (coreFieldModified) {
        triggerMessage = 'TASK_CUSTOMIZED';
      }

      if (mounted) {
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(triggerMessage != null 
                ? 'Planning action: $triggerMessage (Task changes committed successfully)' 
                : 'Task updated successfully.'),
            backgroundColor: const Color(0xFF6B4EFF),
          ),
        );
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save task: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0C1B),
      appBar: AppBar(
        title: const Text('Edit Preparation Step', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          if (_saving)
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 16.0),
                child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
              ),
            )
          else
            TextButton(
              onPressed: _handleSave,
              child: const Text('SAVE', style: TextStyle(color: Color(0xFFFF5E7E), fontWeight: FontWeight.bold)),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Provenance banner if system task
            if (widget.task.taskSource == 'SYSTEM_TEMPLATE') ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF6B4EFF).withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF6B4EFF).withOpacity(0.2)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.auto_awesome_rounded, color: Color(0xFFFF5E7E), size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        widget.task.isUserModified 
                            ? 'System template task (Customized by you)'
                            : 'Original System template task (modifying details will mark it customized)',
                        style: const TextStyle(color: Colors.white70, fontSize: 11),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
            ],

            // Task Name
            const Text('Task Title', style: TextStyle(color: Colors.white38, fontSize: 12, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            TextField(
              controller: _nameController,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              decoration: InputDecoration(
                filled: true,
                fillColor: Colors.white.withOpacity(0.02),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.white10)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF6B4EFF))),
              ),
            ),
            const SizedBox(height: 20),

            // Status Row
            const Text('Status', style: TextStyle(color: Colors.white38, fontSize: 12, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              dropdownColor: const Color(0xFF161226),
              value: _status,
              decoration: InputDecoration(
                filled: true,
                fillColor: Colors.white.withOpacity(0.02),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              items: const [
                DropdownMenuItem(value: 'TODO', child: Text('To Do', style: TextStyle(color: Colors.white))),
                DropdownMenuItem(value: 'IN_PROGRESS', child: Text('In Progress', style: TextStyle(color: Colors.white))),
                DropdownMenuItem(value: 'COMPLETED', child: Text('Completed', style: TextStyle(color: Colors.white))),
                DropdownMenuItem(value: 'CANCELLED', child: Text('Cancelled (Soft Delete)', style: TextStyle(color: Colors.white))),
              ],
              onChanged: (val) => setState(() => _status = val!),
            ),
            const SizedBox(height: 20),

            // Side Selector
            const Text('Side Assignment', style: TextStyle(color: Colors.white38, fontSize: 12, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              dropdownColor: const Color(0xFF161226),
              value: _side,
              decoration: InputDecoration(
                filled: true,
                fillColor: Colors.white.withOpacity(0.02),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              items: const [
                DropdownMenuItem(value: 'COMMON', child: Text('Common / Shared', style: TextStyle(color: Colors.white))),
                DropdownMenuItem(value: 'BRIDE_SIDE', child: Text("Bride's Side", style: TextStyle(color: Colors.white))),
                DropdownMenuItem(value: 'GROOM_SIDE', child: Text("Groom's Side", style: TextStyle(color: Colors.white))),
              ],
              onChanged: (val) => setState(() => _side = val!),
            ),
            const SizedBox(height: 20),

            // Assignee Selector
            const Text('Assignee (Active Members Only)', style: TextStyle(color: Colors.white38, fontSize: 12, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            DropdownButtonFormField<String?>(
              dropdownColor: const Color(0xFF161226),
              value: _assigneeId,
              decoration: InputDecoration(
                filled: true,
                fillColor: Colors.white.withOpacity(0.02),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              items: [
                const DropdownMenuItem(value: null, child: Text('Unassigned', style: TextStyle(color: Colors.white38))),
                ...widget.members.map((m) {
                  return DropdownMenuItem(
                    value: m['id'] as String,
                    child: Text(m['display_name'] as String, style: const TextStyle(color: Colors.white)),
                  );
                }),
              ],
              onChanged: (val) => setState(() => _assigneeId = val),
            ),
            const SizedBox(height: 20),

            // Deadline Intent
            const Text('Deadline Mode', style: TextStyle(color: Colors.white38, fontSize: 12, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              dropdownColor: const Color(0xFF161226),
              value: _deadlineIntent,
              decoration: InputDecoration(
                filled: true,
                fillColor: Colors.white.withOpacity(0.02),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              items: const [
                DropdownMenuItem(value: 'NO_DEADLINE', child: Text('No Deadline', style: TextStyle(color: Colors.white))),
                DropdownMenuItem(value: 'USER_ABSOLUTE', child: Text('Custom Date (Absolute)', style: TextStyle(color: Colors.white))),
                DropdownMenuItem(value: 'USER_RELATIVE', child: Text('Relative to Main Event', style: TextStyle(color: Colors.white))),
                DropdownMenuItem(value: 'SYSTEM_RELATIVE', child: Text('System Relative', style: TextStyle(color: Colors.white))),
              ],
              onChanged: (val) => setState(() {
                _deadlineIntent = val!;
                if (_deadlineIntent == 'USER_RELATIVE' && _dateOffset == null) {
                  _dateOffset = -30;
                }
              }),
            ),
            const SizedBox(height: 20),

            // Relative controls or Pick Absolute controls
            if (_deadlineIntent == 'USER_ABSOLUTE') ...[
              const Text('Absolute Deadline Date', style: TextStyle(color: Colors.white38, fontSize: 12, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              InkWell(
                onTap: () async {
                  final date = await showDatePicker(
                    context: context,
                    initialDate: _customOverrideDate ?? DateTime.now().add(const Duration(days: 90)),
                    firstDate: DateTime.now().subtract(const Duration(days: 365)),
                    lastDate: DateTime.now().add(const Duration(days: 730)),
                  );
                  if (date != null) {
                    setState(() => _customOverrideDate = date);
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.02),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white10),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.calendar_month_rounded, color: Color(0xFFFF5E7E), size: 18),
                      const SizedBox(width: 12),
                      Text(
                        _customOverrideDate == null
                            ? 'Not selected'
                            : '${_customOverrideDate!.day}/${_customOverrideDate!.month}/${_customOverrideDate!.year}',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],

            if (_deadlineIntent == 'USER_RELATIVE' || _deadlineIntent == 'SYSTEM_RELATIVE') ...[
              const Text('Target Event Link', style: TextStyle(color: Colors.white38, fontSize: 12, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              DropdownButtonFormField<String?>(
                dropdownColor: const Color(0xFF161226),
                value: _eventId,
                decoration: InputDecoration(
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.02),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                items: widget.events.map((e) {
                  return DropdownMenuItem(
                    value: e['id'] as String,
                    child: Text(e['name'] as String, style: const TextStyle(color: Colors.white)),
                  );
                }).toList(),
                onChanged: (val) => setState(() => _eventId = val),
              ),
              const SizedBox(height: 20),

              const Text('Date Offset (Days relative to Event)', style: TextStyle(color: Colors.white38, fontSize: 12, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              TextFormField(
                initialValue: _dateOffset?.toString() ?? '0',
                keyboardType: TextInputType.number,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.02),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onChanged: (val) {
                  final parsed = int.tryParse(val);
                  if (parsed != null) {
                    _dateOffset = parsed;
                  }
                },
              ),
              const SizedBox(height: 20),
            ],
          ],
        ),
      ),
    );
  }
}
