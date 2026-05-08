import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/app_admin_provider.dart';
import '../widgets/admin_widgets.dart';

class AppAdminCreateCompanyScreen extends StatefulWidget {
  const AppAdminCreateCompanyScreen({super.key});

  @override
  State<AppAdminCreateCompanyScreen> createState() =>
      _AppAdminCreateCompanyScreenState();
}

class _AppAdminCreateCompanyScreenState
    extends State<AppAdminCreateCompanyScreen> {
  final _formKey = GlobalKey<FormState>();

  final _nameCtrl = TextEditingController();
  final _codeCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();

  String? _selectedPlan;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadPlans();
  }

  Future<void> _loadPlans() async {
    await context.read<AppAdminProvider>().loadPlans();
    if (!mounted) return;

    final plans = context.read<AppAdminProvider>().plans;
    if (plans.isNotEmpty) {
      setState(() {
        _selectedPlan = plans.first['plan_code'];
      });
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _codeCtrl.dispose();
    _emailCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedPlan == null) {
      _showError('Please select a plan');
      return;
    }

    setState(() => _isLoading = true);

    try {
      await context.read<AppAdminProvider>().createCompany({
        "company_name": _nameCtrl.text.trim(),
        "company_code": _codeCtrl.text.trim(),
        "admin_email": _emailCtrl.text.trim(),
        "plan_code": _selectedPlan,
      });

      if (!mounted) return;

      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      _showError(e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppAdminProvider>();
    final plans = provider.plans;

    return Scaffold(
      backgroundColor: AdminColors.bg,
      appBar: AppBar(
        title: const Text('Create Company'),
        backgroundColor: Colors.white,
        foregroundColor: AdminColors.textDark,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              AdminCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Company Details',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AdminColors.textDark,
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Company Name
                    TextFormField(
                      controller: _nameCtrl,
                      decoration: adminInput('Company Name'),
                      validator: (v) =>
                          v == null || v.isEmpty ? 'Required' : null,
                    ),

                    const SizedBox(height: 10),

                    // Company Code
                    TextFormField(
                      controller: _codeCtrl,
                      decoration: adminInput('Company Code'),
                      validator: (v) =>
                          v == null || v.isEmpty ? 'Required' : null,
                    ),

                    const SizedBox(height: 10),

                    // Admin Email
                    TextFormField(
                      controller: _emailCtrl,
                      decoration: adminInput('Admin Email'),
                      validator: (v) {
                        if (v == null || v.isEmpty) return 'Required';
                        if (!v.contains('@')) return 'Invalid email';
                        return null;
                      },
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              // Plan Selection
              AdminCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Select Plan',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 10),

                    if (provider.isLoading && plans.isEmpty)
                      const Center(child: CircularProgressIndicator())
                    else
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: plans.map((p) {
                          final code = p['plan_code'];
                          final name = p['plan_name'];
                          final selected = _selectedPlan == code;

                          return GestureDetector(
                            onTap: () {
                              setState(() => _selectedPlan = code);
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: selected
                                    ? AdminColors.primary
                                    : Colors.white,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: selected
                                      ? AdminColors.primary
                                      : AdminColors.border,
                                ),
                              ),
                              child: Text(
                                name,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: selected
                                      ? Colors.white
                                      : AdminColors.textMid,
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),

      // Submit Button
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(16),
        child: AdminPrimaryButton(
          label: _isLoading ? 'Creating...' : 'Create Company',
          onPressed: _isLoading ? null : _submit,
        ),
      ),
    );
  }
}