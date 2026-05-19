// lib/appointments/appointment_notification.dart
import 'dart:async';
import 'dart:convert';

import 'package:dr_cars_fyp/auth/auth_service.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:dr_cars_fyp/theme/app_theme.dart';
import 'package:google_fonts/google_fonts.dart';

class AppointmentNotificationPage extends StatefulWidget {
  const AppointmentNotificationPage({super.key});

  @override
  State<AppointmentNotificationPage> createState() =>
      _AppointmentNotificationPageState();
}

class _AppointmentNotificationPageState
    extends State<AppointmentNotificationPage> {
  final AuthService _authService = AuthService();
  String? vehicleNumber;
  List<Map<String, dynamic>> _appointments = [];
  bool _isLoading = true;
  Timer? _pollingTimer;

  @override
  void initState() {
    super.initState();
    _initializePage();
    _pollingTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      _refreshAppointmentsSilently();
    });
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    super.dispose();
  }

  Future<void> _initializePage() async {
    await _loadVehicleNumber();
    await _fetchAppointments();
  }

  Future<void> _loadVehicleNumber() async {
    final currentUser = await _authService.getCurrentUser();
    final uid =
        currentUser?['uid']?.toString() ??
        currentUser?['id']?.toString() ??
        currentUser?['_id']?.toString() ??
        currentUser?['userId']?.toString();

    if (uid == null || uid.isEmpty) return;

    try {
      final vehicle = await _authService.getVehicleByUserId(uid);
      if (vehicle != null && mounted) {
        setState(() {
          vehicleNumber =
              vehicle['vehicleNumber']?.toString() ??
              vehicle['plateNumber']?.toString();
        });
      }
    } catch (_) {}
  }

  Future<void> _fetchAppointments() async {
    if (vehicleNumber == null || vehicleNumber!.isEmpty) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _appointments = [];
        });
      }
      return;
    }

    try {
      final response = await http.get(
        Uri.parse(
          '${_authService.baseUrl}/appointments/vehicle/${Uri.encodeComponent(vehicleNumber!)}',
        ),
      );

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body) as List<dynamic>;
        if (mounted) {
          setState(() {
            _appointments =
                decoded
                    .map((item) => Map<String, dynamic>.from(item as Map))
                    .toList();
            _isLoading = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _appointments = [];
            _isLoading = false;
          });
        }
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _appointments = [];
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _refreshAppointmentsSilently() async {
    if (!mounted || vehicleNumber == null || vehicleNumber!.isEmpty) return;
    await _fetchAppointments();
  }

  int _countByStatus(String status) =>
      _appointments.where((a) => a['status'] == status).length;

  List<Map<String, dynamic>> _appointmentsByStatus(String status) =>
      _appointments.where((a) => a['status'] == status).toList();

  Future<Map<String, dynamic>?> _getUserById(String id) async {
    if (id.isEmpty) return null;
    try {
      final response = await http.get(
        Uri.parse('${_authService.baseUrl}/users/${Uri.encodeComponent(id)}'),
      );
      if (response.statusCode == 200) {
        return Map<String, dynamic>.from(jsonDecode(response.body) as Map);
      }
    } catch (_) {}
    return null;
  }

  Future<void> _deleteAppointment(String id) async {
    if (id.isEmpty) return;
    final response = await http.delete(
      Uri.parse('${_authService.baseUrl}/appointments/$id'),
    );
    if (response.statusCode >= 200 && response.statusCode < 300) {
      await _fetchAppointments();
      return;
    }
    throw Exception('Failed to delete appointment');
  }

  Future<void> _updateAppointmentStatus(String id, String status) async {
    if (id.isEmpty) return;
    final response = await http.patch(
      Uri.parse('${_authService.baseUrl}/appointments/$id/status'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'status': status}),
    );
    if (response.statusCode >= 200 && response.statusCode < 300) {
      await _fetchAppointments();
      return;
    }
    print(
      'Failed to update appointment. Status code: ${response.statusCode}, Body: ${response.body}',
    );
    throw Exception(
      'Failed to update appointment Response: ${response.statusCode} ${response.body}',
    );
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
    if (_isLoading) {
      return Scaffold(
        backgroundColor: AppColors.richBlack,
        body: const Center(
          child: CircularProgressIndicator(color: AppColors.gold),
        ),
      );
    }

    return DefaultTabController(
      length: 4,
      child: Scaffold(
        backgroundColor: AppColors.richBlack,
        appBar: AppBar(
          backgroundColor: AppColors.obsidian,
          foregroundColor: AppColors.textPrimary,
          title: Text(
            'Appointment Notifications',
            style: GoogleFonts.cormorantGaramond(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
              letterSpacing: 0.5,
            ),
          ),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(kToolbarHeight),
            child: TabBar(
              isScrollable: true,
              tabAlignment: TabAlignment.start,
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
                _tabLabel('Pending', _countByStatus('pending'), AppColors.gold),
                _tabLabel(
                  'Accepted',
                  _countByStatus('accepted'),
                  AppColors.success,
                ),
                _tabLabel(
                  'In Service',
                  _countByStatus('vehicle_received'),
                  AppColors.gold,
                ),
                _tabLabel(
                  'Rejected',
                  _countByStatus('rejected'),
                  AppColors.error,
                ),
              ],
            ),
          ),
        ),
        body: TabBarView(
          children: [
            _buildAppointmentList('pending'),
            _buildAppointmentList('accepted'),
            _buildAppointmentList('vehicle_received'),
            _buildAppointmentList('rejected'),
          ],
        ),
      ),
    );
  }

  Widget _buildAppointmentList(String status) {
    final appointments = _appointmentsByStatus(status);

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
                  : status == 'vehicle_received'
                  ? Icons.car_repair
                  : Icons.cancel_outlined,
              size: 48,
              color: AppColors.textMuted,
            ),
            const SizedBox(height: 12),
            Text(
              status == 'vehicle_received'
                  ? 'No vehicles currently in service.'
                  : 'No $status appointments.',
              style: GoogleFonts.jost(color: AppColors.textMuted, fontSize: 14),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: appointments.length,
      itemBuilder: (context, index) {
        final appointment = appointments[index];
        final docId = appointment['_id']?.toString() ?? '';
        final serviceCenterUid =
            appointment['serviceCenterUid']?.toString() ?? '';

        return FutureBuilder<Map<String, dynamic>?>(
          future: _getUserById(serviceCenterUid),
          builder: (context, snapshot) {
            String serviceCenterName = 'Loading...';
            if (snapshot.connectionState == ConnectionState.done) {
              final userData = snapshot.data;
              serviceCenterName =
                  userData?['Service Center Name']?.toString() ??
                  userData?['serviceCenterName']?.toString() ??
                  userData?['name']?.toString() ??
                  'Unknown';
            }

            final serviceTypes = appointment['serviceTypes'];
            final servicesText =
                serviceTypes is List
                    ? serviceTypes.map((e) => e.toString()).join(', ')
                    : '-';

            // Status color
            Color statusColor;
            if (status == 'accepted') {
              statusColor = AppColors.success;
            } else if (status == 'rejected') {
              statusColor = AppColors.error;
            } else {
              statusColor = AppColors.gold;
            }

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
                      // ── Colored left strip ──────────────────────────────
                      Container(width: 4, color: statusColor),

                      // ── Card content ────────────────────────────────────
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Header row
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text(
                                      'Appointment ${index + 1}',
                                      style: GoogleFonts.cormorantGaramond(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.textPrimary,
                                      ),
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
                              const SizedBox(height: 4),
                              Text(
                                serviceCenterName,
                                style: GoogleFonts.jost(
                                  fontSize: 13,
                                  color: AppColors.gold,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),

                              Container(
                                height: 1,
                                margin: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                                color: AppColors.borderGold,
                              ),

                              _infoRow(
                                Icons.directions_car,
                                'Model',
                                appointment['vehicleModel'],
                              ),
                              const SizedBox(height: 6),
                              _infoRow(
                                Icons.calendar_today,
                                'Date',
                                appointment['date']
                                        ?.toString()
                                        .split('T')
                                        .first ??
                                    '-',
                              ),
                              const SizedBox(height: 6),
                              _infoRow(
                                Icons.access_time,
                                'Time',
                                appointment['time'],
                              ),
                              const SizedBox(height: 6),
                              _infoRow(
                                Icons.build_outlined,
                                'Services',
                                servicesText,
                              ),

                              const SizedBox(height: 16),

                              // ── Action buttons ──────────────────────────
                              if (status == 'pending')
                                SizedBox(
                                  width: double.infinity,
                                  child: OutlinedButton.icon(
                                    onPressed: () async {
                                      try {
                                        await _deleteAppointment(docId);
                                      } catch (e) {
                                        if (mounted) {
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            SnackBar(
                                              content: Text('Error: $e'),
                                            ),
                                          );
                                        }
                                      }
                                    },
                                    icon: const Icon(
                                      Icons.cancel_outlined,
                                      size: 16,
                                    ),
                                    label: const Text('Cancel'),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: AppColors.error,
                                      side: const BorderSide(
                                        color: AppColors.error,
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 12,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                  ),
                                )
                              else if (status == 'accepted')
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
                                            Icons.info_outline,
                                            color: AppColors.success,
                                            size: 16,
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              'Your appointment is confirmed. Click below once you hand over your vehicle.',
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
                                        onPressed: () async {
                                          try {
                                            // ── Change status to vehicle_received instead of deleting ──
                                            await _updateAppointmentStatus(
                                              docId,
                                              'vehicle_received',
                                            );
                                            if (mounted) {
                                              ScaffoldMessenger.of(
                                                context,
                                              ).showSnackBar(
                                                SnackBar(
                                                  backgroundColor:
                                                      AppColors.success,
                                                  content: Text(
                                                    'Vehicle handed over. Awaiting service charges.',
                                                    style: GoogleFonts.jost(
                                                      color: Colors.white,
                                                    ),
                                                  ),
                                                ),
                                              );
                                            }
                                          } catch (e) {
                                            if (mounted) {
                                              ScaffoldMessenger.of(
                                                context,
                                              ).showSnackBar(
                                                SnackBar(
                                                  content: Text('Error: $e'),
                                                ),
                                              );
                                            }
                                          }
                                        },
                                        icon: const Icon(
                                          Icons.car_repair,
                                          size: 16,
                                        ),
                                        label: Text(
                                          'Handed Over Vehicle',
                                          style: GoogleFonts.jost(
                                            fontWeight: FontWeight.w700,
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
                                Row(
                                  children: [
                                    Expanded(
                                      child: ElevatedButton.icon(
                                        onPressed: () async {
                                          try {
                                            await _updateAppointmentStatus(
                                              docId,
                                              'pending',
                                            );
                                          } catch (e) {
                                            if (mounted) {
                                              ScaffoldMessenger.of(
                                                context,
                                              ).showSnackBar(
                                                SnackBar(
                                                  content: Text('Error: $e'),
                                                ),
                                              );
                                            }
                                          }
                                        },
                                        icon: const Icon(
                                          Icons.refresh,
                                          size: 16,
                                        ),
                                        label: const Text('Resend'),
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
                                        onPressed: () async {
                                          try {
                                            await _deleteAppointment(docId);
                                          } catch (e) {
                                            if (mounted) {
                                              ScaffoldMessenger.of(
                                                context,
                                              ).showSnackBar(
                                                SnackBar(
                                                  content: Text('Error: $e'),
                                                ),
                                              );
                                            }
                                          }
                                        },
                                        icon: const Icon(
                                          Icons.delete_outline,
                                          size: 16,
                                        ),
                                        label: const Text('Delete'),
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
                              else if (status == 'vehicle_received')
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
                                        Icons.car_repair,
                                        color: AppColors.gold,
                                        size: 16,
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          'Your vehicle is currently being serviced. You will receive a receipt shortly.',
                                          style: GoogleFonts.jost(
                                            color: AppColors.gold,
                                            fontSize: 12,
                                          ),
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
        );
      },
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
