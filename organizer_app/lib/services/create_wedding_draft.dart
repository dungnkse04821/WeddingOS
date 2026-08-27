class CreateWeddingDraft {
  const CreateWeddingDraft({
    this.name = '',
    this.targetBudget = '',
    this.culturalContext = 'TUY_CHON',
    this.useExactDate = true,
    this.exactDate,
    this.expectedYear,
    this.expectedMonth,
  });

  final String name;
  final String targetBudget;
  final String culturalContext;
  final bool useExactDate;
  final DateTime? exactDate;
  final int? expectedYear;
  final int? expectedMonth;
}

class CreateWeddingDraftStore {
  CreateWeddingDraftStore._();

  static final instance = CreateWeddingDraftStore._();

  CreateWeddingDraft? _draft;

  CreateWeddingDraft? get draft => _draft;

  void save(CreateWeddingDraft draft) => _draft = draft;

  void clear() => _draft = null;
}
