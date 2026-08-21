import 'package:flutter/material.dart';
import '../models/task_model.dart';
import '../services/supabase_service.dart';
import 'task_detail_screen.dart';
import 'event_date_change_preview_screen.dart';
import 'event_removal_preview_screen.dart';

class PlanningScreen extends StatefulWidget {
  final String weddingId;
  const PlanningScreen({super.key, required this.weddingId});

  @override
  State<PlanningScreen> createState() => _PlanningScreenState();
}

class _PlanningScreenState extends State<PlanningScreen> {
  bool _loading = true;
  bool _generating = false;
  Map<String, dynamic>? _wedding;
  List<TaskModel> _tasks = [];
  List<Map<String, dynamic>> _events = [];
  List<Map<String, dynamic>> _members = [];
  String? _errorMessage;

  // Search & Filter state
  String _searchQuery = '';
  String _statusFilter = 'ALL'; // ALL, TODO, IN_PROGRESS, COMPLETED, CANCELLED
  String _sideFilter = 'ALL'; // ALL, COMMON, BRIDE_SIDE, GROOM_SIDE

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    try {
      final wList = await SupabaseService.instance.fetchMyWeddings();
      final currentWedding = wList.firstWhere((w) => w['id'] == widget.weddingId);
      
      final eventList = await SupabaseService.instance.fetchWeddingEvents(widget.weddingId);
      final memberList = await SupabaseService.instance.client
          .from('wedding_members')
          .select('id, display_name, profile_email, role, status')
          .eq('wedding_id', widget.weddingId)
          .eq('status', 'ACTIVE');

      List<TaskModel> taskList = [];
      if (currentWedding['initial_plan_generated_at'] != null) {
        taskList = await SupabaseService.instance.fetchTasks(widget.weddingId);
      }

      setState(() {
        _wedding = currentWedding;
        _events = List<Map<String, dynamic>>.from(eventList);
        _members = List<Map<String, dynamic>>.from(memberList);
        _tasks = taskList;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load plan: $e';
        _loading = false;
      });
    }
  }

  Future<void> _handleGeneratePlan() async {
    setState(() {
      _generating = true;
    });

    try {
      // 1. Verify if there is a main event
      final mainEvent = _events.firstWhere(
        (e) => e['is_main_event'] == true,
        orElse: () => {},
      );

      if (mainEvent.isEmpty) {
        // Create a default Main Event if none configured yet to satisfy constraint
        final exactDate = _wedding!['exact_date'] != null
            ? DateTime.parse(_wedding!['exact_date'] as String)
            : null;
        final expectedYear = _wedding!['expected_year'] as int?;
        final expectedMonth = _wedding!['expected_month'] as int?;

        await SupabaseService.instance.createMainEvent(
          weddingId: widget.weddingId,
          name: 'Lễ cưới chính',
          exactDate: exactDate,
          expectedYear: expectedYear,
          expectedMonth: expectedMonth,
        );

        // Reload event list
        final eventList = await SupabaseService.instance.fetchWeddingEvents(widget.weddingId);
        setState(() {
          _events = List<Map<String, dynamic>>.from(eventList);
        });
      }

      // 2. Call initial plan generation RPC
      final result = await SupabaseService.instance.generateInitialPlan(widget.weddingId);
      final replayed = result['replayed'] as bool? ?? false;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(replayed 
              ? 'Replayed cached initial plan tasks successfully.' 
              : 'Initial plan generated from deterministic templates!'),
          backgroundColor: const Color(0xFF6B4EFF),
        ),
      );

      await _loadData();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to generate plan: $e'),
          backgroundColor: Colors.redAccent,
        ),
      );
    } finally {
      setState(() {
        _generating = false;
      });
    }
  }

  Future<void> _toggleTaskStatus(TaskModel task) async {
    String nextStatus;
    String toastEvent;
    
    if (task.status == 'TODO') {
      nextStatus = 'IN_PROGRESS';
      toastEvent = 'TASK_STARTED';
    } else if (task.status == 'IN_PROGRESS') {
      nextStatus = 'COMPLETED';
      toastEvent = 'TASK_COMPLETED';
    } else {
      nextStatus = 'TODO';
      toastEvent = 'TASK_REOPENED';
    }

    try {
      await SupabaseService.instance.updateTaskStatus(task.id, nextStatus);
      
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Planning action: $toastEvent (Task status updated to $nextStatus)'),
          backgroundColor: const Color(0xFF6B4EFF),
          duration: const Duration(seconds: 2),
        ),
      );

      await _loadData();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to update status: $e'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  Future<void> _navigateToDateChangePreview(Map<String, dynamic> event) async {
    final result = await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => EventDateChangePreviewScreen(event: event),
      ),
    );
    if (result != null) {
      _loadData();
    }
  }

  Future<void> _navigateToRemovalPreview(Map<String, dynamic> event) async {
    final result = await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => EventRemovalPreviewScreen(event: event),
      ),
    );
    if (result != null) {
      _loadData();
    }
  }

  Future<void> _handleAddTask() async {
    // Show add task dialog
    final nameController = TextEditingController();
    String side = 'COMMON';
    String deadlineIntent = 'NO_DEADLINE';
    String? selectedEventId;
    int? dateOffset;
    DateTime? selectedDate;

    final mainEvent = _events.firstWhere((e) => e['is_main_event'] == true, orElse: () => {});
    if (mainEvent.isNotEmpty) {
      selectedEventId = mainEvent['id'] as String;
    }

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF161226),
              title: const Text('Add Custom Task', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameController,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        labelText: 'Task Name',
                        labelStyle: TextStyle(color: Colors.white60),
                        enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                        focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFF6B4EFF))),
                      ),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      dropdownColor: const Color(0xFF161226),
                      value: side,
                      decoration: const InputDecoration(labelText: 'Side', labelStyle: TextStyle(color: Colors.white60)),
                      items: const [
                        DropdownMenuItem(value: 'COMMON', child: Text('Common / Shared', style: TextStyle(color: Colors.white))),
                        DropdownMenuItem(value: 'BRIDE_SIDE', child: Text("Bride's Side", style: TextStyle(color: Colors.white))),
                        DropdownMenuItem(value: 'GROOM_SIDE', child: Text("Groom's Side", style: TextStyle(color: Colors.white))),
                      ],
                      onChanged: (val) => setDialogState(() => side = val!),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      dropdownColor: const Color(0xFF161226),
                      value: deadlineIntent,
                      decoration: const InputDecoration(labelText: 'Deadline Intent', labelStyle: TextStyle(color: Colors.white60)),
                      items: const [
                        DropdownMenuItem(value: 'NO_DEADLINE', child: Text('No Deadline', style: TextStyle(color: Colors.white))),
                        DropdownMenuItem(value: 'USER_ABSOLUTE', child: Text('Custom Date (Absolute)', style: TextStyle(color: Colors.white))),
                        DropdownMenuItem(value: 'USER_RELATIVE', child: Text('Relative to Main Event', style: TextStyle(color: Colors.white))),
                      ],
                      onChanged: (val) => setDialogState(() {
                        deadlineIntent = val!;
                        if (deadlineIntent == 'USER_RELATIVE') {
                          dateOffset = -30; // default offset
                        }
                      }),
                    ),
                    if (deadlineIntent == 'USER_ABSOLUTE') ...[
                      const SizedBox(height: 16),
                      TextButton(
                        onPressed: () async {
                          final date = await showDatePicker(
                            context: context,
                            initialDate: DateTime.now().add(const Duration(days: 90)),
                            firstDate: DateTime.now(),
                            lastDate: DateTime.now().add(const Duration(days: 730)),
                          );
                          if (date != null) {
                            setDialogState(() => selectedDate = date);
                          }
                        },
                        child: Text(
                          selectedDate == null 
                              ? 'Pick Absolute Date' 
                              : 'Selected: ${selectedDate!.toIso8601String().split('T').first}',
                          style: const TextStyle(color: Color(0xFFFF5E7E)),
                        ),
                      ),
                    ],
                    if (deadlineIntent == 'USER_RELATIVE') ...[
                      const SizedBox(height: 16),
                      TextFormField(
                        initialValue: '-30',
                        keyboardType: TextInputType.number,
                        style: const TextStyle(color: Colors.white),
                        decoration: const InputDecoration(
                          labelText: 'Offset Days (e.g. -30 for 30 days before event)',
                          labelStyle: TextStyle(color: Colors.white60),
                        ),
                        onChanged: (val) {
                          final parsed = int.tryParse(val);
                          if (parsed != null) {
                            dateOffset = parsed;
                          }
                        },
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel', style: TextStyle(color: Colors.white38)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6B4EFF),
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () async {
                    if (nameController.text.trim().isEmpty) return;
                    Navigator.of(context).pop(true);
                  },
                  child: const Text('Create'),
                ),
              ],
            );
          },
        );
      },
    );

    if (nameController.text.trim().isEmpty) return;

    try {
      await SupabaseService.instance.createCustomTask(
        weddingId: widget.weddingId,
        name: nameController.text.trim(),
        deadlineIntent: deadlineIntent,
        dateOffset: dateOffset,
        customOverrideDate: selectedDate,
        weddingEventId: deadlineIntent == 'USER_RELATIVE' ? selectedEventId : null,
        side: side,
      );

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Planning action: TASK_CREATED (Custom task "${nameController.text.trim()}" added)'),
          backgroundColor: const Color(0xFF6B4EFF),
        ),
      );

      await _loadData();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to create task: $e'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: const Color(0xFF0F0C1B),
      appBar: AppBar(
        title: const Text('Wedding Planning Checklist', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF6B4EFF)))
          : _errorMessage != null
              ? _buildErrorState()
              : _wedding!['initial_plan_generated_at'] == null
                  ? _buildGeneratePlanPrompt()
                  : _buildTaskDashboard(theme),
      floatingActionButton: _wedding != null && _wedding!['initial_plan_generated_at'] != null
          ? FloatingActionButton(
              backgroundColor: const Color(0xFFFF5E7E),
              foregroundColor: Colors.white,
              onPressed: _handleAddTask,
              child: const Icon(Icons.add_rounded),
            )
          : null,
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline_rounded, size: 64, color: Colors.redAccent),
            const SizedBox(height: 16),
            Text(_errorMessage!, style: const TextStyle(color: Colors.redAccent), textAlign: TextAlign.center),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _loadData,
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6B4EFF)),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGeneratePlanPrompt() {
    final culturalContext = _wedding!['cultural_context'] as String? ?? 'TUY_CHON';
    String templateDesc = 'Custom general template with 5 core steps';
    if (culturalContext == 'VIETNAMESE') {
      templateDesc = 'Traditional Vietnamese templates: 7 cultural preparation events & tasks (Lễ dạm ngõ, mâm quả sính lễ, thiệp mời, nhà hàng, chuẩn bị MC)';
    } else if (culturalContext == 'WESTERN') {
      templateDesc = 'Modern Western templates: 5 scheduling steps (Venue book, Guest list, fitting, RSVPs & Rehearsal synced)';
    }

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Container(
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.02),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: Colors.white.withOpacity(0.06)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF6B4EFF).withOpacity(0.1),
                ),
                child: const Icon(Icons.auto_awesome_rounded, color: Color(0xFFFF5E7E), size: 48),
              ),
              const SizedBox(height: 24),
              const Text(
                'Generate Initial Plan',
                style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                'Establish a reliable, server-side deterministic roadmap aligned with your cultural settings.',
                style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 13, height: 1.4),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.02),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    Text(
                      'Cultural Config: $culturalContext',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      templateDesc,
                      style: const TextStyle(color: Colors.white38, fontSize: 11),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6B4EFF),
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 54),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 0,
                ),
                onPressed: _generating ? null : _handleGeneratePlan,
                child: _generating
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.flash_on_rounded, size: 20),
                          SizedBox(width: 8),
                          Text('Build My Wedding Roadmap', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEventsSection(ThemeData theme) {
    if (_events.isEmpty) return const SizedBox.shrink();

    return Container(
      height: 95,
      padding: const EdgeInsets.only(bottom: 12, top: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF161226).withOpacity(0.3),
        border: const Border(bottom: BorderSide(color: Colors.white10)),
      ),
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        itemCount: _events.length,
        itemBuilder: (context, index) {
          final event = _events[index];
          final isMain = event['is_main_event'] == true;
          
          return Container(
            width: 220,
            margin: const EdgeInsets.only(right: 12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.04),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isMain ? Colors.pinkAccent.withOpacity(0.3) : Colors.white10,
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        event['name'] as String,
                        style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        event['exact_date'] != null
                            ? (event['exact_date'] as String)
                            : 'Tháng ${event['expected_month']}/${event['expected_year']}',
                        style: TextStyle(
                          color: isMain ? Colors.pinkAccent : Colors.white54,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit_calendar_rounded, size: 16, color: Colors.blueAccent),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: () => _navigateToDateChangePreview(event),
                    ),
                    const SizedBox(height: 8),
                    IconButton(
                      icon: const Icon(Icons.delete_outline_rounded, size: 16, color: Colors.redAccent),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: () => _navigateToRemovalPreview(event),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildTaskDashboard(ThemeData theme) {
    // 1. Apply filtering & search
    final filtered = _tasks.where((t) {
      final nameMatches = t.name.toLowerCase().contains(_searchQuery.toLowerCase());
      final statusMatches = _statusFilter == 'ALL' || t.status == _statusFilter;
      final sideMatches = _sideFilter == 'ALL' || t.side == _sideFilter;
      return nameMatches && statusMatches && sideMatches;
    }).toList();

    // 2. Sort by resolvedDeadlineAt (overdue / nearest first, then null deadlines at the bottom)
    filtered.sort((a, b) {
      if (a.resolvedDeadlineAt != null && b.resolvedDeadlineAt != null) {
        return a.resolvedDeadlineAt!.compareTo(b.resolvedDeadlineAt!);
      }
      if (a.resolvedDeadlineAt != null) return -1;
      if (b.resolvedDeadlineAt != null) return 1;
      return a.name.compareTo(b.name);
    });

    return Column(
      children: [
        _buildEventsSection(theme),
        // Search & Filter Panel
        Container(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          decoration: BoxDecoration(
            color: const Color(0xFF161226).withOpacity(0.5),
            border: const Border(bottom: BorderSide(color: Colors.white10)),
          ),
          child: Column(
            children: [
              // Search input
              TextField(
                onChanged: (val) => setState(() => _searchQuery = val),
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Search preparation tasks...',
                  hintStyle: const TextStyle(color: Colors.white30),
                  prefixIcon: const Icon(Icons.search_rounded, color: Colors.white30),
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.03),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: Colors.white.withOpacity(0.08)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: Color(0xFF6B4EFF)),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              // Filter chips (status & side)
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildFilterChip('ALL', 'All Tasks', true),
                    _buildFilterChip('TODO', 'To Do', true),
                    _buildFilterChip('IN_PROGRESS', 'In Progress', true),
                    _buildFilterChip('COMPLETED', 'Completed', true),
                    const SizedBox(width: 16),
                    Container(width: 1, height: 24, color: Colors.white24),
                    const SizedBox(width: 16),
                    _buildFilterChip('ALL', 'All Sides', false),
                    _buildFilterChip('COMMON', 'Common', false),
                    _buildFilterChip('BRIDE_SIDE', "Bride's Side", false),
                    _buildFilterChip('GROOM_SIDE', "Groom's Side", false),
                  ],
                ),
              ),
            ],
          ),
        ),

        // Tasks Checklist
        Expanded(
          child: filtered.isEmpty
              ? Center(
                  child: Text(
                    'No tasks match active search/filters.',
                    style: TextStyle(color: Colors.white.withOpacity(0.3)),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final task = filtered[index];
                    return _buildTaskTile(task);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildFilterChip(String value, String label, bool isStatus) {
    final activeValue = isStatus ? _statusFilter : _sideFilter;
    final isSelected = activeValue == value;

    return Padding(
      padding: const EdgeInsets.only(right: 6.0),
      child: ChoiceChip(
        selected: isSelected,
        label: Text(label, style: TextStyle(fontSize: 12, color: isSelected ? Colors.white : Colors.white60)),
        backgroundColor: Colors.transparent,
        selectedColor: const Color(0xFF6B4EFF),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: isSelected ? Colors.transparent : Colors.white10),
        ),
        onSelected: (val) {
          if (val) {
            setState(() {
              if (isStatus) {
                _statusFilter = value;
              } else {
                _sideFilter = value;
              }
            });
          }
        },
      ),
    );
  }

  Widget _buildTaskTile(TaskModel task) {
    // Format deadline label
    String deadlineStr = 'No deadline';
    if (task.resolvedDeadlineAt != null) {
      final date = task.resolvedDeadlineAt!;
      deadlineStr = '${date.day}/${date.month}/${date.year}';
      if (task.dateOffset != null) {
        deadlineStr += ' (T${task.dateOffset! >= 0 ? '+' : ''}${task.dateOffset} days)';
      }
    } else if (task.weddingEventId != null && task.dateOffset != null) {
      final linkedEvent = _events.firstWhere((e) => e['id'] == task.weddingEventId, orElse: () => {});
      if (linkedEvent.isNotEmpty) {
        final name = linkedEvent['name'] as String? ?? 'Event';
        if (linkedEvent['expected_month'] != null && linkedEvent['expected_year'] != null) {
          deadlineStr = 'T${task.dateOffset! >= 0 ? '+' : ''}${task.dateOffset}d rel. to $name (Exp: ${linkedEvent['expected_month']}/${linkedEvent['expected_year']})';
        } else {
          deadlineStr = 'T${task.dateOffset! >= 0 ? '+' : ''}${task.dateOffset}d rel. to $name';
        }
      }
    }

    final isOverdue = task.isOverdue;
    Color statusColor = Colors.white54;
    IconData statusIcon = Icons.circle_outlined;

    if (task.isCompleted) {
      statusColor = Colors.greenAccent;
      statusIcon = Icons.check_circle_rounded;
    } else if (task.isInProgress) {
      statusColor = const Color(0xFFFF5E7E);
      statusIcon = Icons.pending_rounded;
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.02),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isOverdue 
              ? Colors.redAccent.withOpacity(0.2) 
              : Colors.white.withOpacity(0.04),
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        leading: IconButton(
          icon: Icon(statusIcon, color: statusColor, size: 24),
          onPressed: () => _toggleTaskStatus(task),
        ),
        title: Text(
          task.name,
          style: TextStyle(
            color: task.isCompleted ? Colors.white30 : Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 14,
            decoration: task.isCompleted ? TextDecoration.lineThrough : null,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 6.0),
          child: Row(
            children: [
              Icon(Icons.calendar_month_rounded, size: 12, color: isOverdue ? Colors.redAccent : Colors.white30),
              const SizedBox(width: 4),
              Text(
                deadlineStr,
                style: TextStyle(
                  color: isOverdue ? Colors.redAccent : Colors.white30,
                  fontSize: 11,
                  fontWeight: isOverdue ? FontWeight.bold : null,
                ),
              ),
              const SizedBox(width: 12),
              Container(width: 3, height: 3, decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.white12)),
              const SizedBox(width: 12),
              Text(
                task.side,
                style: const TextStyle(color: Colors.white24, fontSize: 11),
              ),
            ],
          ),
        ),
        trailing: const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white24, size: 14),
        onTap: () async {
          final changed = await Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => TaskDetailScreen(
                task: task,
                events: _events,
                members: _members,
              ),
            ),
          );
          if (changed == true) {
            _loadData();
          }
        },
      ),
    );
  }
}
