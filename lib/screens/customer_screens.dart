import 'dart:async';
import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../app_theme.dart';
import '../motornauts/api_error.dart';
import '../motornauts/data_helpers.dart';
import '../motornauts/idempotency.dart';
import '../motornauts/link_parser.dart';
import '../motornauts/motornauts_client.dart';
import '../motornauts/payloads.dart';
import '../obd/local_obd.dart';

const double _mobileMaxContentWidth = 720;
const EdgeInsets _mobilePagePadding = EdgeInsets.all(16);
const double _cardBottomSpacing = 12;
const double _tileBottomSpacing = 8;

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

class _MobileBody extends StatelessWidget {
  const _MobileBody({required this.child, this.safeArea = true});

  final Widget child;
  final bool safeArea;

  @override
  Widget build(BuildContext context) {
    final body = Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: _mobileMaxContentWidth),
        child: child,
      ),
    );
    return safeArea ? SafeArea(top: false, child: body) : body;
  }
}

class _MobileListView extends StatelessWidget {
  const _MobileListView({
    required this.children,
    this.listKey,
    this.safeArea = true,
  });

  final List<Widget> children;
  final Key? listKey;
  final bool safeArea;

  @override
  Widget build(BuildContext context) {
    return _MobileBody(
      safeArea: safeArea,
      child: ListView(
        key: listKey,
        padding: _mobilePagePadding,
        physics: const AlwaysScrollableScrollPhysics(),
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        children: children,
      ),
    );
  }
}

class _LoadingBar extends StatelessWidget {
  const _LoadingBar();

  @override
  Widget build(BuildContext context) {
    final colors = MotornautsThemeColors.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(99),
        child: LinearProgressIndicator(
          minHeight: 3,
          backgroundColor: colors.accentMuted,
        ),
      ),
    );
  }
}

class _ButtonProgressIndicator extends StatelessWidget {
  const _ButtonProgressIndicator();

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: 18,
      child: CircularProgressIndicator(
        strokeWidth: 2,
        color:
            IconTheme.of(context).color ??
            Theme.of(context).colorScheme.primary,
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    final text = label.trim();
    if (text.isEmpty) {
      return const SizedBox.shrink();
    }
    final colors = MotornautsThemeColors.of(context);
    final statusColor = _statusColor(colors, text);
    final labelColor =
        Theme.of(context).brightness == Brightness.light
            ? colors.textPrimary
            : statusColor;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: colors.statusBackground(statusColor),
        border: Border.all(color: colors.statusBorder(statusColor)),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: labelColor,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Color _statusColor(MotornautsThemeColors colors, String value) {
    final lower = value.toLowerCase();
    if (lower.contains('approved') ||
        lower.contains('active') ||
        lower.contains('available') ||
        lower.contains('complete') ||
        lower.contains('paid') ||
        lower.contains('success')) {
      return colors.success;
    }
    if (lower.contains('cancel') ||
        lower.contains('declin') ||
        lower.contains('denied') ||
        lower.contains('expired') ||
        lower.contains('fail') ||
        lower.contains('reject')) {
      return colors.danger;
    }
    if (lower.contains('pending') ||
        lower.contains('draft') ||
        lower.contains('requested') ||
        lower.contains('waiting')) {
      return colors.warning;
    }
    return colors.info;
  }
}

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
      } catch (_) {
        signedIn = false;
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
      return const Scaffold(
        body: SafeArea(child: Center(child: CircularProgressIndicator())),
      );
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
    final colors = MotornautsThemeColors.of(context);
    return Scaffold(
      body: SafeArea(
        top: false,
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.domain_disabled_outlined,
                    size: 56,
                    color: colors.textSecondary,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Tenant unavailable',
                    style: Theme.of(context).textTheme.headlineSmall,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    message,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: colors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: onRetry,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Retry'),
                    ),
                  ),
                ],
              ),
            ),
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
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: _mobileMaxContentWidth),
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
        ),
      ),
    );
  }

  Widget _buildOtpTab() {
    return _MobileListView(
      safeArea: false,
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
                  ? const _ButtonProgressIndicator()
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
                    ? const _ButtonProgressIndicator()
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
      child: _MobileListView(
        listKey: const Key('registration-scroll'),
        safeArea: false,
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
                    ? const _ButtonProgressIndicator()
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
      body: SafeArea(top: true, bottom: false, child: screens[_index]),
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
      child: _MobileListView(
        children: [
          _HomeHeader(profile: _profile ?? const {}),
          if (_loading) const _LoadingBar(),
          if (_error != null)
            ErrorPanel(message: _error!, onRetry: _load)
          else ...[
            CustomerProfileSummary(profile: _profile ?? const {}),
            DashboardSummary(data: _summary),
          ],
        ],
      ),
    );
  }
}

class _HomeHeader extends StatelessWidget {
  const _HomeHeader({required this.profile});

  final Map<String, dynamic> profile;

  @override
  Widget build(BuildContext context) {
    final colors = MotornautsThemeColors.of(context);
    final customer = _customerProfileFields(profile);
    final firstName = valueText(customer, const [
      'firstName',
      'givenName',
    ], fallback: 'Customer');
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _greetingFor(DateTime.now()),
                  style: Theme.of(
                    context,
                  ).textTheme.labelMedium?.copyWith(color: colors.textTertiary),
                ),
                const SizedBox(height: 4),
                Text(
                  '$firstName 👋',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: colors.elevated,
              border: Border.all(color: colors.borderDefault),
              borderRadius: BorderRadius.circular(99),
            ),
            child: Icon(Icons.notifications_none, color: colors.textSecondary),
          ),
        ],
      ),
    );
  }
}

class CustomerProfileSummary extends StatelessWidget {
  const CustomerProfileSummary({required this.profile, super.key});

  final Map<String, dynamic> profile;

  @override
  Widget build(BuildContext context) {
    final customer = _customerProfileFields(profile);
    final firstName = valueText(customer, const ['firstName'], fallback: '');
    final lastName = valueText(customer, const ['lastName'], fallback: '');
    final fullName =
        [
          firstName,
          lastName,
        ].where((part) => part.trim().isNotEmpty).join(' ').trim();
    final displayName = fullName.isEmpty ? 'Customer profile' : fullName;
    final email = valueText(customer, const [
      'email',
      'emailAddress',
    ], fallback: '');

    return Padding(
      padding: const EdgeInsets.only(bottom: _cardBottomSpacing),
      child: _SurfacePanel(
        child: Row(
          children: [
            _AvatarMonogram(label: displayName, size: 56),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    displayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  if (email.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      email,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class DashboardSummary extends StatelessWidget {
  const DashboardSummary({required this.data, super.key});

  final Object? data;

  @override
  Widget build(BuildContext context) {
    final summary = objectMap(data);
    if (summary.isEmpty) {
      return const Text('No dashboard summary returned.');
    }
    if (summary['stale'] == true || summary['unavailable'] == true) {
      return _InlineNotice(
        icon: Icons.cloud_off_outlined,
        message: valueText(summary, const [
          'message',
        ], fallback: 'Dashboard summary is unavailable.'),
      );
    }

    final appointmentCount =
        _summaryCount(summary, const [
          'upcomingAppointments',
          'openAppointments',
          'appointments',
        ]) ??
        0;
    final vehicleCount =
        _summaryCount(summary, const ['vehicles', 'vehicleSummary']) ?? 0;
    final serviceJobCount =
        _summaryCount(summary, const [
          'activeServiceJobs',
          'repairOrders',
          'activeRepairOrders',
        ]) ??
        0;
    final approvalCount =
        _summaryCount(summary, const [
          'pendingApprovals',
          'pendingApp',
          'pendingEstimates',
          'pendingApprovalRequests',
        ]) ??
        0;
    final metrics = [
      _DashboardMetricData(
        label: 'Appointments',
        icon: Icons.event_available_outlined,
        count: appointmentCount,
      ),
      _DashboardMetricData(
        label: 'Vehicles',
        icon: Icons.directions_car_outlined,
        count: vehicleCount,
      ),
      _DashboardMetricData(
        label: 'Service jobs',
        icon: Icons.build_circle_outlined,
        count: serviceJobCount,
      ),
      _DashboardMetricData(
        label: 'Approvals',
        icon: Icons.fact_check_outlined,
        count: approvalCount,
        muted: approvalCount == 0,
      ),
    ];

    final appointments = _summaryItems(summary, const [
      'upcomingAppointments',
      'openAppointments',
      'appointments',
    ]);

    final sections =
        [
          _DashboardSectionData(
            title: 'Upcoming appointments',
            icon: Icons.event_available_outlined,
            items: _summaryItems(summary, const [
              'upcomingAppointments',
              'openAppointments',
              'appointments',
            ]),
            itemBuilder: _appointmentRecord,
          ),
          _DashboardSectionData(
            title: 'Active service jobs',
            icon: Icons.build_circle_outlined,
            items: _summaryItems(summary, const [
              'activeServiceJobs',
              'repairOrders',
              'activeRepairOrders',
            ]),
            itemBuilder: _serviceJobRecord,
          ),
          _DashboardSectionData(
            title: 'Pending approvals',
            icon: Icons.fact_check_outlined,
            items: _summaryItems(summary, const [
              'pendingApprovals',
              'pendingApp',
              'pendingEstimates',
              'pendingApprovalRequests',
            ]),
            itemBuilder: _approvalRecord,
          ),
          _DashboardSectionData(
            title: 'Payments',
            icon: Icons.receipt_long_outlined,
            items: _summaryItems(summary, const [
              'pendingPayments',
              'unpaidInvoices',
              'invoicesDue',
            ]),
            itemBuilder: _paymentRecord,
          ),
        ].where((section) => section.items.isNotEmpty).toList();

    if (metrics.isEmpty && sections.isEmpty && appointments.isEmpty) {
      return const Text('No active customer activity returned.');
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionDivider(label: 'Overview'),
        _DashboardMetricsGrid(metrics: metrics),
        const SizedBox(height: 16),
        if (appointments.isNotEmpty) ...[
          const _SectionDivider(label: 'Upcoming'),
          for (final appointment in appointments.take(2))
            _UpcomingAppointmentCard(appointment: appointment),
          const SizedBox(height: 4),
        ],
        for (final section in sections.where(
          (section) => section.title != 'Upcoming appointments',
        ))
          _DashboardSection(section: section),
      ],
    );
  }
}

class _DashboardMetricsGrid extends StatelessWidget {
  const _DashboardMetricsGrid({required this.metrics});

  final List<_DashboardMetricData> metrics;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 560 ? 3 : 2;
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: metrics.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
            mainAxisExtent: 104,
          ),
          itemBuilder: (context, index) {
            return _DashboardMetric(metric: metrics[index]);
          },
        );
      },
    );
  }
}

class _DashboardMetric extends StatelessWidget {
  const _DashboardMetric({required this.metric});

  final _DashboardMetricData metric;

  @override
  Widget build(BuildContext context) {
    final colors = MotornautsThemeColors.of(context);
    final foreground = metric.muted ? colors.textTertiary : colors.accent;
    final borderColor =
        metric.muted ? colors.borderDefault : colors.borderStrong;
    final fillColor = metric.muted ? colors.elevated : colors.accentSubtle;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: fillColor,
        border: Border.all(color: borderColor),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Icon(metric.icon, color: foreground, size: 20),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  metric.count.toString(),
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: metric.muted ? colors.textTertiary : null,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  metric.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: metric.muted ? colors.textTertiary : null,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _UpcomingAppointmentCard extends StatelessWidget {
  const _UpcomingAppointmentCard({required this.appointment});

  final Map<String, dynamic> appointment;

  @override
  Widget build(BuildContext context) {
    final colors = MotornautsThemeColors.of(context);
    final vehicle = objectMap(appointment['vehicle']);
    final servicePackage = objectMap(appointment['servicePackage']);
    final startsAt = _dateTimeFromKeys(appointment, const [
      'confirmedStartAt',
      'rescheduledStartAt',
      'requestedStartAt',
      'startsAt',
    ]);
    final serviceName = valueText(
      servicePackage,
      const ['name'],
      fallback: valueText(appointment, const [
        'servicePackageName',
        'serviceName',
      ], fallback: 'Service'),
    );
    final branchName = valueText(
      objectMap(appointment['branch']),
      const ['name'],
      fallback: valueText(appointment, const ['branchName'], fallback: ''),
    );
    final vehicleText = _vehicleSummaryText(
      vehicle,
      fallback: valueText(appointment, const [
        'vehicleRegistrationNumber',
        'registrationNumber',
        'vehicleId',
      ], fallback: 'Vehicle'),
    );
    final status = valueText(appointment, const ['status'], fallback: '');
    final localStart = startsAt?.toLocal();
    final timeText =
        localStart == null ? '' : DateFormat('h:mm a').format(localStart);
    final monthText =
        localStart == null
            ? '--'
            : DateFormat('MMM').format(localStart).toUpperCase();
    final dayText =
        localStart == null ? '--' : DateFormat('d').format(localStart);

    return Padding(
      padding: const EdgeInsets.only(bottom: _tileBottomSpacing),
      child: _SurfacePanel(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 54,
              height: 64,
              decoration: BoxDecoration(
                color: colors.accentSubtle,
                border: Border.all(color: colors.statusBorder(colors.accent)),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    dayText,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: colors.accent,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    monthText,
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: colors.accent,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          serviceName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                      if (status.isNotEmpty) ...[
                        const SizedBox(width: 8),
                        _StatusBadge(status),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _joinSummaryParts([timeText, branchName], separator: ' - '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 10),
                  _Pill(
                    icon: Icons.directions_car_outlined,
                    label: vehicleText,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DashboardSection extends StatelessWidget {
  const _DashboardSection({required this.section});

  final _DashboardSectionData section;

  @override
  Widget build(BuildContext context) {
    final colors = MotornautsThemeColors.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: EdgeInsets.zero,
          childrenPadding: EdgeInsets.zero,
          iconColor: colors.accent,
          collapsedIconColor: colors.textSecondary,
          leading: Icon(section.icon, size: 20, color: colors.accent),
          title: Text(
            section.title,
            style: Theme.of(context).textTheme.titleSmall,
          ),
          subtitle: Text(
            '${section.items.length} item${section.items.length == 1 ? '' : 's'}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          children: [
            for (final item in section.items.take(3))
              _DashboardRecord(record: section.itemBuilder(item)),
          ],
        ),
      ),
    );
  }
}

class _DashboardRecord extends StatelessWidget {
  const _DashboardRecord({required this.record});

  final _DashboardRecordData record;

  @override
  Widget build(BuildContext context) {
    final colors = MotornautsThemeColors.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border.all(color: colors.borderDefault),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(record.icon, color: colors.textSecondary),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      record.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    if (record.subtitle.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        record.subtitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                    if (record.status.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      _StatusBadge(record.status),
                    ],
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

class _DetailList extends StatelessWidget {
  const _DetailList({required this.rows});

  final List<_DetailRow> rows;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final row in rows)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(row.icon, size: 18),
                const SizedBox(width: 10),
                SizedBox(
                  width: 92,
                  child: Text(
                    row.label,
                    style: Theme.of(context).textTheme.labelMedium,
                  ),
                ),
                Expanded(child: Text(row.value)),
              ],
            ),
          ),
      ],
    );
  }
}

class _InlineNotice extends StatelessWidget {
  const _InlineNotice({required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    final colors = MotornautsThemeColors.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: colors.textSecondary),
        const SizedBox(width: 10),
        Expanded(child: Text(message)),
      ],
    );
  }
}

class _SurfacePanel extends StatelessWidget {
  const _SurfacePanel({
    required this.child,
    this.padding = const EdgeInsets.all(14),
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final colors = MotornautsThemeColors.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border.all(color: colors.borderDefault),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(padding: padding, child: child),
    );
  }
}

class _AvatarMonogram extends StatelessWidget {
  const _AvatarMonogram({required this.label, this.size = 72});

  final String label;
  final double size;

  @override
  Widget build(BuildContext context) {
    final colors = MotornautsThemeColors.of(context);
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: colors.accentSubtle,
        border: Border.all(color: colors.statusBorder(colors.accent)),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        _initialsFor(label),
        style: Theme.of(context).textTheme.titleLarge?.copyWith(
          color: colors.accent,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _SectionDivider extends StatelessWidget {
  const _SectionDivider({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = MotornautsThemeColors.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Text(
            label.toUpperCase(),
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: colors.textTertiary,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(child: Divider(color: colors.borderDefault)),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = MotornautsThemeColors.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: colors.accentSubtle,
        border: Border.all(color: colors.statusBorder(colors.accent)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: colors.accent),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: colors.accent,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DashboardMetricData {
  const _DashboardMetricData({
    required this.label,
    required this.icon,
    required this.count,
    this.muted = false,
  });

  final String label;
  final IconData icon;
  final int count;
  final bool muted;
}

class _DashboardSectionData {
  const _DashboardSectionData({
    required this.title,
    required this.icon,
    required this.items,
    required this.itemBuilder,
  });

  final String title;
  final IconData icon;
  final List<Map<String, dynamic>> items;
  final _DashboardRecordData Function(Map<String, dynamic>) itemBuilder;
}

class _DashboardRecordData {
  const _DashboardRecordData({
    required this.title,
    required this.subtitle,
    required this.status,
    required this.icon,
  });

  final String title;
  final String subtitle;
  final String status;
  final IconData icon;
}

class _DetailRow {
  const _DetailRow({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;
}

class VehicleSummaryOverview extends StatelessWidget {
  const VehicleSummaryOverview({
    required this.summary,
    required this.vehicles,
    super.key,
  });

  final Object? summary;
  final List<Map<String, dynamic>> vehicles;

  @override
  Widget build(BuildContext context) {
    final summaryMap = objectMap(summary);
    final unavailable =
        summaryMap['unavailable'] == true || summaryMap['stale'] == true;
    final hasVehicleFallback = vehicles.isNotEmpty;
    final metrics =
        [
          _metric(
            label: 'Total',
            icon: Icons.directions_car_outlined,
            count:
                _summaryCount(summaryMap, const [
                  'totalVehicles',
                  'vehicleCount',
                  'vehicles',
                  'active',
                ]) ??
                (hasVehicleFallback ? vehicles.length : null),
          ),
          _metric(
            label: 'Approved',
            icon: Icons.verified_outlined,
            count:
                _summaryCount(summaryMap, const [
                  'approvedVehicles',
                  'approved',
                  'verifiedVehicles',
                ]) ??
                (hasVehicleFallback
                    ? _vehicleStatusCount(vehicles, const ['APPROVED'])
                    : null),
          ),
          _metric(
            label: 'Pending',
            icon: Icons.pending_actions_outlined,
            count:
                _summaryCount(summaryMap, const [
                  'pendingVehicles',
                  'pendingVerification',
                  'pending',
                ]) ??
                (hasVehicleFallback
                    ? _vehicleStatusCount(vehicles, const [
                      'PENDING',
                      'PENDING_REVIEW',
                      'REJECTED',
                    ])
                    : null),
          ),
          _metric(
            label: 'Documents',
            icon: Icons.description_outlined,
            count: _summaryCount(summaryMap, const [
              'documents',
              'vehicleDocuments',
              'pendingDocuments',
            ]),
          ),
        ].whereType<_DashboardMetricData>().toList();

    if (metrics.isEmpty && unavailable) {
      return const _InlineNotice(
        icon: Icons.cloud_off_outlined,
        message: 'Vehicle summary is unavailable.',
      );
    }
    if (metrics.isEmpty) {
      return const Text('No vehicle summary returned.');
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _DashboardMetricsGrid(metrics: metrics),
        if (unavailable) ...[
          const SizedBox(height: 12),
          const _InlineNotice(
            icon: Icons.info_outline,
            message:
                'Live vehicle summary is unavailable. Showing garage list totals.',
          ),
        ],
      ],
    );
  }
}

class VehicleDetailOverview extends StatelessWidget {
  const VehicleDetailOverview({required this.vehicle, super.key});

  final Map<String, dynamic> vehicle;

  @override
  Widget build(BuildContext context) {
    final rows = _detailRows([
      _detailRow(
        label: 'Registration',
        icon: Icons.confirmation_number_outlined,
        object: vehicle,
        keys: const ['registrationNumber', 'plateNumber', 'vehicleNumber'],
      ),
      _detailValueRow(
        label: 'Vehicle',
        icon: Icons.directions_car_outlined,
        value: _vehicleNameText(vehicle),
      ),
      _detailRow(
        label: 'Mileage',
        icon: Icons.speed_outlined,
        object: vehicle,
        keys: const ['currentMileage', 'mileage'],
      ),
      _detailValueRow(
        label: 'Fuel',
        icon: Icons.local_gas_station_outlined,
        value: _enumField(vehicle, const ['fuelType']),
      ),
      _detailValueRow(
        label: 'Transmission',
        icon: Icons.settings_outlined,
        value: _enumField(vehicle, const ['transmission']),
      ),
      _detailValueRow(
        label: 'Ownership',
        icon: Icons.assignment_ind_outlined,
        value: _enumField(vehicle, const ['ownershipStatus']),
      ),
      _detailValueRow(
        label: 'Status',
        icon: Icons.verified_outlined,
        value: _enumField(vehicle, const ['verificationStatus', 'status']),
      ),
    ]);
    if (rows.isEmpty) {
      return const Text('No vehicle details returned.');
    }
    return _DetailList(rows: rows);
  }
}

class DocumentUploadPanel extends StatelessWidget {
  const DocumentUploadPanel({
    required this.documentType,
    required this.uploading,
    required this.onDocumentTypeChanged,
    required this.onUpload,
    super.key,
  });

  final String documentType;
  final bool uploading;
  final ValueChanged<String?> onDocumentTypeChanged;
  final VoidCallback onUpload;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DropdownButtonFormField<String>(
          initialValue: documentType,
          isExpanded: true,
          decoration: const InputDecoration(labelText: 'Document type'),
          items:
              _documentTypes
                  .map(
                    (value) => DropdownMenuItem<String>(
                      value: value,
                      child: Text(
                        _enumLabel(value),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  )
                  .toList(),
          onChanged: onDocumentTypeChanged,
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: uploading ? null : onUpload,
          icon:
              uploading
                  ? const _ButtonProgressIndicator()
                  : const Icon(Icons.upload_file_outlined),
          label: Text(uploading ? 'Uploading' : 'Choose file'),
        ),
      ],
    );
  }
}

class AppointmentDetailOverview extends StatelessWidget {
  const AppointmentDetailOverview({required this.appointment, super.key});

  final Map<String, dynamic> appointment;

  @override
  Widget build(BuildContext context) {
    final rows = _detailRows([
      _detailValueRow(
        label: 'Status',
        icon: Icons.flag_outlined,
        value: _enumField(appointment, const ['status']),
      ),
      _detailValueRow(
        label: 'Vehicle',
        icon: Icons.directions_car_outlined,
        value: _recordVehicleText(appointment),
      ),
      _detailValueRow(
        label: 'Service',
        icon: Icons.home_repair_service_outlined,
        value: _recordServiceText(appointment),
      ),
      _detailValueRow(
        label: 'Branch',
        icon: Icons.store_outlined,
        value: valueText(
          objectMap(appointment['branch']),
          const ['name'],
          fallback: valueText(appointment, const ['branchName'], fallback: ''),
        ),
      ),
      _detailValueRow(
        label: 'Requested',
        icon: Icons.event_outlined,
        value: _dateText(
          valueText(appointment, const [
            'requestedStartAt',
            'startsAt',
          ], fallback: ''),
        ),
      ),
      _detailValueRow(
        label: 'Confirmed',
        icon: Icons.event_available_outlined,
        value: _dateText(
          valueText(appointment, const [
            'confirmedStartAt',
            'rescheduledStartAt',
          ], fallback: ''),
        ),
      ),
    ]);
    return _DetailList(rows: rows);
  }
}

class RepairOrderOverview extends StatelessWidget {
  const RepairOrderOverview({required this.repairOrder, super.key});

  final Map<String, dynamic> repairOrder;

  @override
  Widget build(BuildContext context) {
    final rows = _detailRows([
      _detailValueRow(
        label: 'Status',
        icon: Icons.flag_outlined,
        value: _enumField(repairOrder, const ['status', 'workflowStatus']),
      ),
      _detailValueRow(
        label: 'Vehicle',
        icon: Icons.directions_car_outlined,
        value: _recordVehicleText(repairOrder),
      ),
      _detailValueRow(
        label: 'Service',
        icon: Icons.home_repair_service_outlined,
        value: _recordServiceText(repairOrder),
      ),
      _detailValueRow(
        label: 'Checked in',
        icon: Icons.login_outlined,
        value: _dateText(
          valueText(repairOrder, const ['checkedInAt'], fallback: ''),
        ),
      ),
      _detailValueRow(
        label: 'Updated',
        icon: Icons.update_outlined,
        value: _dateText(
          valueText(repairOrder, const [
            'statusChangedAt',
            'updatedAt',
          ], fallback: ''),
        ),
      ),
    ]);
    return _DetailList(rows: rows);
  }
}

class EstimateOverview extends StatelessWidget {
  const EstimateOverview({required this.estimate, super.key});

  final Map<String, dynamic> estimate;

  @override
  Widget build(BuildContext context) {
    final rows = _detailRows([
      _detailValueRow(
        label: 'Status',
        icon: Icons.flag_outlined,
        value: _enumField(estimate, const ['status']),
      ),
      _detailRow(
        label: 'Version',
        icon: Icons.numbers_outlined,
        object: estimate,
        keys: const ['estimateVersion', 'version'],
      ),
      _detailValueRow(
        label: 'Total',
        icon: Icons.payments_outlined,
        value: _moneyText(estimate),
      ),
      _detailValueRow(
        label: 'Expires',
        icon: Icons.event_busy_outlined,
        value: _dateText(
          valueText(estimate, const ['expiresAt', 'validUntil'], fallback: ''),
        ),
      ),
    ]);
    return _DetailList(rows: rows);
  }
}

class EstimateLineItemSummary extends StatelessWidget {
  const EstimateLineItemSummary({required this.item, super.key});

  final Map<String, dynamic> item;

  @override
  Widget build(BuildContext context) {
    final rows = _detailRows([
      _detailRow(
        label: 'Item',
        icon: Icons.build_outlined,
        object: item,
        keys: const ['description', 'name', 'title'],
      ),
      _detailValueRow(
        label: 'Amount',
        icon: Icons.payments_outlined,
        value: _moneyText(item),
      ),
      _detailValueRow(
        label: 'Status',
        icon: Icons.flag_outlined,
        value: _enumField(item, const ['status']),
      ),
    ]);
    return _DetailList(rows: rows);
  }
}

class InvoiceOverview extends StatelessWidget {
  const InvoiceOverview({required this.invoice, super.key});

  final Map<String, dynamic> invoice;

  @override
  Widget build(BuildContext context) {
    final rows = _detailRows([
      _detailValueRow(
        label: 'Status',
        icon: Icons.flag_outlined,
        value: _enumField(invoice, const ['status', 'paymentStatus']),
      ),
      _detailValueRow(
        label: 'Amount',
        icon: Icons.payments_outlined,
        value: _moneyText(invoice),
      ),
      _detailValueRow(
        label: 'Issued',
        icon: Icons.event_note_outlined,
        value: _dateText(
          valueText(invoice, const ['issuedAt', 'createdAt'], fallback: ''),
        ),
      ),
      _detailValueRow(
        label: 'Due',
        icon: Icons.event_busy_outlined,
        value: _dateText(
          valueText(invoice, const ['dueAt', 'dueDate'], fallback: ''),
        ),
      ),
    ]);
    return _DetailList(rows: rows);
  }
}

class FeedbackContextSummary extends StatelessWidget {
  const FeedbackContextSummary({required this.feedback, super.key});

  final Map<String, dynamic> feedback;

  @override
  Widget build(BuildContext context) {
    final rows = _detailRows([
      _detailRow(
        label: 'Service',
        icon: Icons.receipt_long_outlined,
        object: feedback,
        keys: const ['repairOrderNumber', 'repairOrderId'],
      ),
      _detailValueRow(
        label: 'Vehicle',
        icon: Icons.directions_car_outlined,
        value: _recordVehicleText(feedback),
      ),
      _detailRow(
        label: 'Customer',
        icon: Icons.person_outline,
        object: feedback,
        keys: const ['customerName', 'tenantCustomerId'],
      ),
    ]);
    return _DetailList(rows: rows);
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
    return objectId(_customerProfileFields(profile), const [
      'tenantCustomerId',
      'id',
      'customerId',
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final hasLoadedContent = _summary != null || _vehicles.isNotEmpty;
    return RefreshIndicator(
      onRefresh: _load,
      child: _MobileListView(
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
          if (_loading) const _LoadingBar(),
          if (_error != null)
            ErrorPanel(message: _error!, onRetry: _load)
          else if (_loading && !hasLoadedContent)
            const SizedBox.shrink()
          else ...[
            InfoCard(
              title: 'Vehicle summary',
              child: VehicleSummaryOverview(
                summary: _summary,
                vehicles: _vehicles,
              ),
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
        child: _MobileListView(
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
                      ? const _ButtonProgressIndicator()
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
        child: _MobileListView(
          children: [
            if (_loading) const _LoadingBar(),
            if (_error != null)
              ErrorPanel(message: _error!, onRetry: _load)
            else ...[
              InfoCard(
                title: valueText(_vehicle ?? widget.summary, const [
                  'registrationNumber',
                  'nickname',
                ], fallback: 'Vehicle'),
                child: VehicleDetailOverview(
                  vehicle: _vehicle ?? widget.summary,
                ),
              ),
              InfoCard(
                title: 'Upload document',
                child: DocumentUploadPanel(
                  documentType: _documentType,
                  uploading: _uploading,
                  onDocumentTypeChanged: (value) {
                    setState(() => _documentType = value ?? _documentType);
                  },
                  onUpload: _uploadDocument,
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
                    title: _documentTitle(document),
                    subtitle: _documentSubtitle(document),
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
    _mileageController.dispose();
    super.dispose();
  }

  int get _bookingProgressStepCount {
    var count = 0;
    if (_vehicleId != null && _branchId != null) {
      count += 1;
    }
    if (_servicePackageId != null) {
      count += 1;
    }
    if (_mileageController.text.trim().isNotEmpty ||
        _notesController.text.trim().isNotEmpty) {
      count += 1;
    }
    return count;
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
          complaints: null,
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
      child: _MobileListView(
        children: [
          HeaderRow(title: 'New booking', onRefresh: _load),
          if (_loading) const _LoadingBar(),
          if (_error != null)
            ErrorPanel(message: _error!, onRetry: _load)
          else ...[
            InfoCard(
              title: 'Request details',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _BookingProgress(activeSteps: _bookingProgressStepCount),
                  const SizedBox(height: 18),
                  const _SectionDivider(label: 'Vehicle & location'),
                  _richIdDropdown(
                    label: 'Vehicle',
                    icon: Icons.directions_car_outlined,
                    value: _vehicleId,
                    items: _vehicles,
                    idKeys: const ['vehicleId', 'id'],
                    labelKeys: const ['registrationNumber', 'nickname'],
                    subtitleBuilder: _vehicleOptionSubtitle,
                    onChanged: (value) => setState(() => _vehicleId = value),
                  ),
                  const SizedBox(height: 12),
                  _richIdDropdown(
                    label: 'Branch',
                    icon: Icons.store_outlined,
                    value: _branchId,
                    items: _branches,
                    idKeys: const ['branchId', 'id'],
                    labelKeys: const ['name', 'displayName', 'branchName'],
                    subtitleBuilder: _branchOptionSubtitle,
                    onChanged: (value) {
                      setState(() {
                        _branchId = value;
                        _slots = const [];
                        _selectedSlot = null;
                      });
                    },
                  ),
                  const SizedBox(height: 18),
                  const _SectionDivider(label: 'Service'),
                  _richIdDropdown(
                    label: 'Service package',
                    icon: Icons.home_repair_service_outlined,
                    value: _servicePackageId,
                    items: _packages,
                    idKeys: const ['servicePackageId', 'id'],
                    labelKeys: const ['name', 'displayName', 'serviceName'],
                    subtitleBuilder: _servicePackageOptionSubtitle,
                    onChanged: (value) {
                      setState(() {
                        _servicePackageId = value;
                        _slots = const [];
                        _selectedSlot = null;
                      });
                    },
                  ),
                  const SizedBox(height: 12),
                  _DateTimeBadge(value: _requestedAt, onTap: _pickRequestedAt),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed:
                        _checkingAvailability ? null : _checkAvailability,
                    icon:
                        _checkingAvailability
                            ? const _ButtonProgressIndicator()
                            : const Icon(Icons.event_available_outlined),
                    label: const Text('Check availability'),
                  ),
                  if (_slots.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    DropdownButtonFormField<Map<String, dynamic>>(
                      initialValue: _selectedSlot,
                      decoration: const InputDecoration(
                        labelText: 'Available slot',
                        prefixIcon: Icon(Icons.event_available_outlined),
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
                  const SizedBox(height: 18),
                  const _SectionDivider(label: 'Details'),
                  TextField(
                    controller: _mileageController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    onChanged: (_) => setState(() {}),
                    decoration: const InputDecoration(
                      labelText: 'Mileage at booking',
                      hintText: 'e.g. 24,500 km',
                      prefixIcon: Icon(Icons.speed_outlined),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _notesController,
                    maxLines: 3,
                    onChanged: (_) => setState(() {}),
                    decoration: const InputDecoration(
                      labelText: 'Notes / complaints',
                      hintText: 'Describe symptoms or service requests',
                      prefixIcon: Icon(Icons.notes_outlined),
                    ),
                  ),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: _submitting ? null : _submitBooking,
                    icon:
                        _submitting
                            ? const _ButtonProgressIndicator()
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

class _BookingProgress extends StatelessWidget {
  const _BookingProgress({required this.activeSteps});

  final int activeSteps;

  @override
  Widget build(BuildContext context) {
    final colors = MotornautsThemeColors.of(context);
    return Row(
      children: [
        for (var index = 0; index < 3; index += 1) ...[
          Expanded(
            child: Container(
              height: 4,
              decoration: BoxDecoration(
                color:
                    index < activeSteps ? colors.accent : colors.borderDefault,
                borderRadius: BorderRadius.circular(99),
              ),
            ),
          ),
          if (index != 2) const SizedBox(width: 6),
        ],
      ],
    );
  }
}

class _DateTimeBadge extends StatelessWidget {
  const _DateTimeBadge({required this.value, required this.onTap});

  final DateTime value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = MotornautsThemeColors.of(context);
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: colors.accentSubtle,
          border: Border.all(color: colors.statusBorder(colors.accent)),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(Icons.schedule_outlined, color: colors.accent),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    DateFormat('MMM d, yyyy - h:mm a').format(value),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(
                      context,
                    ).textTheme.titleSmall?.copyWith(color: colors.accent),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Tap to change',
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: colors.textTertiary),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
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
      body: _MobileListView(
        children: [
          if (_loading) const _LoadingBar(),
          if (_error != null)
            ErrorPanel(message: _error!, onRetry: _load)
          else if (appointment != null) ...[
            InfoCard(
              title: valueText(appointment, const [
                'status',
              ], fallback: 'Appointment'),
              child: AppointmentDetailOverview(appointment: appointment),
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
      child: _MobileListView(
        children: [
          HeaderRow(title: 'Service', onRefresh: _load),
          if (_loading) const _LoadingBar(),
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
        child: _MobileListView(
          children: [
            if (_loading) const _LoadingBar(),
            if (_error != null)
              ErrorPanel(message: _error!, onRetry: _load)
            else if (_repairOrder != null) ...[
              InfoCard(
                title: valueText(_repairOrder!, const [
                  'repairOrderNumber',
                  'number',
                  'status',
                ], fallback: 'Repair order'),
                child: RepairOrderOverview(repairOrder: _repairOrder!),
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
      body: _MobileListView(
        children: [
          if (_loading) const _LoadingBar(),
          if (_error != null)
            ErrorPanel(message: _error!, onRetry: _load)
          else if (_estimate != null) ...[
            InfoCard(
              title: valueText(_estimate!, const [
                'estimateNumber',
                'status',
              ], fallback: 'Estimate'),
              child: EstimateOverview(estimate: _estimate!),
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
                      ? const _ButtonProgressIndicator()
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
      return InfoCard(
        title: 'Line item',
        child: EstimateLineItemSummary(item: item),
      );
    }
    _notes.putIfAbsent(id, TextEditingController.new);
    final colors = MotornautsThemeColors.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: _cardBottomSpacing),
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: Padding(
          padding: const EdgeInsets.all(14),
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
              Text(
                _moneyText(item),
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: colors.textSecondary),
              ),
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
      body: _MobileListView(
        children: [
          if (_loading) const _LoadingBar(),
          if (_error != null)
            ErrorPanel(message: _error!, onRetry: _load)
          else if (_invoice != null) ...[
            InfoCard(
              title: valueText(_invoice!, const [
                'invoiceNumber',
                'number',
                'status',
              ], fallback: 'Invoice'),
              child: InvoiceOverview(invoice: _invoice!),
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
    return _MobileListView(
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
                MaterialPageRoute<void>(builder: (_) => const LocalObdScreen()),
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
  Map<String, dynamic>? _profile;
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
      _firstNameController.text = _profileFieldText(profile, const [
        'firstName',
        'givenName',
      ]);
      _lastNameController.text = _profileFieldText(profile, const [
        'lastName',
        'familyName',
        'surname',
      ]);
      _phoneController.text = _localSriLankaPhoneText(
        _profileFieldText(profile, const [
          'phone',
          'phoneNumber',
          'contactNumber',
          'mobile',
          'mobileNumber',
        ]),
      );
      _address1Controller.text = _profileFieldText(profile, const [
        'addressLine1',
        'line1',
        'streetAddress',
        'street',
      ]);
      _address2Controller.text = _profileFieldText(profile, const [
        'addressLine2',
        'line2',
        'suite',
      ]);
      _cityController.text = _profileFieldText(profile, const [
        'city',
        'locality',
      ]);
      setState(() {
        _profile = profile;
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
          phone: _fullSriLankaPhoneText(_phoneController.text),
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
        child: _MobileListView(
          children: [
            if (_loading) const _LoadingBar(),
            if (_error != null)
              ErrorPanel(message: _error!, onRetry: _load)
            else ...[
              _ProfileHero(
                profile: _profile ?? const {},
                firstName: _firstNameController.text,
                lastName: _lastNameController.text,
                city: _cityController.text,
              ),
              const SizedBox(height: 18),
              const _SectionDivider(label: 'Personal info'),
              LayoutBuilder(
                builder: (context, constraints) {
                  if (constraints.maxWidth < 380) {
                    return Column(
                      children: [
                        _field(_firstNameController, 'First name', 'firstName'),
                        _field(_lastNameController, 'Last name', 'lastName'),
                      ],
                    );
                  }
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: _field(
                          _firstNameController,
                          'First name',
                          'firstName',
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _field(
                          _lastNameController,
                          'Last name',
                          'lastName',
                        ),
                      ),
                    ],
                  );
                },
              ),
              _phoneField(),
              const SizedBox(height: 6),
              const _SectionDivider(label: 'Address'),
              _field(
                _address1Controller,
                'Street',
                'addressLine1',
                required: false,
              ),
              _field(
                _address2Controller,
                'Area / landmark',
                'addressLine2',
                required: false,
              ),
              _field(_cityController, 'City', 'city', required: false),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: _saving ? null : _save,
                icon:
                    _saving
                        ? const _ButtonProgressIndicator()
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
    List<TextInputFormatter>? inputFormatters,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: controller,
        inputFormatters: inputFormatters,
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

  Widget _phoneField() {
    final colors = MotornautsThemeColors.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 64,
            height: 56,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: colors.elevated,
              border: Border.all(color: colors.borderDefault),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text('+94', style: Theme.of(context).textTheme.titleSmall),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: TextFormField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: InputDecoration(
                labelText: 'Phone number',
                errorText: _fieldErrors['phone'],
              ),
              validator: (value) {
                if (value?.trim().isEmpty ?? true) {
                  return 'Required';
                }
                return null;
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileHero extends StatelessWidget {
  const _ProfileHero({
    required this.profile,
    required this.firstName,
    required this.lastName,
    required this.city,
  });

  final Map<String, dynamic> profile;
  final String firstName;
  final String lastName;
  final String city;

  @override
  Widget build(BuildContext context) {
    final colors = MotornautsThemeColors.of(context);
    final customer = _customerProfileFields(profile);
    final email = valueText(customer, const [
      'email',
      'emailAddress',
    ], fallback: '');
    final name =
        [
          firstName,
          lastName,
        ].where((part) => part.trim().isNotEmpty).join(' ').trim();
    final displayName = name.isEmpty ? 'Profile' : name;
    final cityLabel = city.trim();

    return _SurfacePanel(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 22),
      child: Column(
        children: [
          Row(
            children: [
              Icon(Icons.person_outline, color: colors.textSecondary),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Profile',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
              ),
              if (cityLabel.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: colors.elevated,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    cityLabel,
                    style: Theme.of(context).textTheme.labelMedium,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 18),
          _AvatarMonogram(label: displayName),
          const SizedBox(height: 12),
          Text(
            displayName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          if (email.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              email,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
          const SizedBox(height: 12),
          const _VerifiedAccountChip(),
        ],
      ),
    );
  }
}

class _VerifiedAccountChip extends StatelessWidget {
  const _VerifiedAccountChip();

  @override
  Widget build(BuildContext context) {
    final colors = MotornautsThemeColors.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: colors.statusBackground(colors.success),
        border: Border.all(color: colors.statusBorder(colors.success)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.verified_outlined, size: 16, color: colors.success),
          const SizedBox(width: 6),
          Text(
            'Verified account',
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: colors.success,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
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
        child: _MobileListView(
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
                      ? const _ButtonProgressIndicator()
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
      body: _MobileListView(
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
        child: _MobileListView(
          children: [
            if (_loading) const _LoadingBar(),
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
      body: SafeArea(top: false, child: WebViewWidget(controller: _controller)),
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
      body: _MobileListView(
        children: [
          if (_loading) const _LoadingBar(),
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
                child: FeedbackContextSummary(feedback: _feedback!),
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
                      ? const _ButtonProgressIndicator()
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
      body: _MobileListView(
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
    final colors = MotornautsThemeColors.of(context);
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
              icon: Icon(Icons.refresh, color: colors.accent),
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
    final colors = MotornautsThemeColors.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: _cardBottomSpacing),
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(color: colors.textPrimary),
              ),
              const SizedBox(height: 8),
              child,
            ],
          ),
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
    final colors = MotornautsThemeColors.of(context);
    return InfoCard(
      title: 'Could not load',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.error_outline, color: colors.danger),
              const SizedBox(width: 10),
              Expanded(child: Text(message)),
            ],
          ),
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
    final colors = MotornautsThemeColors.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: _cardBottomSpacing),
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Icon(icon, size: 40, color: colors.textSecondary),
              const SizedBox(height: 10),
              Text(title, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 4),
              Text(
                message,
                textAlign: TextAlign.center,
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: colors.textSecondary),
              ),
            ],
          ),
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
    final colors = MotornautsThemeColors.of(context);
    final statusText = status.trim();
    final subtitleText = subtitle.trim();
    return Padding(
      padding: const EdgeInsets.only(bottom: _tileBottomSpacing),
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: ListTile(
          leading: Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: colors.accentSubtle,
              border: Border.all(color: colors.borderDefault),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: colors.accent),
          ),
          title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (subtitleText.isNotEmpty)
                  Text(
                    subtitleText,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                if (statusText.isNotEmpty) ...[
                  if (subtitleText.isNotEmpty) const SizedBox(height: 6),
                  _StatusBadge(statusText),
                ],
              ],
            ),
          ),
          minVerticalPadding: 10,
          trailing:
              trailing ??
              (onTap == null ? null : const Icon(Icons.chevron_right)),
          onTap: onTap,
        ),
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
    final colors = MotornautsThemeColors.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 360;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final key in entries)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child:
                    compact
                        ? Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              key,
                              style: Theme.of(context).textTheme.labelMedium,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              object[key].toString(),
                              style: TextStyle(color: colors.textPrimary),
                            ),
                          ],
                        )
                        : Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(
                              width: 136,
                              child: Text(
                                key,
                                style: Theme.of(context).textTheme.labelMedium,
                              ),
                            ),
                            Expanded(
                              child: Text(
                                object[key].toString(),
                                style: TextStyle(color: colors.textPrimary),
                              ),
                            ),
                          ],
                        ),
              ),
          ],
        );
      },
    );
  }
}

Map<String, dynamic> _customerProfileFields(Map<String, dynamic> profile) {
  final fields = {
    ...profile,
    ...objectMap(profile['customer']),
    ...objectMap(profile['tenantCustomer']),
    ...objectMap(profile['customerProfile']),
    ...objectMap(profile['profile']),
    ...objectMap(profile['user']),
    ...objectMap(profile['account']),
  };
  return {
    ...fields,
    ...objectMap(fields['address']),
    ...objectMap(fields['mailingAddress']),
    ...objectMap(fields['billingAddress']),
  };
}

String _greetingFor(DateTime value) {
  final hour = value.hour;
  if (hour < 12) {
    return 'Good morning';
  }
  if (hour < 17) {
    return 'Good afternoon';
  }
  return 'Good evening';
}

String _initialsFor(String value) {
  final parts =
      value
          .trim()
          .split(RegExp(r'\s+'))
          .where((part) => part.isNotEmpty)
          .toList();
  if (parts.isEmpty) {
    return 'AA';
  }
  final first = parts.first.substring(0, 1).toUpperCase();
  final second =
      parts.length > 1
          ? parts.last.substring(0, 1).toUpperCase()
          : (parts.first.length > 1
              ? parts.first.substring(1, 2).toUpperCase()
              : '');
  return '$first$second';
}

DateTime? _dateTimeFromKeys(Map<String, dynamic> object, List<String> keys) {
  final value = valueText(object, keys, fallback: '');
  if (value.isEmpty) {
    return null;
  }
  return DateTime.tryParse(value);
}

String _profileFieldText(Map<String, dynamic> profile, List<String> keys) {
  return valueText(_customerProfileFields(profile), keys, fallback: '');
}

String _localSriLankaPhoneText(String value) {
  var digits = value.replaceAll(RegExp(r'\D'), '');
  if (digits.startsWith('94')) {
    digits = digits.substring(2);
  }
  if (digits.startsWith('0')) {
    digits = digits.substring(1);
  }
  return digits;
}

String _fullSriLankaPhoneText(String value) {
  var digits = value.replaceAll(RegExp(r'\D'), '');
  if (digits.startsWith('94')) {
    digits = digits.substring(2);
  }
  if (digits.startsWith('0')) {
    digits = digits.substring(1);
  }
  return '+94$digits';
}

_DetailRow? _detailRow({
  required String label,
  required IconData icon,
  required Map<String, dynamic> object,
  required List<String> keys,
}) {
  final value = valueText(object, keys, fallback: '');
  if (value.isEmpty) {
    return null;
  }
  return _DetailRow(label: label, value: value, icon: icon);
}

_DashboardMetricData? _metric({
  required String label,
  required IconData icon,
  required int? count,
}) {
  if (count == null) {
    return null;
  }
  return _DashboardMetricData(label: label, icon: icon, count: count);
}

int? _summaryCount(Map<String, dynamic> summary, List<String> keys) {
  for (final key in keys) {
    final value = summary[key];
    if (value is num) {
      return value.toInt();
    }
    if (value is List) {
      return value.length;
    }
    final map = objectMap(value);
    if (map.isEmpty) {
      continue;
    }
    final count = map['count'];
    if (count is num) {
      return count.toInt();
    }
    final parsedCount = int.tryParse(count?.toString() ?? '');
    if (parsedCount != null) {
      return parsedCount;
    }
    final items = objectList(map, keys: const ['items', 'results', 'data']);
    if (items.isNotEmpty) {
      return items.length;
    }
  }
  return null;
}

List<Map<String, dynamic>> _summaryItems(
  Map<String, dynamic> summary,
  List<String> keys,
) {
  for (final key in keys) {
    final items = objectList(
      summary[key],
      keys: const ['items', 'results', 'data'],
    );
    if (items.isNotEmpty) {
      return items;
    }
  }
  return const [];
}

_DashboardRecordData _appointmentRecord(Map<String, dynamic> item) {
  final vehicle = objectMap(item['vehicle']);
  final servicePackage = objectMap(item['servicePackage']);
  final time = _dateText(
    valueText(item, const [
      'confirmedStartAt',
      'rescheduledStartAt',
      'requestedStartAt',
      'startsAt',
    ], fallback: ''),
  );
  final serviceName = valueText(
    servicePackage,
    const ['name'],
    fallback: valueText(item, const [
      'servicePackageName',
      'serviceName',
    ], fallback: 'Service'),
  );
  final vehicleText = _vehicleSummaryText(
    vehicle,
    fallback: valueText(item, const [
      'vehicleRegistrationNumber',
      'registrationNumber',
      'vehicleId',
    ], fallback: 'Vehicle'),
  );
  return _DashboardRecordData(
    title: time.isEmpty ? serviceName : time,
    subtitle: _joinSummaryParts([vehicleText, serviceName]),
    status: valueText(item, const ['status'], fallback: ''),
    icon: Icons.event_note_outlined,
  );
}

_DashboardRecordData _serviceJobRecord(Map<String, dynamic> item) {
  final vehicle = objectMap(item['vehicle']);
  final servicePackage = objectMap(item['servicePackage']);
  final serviceName = valueText(
    servicePackage,
    const ['name'],
    fallback: valueText(item, const [
      'servicePackageName',
      'serviceName',
    ], fallback: 'Service job'),
  );
  final changedAt = _dateText(
    valueText(item, const [
      'statusChangedAt',
      'updatedAt',
      'checkedInAt',
    ], fallback: ''),
  );
  final vehicleText = _vehicleSummaryText(
    vehicle,
    fallback: valueText(item, const [
      'vehicleRegistrationNumber',
      'registrationNumber',
      'vehicleId',
    ], fallback: ''),
  );
  return _DashboardRecordData(
    title: valueText(item, const [
      'repairOrderNumber',
      'number',
      'id',
    ], fallback: serviceName),
    subtitle: _joinSummaryParts([vehicleText, serviceName, changedAt]),
    status: valueText(item, const ['status', 'workflowStatus'], fallback: ''),
    icon: Icons.build_circle_outlined,
  );
}

_DashboardRecordData _approvalRecord(Map<String, dynamic> item) {
  final amount = _moneyText(item);
  final vehicleText = _vehicleSummaryText(
    objectMap(item['vehicle']),
    fallback: valueText(item, const [
      'vehicleRegistrationNumber',
      'registrationNumber',
    ], fallback: ''),
  );
  return _DashboardRecordData(
    title: valueText(item, const [
      'estimateNumber',
      'number',
      'title',
      'id',
    ], fallback: 'Approval needed'),
    subtitle: _joinSummaryParts([if (amount != '-') amount, vehicleText]),
    status: valueText(item, const ['status'], fallback: 'PENDING'),
    icon: Icons.fact_check_outlined,
  );
}

_DashboardRecordData _paymentRecord(Map<String, dynamic> item) {
  final amount = _moneyText(item);
  return _DashboardRecordData(
    title: valueText(item, const [
      'invoiceNumber',
      'paymentRequestId',
      'number',
      'id',
    ], fallback: 'Payment'),
    subtitle: amount == '-' ? '' : amount,
    status: valueText(item, const ['status', 'paymentStatus'], fallback: ''),
    icon: Icons.receipt_long_outlined,
  );
}

String _vehicleSummaryText(
  Map<String, dynamic> vehicle, {
  String fallback = '',
}) {
  final registration = valueText(vehicle, const [
    'registrationNumber',
    'plateNumber',
    'vehicleNumber',
  ], fallback: '');
  final make = valueText(vehicle, const ['make'], fallback: '');
  final model = valueText(vehicle, const ['model'], fallback: '');
  final year = valueText(vehicle, const ['year'], fallback: '');
  final name = _joinSummaryParts([make, model, year], separator: ' ');
  if (registration.isNotEmpty && name.isNotEmpty) {
    return '$registration - $name';
  }
  if (registration.isNotEmpty) {
    return registration;
  }
  if (name.isNotEmpty) {
    return name;
  }
  return fallback;
}

String _dateText(String value) {
  if (value.isEmpty) {
    return '';
  }
  final parsed = DateTime.tryParse(value);
  if (parsed == null) {
    return value;
  }
  return DateFormat('MMM d, h:mm a').format(parsed.toLocal());
}

String _joinSummaryParts(Iterable<String> parts, {String separator = ' - '}) {
  return parts
      .map((part) => part.trim())
      .where((part) => part.isNotEmpty && part != '-')
      .join(separator);
}

List<_DetailRow> _detailRows(Iterable<_DetailRow?> rows) {
  return rows.whereType<_DetailRow>().toList();
}

_DetailRow? _detailValueRow({
  required String label,
  required IconData icon,
  required String value,
}) {
  final cleanValue = value.trim();
  if (cleanValue.isEmpty || cleanValue == '-') {
    return null;
  }
  return _DetailRow(label: label, value: cleanValue, icon: icon);
}

int _vehicleStatusCount(
  List<Map<String, dynamic>> vehicles,
  List<String> statuses,
) {
  final allowed = statuses.map((status) => status.toUpperCase()).toSet();
  return vehicles.where((vehicle) {
    final status =
        valueText(vehicle, const [
          'verificationStatus',
          'status',
        ], fallback: '').toUpperCase();
    return allowed.contains(status);
  }).length;
}

String _vehicleNameText(Map<String, dynamic> vehicle) {
  final make = valueText(vehicle, const [
    'make',
    'selectedBrand',
  ], fallback: '');
  final model = valueText(vehicle, const [
    'model',
    'selectedModel',
  ], fallback: '');
  final year = valueText(vehicle, const ['year'], fallback: '');
  final name = _joinSummaryParts([make, model, year], separator: ' ');
  if (name.isNotEmpty) {
    return name;
  }
  return valueText(vehicle, const ['nickname'], fallback: '');
}

String _enumField(Map<String, dynamic> object, List<String> keys) {
  return _enumLabel(valueText(object, keys, fallback: ''));
}

String _enumLabel(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty || trimmed == '-') {
    return '';
  }
  final enumPattern = RegExp(r'^[A-Z0-9_]+$');
  if (!enumPattern.hasMatch(trimmed)) {
    return trimmed;
  }
  final words =
      trimmed
          .split('_')
          .where((part) => part.isNotEmpty)
          .map((part) => part.toLowerCase())
          .toList();
  if (words.isEmpty) {
    return '';
  }
  return [
    '${words.first[0].toUpperCase()}${words.first.substring(1)}',
    ...words.skip(1),
  ].join(' ');
}

String _recordVehicleText(Map<String, dynamic> record) {
  return _vehicleSummaryText(
    objectMap(record['vehicle']),
    fallback: valueText(record, const [
      'vehicleRegistrationNumber',
      'registrationNumber',
      'vehicleNumber',
      'vehicleId',
    ], fallback: ''),
  );
}

String _recordServiceText(Map<String, dynamic> record) {
  return valueText(
    objectMap(record['servicePackage']),
    const ['name'],
    fallback: valueText(
      objectMap(record['service']),
      const ['name'],
      fallback: valueText(record, const [
        'servicePackageName',
        'serviceName',
        'packageName',
      ], fallback: ''),
    ),
  );
}

String _documentTitle(Map<String, dynamic> document) {
  final documentType = valueText(document, const [
    'documentType',
  ], fallback: '');
  if (documentType.isNotEmpty) {
    return _enumLabel(documentType);
  }
  return valueText(document, const ['fileName', 'name'], fallback: 'Document');
}

String _documentSubtitle(Map<String, dynamic> document) {
  final fileName = valueText(document, const [
    'fileName',
    'name',
  ], fallback: '');
  final status = _enumField(document, const ['status', 'verificationStatus']);
  final mimeType = valueText(document, const ['mimeType'], fallback: '');
  return _joinSummaryParts([fileName, status, mimeType]);
}

DropdownMenuItem<String> _dropdownItem(String value) {
  return DropdownMenuItem(value: value, child: Text(_enumLabel(value)));
}

Widget _richIdDropdown({
  required String label,
  required IconData icon,
  required String? value,
  required List<Map<String, dynamic>> items,
  required List<String> idKeys,
  required List<String> labelKeys,
  required String Function(Map<String, dynamic> item) subtitleBuilder,
  required ValueChanged<String?> onChanged,
}) {
  final options =
      items
          .map((item) {
            final id = objectId(item, idKeys);
            if (id == null) {
              return null;
            }
            return _DropdownOptionData(
              id: id,
              title: valueText(item, labelKeys, fallback: id),
              subtitle: subtitleBuilder(item),
            );
          })
          .whereType<_DropdownOptionData>()
          .toList();
  final safeValue = options.any((item) => item.id == value) ? value : null;
  return DropdownButtonFormField<String>(
    isExpanded: true,
    initialValue: safeValue,
    decoration: InputDecoration(labelText: label, prefixIcon: Icon(icon)),
    items:
        options
            .map(
              (option) => DropdownMenuItem<String>(
                value: option.id,
                child: _DropdownOption(option: option),
              ),
            )
            .toList(),
    selectedItemBuilder:
        (context) =>
            options
                .map((option) => _DropdownOption(option: option, compact: true))
                .toList(),
    onChanged: onChanged,
  );
}

String _vehicleOptionSubtitle(Map<String, dynamic> item) {
  return _vehicleNameText(item);
}

String _branchOptionSubtitle(Map<String, dynamic> item) {
  return _joinSummaryParts([
    valueText(item, const ['city', 'locality'], fallback: ''),
    valueText(item, const ['addressLine1', 'street'], fallback: ''),
  ], separator: ' - ');
}

String _servicePackageOptionSubtitle(Map<String, dynamic> item) {
  final duration = valueText(item, const [
    'durationMinutes',
    'estimatedDurationMinutes',
  ], fallback: '');
  final description = valueText(item, const [
    'shortDescription',
    'description',
    'category',
  ], fallback: '');
  return _joinSummaryParts([
    description,
    if (duration.isNotEmpty) '$duration min',
  ], separator: ' - ');
}

class _DropdownOptionData {
  const _DropdownOptionData({
    required this.id,
    required this.title,
    required this.subtitle,
  });

  final String id;
  final String title;
  final String subtitle;
}

class _DropdownOption extends StatelessWidget {
  const _DropdownOption({required this.option, this.compact = false});

  final _DropdownOptionData option;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final colors = MotornautsThemeColors.of(context);
    if (compact) {
      return Text(
        option.title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.titleSmall,
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            option.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleSmall,
          ),
          if (option.subtitle.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              option.subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: colors.textTertiary),
            ),
          ],
        ],
      ),
    );
  }
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
