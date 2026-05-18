// lib/user/user_profile.dart
import 'dart:convert';
import 'package:dr_cars_fyp/auth/auth_service.dart';
import 'package:dr_cars_fyp/settings/Settings.dart';
import 'package:flutter/material.dart';
import 'package:dr_cars_fyp/user/main_dashboard.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dr_cars_fyp/utils/vehicle_image_helper.dart';
import 'package:dr_cars_fyp/l10n/app_strings.dart';
import 'package:dr_cars_fyp/providers/locale_provider.dart';
import 'package:dr_cars_fyp/theme/app_theme.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:dr_cars_fyp/widgets/app_bottom_nav.dart';
import 'package:dr_cars_fyp/user/document_scan_screen.dart';
import 'package:dr_cars_fyp/service/document_service.dart';
import 'package:dr_cars_fyp/service/document_notification_service.dart';
import 'package:dr_cars_fyp/models/vehicle_document.dart';
import 'package:dr_cars_fyp/user/driving_licence_screen.dart';

int _selectedIndex = 4;

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  _ProfileScreenState createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final AuthService _authService = AuthService();
  final _formKey = GlobalKey<FormState>();
  final TextEditingController nameController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController vehicleNumberController = TextEditingController();
  String? selectedBrand;
  String? selectedModel;
  String? selectedType;
  TextEditingController mileageController = TextEditingController();
  TextEditingController yearController = TextEditingController();

  bool _isLoading = false;
  String? _vehiclePhotoUrl;
  bool _isInitialSetup = true;
  String? _currentUserId;

  Widget _buildDocumentsSection() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceDark,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderGold),
        boxShadow: [
          BoxShadow(
            color: AppColors.gold.withOpacity(0.06),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'My Documents',
                style: GoogleFonts.cormorantGaramond(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              GestureDetector(
                onTap: () async {
                  await Future.delayed(const Duration(milliseconds: 400));
                  if (!mounted) return;
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder:
                          (_) => DrivingLicenceScreen(
                            userId: _currentUserId!,
                            userName: nameController.text,
                          ),
                    ),
                  );
                },

                child: Row(
                  children: [
                    const Icon(
                      Icons.add_circle_outline,
                      color: AppColors.gold,
                      size: 18,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Add',
                      style: GoogleFonts.jost(
                        color: AppColors.gold,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          Container(
            height: 1,
            margin: const EdgeInsets.symmetric(vertical: 12),
            color: AppColors.borderGold,
          ),
          GestureDetector(
            onTap: () async {
              await Future.delayed(const Duration(milliseconds: 400));
              if (!mounted) return;
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder:
                      (_) => DrivingLicenceScreen(
                        userId: _currentUserId!,
                        userName: nameController.text,
                      ),
                ),
              );
            },

            child: Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.gold.withOpacity(0.15),
                    AppColors.surfaceElevated,
                  ],
                ),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.gold.withOpacity(0.5)),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.credit_card,
                    color: AppColors.gold,
                    size: 28,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Virtual Driving Licence',
                          style: GoogleFonts.jost(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                        Text(
                          'View & store your driving licence card',
                          style: GoogleFonts.jost(
                            color: AppColors.textSecondary,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(
                    Icons.arrow_forward_ios,
                    color: AppColors.gold,
                    size: 14,
                  ),
                ],
              ),
            ),
          ),
          if (_documents.isEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                'No documents added yet. Tap Add to scan your license or insurance.',
                style: GoogleFonts.jost(
                  color: AppColors.textMuted,
                  fontSize: 12,
                ),
              ),
            )
          else
            ..._documents.map((doc) => _documentCard(doc)),
        ],
      ),
    );
  }

  // ── Step 13: documents state ───────────────────────────────────────────
  List<VehicleDocument> _documents = [];

  final Map<String, List<String>> vehicleModels = {
    'Toyota': [
      'Corolla',
      'Camry',
      'RAV4',
      'Highlander',
      'Aqua',
      'Axio',
      'Vitz',
      'Prius',
      'Crown',
      'Fortuner',
    ],
    'Nissan': [
      'Sunny',
      'X-Trail',
      'Juke',
      'Note',
      'Teana',
      'GT-R',
      'Sentra',
      'Patrol',
      '370Z',
    ],
    'Honda': [
      'Civic',
      'Accord',
      'CR-V',
      'Fit',
      'Vezel',
      'City',
      'Odyssey',
      'Freed',
    ],
    'Suzuki': [
      'Alto',
      'Wagon R',
      'Swift',
      'Baleno',
      'Vitara',
      'Ertiga',
      'Jimny',
      'Estilo',
    ],
    'Mazda': [
      'Mazda3',
      'Mazda6',
      'CX-3',
      'CX-5',
      'CX-9',
      'BT-50',
      'RX-8',
      'MX-5',
    ],
    'BMW': ['320i', 'X1', 'X3', 'X5', 'M3', 'Z4', '530e', '740i'],
    'Kia': [
      'Picanto',
      'Rio',
      'Sportage',
      'Seltos',
      'Sorento',
      'Cerato',
      'Stinger',
      'Carnival',
    ],
    'Hyundai': [
      'i10',
      'i20',
      'Elantra',
      'Tucson',
      'Santa fe',
      'Accent',
      'Venue',
      'Creta',
    ],
  };

  final List<String> vehicleTypes = ['Car', 'SUV', 'Truck', 'Buses', 'Van'];

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  @override
  void dispose() {
    nameController.dispose();
    emailController.dispose();
    vehicleNumberController.dispose();
    mileageController.dispose();
    yearController.dispose();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    setState(() => _isLoading = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedUserId = prefs.getString('currentUserId');
      final user = await _authService.getCurrentUser();

      if (user != null) {
        final uid =
            user['uid']?.toString() ??
            user['id']?.toString() ??
            user['_id']?.toString() ??
            user['userId']?.toString() ??
            cachedUserId;

        if (uid != null && uid.isNotEmpty) {
          _currentUserId = uid;
          nameController.text =
              user['Name']?.toString() ?? user['name']?.toString() ?? '';
          emailController.text =
              user['Email']?.toString() ?? user['email']?.toString() ?? '';

          final vehicleDoc = await _authService.getVehicleByUserId(uid);
          if (vehicleDoc != null) {
            setState(() {
              _isInitialSetup = false;
              vehicleNumberController.text =
                  vehicleDoc['vehicleNumber']?.toString() ?? '';
              selectedBrand = vehicleDoc['selectedBrand']?.toString();
              selectedModel = vehicleDoc['selectedModel']?.toString();
              selectedType = vehicleDoc['vehicleType']?.toString();
              mileageController.text = vehicleDoc['mileage']?.toString() ?? '';
              yearController.text = vehicleDoc['year']?.toString() ?? '';
              _vehiclePhotoUrl = vehicleDoc['vehiclePhotoUrl']?.toString();
            });
          }
        }
      }

      // ── Step 13: load documents after user data ────────────────────────
      await _loadDocuments();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.error,
            content: Text(
              'Error loading profile data',
              style: GoogleFonts.jost(color: Colors.white),
            ),
          ),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // ── Step 13: load documents method ──────────────────────────────────────
  Future<void> _loadDocuments() async {
    if (_currentUserId == null) return;
    final docs = await DocumentService.getDocuments(_currentUserId!);
    await DocumentNotificationService.scheduleAll(docs);
    if (mounted) setState(() => _documents = docs);
  }

  // ── Luxury text field ─────────────────────────────────────────────────────────
  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hintText,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        style: GoogleFonts.jost(color: AppColors.textPrimary, fontSize: 14),
        decoration: InputDecoration(
          labelText: label,
          hintText: hintText,
          labelStyle: GoogleFonts.jost(
            color: AppColors.textSecondary,
            fontSize: 13,
          ),
          floatingLabelStyle: GoogleFonts.jost(
            color: AppColors.gold,
            fontSize: 12,
          ),
          hintStyle: GoogleFonts.jost(color: AppColors.textMuted, fontSize: 14),
          filled: true,
          fillColor: AppColors.surfaceElevated,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.borderGold),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.borderGold),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.gold, width: 1.5),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.error),
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 14,
          ),
        ),
        validator: (value) {
          if (value == null || value.isEmpty) {
            return 'Please enter $label';
          }
          return null;
        },
      ),
    );
  }

  // ── Luxury dropdown ───────────────────────────────────────────────────────
  Widget _buildDarkDropdown({
    required List<String> items,
    required String? selectedValue,
    required String hintText,
    required String label,
    required Function(String?) onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: DropdownButtonFormField<String>(
        value: selectedValue,
        style: GoogleFonts.jost(color: AppColors.textPrimary, fontSize: 14),
        dropdownColor: AppColors.surfaceElevated,
        icon: const Icon(
          Icons.keyboard_arrow_down_rounded,
          color: AppColors.gold,
        ),
        selectedItemBuilder:
            (context) =>
                items
                    .map(
                      (item) => Text(
                        item,
                        style: GoogleFonts.jost(
                          color: AppColors.textPrimary,
                          fontSize: 14,
                        ),
                      ),
                    )
                    .toList(),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: GoogleFonts.jost(
            color: AppColors.textSecondary,
            fontSize: 13,
          ),
          floatingLabelStyle: GoogleFonts.jost(
            color: AppColors.gold,
            fontSize: 12,
          ),
          filled: true,
          fillColor: AppColors.surfaceElevated,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.borderGold),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.borderGold),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.gold, width: 1.5),
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 14,
          ),
        ),
        hint: Text(
          hintText,
          style: GoogleFonts.jost(color: AppColors.textMuted, fontSize: 14),
        ),
        items:
            items
                .map(
                  (item) => DropdownMenuItem(
                    value: item,
                    child: Text(
                      item,
                      style: GoogleFonts.jost(
                        color: AppColors.textPrimary,
                        fontSize: 14,
                      ),
                    ),
                  ),
                )
                .toList(),
        onChanged: onChanged,
      ),
    );
  }

  // ── Vehicle panel (when setup is done) ───────────────────────────────────
  Widget _buildVehiclePanel(String lang) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceDark,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderGold),
        boxShadow: [
          BoxShadow(
            color: AppColors.gold.withOpacity(0.06),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Theme(
        data: Theme.of(context).copyWith(
          dividerColor: Colors.transparent,
          expansionTileTheme: const ExpansionTileThemeData(
            backgroundColor: AppColors.surfaceDark,
            collapsedBackgroundColor: AppColors.surfaceDark,
          ),
        ),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          leading: VehicleImageHelper.buildFittedImage(
            brand: selectedBrand,
            model: selectedModel,
            photoUrl: _vehiclePhotoUrl,
            size: 50,
          ),
          title: Text(
            '${selectedBrand ?? ''} ${selectedModel ?? ''}',
            style: GoogleFonts.cormorantGaramond(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          subtitle: Text(
            vehicleNumberController.text,
            style: GoogleFonts.jost(
              fontSize: 12,
              color: AppColors.gold,
              letterSpacing: 1,
            ),
          ),
          iconColor: AppColors.gold,
          collapsedIconColor: AppColors.textSecondary,
          children: [
            Container(height: 1, color: AppColors.borderGold),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Existing vehicle info rows (unchanged) ──
                  _infoRow('Vehicle Type', selectedType ?? '-'),
                  const SizedBox(height: 8),
                  _infoRow('Mileage', '${mileageController.text} km'),
                  const SizedBox(height: 8),
                  _infoRow('Year', yearController.text),

                  // ── Existing edit button (unchanged) ──
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        setState(() => _isInitialSetup = true);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.gold,
                        foregroundColor: AppColors.obsidian,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: Text(
                        AppStrings.get('edit_vehicle', lang),
                        style: GoogleFonts.jost(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Step 13: Document card widget ─────────────────────────────────────────
  Widget _documentCard(VehicleDocument doc) {
    Color statusColor;
    String statusLabel;

    if (doc.isExpired) {
      statusColor = AppColors.error;
      statusLabel = 'EXPIRED';
    } else if (doc.isExpiringSoon) {
      statusColor = Colors.orange;
      statusLabel = 'Expires in ${doc.daysUntilExpiry}d';
    } else {
      statusColor = AppColors.gold;
      statusLabel = 'Valid';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.richBlack,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: statusColor.withOpacity(0.4)),
      ),
      child: Row(
        children: [
          Icon(
            doc.type == 'license' ? Icons.badge : Icons.shield,
            color: statusColor,
            size: 28,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  doc.label,
                  style: GoogleFonts.jost(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
                if (doc.documentNumber.isNotEmpty)
                  Text(
                    doc.documentNumber,
                    style: GoogleFonts.jost(
                      color: AppColors.textMuted,
                      fontSize: 11,
                    ),
                  ),
                if (doc.vehiclePlate.isNotEmpty)
                  Text(
                    doc.vehiclePlate,
                    style: GoogleFonts.jost(
                      color: AppColors.textMuted,
                      fontSize: 11,
                    ),
                  ),
                Text(
                  'Expires: ${doc.formattedExpiry}',
                  style: GoogleFonts.jost(
                    color: statusColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          Column(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  statusLabel,
                  style: GoogleFonts.jost(
                    color: statusColor,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(
                  Icons.delete_outline,
                  color: Colors.redAccent,
                  size: 18,
                ),
                onPressed: () async {
                  await DocumentService.deleteDocument(doc.id);
                  _loadDocuments();
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: GoogleFonts.jost(fontSize: 13, color: AppColors.textSecondary),
        ),
        Text(
          value,
          style: GoogleFonts.jost(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }

  // ── Setup form (unchanged) ────────────────────────────────────────────────
  Widget _buildInitialSetupForm(String lang) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Vehicle image circle
          Container(
            width: 150,
            height: 150,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.gold, width: 2),
              boxShadow: [
                BoxShadow(
                  color: AppColors.gold.withOpacity(0.1),
                  blurRadius: 20,
                  spreadRadius: 2,
                ),
              ],
            ),
            child:
                _vehiclePhotoUrl != null
                    ? ClipOval(
                      child: Image.network(
                        _vehiclePhotoUrl!,
                        fit: BoxFit.cover,
                      ),
                    )
                    : Stack(
                      alignment: Alignment.center,
                      children: [
                        VehicleImageHelper.buildFittedImage(
                          brand: selectedBrand,
                          model: selectedModel,
                          size: 150,
                        ),
                        Container(
                          width: 150,
                          height: 150,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.black.withOpacity(0.3),
                          ),
                          child: const Icon(
                            Icons.add_photo_alternate,
                            color: Colors.white,
                            size: 30,
                          ),
                        ),
                      ],
                    ),
          ),

          const SizedBox(height: 20),

          Text(
            AppStrings.get('vehicle_information_setup', lang),
            style: GoogleFonts.cormorantGaramond(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),

          goldDivider(),

          _buildDarkDropdown(
            items: vehicleModels.keys.toList(),
            selectedValue: selectedBrand,
            hintText: AppStrings.get('select_brand', lang),
            label: 'Vehicle Brand',
            onChanged: (value) {
              setState(() {
                selectedBrand = value;
                selectedModel = null;
              });
            },
          ),

          _buildDarkDropdown(
            items:
                selectedBrand != null && vehicleModels[selectedBrand] != null
                    ? vehicleModels[selectedBrand]!
                    : [],
            selectedValue: selectedModel,
            hintText:
                selectedBrand == null
                    ? AppStrings.get('select_brand_first', lang)
                    : AppStrings.get('select_model', lang),
            label: 'Vehicle Model',
            onChanged: (value) {
              setState(() => selectedModel = value);
            },
          ),

          _buildDarkDropdown(
            items: vehicleTypes,
            selectedValue: selectedType,
            hintText: AppStrings.get('select_type', lang),
            label: 'Vehicle Type',
            onChanged: (value) {
              setState(() => selectedType = value);
            },
          ),

          _buildTextField(
            controller: vehicleNumberController,
            label: 'Vehicle Number',
            hintText: 'Enter vehicle number',
          ),

          _buildTextField(
            controller: mileageController,
            label: 'Mileage (km)',
            hintText: 'Enter mileage',
            keyboardType: TextInputType.number,
          ),

          _buildTextField(
            controller: yearController,
            label: 'Manufacture Year',
            hintText: 'Enter year',
            keyboardType: TextInputType.number,
          ),

          const SizedBox(height: 8),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.gold,
                foregroundColor: AppColors.obsidian,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onPressed: _isLoading ? null : () => _saveProfile(),
              child:
                  _isLoading
                      ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: AppColors.obsidian,
                          strokeWidth: 2,
                        ),
                      )
                      : Text(
                        AppStrings.get('save_vehicle', lang),
                        style: GoogleFonts.jost(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          letterSpacing: 1.5,
                        ),
                      ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: localeNotifier,
      builder: (context, lang, _) {
        return Scaffold(
          backgroundColor: AppColors.richBlack,
          appBar: AppBar(
            backgroundColor: AppColors.obsidian,
            elevation: 0,
            iconTheme: const IconThemeData(color: AppColors.gold),
            leading: IconButton(
              icon: const Icon(Icons.home, color: AppColors.gold),
              onPressed:
                  () => Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (context) => DashboardScreen()),
                  ),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.refresh, color: AppColors.gold),
                onPressed: _loadUserData,
              ),
              IconButton(
                icon: const Icon(Icons.settings, color: AppColors.gold),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => SettingsScreen()),
                  );
                },
              ),
            ],
          ),
          body: Stack(
            children: [
              SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child:
                    _isInitialSetup
                        ? _buildInitialSetupForm(lang)
                        : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildVehiclePanel(lang),
                            const SizedBox(height: 20),
                            _buildDocumentsSection(),
                          ],
                        ),
              ),
              if (_isLoading)
                Container(
                  color: Colors.black.withOpacity(0.5),
                  child: const Center(
                    child: CircularProgressIndicator(color: AppColors.gold),
                  ),
                ),
            ],
          ),
          bottomNavigationBar: AppBottomNav(currentIndex: 4),
        );
      },
    );
  }

  Future<void> _saveProfile() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);

      try {
        if (_currentUserId == null || _currentUserId!.isEmpty) {
          throw Exception('User not authenticated');
        }

        Map<String, dynamic> vehicleData = {
          'uid': _currentUserId,
          'vehicleNumber': vehicleNumberController.text,
          'selectedBrand': selectedBrand,
          'selectedModel': selectedModel,
          'vehicleType': selectedType,
          'mileage': int.tryParse(mileageController.text) ?? 0,
          'year': yearController.text,
          'vehiclePhotoUrl': _vehiclePhotoUrl,
          'lastUpdated': DateTime.now().toIso8601String(),
        };

        final response = await http.put(
          Uri.parse('${_authService.baseUrl}/vehicles/by-user/$_currentUserId'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(vehicleData),
        );

        if (response.statusCode < 200 || response.statusCode >= 300) {
          throw Exception('Failed to save vehicle data');
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: AppColors.success,
              content: Text(
                'Vehicle information saved successfully!',
                style: GoogleFonts.jost(color: Colors.white),
              ),
            ),
          );
          setState(() => _isInitialSetup = false);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: AppColors.error,
              content: Text(
                'Failed to save vehicle data: ${e.toString()}',
                style: GoogleFonts.jost(color: Colors.white),
              ),
            ),
          );
        }
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }
}
