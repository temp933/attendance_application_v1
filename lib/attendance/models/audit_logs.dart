class AuditLog {
  final String userName;
  final String actionType;
  final String entity;
  final String entityId;
  final String oldValue;
  final String newValue;
  final String notes;
  final DateTime timestamp;

  AuditLog({
    required this.userName,
    required this.actionType,
    required this.entity,
    required this.entityId,
    this.oldValue = '',
    this.newValue = '',
    this.notes = '',
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();
}
