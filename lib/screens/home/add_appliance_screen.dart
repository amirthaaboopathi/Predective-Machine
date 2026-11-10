import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/appliance_model.dart';
import '../../services/appliance_service.dart';
import '../../services/hardware_mapping_service.dart';
import '../../services/hardware_serial_service.dart';
import '../../utils/app_colors.dart';
import '../../utils/constants.dart';
import '../../utils/app_text_styles.dart';
import '../../widgets/custom_text_field.dart';
import '../../widgets/primary_button.dart';

/// Form screen to add a new physical appliance to the user's account in Supabase
/// and configure dedicated hardware sensor monitoring (e.g. COM3).
class AddApplianceScreen extends StatefulWidget {
  const AddApplianceScreen({super.key});

  @override
  State<AddApplianceScreen> createState() => _AddApplianceScreenState();
}

class _AddApplianceScreenState extends State<AddApplianceScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _brandController = TextEditingController();
  final _modelController = TextEditingController();
  final _purchaseDateController = TextEditingController();

  String _selectedType = AppConstants.applianceTypes.first;
  String _selectedHardwarePort = 'COM3';
  List<String> _availablePorts = ['COM3'];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadPorts();
  }

  Future<void> _loadPorts() async {
    await HardwareMappingService().init();
    final ports = await HardwareSerialService().scanAvailablePorts();
    if (mounted) {
      setState(() {
        _availablePorts = ports;
        if (!_availablePorts.contains('COM3')) {
          _availablePorts.insert(0, 'COM3');
        }
      });
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _brandController.dispose();
    _modelController.dispose();
    _purchaseDateController.dispose();
    super.dispose();
  }

  Future<void> _selectPurchaseDate() async {
    final now = DateTime.now();
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: DateTime(2000),
      lastDate: now,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.primaryBlue,
            ),
          ),
          child: child!,
        );
      },
    );

    if (pickedDate != null) {
      setState(() {
        _purchaseDateController.text =
            '${pickedDate.year}-${pickedDate.month.toString().padLeft(2, '0')}-${pickedDate.day.toString().padLeft(2, '0')}';
      });
    }
  }

  Future<void> _handleAddAppliance() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please login to add an appliance'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final name = _nameController.text.trim();
      final brandText = _brandController.text.trim();
      final modelText = _modelController.text.trim();
      final dateText = _purchaseDateController.text.trim();

      final portToAssign = _selectedHardwarePort == 'None' ? null : _selectedHardwarePort;

      final newAppliance = ApplianceModel(
        id: '',
        userId: user.id,
        name: name,
        type: _selectedType,
        brand: brandText.isNotEmpty ? brandText : null,
        modelNumber: modelText.isNotEmpty ? modelText : null,
        purchaseDate: dateText.isNotEmpty ? dateText : null,
        addedAt: DateTime.now(),
        hardwarePort: portToAssign,
      );

      await ApplianceService().addAppliance(
        newAppliance,
        assignedPort: portToAssign,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            portToAssign != null
                ? '$name added and linked to hardware port $portToAssign!'
                : '$name added successfully',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );

      Navigator.pop(context);
    } catch (e, stackTrace) {
      debugPrint('Failed to add appliance: $e');
      debugPrintStack(stackTrace: stackTrace);

      if (!mounted) return;

      final String errorMessage = e is PostgrestException
          ? e.message
          : 'Unable to save appliance. Please try again.';

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMessage),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final mappingService = HardwareMappingService();
    final currentOccupantId = mappingService.getApplianceIdForPort(_selectedHardwarePort);
    final occupantAppliance = currentOccupantId != null
        ? ApplianceService().getApplianceById(currentOccupantId)
        : null;

    final portOptions = ['COM3', ..._availablePorts.where((p) => p != 'COM3'), 'None'];

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Add Appliance'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Appliance Information',
                  style: AppTextStyles.heading2,
                ),
                const SizedBox(height: 6),
                Text(
                  'Enter details and pair with a dedicated hardware sensor device.',
                  style: AppTextStyles.subtitle,
                ),
                const SizedBox(height: 24),

                // Appliance Name
                CustomTextField(
                  label: 'Appliance Name',
                  hintText: 'e.g., Living Room AC, Kitchen Fridge',
                  controller: _nameController,
                  validator: (val) =>
                      val == null || val.trim().isEmpty ? 'Appliance Name is required' : null,
                ),
                const SizedBox(height: 16),

                // Appliance Type Dropdown
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Appliance Type', style: AppTextStyles.label),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      initialValue: _selectedType,
                      decoration: const InputDecoration(),
                      items: AppConstants.applianceTypes.map((type) {
                        return DropdownMenuItem(
                          value: type,
                          child: Text(type, style: AppTextStyles.bodyMedium),
                        );
                      }).toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setState(() {
                            _selectedType = value;
                          });
                        }
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Brand
                CustomTextField(
                  label: 'Brand (Optional)',
                  hintText: 'e.g., Samsung, LG, Whirlpool',
                  controller: _brandController,
                ),
                const SizedBox(height: 16),

                // Model Number
                CustomTextField(
                  label: 'Model (Optional)',
                  hintText: 'e.g., RS68A8820B1',
                  controller: _modelController,
                ),
                const SizedBox(height: 16),

                // Purchase Date
                CustomTextField(
                  label: 'Purchase Date (Optional)',
                  hintText: 'DD/MM/YYYY',
                  controller: _purchaseDateController,
                  readOnly: true,
                  onTap: _selectPurchaseDate,
                  prefixIcon: Icons.calendar_today_outlined,
                ),
                const SizedBox(height: 24),

                // Hardware Sensor Device Link Section
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.borderColor, width: 1),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.shadowColor,
                        blurRadius: 14,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppColors.primaryBlue.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(
                              Icons.memory_rounded,
                              color: AppColors.primaryBlue,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Hardware Sensor Link',
                                  style: AppTextStyles.heading3.copyWith(fontSize: 16),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Dedicated COM Port for this appliance',
                                  style: AppTextStyles.caption,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Select Hardware Port',
                        style: AppTextStyles.label,
                      ),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        initialValue: _selectedHardwarePort,
                        decoration: const InputDecoration(),
                        items: portOptions.toSet().map((port) {
                          String label = port;
                          if (port == 'COM3') {
                            label = 'COM3 (Primary Sensor Device)';
                          } else if (port == 'None') {
                            label = 'None (Manual Diagnostic Only)';
                          }
                          return DropdownMenuItem(
                            value: port,
                            child: Text(label, style: AppTextStyles.bodyMedium),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setState(() {
                              _selectedHardwarePort = val;
                            });
                          }
                        },
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.background,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(
                              Icons.info_outline_rounded,
                              size: 16,
                              color: AppColors.secondaryText,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _selectedHardwarePort == 'None'
                                    ? 'No physical hardware assigned. Appliance will use diagnostic question surveys.'
                                    : 'Telemetry from $_selectedHardwarePort will be stored exclusively for this appliance in Supabase.',
                                style: AppTextStyles.caption.copyWith(fontSize: 12),
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (occupantAppliance != null && _selectedHardwarePort != 'None') ...[
                        const SizedBox(height: 8),
                        Text(
                          'Note: $_selectedHardwarePort is currently assigned to "${occupantAppliance.name}". Saving will transfer hardware monitoring to this appliance.',
                          style: AppTextStyles.caption.copyWith(
                            color: AppColors.warning,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 32),

                // Primary Add Button
                PrimaryButton(
                  text: 'Add Appliance',
                  isLoading: _isLoading,
                  onPressed: _handleAddAppliance,
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
