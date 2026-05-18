import 'dart:async';
import 'dart:convert';
import 'package:dr_cars_fyp/auth/auth_service.dart';
import 'package:dr_cars_fyp/service/service_history.dart';
import 'package:dr_cars_fyp/admin/dashboard/vehicle_dashboard.dart';
import 'package:dr_cars_fyp/appointments/appointment_notification.dart';
import 'package:dr_cars_fyp/map/mapscreen.dart';
import 'package:dr_cars_fyp/user/user_profile.dart';
import 'package:dr_cars_fyp/recipt_notification/recipt_notification_page.dart';
import 'package:flutter/material.dart';
import 'package:dr_cars_fyp/obd/OBD2.dart';
import 'package:dr_cars_fyp/service/service_records.dart';
import 'package:dr_cars_fyp/appointments/appointments.dart';
import 'dart:ui';
import 'package:http/http.dart' as http;
import 'package:dr_cars_fyp/user/car_3d_viewer.dart';
import 'package:dr_cars_fyp/utils/vehicle_image_helper.dart';
import 'package:dr_cars_fyp/l10n/app_strings.dart';
import 'package:dr_cars_fyp/providers/locale_provider.dart';
import 'package:dr_cars_fyp/theme/app_theme.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:dr_cars_fyp/widgets/app_bottom_nav.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});
  @override
  _DashboardScreenState createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final AuthService _authService = AuthService();
  String userName = "Loading...";
  int _selectedIndex = 0;
  Map<String, dynamic>? vehicleData;
  bool isLoading = true;
  String? errorMessage;
  String? _vehicleImageUrl;
  bool _hasVehicleInfo = false;
  bool _checkingVehicleInfo = true;

  Future<Map<String, int>>? _notificationFuture;

  @override
  void initState() {
    super.initState();
    _initDashboard();
  }

  Future<void> _fetchUserData() async {
    try {
      final user = await _authService.getCurrentUser();
      if (user == null) {
        setState(() => userName = "User");
        return;
      }
      setState(() {
        userName =
            user['Name']?.toString() ?? user['name']?.toString() ?? "User";
      });
    } catch (e) {
      setState(() => userName = "User");
      debugPrint("Error fetching user data: $e");
    }
  }

  Future<void> _initDashboard() async {
    try {
      final user = await _authService.getCurrentUser();
      if (user == null) {
        setState(() {
          userName = "User";
          isLoading = false;
          _checkingVehicleInfo = false;
        });
        return;
      }

      setState(() {
        userName =
            user['Name']?.toString() ?? user['name']?.toString() ?? "User";
      });

      final uid =
          user['uid']?.toString() ??
          user['id']?.toString() ??
          user['_id']?.toString() ??
          user['userId']?.toString();

      if (uid == null || uid.isEmpty) {
        setState(() {
          isLoading = false;
          _checkingVehicleInfo = false;
          errorMessage = "Could not identify user";
        });
        return;
      }

      final vehicleDoc = await _authService.getVehicleByUserId(uid);

      setState(() {
        vehicleData = vehicleDoc;
        _hasVehicleInfo = vehicleDoc != null;
        _vehicleImageUrl = vehicleDoc?['vehiclePhotoUrl'];
        if (vehicleDoc == null) {
          errorMessage =
              "No vehicle data found. Please add your vehicle in your profile.";
        }
        isLoading = false;
        _checkingVehicleInfo = false;
      });

      if (vehicleDoc?['vehicleNumber'] != null) {
        setState(() {
          _notificationFuture = _loadNotificationCounts();
        });
      }
    } catch (e) {
      debugPrint("Dashboard init error: $e");
      try {
        setState(() {
          isLoading = false;
          _checkingVehicleInfo = false;
          errorMessage = "Failed to load data.";
        });
      } catch (_) {}
      // setState(() {
      //   isLoading = false;
      //   _checkingVehicleInfo = false;
      //   errorMessage = "Failed to load data.";
      // });
    }
  }

  static const Map<String, List<String>> _availableModels = {
    'BMW': ['Z4'],
    'Toyota': ['Camry', 'Crown', 'Fortuner'],
    'Nissan': ['X-Trail', 'GT-R', '370Z'],
    'Honda': ['Vezel'],
    'Suzuki': ['Vitara'],
    'Mazda': ['CX-5'],
    'Kia': ['Picanto'],
    'Hyundai': ['Santa fe'],
  };

  Widget _buildVehicleDisplay(double w) {
    final brand = vehicleData?['selectedBrand']?.toString();
    final model = vehicleData?['selectedModel']?.toString();
    final hasGlb = _availableModels[brand]?.contains(model) ?? false;
    final vehicleAsset = VehicleImageHelper.getImage(brand, model);

    Widget imageWidget;
    if (_vehicleImageUrl != null && _vehicleImageUrl!.isNotEmpty) {
      imageWidget = Image.network(
        _vehicleImageUrl!,
        fit: BoxFit.contain,
        errorBuilder:
            (_, __, ___) =>
                vehicleAsset != null
                    ? Image.asset(vehicleAsset, fit: BoxFit.contain)
                    : Image.asset('images/dashcar.png', fit: BoxFit.contain),
      );
    } else if (vehicleAsset != null) {
      imageWidget = Image.asset(vehicleAsset, fit: BoxFit.contain);
    } else {
      imageWidget = Image.asset('images/dashcar.png', fit: BoxFit.contain);
    }

    return Stack(
      children: [
        // ── Light container — matches car photo background ─────────────
        Container(
          width: w,
          height: 200,
          color: const Color(0xFFF0EEEA), // warm light grey matching car photos
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Center(child: imageWidget),
          ),
        ),

        // ── Strong bottom gradient: light → dark card ─────────────────
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: Container(
            height: 90,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  AppColors.surfaceDark.withOpacity(0.6),
                  AppColors.surfaceDark,
                ],
                stops: const [0.0, 0.6, 1.0],
              ),
            ),
          ),
        ),

        // ── Left fade ─────────────────────────────────────────────────
        Positioned(
          left: 0,
          top: 0,
          bottom: 0,
          child: Container(
            width: 28,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.centerRight,
                end: Alignment.centerLeft,
                colors: [
                  Colors.transparent,
                  AppColors.surfaceDark.withOpacity(0.4),
                ],
              ),
            ),
          ),
        ),

        // ── Right fade ────────────────────────────────────────────────
        Positioned(
          right: 0,
          top: 0,
          bottom: 0,
          child: Container(
            width: 28,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [
                  Colors.transparent,
                  AppColors.surfaceDark.withOpacity(0.4),
                ],
              ),
            ),
          ),
        ),

        // ── 3D button ─────────────────────────────────────────────────
        if (hasGlb)
          Positioned(
            bottom: 12,
            right: 12,
            child: GestureDetector(
              onTap:
                  () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder:
                          (_) => Car3DViewerPage(brand: brand!, model: model!),
                    ),
                  ),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.65),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white24),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.view_in_ar, color: Colors.white, size: 18),
                    SizedBox(width: 6),
                    Text(
                      'View in 3D',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  int getNextMaintenanceMileage(int current) => ((current ~/ 5000) + 1) * 5000;

  Future<Map<String, int>> _loadNotificationCounts() async {
    try {
      final vehicleNumber = vehicleData?['vehicleNumber']?.toString();
      if (vehicleNumber == null || vehicleNumber.isEmpty) {
        return {'receipts': 0, 'appointments': 0};
      }

      final receiptsResponse = await http.get(
        Uri.parse(
          '${_authService.baseUrl}/service-receipts/vehicle/${Uri.encodeComponent(vehicleNumber)}',
        ),
      );
      int receiptsCount = 0;
      if (receiptsResponse.statusCode == 200) {
        final decoded = jsonDecode(receiptsResponse.body) as List<dynamic>;
        receiptsCount =
            decoded
                .where(
                  (item) =>
                      ((item as Map<String, dynamic>)['status'] ??
                                  item['Status'])
                              ?.toString()
                              .toLowerCase() ==
                          'not confirmed' ||
                      ((item)['status'] ?? item['Status'])
                              ?.toString()
                              .toLowerCase() ==
                          'finished',
                )
                .length;
      }

      final appointmentsResponse = await http.get(
        Uri.parse(
          '${_authService.baseUrl}/appointments/vehicle/${Uri.encodeComponent(vehicleNumber)}',
        ),
      );
      int appointmentsCount = 0;
      if (appointmentsResponse.statusCode == 200) {
        final decoded = jsonDecode(appointmentsResponse.body) as List<dynamic>;
        appointmentsCount =
            decoded
                .where(
                  (item) =>
                      ((item as Map<String, dynamic>)['status'] ??
                                  item['Status'])
                              ?.toString()
                              .toLowerCase() ==
                          'accepted' ||
                      ((item)['status'] ?? item['Status'])
                              ?.toString()
                              .toLowerCase() ==
                          'rejected',
                )
                .length;
      }

      return {'receipts': receiptsCount, 'appointments': appointmentsCount};
    } catch (e) {
      debugPrint("Error loading notification counts: $e");
      return {'receipts': 0, 'appointments': 0};
    }
  }

  Widget _buildVehicleDashboardButton() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surfaceDark,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderGold),
        boxShadow: [
          BoxShadow(
            color: AppColors.gold.withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap:
              () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const VehicleDashboardScreen(),
                ),
              ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.gold.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.all(12),
                  child: const Icon(
                    Icons.dashboard_customize,
                    color: AppColors.gold,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Vehicle Dashboard',
                        style: GoogleFonts.jost(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'View real-time vehicle metrics and status',
                        style: GoogleFonts.jost(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.arrow_forward_ios,
                  size: 14,
                  color: AppColors.gold,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSmartVehicleDashboardButton(String lang) {
    if (_checkingVehicleInfo) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (!_hasVehicleInfo) {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: goldBorderCard(),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap:
              () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ProfileScreen()),
              ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.gold.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.all(12),
                  child: const Icon(
                    Icons.directions_car,
                    color: AppColors.gold,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        AppStrings.get('setup_vehicle', lang),
                        style: GoogleFonts.jost(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        AppStrings.get('setup_vehicle_sub', lang),
                        style: GoogleFonts.jost(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.arrow_forward_ios,
                  size: 14,
                  color: AppColors.gold,
                ),
              ],
            ),
          ),
        ),
      );
    }
    return _buildVehicleDashboardButton();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: localeNotifier,
      builder: (context, lang, _) {
        final theme = Theme.of(context);
        final w = MediaQuery.of(context).size.width;
        final text = theme.textTheme;

        return Scaffold(
          backgroundColor: AppColors.richBlack, // ← fixes white page background
          appBar: AppBar(
            backgroundColor: AppColors.obsidian,
            automaticallyImplyLeading: false,
            title: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    ClipOval(
                      child: Image.asset(
                        'images/logo.png',
                        width: 40,
                        height: 40,
                        fit: BoxFit.cover,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          AppStrings.get('welcome_back', lang),
                          style: text.bodyLarge?.copyWith(
                            color: Colors.white70,
                            fontSize: 16,
                          ),
                        ),
                        Text(
                          userName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),

                if (vehicleData?['vehicleNumber'] != null)
                  FutureBuilder<Map<String, int>>(
                    future: _notificationFuture,
                    builder: (_, snap) {
                      if (!snap.hasData) return const SizedBox();
                      final counts = snap.data ?? {};
                      final receiptsCount = counts['receipts'] ?? 0;
                      final appointmentsCount = counts['appointments'] ?? 0;
                      final totalCount = receiptsCount + appointmentsCount;

                      return Stack(
                        children: [
                          IconButton(
                            icon: const Icon(
                              Icons.receipt_long,
                              color: Colors.white,
                            ),
                            onPressed: () {
                              showDialog(
                                context: context,
                                barrierDismissible: true,
                                builder:
                                    (_) => BackdropFilter(
                                      filter: ImageFilter.blur(
                                        sigmaX: 4,
                                        sigmaY: 4,
                                      ),
                                      child: Dialog(
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            16,
                                          ),
                                        ),
                                        backgroundColor: AppColors.surfaceDark,
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 20,
                                          ),
                                          child: Column(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Text(
                                                "Select Notification Type",
                                                style:
                                                    GoogleFonts.cormorantGaramond(
                                                      fontSize: 20,
                                                      fontWeight:
                                                          FontWeight.w700,
                                                      color:
                                                          AppColors.textPrimary,
                                                    ),
                                              ),
                                              const Divider(
                                                color: AppColors.borderGold,
                                              ),
                                              ListTile(
                                                leading: const Icon(
                                                  Icons.receipt_long,
                                                  color: AppColors.gold,
                                                ),
                                                title: Row(
                                                  mainAxisAlignment:
                                                      MainAxisAlignment
                                                          .spaceBetween,
                                                  children: [
                                                    Text(
                                                      AppStrings.get(
                                                        'receipt_notifications',
                                                        lang,
                                                      ),
                                                      style: GoogleFonts.jost(
                                                        color:
                                                            AppColors
                                                                .textPrimary,
                                                        fontSize: 14,
                                                      ),
                                                    ),
                                                    if (receiptsCount > 0)
                                                      Container(
                                                        padding:
                                                            const EdgeInsets.symmetric(
                                                              horizontal: 6,
                                                              vertical: 2,
                                                            ),
                                                        decoration: BoxDecoration(
                                                          color: kErrorRed,
                                                          borderRadius:
                                                              BorderRadius.circular(
                                                                12,
                                                              ),
                                                        ),
                                                        child: Text(
                                                          '$receiptsCount',
                                                          style:
                                                              const TextStyle(
                                                                color:
                                                                    Colors
                                                                        .white,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .bold,
                                                                fontSize: 12,
                                                              ),
                                                        ),
                                                      ),
                                                  ],
                                                ),
                                                onTap: () {
                                                  Navigator.pop(context);
                                                  Navigator.push(
                                                    context,
                                                    MaterialPageRoute(
                                                      builder:
                                                          (_) =>
                                                              const ReceiptNotificationPage(),
                                                    ),
                                                  );
                                                },
                                              ),
                                              ListTile(
                                                leading: const Icon(
                                                  Icons.calendar_today,
                                                  color: AppColors.gold,
                                                ),
                                                title: Row(
                                                  mainAxisAlignment:
                                                      MainAxisAlignment
                                                          .spaceBetween,
                                                  children: [
                                                    Text(
                                                      AppStrings.get(
                                                        'appointment_notifications',
                                                        lang,
                                                      ),
                                                      style: GoogleFonts.jost(
                                                        color:
                                                            AppColors
                                                                .textPrimary,
                                                        fontSize: 14,
                                                      ),
                                                    ),
                                                    if (appointmentsCount > 0)
                                                      Container(
                                                        padding:
                                                            const EdgeInsets.symmetric(
                                                              horizontal: 6,
                                                              vertical: 2,
                                                            ),
                                                        decoration: BoxDecoration(
                                                          color: kErrorRed,
                                                          borderRadius:
                                                              BorderRadius.circular(
                                                                12,
                                                              ),
                                                        ),
                                                        child: Text(
                                                          '$appointmentsCount',
                                                          style:
                                                              const TextStyle(
                                                                color:
                                                                    Colors
                                                                        .white,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .bold,
                                                                fontSize: 12,
                                                              ),
                                                        ),
                                                      ),
                                                  ],
                                                ),
                                                onTap: () {
                                                  Navigator.pop(context);
                                                  Navigator.push(
                                                    context,
                                                    MaterialPageRoute(
                                                      builder:
                                                          (_) =>
                                                              const AppointmentNotificationPage(),
                                                    ),
                                                  );
                                                },
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                              );
                            },
                          ),
                          if (totalCount > 0)
                            Positioned(
                              right: 6,
                              top: 6,
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: const BoxDecoration(
                                  color: kErrorRed,
                                  shape: BoxShape.circle,
                                ),
                                constraints: const BoxConstraints(
                                  minWidth: 20,
                                  minHeight: 20,
                                ),
                                child: Text(
                                  '$totalCount',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ),
                        ],
                      );
                    },
                  ),
              ],
            ),
          ),

          body: SingleChildScrollView(
            child: Column(
              children: [
                const SizedBox(height: 20),
                Text(
                  AppStrings.get('your_vehicle', lang),
                  style: GoogleFonts.cormorantGaramond(
                    fontSize: 32,
                    fontWeight: FontWeight.w600,
                    color: AppColors.gold,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 10),

                if (isLoading)
                  const Padding(
                    padding: EdgeInsets.all(20),
                    child: CircularProgressIndicator(color: AppColors.gold),
                  )
                else if (errorMessage != null)
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      errorMessage!,
                      style: GoogleFonts.jost(
                        color: AppColors.error,
                        fontSize: 16,
                      ),
                    ),
                  )
                else if (vehicleData == null)
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      AppStrings.get('no_vehicle_data', lang),
                      style: GoogleFonts.jost(
                        color: AppColors.textSecondary,
                        fontSize: 16,
                      ),
                    ),
                  )
                else
                  Container(
                    width: w,
                    margin: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceDark,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.borderGold),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.gold.withOpacity(0.08),
                          blurRadius: 20,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        ClipRRect(
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(16),
                          ),
                          child: _buildVehicleDisplay(w),
                        ),
                        Container(height: 1, color: AppColors.borderGold),
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "${vehicleData!['year'] ?? ''}",
                                style: GoogleFonts.jost(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: AppColors.gold,
                                  letterSpacing: 3,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                "${vehicleData!['selectedBrand'] ?? ''} ${vehicleData!['selectedModel'] ?? ''}",
                                style: GoogleFonts.cormorantGaramond(
                                  fontSize: 32,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textPrimary,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    '⚙️ ${vehicleData!['mileage'] ?? '0'} KM',
                                    style: GoogleFonts.jost(
                                      fontSize: 13,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                  Text(
                                    '🚗 ${vehicleData!['vehicleType'] ?? ''}',
                                    style: GoogleFonts.jost(
                                      fontSize: 13,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                              if (vehicleData!['vehicleNumber'] != null)
                                Padding(
                                  padding: const EdgeInsets.only(top: 8),
                                  child: Text(
                                    '${vehicleData!['vehicleNumber']}',
                                    style: GoogleFonts.jost(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.gold,
                                      letterSpacing: 2,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                const SizedBox(height: 20),

                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed:
                          () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const AppointmentsPage(),
                            ),
                          ),
                      icon: const Icon(Icons.calendar_today),
                      label: Text(
                        AppStrings.get('make_appointment', lang),
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 16.0,
                        ),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 10),

                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        foregroundColor: AppColors.gold,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                          side: const BorderSide(
                            color: AppColors.gold,
                            width: 1,
                          ),
                        ),
                      ),
                      onPressed:
                          () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ServiceRecordsPage(),
                            ),
                          ),
                      icon: const Icon(Icons.add),
                      label: Text(
                        AppStrings.get('add_service_record', lang),
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 16.0,
                        ),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 10),

                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      AppStrings.get('upcoming_maintenance', lang),
                      style: GoogleFonts.jost(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.gold,
                        letterSpacing: 2,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 8),

                Container(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceDark,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.borderGold),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.gold.withOpacity(0.05),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap:
                          () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ServiceRecordsPage(),
                            ),
                          ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: AppColors.warning.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: AppColors.warning.withOpacity(0.3),
                                ),
                              ),
                              child: const Icon(
                                Icons.build_outlined,
                                color: AppColors.warning,
                                size: 22,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    vehicleData != null
                                        ? '${vehicleData!['selectedBrand']} ${vehicleData!['selectedModel']} (${vehicleData!['year']})'
                                        : '',
                                    style: GoogleFonts.jost(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    vehicleData != null
                                        ? '${AppStrings.get('next_maintenance', lang)}: ${getNextMaintenanceMileage(int.tryParse(vehicleData!['mileage'].toString()) ?? 0)} KM'
                                        : '',
                                    style: GoogleFonts.jost(
                                      fontSize: 12,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Icon(
                              Icons.arrow_forward_ios,
                              size: 14,
                              color: AppColors.gold,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 8),

                _buildSmartVehicleDashboardButton(lang),

                const SizedBox(height: 20),
              ],
            ),
          ),

          bottomNavigationBar: AppBottomNav(currentIndex: 0),
        );
      },
    );
  }
}
