import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../foundation/app_error.dart';
import '../services/create_wedding_draft.dart';
import '../services/supabase_service.dart';
import '../utils/money_text.dart';
import 'home_screen.dart';

class WeddingSelectionScreen extends StatefulWidget {
  const WeddingSelectionScreen({super.key});

  @override
  State<WeddingSelectionScreen> createState() => _WeddingSelectionScreenState();
}

class _WeddingSelectionScreenState extends State<WeddingSelectionScreen> {
  bool _loading = true;
  List<Map<String, dynamic>> _weddings = [];
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadWeddings();
  }

  Future<void> _loadWeddings() async {
    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    try {
      final list = await SupabaseService.instance.fetchMyWeddings();
      setState(() {
        _weddings = list;
        _loading = false;
      });
    } catch (e) {
      final failure = await SupabaseService.instance.handleOperationalError(e);
      if (!mounted || failure.kind == AppErrorKind.authLost) return;
      setState(() {
        _errorMessage = failure.message;
        _loading = false;
      });
    }
  }

  void _selectWedding(String id, String name) async {
    await SupabaseService.instance.saveSelectedWedding(id, name);
    if (mounted) {
      Navigator.of(
        context,
      ).pushReplacement(MaterialPageRoute(builder: (_) => const HomeScreen()));
    }
  }

  void _showCreateWeddingBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const CreateWeddingBottomSheet(),
    ).then((value) {
      if (value == true) {
        _loadWeddings();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: const Color(0xFF0F0C1B),
      appBar: AppBar(
        title: const Text(
          'Select Wedding Workspace',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_rounded, color: Colors.white70),
            onPressed: () async {
              await SupabaseService.instance.signOut();
              if (mounted) {
                Navigator.of(context).pushReplacementNamed('/auth');
              }
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          // Background Glows
          Positioned(
            top: 200,
            left: -100,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF6B4EFF).withOpacity(0.08),
                    blurRadius: 120,
                  ),
                ],
              ),
            ),
          ),

          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Welcome back,',
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: Colors.white60,
                    ),
                  ),
                  Text(
                    SupabaseService.instance.currentUser?.email ?? 'Organizer',
                    style: theme.textTheme.titleLarge?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 32),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Your Weddings',
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                      TextButton.icon(
                        icon: const Icon(Icons.add, size: 18),
                        label: const Text('New Plan'),
                        style: TextButton.styleFrom(
                          foregroundColor: const Color(0xFFFF5E7E),
                        ),
                        onPressed: _showCreateWeddingBottomSheet,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  Expanded(
                    child: _loading
                        ? const Center(
                            child: CircularProgressIndicator(
                              color: Color(0xFF6B4EFF),
                            ),
                          )
                        : _errorMessage != null
                        ? Center(
                            child: Text(
                              _errorMessage!,
                              style: const TextStyle(color: Colors.redAccent),
                              textAlign: TextAlign.center,
                            ),
                          )
                        : _weddings.isEmpty
                        ? _buildEmptyState()
                        : _buildWeddingList(),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.02),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white.withOpacity(0.05)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.workspace_premium_outlined,
              size: 64,
              color: Colors.white.withOpacity(0.2),
            ),
            const SizedBox(height: 16),
            const Text(
              'No Wedding Workspaces Yet',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Create your first wedding to start planning budgets, tasks, and guests.',
              style: TextStyle(color: Colors.white54),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6B4EFF),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: _showCreateWeddingBottomSheet,
              child: const Text('Create Wedding Workspace'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWeddingList() {
    return ListView.separated(
      itemCount: _weddings.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final w = _weddings[index];
        final id = w['id'] as String;
        final name = w['name'] as String;
        final status = w['status'] as String? ?? 'ACTIVE';
        final targetBudget = w['target_budget'] != null
            ? '${w['target_budget']} VND'
            : 'Not set';

        String dateStr = '';
        if (w['exact_date'] != null) {
          dateStr = w['exact_date'] as String;
        } else if (w['expected_year'] != null && w['expected_month'] != null) {
          dateStr = 'Expected: ${w['expected_month']}/${w['expected_year']}';
        }

        return Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.04),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withOpacity(0.08)),
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 20,
              vertical: 12,
            ),
            title: Text(
              name,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
            isThreeLine: true,
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (status != 'ACTIVE')
                    Text(
                      status == 'ARCHIVED'
                          ? 'ARCHIVED · READ ONLY'
                          : 'DELETING · RECOVERY REQUIRED',
                      style: TextStyle(
                        color: status == 'ARCHIVED'
                            ? Colors.amber
                            : Colors.redAccent,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  Row(
                    children: [
                      Icon(
                        Icons.calendar_today_rounded,
                        size: 14,
                        color: Colors.white.withOpacity(0.5),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        dateStr,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.6),
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Icon(
                        Icons.monetization_on_outlined,
                        size: 14,
                        color: Colors.white.withOpacity(0.5),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          targetBudget,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.6),
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            trailing: const Icon(
              Icons.chevron_right_rounded,
              color: Colors.white70,
              size: 28,
            ),
            onTap: () => _selectWedding(id, name),
          ),
        );
      },
    );
  }
}

class CreateWeddingBottomSheet extends StatefulWidget {
  const CreateWeddingBottomSheet({super.key});

  @override
  State<CreateWeddingBottomSheet> createState() =>
      _CreateWeddingBottomSheetState();
}

class _CreateWeddingBottomSheetState extends State<CreateWeddingBottomSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _budgetController = TextEditingController();

  String _culturalContext = 'TUY_CHON';
  bool _useExactDate = true;

  DateTime? _selectedExactDate;
  int? _selectedExpectedYear;
  int? _selectedExpectedMonth;

  bool _submitting = false;
  String? _error;

  // Local unique request_id generated for the form session
  late final String _requestId;

  @override
  void initState() {
    super.initState();
    _requestId = const Uuid().v4();
    final draft = CreateWeddingDraftStore.instance.draft;
    _nameController.text = draft?.name ?? '';
    _budgetController.text = draft?.targetBudget ?? '';
    _culturalContext = draft?.culturalContext ?? 'TUY_CHON';
    _useExactDate = draft?.useExactDate ?? true;
    _selectedExactDate = draft?.exactDate;
    _selectedExpectedYear = draft?.expectedYear ?? DateTime.now().year;
    _selectedExpectedMonth = draft?.expectedMonth ?? DateTime.now().month;
  }

  void _saveDraft() {
    CreateWeddingDraftStore.instance.save(
      CreateWeddingDraft(
        name: _nameController.text,
        targetBudget: _budgetController.text,
        culturalContext: _culturalContext,
        useExactDate: _useExactDate,
        exactDate: _selectedExactDate,
        expectedYear: _selectedExpectedYear,
        expectedMonth: _selectedExpectedMonth,
      ),
    );
  }

  Future<void> _selectExactDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 180)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 3650)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Color(0xFF6B4EFF),
              onPrimary: Colors.white,
              surface: Color(0xFF16122C),
              onSurface: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _selectedExactDate = picked;
      });
      _saveDraft();
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    if (_useExactDate && _selectedExactDate == null) {
      setState(() {
        _error = 'Please select a wedding date';
      });
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });

    final targetBudget = MoneyText.normalizeOptional(_budgetController.text);

    try {
      await SupabaseService.instance.createWedding(
        requestId: _requestId,
        name: _nameController.text.trim(),
        culturalContext: _culturalContext,
        exactDate: _useExactDate ? _selectedExactDate : null,
        expectedYear: _useExactDate ? null : _selectedExpectedYear,
        expectedMonth: _useExactDate ? null : _selectedExpectedMonth,
        targetBudget: targetBudget,
      );
      CreateWeddingDraftStore.instance.clear();

      if (mounted) {
        Navigator.of(context).pop(true);
        // Route to home directly
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const HomeScreen()),
        );
      }
    } catch (e) {
      _saveDraft();
      final failure = await SupabaseService.instance.handleOperationalError(e);
      if (!mounted || failure.kind == AppErrorKind.authLost) return;
      setState(() {
        _error = failure.message;
        _submitting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final theme = Theme.of(context);

    return Container(
      padding: EdgeInsets.only(
        bottom: mediaQuery.viewInsets.bottom,
        left: 24,
        right: 24,
        top: 24,
      ),
      decoration: const BoxDecoration(
        color: Color(0xFF16122C),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Bottomsheet handle
              Center(
                child: Container(
                  width: 48,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              Text(
                'Create New Wedding Workspace',
                style: theme.textTheme.titleLarge?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Provide basic metadata. We will initialize the DB schema context.',
                style: TextStyle(color: Colors.white54, fontSize: 13),
              ),
              const SizedBox(height: 24),

              if (_error != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.redAccent.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.redAccent.withOpacity(0.25),
                    ),
                  ),
                  child: Text(
                    _error!,
                    style: const TextStyle(color: Colors.redAccent),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Name Input
              TextFormField(
                controller: _nameController,
                onChanged: (_) => _saveDraft(),
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Wedding Name (e.g. Anh & Chi)',
                  labelStyle: const TextStyle(color: Colors.white60),
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.02),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: Colors.white.withOpacity(0.08),
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFF6B4EFF)),
                  ),
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'Wedding name is required';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Target Budget
              TextFormField(
                controller: _budgetController,
                onChanged: (_) => _saveDraft(),
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Target Budget (VND)',
                  labelStyle: const TextStyle(color: Colors.white60),
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.02),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: Colors.white.withOpacity(0.08),
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFF6B4EFF)),
                  ),
                ),
                keyboardType: TextInputType.number,
                validator: (value) => MoneyText.validate(value, optional: true),
              ),
              const SizedBox(height: 16),

              // Cultural Context Dropdown
              DropdownButtonFormField<String>(
                value: _culturalContext,
                dropdownColor: const Color(0xFF16122C),
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Cultural Context',
                  labelStyle: const TextStyle(color: Colors.white60),
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.02),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: Colors.white.withOpacity(0.08),
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFF6B4EFF)),
                  ),
                ),
                items: const [
                  DropdownMenuItem(
                    value: 'TUY_CHON',
                    child: Text('Tùy Chọn / Khác'),
                  ),
                  DropdownMenuItem(
                    value: 'VIETNAMESE',
                    child: Text('Truyền thống Việt Nam'),
                  ),
                  DropdownMenuItem(
                    value: 'WESTERN',
                    child: Text('Hiện đại phương Tây'),
                  ),
                ],
                onChanged: (val) {
                  if (val != null) {
                    setState(() {
                      _culturalContext = val;
                    });
                    _saveDraft();
                  }
                },
              ),
              const SizedBox(height: 20),

              // Date Precision Selector Toggle
              Row(
                children: [
                  const Text(
                    'Date Precision:',
                    style: TextStyle(color: Colors.white70),
                  ),
                  const Spacer(),
                  ChoiceChip(
                    label: const Text('Exact Date'),
                    selected: _useExactDate,
                    selectedColor: const Color(0xFF6B4EFF),
                    backgroundColor: Colors.white.withOpacity(0.05),
                    labelStyle: const TextStyle(color: Colors.white),
                    onSelected: (val) {
                      setState(() {
                        _useExactDate = true;
                      });
                      _saveDraft();
                    },
                  ),
                  const SizedBox(width: 8),
                  ChoiceChip(
                    label: const Text('Month/Year'),
                    selected: !_useExactDate,
                    selectedColor: const Color(0xFF6B4EFF),
                    backgroundColor: Colors.white.withOpacity(0.05),
                    labelStyle: const TextStyle(color: Colors.white),
                    onSelected: (val) {
                      setState(() {
                        _useExactDate = false;
                      });
                      _saveDraft();
                    },
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Conditional Date Picker / Month Selector
              if (_useExactDate) ...[
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text(
                    'Selected Date',
                    style: TextStyle(color: Colors.white60, fontSize: 13),
                  ),
                  subtitle: Text(
                    _selectedExactDate != null
                        ? '${_selectedExactDate!.day}/${_selectedExactDate!.month}/${_selectedExactDate!.year}'
                        : 'Select Date...',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  trailing: const Icon(
                    Icons.calendar_month,
                    color: Color(0xFFFF5E7E),
                  ),
                  onTap: _selectExactDate,
                ),
              ] else ...[
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<int>(
                        value: _selectedExpectedMonth,
                        dropdownColor: const Color(0xFF16122C),
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          labelText: 'Expected Month',
                          labelStyle: const TextStyle(color: Colors.white60),
                          filled: true,
                          fillColor: Colors.white.withOpacity(0.02),
                        ),
                        items: List.generate(12, (index) => index + 1)
                            .map(
                              (m) => DropdownMenuItem(
                                value: m,
                                child: Text('Month $m'),
                              ),
                            )
                            .toList(),
                        onChanged: (val) {
                          setState(() {
                            _selectedExpectedMonth = val;
                          });
                          _saveDraft();
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonFormField<int>(
                        value: _selectedExpectedYear,
                        dropdownColor: const Color(0xFF16122C),
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          labelText: 'Expected Year',
                          labelStyle: const TextStyle(color: Colors.white60),
                          filled: true,
                          fillColor: Colors.white.withOpacity(0.02),
                        ),
                        items:
                            List.generate(
                                  10,
                                  (index) => DateTime.now().year + index,
                                )
                                .map(
                                  (y) => DropdownMenuItem(
                                    value: y,
                                    child: Text('$y'),
                                  ),
                                )
                                .toList(),
                        onChanged: (val) {
                          setState(() {
                            _selectedExpectedYear = val;
                          });
                          _saveDraft();
                        },
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 32),

              // Submit Button
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF5E7E),
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(54),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                onPressed: _submitting ? null : _submit,
                child: _submitting
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        'Initialize Plan Workspace',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}
