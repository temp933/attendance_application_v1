// ─────────────────────────────────────────────────────────────────────────────
// dept_role_desg_models.dart
// Models: DepartmentModel | DesignationModel | RoleModel
// ─────────────────────────────────────────────────────────────────────────────

// ═══════════════════════════════════════════════════════════════════════════════
// DEPARTMENT MODEL
// ═══════════════════════════════════════════════════════════════════════════════
class DepartmentModel {
  final int id;
  final String departmentName;
  final String status;
  final String? createdAt;
  final String? updatedAt;

  const DepartmentModel({
    required this.id,
    required this.departmentName,
    required this.status,
    this.createdAt,
    this.updatedAt,
  });

  factory DepartmentModel.fromJson(Map<String, dynamic> json) {
    return DepartmentModel(
      id: json['id'] as int,
      departmentName: json['department_name'] as String? ?? '',
      status: json['status'] as String? ?? 'Active',
      createdAt: json['created_at']?.toString(),
      updatedAt: json['updated_at']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
    'department_name': departmentName,
    'status': status,
  };

  /// Returns a copy with updated fields
  DepartmentModel copyWith({
    String? departmentCode,
    String? departmentName,
    String? status,
  }) {
    return DepartmentModel(
      id: id,
      departmentName: departmentName ?? this.departmentName,
      status: status ?? this.status,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// DESIGNATION MODEL
// ═══════════════════════════════════════════════════════════════════════════════
class DesignationModel {
  final int id;
  final String designationCode;
  final String designationName;
  final int departmentId;
  final String departmentName; // joined from department_master
  final String status;
  final String? createdAt;
  final String? updatedAt;

  const DesignationModel({
    required this.id,
    required this.designationCode,
    required this.designationName,
    required this.departmentId,
    required this.departmentName,
    required this.status,
    this.createdAt,
    this.updatedAt,
  });

  factory DesignationModel.fromJson(Map<String, dynamic> json) {
    return DesignationModel(
      id: json['id'] as int,
      designationCode: json['designation_code'] as String? ?? '',
      designationName: json['designation_name'] as String? ?? '',
      departmentId: json['department_id'] as int? ?? 0,
      departmentName: json['department_name'] as String? ?? '',
      status: json['status'] as String? ?? 'Active',
      createdAt: json['created_at']?.toString(),
      updatedAt: json['updated_at']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
    'designation_code': designationCode,
    'designation_name': designationName,
    'department_id': departmentId,
    'status': status,
  };

  DesignationModel copyWith({
    String? designationCode,
    String? designationName,
    int? departmentId,
    String? departmentName,
    String? status,
  }) {
    return DesignationModel(
      id: id,
      designationCode: designationCode ?? this.designationCode,
      designationName: designationName ?? this.designationName,
      departmentId: departmentId ?? this.departmentId,
      departmentName: departmentName ?? this.departmentName,
      status: status ?? this.status,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// ROLE MODEL
// ═══════════════════════════════════════════════════════════════════════════════
class RoleModel {
  final int id;
  final String roleCode;
  final String roleName;
  final String status;
  final String? createdAt;
  final String? updatedAt;
  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is RoleModel && other.id == id);

  @override
  int get hashCode => id.hashCode;
  const RoleModel({
    required this.id,
    required this.roleCode,
    required this.roleName,
    required this.status,
    this.createdAt,
    this.updatedAt,
  });

  factory RoleModel.fromJson(Map<String, dynamic> json) {
    return RoleModel(
      id: json['id'] as int,
      roleCode: json['role_code'] as String? ?? '',
      roleName: json['role_name'] as String? ?? '',
      status: json['status'] as String? ?? 'Active',
      createdAt: json['created_at']?.toString(),
      updatedAt: json['updated_at']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
    'role_code': roleCode,
    'role_name': roleName,
    'status': status,
  };

  RoleModel copyWith({String? roleCode, String? roleName, String? status}) {
    return RoleModel(
      id: id,
      roleCode: roleCode ?? this.roleCode,
      roleName: roleName ?? this.roleName,
      status: status ?? this.status,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }
}

class RolePermissionModule {
  final String moduleKey;
  final String label;
  bool canView;
  bool canEdit;

  RolePermissionModule({
    required this.moduleKey,
    required this.label,
    required this.canView,
    required this.canEdit,
  });

  factory RolePermissionModule.fromJson(Map<String, dynamic> j) =>
      RolePermissionModule(
        moduleKey: j['module_key'] as String,
        label: j['label'] as String,
        canView: j['can_view'] == 1 || j['can_view'] == true,
        canEdit: j['can_edit'] == 1 || j['can_edit'] == true,
      );

  Map<String, dynamic> toJson() => {
    'module_key': moduleKey,
    'can_view': canView,
    'can_edit': canEdit,
  };
}
