import 'dart:convert';

import 'package:dr_cars_fyp/auth/auth_service.dart';
import 'package:dr_cars_fyp/obd/OBD2.dart';
import 'package:dr_cars_fyp/user/main_dashboard.dart';
import 'package:dr_cars_fyp/map/mapscreen.dart';
import 'package:dr_cars_fyp/user/user_profile.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:dr_cars_fyp/l10n/app_strings.dart';
import 'package:dr_cars_fyp/providers/locale_provider.dart';
import 'package:dr_cars_fyp/theme/app_theme.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:dr_cars_fyp/widgets/app_bottom_nav.dart';

class ServiceHistorypage extends StatefulWidget {
  const ServiceHistorypage({super.key});

  @override
  State<ServiceHistorypage> createState() => _ServiceHistorypageState();
}

class _ServiceHistorypageState extends State<ServiceHistorypage> {
  final AuthService _authService = AuthService();
  final TextEditingController _searchController = TextEditingController();
  String? _selectedFilter;
  DateTime? _selectedDate;
  List<Map<String, dynamic>> _serviceRecords = [];
  bool _isLoading = true;

  final List<String> _serviceTypes = [
    'Full Service',
    'Oil Filter Change',
    'Tire pressure and rotation check',
    'Fluid level check',
    'Battery check and replacements',
    'Wiper blade replacement',
    'Light bulb check',
    'Brake system services',
    'Suspension and alignment services',
    'Exhaust system service',
    'Air conditioning services',
    'Electrical system services',
    'Car detailing (Interior and exterior cleaning, waxing)',
    'Tire sales and installation',
    'Pre-purchase inspections',
    'Diagnostic testing',
  ];

  static const Map<String, Map<String, String>> _serviceTypeTranslations = {
    'Full Service': {'si': 'සම්පූර්ණ සේවාව', 'ta': 'முழு சேவை'},
    'Oil Filter Change': {
      'si': 'තෙල් පෙරහන් මාරුව',
      'ta': 'எண்ணெய் வடிகட்டி மாற்றம்',
    },
    'Tire pressure and rotation check': {
      'si': 'ටයර් පීඩන පරීක්ෂාව',
      'ta': 'டயர் அழுத்த சோதனை',
    },
    'Fluid level check': {'si': 'තරල මට්ටම් පරීක්ෂාව', 'ta': 'திரவ அளவு சோதனை'},
    'Battery check and replacements': {
      'si': 'බැටරි පරීක්ෂාව',
      'ta': 'பேட்டரி சோதனை',
    },
    'Wiper blade replacement': {
      'si': 'වයිපර් තලය මාරුව',
      'ta': 'வைப்பர் மாற்றம்',
    },
    'Light bulb check': {'si': 'ලාම්පු පරීක්ෂාව', 'ta': 'விளக்கு சோதனை'},
    'Brake system services': {'si': 'බ්‍රේක් සේවාව', 'ta': 'பிரேக் சேவை'},
    'Suspension and alignment services': {
      'si': 'සසස්පෙන්ෂන් සේවාව',
      'ta': 'சஸ்பென்ஷன் சேவை',
    },
    'Exhaust system service': {
      'si': 'නික්මෙන් ගෑස් සේවාව',
      'ta': 'எக்ஸாஸ்ட் சேவை',
    },
    'Air conditioning services': {
      'si': 'ශීතකරණ සේවාව',
      'ta': 'குளிரூட்டல் சேவை',
    },
    'Electrical system services': {'si': 'විදුලි සේවාව', 'ta': 'மின் சேவை'},
    'Car detailing (Interior and exterior cleaning, waxing)': {
      'si': 'වාහන පිරිසිදු කිරීම',
      'ta': 'கார் சுத்தம்',
    },
    'Tire sales and installation': {'si': 'ටයර් විකිණීම', 'ta': 'டயர் விற்பனை'},
    'Pre-purchase inspections': {
      'si': 'මිලදී ගැනීමට පෙර පරීක්ෂාව',
      'ta': 'வாங்கும் முன் சோதனை',
    },
    'Diagnostic testing': {'si': 'රෝග නිර්ණය', 'ta': 'நோயறிதல் சோதனை'},
  };

  String _translateServiceType(String type, String lang) {
    if (lang == 'en') return type;
    return _serviceTypeTranslations[type]?[lang] ?? type;
  }

  @override
  void initState() {
    super.initState();
    _loadServiceRecords();
  }

  DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    if (value is Map && value['\$date'] != null) {
      return DateTime.tryParse(value['\$date'].toString());
    }
    return DateTime.tryParse(value.toString());
  }

  Future<void> _loadServiceRecords() async {
    setState(() => _isLoading = true);
    try {
      final currentUser = await _authService.getCurrentUser();
      final userId =
          currentUser?['uid']?.toString() ??
          currentUser?['id']?.toString() ??
          currentUser?['_id']?.toString() ??
          currentUser?['userId']?.toString();

      if (userId != null && userId.isNotEmpty) {
        final response = await http.get(
          Uri.parse(
            '${_authService.baseUrl}/service-records/user/${Uri.encodeComponent(userId)}',
          ),
        );

        final records = <Map<String, dynamic>>[];
        if (response.statusCode == 200) {
          final decoded = jsonDecode(response.body) as List<dynamic>;
          records.addAll(
            decoded.map((doc) => Map<String, dynamic>.from(doc as Map)),
          );
        }
        setState(() {
          _serviceRecords = records;
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  List<Map<String, dynamic>> _getFilteredRecords() {
    return _serviceRecords.where((record) {
      bool matchesSearch = true;
      bool matchesFilter = true;
      bool matchesDate = true;

      if (_searchController.text.isNotEmpty) {
        matchesSearch = (record['serviceProvider']?.toString() ?? '')
            .toLowerCase()
            .contains(_searchController.text.toLowerCase());
      }
      if (_selectedFilter != null) {
        matchesFilter = record['serviceType'] == _selectedFilter;
      }
      if (_selectedDate != null) {
        final recordDate = _parseDate(record['date']);
        if (recordDate == null) return false;
        matchesDate =
            recordDate.year == _selectedDate!.year &&
            recordDate.month == _selectedDate!.month &&
            recordDate.day == _selectedDate!.day;
      }
      return matchesSearch && matchesFilter && matchesDate;
    }).toList();
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
      builder:
          (context, child) => Theme(
            data: Theme.of(context).copyWith(
              colorScheme: const ColorScheme.dark(
                primary: AppColors.gold,
                onPrimary: AppColors.obsidian,
                surface: AppColors.surfaceDark,
                onSurface: AppColors.textPrimary,
              ),
            ),
            child: child!,
          ),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() => _selectedDate = picked);
    }
  }

  void _showRecordDetails(Map<String, dynamic> record, String lang) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            backgroundColor: AppColors.surfaceDark,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: const BorderSide(color: AppColors.borderGold),
            ),
            title: Text(
              AppStrings.get('service_details', lang),
              style: GoogleFonts.cormorantGaramond(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            content: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildDetailRow(
                    AppStrings.get('service_type', lang),
                    record['serviceType'] ?? '-',
                  ),
                  _buildDetailRow(
                    AppStrings.get('date', lang),
                    (_parseDate(record['date'])?.toString().split(' ')[0]) ??
                        '-',
                  ),
                  _buildDetailRow(
                    AppStrings.get('current_mileage', lang),
                    '${record['currentMileage'] ?? '-'} KM',
                  ),
                  _buildDetailRow(
                    AppStrings.get('service_mileage', lang),
                    '${record['serviceMileage'] ?? '-'} KM',
                  ),
                  _buildDetailRow(
                    AppStrings.get('service_provider', lang),
                    record['serviceProvider'] ?? '-',
                  ),
                  if (record['serviceType'] == 'Oil Filter Change')
                    _buildDetailRow(
                      AppStrings.get('oil_type', lang),
                      record['oilType'] ?? '-',
                    ),
                  if (record['notes'] != null &&
                      record['notes'].toString().isNotEmpty)
                    _buildDetailRow(
                      AppStrings.get('notes', lang),
                      record['notes'],
                    ),
                ],
              ),
            ),
            actions: [
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.gold,
                    foregroundColor: AppColors.obsidian,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: Text(
                    AppStrings.get('close', lang),
                    style: GoogleFonts.jost(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
          ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.jost(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.5,
              color: AppColors.gold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: GoogleFonts.jost(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: AppColors.textPrimary,
            ),
          ),
          Container(
            height: 1,
            margin: const EdgeInsets.only(top: 8),
            color: AppColors.borderGold,
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
        final filteredRecords = _getFilteredRecords();

        return Scaffold(
          backgroundColor: AppColors.richBlack,
          appBar: AppBar(
            title: Text(
              AppStrings.get('service_history', lang),
              style: GoogleFonts.cormorantGaramond(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            backgroundColor: AppColors.obsidian,
            elevation: 0,
            iconTheme: const IconThemeData(color: AppColors.gold),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios, size: 20),
              onPressed: () => Navigator.pop(context),
            ),
          ),
          body: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // ── Search bar ──────────────────────────────────────────
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.surfaceDark,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.borderGold),
                  ),
                  child: TextField(
                    controller: _searchController,
                    style: GoogleFonts.jost(
                      color: AppColors.textPrimary,
                      fontSize: 14,
                    ),
                    decoration: InputDecoration(
                      hintText: AppStrings.get('search_provider', lang),
                      hintStyle: GoogleFonts.jost(
                        color: AppColors.textMuted,
                        fontSize: 14,
                      ),
                      border: InputBorder.none,
                      prefixIcon: const Icon(
                        Icons.search,
                        color: AppColors.gold,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                const SizedBox(height: 12),

                // ── Filter row ──────────────────────────────────────────
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceDark,
                          border: Border.all(color: AppColors.borderGold),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            isExpanded: true,
                            value: _selectedFilter,
                            dropdownColor: AppColors.surfaceElevated,
                            style: GoogleFonts.jost(
                              color: AppColors.textPrimary,
                              fontSize: 13,
                            ),
                            icon: const Icon(
                              Icons.keyboard_arrow_down_rounded,
                              color: AppColors.gold,
                            ),
                            hint: Text(
                              AppStrings.get('select_service_type', lang),
                              style: GoogleFonts.jost(
                                color: AppColors.textMuted,
                                fontSize: 13,
                              ),
                            ),
                            items:
                                _serviceTypes
                                    .map(
                                      (type) => DropdownMenuItem(
                                        value: type,
                                        child: Text(
                                          _translateServiceType(type, lang),
                                          style: GoogleFonts.jost(
                                            color: AppColors.textPrimary,
                                            fontSize: 13,
                                          ),
                                        ),
                                      ),
                                    )
                                    .toList(),
                            onChanged:
                                (value) =>
                                    setState(() => _selectedFilter = value),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => _selectDate(context),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 14,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceDark,
                            border: Border.all(color: AppColors.borderGold),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                _selectedDate == null
                                    ? AppStrings.get('select_date', lang)
                                    : '${_selectedDate!.day}/${_selectedDate!.month}/${_selectedDate!.year}',
                                style: GoogleFonts.jost(
                                  fontSize: 13,
                                  color:
                                      _selectedDate == null
                                          ? AppColors.textMuted
                                          : AppColors.textPrimary,
                                ),
                              ),
                              const Icon(
                                Icons.calendar_today,
                                size: 16,
                                color: AppColors.gold,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),

                // ── Clear filters row ───────────────────────────────────
                if (_selectedFilter != null || _selectedDate != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: GestureDetector(
                        onTap:
                            () => setState(() {
                              _selectedFilter = null;
                              _selectedDate = null;
                              _searchController.clear();
                            }),
                        child: Text(
                          'Clear filters',
                          style: GoogleFonts.jost(
                            fontSize: 12,
                            color: AppColors.gold,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                    ),
                  ),

                const SizedBox(height: 16),

                // ── Section label ───────────────────────────────────────
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    AppStrings.get('record_details', lang),
                    style: GoogleFonts.jost(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.gold,
                      letterSpacing: 2.5,
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // ── Records list ────────────────────────────────────────
                Expanded(
                  child:
                      _isLoading
                          ? const Center(
                            child: CircularProgressIndicator(
                              color: AppColors.gold,
                            ),
                          )
                          : filteredRecords.isEmpty
                          ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(
                                  Icons.history,
                                  size: 48,
                                  color: AppColors.textMuted,
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  AppStrings.get('no_records', lang),
                                  style: GoogleFonts.jost(
                                    color: AppColors.textMuted,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          )
                          : ListView.builder(
                            itemCount: filteredRecords.length,
                            itemBuilder: (context, index) {
                              final record = filteredRecords[index];
                              return GestureDetector(
                                onTap: () => _showRecordDetails(record, lang),
                                child: ServiceRecordCard(
                                  date:
                                      (_parseDate(
                                        record['date'],
                                      )?.toString().split(' ')[0]) ??
                                      '-',
                                  mileage:
                                      record['serviceMileage']?.toString() ??
                                      '-', // ✅ null safe
                                  provider:
                                      record['serviceProvider']?.toString() ??
                                      'Unknown Center', // ✅
                                  serviceType:
                                      record['serviceType']?.toString() ??
                                      'General Service', // ✅
                                ),
                              );
                            },
                          ),
                ),
              ],
            ),
          ),
          bottomNavigationBar: AppBottomNav(currentIndex: 3),
        );
      },
    );
  }
}

// ── Record card ───────────────────────────────────────────────────────────────
class ServiceRecordCard extends StatelessWidget {
  final String date;
  final String mileage;
  final String provider;
  final String serviceType;

  const ServiceRecordCard({
    super.key,
    required this.date,
    required this.mileage,
    required this.provider,
    required this.serviceType,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.surfaceDark,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.borderGold),
        boxShadow: [
          BoxShadow(
            color: AppColors.gold.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Gold left strip
              Container(width: 4, color: AppColors.gold),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            serviceType,
                            style: GoogleFonts.jost(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          Text(
                            date,
                            style: GoogleFonts.jost(
                              fontWeight: FontWeight.w500,
                              fontSize: 12,
                              color: AppColors.gold,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                      Container(
                        height: 1,
                        margin: const EdgeInsets.symmetric(vertical: 8),
                        color: AppColors.borderGold,
                      ),
                      Row(
                        children: [
                          const Icon(
                            Icons.speed_outlined,
                            size: 14,
                            color: AppColors.textSecondary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '$mileage KM',
                            style: GoogleFonts.jost(
                              color: AppColors.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(width: 16),
                          const Icon(
                            Icons.store_outlined,
                            size: 14,
                            color: AppColors.textSecondary,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              provider,
                              style: GoogleFonts.jost(
                                color: AppColors.textSecondary,
                                fontSize: 12,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
