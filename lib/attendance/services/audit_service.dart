import '../models/audit_logs.dart';

class AuditService {
  // In-memory list of logs
  final List<AuditLog> _logs = [];

  // Get all logs
  List<AuditLog> get logs => List.unmodifiable(_logs);

  // Add a new log
  void addLog({
    required String userName,
    required String actionType,
    required String entity,
    required String entityId,
    String oldValue = '',
    String newValue = '',
    String notes = '',
  }) {
    final log = AuditLog(
      userName: userName,
      actionType: actionType,
      entity: entity,
      entityId: entityId,
      oldValue: oldValue,
      newValue: newValue,
      notes: notes,
    );
    _logs.add(log);
  }

  // Optional: clear logs
  void clearLogs() {
    _logs.clear();
  }
}
