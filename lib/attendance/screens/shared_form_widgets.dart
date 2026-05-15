import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// ─── THEME CONSTANTS ──────────────────────────────────────────────────────────
const _kPrimary = Color(0xFF1A237E);
const _kAccent = Color(0xFF00ACC1);
const _kSurface = Color(0xFFF5F7FA);
const _kBorder = Color(0xFFE0E4EF);
const _kTextDark = Color(0xFF1C1F2E);
const _kTextMid = Color(0xFF5A6282);
const _kTextLight = Color(0xFF9EA3B8);

const _kEduLevels = ['10', '12', 'Diploma', 'UG', 'PG'];

class FormTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final bool required;
  final bool optional;
  final String fieldType;
  final bool readOnly;
  final VoidCallback? onTap;
  final String? Function(String?)? validator;
  final EdgeInsets padding;

  const FormTextField(
    this.controller,
    this.label, {
    super.key,
    this.required = false,
    this.optional = false,
    this.fieldType = 'text',
    this.readOnly = false,
    this.onTap,
    this.validator,
    this.padding = const EdgeInsets.only(bottom: 12),
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: TextFormField(
        controller: controller,
        readOnly: readOnly,
        keyboardType: _keyboardType(),
        inputFormatters: _formatters(),
        onTap: onTap,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
        validator: validator ?? _defaultValidator,
      ),
    );
  }

  TextInputType _keyboardType() {
    switch (fieldType) {
      case 'phone':
      case 'aadhar':
      case 'yoe':
      case 'password':
        return TextInputType.number;
      case 'email':
        return TextInputType.emailAddress;
      default:
        return TextInputType.text;
    }
  }

  List<TextInputFormatter> _formatters() {
    switch (fieldType) {
      case 'name':
        return [FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z ]'))];
      case 'phone':
        return [
          FilteringTextInputFormatter.digitsOnly,
          LengthLimitingTextInputFormatter(10),
        ];
      case 'aadhar':
        return [
          FilteringTextInputFormatter.digitsOnly,
          LengthLimitingTextInputFormatter(12),
        ];
      case 'pan':
        return [
          FilteringTextInputFormatter.allow(RegExp(r'[A-Z0-9]')),
          LengthLimitingTextInputFormatter(10),
        ];
      case 'passport':
        return [
          FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9]')),
          LengthLimitingTextInputFormatter(9),
        ];
      case 'password':
        return [
          FilteringTextInputFormatter.digitsOnly,
          LengthLimitingTextInputFormatter(6),
        ];
      case 'pf':
        return [
          FilteringTextInputFormatter.digitsOnly,
          LengthLimitingTextInputFormatter(12),
        ];
      case 'esic':
        return [
          FilteringTextInputFormatter.digitsOnly,
          LengthLimitingTextInputFormatter(10),
        ];
      case 'yoe':
        return [
          FilteringTextInputFormatter.digitsOnly,
          LengthLimitingTextInputFormatter(2),
        ];
      default:
        return [];
    }
  }

  String? _defaultValidator(String? value) {
    if (!optional && required && (value == null || value.trim().isEmpty)) {
      return '$label is required';
    }

    // ── Email format validation ──────────────────────────────────────────────
    if (fieldType == 'email' && value != null && value.trim().isNotEmpty) {
      final emailRegex = RegExp(
        r'^[a-zA-Z0-9._%+\-]+@[a-zA-Z0-9.\-]+\.[a-zA-Z]{2,}$',
      );
      if (!emailRegex.hasMatch(value.trim())) {
        return 'Enter a valid email address';
      }
    }

    if (fieldType == 'phone' &&
        value != null &&
        value.isNotEmpty &&
        value.length != 10) {
      return 'Phone must be 10 digits';
    }
    if (fieldType == 'aadhar' &&
        value != null &&
        value.isNotEmpty &&
        value.length != 12) {
      return 'Aadhar must be 12 digits';
    }
    if (fieldType == 'pf' &&
        value != null &&
        value.isNotEmpty &&
        value.length < 5) {
      return 'Enter valid PF number';
    }
    if (fieldType == 'esic' &&
        value != null &&
        value.isNotEmpty &&
        value.length < 5) {
      return 'Enter valid ESIC number';
    }
    if (fieldType == 'password' &&
        value != null &&
        value.isNotEmpty &&
        value.length != 6) {
      return 'Password must be exactly 6 digits';
    }
    if (fieldType == 'pan' &&
        value != null &&
        value.isNotEmpty &&
        !RegExp(r'^[A-Z]{5}[0-9]{4}[A-Z]{1}$').hasMatch(value)) {
      return 'Enter valid PAN (ABCDE1234F)';
    }
    return null;
  }
}

class FormDateField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final bool required;
  final String? Function(String?)? validator;
  final EdgeInsets padding;
  final DateTime? firstDate;
  final DateTime? lastDate;

  const FormDateField(
    this.controller,
    this.label, {
    super.key,
    this.required = true,
    this.validator,
    this.padding = const EdgeInsets.only(bottom: 12),
    this.firstDate,
    this.lastDate,
  });

  /// Returns a safe initialDate that lies within [first, last].
  DateTime _safeInitialDate() {
    final first = firstDate ?? DateTime(1950);
    final last = lastDate ?? DateTime(2100);

    // Try to use whatever is already typed in the field.
    final parsed = DateTime.tryParse(controller.text);
    if (parsed != null) {
      if (parsed.isBefore(first)) return first;
      if (parsed.isAfter(last)) return last;
      return parsed;
    }

    // Nothing in the field yet — default to `last` (most recent allowed date).
    // For DOB this is "18 years ago today", which is a sensible default.
    final now = DateTime.now();
    if (now.isAfter(last)) return last;
    if (now.isBefore(first)) return first;
    return now;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: TextFormField(
        controller: controller,
        // ✅ Not readOnly — user can also type directly if desired.
        //    The calendar icon tap always opens the picker.
        readOnly:
            true, // keep readOnly so keyboard doesn't pop up; picker is the input method
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          suffixIcon: const Icon(Icons.calendar_today, size: 18),
        ),
        validator:
            validator ??
            (v) {
              if (required && (v == null || v.isEmpty)) return 'Required';
              return null;
            },
        onTap: () async {
          // Unfocus any active text field first (avoids keyboard overlap).
          FocusScope.of(context).requestFocus(FocusNode());

          final picked = await showDatePicker(
            context: context,
            // ✅ Safe initial date — never outside [firstDate, lastDate].
            initialDate: _safeInitialDate(),
            firstDate: firstDate ?? DateTime(1950),
            lastDate: lastDate ?? DateTime(2100),
          );
          if (picked != null) {
            controller.text = picked.toIso8601String().split('T').first;
          }
        },
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
//  FormDropdownString
// ═════════════════════════════════════════════════════════════════════════════
class FormDropdownString extends StatelessWidget {
  final String label;
  final String? value;
  final List<String> items;
  final Function(String?) onChanged;
  final EdgeInsets padding;

  const FormDropdownString(
    this.label,
    this.value,
    this.items,
    this.onChanged, {
    super.key,
    this.padding = const EdgeInsets.only(bottom: 12),
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: DropdownButtonFormField<String>(
        initialValue: (value != null && value!.isNotEmpty) ? value : null,
        isExpanded: true,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 10,
            vertical: 8,
          ),
        ),
        items: items
            .map((e) => DropdownMenuItem(value: e, child: Text(e)))
            .toList(),
        onChanged: onChanged,
        validator: (v) =>
            (v == null || v.isEmpty) ? '$label is required' : null,
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
//  FormDropdownMap
// ═════════════════════════════════════════════════════════════════════════════
class FormDropdownMap extends StatelessWidget {
  final String label;
  final List<Map<String, dynamic>> items;
  final int? value;
  final ValueChanged<int?> onChanged;
  final EdgeInsets padding;
  final bool optional;

  const FormDropdownMap(
    this.label,
    this.items,
    this.value,
    this.onChanged, {
    super.key,
    this.padding = const EdgeInsets.only(bottom: 12),
    this.optional = false,
  });

  @override
  Widget build(BuildContext context) {
    // Guard: if value isn't in the current items list, force null
    // (prevents FormatException when items load asynchronously)
    final ids = items
        .map((e) => (e['id'] ?? e['role_id'] ?? e['emp_id']) as int?)
        .toSet();
    final safeValue = ids.contains(value) ? value : null;

    return Padding(
      padding: padding,
      child: DropdownButtonFormField<int>(
        initialValue: safeValue, // ← use initialValue, not value
        isExpanded: true,
        decoration: _dec(label), // ← _dec() is defined in this file
        hint: Text(
          items.isEmpty ? 'Loading…' : 'Select $label',
          style: const TextStyle(
            color: _kTextLight,
            fontSize: 13,
          ), // ← _kTextLight
        ),
        items: items.map((e) {
          final id = (e['id'] ?? e['role_id'] ?? e['emp_id']) as int?;
          final name = (e['name'] ?? e['role_name'] ?? e['label'] ?? '')
              .toString();
          return DropdownMenuItem<int>(
            value: id,
            child: Text(name, overflow: TextOverflow.ellipsis),
          );
        }).toList(),
        validator: optional
            ? null
            : (v) => v == null ? 'Please select $label' : null,
        onChanged: onChanged,
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
//  FormSectionTitle
// ═════════════════════════════════════════════════════════════════════════════
class FormSectionTitle extends StatelessWidget {
  final String title;
  final Color color;

  const FormSectionTitle(this.title, {super.key, this.color = Colors.blue});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10, top: 4),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
//  FormCard
// ═════════════════════════════════════════════════════════════════════════════
class FormCard extends StatelessWidget {
  final String title;
  final List<Widget> children;
  final double spacing;

  const FormCard(this.title, this.children, {super.key, this.spacing = 12});

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: spacing),
            ...children,
          ],
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
//  CopyAddressRow
// ═════════════════════════════════════════════════════════════════════════════
class CopyAddressRow extends StatelessWidget {
  final TextEditingController sourceController;
  final TextEditingController targetController;
  final bool useIconButton;

  const CopyAddressRow({
    super.key,
    required this.sourceController,
    required this.targetController,
    this.useIconButton = true,
  });

  @override
  Widget build(BuildContext context) {
    void doCopy() => targetController.text = sourceController.text;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: FormTextField(
            targetController,
            'Communication Address',
            required: true,
            padding: EdgeInsets.zero,
          ),
        ),
        const SizedBox(width: 8),
        if (useIconButton)
          IconButton(
            icon: const Icon(Icons.copy, color: Colors.blue),
            onPressed: doCopy,
          )
        else
          ElevatedButton(
            onPressed: doCopy,
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
              minimumSize: const Size(50, 50),
            ),
            child: const Icon(Icons.copy, size: 20),
          ),
      ],
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
//  EducationFormSection  — used in AddEmployeePage & EmployeeResubmitPage
// ═════════════════════════════════════════════════════════════════════════════
class EducationFormSection extends StatefulWidget {
  final List<Map<String, dynamic>> initialEntries;

  const EducationFormSection({super.key, this.initialEntries = const []});

  @override
  State<EducationFormSection> createState() => EducationFormSectionState();
}

class EducationFormSectionState extends State<EducationFormSection> {
  final List<Map<String, dynamic>> _entries = [];
  bool _showError = false;
  bool validate() {
    final entries = getEntries();
    if (entries.isEmpty) {
      setState(() => _showError = true);
      return false;
    }
    setState(() => _showError = false);
    return true;
  }

  @override
  void initState() {
    super.initState();
    for (final e in widget.initialEntries) {
      _entries.add(Map<String, dynamic>.from(e));
    }
  }

  /// Called by parent's submit handler to collect all entries.
  List<Map<String, dynamic>> getEntries() => List.unmodifiable(_entries);

  List<String> get _usedLevels =>
      _entries.map((e) => e['education_level']?.toString() ?? '').toList();

  List<String> get _availableLevels =>
      _kEduLevels.where((l) => !_usedLevels.contains(l)).toList();

  void _openDialog(BuildContext context, {int? existingIndex}) {
    final isEdit = existingIndex != null;
    final existing = isEdit ? _entries[existingIndex] : null;
    final levels = isEdit ? _kEduLevels : _availableLevels;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => _EduDialog(
        isEdit: isEdit,
        availableLevels: levels,
        initialLevel:
            existing?['education_level']?.toString() ??
            (levels.isNotEmpty ? levels.first : '10'),
        initialStream: existing?['stream']?.toString() ?? '',
        initialScore: existing?['score']?.toString() ?? '',
        initialYear: existing?['year_of_passout']?.toString() ?? '',
        initialUniversity: existing?['university']?.toString() ?? '',
        initialCollege: existing?['college_name']?.toString() ?? '',
        onSave: (entry) {
          if (!mounted) return;
          setState(() {
            if (isEdit) {
              _entries[existingIndex] = entry;
            } else {
              _entries.add(entry);
            }

            _showError = false;
          });
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _kBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(context),
          Padding(
            padding: const EdgeInsets.all(16),
            child: _entries.isEmpty ? _buildEmpty() : _buildList(context),
          ),
          // ← ADD THIS BLOCK
          if (_showError)
            Padding(
              padding: const EdgeInsets.only(bottom: 12, left: 16),
              child: Row(
                children: const [
                  Icon(Icons.error_outline, color: Color(0xFFEF4444), size: 14),
                  SizedBox(width: 6),
                  Text(
                    'At least one education record is required',
                    style: TextStyle(color: Color(0xFFEF4444), fontSize: 12),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: _kPrimary.withOpacity(0.05),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
        border: const Border(bottom: BorderSide(color: _kBorder)),
      ),
      child: Row(
        children: [
          const Icon(Icons.school_outlined, size: 18, color: _kPrimary),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              "Education Details",
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: _kPrimary,
                letterSpacing: 0.3,
              ),
            ),
          ),
          if (_availableLevels.isNotEmpty)
            TextButton.icon(
              onPressed: () => _openDialog(context),
              icon: const Icon(Icons.add, size: 16),
              label: const Text("Add"),
              style: TextButton.styleFrom(
                foregroundColor: _kAccent,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                textStyle: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                "All levels added",
                style: TextStyle(fontSize: 11, color: Colors.grey[400]),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.school_outlined, size: 40, color: Colors.grey[300]),
            const SizedBox(height: 8),
            const Text(
              "No education records added yet",
              style: TextStyle(color: _kTextMid, fontSize: 13),
            ),
            const SizedBox(height: 4),
            const Text(
              "Tap  +  Add  to add education details",
              style: TextStyle(color: _kTextLight, fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildList(BuildContext context) {
    return Column(
      children: _entries.asMap().entries.map((e) {
        final idx = e.key;
        final entry = e.value;
        return _EduEntryCard(
          entry: entry,
          onEdit: () => _openDialog(context, existingIndex: idx),
          onDelete: () => setState(() => _entries.removeAt(idx)),
        );
      }).toList(),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
//  _EduDialog
// ═════════════════════════════════════════════════════════════════════════════
class _EduDialog extends StatefulWidget {
  final bool isEdit;
  final List<String> availableLevels;
  final String initialLevel;
  final String initialStream;
  final String initialScore;
  final String initialYear;
  final String initialUniversity;
  final String initialCollege;
  final void Function(Map<String, dynamic>) onSave;

  const _EduDialog({
    required this.isEdit,
    required this.availableLevels,
    required this.initialLevel,
    required this.initialStream,
    required this.initialScore,
    required this.initialYear,
    required this.initialUniversity,
    required this.initialCollege,
    required this.onSave,
  });

  @override
  State<_EduDialog> createState() => _EduDialogState();
}

class _EduDialogState extends State<_EduDialog> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _streamCtrl;
  late final TextEditingController _scoreCtrl;
  late final TextEditingController _yearCtrl;
  late final TextEditingController _uniCtrl;
  late final TextEditingController _collegeCtrl;

  late String _level;

  @override
  void initState() {
    super.initState();
    _level = widget.initialLevel;
    _streamCtrl = TextEditingController(text: widget.initialStream);
    _scoreCtrl = TextEditingController(text: widget.initialScore);
    _yearCtrl = TextEditingController(text: widget.initialYear);
    _uniCtrl = TextEditingController(text: widget.initialUniversity);
    _collegeCtrl = TextEditingController(text: widget.initialCollege);
  }

  @override
  void dispose() {
    _streamCtrl.dispose();
    _scoreCtrl.dispose();
    _yearCtrl.dispose();
    _uniCtrl.dispose();
    _collegeCtrl.dispose();
    super.dispose();
  }

  void _handleSave() {
    if (!_formKey.currentState!.validate()) return;

    widget.onSave({
      'education_level': _level,
      'stream': _streamCtrl.text.trim().isEmpty
          ? null
          : _streamCtrl.text.trim(),
      'score': _scoreCtrl.text.trim().isEmpty ? null : _scoreCtrl.text.trim(),
      'year_of_passout': _yearCtrl.text.trim().isEmpty
          ? null
          : _yearCtrl.text.trim(),
      'university': _uniCtrl.text.trim().isEmpty ? null : _uniCtrl.text.trim(),
      'college_name': _collegeCtrl.text.trim().isEmpty
          ? null
          : _collegeCtrl.text.trim(),
    });

    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final sw = MediaQuery.of(context).size.width;
    final isMobile = sw < 600;

    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      insetPadding: EdgeInsets.symmetric(
        horizontal: isMobile ? 12 : 40,
        vertical: 24,
      ),
      child: SizedBox(
        width: isMobile ? sw * 0.95 : 520,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.85,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Header ────────────────────────────────────────────
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 16,
                ),
                decoration: const BoxDecoration(
                  color: _kPrimary,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.school_outlined,
                      color: Colors.white,
                      size: 18,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      widget.isEdit ? "Edit Education" : "Add Education",
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
                    const Spacer(),
                    InkWell(
                      onTap: () => Navigator.pop(context),
                      borderRadius: BorderRadius.circular(20),
                      child: const Padding(
                        padding: EdgeInsets.all(4),
                        child: Icon(
                          Icons.close,
                          color: Colors.white70,
                          size: 20,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // ── Scrollable form body ───────────────────────────────
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        DropdownButtonFormField<String>(
                          initialValue: _level,
                          isExpanded: true,
                          decoration: _dec("Education Level *"),
                          items: widget.availableLevels
                              .map(
                                (l) =>
                                    DropdownMenuItem(value: l, child: Text(l)),
                              )
                              .toList(),
                          onChanged: widget.isEdit
                              ? null
                              : (v) {
                                  if (v != null) setState(() => _level = v);
                                },
                          validator: (v) =>
                              (v == null || v.isEmpty) ? "Required" : null,
                        ),
                        const SizedBox(height: 14),

                        TextFormField(
                          controller: _streamCtrl,
                          textCapitalization: TextCapitalization.words,
                          decoration: _dec("Stream / Specialisation"),
                        ),
                        const SizedBox(height: 14),

                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _scoreCtrl,
                                decoration: _dec("Score / %"),
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                      decimal: true,
                                    ),
                                inputFormatters: [
                                  FilteringTextInputFormatter.allow(
                                    RegExp(r'[0-9.]'),
                                  ),
                                  LengthLimitingTextInputFormatter(6),
                                ],
                                validator: (v) {
                                  if (v == null || v.isEmpty) return null;
                                  final d = double.tryParse(v);
                                  if (d == null || d < 0 || d > 100) {
                                    return "0–100";
                                  }
                                  return null;
                                },
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextFormField(
                                controller: _yearCtrl,
                                decoration: _dec("Year of Passout"),
                                keyboardType: TextInputType.number,
                                inputFormatters: [
                                  FilteringTextInputFormatter.digitsOnly,
                                  LengthLimitingTextInputFormatter(4),
                                ],
                                validator: (v) {
                                  if (v == null || v.isEmpty) return null;
                                  final y = int.tryParse(v);
                                  if (y == null ||
                                      y < 1950 ||
                                      y > DateTime.now().year + 1) {
                                    return "Invalid year";
                                  }
                                  return null;
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),

                        TextFormField(
                          controller: _uniCtrl,
                          textCapitalization: TextCapitalization.words,
                          decoration: _dec("University / Board"),
                        ),
                        const SizedBox(height: 14),

                        TextFormField(
                          controller: _collegeCtrl,
                          textCapitalization: TextCapitalization.words,
                          decoration: _dec("College / School Name"),
                        ),
                        const SizedBox(height: 8),
                      ],
                    ),
                  ),
                ),
              ),

              // ── Divider + Action buttons ───────────────────────────
              const Divider(height: 1, color: _kBorder),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      style: TextButton.styleFrom(
                        foregroundColor: _kTextMid,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                      ),
                      child: const Text("Cancel"),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: _handleSave,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _kPrimary,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 10,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: Text(widget.isEdit ? "Update" : "Add"),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
//  _EduEntryCard  — displays one education record row
// ═════════════════════════════════════════════════════════════════════════════
class _EduEntryCard extends StatelessWidget {
  final Map<String, dynamic> entry;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _EduEntryCard({
    required this.entry,
    required this.onEdit,
    required this.onDelete,
  });

  Color _levelColor(String l) {
    switch (l) {
      case '10':
        return const Color(0xFF6D4C41);
      case '12':
        return const Color(0xFF1565C0);
      case 'Diploma':
        return const Color(0xFF00838F);
      case 'UG':
        return const Color(0xFF2E7D32);
      case 'PG':
        return const Color(0xFF6A1B9A);

      default:
        return _kPrimary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final level = entry['education_level']?.toString() ?? '-';
    final color = _levelColor(level);
    final stream = entry['stream']?.toString() ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: _kSurface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _kBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.08),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(10),
              ),
              border: Border(bottom: BorderSide(color: color.withOpacity(0.2))),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    level,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    stream.isNotEmpty ? stream : "—",
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: _kTextDark,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                InkWell(
                  onTap: onEdit,
                  borderRadius: BorderRadius.circular(6),
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: Icon(Icons.edit_outlined, size: 18, color: _kAccent),
                  ),
                ),
                const SizedBox(width: 4),
                InkWell(
                  onTap: () => _confirmDelete(context),
                  borderRadius: BorderRadius.circular(6),
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: Icon(
                      Icons.delete_outline,
                      size: 18,
                      color: Colors.red.shade400,
                    ),
                  ),
                ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Wrap(
              spacing: 24,
              runSpacing: 6,
              children: [
                if ((entry['college_name']?.toString() ?? '').isNotEmpty)
                  _chip(
                    Icons.account_balance_outlined,
                    entry['college_name'].toString(),
                  ),
                if ((entry['university']?.toString() ?? '').isNotEmpty)
                  _chip(
                    Icons.location_city_outlined,
                    entry['university'].toString(),
                  ),
                if ((entry['score']?.toString() ?? '').isNotEmpty)
                  _chip(Icons.grade_outlined, "${entry['score']}%"),
                if ((entry['year_of_passout']?.toString() ?? '').isNotEmpty)
                  _chip(
                    Icons.calendar_month_outlined,
                    entry['year_of_passout'].toString(),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Text("Remove Education Record"),
        content: Text("Remove '${entry['education_level']}' record?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("Cancel", style: TextStyle(color: _kTextMid)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("Remove"),
          ),
        ],
      ),
    );
    if (ok == true) onDelete();
  }

  Widget _chip(IconData icon, String text) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 13, color: _kTextLight),
      const SizedBox(width: 4),
      Text(text, style: const TextStyle(fontSize: 12, color: _kTextMid)),
    ],
  );
}

// ─── Input decoration helper (used inside _EduDialogState only) ──────────────
InputDecoration _dec(String label) => InputDecoration(
  labelText: label,
  labelStyle: const TextStyle(color: _kTextMid, fontSize: 13),
  filled: true,
  fillColor: _kSurface,
  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
  border: OutlineInputBorder(
    borderRadius: BorderRadius.circular(8),
    borderSide: const BorderSide(color: _kBorder),
  ),
  enabledBorder: OutlineInputBorder(
    borderRadius: BorderRadius.circular(8),
    borderSide: const BorderSide(color: _kBorder),
  ),
  focusedBorder: OutlineInputBorder(
    borderRadius: BorderRadius.circular(8),
    borderSide: const BorderSide(color: _kAccent, width: 1.5),
  ),
  errorBorder: OutlineInputBorder(
    borderRadius: BorderRadius.circular(8),
    borderSide: BorderSide(color: Colors.red.shade300),
  ),
  focusedErrorBorder: OutlineInputBorder(
    borderRadius: BorderRadius.circular(8),
    borderSide: BorderSide(color: Colors.red.shade400, width: 1.5),
  ),
);
