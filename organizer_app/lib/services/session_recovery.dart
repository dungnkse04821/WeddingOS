import 'package:flutter/foundation.dart';

enum AppSessionStatus { initializing, authenticated, authLost }

class SessionRecoveryController extends ChangeNotifier {
  AppSessionStatus _status = AppSessionStatus.initializing;

  AppSessionStatus get status => _status;

  void markAuthenticated({bool revalidate = false}) {
    if (_status == AppSessionStatus.authenticated && revalidate) {
      notifyListeners();
      return;
    }
    _setStatus(AppSessionStatus.authenticated);
  }

  void requestAccessRevalidation() => notifyListeners();

  void markAuthLost() => _setStatus(AppSessionStatus.authLost);

  void _setStatus(AppSessionStatus value) {
    if (_status == value) return;
    _status = value;
    notifyListeners();
  }
}

enum WeddingAccessDestination { home, selection }

class WeddingAccessResolution {
  const WeddingAccessResolution(this.destination, {this.wedding});

  final WeddingAccessDestination destination;
  final Map<String, dynamic>? wedding;
}

Future<WeddingAccessResolution> resolveSelectedWeddingAccess({
  required String? selectedWeddingId,
  required Future<List<Map<String, dynamic>>> Function() fetchWeddings,
  required Future<void> Function() clearSelection,
  required Future<void> Function(String id, String name) saveSelection,
}) async {
  if (selectedWeddingId == null) {
    return const WeddingAccessResolution(WeddingAccessDestination.selection);
  }

  final weddings = await fetchWeddings();
  Map<String, dynamic>? selected;
  for (final wedding in weddings) {
    if (wedding['id'] == selectedWeddingId) {
      selected = wedding;
      break;
    }
  }
  if (selected == null) {
    await clearSelection();
    return const WeddingAccessResolution(WeddingAccessDestination.selection);
  }

  await saveSelection(selectedWeddingId, selected['name'] as String);
  return WeddingAccessResolution(
    WeddingAccessDestination.home,
    wedding: selected,
  );
}
