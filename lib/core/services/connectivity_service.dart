import 'package:connectivity_plus/connectivity_plus.dart';

/// Wraps [connectivity_plus] so the repository can decide online vs offline
/// without importing platform details everywhere.
class ConnectivityService {
  ConnectivityService._();
  static final ConnectivityService instance = ConnectivityService._();

  final Connectivity _connectivity = Connectivity();

  Future<bool> isConnected() async {
    final results = await _connectivity.checkConnectivity();
    return results.any((result) => result != ConnectivityResult.none);
  }
}
