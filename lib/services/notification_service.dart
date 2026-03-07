// Notifications temporarily disabled due to Gradle compatibility issues.
// Will be re-added in a future update.
class NotificationService {
  static final NotificationService instance = NotificationService._();
  NotificationService._();

  Future<void> init() async {}
  Future<void> setEnabled(bool enabled) async {}
  Future<bool> isEnabled() async => false;
}