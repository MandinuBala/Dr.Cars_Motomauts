import 'dart:async';
import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../motornauts/api_error.dart';
import '../motornauts/data_helpers.dart';
import '../motornauts/idempotency.dart';
import '../motornauts/link_parser.dart';
import '../motornauts/motornauts_client.dart';
import '../motornauts/payloads.dart';

const List<String> _vehicleTypes = [
  'CAR',
  'SUV',
  'VAN',
  'PICKUP',
  'MOTORCYCLE',
  'TRUCK',
  'BUS',
  'OTHER',
];
const List<String> _fuelTypes = [
  'PETROL',
  'DIESEL',
  'HYBRID',
  'ELECTRIC',
  'OTHER',
];
const List<String> _transmissions = ['MANUAL', 'AUTOMATIC', 'CVT', 'OTHER'];
const List<String> _ownershipStatuses = ['OWNED', 'LEASED', 'COMPANY', 'OTHER'];
const List<String> _documentTypes = [
  'REGISTRATION_CERTIFICATE',
  'INSURANCE',
  'REVENUE_LICENSE',
  'EMISSION_TEST',
  'OTHER',
];

class BootstrapScreen extends StatefulWidget {
  const BootstrapScreen({required this.client, super.key});

  final MotornautsGateway client;

  @override
  State<BootstrapScreen> createState() => _BootstrapScreenState();
}

class _BootstrapScreenState extends State<BootstrapScreen> {
  Map<String, dynamic>? _tenantProfile;
  String? _error;
  bool _loading = true;
  bool _signedIn = false;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final profile = await widget.client.getPublicTenantProfile();
      var signedIn = false;
      try {
        await widget.client.getCustomerSession();
        signedIn = true;
      } on MotornautsApiException catch (error) {
        if (error.type != MotornautsErrorType.unauthenticated) {
          signedIn = false;
        }
      }
      if (!mounted) {
        return;
      }
      setState(() {
        _tenantProfile = profile;
        _signedIn = signedIn;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = _messageFor(error);
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_error != null || _tenantProfile == null) {
      return TenantUnavailableScreen(
        message: _error ?? 'Tenant unavailable.',
        onRetry: _bootstrap,
      );
    }

    if (_signedIn) {
      return CustomerShell(
        client: widget.client,
        tenantProfile: _tenantProfile!,
        onSignedOut: () => setState(() => _signedIn = false),
      );
    }

    return AuthScreen(
      client: widget.client,
      tenantProfile: _tenantProfile!,
      onSignedIn: () => setState(() => _signedIn = true),
    );
  }
}

class TenantUnavailableScreen extends StatelessWidget {
  const TenantUnavailableScreen({
    required this.message,
    required this.onRetry,
    super.key,
  });

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.domain_disabled_outlined, size: 56),
              const SizedBox(height: 16),
              Text(
                'Tenant unavailable',
                style: Theme.of(context).textTheme.headlineSmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(message, textAlign: TextAlign.center),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class AuthScreen extends StatefulWidget {
  const AuthScreen({
    required this.client,
    required this.tenantProfile,
    required this.onSignedIn,
    super.key,
  });

  final MotornautsGateway client;
  final Map<String, dynamic> tenantProfile;
  final VoidCallback onSignedIn;

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final GlobalKey<FormState> _otpFormKey = GlobalKey<FormState>();
  final GlobalKey<FormState> _registrationFormKey = GlobalKey<FormState>();
  final TextEditingController _contactController = TextEditingController();
  final TextEditingController _codeController = TextEditingController();
  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _address1Controller = TextEditingController();
  final TextEditingController _address2Controller = TextEditingController();
  final TextEditingController _cityController = TextEditingController();
  final TextEditingController _registrationController = TextEditingController();
  final TextEditingController _makeController = TextEditingController();
  final TextEditingController _modelController = TextEditingController();
  final TextEditingController _yearController = TextEditingController();
  final TextEditingController _mileageController = TextEditingController();
  final TextEditingController _nicknameController = TextEditingController();

  String _channel = 'EMAIL';
  String? _challengeId;
  String? _registrationStatus;
  String _vehicleType = 'CAR';
  String _fuelType = 'PETROL';
  String _transmission = 'AUTOMATIC';
  String _ownershipStatus = 'OWNED';
  bool _termsAccepted = false;
  bool _marketingConsent = false;
  bool _requestingOtp = false;
  bool _verifyingOtp = false;
  bool _registering = false;
  bool _registrationAvailable = true;
  String? _termsCopy;
  DateTime? _lastResendAt;
  Map<String, String> _fieldErrors = const {};

  @override
  void initState() {
    super.initState();
    _loadRegistrationAvailability();
  }

  @override
  void dispose() {
    _contactController.dispose();
    _codeController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _address1Controller.dispose();
    _address2Controller.dispose();
    _cityController.dispose();
    _registrationController.dispose();
    _makeController.dispose();
    _modelController.dispose();
    _yearController.dispose();
    _mileageController.dispose();
    _nicknameController.dispose();
    super.dispose();
  }

  Future<void> _loadRegistrationAvailability() async {
    try {
      final response = await widget.client.getSelfRegistrationAvailability();
      if (!mounted) {
        return;
      }
      setState(() {
        _registrationAvailable = response['available'] == true;
        _termsCopy = response['publicTermsCopy']?.toString();
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() => _registrationAvailable = false);
    }
  }

  Future<void> _requestOtp() async {
    if (!_otpFormKey.currentState!.validate()) {
      return;
    }
    setState(() => _requestingOtp = true);
    try {
      final contact = _contactController.text.trim();
      final response = await widget.client.requestOtp(
        MotornautsPayloads.otpRequest(
          channel: _channel,
          email: _channel == 'EMAIL' ? contact : null,
          phone: _channel == 'SMS' ? contact : null,
        ),
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _challengeId =
            response['challengeId']?.toString() ?? response['id']?.toString();
      });
      _showSnack(context, 'OTP sent.');
    } catch (error) {
      if (!mounted) {
        return;
      }
      _showSnack(context, _messageFor(error));
    } finally {
      if (mounted) {
        setState(() => _requestingOtp = false);
      }
    }
  }

  Future<void> _resendOtp() async {
    final challengeId = _challengeId;
    if (challengeId == null || challengeId.isEmpty) {
      return;
    }
    final lastResendAt = _lastResendAt;
    if (lastResendAt != null &&
        DateTime.now().difference(lastResendAt) < const Duration(seconds: 30)) {
      _showSnack(context, 'Please wait before resending.');
      return;
    }
    setState(() => _lastResendAt = DateTime.now());
    try {
      await widget.client.resendOtp(challengeId);
      if (!mounted) {
        return;
      }
      _showSnack(context, 'OTP resent.');
    } catch (error) {
      if (!mounted) {
        return;
      }
      _showSnack(context, _messageFor(error));
    }
  }

  Future<void> _verifyOtp() async {
    final challengeId = _challengeId;
    if (challengeId == null || challengeId.isEmpty) {
      _showSnack(context, 'Request an OTP first.');
      return;
    }
    final code = _codeController.text.trim();
    if (!RegExp(r'^\d{6}$').hasMatch(code)) {
      _showSnack(context, 'Enter the 6-digit OTP.');
      return;
    }
    setState(() => _verifyingOtp = true);
    try {
      await widget.client.verifyOtp(challengeId: challengeId, code: code);
      await widget.client.getCustomerSession();
      if (!mounted) {
        return;
      }
      widget.onSignedIn();
    } catch (error) {
      if (!mounted) {
        return;
      }
      _showSnack(context, _messageFor(error));
    } finally {
      if (mounted) {
        setState(() => _verifyingOtp = false);
      }
    }
  }

  Future<void> _submitRegistration() async {
    setState(() => _fieldErrors = const {});
    if (!_registrationFormKey.currentState!.validate()) {
      return;
    }
    if (!_termsAccepted) {
      _showSnack(context, 'Accept the tenant terms before submitting.');
      return;
    }

    setState(() => _registering = true);
    try {
      final response = await widget.client.submitSelfRegistration(
        MotornautsPayloads.selfRegistration(
          firstName: _firstNameController.text.trim(),
          lastName: _lastNameController.text.trim(),
          email: _emailController.text.trim(),
          phone: _phoneController.text.trim(),
          addressLine1: _address1Controller.text.trim(),
          addressLine2: _address2Controller.text.trim(),
          city: _cityController.text.trim(),
          registrationNumber: _registrationController.text.trim(),
          vehicleType: _vehicleType,
          make: _makeController.text.trim(),
          model: _modelController.text.trim(),
          year: int.parse(_yearController.text.trim()),
          fuelType: _fuelType,
          transmission: _transmission,
          currentMileage: int.parse(_mileageController.text.trim()),
          nickname: _nicknameController.text.trim(),
          ownershipStatus: _ownershipStatus,
          termsAccepted: _termsAccepted,
          marketingConsent: _marketingConsent,
        ),
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _registrationStatus =
            'Submitted: ${valueText(response, const ['requestId', 'id', 'status'])}';
      });
      _showSnack(context, 'Registration request submitted.');
    } on MotornautsApiException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _fieldErrors = error.fieldMessages);
      _showSnack(context, error.message);
    } catch (error) {
      if (!mounted) {
        return;
      }
      _showSnack(context, _messageFor(error));
    } finally {
      if (mounted) {
        setState(() => _registering = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final tenant = objectMap(widget.tenantProfile['tenant']);
    final tenantName = valueText(
      tenant.isEmpty ? widget.tenantProfile : tenant,
      const ['displayName', 'name', 'tenantName', 'slug'],
      fallback: widget.client.config.tenantSlug,
    );

    return Scaffold(
      appBar: AppBar(title: Text(tenantName)),
      body: SafeArea(
        child: DefaultTabController(
          length: 2,
          child: Column(
            children: [
              const TabBar(
                tabs: [
                  Tab(icon: Icon(Icons.password), text: 'OTP Login'),
                  Tab(icon: Icon(Icons.person_add_alt), text: 'Register'),
                ],
              ),
              Expanded(
                child: TabBarView(
                  children: [_buildOtpTab(), _buildRegistrationTab()],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOtpTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'Sign in with your customer OTP. Password and social login are not used for Motornauts customer sessions.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 16),
        SegmentedButton<String>(
          segments: const [
            ButtonSegment(
              value: 'EMAIL',
              label: Text('Email'),
              icon: Icon(Icons.mail_outline),
            ),
            ButtonSegment(
              value: 'SMS',
              label: Text('SMS'),
              icon: Icon(Icons.sms_outlined),
            ),
          ],
          selected: {_channel},
          onSelectionChanged: (value) {
            setState(() {
              _channel = value.first;
              _challengeId = null;
              _codeController.clear();
            });
          },
        ),
        const SizedBox(height: 16),
        Form(
          key: _otpFormKey,
          child: TextFormField(
            controller: _contactController,
            keyboardType:
                _channel == 'EMAIL'
                    ? TextInputType.emailAddress
                    : TextInputType.phone,
            decoration: InputDecoration(
              labelText: _channel == 'EMAIL' ? 'Email' : 'Phone',
              prefixIcon: Icon(
                _channel == 'EMAIL' ? Icons.mail_outline : Icons.phone_outlined,
              ),
            ),
            validator: (value) {
              final text = value?.trim() ?? '';
              if (text.isEmpty) {
                return 'Required';
              }
              if (_channel == 'EMAIL' && !text.contains('@')) {
                return 'Enter a valid email';
              }
              return null;
            },
          ),
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: _requestingOtp ? null : _requestOtp,
          icon:
              _requestingOtp
                  ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                  : const Icon(Icons.send_outlined),
          label: const Text('Request OTP'),
        ),
        if (_challengeId != null) ...[
          const SizedBox(height: 20),
          TextField(
            controller: _codeController,
            keyboardType: TextInputType.number,
            maxLength: 6,
            decoration: const InputDecoration(
              labelText: '6-digit code',
              prefixIcon: Icon(Icons.pin_outlined),
              counterText: '',
            ),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _verifyingOtp ? null : _verifyOtp,
            icon:
                _verifyingOtp
                    ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                    : const Icon(Icons.verified_user_outlined),
            label: const Text('Verify and continue'),
          ),
          TextButton.icon(
            onPressed: _resendOtp,
            icon: const Icon(Icons.refresh),
            label: const Text('Resend OTP'),
          ),
        ],
      ],
    );
  }

  Widget _buildRegistrationTab() {
    if (!_registrationAvailable) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Self-registration is unavailable. Contact the service center.',
          ),
        ),
      );
    }

    return Form(
      key: _registrationFormKey,
      child: ListView(
        key: const Key('registration-scroll'),
        padding: const EdgeInsets.all(16),
        children: [
          if (_termsCopy != null && _termsCopy!.isNotEmpty)
            InfoCard(title: 'Tenant terms', child: Text(_termsCopy!)),
          _textField(_firstNameController, 'First name', 'firstName'),
          _textField(_lastNameController, 'Last name', 'lastName'),
          _textField(_emailController, 'Email', 'email', email: true),
          _textField(_phoneController, 'Phone', 'phone'),
          _textField(
            _address1Controller,
            'Address line 1',
            'addressLine1',
            required: false,
          ),
          _textField(
            _address2Controller,
            'Address line 2',
            'addressLine2',
            required: false,
          ),
          _textField(_cityController, 'City', 'city', required: false),
          const SizedBox(height: 16),
          Text('Vehicle', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          _textField(
            _registrationController,
            'Registration number',
            'registrationNumber',
          ),
          DropdownButtonFormField<String>(
            initialValue: _vehicleType,
            decoration: const InputDecoration(labelText: 'Vehicle type'),
            items: _vehicleTypes.map(_dropdownItem).toList(),
            onChanged:
                (value) => setState(() => _vehicleType = value ?? _vehicleType),
          ),
          const SizedBox(height: 12),
          _textField(_makeController, 'Make', 'make'),
          _textField(_modelController, 'Model', 'model'),
          _numberField(_yearController, 'Year', 'year'),
          DropdownButtonFormField<String>(
            initialValue: _fuelType,
            decoration: const InputDecoration(labelText: 'Fuel type'),
            items: _fuelTypes.map(_dropdownItem).toList(),
            onChanged:
                (value) => setState(() => _fuelType = value ?? _fuelType),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _transmission,
            decoration: const InputDecoration(labelText: 'Transmission'),
            items: _transmissions.map(_dropdownItem).toList(),
            onChanged:
                (value) =>
                    setState(() => _transmission = value ?? _transmission),
          ),
          const SizedBox(height: 12),
          _numberField(_mileageController, 'Current mileage', 'currentMileage'),
          _textField(
            _nicknameController,
            'Nickname',
            'nickname',
            required: false,
          ),
          DropdownButtonFormField<String>(
            initialValue: _ownershipStatus,
            decoration: const InputDecoration(labelText: 'Ownership status'),
            items: _ownershipStatuses.map(_dropdownItem).toList(),
            onChanged:
                (value) => setState(
                  () => _ownershipStatus = value ?? _ownershipStatus,
                ),
          ),
          const SizedBox(height: 12),
          CheckboxListTile(
            value: _termsAccepted,
            onChanged:
                (value) => setState(() => _termsAccepted = value ?? false),
            title: const Text('I accept the tenant terms'),
            controlAffinity: ListTileControlAffinity.leading,
          ),
          CheckboxListTile(
            value: _marketingConsent,
            onChanged:
                (value) => setState(() => _marketingConsent = value ?? false),
            title: const Text('Send me service updates and offers'),
            controlAffinity: ListTileControlAffinity.leading,
          ),
          if (_registrationStatus != null)
            InfoCard(
              title: 'Request status',
              child: Text(_registrationStatus!),
            ),
          const SizedBox(height: 12),
          FilledButton.icon(
            key: const Key('registration-submit'),
            onPressed:
                !_termsAccepted || _registering ? null : _submitRegistration,
            icon:
                _registering
                    ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                    : const Icon(Icons.send_outlined),
            label: const Text('Submit registration request'),
          ),
        ],
      ),
    );
  }

  Widget _textField(
    TextEditingController controller,
    String label,
    String field, {
    bool required = true,
    bool email = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: controller,
        keyboardType: email ? TextInputType.emailAddress : TextInputType.text,
        decoration: InputDecoration(
          labelText: label,
          errorText: _fieldErrors[field],
        ),
        validator: (value) {
          final text = value?.trim() ?? '';
          if (required && text.isEmpty) {
            return 'Required';
          }
          if (email && text.isNotEmpty && !text.contains('@')) {
            return 'Enter a valid email';
          }
          return null;
        },
      ),
    );
  }

  Widget _numberField(
    TextEditingController controller,
    String label,
    String field,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: controller,
        keyboardType: TextInputType.number,
        decoration: InputDecoration(
          labelText: label,
          errorText: _fieldErrors[field],
        ),
        validator: (value) {
          final number = int.tryParse(value?.trim() ?? '');
          if (number == null || number < 0) {
            return 'Enter a valid number';
          }
          return null;
        },
      ),
    );
  }
}

class CustomerShell extends StatefulWidget {
  const CustomerShell({
    required this.client,
    required this.tenantProfile,
    required this.onSignedOut,
    super.key,
  });

  final MotornautsGateway client;
  final Map<String, dynamic> tenantProfile;
  final VoidCallback onSignedOut;

  @override
  State<CustomerShell> createState() => _CustomerShellState();
}

class _CustomerShellState extends State<CustomerShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final screens = [
      HomeScreen(client: widget.client),
      GarageScreen(client: widget.client),
      BookingScreen(client: widget.client),
      ServiceScreen(client: widget.client),
      MoreScreen(client: widget.client, onSignedOut: widget.onSignedOut),
    ];

    return Scaffold(
      body: SafeArea(child: screens[_index]),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (value) => setState(() => _index = value),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.directions_car_outlined),
            label: 'Garage',
          ),
          NavigationDestination(
            icon: Icon(Icons.event_available_outlined),
            label: 'Book',
          ),
          NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            label: 'Service',
          ),
          NavigationDestination(icon: Icon(Icons.more_horiz), label: 'More'),
        ],
      ),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({required this.client, super.key});

  final MotornautsGateway client;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Object? _summary;
  Map<String, dynamic>? _profile;
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final profile = await widget.client.getMyCustomerProfile();
      Object? summary;
      try {
        summary = await widget.client.getCustomerDashboardSummary();
      } catch (error) {
        summary = {'stale': true, 'message': _messageFor(error)};
      }
      if (!mounted) {
        return;
      }
      setState(() {
        _profile = profile;
        _summary = summary;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = _messageFor(error);
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          HeaderRow(title: 'Home', onRefresh: _load),
          if (_loading) const LinearProgressIndicator(),
          if (_error != null)
            ErrorPanel(message: _error!, onRetry: _load)
          else ...[
            InfoCard(
              title: 'Customer profile',
              child: KeyValueList(
                object: _profile ?? const {},
                keys: const [
                  'tenantCustomerId',
                  'firstName',
                  'lastName',
                  'email',
                  'phone',
                ],
              ),
            ),
            InfoCard(
              title: 'Dashboard summary',
              child: JsonPreview(data: _summary),
            ),
          ],
        ],
      ),
    );
  }
}

class GarageScreen extends StatefulWidget {
  const GarageScreen({required this.client, super.key});

  final MotornautsGateway client;

  @override
  State<GarageScreen> createState() => _GarageScreenState();
}

class _GarageScreenState extends State<GarageScreen> {
  Map<String, dynamic>? _profile;
  List<Map<String, dynamic>> _vehicles = const [];
  Object? _summary;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final profile = await widget.client.getMyCustomerProfile();
      final vehicles = await widget.client.listCustomerVehicles();
      Object? summary;
      try {
        summary = await widget.client.getVehicleSummary();
      } catch (error) {
        summary = {'unavailable': true, 'message': _messageFor(error)};
      }
      if (!mounted) {
        return;
      }
      setState(() {
        _profile = profile;
        _vehicles = objectList(
          vehicles,
          keys: const ['vehicles', 'items', 'results'],
        );
        _summary = summary;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = _messageFor(error);
        _loading = false;
      });
    }
  }

  Future<void> _openVehicleEditor([Map<String, dynamic>? vehicle]) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder:
            (_) => VehicleEditorScreen(
              client: widget.client,
              tenantCustomerId: _tenantCustomerId,
              vehicle: vehicle,
            ),
      ),
    );
    if (!mounted) {
      return;
    }
    if (changed == true) {
      await _load();
    }
  }

  Future<void> _openVehicle(Map<String, dynamic> vehicle) async {
    final vehicleId = objectId(vehicle, const ['vehicleId', 'id']);
    if (vehicleId == null) {
      _showSnack(context, 'Vehicle ID is missing.');
      return;
    }
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder:
            (_) => VehicleDetailScreen(
              client: widget.client,
              vehicleId: vehicleId,
              summary: vehicle,
            ),
      ),
    );
    if (!mounted) {
      return;
    }
    if (changed == true) {
      await _load();
    }
  }

  String? get _tenantCustomerId {
    final profile = _profile;
    if (profile == null) {
      return null;
    }
    return objectId(profile, const ['tenantCustomerId', 'id', 'customerId']);
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          HeaderRow(
            title: 'Garage',
            onRefresh: _load,
            action: IconButton(
              tooltip: 'Add vehicle',
              onPressed:
                  _tenantCustomerId == null ? null : () => _openVehicleEditor(),
              icon: const Icon(Icons.add_circle_outline),
            ),
          ),
          if (_loading) const LinearProgressIndicator(),
          if (_error != null)
            ErrorPanel(message: _error!, onRetry: _load)
          else ...[
            InfoCard(
              title: 'Vehicle summary',
              child: JsonPreview(data: _summary),
            ),
            if (_vehicles.isEmpty)
              const EmptyState(
                icon: Icons.directions_car_outlined,
                title: 'No vehicles',
                message:
                    'Add a vehicle after your customer profile is available.',
              )
            else
              for (final vehicle in _vehicles)
                DataListTile(
                  title: valueText(vehicle, const [
                    'registrationNumber',
                    'plateNumber',
                    'vehicleNumber',
                    'nickname',
                  ]),
                  subtitle:
                      '${valueText(vehicle, const ['make'])} ${valueText(vehicle, const ['model'])}',
                  status: valueText(vehicle, const [
                    'verificationStatus',
                    'status',
                  ], fallback: ''),
                  icon: Icons.directions_car_outlined,
                  onTap: () => _openVehicle(vehicle),
                  trailing: IconButton(
                    tooltip: 'Edit',
                    onPressed: () => _openVehicleEditor(vehicle),
                    icon: const Icon(Icons.edit_outlined),
                  ),
                ),
          ],
        ],
      ),
    );
  }
}

class VehicleEditorScreen extends StatefulWidget {
  const VehicleEditorScreen({
    required this.client,
    required this.tenantCustomerId,
    this.vehicle,
    super.key,
  });

  final MotornautsGateway client;
  final String? tenantCustomerId;
  final Map<String, dynamic>? vehicle;

  @override
  State<VehicleEditorScreen> createState() => _VehicleEditorScreenState();
}

class _VehicleEditorScreenState extends State<VehicleEditorScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _registrationController;
  late final TextEditingController _makeController;
  late final TextEditingController _modelController;
  late final TextEditingController _yearController;
  late final TextEditingController _mileageController;
  late final TextEditingController _chassisController;
  late final TextEditingController _engineController;
  late final TextEditingController _nicknameController;
  late String _vehicleType;
  late String _fuelType;
  late String _transmission;
  late String _ownershipStatus;
  bool _saving = false;
  Map<String, String> _fieldErrors = const {};

  @override
  void initState() {
    super.initState();
    final vehicle = widget.vehicle ?? const <String, dynamic>{};
    _registrationController = TextEditingController(
      text: valueText(vehicle, const ['registrationNumber'], fallback: ''),
    );
    _makeController = TextEditingController(
      text: valueText(vehicle, const [
        'make',
        'selectedBrand',
        'brand',
      ], fallback: ''),
    );
    _modelController = TextEditingController(
      text: valueText(vehicle, const ['model', 'selectedModel'], fallback: ''),
    );
    _yearController = TextEditingController(
      text: valueText(vehicle, const ['year'], fallback: ''),
    );
    _mileageController = TextEditingController(
      text: valueText(vehicle, const [
        'currentMileage',
        'mileage',
      ], fallback: ''),
    );
    _chassisController = TextEditingController(
      text: valueText(vehicle, const ['chassisNumber'], fallback: ''),
    );
    _engineController = TextEditingController(
      text: valueText(vehicle, const ['engineNumber'], fallback: ''),
    );
    _nicknameController = TextEditingController(
      text: valueText(vehicle, const ['nickname'], fallback: ''),
    );
    _vehicleType = _enumValue(vehicle['vehicleType'], _vehicleTypes, 'CAR');
    _fuelType = _enumValue(vehicle['fuelType'], _fuelTypes, 'PETROL');
    _transmission = _enumValue(
      vehicle['transmission'],
      _transmissions,
      'AUTOMATIC',
    );
    _ownershipStatus = _enumValue(
      vehicle['ownershipStatus'],
      _ownershipStatuses,
      'OWNED',
    );
  }

  @override
  void dispose() {
    _registrationController.dispose();
    _makeController.dispose();
    _modelController.dispose();
    _yearController.dispose();
    _mileageController.dispose();
    _chassisController.dispose();
    _engineController.dispose();
    _nicknameController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _fieldErrors = const {});
    if (!_formKey.currentState!.validate()) {
      return;
    }
    final vehicleId = objectId(widget.vehicle ?? const {}, const [
      'vehicleId',
      'id',
    ]);
    if (vehicleId == null && widget.tenantCustomerId == null) {
      _showSnack(
        context,
        'Customer profile is required before creating vehicles.',
      );
      return;
    }

    final body = MotornautsPayloads.vehicle(
      tenantCustomerId: vehicleId == null ? widget.tenantCustomerId : null,
      registrationNumber: _registrationController.text.trim(),
      vehicleType: _vehicleType,
      make: _makeController.text.trim(),
      model: _modelController.text.trim(),
      year: int.parse(_yearController.text.trim()),
      fuelType: _fuelType,
      transmission: _transmission,
      currentMileage: int.parse(_mileageController.text.trim()),
      chassisNumber: _chassisController.text.trim(),
      engineNumber: _engineController.text.trim(),
      nickname: _nicknameController.text.trim(),
      ownershipStatus: _ownershipStatus,
    );

    setState(() => _saving = true);
    try {
      if (vehicleId == null) {
        await widget.client.createCustomerVehicle(body);
      } else {
        await widget.client.updateCustomerVehicle(vehicleId, body);
      }
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop(true);
    } on MotornautsApiException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _fieldErrors = error.fieldMessages);
      _showSnack(context, error.message);
    } catch (error) {
      if (!mounted) {
        return;
      }
      _showSnack(context, _messageFor(error));
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.vehicle != null;
    return Scaffold(
      appBar: AppBar(title: Text(editing ? 'Edit vehicle' : 'Add vehicle')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _formText(
              _registrationController,
              'Registration number',
              'registrationNumber',
            ),
            DropdownButtonFormField<String>(
              initialValue: _vehicleType,
              decoration: const InputDecoration(labelText: 'Vehicle type'),
              items: _vehicleTypes.map(_dropdownItem).toList(),
              onChanged:
                  (value) =>
                      setState(() => _vehicleType = value ?? _vehicleType),
            ),
            const SizedBox(height: 12),
            _formText(_makeController, 'Make', 'make'),
            _formText(_modelController, 'Model', 'model'),
            _formNumber(_yearController, 'Year', 'year'),
            DropdownButtonFormField<String>(
              initialValue: _fuelType,
              decoration: const InputDecoration(labelText: 'Fuel type'),
              items: _fuelTypes.map(_dropdownItem).toList(),
              onChanged:
                  (value) => setState(() => _fuelType = value ?? _fuelType),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _transmission,
              decoration: const InputDecoration(labelText: 'Transmission'),
              items: _transmissions.map(_dropdownItem).toList(),
              onChanged:
                  (value) =>
                      setState(() => _transmission = value ?? _transmission),
            ),
            const SizedBox(height: 12),
            _formNumber(
              _mileageController,
              'Current mileage',
              'currentMileage',
            ),
            _formText(
              _chassisController,
              'Chassis number',
              'chassisNumber',
              required: false,
            ),
            _formText(
              _engineController,
              'Engine number',
              'engineNumber',
              required: false,
            ),
            _formText(
              _nicknameController,
              'Nickname',
              'nickname',
              required: false,
            ),
            DropdownButtonFormField<String>(
              initialValue: _ownershipStatus,
              decoration: const InputDecoration(labelText: 'Ownership status'),
              items: _ownershipStatuses.map(_dropdownItem).toList(),
              onChanged: (value) {
                setState(() => _ownershipStatus = value ?? _ownershipStatus);
              },
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon:
                  _saving
                      ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                      : const Icon(Icons.save_outlined),
              label: Text(editing ? 'Save changes' : 'Create vehicle'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _formText(
    TextEditingController controller,
    String label,
    String field, {
    bool required = true,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          errorText: _fieldErrors[field],
        ),
        validator: (value) {
          if (required && (value?.trim().isEmpty ?? true)) {
            return 'Required';
          }
          return null;
        },
      ),
    );
  }

  Widget _formNumber(
    TextEditingController controller,
    String label,
    String field,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: controller,
        keyboardType: TextInputType.number,
        decoration: InputDecoration(
          labelText: label,
          errorText: _fieldErrors[field],
        ),
        validator: (value) {
          final number = int.tryParse(value?.trim() ?? '');
          if (number == null || number < 0) {
            return 'Enter a valid number';
          }
          return null;
        },
      ),
    );
  }
}

class VehicleDetailScreen extends StatefulWidget {
  const VehicleDetailScreen({
    required this.client,
    required this.vehicleId,
    required this.summary,
    super.key,
  });

  final MotornautsGateway client;
  final String vehicleId;
  final Map<String, dynamic> summary;

  @override
  State<VehicleDetailScreen> createState() => _VehicleDetailScreenState();
}

class _VehicleDetailScreenState extends State<VehicleDetailScreen> {
  Map<String, dynamic>? _vehicle;
  List<Map<String, dynamic>> _documents = const [];
  String _documentType = 'REGISTRATION_CERTIFICATE';
  bool _loading = true;
  bool _uploading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final vehicle = await widget.client.getCustomerVehicle(widget.vehicleId);
      final documents = await widget.client.listVehicleDocuments(
        widget.vehicleId,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _vehicle = vehicle;
        _documents = objectList(documents, keys: const ['documents', 'items']);
        _loading = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = _messageFor(error);
        _loading = false;
      });
    }
  }

  Future<void> _uploadDocument() async {
    final picked = await FilePicker.platform.pickFiles(
      withData: true,
      type: FileType.custom,
      allowedExtensions: const ['pdf', 'jpg', 'jpeg', 'png', 'webp'],
    );
    if (!mounted || picked == null || picked.files.isEmpty) {
      return;
    }
    final file = picked.files.single;
    final bytes = file.bytes;
    if (bytes == null || bytes.isEmpty) {
      _showSnack(context, 'Could not read selected file.');
      return;
    }

    setState(() => _uploading = true);
    try {
      final intent = await widget.client.createVehicleDocumentUploadIntent(
        widget.vehicleId,
        MotornautsPayloads.documentUploadIntent(
          documentType: _documentType,
          fileName: file.name,
          mimeType: _mimeTypeFor(file.name),
          fileSizeBytes: bytes.length,
        ),
      );
      final upload = objectMap(intent['upload']);
      final document = objectMap(intent['document']);
      final documentId = objectId(document, const ['documentId', 'id']);
      final url = upload['url']?.toString();
      if (documentId == null || url == null || url.isEmpty) {
        throw const MotornautsNetworkException('Upload intent was incomplete.');
      }
      final headers =
          upload['headers'] is Map
              ? Map<String, String>.from(
                (upload['headers'] as Map).map(
                  (key, dynamic value) =>
                      MapEntry(key.toString(), value.toString()),
                ),
              )
              : const <String, String>{};
      await widget.client.uploadSignedObject(
        url: url,
        bytes: bytes,
        headers: headers,
      );
      await widget.client.completeVehicleDocumentUpload(
        vehicleId: widget.vehicleId,
        documentId: documentId,
      );
      if (!mounted) {
        return;
      }
      _showSnack(context, 'Document uploaded.');
      await _load();
    } catch (error) {
      if (!mounted) {
        return;
      }
      _showSnack(context, _messageFor(error));
    } finally {
      if (mounted) {
        setState(() => _uploading = false);
      }
    }
  }

  Future<void> _openSignedUrl(
    Map<String, dynamic> document,
    bool download,
  ) async {
    final documentId = objectId(document, const ['documentId', 'id']);
    if (documentId == null) {
      _showSnack(context, 'Document ID is missing.');
      return;
    }
    try {
      final access =
          download
              ? await widget.client.createVehicleDocumentDownloadUrl(
                vehicleId: widget.vehicleId,
                documentId: documentId,
              )
              : await widget.client.createVehicleDocumentViewUrl(
                vehicleId: widget.vehicleId,
                documentId: documentId,
              );
      final url = access['url']?.toString();
      if (url == null || url.isEmpty) {
        throw const MotornautsNetworkException('Signed URL unavailable.');
      }
      final launched = await launchUrl(
        Uri.parse(url),
        mode: LaunchMode.externalApplication,
      );
      if (!mounted) {
        return;
      }
      if (!launched) {
        _showSnack(context, 'Could not open document.');
      }
    } catch (error) {
      if (!mounted) {
        return;
      }
      _showSnack(context, _messageFor(error));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Vehicle detail')),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (_loading) const LinearProgressIndicator(),
            if (_error != null)
              ErrorPanel(message: _error!, onRetry: _load)
            else ...[
              InfoCard(
                title: valueText(_vehicle ?? widget.summary, const [
                  'registrationNumber',
                  'nickname',
                ], fallback: 'Vehicle'),
                child: KeyValueList(
                  object: _vehicle ?? widget.summary,
                  keys: const [
                    'vehicleId',
                    'make',
                    'model',
                    'year',
                    'fuelType',
                    'transmission',
                    'currentMileage',
                    'verificationStatus',
                  ],
                ),
              ),
              InfoCard(
                title: 'Upload document',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    DropdownButtonFormField<String>(
                      initialValue: _documentType,
                      decoration: const InputDecoration(
                        labelText: 'Document type',
                      ),
                      items: _documentTypes.map(_dropdownItem).toList(),
                      onChanged: (value) {
                        setState(() => _documentType = value ?? _documentType);
                      },
                    ),
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      onPressed: _uploading ? null : _uploadDocument,
                      icon:
                          _uploading
                              ? const SizedBox.square(
                                dimension: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                              : const Icon(Icons.upload_file_outlined),
                      label: const Text('Choose and upload'),
                    ),
                  ],
                ),
              ),
              Text('Documents', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              if (_documents.isEmpty)
                const EmptyState(
                  icon: Icons.description_outlined,
                  title: 'No documents',
                  message:
                      'Documents will appear after upload and verification.',
                )
              else
                for (final document in _documents)
                  DataListTile(
                    title: valueText(document, const [
                      'documentType',
                      'fileName',
                    ]),
                    subtitle: valueText(document, const [
                      'status',
                      'verificationStatus',
                      'mimeType',
                    ]),
                    icon: Icons.description_outlined,
                    trailing: Wrap(
                      children: [
                        IconButton(
                          tooltip: 'View',
                          onPressed: () => _openSignedUrl(document, false),
                          icon: const Icon(Icons.visibility_outlined),
                        ),
                        IconButton(
                          tooltip: 'Download',
                          onPressed: () => _openSignedUrl(document, true),
                          icon: const Icon(Icons.download_outlined),
                        ),
                      ],
                    ),
                  ),
            ],
          ],
        ),
      ),
    );
  }
}

class BookingScreen extends StatefulWidget {
  const BookingScreen({required this.client, super.key});

  final MotornautsGateway client;

  @override
  State<BookingScreen> createState() => _BookingScreenState();
}

class _BookingScreenState extends State<BookingScreen> {
  List<Map<String, dynamic>> _vehicles = const [];
  List<Map<String, dynamic>> _branches = const [];
  List<Map<String, dynamic>> _packages = const [];
  List<Map<String, dynamic>> _slots = const [];
  List<Map<String, dynamic>> _appointments = const [];
  String? _vehicleId;
  String? _branchId;
  String? _servicePackageId;
  Map<String, dynamic>? _selectedSlot;
  DateTime _requestedAt = DateTime.now().add(const Duration(days: 1));
  final TextEditingController _notesController = TextEditingController();
  final TextEditingController _complaintsController = TextEditingController();
  final TextEditingController _mileageController = TextEditingController();
  String? _submitKey;
  bool _loading = true;
  bool _checkingAvailability = false;
  bool _submitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _notesController.dispose();
    _complaintsController.dispose();
    _mileageController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final vehicles = await widget.client.listCustomerVehicles();
      final options = await widget.client.getCustomerBookingOptions();
      final appointments = await widget.client.listCustomerAppointments();
      if (!mounted) {
        return;
      }
      final optionMap = objectMap(options);
      setState(() {
        _vehicles = objectList(vehicles, keys: const ['vehicles', 'items']);
        _branches = objectList(
          optionMap['branches'],
          keys: const ['branches', 'items'],
        );
        _packages = objectList(
          optionMap['servicePackages'] ?? optionMap['packages'],
          keys: const ['servicePackages', 'packages', 'items'],
        );
        _appointments = objectList(
          appointments,
          keys: const ['appointments', 'items'],
        );
        _vehicleId ??=
            _vehicles.isEmpty
                ? null
                : objectId(_vehicles.first, const ['vehicleId', 'id']);
        _branchId ??=
            _branches.isEmpty
                ? null
                : objectId(_branches.first, const ['branchId', 'id']);
        _servicePackageId ??=
            _packages.isEmpty
                ? null
                : objectId(_packages.first, const ['servicePackageId', 'id']);
        _loading = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = _messageFor(error);
        _loading = false;
      });
    }
  }

  Future<void> _pickRequestedAt() async {
    final date = await showDatePicker(
      context: context,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 30)),
      initialDate: _requestedAt,
    );
    if (!mounted || date == null) {
      return;
    }
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_requestedAt),
    );
    if (!mounted || time == null) {
      return;
    }
    setState(() {
      _requestedAt = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
      _selectedSlot = null;
      _submitKey = null;
    });
  }

  Future<void> _checkAvailability() async {
    final branchId = _branchId;
    final packageId = _servicePackageId;
    if (branchId == null || packageId == null) {
      _showSnack(context, 'Select a branch and service package.');
      return;
    }
    setState(() => _checkingAvailability = true);
    try {
      final from = DateTime(
        _requestedAt.year,
        _requestedAt.month,
        _requestedAt.day,
      );
      final to = from.add(const Duration(days: 1));
      final availability = await widget.client.getAppointmentAvailability(
        branchId: branchId,
        servicePackageId: packageId,
        from: from,
        to: to,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _slots = objectList(
          availability,
          keys: const ['slots', 'items', 'availability'],
        );
        _selectedSlot = _slots.isEmpty ? null : _slots.first;
        _submitKey = null;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      _showSnack(context, _messageFor(error));
    } finally {
      if (mounted) {
        setState(() => _checkingAvailability = false);
      }
    }
  }

  Future<void> _submitBooking() async {
    final vehicleId = _vehicleId;
    final branchId = _branchId;
    final packageId = _servicePackageId;
    if (vehicleId == null || branchId == null || packageId == null) {
      _showSnack(context, 'Select a vehicle, branch, and service package.');
      return;
    }
    final startText =
        _selectedSlot == null
            ? null
            : valueText(_selectedSlot!, const [
              'startAt',
              'requestedStartAt',
              'from',
            ], fallback: '');
    final endText =
        _selectedSlot == null
            ? null
            : valueText(_selectedSlot!, const [
              'endAt',
              'requestedEndAt',
              'to',
            ], fallback: '');
    final start =
        startText == null || startText.isEmpty
            ? _requestedAt
            : DateTime.tryParse(startText) ?? _requestedAt;
    final end =
        endText == null || endText.isEmpty ? null : DateTime.tryParse(endText);
    _submitKey ??= newIdempotencyKey();

    setState(() => _submitting = true);
    try {
      await widget.client.createCustomerBooking(
        MotornautsPayloads.booking(
          vehicleId: vehicleId,
          branchId: branchId,
          servicePackageId: packageId,
          requestedStartAt: start,
          requestedEndAt: end,
          mileageAtBooking: int.tryParse(_mileageController.text.trim()),
          customerNotes: _notesController.text.trim(),
          complaints: _complaintsController.text.trim(),
          idempotencyKey: _submitKey!,
        ),
      );
      if (!mounted) {
        return;
      }
      _showSnack(context, 'Appointment requested.');
      setState(() {
        _submitKey = null;
        _selectedSlot = null;
      });
      await _load();
    } catch (error) {
      if (!mounted) {
        return;
      }
      _showSnack(context, _messageFor(error));
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          HeaderRow(title: 'Booking', onRefresh: _load),
          if (_loading) const LinearProgressIndicator(),
          if (_error != null)
            ErrorPanel(message: _error!, onRetry: _load)
          else ...[
            InfoCard(
              title: 'New appointment',
              child: Column(
                children: [
                  _idDropdown(
                    label: 'Vehicle',
                    value: _vehicleId,
                    items: _vehicles,
                    idKeys: const ['vehicleId', 'id'],
                    labelKeys: const ['registrationNumber', 'nickname'],
                    onChanged: (value) => setState(() => _vehicleId = value),
                  ),
                  const SizedBox(height: 12),
                  _idDropdown(
                    label: 'Branch',
                    value: _branchId,
                    items: _branches,
                    idKeys: const ['branchId', 'id'],
                    labelKeys: const ['name', 'displayName', 'branchName'],
                    onChanged: (value) {
                      setState(() {
                        _branchId = value;
                        _slots = const [];
                        _selectedSlot = null;
                      });
                    },
                  ),
                  const SizedBox(height: 12),
                  _idDropdown(
                    label: 'Service package',
                    value: _servicePackageId,
                    items: _packages,
                    idKeys: const ['servicePackageId', 'id'],
                    labelKeys: const ['name', 'displayName', 'serviceName'],
                    onChanged: (value) {
                      setState(() {
                        _servicePackageId = value;
                        _slots = const [];
                        _selectedSlot = null;
                      });
                    },
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: _pickRequestedAt,
                    icon: const Icon(Icons.schedule_outlined),
                    label: Text(
                      DateFormat('yyyy-MM-dd HH:mm').format(_requestedAt),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _mileageController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Mileage at booking',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _complaintsController,
                    maxLines: 2,
                    decoration: const InputDecoration(labelText: 'Complaints'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _notesController,
                    maxLines: 2,
                    decoration: const InputDecoration(labelText: 'Notes'),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed:
                        _checkingAvailability ? null : _checkAvailability,
                    icon:
                        _checkingAvailability
                            ? const SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                            : const Icon(Icons.event_available_outlined),
                    label: const Text('Check availability'),
                  ),
                  if (_slots.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    DropdownButtonFormField<Map<String, dynamic>>(
                      initialValue: _selectedSlot,
                      decoration: const InputDecoration(
                        labelText: 'Available slot',
                      ),
                      items:
                          _slots
                              .map(
                                (slot) => DropdownMenuItem(
                                  value: slot,
                                  child: Text(
                                    valueText(slot, const [
                                      'label',
                                      'startAt',
                                      'requestedStartAt',
                                      'from',
                                    ]),
                                  ),
                                ),
                              )
                              .toList(),
                      onChanged: (slot) => setState(() => _selectedSlot = slot),
                    ),
                  ],
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: _submitting ? null : _submitBooking,
                    icon:
                        _submitting
                            ? const SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                            : const Icon(Icons.send_outlined),
                    label: const Text('Request appointment'),
                  ),
                ],
              ),
            ),
            Text(
              'Appointments',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            if (_appointments.isEmpty)
              const EmptyState(
                icon: Icons.event_busy_outlined,
                title: 'No appointments',
                message: 'Your tenant appointments will appear here.',
              )
            else
              for (final appointment in _appointments)
                DataListTile(
                  title: valueText(appointment, const [
                    'requestedStartAt',
                    'confirmedStartAt',
                    'startAt',
                  ]),
                  subtitle: valueText(appointment, const [
                    'servicePackageName',
                    'branchName',
                    'vehicleRegistrationNumber',
                  ]),
                  status: valueText(appointment, const [
                    'status',
                  ], fallback: ''),
                  icon: Icons.event_note_outlined,
                  onTap: () => _openAppointment(appointment),
                ),
          ],
        ],
      ),
    );
  }

  Future<void> _openAppointment(Map<String, dynamic> appointment) async {
    final id = objectId(appointment, const ['appointmentId', 'id']);
    if (id == null) {
      _showSnack(context, 'Appointment ID is missing.');
      return;
    }
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder:
            (_) => AppointmentDetailScreen(
              client: widget.client,
              appointmentId: id,
            ),
      ),
    );
    if (!mounted) {
      return;
    }
    await _load();
  }
}

class AppointmentDetailScreen extends StatefulWidget {
  const AppointmentDetailScreen({
    required this.client,
    required this.appointmentId,
    super.key,
  });

  final MotornautsGateway client;
  final String appointmentId;

  @override
  State<AppointmentDetailScreen> createState() =>
      _AppointmentDetailScreenState();
}

class _AppointmentDetailScreenState extends State<AppointmentDetailScreen> {
  Map<String, dynamic>? _appointment;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final appointment = await widget.client.getCustomerAppointment(
        widget.appointmentId,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _appointment = appointment;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = _messageFor(error);
        _loading = false;
      });
    }
  }

  Future<void> _transition(String status) async {
    try {
      await widget.client.transitionCustomerAppointmentStatus(
        appointmentId: widget.appointmentId,
        body: {'status': status},
      );
      if (!mounted) {
        return;
      }
      _showSnack(context, 'Appointment updated.');
      await _load();
    } catch (error) {
      if (!mounted) {
        return;
      }
      _showSnack(context, _messageFor(error));
      await _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final appointment = _appointment;
    final actions = objectList(
      appointment?['allowedTransitions'],
      keys: const ['items'],
    );
    return Scaffold(
      appBar: AppBar(title: const Text('Appointment')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (_loading) const LinearProgressIndicator(),
          if (_error != null)
            ErrorPanel(message: _error!, onRetry: _load)
          else if (appointment != null) ...[
            InfoCard(
              title: valueText(appointment, const [
                'status',
              ], fallback: 'Appointment'),
              child: JsonPreview(data: appointment),
            ),
            if (actions.isNotEmpty)
              for (final action in actions)
                OutlinedButton.icon(
                  onPressed:
                      () => _transition(
                        valueText(action, const ['status', 'to']),
                      ),
                  icon: const Icon(Icons.swap_horiz_outlined),
                  label: Text(
                    valueText(action, const ['label', 'status', 'to']),
                  ),
                ),
          ],
        ],
      ),
    );
  }
}

class ServiceScreen extends StatefulWidget {
  const ServiceScreen({required this.client, super.key});

  final MotornautsGateway client;

  @override
  State<ServiceScreen> createState() => _ServiceScreenState();
}

class _ServiceScreenState extends State<ServiceScreen> {
  List<Map<String, dynamic>> _repairOrders = const [];
  List<Map<String, dynamic>> _invoices = const [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final repairOrders = await widget.client.listCustomerRepairOrders();
      final invoices = await widget.client.listCustomerInvoices();
      if (!mounted) {
        return;
      }
      setState(() {
        _repairOrders = objectList(
          repairOrders,
          keys: const ['repairOrders', 'items'],
        );
        _invoices = objectList(invoices, keys: const ['invoices', 'items']);
        _loading = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = _messageFor(error);
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          HeaderRow(title: 'Service', onRefresh: _load),
          if (_loading) const LinearProgressIndicator(),
          if (_error != null)
            ErrorPanel(message: _error!, onRetry: _load)
          else ...[
            Text(
              'Repair orders',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            if (_repairOrders.isEmpty)
              const EmptyState(
                icon: Icons.build_circle_outlined,
                title: 'No repair orders',
                message: 'Customer-visible repair orders will appear here.',
              )
            else
              for (final order in _repairOrders)
                DataListTile(
                  title: valueText(order, const [
                    'repairOrderNumber',
                    'number',
                    'id',
                  ]),
                  subtitle: valueText(order, const [
                    'vehicleRegistrationNumber',
                    'registrationNumber',
                    'vehicleId',
                  ]),
                  status: valueText(order, const [
                    'status',
                    'workflowStatus',
                  ], fallback: ''),
                  icon: Icons.build_circle_outlined,
                  onTap: () => _openRepairOrder(order),
                ),
            const SizedBox(height: 16),
            Text('Invoices', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            if (_invoices.isEmpty)
              const EmptyState(
                icon: Icons.receipt_long_outlined,
                title: 'No invoices',
                message: 'Customer-visible invoices will appear here.',
              )
            else
              for (final invoice in _invoices)
                DataListTile(
                  title: valueText(invoice, const [
                    'invoiceNumber',
                    'number',
                    'invoiceId',
                    'id',
                  ]),
                  subtitle: _moneyText(invoice),
                  status: valueText(invoice, const [
                    'status',
                    'paymentStatus',
                  ], fallback: ''),
                  icon: Icons.receipt_long_outlined,
                  onTap: () => _openInvoice(invoice),
                ),
          ],
        ],
      ),
    );
  }

  Future<void> _openRepairOrder(Map<String, dynamic> order) async {
    final id = objectId(order, const ['repairOrderId', 'id']);
    if (id == null) {
      _showSnack(context, 'Repair order ID is missing.');
      return;
    }
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder:
            (_) => RepairOrderDetailScreen(
              client: widget.client,
              repairOrderId: id,
            ),
      ),
    );
    if (!mounted) {
      return;
    }
    await _load();
  }

  Future<void> _openInvoice(Map<String, dynamic> invoice) async {
    final id = objectId(invoice, const ['invoiceId', 'id']);
    if (id == null) {
      _showSnack(context, 'Invoice ID is missing.');
      return;
    }
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder:
            (_) => InvoiceDetailScreen(client: widget.client, invoiceId: id),
      ),
    );
    if (!mounted) {
      return;
    }
    await _load();
  }
}

class RepairOrderDetailScreen extends StatefulWidget {
  const RepairOrderDetailScreen({
    required this.client,
    required this.repairOrderId,
    super.key,
  });

  final MotornautsGateway client;
  final String repairOrderId;

  @override
  State<RepairOrderDetailScreen> createState() =>
      _RepairOrderDetailScreenState();
}

class _RepairOrderDetailScreenState extends State<RepairOrderDetailScreen> {
  Map<String, dynamic>? _repairOrder;
  List<Map<String, dynamic>> _timeline = const [];
  Timer? _pollTimer;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
    _pollTimer = Timer.periodic(
      const Duration(seconds: 45),
      (_) => _load(silent: true),
    );
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _load({bool silent = false}) async {
    if (!silent) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final order = await widget.client.getCustomerRepairOrder(
        widget.repairOrderId,
      );
      Object? timeline;
      try {
        timeline = await widget.client.listCustomerRepairOrderTimeline(
          widget.repairOrderId,
        );
      } catch (_) {
        timeline = const [];
      }
      if (!mounted) {
        return;
      }
      setState(() {
        _repairOrder = order;
        _timeline = objectList(
          timeline,
          keys: const ['events', 'timeline', 'items'],
        );
        _loading = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = _messageFor(error);
        _loading = false;
      });
    }
  }

  List<Map<String, String>> _estimateRefs() {
    final order = _repairOrder;
    if (order == null) {
      return const [];
    }
    final refs = <Map<String, String>>[];
    final single = objectId(order, const [
      'estimateId',
      'pendingEstimateId',
      'activeEstimateId',
    ]);
    if (single != null) {
      refs.add({'estimateId': single, 'label': single});
    }
    for (final estimate in objectList(
      order['estimates'],
      keys: const ['items'],
    )) {
      final estimateId = objectId(estimate, const ['estimateId', 'id']);
      if (estimateId != null) {
        refs.add({
          'estimateId': estimateId,
          'label': valueText(estimate, const [
            'estimateNumber',
            'number',
            'status',
          ], fallback: estimateId),
        });
      }
    }
    return refs;
  }

  Future<void> _openEstimate(String estimateId) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder:
            (_) => EstimateDetailScreen(
              client: widget.client,
              repairOrderId: widget.repairOrderId,
              estimateId: estimateId,
            ),
      ),
    );
    if (!mounted) {
      return;
    }
    await _load();
  }

  Future<void> _downloadServiceHistory() async {
    try {
      final state = await widget.client.getCustomerServiceHistoryPdfState(
        widget.repairOrderId,
      );
      final available =
          state['available'] == true ||
          valueText(state, const ['status'], fallback: '').toLowerCase() ==
              'available';
      if (!available && mounted) {
        _showSnack(context, 'Service history PDF is not available yet.');
      }
      final access = await widget.client
          .createCustomerServiceHistoryPdfDownloadUrl(widget.repairOrderId);
      final url = access['url']?.toString();
      if (url == null || url.isEmpty) {
        throw const MotornautsNetworkException('Download URL unavailable.');
      }
      final launched = await launchUrl(
        Uri.parse(url),
        mode: LaunchMode.externalApplication,
      );
      if (!mounted) {
        return;
      }
      if (!launched) {
        _showSnack(context, 'Could not open PDF.');
      }
    } catch (error) {
      if (!mounted) {
        return;
      }
      _showSnack(context, _messageFor(error));
    }
  }

  @override
  Widget build(BuildContext context) {
    final estimateRefs = _estimateRefs();
    return Scaffold(
      appBar: AppBar(title: const Text('Repair order')),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (_loading) const LinearProgressIndicator(),
            if (_error != null)
              ErrorPanel(message: _error!, onRetry: _load)
            else if (_repairOrder != null) ...[
              InfoCard(
                title: valueText(_repairOrder!, const [
                  'repairOrderNumber',
                  'number',
                  'status',
                ], fallback: 'Repair order'),
                child: JsonPreview(data: _repairOrder),
              ),
              FilledButton.icon(
                onPressed: _downloadServiceHistory,
                icon: const Icon(Icons.picture_as_pdf_outlined),
                label: const Text('Open service-history PDF'),
              ),
              const SizedBox(height: 16),
              if (estimateRefs.isNotEmpty) ...[
                Text(
                  'Estimates',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                for (final estimate in estimateRefs)
                  DataListTile(
                    title:
                        estimate['label'] ??
                        estimate['estimateId'] ??
                        'Estimate',
                    subtitle: estimate['estimateId'] ?? '',
                    icon: Icons.fact_check_outlined,
                    onTap: () => _openEstimate(estimate['estimateId']!),
                  ),
                const SizedBox(height: 16),
              ],
              Text('Timeline', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              if (_timeline.isEmpty)
                const EmptyState(
                  icon: Icons.timeline_outlined,
                  title: 'No timeline events',
                  message:
                      'Timeline events are polled while this screen is open.',
                )
              else
                for (final event in _timeline)
                  DataListTile(
                    title: valueText(event, const [
                      'title',
                      'eventType',
                      'status',
                      'createdAt',
                    ]),
                    subtitle: valueText(event, const [
                      'message',
                      'description',
                      'occurredAt',
                    ]),
                    icon: Icons.timeline_outlined,
                  ),
            ],
          ],
        ),
      ),
    );
  }
}

class EstimateDetailScreen extends StatefulWidget {
  const EstimateDetailScreen({
    required this.client,
    required this.repairOrderId,
    required this.estimateId,
    super.key,
  });

  final MotornautsGateway client;
  final String repairOrderId;
  final String estimateId;

  @override
  State<EstimateDetailScreen> createState() => _EstimateDetailScreenState();
}

class _EstimateDetailScreenState extends State<EstimateDetailScreen> {
  Map<String, dynamic>? _estimate;
  final Map<String, String> _decisions = {};
  final Map<String, TextEditingController> _notes = {};
  bool _loading = true;
  bool _submitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final controller in _notes.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final estimate = await widget.client.getCustomerEstimate(
        repairOrderId: widget.repairOrderId,
        estimateId: widget.estimateId,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _estimate = estimate;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = _messageFor(error);
        _loading = false;
      });
    }
  }

  Future<void> _submit() async {
    final estimate = _estimate;
    if (estimate == null || _decisions.isEmpty) {
      _showSnack(context, 'Choose at least one line decision.');
      return;
    }
    final estimateVersion =
        int.tryParse(
          valueText(estimate, const [
            'estimateVersion',
            'version',
          ], fallback: '1'),
        ) ??
        1;
    final decisions =
        _decisions.entries
            .map(
              (entry) => {
                'estimateLineItemId': entry.key,
                'status': entry.value,
                'note': _notes[entry.key]?.text.trim(),
              },
            )
            .toList();

    setState(() => _submitting = true);
    try {
      await widget.client.submitCustomerEstimateDecisions(
        repairOrderId: widget.repairOrderId,
        estimateId: widget.estimateId,
        body: MotornautsPayloads.estimateDecisionBatch(
          estimateVersion: estimateVersion,
          idempotencyKey: newIdempotencyKey(),
          decisions: decisions,
        ),
      );
      if (!mounted) {
        return;
      }
      _showSnack(context, 'Estimate decisions submitted.');
      _decisions.clear();
      await _load();
    } catch (error) {
      if (!mounted) {
        return;
      }
      _showSnack(context, _messageFor(error));
      await _load();
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  Future<void> _downloadPdf() async {
    try {
      final state = await widget.client.getCustomerEstimatePdfState(
        repairOrderId: widget.repairOrderId,
        estimateId: widget.estimateId,
      );
      final available =
          state['available'] == true ||
          valueText(state, const ['status'], fallback: '').toLowerCase() ==
              'available';
      if (!available && mounted) {
        _showSnack(context, 'Estimate PDF is not available yet.');
      }
      final access = await widget.client.createCustomerEstimatePdfDownloadUrl(
        repairOrderId: widget.repairOrderId,
        estimateId: widget.estimateId,
      );
      final url = access['url']?.toString();
      if (url == null || url.isEmpty) {
        throw const MotornautsNetworkException('Download URL unavailable.');
      }
      final launched = await launchUrl(
        Uri.parse(url),
        mode: LaunchMode.externalApplication,
      );
      if (!mounted) {
        return;
      }
      if (!launched) {
        _showSnack(context, 'Could not open PDF.');
      }
    } catch (error) {
      if (!mounted) {
        return;
      }
      _showSnack(context, _messageFor(error));
    }
  }

  @override
  Widget build(BuildContext context) {
    final lineItems = objectList(
      _estimate?['lineItems'] ?? _estimate?['items'],
      keys: const ['lineItems', 'items'],
    );
    return Scaffold(
      appBar: AppBar(title: const Text('Estimate')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (_loading) const LinearProgressIndicator(),
          if (_error != null)
            ErrorPanel(message: _error!, onRetry: _load)
          else if (_estimate != null) ...[
            InfoCard(
              title: valueText(_estimate!, const [
                'estimateNumber',
                'status',
              ], fallback: 'Estimate'),
              child: JsonPreview(data: _estimate),
            ),
            OutlinedButton.icon(
              onPressed: _downloadPdf,
              icon: const Icon(Icons.picture_as_pdf_outlined),
              label: const Text('Open estimate PDF'),
            ),
            const SizedBox(height: 16),
            Text(
              'Line decisions',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            if (lineItems.isEmpty)
              const EmptyState(
                icon: Icons.fact_check_outlined,
                title: 'No line items',
                message: 'No customer-decision line items were returned.',
              )
            else
              for (final item in lineItems) _buildLineDecision(item),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _submitting ? null : _submit,
              icon:
                  _submitting
                      ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                      : const Icon(Icons.send_outlined),
              label: const Text('Submit decisions'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildLineDecision(Map<String, dynamic> item) {
    final id = objectId(item, const ['estimateLineItemId', 'lineItemId', 'id']);
    if (id == null) {
      return InfoCard(title: 'Line item', child: JsonPreview(data: item));
    }
    _notes.putIfAbsent(id, TextEditingController.new);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              valueText(item, const [
                'description',
                'name',
                'title',
              ], fallback: id),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            Text(_moneyText(item)),
            const SizedBox(height: 8),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'APPROVED', label: Text('Approve')),
                ButtonSegment(value: 'REJECTED', label: Text('Reject')),
              ],
              emptySelectionAllowed: true,
              selected: _decisions[id] == null ? const {} : {_decisions[id]!},
              onSelectionChanged: (value) {
                setState(() {
                  if (value.isEmpty) {
                    _decisions.remove(id);
                  } else {
                    _decisions[id] = value.first;
                  }
                });
              },
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _notes[id],
              decoration: const InputDecoration(labelText: 'Optional note'),
            ),
          ],
        ),
      ),
    );
  }
}

class InvoiceDetailScreen extends StatefulWidget {
  const InvoiceDetailScreen({
    required this.client,
    required this.invoiceId,
    super.key,
  });

  final MotornautsGateway client;
  final String invoiceId;

  @override
  State<InvoiceDetailScreen> createState() => _InvoiceDetailScreenState();
}

class _InvoiceDetailScreenState extends State<InvoiceDetailScreen> {
  Map<String, dynamic>? _invoice;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final invoice = await widget.client.getCustomerInvoice(widget.invoiceId);
      if (!mounted) {
        return;
      }
      setState(() {
        _invoice = invoice;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = _messageFor(error);
        _loading = false;
      });
    }
  }

  Future<void> _downloadPdf() async {
    try {
      final state = await widget.client.getCustomerInvoicePdfState(
        widget.invoiceId,
      );
      final available =
          state['available'] == true ||
          valueText(state, const ['status'], fallback: '').toLowerCase() ==
              'available';
      if (!available && mounted) {
        _showSnack(context, 'Invoice PDF is not available yet.');
      }
      final access = await widget.client.createCustomerInvoicePdfDownloadUrl(
        widget.invoiceId,
      );
      final url = access['url']?.toString();
      if (url == null || url.isEmpty) {
        throw const MotornautsNetworkException('Download URL unavailable.');
      }
      final launched = await launchUrl(
        Uri.parse(url),
        mode: LaunchMode.externalApplication,
      );
      if (!mounted) {
        return;
      }
      if (!launched) {
        _showSnack(context, 'Could not open PDF.');
      }
    } catch (error) {
      if (!mounted) {
        return;
      }
      _showSnack(context, _messageFor(error));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Invoice')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (_loading) const LinearProgressIndicator(),
          if (_error != null)
            ErrorPanel(message: _error!, onRetry: _load)
          else if (_invoice != null) ...[
            InfoCard(
              title: valueText(_invoice!, const [
                'invoiceNumber',
                'number',
                'status',
              ], fallback: 'Invoice'),
              child: JsonPreview(data: _invoice),
            ),
            FilledButton.icon(
              onPressed: _downloadPdf,
              icon: const Icon(Icons.picture_as_pdf_outlined),
              label: const Text('Open invoice PDF'),
            ),
          ],
        ],
      ),
    );
  }
}

class MoreScreen extends StatelessWidget {
  const MoreScreen({
    required this.client,
    required this.onSignedOut,
    super.key,
  });

  final MotornautsGateway client;
  final VoidCallback onSignedOut;

  Future<void> _logout(BuildContext context) async {
    try {
      await client.logout();
    } finally {
      if (context.mounted) {
        onSignedOut();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        HeaderRow(title: 'More'),
        DataListTile(
          title: 'Profile',
          subtitle: 'Edit customer contact fields',
          icon: Icons.person_outline,
          onTap:
              () => Navigator.of(context).push<void>(
                MaterialPageRoute<void>(
                  builder: (_) => ProfileScreen(client: client),
                ),
              ),
        ),
        DataListTile(
          title: 'Payment or feedback link',
          subtitle: 'Open a tokenized Motornauts link',
          icon: Icons.link_outlined,
          onTap:
              () => Navigator.of(context).push<void>(
                MaterialPageRoute<void>(
                  builder: (_) => LinkInputScreen(client: client),
                ),
              ),
        ),
        DataListTile(
          title: 'Compliance request',
          subtitle: 'Submit a privacy or legal data request',
          icon: Icons.privacy_tip_outlined,
          onTap:
              () => Navigator.of(context).push<void>(
                MaterialPageRoute<void>(
                  builder: (_) => ComplianceScreen(client: client),
                ),
              ),
        ),
        DataListTile(
          title: 'Local OBD utility',
          subtitle: 'Local-only diagnostics; not synced to Motornauts',
          icon: Icons.sensors_outlined,
          onTap:
              () => Navigator.of(context).push<void>(
                MaterialPageRoute<void>(
                  builder: (_) => const LocalUtilityScreen(kind: 'OBD'),
                ),
              ),
        ),
        DataListTile(
          title: 'Local 3D viewer',
          subtitle: 'Bundled/static assets only; not served by Motornauts',
          icon: Icons.view_in_ar_outlined,
          onTap:
              () => Navigator.of(context).push<void>(
                MaterialPageRoute<void>(
                  builder: (_) => const LocalUtilityScreen(kind: '3D'),
                ),
              ),
        ),
        const SizedBox(height: 24),
        OutlinedButton.icon(
          onPressed: () => _logout(context),
          icon: const Icon(Icons.logout),
          label: const Text('Logout'),
        ),
      ],
    );
  }
}

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({required this.client, super.key});

  final MotornautsGateway client;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _address1Controller = TextEditingController();
  final TextEditingController _address2Controller = TextEditingController();
  final TextEditingController _cityController = TextEditingController();
  bool _loading = true;
  bool _saving = false;
  String? _error;
  Map<String, String> _fieldErrors = const {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _phoneController.dispose();
    _address1Controller.dispose();
    _address2Controller.dispose();
    _cityController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final profile = await widget.client.getMyCustomerProfile();
      if (!mounted) {
        return;
      }
      _firstNameController.text = valueText(profile, const [
        'firstName',
      ], fallback: '');
      _lastNameController.text = valueText(profile, const [
        'lastName',
      ], fallback: '');
      _phoneController.text = valueText(profile, const ['phone'], fallback: '');
      _address1Controller.text = valueText(profile, const [
        'addressLine1',
      ], fallback: '');
      _address2Controller.text = valueText(profile, const [
        'addressLine2',
      ], fallback: '');
      _cityController.text = valueText(profile, const ['city'], fallback: '');
      setState(() => _loading = false);
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = _messageFor(error);
        _loading = false;
      });
    }
  }

  Future<void> _save() async {
    setState(() => _fieldErrors = const {});
    if (!_formKey.currentState!.validate()) {
      return;
    }
    setState(() => _saving = true);
    try {
      await widget.client.updateMyCustomerProfile(
        MotornautsPayloads.profileUpdate(
          firstName: _firstNameController.text.trim(),
          lastName: _lastNameController.text.trim(),
          phone: _phoneController.text.trim(),
          addressLine1: _address1Controller.text.trim(),
          addressLine2: _address2Controller.text.trim(),
          city: _cityController.text.trim(),
        ),
      );
      if (!mounted) {
        return;
      }
      _showSnack(context, 'Profile updated.');
      await _load();
    } on MotornautsApiException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _fieldErrors = error.fieldMessages);
      _showSnack(context, error.message);
    } catch (error) {
      if (!mounted) {
        return;
      }
      _showSnack(context, _messageFor(error));
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (_loading) const LinearProgressIndicator(),
            if (_error != null)
              ErrorPanel(message: _error!, onRetry: _load)
            else ...[
              _field(_firstNameController, 'First name', 'firstName'),
              _field(_lastNameController, 'Last name', 'lastName'),
              _field(_phoneController, 'Phone', 'phone'),
              _field(
                _address1Controller,
                'Address line 1',
                'addressLine1',
                required: false,
              ),
              _field(
                _address2Controller,
                'Address line 2',
                'addressLine2',
                required: false,
              ),
              _field(_cityController, 'City', 'city', required: false),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: _saving ? null : _save,
                icon:
                    _saving
                        ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                        : const Icon(Icons.save_outlined),
                label: const Text('Save profile'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _field(
    TextEditingController controller,
    String label,
    String name, {
    bool required = true,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          errorText: _fieldErrors[name],
        ),
        validator: (value) {
          if (required && (value?.trim().isEmpty ?? true)) {
            return 'Required';
          }
          return null;
        },
      ),
    );
  }
}

class ComplianceScreen extends StatefulWidget {
  const ComplianceScreen({required this.client, super.key});

  final MotornautsGateway client;

  @override
  State<ComplianceScreen> createState() => _ComplianceScreenState();
}

class _ComplianceScreenState extends State<ComplianceScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _summaryController = TextEditingController();
  String _requestType = 'DATA_ACCESS';
  bool _submitting = false;
  String? _receipt;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _summaryController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    setState(() => _submitting = true);
    try {
      final response = await widget.client.submitTenantComplianceRequest(
        MotornautsPayloads.complianceRequest(
          requestType: _requestType,
          requesterName: _nameController.text.trim(),
          requesterEmail: _emailController.text.trim(),
          requesterPhone: _phoneController.text.trim(),
          summary: _summaryController.text.trim(),
          evidence: const {'source': 'mobile_app'},
          sourceEntityType: 'CUSTOMER_MOBILE_APP',
        ),
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _receipt = valueText(response, const [
          'reference',
          'requestId',
          'id',
          'status',
        ]);
      });
      _showSnack(context, 'Compliance request submitted.');
    } catch (error) {
      if (!mounted) {
        return;
      }
      _showSnack(context, _messageFor(error));
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Compliance request')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            DropdownButtonFormField<String>(
              initialValue: _requestType,
              decoration: const InputDecoration(labelText: 'Request type'),
              items: const [
                DropdownMenuItem(
                  value: 'DATA_ACCESS',
                  child: Text('Data access'),
                ),
                DropdownMenuItem(
                  value: 'DATA_CORRECTION',
                  child: Text('Data correction'),
                ),
                DropdownMenuItem(
                  value: 'DATA_DELETION',
                  child: Text('Data deletion'),
                ),
                DropdownMenuItem(value: 'OTHER', child: Text('Other')),
              ],
              onChanged:
                  (value) =>
                      setState(() => _requestType = value ?? _requestType),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Requester name'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(labelText: 'Requester email'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: 'Requester phone'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _summaryController,
              minLines: 4,
              maxLines: 6,
              decoration: const InputDecoration(labelText: 'Summary'),
              validator: (value) {
                if (value?.trim().isEmpty ?? true) {
                  return 'Required';
                }
                return null;
              },
            ),
            if (_receipt != null)
              InfoCard(title: 'Receipt', child: Text(_receipt!)),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _submitting ? null : _submit,
              icon:
                  _submitting
                      ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                      : const Icon(Icons.send_outlined),
              label: const Text('Submit request'),
            ),
          ],
        ),
      ),
    );
  }
}

class LinkInputScreen extends StatefulWidget {
  const LinkInputScreen({required this.client, super.key});

  final MotornautsGateway client;

  @override
  State<LinkInputScreen> createState() => _LinkInputScreenState();
}

class _LinkInputScreenState extends State<LinkInputScreen> {
  final TextEditingController _linkController = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _linkController.dispose();
    super.dispose();
  }

  void _open() {
    final uri = Uri.tryParse(_linkController.text.trim());
    final parsed = uri == null ? null : parseMotornautsLink(uri);
    if (parsed == null) {
      setState(
        () => _error = 'Enter a valid Motornauts payment or feedback link.',
      );
      return;
    }
    Navigator.of(context).pushReplacement<void, void>(
      MaterialPageRoute<void>(
        builder:
            (_) => LinkDestinationScreen(client: widget.client, link: parsed),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Open link')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _linkController,
            decoration: InputDecoration(
              labelText: 'Motornauts link',
              errorText: _error,
              prefixIcon: const Icon(Icons.link_outlined),
            ),
            onChanged: (_) => setState(() => _error = null),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _open,
            icon: const Icon(Icons.open_in_new),
            label: const Text('Open'),
          ),
        ],
      ),
    );
  }
}

class LinkDestinationScreen extends StatelessWidget {
  const LinkDestinationScreen({
    required this.client,
    required this.link,
    super.key,
  });

  final MotornautsGateway client;
  final ParsedMotornautsLink link;

  @override
  Widget build(BuildContext context) {
    return switch (link.type) {
      MotornautsLinkType.payment => PaymentRequestScreen(
        client: client,
        tenantSlug: link.tenantSlug,
        paymentRequestId: link.paymentRequestId!,
        token: link.token!,
      ),
      MotornautsLinkType.feedback => FeedbackScreen(
        client: client,
        tenantSlug: link.tenantSlug,
        token: link.feedbackToken!,
      ),
    };
  }
}

class PaymentRequestScreen extends StatefulWidget {
  const PaymentRequestScreen({
    required this.client,
    required this.tenantSlug,
    required this.paymentRequestId,
    required this.token,
    super.key,
  });

  final MotornautsGateway client;
  final String tenantSlug;
  final String paymentRequestId;
  final String token;

  @override
  State<PaymentRequestScreen> createState() => _PaymentRequestScreenState();
}

class _PaymentRequestScreenState extends State<PaymentRequestScreen> {
  Map<String, dynamic>? _payment;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final payment = await widget.client.getCustomerPaymentRequest(
        tenantSlug: widget.tenantSlug,
        paymentRequestId: widget.paymentRequestId,
        token: widget.token,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _payment = payment;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = _messageFor(error);
        _loading = false;
      });
    }
  }

  void _openProvider() {
    final handoff = objectMap(_payment?['providerHandoff']);
    final action = handoff['action']?.toString();
    final fields = handoff['fields'];
    if (action == null || action.isEmpty || fields is! Map) {
      _showSnack(context, 'Provider checkout is not ready.');
      return;
    }
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder:
            (_) => ProviderHandoffScreen(
              action: action,
              fields: fields.map(
                (key, dynamic value) =>
                    MapEntry(key.toString(), value.toString()),
              ),
            ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final handoff = objectMap(_payment?['providerHandoff']);
    final status = valueText(_payment ?? const {}, const [
      'status',
    ], fallback: '');
    final terminal = {
      'PAID',
      'EXPIRED',
      'CANCELLED',
      'CANCELED',
    }.contains(status.toUpperCase());
    return Scaffold(
      appBar: AppBar(title: const Text('Payment request')),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (_loading) const LinearProgressIndicator(),
            if (_error != null)
              ErrorPanel(message: _error!, onRetry: _load)
            else if (_payment != null) ...[
              InfoCard(
                title: valueText(_payment!, const [
                  'tenantName',
                  'status',
                ], fallback: 'Payment'),
                child: KeyValueList(
                  object: _payment!,
                  keys: const [
                    'id',
                    'tenantName',
                    'status',
                    'amountMinor',
                    'currency',
                    'expiresAt',
                  ],
                ),
              ),
              FilledButton.icon(
                onPressed: terminal || handoff.isEmpty ? null : _openProvider,
                icon: const Icon(Icons.payment_outlined),
                label: const Text('Open provider checkout'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class ProviderHandoffScreen extends StatefulWidget {
  const ProviderHandoffScreen({
    required this.action,
    required this.fields,
    super.key,
  });

  final String action;
  final Map<String, String> fields;

  @override
  State<ProviderHandoffScreen> createState() => _ProviderHandoffScreenState();
}

class _ProviderHandoffScreenState extends State<ProviderHandoffScreen> {
  late final WebViewController _controller;

  @override
  void initState() {
    super.initState();
    _controller =
        WebViewController()
          ..setJavaScriptMode(JavaScriptMode.unrestricted)
          ..loadHtmlString(_handoffHtml(widget.action, widget.fields));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Checkout')),
      body: WebViewWidget(controller: _controller),
    );
  }
}

class FeedbackScreen extends StatefulWidget {
  const FeedbackScreen({
    required this.client,
    required this.tenantSlug,
    required this.token,
    super.key,
  });

  final MotornautsGateway client;
  final String tenantSlug;
  final String token;

  @override
  State<FeedbackScreen> createState() => _FeedbackScreenState();
}

class _FeedbackScreenState extends State<FeedbackScreen> {
  final TextEditingController _commentController = TextEditingController();
  Map<String, dynamic>? _feedback;
  int _rating = 5;
  bool _loading = true;
  bool _submitting = false;
  bool _submitted = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final feedback = await widget.client.getCustomerFeedbackRequest(
        tenantSlug: widget.tenantSlug,
        token: widget.token,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _feedback = feedback;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = _messageFor(error);
        _loading = false;
      });
    }
  }

  Future<void> _submit() async {
    setState(() => _submitting = true);
    try {
      await widget.client.submitCustomerFeedback(
        tenantSlug: widget.tenantSlug,
        token: widget.token,
        body: MotornautsPayloads.feedback(
          rating: _rating,
          comment: _commentController.text.trim(),
        ),
      );
      if (!mounted) {
        return;
      }
      setState(() => _submitted = true);
      _showSnack(context, 'Feedback submitted.');
    } catch (error) {
      if (!mounted) {
        return;
      }
      _showSnack(context, _messageFor(error));
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Feedback')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (_loading) const LinearProgressIndicator(),
          if (_error != null)
            ErrorPanel(message: _error!, onRetry: _load)
          else if (_submitted)
            const EmptyState(
              icon: Icons.check_circle_outline,
              title: 'Feedback submitted',
              message: 'Thank you for rating your service experience.',
            )
          else ...[
            if (_feedback != null)
              InfoCard(
                title: 'Service context',
                child: JsonPreview(data: _feedback),
              ),
            const SizedBox(height: 12),
            Text('Rating', style: Theme.of(context).textTheme.titleMedium),
            Slider(
              value: _rating.toDouble(),
              min: 1,
              max: 5,
              divisions: 4,
              label: _rating.toString(),
              onChanged: (value) => setState(() => _rating = value.round()),
            ),
            TextField(
              controller: _commentController,
              maxLines: 4,
              decoration: const InputDecoration(labelText: 'Comment'),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _submitting ? null : _submit,
              icon:
                  _submitting
                      ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                      : const Icon(Icons.send_outlined),
              label: const Text('Submit feedback'),
            ),
          ],
        ],
      ),
    );
  }
}

class LocalUtilityScreen extends StatelessWidget {
  const LocalUtilityScreen({required this.kind, super.key});

  final String kind;

  @override
  Widget build(BuildContext context) {
    final isObd = kind == 'OBD';
    return Scaffold(
      appBar: AppBar(
        title: Text(isObd ? 'Local OBD utility' : 'Local 3D viewer'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          EmptyState(
            icon: isObd ? Icons.sensors_outlined : Icons.view_in_ar_outlined,
            title: isObd ? 'Local-only diagnostics' : 'Local-only 3D assets',
            message:
                isObd
                    ? 'Motornauts has no customer API for OBD readings. This area is intentionally not synced.'
                    : 'Motornauts has no customer API for vehicle model serving. Use bundled assets only.',
          ),
        ],
      ),
    );
  }
}

class HeaderRow extends StatelessWidget {
  const HeaderRow({
    required this.title,
    this.onRefresh,
    this.action,
    super.key,
  });

  final String title;
  final Future<void> Function()? onRefresh;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
          ),
          if (action != null) action!,
          if (onRefresh != null)
            IconButton(
              tooltip: 'Refresh',
              onPressed: onRefresh,
              icon: const Icon(Icons.refresh),
            ),
        ],
      ),
    );
  }
}

class InfoCard extends StatelessWidget {
  const InfoCard({required this.title, required this.child, super.key});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            child,
          ],
        ),
      ),
    );
  }
}

class ErrorPanel extends StatelessWidget {
  const ErrorPanel({required this.message, required this.onRetry, super.key});

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return InfoCard(
      title: 'Could not load',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(message),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState({
    required this.icon,
    required this.title,
    required this.message,
    super.key,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Icon(icon, size: 40),
            const SizedBox(height: 10),
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(message, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

class DataListTile extends StatelessWidget {
  const DataListTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    this.status = '',
    this.onTap,
    this.trailing,
    super.key,
  });

  final String title;
  final String subtitle;
  final String status;
  final IconData icon;
  final VoidCallback? onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(icon),
        title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Text(
          status.isEmpty ? subtitle : '$subtitle\n$status',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        trailing:
            trailing ??
            (onTap == null ? null : const Icon(Icons.chevron_right)),
        onTap: onTap,
      ),
    );
  }
}

class KeyValueList extends StatelessWidget {
  const KeyValueList({required this.object, required this.keys, super.key});

  final Map<String, dynamic> object;
  final List<String> keys;

  @override
  Widget build(BuildContext context) {
    final entries =
        keys
            .where(
              (key) => object[key] != null && object[key].toString().isNotEmpty,
            )
            .toList();
    if (entries.isEmpty) {
      return const Text('No data returned.');
    }
    return Column(
      children: [
        for (final key in entries)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 136,
                  child: Text(
                    key,
                    style: Theme.of(context).textTheme.labelMedium,
                  ),
                ),
                Expanded(child: Text(object[key].toString())),
              ],
            ),
          ),
      ],
    );
  }
}

class JsonPreview extends StatelessWidget {
  const JsonPreview({required this.data, super.key});

  final Object? data;

  @override
  Widget build(BuildContext context) {
    if (data == null) {
      return const Text('No data returned.');
    }
    const encoder = JsonEncoder.withIndent('  ');
    final text = data is String ? data.toString() : encoder.convert(data);
    return SelectableText(
      text.length > 1800 ? '${text.substring(0, 1800)}\n...' : text,
      style: Theme.of(context).textTheme.bodySmall,
    );
  }
}

DropdownMenuItem<String> _dropdownItem(String value) {
  return DropdownMenuItem(value: value, child: Text(value));
}

Widget _idDropdown({
  required String label,
  required String? value,
  required List<Map<String, dynamic>> items,
  required List<String> idKeys,
  required List<String> labelKeys,
  required ValueChanged<String?> onChanged,
}) {
  final dropdownItems =
      items
          .map((item) {
            final id = objectId(item, idKeys);
            if (id == null) {
              return null;
            }
            return DropdownMenuItem<String>(
              value: id,
              child: Text(valueText(item, labelKeys, fallback: id)),
            );
          })
          .whereType<DropdownMenuItem<String>>()
          .toList();
  final safeValue =
      dropdownItems.any((item) => item.value == value) ? value : null;
  return DropdownButtonFormField<String>(
    initialValue: safeValue,
    decoration: InputDecoration(labelText: label),
    items: dropdownItems,
    onChanged: onChanged,
  );
}

String _enumValue(Object? value, List<String> allowed, String fallback) {
  final text = value?.toString();
  if (text != null && allowed.contains(text)) {
    return text;
  }
  return fallback;
}

String _mimeTypeFor(String fileName) {
  final lower = fileName.toLowerCase();
  if (lower.endsWith('.pdf')) {
    return 'application/pdf';
  }
  if (lower.endsWith('.png')) {
    return 'image/png';
  }
  if (lower.endsWith('.webp')) {
    return 'image/webp';
  }
  return 'image/jpeg';
}

String _moneyText(Map<String, dynamic> object) {
  final currency = valueText(object, const ['currency'], fallback: '');
  final amountMinor = int.tryParse(
    valueText(object, const [
      'amountMinor',
      'totalMinor',
      'lineTotalMinor',
    ], fallback: ''),
  );
  if (amountMinor != null && currency.isNotEmpty) {
    return '$currency ${(amountMinor / 100).toStringAsFixed(2)}';
  }
  return valueText(object, const [
    'amount',
    'total',
    'description',
  ], fallback: '-');
}

String _messageFor(Object error) {
  if (error is MotornautsApiException) {
    final requestId = error.requestId == null ? '' : ' (${error.requestId})';
    return '${error.message}$requestId';
  }
  if (error is MotornautsNetworkException || error is SignedUploadException) {
    return error.toString();
  }
  return 'Something went wrong. Please retry.';
}

void _showSnack(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
}

String _handoffHtml(String action, Map<String, String> fields) {
  final inputs =
      fields.entries
          .map(
            (entry) =>
                '<input type="hidden" name="${_htmlEscape(entry.key)}" value="${_htmlEscape(entry.value)}">',
          )
          .join();
  return '''
<!doctype html>
<html>
<head>
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <style>
    body { font-family: -apple-system, BlinkMacSystemFont, sans-serif; padding: 24px; }
    button { min-height: 44px; padding: 0 18px; border-radius: 8px; }
  </style>
</head>
<body onload="document.forms[0].submit()">
  <p>Opening secure checkout...</p>
  <form method="POST" action="${_htmlEscape(action)}">
    $inputs
    <button type="submit">Continue</button>
  </form>
</body>
</html>
''';
}

String _htmlEscape(String value) {
  return const HtmlEscape(HtmlEscapeMode.attribute).convert(value);
}
