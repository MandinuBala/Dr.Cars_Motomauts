// lib/appointments/appointments_screen.dart
import 'dart:async';
import 'dart:convert';

import 'package:dr_cars_fyp/auth/auth_service.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:dr_cars_fyp/theme/app_theme.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:dr_cars_fyp/service/add_service.dart';

class AppointmentsScreen extends StatefulWidget {
  const AppointmentsScreen({super.key});

  @override
  State<AppointmentsScreen> createState() => _AppointmentsScreenState();
}

class _AppointmentsScreenState extends State<AppointmentsScreen>
    with SingleTickerProviderStateMixin {
  final AuthService _authService = AuthService();

  String? serviceCenterUid;
  DateTime? selectedDate;

  List<Map<String, dynamic>> _pendingAppointments = [];
  List<Map<String, dynamic>> _acceptedAppointments = [];
  List<Map<String, dynamic>> _rejectedAppointments = [];
  List<Map<String, dynamic>> _vehicleReceivedAppointments = [];

  bool _isLoading = true;
  Timer? _pollingTimer;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _initialize();
    _pollingTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      _fetchAllSilently();
    });
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _initialize() async {
    await _loadUser();
    await _fetchAll();
  }

  Future<void> _loadUser() async {
    final currentUser = await _authService.getCurrentUser();
    final uid =
        currentUser?['uid']?.toString() ??
        currentUser?['id']?.toString() ??
        currentUser?['_id']?.toString() ??
        currentUser?['userId']?.toString();

    if (uid != null && uid.isNotEmpty && mounted) {
      setState(() => serviceCenterUid = uid);
    }
  }

  Future<void> _fetchAll() async {
    if (serviceCenterUid == null || serviceCenterUid!.isEmpty) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }
    setState(() => _isLoading = true);
    await Future.wait([
      _fetchByStatus('pending'),
      _fetchByStatus('accepted'),
      _fetchByStatus('vehicle_received'),
      _fetchByStatus('rejected'),
    ]);
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _fetchAllSilently() async {
    if (!mounted || serviceCenterUid == null) return;
    await Future.wait([
      _fetchByStatus('pending'),
      _fetchByStatus('accepted'),
      _fetchByStatus('vehicle_received'),
      _fetchByStatus('rejected'),
    ]);
  }

  Future<void> _fetchByStatus(String status) async {
    final uid = serviceCenterUid;
    if (uid == null || uid.isEmpty) return;

    try {
      final response = await http.get(
        Uri.parse(
          '${_authService.baseUrl}/appointments/service-center/${Uri.encodeComponent(uid)}?status=$status',
        ),
      );

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body) as List<dynamic>;
        final fetched =
            decoded
                .map((item) => Map<String, dynamic>.from(item as Map))
                .toList();

        fetched.sort((a, b) {
          final aDate = _parseDateTime(a['date'] ?? a['createdAt']);
          final bDate = _parseDateTime(b['date'] ?? b['createdAt']);
          return aDate.compareTo(bDate);
        });

        if (mounted) {
          setState(() {
            if (status == 'pending') _pendingAppointments = fetched;
            if (status == 'accepted') _acceptedAppointments = fetched;
            if (status == 'vehicle_received')
              _vehicleReceivedAppointments = fetched;
            if (status == 'rejected') _rejectedAppointments = fetched;
          });
        }
      }
    } catch (_) {}
  }

  DateTime _parseDateTime(dynamic value) {
    if (value == null) return DateTime(2000);
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value) ?? DateTime(2000);
    if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
    if (value is Map && value['\$date'] != null) {
      return DateTime.tryParse(value['\$date'].toString()) ?? DateTime(2000);
    }
    return DateTime.tryParse(value.toString()) ?? DateTime(2000);
  }

  Future<void> _updateStatus(String appointmentId, String newStatus) async {
    try {
      final response = await http.patch(
        Uri.parse('${_authService.baseUrl}/appointments/$appointmentId/status'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'status': newStatus}),
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        await _fetchAll();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor:
                  newStatus == 'accepted' ? AppColors.success : AppColors.error,
              content: Text(
                newStatus == 'accepted'
                    ? '✅ Appointment accepted.'
                    : '❌ Appointment rejected.',
                style: GoogleFonts.jost(color: Colors.white),
              ),
            ),
          );
        }
      } else {
        throw Exception('Server returned ${response.statusCode}');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  String _formatDate(dynamic dateValue) {
    if (dateValue is String) return dateValue.split('T').first;
    if (dateValue is DateTime)
      return dateValue.toIso8601String().split('T').first;
    return '-';
  }

  List<Map<String, dynamic>> _applyDateFilter(List<Map<String, dynamic>> list) {
    if (selectedDate == null) return list;
    return list.where((data) {
      final docDate = _parseDateTime(data['date']);
      return docDate.year == selectedDate!.year &&
          docDate.month == selectedDate!.month &&
          docDate.day == selectedDate!.day;
    }).toList();
  }

  // ── Tab with badge ────────────────────────────────────────────────────────
  Widget _tabLabel(String label, int count, Color badgeColor) {
    return Tab(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(label),
          if (count > 0) ...[
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: badgeColor,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$count',
                style: GoogleFonts.jost(
                  fontSize: 11,
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.richBlack,
      appBar: AppBar(
        backgroundColor: AppColors.obsidian,
        foregroundColor: AppColors.textPrimary,
        centerTitle: true,
        title: Text(
          'Appointments',
          style: GoogleFonts.cormorantGaramond(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
            letterSpacing: 0.5,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_today, color: AppColors.gold),
            tooltip: 'Filter by date',
            onPressed: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: selectedDate ?? DateTime.now(),
                firstDate: DateTime(2020),
                lastDate: DateTime(2030),
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
              if (picked != null) setState(() => selectedDate = picked);
            },
          ),
          if (selectedDate != null)
            IconButton(
              icon: const Icon(Icons.clear, color: AppColors.gold),
              tooltip: 'Clear date filter',
              onPressed: () => setState(() => selectedDate = null),
            ),
          IconButton(
            icon: const Icon(Icons.refresh, color: AppColors.gold),
            tooltip: 'Refresh',
            onPressed: _fetchAll,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.gold,
          unselectedLabelColor: AppColors.textMuted,
          indicatorColor: AppColors.gold,
          indicatorWeight: 2,
          labelStyle: GoogleFonts.jost(
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
          unselectedLabelStyle: GoogleFonts.jost(fontSize: 13),
          tabs: [
            _tabLabel('Pending', _pendingAppointments.length, AppColors.gold),
            _tabLabel(
              'Accepted',
              _acceptedAppointments.length,
              AppColors.success,
            ),
            _tabLabel(
              'In Service',
              _vehicleReceivedAppointments.length,
              AppColors.gold,
            ),
            _tabLabel(
              'Rejected',
              _rejectedAppointments.length,
              AppColors.error,
            ),
          ],
        ),
      ),
      body:
          _isLoading
              ? const Center(
                child: CircularProgressIndicator(color: AppColors.gold),
              )
              : TabBarView(
                controller: _tabController,
                children: [
                  _buildAppointmentList(
                    _applyDateFilter(_pendingAppointments),
                    'pending',
                  ),
                  _buildAppointmentList(
                    _applyDateFilter(_acceptedAppointments),
                    'accepted',
                  ),
                  _buildAppointmentList(
                    _applyDateFilter(_vehicleReceivedAppointments),
                    'vehicle_received',
                  ),
                  _buildAppointmentList(
                    _applyDateFilter(_rejectedAppointments),
                    'rejected',
                  ),
                ],
              ),
    );
  }

  Widget _buildAppointmentList(
    List<Map<String, dynamic>> appointments,
    String status,
  ) {
    if (appointments.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              status == 'pending'
                  ? Icons.hourglass_empty
                  : status == 'accepted'
                  ? Icons.check_circle_outline
                  : Icons.cancel_outlined,
              size: 48,
              color: AppColors.textMuted,
            ),
            const SizedBox(height: 12),
            Text(
              'No $status appointments${selectedDate != null ? ' on this date' : ''}.',
              style: GoogleFonts.jost(color: AppColors.textMuted, fontSize: 14),
            ),
          ],
        ),
      );
    }

    // Status color
    Color statusColor;
    if (status == 'accepted')
      statusColor = AppColors.success;
    else if (status == 'rejected')
      statusColor = AppColors.error;
    else
      statusColor = AppColors.gold;

    return RefreshIndicator(
      color: AppColors.gold,
      onRefresh: _fetchAll,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: appointments.length,
        itemBuilder: (context, index) {
          final data = appointments[index];
          final appointmentId = data['_id']?.toString() ?? '';
          final serviceTypes = data['serviceTypes'];
          final serviceTypesText =
              serviceTypes is List
                  ? serviceTypes.map((item) => item.toString()).join(', ')
                  : '-';

          return Container(
            margin: const EdgeInsets.only(bottom: 16),
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
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(width: 4, color: statusColor),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Header
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  data['vehicleNumber'] ?? '-',
                                  style: GoogleFonts.cormorantGaramond(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: statusColor.withOpacity(0.1),
                                    border: Border.all(color: statusColor),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    status.toUpperCase(),
                                    style: GoogleFonts.jost(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 1.2,
                                      color: statusColor,
                                    ),
                                  ),
                                ),
                              ],
                            ),

                            Container(
                              height: 1,
                              margin: const EdgeInsets.symmetric(vertical: 12),
                              color: AppColors.borderGold,
                            ),

                            _infoRow(
                              Icons.directions_car,
                              'Model',
                              data['vehicleModel'],
                            ),
                            const SizedBox(height: 6),
                            _infoRow(
                              Icons.calendar_today,
                              'Date',
                              _formatDate(data['date']),
                            ),
                            const SizedBox(height: 6),
                            _infoRow(Icons.access_time, 'Time', data['time']),
                            const SizedBox(height: 6),
                            _infoRow(Icons.phone, 'Contact', data['Contact']),
                            const SizedBox(height: 6),
                            _infoRow(
                              Icons.build_outlined,
                              'Services',
                              serviceTypesText,
                            ),

                            const SizedBox(height: 16),

                            // Action buttons
                            if (status == 'pending')
                              Row(
                                children: [
                                  Expanded(
                                    child: ElevatedButton.icon(
                                      onPressed:
                                          appointmentId.isEmpty
                                              ? null
                                              : () => _updateStatus(
                                                appointmentId,
                                                'accepted',
                                              ),
                                      icon: const Icon(Icons.check, size: 16),
                                      label: const Text('Accept'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: AppColors.gold,
                                        foregroundColor: AppColors.obsidian,
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 12,
                                        ),
                                        elevation: 0,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: OutlinedButton.icon(
                                      onPressed:
                                          appointmentId.isEmpty
                                              ? null
                                              : () => _updateStatus(
                                                appointmentId,
                                                'rejected',
                                              ),
                                      icon: const Icon(Icons.close, size: 16),
                                      label: const Text('Reject'),
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: AppColors.error,
                                        side: const BorderSide(
                                          color: AppColors.error,
                                        ),
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 12,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              )
                            else if (status == 'accepted')
                              // ── Waiting for customer to hand over vehicle ─────────
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: AppColors.gold.withOpacity(0.08),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: AppColors.gold.withOpacity(0.3),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.hourglass_top,
                                      color: AppColors.gold,
                                      size: 16,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        'Awaiting vehicle handover from customer.',
                                        style: GoogleFonts.jost(
                                          color: AppColors.gold,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            else if (status == 'vehicle_received')
                              // ── Vehicle received — now send the receipt ───────────
                              Column(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: AppColors.success.withOpacity(
                                        0.08,
                                      ),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: AppColors.success.withOpacity(
                                          0.3,
                                        ),
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        const Icon(
                                          Icons.car_repair,
                                          color: AppColors.success,
                                          size: 16,
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            'Vehicle received. Add service charges and send receipt to customer.',
                                            style: GoogleFonts.jost(
                                              color: AppColors.success,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  SizedBox(
                                    width: double.infinity,
                                    child: ElevatedButton.icon(
                                      onPressed: () {
                                        final vNumber =
                                            data['vehicleNumber']?.toString() ??
                                            '';
                                        if (vNumber.isEmpty) {
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            SnackBar(
                                              backgroundColor: AppColors.error,
                                              content: Text(
                                                'Vehicle number not found.',
                                                style: GoogleFonts.jost(
                                                  color: Colors.white,
                                                ),
                                              ),
                                            ),
                                          );
                                          return;
                                        }
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder:
                                                (_) => AddService(
                                                  vehicleNumber: vNumber,
                                                ),
                                          ),
                                        );
                                      },
                                      icon: const Icon(
                                        Icons.receipt_long,
                                        size: 16,
                                      ),
                                      label: Text(
                                        'Add Service Charges & Send Receipt',
                                        style: GoogleFonts.jost(
                                          fontWeight: FontWeight.w700,
                                          letterSpacing: 1.0,
                                          fontSize: 13,
                                        ),
                                      ),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: AppColors.gold,
                                        foregroundColor: AppColors.obsidian,
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 12,
                                        ),
                                        elevation: 0,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              )
                            else if (status == 'rejected')
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: AppColors.error.withOpacity(0.08),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: AppColors.error.withOpacity(0.3),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.info_outline,
                                      color: AppColors.error,
                                      size: 16,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Customer has been notified of rejection.',
                                      style: GoogleFonts.jost(
                                        color: AppColors.error,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ],
                                ),
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
        },
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, dynamic value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 14, color: AppColors.gold),
        const SizedBox(width: 8),
        Text(
          '$label: ',
          style: GoogleFonts.jost(fontSize: 12, color: AppColors.textSecondary),
        ),
        Expanded(
          child: Text(
            value?.toString() ?? '-',
            style: GoogleFonts.jost(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
        ),
      ],
    );
  }
}
