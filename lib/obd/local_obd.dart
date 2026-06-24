import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';

import '../app_theme.dart';

const List<String> localObdVehiclePresets = [
  'Toyota Camry',
  'Honda Civic',
  'Suzuki Estilo',
  'BMW X5',
  'Mercedes C-Class',
  'Ford Mustang',
  'Hyundai Elantra',
  'Kia Seltos',
  'Nissan Altima',
  'Mazda 3',
];

const Map<String, String> obdDtcDescriptions = {
  'P0100': 'Mass or volume air flow circuit malfunction',
  'P0101': 'Mass air flow circuit range or performance',
  'P0115': 'Engine coolant temperature circuit malfunction',
  'P0128': 'Coolant thermostat temperature below regulating range',
  'P0133': 'Oxygen sensor circuit slow response',
  'P0171': 'System too lean',
  'P0172': 'System too rich',
  'P0300': 'Random or multiple cylinder misfire detected',
  'P0301': 'Cylinder 1 misfire detected',
  'P0302': 'Cylinder 2 misfire detected',
  'P0340': 'Camshaft position sensor circuit malfunction',
  'P0343': 'Camshaft position sensor circuit high input',
  'P0401': 'Exhaust gas recirculation flow insufficient',
  'P0420': 'Catalyst system efficiency below threshold',
  'P0440': 'Evaporative emission control system malfunction',
  'P0442': 'Evaporative emission control system small leak detected',
  'P0455': 'Evaporative emission control system gross leak detected',
  'P0500': 'Vehicle speed sensor malfunction',
  'P0700': 'Transmission control system malfunction',
};

const Map<String, List<String>> _obdRepairHints = {
  'P0101': [
    'Inspect the air filter and intake hose for restrictions or leaks.',
    'Check the MAF sensor connector and wiring.',
    'Clean the MAF sensor only with electronics-safe MAF cleaner.',
  ],
  'P0115': [
    'Check coolant level when the engine is cold.',
    'Inspect the coolant temperature sensor connector.',
    'Compare coolant temperature against a cold engine before replacing parts.',
  ],
  'P0133': [
    'Inspect the oxygen sensor wiring and connector.',
    'Check for exhaust leaks before the sensor.',
    'A slow response can require sensor replacement after wiring is verified.',
  ],
  'P0171': [
    'Look for vacuum leaks around intake hoses and PCV lines.',
    'Check air intake clamps after the MAF sensor.',
    'Inspect fuel pressure if the lean condition returns after clearing.',
  ],
  'P0300': [
    'Check spark plugs, ignition coils, and plug wires.',
    'Listen for rough idle and note whether the misfire happens cold or hot.',
    'Avoid extended driving if the check engine light is flashing.',
  ],
  'P0343': [
    'Inspect the camshaft position sensor connector.',
    'Check wiring for oil contamination, heat damage, or corrosion.',
    'Professional voltage testing is recommended before replacing the ECU.',
  ],
  'P0420': [
    'Repair misfires or fuel trim issues before replacing the catalyst.',
    'Check for exhaust leaks near the upstream and downstream oxygen sensors.',
    'Confirm catalyst efficiency with live oxygen sensor data.',
  ],
};

class ObdAdapter {
  const ObdAdapter({
    required this.id,
    required this.name,
    this.rssi,
    this.isDemo = false,
  });

  final String id;
  final String name;
  final int? rssi;
  final bool isDemo;

  String get label {
    final cleanName = name.trim();
    if (cleanName.isNotEmpty) {
      return cleanName;
    }
    return isDemo ? 'Demo ELM327 adapter' : 'BLE adapter ${_shortId(id)}';
  }
}

class ObdLiveData {
  const ObdLiveData({
    this.rpm,
    this.speedKmh,
    this.coolantTempC,
    this.engineLoadPercent,
    this.intakeTempC,
    this.throttlePercent,
    this.mafGramsPerSecond,
    this.fuelLevelPercent,
    this.controlVoltage,
  });

  final double? rpm;
  final double? speedKmh;
  final double? coolantTempC;
  final double? engineLoadPercent;
  final double? intakeTempC;
  final double? throttlePercent;
  final double? mafGramsPerSecond;
  final double? fuelLevelPercent;
  final double? controlVoltage;

  bool get hasAnyValue =>
      rpm != null ||
      speedKmh != null ||
      coolantTempC != null ||
      engineLoadPercent != null ||
      intakeTempC != null ||
      throttlePercent != null ||
      mafGramsPerSecond != null ||
      fuelLevelPercent != null ||
      controlVoltage != null;
}

class DiagnosticTroubleCode {
  const DiagnosticTroubleCode({
    required this.code,
    required this.status,
    required this.description,
  });

  final String code;
  final String status;
  final String description;

  List<String> get repairHints =>
      _obdRepairHints[code] ??
      const [
        'Record the code and freeze-frame values before clearing it.',
        'Check visible connectors, fluid levels, and recent repair work first.',
        'Use a workshop scan tool if the code returns after a short drive.',
      ];
}

class ObdFreezeFrame {
  const ObdFreezeFrame({this.triggerCode, required this.data});

  final String? triggerCode;
  final ObdLiveData data;
}

class ObdCommandLog {
  const ObdCommandLog({
    required this.command,
    required this.response,
    required this.timestamp,
  });

  final String command;
  final String response;
  final DateTime timestamp;
}

abstract class ObdTransport {
  bool get isConnected;
  String get connectionLabel;

  Future<List<ObdAdapter>> scan({
    Duration timeout = const Duration(seconds: 6),
  });
  Future<void> connect(ObdAdapter adapter);
  Future<String> send(
    String command, {
    Duration timeout = const Duration(seconds: 5),
  });
  Future<void> disconnect();
}

class DemoObdTransport implements ObdTransport {
  bool _connected = false;
  int _tick = 0;

  @override
  bool get isConnected => _connected;

  @override
  String get connectionLabel =>
      _connected ? 'Demo adapter connected' : 'Demo adapter';

  @override
  Future<List<ObdAdapter>> scan({
    Duration timeout = const Duration(seconds: 6),
  }) async {
    return const [
      ObdAdapter(
        id: 'demo-elm327',
        name: 'Demo ELM327 BLE',
        rssi: -42,
        isDemo: true,
      ),
    ];
  }

  @override
  Future<void> connect(ObdAdapter adapter) async {
    await Future<void>.delayed(const Duration(milliseconds: 250));
    _connected = true;
  }

  @override
  Future<void> disconnect() async {
    _connected = false;
  }

  @override
  Future<String> send(
    String command, {
    Duration timeout = const Duration(seconds: 5),
  }) async {
    if (!_connected) {
      throw StateError('Demo adapter is not connected.');
    }
    await Future<void>.delayed(const Duration(milliseconds: 120));
    final normalized = command.trim().toUpperCase();
    if (normalized.startsWith('AT')) {
      return '$normalized\rOK\r>';
    }
    _tick += 1;
    return switch (normalized) {
      '0104' => '41 04 ${_hexByte(108 + (_tick % 12))}\r>',
      '0105' => '41 05 ${_hexByte(94 + (_tick % 6))}\r>',
      '010C' => _rpmResponse(1550 + (_tick % 5) * 95),
      '010D' => '41 0D ${_hexByte(42 + (_tick % 8))}\r>',
      '010F' => '41 0F ${_hexByte(82 + (_tick % 5))}\r>',
      '0110' => '41 10 01 ${_hexByte(120 + (_tick % 16))}\r>',
      '0111' => '41 11 ${_hexByte(48 + (_tick % 10))}\r>',
      '012F' => '41 2F 86\r>',
      '0142' => '41 42 36 B0\r>',
      '0202' => '42 02 01 33\r>',
      '0204' => '42 04 6F\r>',
      '0205' => '42 05 61\r>',
      '020C' => _freezeRpmResponse(1810),
      '020D' => '42 0D 38\r>',
      '020F' => '42 0F 57\r>',
      '0210' => '42 10 01 70\r>',
      '0211' => '42 11 52\r>',
      '022F' => '42 2F 82\r>',
      '0242' => '42 42 36 98\r>',
      '03' => '43 01 33 03 00 00 00\r>',
      '07' => '47 01 71 00 00\r>',
      '04' => '44\r>',
      _ => 'NO DATA\r>',
    };
  }

  String _rpmResponse(int rpm) {
    final raw = rpm * 4;
    return '41 0C ${_hexByte(raw ~/ 256)} ${_hexByte(raw % 256)}\r>';
  }

  String _freezeRpmResponse(int rpm) {
    final raw = rpm * 4;
    return '42 0C ${_hexByte(raw ~/ 256)} ${_hexByte(raw % 256)}\r>';
  }
}

class BleObdTransport implements ObdTransport {
  BleObdTransport({FlutterReactiveBle? ble})
    : _ble = ble ?? FlutterReactiveBle();

  final FlutterReactiveBle _ble;
  final Map<String, DiscoveredDevice> _scanCache = {};
  final StringBuffer _buffer = StringBuffer();
  final Duration _connectTimeout = const Duration(seconds: 12);

  StreamSubscription<ConnectionStateUpdate>? _connectionSubscription;
  StreamSubscription<List<int>>? _notifySubscription;
  Characteristic? _writeCharacteristic;
  Characteristic? _responseCharacteristic;
  bool _responseCanRead = false;
  bool _writeWithResponse = true;
  Completer<String>? _pendingResponse;
  Future<void> _commandQueue = Future<void>.value();
  bool _connected = false;
  String _connectionLabel = 'Disconnected';

  @override
  bool get isConnected => _connected;

  @override
  String get connectionLabel => _connectionLabel;

  @override
  Future<List<ObdAdapter>> scan({
    Duration timeout = const Duration(seconds: 6),
  }) async {
    await _ensureBleReady();
    _scanCache.clear();
    final subscription = _ble
        .scanForDevices(
          withServices: const [],
          scanMode: ScanMode.lowLatency,
          requireLocationServicesEnabled: false,
        )
        .listen((device) {
          if (device.id.trim().isEmpty) {
            return;
          }
          _scanCache[device.id] = device;
        });
    await Future<void>.delayed(timeout);
    await subscription.cancel();
    final adapters = _scanCache.values.map(_adapterFromDevice).toList();
    adapters.sort(_compareAdapters);
    return adapters;
  }

  @override
  Future<void> connect(ObdAdapter adapter) async {
    await disconnect();
    await _ensureBleReady();
    final completer = Completer<void>();
    _connectionLabel = 'Connecting to ${adapter.label}';
    _connectionSubscription = _ble
        .connectToDevice(id: adapter.id, connectionTimeout: _connectTimeout)
        .listen(
          (update) {
            if (update.connectionState == DeviceConnectionState.connected) {
              _connected = true;
              _connectionLabel = 'Connected to ${adapter.label}';
              if (!completer.isCompleted) {
                completer.complete();
              }
            } else if (update.connectionState ==
                DeviceConnectionState.disconnected) {
              _connected = false;
              _connectionLabel = 'Disconnected';
              if (!completer.isCompleted) {
                completer.completeError(
                  StateError('Could not connect to ${adapter.label}.'),
                );
              }
            }
          },
          onError: (Object error) {
            _connected = false;
            _connectionLabel = 'Connection failed';
            if (!completer.isCompleted) {
              completer.completeError(error);
            }
          },
        );

    await completer.future.timeout(_connectTimeout);
    await _resolveSerialChannel(adapter.id);
    await _startElmSession();
  }

  @override
  Future<String> send(
    String command, {
    Duration timeout = const Duration(seconds: 5),
  }) {
    final completer = Completer<String>();
    _commandQueue = _commandQueue.then((_) async {
      try {
        completer.complete(await _sendNow(command, timeout: timeout));
      } catch (error, stackTrace) {
        completer.completeError(error, stackTrace);
      }
    });
    return completer.future;
  }

  @override
  Future<void> disconnect() async {
    await _notifySubscription?.cancel();
    await _connectionSubscription?.cancel();
    _notifySubscription = null;
    _connectionSubscription = null;
    _writeCharacteristic = null;
    _responseCharacteristic = null;
    _responseCanRead = false;
    _writeWithResponse = true;
    _pendingResponse = null;
    _buffer.clear();
    _connected = false;
    _connectionLabel = 'Disconnected';
  }

  Future<void> _ensureBleReady() async {
    var status = _ble.status;
    if (status == BleStatus.unknown) {
      status = await _ble.statusStream
          .firstWhere((value) => value != BleStatus.unknown)
          .timeout(const Duration(seconds: 4), onTimeout: () => _ble.status);
    }
    if (status == BleStatus.ready) {
      return;
    }
    throw StateError(_bleStatusMessage(status));
  }

  Future<void> _resolveSerialChannel(String deviceId) async {
    await _ble.discoverAllServices(deviceId);
    final services = await _ble.getDiscoveredServices(deviceId);
    final channel = _findSerialChannel(services);
    if (channel == null) {
      throw StateError(
        'No writable OBD BLE serial characteristic was found. Use an ELM327 BLE adapter that exposes UART-style GATT characteristics.',
      );
    }
    _writeCharacteristic = channel.write;
    _responseCharacteristic = channel.response;
    _responseCanRead = channel.responseCanRead;
    _writeWithResponse = channel.writeWithResponse;
    if (channel.responseCanNotify) {
      _notifySubscription = channel.response.subscribe().listen(
        _onNotification,
      );
    }
  }

  Future<void> _startElmSession() async {
    for (final command in const [
      'ATZ',
      'ATE0',
      'ATL0',
      'ATS0',
      'ATH0',
      'ATSP0',
    ]) {
      try {
        await send(command, timeout: const Duration(seconds: 4));
      } catch (_) {
        // Some low-cost adapters reject one or more setup commands. The first
        // live PID read still provides the useful connection check.
      }
    }
  }

  Future<String> _sendNow(String command, {required Duration timeout}) async {
    final write = _writeCharacteristic;
    final response = _responseCharacteristic;
    if (!_connected || write == null || response == null) {
      throw StateError('Connect to a BLE OBD adapter first.');
    }

    final normalized = command.trim().toUpperCase();
    _buffer.clear();
    _pendingResponse = Completer<String>();
    final bytes = ascii.encode('$normalized\r');
    if (_writeWithResponse) {
      await write.write(bytes);
    } else {
      await write.write(bytes, withResponse: false);
    }

    if (_notifySubscription != null) {
      return _pendingResponse!.future.timeout(
        timeout,
        onTimeout: () {
          _pendingResponse = null;
          return '';
        },
      );
    }

    if (_responseCanRead) {
      await Future<void>.delayed(const Duration(milliseconds: 250));
      final value = await response.read().timeout(timeout);
      _pendingResponse = null;
      return _cleanElmResponse(
        ascii.decode(value, allowInvalid: true),
        command: normalized,
      );
    }

    _pendingResponse = null;
    return '';
  }

  void _onNotification(List<int> data) {
    final text = ascii.decode(data, allowInvalid: true);
    _buffer.write(text);
    final pending = _pendingResponse;
    if (pending == null || pending.isCompleted) {
      return;
    }
    final current = _buffer.toString();
    if (current.contains('>') ||
        current.toUpperCase().contains('NO DATA') ||
        current.toUpperCase().contains('UNABLE TO CONNECT')) {
      pending.complete(_cleanElmResponse(current));
      _pendingResponse = null;
      _buffer.clear();
    }
  }
}

class _BleSerialChannel {
  const _BleSerialChannel({
    required this.write,
    required this.response,
    required this.writeWithResponse,
    required this.responseCanNotify,
    required this.responseCanRead,
  });

  final Characteristic write;
  final Characteristic response;
  final bool writeWithResponse;
  final bool responseCanNotify;
  final bool responseCanRead;
}

class _DiscoveredCharacteristicRef {
  const _DiscoveredCharacteristicRef({
    required this.service,
    required this.characteristic,
  });

  final Service service;
  final Characteristic characteristic;
}

class LocalObdScreen extends StatefulWidget {
  const LocalObdScreen({super.key, this.bleTransport});

  final ObdTransport? bleTransport;

  @override
  State<LocalObdScreen> createState() => _LocalObdScreenState();
}

class _LocalObdScreenState extends State<LocalObdScreen> {
  late ObdTransport _transport;
  final DemoObdTransport _demoTransport = DemoObdTransport();
  final List<ObdCommandLog> _logs = [];
  final List<ObdAdapter> _adapters = [
    const ObdAdapter(
      id: 'demo-elm327',
      name: 'Demo ELM327 BLE',
      rssi: -42,
      isDemo: true,
    ),
  ];

  Timer? _liveTimer;
  ObdAdapter? _selectedAdapter;
  String? _selectedVehicle = localObdVehiclePresets.first;
  ObdLiveData _liveData = const ObdLiveData();
  ObdFreezeFrame? _freezeFrame;
  List<DiagnosticTroubleCode> _codes = const [];
  String _status = 'Disconnected';
  bool _scanning = false;
  bool _connecting = false;
  bool _readingLiveData = false;
  bool _readingCodes = false;
  bool _readingFreezeFrame = false;
  bool _clearingCodes = false;
  bool _polling = false;

  @override
  void initState() {
    super.initState();
    _transport = widget.bleTransport ?? BleObdTransport();
    _selectedAdapter = _adapters.first;
  }

  @override
  void dispose() {
    _liveTimer?.cancel();
    _transport.disconnect();
    _demoTransport.disconnect();
    super.dispose();
  }

  Future<void> _scan() async {
    setState(() {
      _scanning = true;
      _status = 'Scanning for BLE OBD adapters';
    });
    try {
      final adapters = await _transport.scan();
      if (!mounted) {
        return;
      }
      setState(() {
        _adapters
          ..removeWhere((adapter) => !adapter.isDemo)
          ..addAll(adapters);
        if (adapters.isNotEmpty) {
          _selectedAdapter = adapters.first;
        }
        _status =
            adapters.isEmpty
                ? 'No BLE adapters found'
                : 'Found ${adapters.length} BLE adapter(s)';
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _status = _messageForError(error));
    } finally {
      if (mounted) {
        setState(() => _scanning = false);
      }
    }
  }

  Future<void> _connect() async {
    final adapter = _selectedAdapter;
    if (adapter == null) {
      _showSnack('Select an adapter first.');
      return;
    }
    await _transport.disconnect();
    _liveTimer?.cancel();
    _transport = adapter.isDemo ? _demoTransport : BleObdTransport();
    setState(() {
      _connecting = true;
      _polling = false;
      _status = 'Connecting to ${adapter.label}';
    });
    try {
      await _transport.connect(adapter);
      if (!mounted) {
        return;
      }
      setState(() => _status = _transport.connectionLabel);
      await _readLiveData();
      await _readTroubleCodes();
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _status = _messageForError(error));
    } finally {
      if (mounted) {
        setState(() => _connecting = false);
      }
    }
  }

  Future<void> _disconnect() async {
    _liveTimer?.cancel();
    await _transport.disconnect();
    if (!mounted) {
      return;
    }
    setState(() {
      _polling = false;
      _liveData = const ObdLiveData();
      _freezeFrame = null;
      _status = 'Disconnected';
    });
  }

  Future<void> _readLiveData() async {
    if (!_transport.isConnected) {
      _showSnack('Connect to an adapter first.');
      return;
    }
    setState(() => _readingLiveData = true);
    try {
      final data = ObdLiveData(
        rpm: parseObdPidValue(await _safeCommand('010C'), '0C'),
        speedKmh: parseObdPidValue(await _safeCommand('010D'), '0D'),
        coolantTempC: parseObdPidValue(await _safeCommand('0105'), '05'),
        engineLoadPercent: parseObdPidValue(await _safeCommand('0104'), '04'),
        intakeTempC: parseObdPidValue(await _safeCommand('010F'), '0F'),
        throttlePercent: parseObdPidValue(await _safeCommand('0111'), '11'),
        mafGramsPerSecond: parseObdPidValue(await _safeCommand('0110'), '10'),
        fuelLevelPercent: parseObdPidValue(await _safeCommand('012F'), '2F'),
        controlVoltage: parseObdPidValue(await _safeCommand('0142'), '42'),
      );
      if (mounted) {
        setState(() => _liveData = data);
      }
    } finally {
      if (mounted) {
        setState(() => _readingLiveData = false);
      }
    }
  }

  Future<void> _readTroubleCodes() async {
    if (!_transport.isConnected) {
      _showSnack('Connect to an adapter first.');
      return;
    }
    setState(() => _readingCodes = true);
    try {
      final stored = parseDiagnosticTroubleCodes(
        await _safeCommand('03'),
        status: 'Stored',
      );
      final pending = parseDiagnosticTroubleCodes(
        await _safeCommand('07'),
        status: 'Pending',
      );
      if (mounted) {
        setState(() => _codes = [...stored, ...pending]);
      }
    } finally {
      if (mounted) {
        setState(() => _readingCodes = false);
      }
    }
  }

  Future<void> _readFreezeFrame() async {
    if (!_transport.isConnected) {
      _showSnack('Connect to an adapter first.');
      return;
    }
    setState(() => _readingFreezeFrame = true);
    try {
      final triggerResponse = await _safeCommand('0202');
      final trigger = parseFreezeFrameTroubleCode(triggerResponse);
      final frame = ObdFreezeFrame(
        triggerCode: trigger,
        data: ObdLiveData(
          rpm: parseObdPidValue(await _safeCommand('020C'), '0C', mode: '42'),
          speedKmh: parseObdPidValue(
            await _safeCommand('020D'),
            '0D',
            mode: '42',
          ),
          coolantTempC: parseObdPidValue(
            await _safeCommand('0205'),
            '05',
            mode: '42',
          ),
          engineLoadPercent: parseObdPidValue(
            await _safeCommand('0204'),
            '04',
            mode: '42',
          ),
          intakeTempC: parseObdPidValue(
            await _safeCommand('020F'),
            '0F',
            mode: '42',
          ),
          throttlePercent: parseObdPidValue(
            await _safeCommand('0211'),
            '11',
            mode: '42',
          ),
          mafGramsPerSecond: parseObdPidValue(
            await _safeCommand('0210'),
            '10',
            mode: '42',
          ),
          fuelLevelPercent: parseObdPidValue(
            await _safeCommand('022F'),
            '2F',
            mode: '42',
          ),
          controlVoltage: parseObdPidValue(
            await _safeCommand('0242'),
            '42',
            mode: '42',
          ),
        ),
      );
      if (mounted) {
        setState(() => _freezeFrame = frame);
      }
    } finally {
      if (mounted) {
        setState(() => _readingFreezeFrame = false);
      }
    }
  }

  Future<void> _clearTroubleCodes() async {
    if (!_transport.isConnected) {
      _showSnack('Connect to an adapter first.');
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Clear trouble codes?'),
          content: const Text(
            'This sends local OBD mode 04 to the connected adapter. Record codes and freeze-frame data before clearing.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Clear'),
            ),
          ],
        );
      },
    );
    if (confirmed != true) {
      return;
    }
    setState(() => _clearingCodes = true);
    try {
      await _safeCommand('04');
      if (!mounted) {
        return;
      }
      setState(() => _codes = const []);
      _showSnack('Trouble codes cleared locally.');
    } finally {
      if (mounted) {
        setState(() => _clearingCodes = false);
      }
    }
  }

  void _togglePolling() {
    if (!_transport.isConnected) {
      _showSnack('Connect to an adapter first.');
      return;
    }
    if (_polling) {
      _liveTimer?.cancel();
      setState(() => _polling = false);
      return;
    }
    _liveTimer?.cancel();
    _liveTimer = Timer.periodic(
      const Duration(seconds: 3),
      (_) => _readLiveData(),
    );
    setState(() => _polling = true);
    _readLiveData();
  }

  Future<String> _safeCommand(String command) async {
    try {
      final response = await _transport.send(command);
      _appendLog(command, response);
      return response;
    } catch (error) {
      _appendLog(command, _messageForError(error));
      return '';
    }
  }

  void _appendLog(String command, String response) {
    if (!mounted) {
      return;
    }
    setState(() {
      _logs.insert(
        0,
        ObdCommandLog(
          command: command.toUpperCase(),
          response: response.trim().isEmpty ? 'No response' : response.trim(),
          timestamp: DateTime.now(),
        ),
      );
      if (_logs.length > 12) {
        _logs.removeRange(12, _logs.length);
      }
    });
  }

  void _showSnack(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final colors = MotornautsThemeColors.of(context);
    final connected = _transport.isConnected;
    return Scaffold(
      appBar: AppBar(title: const Text('Local OBD utility')),
      body: _ObdListView(
        children: [
          _ObdHeader(
            title: 'OBD diagnostics',
            subtitle:
                'Local BLE adapter utility. Readings stay on this device.',
            trailing: _LocalBadge(connected ? 'Connected' : 'Local only'),
          ),
          _ObdCard(
            title: 'Adapter',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _StatusLine(
                  icon:
                      connected
                          ? Icons.bluetooth_connected
                          : Icons.bluetooth_searching,
                  text: _status,
                  color: connected ? colors.success : colors.textSecondary,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<ObdAdapter>(
                  key: ValueKey(_selectedAdapter?.id ?? 'no-obd-adapter'),
                  initialValue: _selectedAdapter,
                  decoration: const InputDecoration(labelText: 'Adapter'),
                  items: [
                    for (final adapter in _adapters)
                      DropdownMenuItem<ObdAdapter>(
                        value: adapter,
                        child: Text(
                          adapter.rssi == null
                              ? adapter.label
                              : '${adapter.label} (${adapter.rssi} dBm)',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                  onChanged:
                      connected || _connecting
                          ? null
                          : (value) => setState(() => _selectedAdapter = value),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    OutlinedButton.icon(
                      onPressed: connected || _scanning ? null : _scan,
                      icon:
                          _scanning
                              ? const _SmallProgress()
                              : const Icon(Icons.bluetooth_searching),
                      label: const Text('Scan BLE'),
                    ),
                    FilledButton.icon(
                      onPressed:
                          _connecting
                              ? null
                              : (connected ? _disconnect : _connect),
                      icon:
                          _connecting
                              ? const _SmallProgress()
                              : Icon(connected ? Icons.link_off : Icons.cable),
                      label: Text(connected ? 'Disconnect' : 'Connect'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          _ObdCard(
            title: 'Vehicle',
            child: DropdownButtonFormField<String>(
              initialValue: _selectedVehicle,
              decoration: const InputDecoration(
                labelText: 'Local vehicle profile',
              ),
              items: [
                for (final vehicle in localObdVehiclePresets)
                  DropdownMenuItem<String>(
                    value: vehicle,
                    child: Text(vehicle),
                  ),
              ],
              onChanged: (value) => setState(() => _selectedVehicle = value),
            ),
          ),
          _ObdCard(
            title: 'Live data',
            child: Column(
              children: [
                _LiveDataGrid(data: _liveData),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _readingLiveData ? null : _readLiveData,
                        icon:
                            _readingLiveData
                                ? const _SmallProgress()
                                : const Icon(Icons.refresh),
                        label: const Text('Refresh once'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: _togglePolling,
                        icon: Icon(_polling ? Icons.pause : Icons.play_arrow),
                        label: Text(_polling ? 'Stop live' : 'Start live'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          _ObdCard(
            title: 'Trouble codes',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _readingCodes ? null : _readTroubleCodes,
                        icon:
                            _readingCodes
                                ? const _SmallProgress()
                                : const Icon(Icons.manage_search),
                        label: const Text('Read codes'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: _clearingCodes ? null : _clearTroubleCodes,
                        icon:
                            _clearingCodes
                                ? const _SmallProgress()
                                : const Icon(Icons.cleaning_services_outlined),
                        label: const Text('Clear'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (_codes.isEmpty)
                  _StatusLine(
                    icon: Icons.check_circle_outline,
                    text: 'No stored or pending codes read in this session.',
                    color: colors.success,
                  )
                else
                  for (final code in _codes)
                    _DtcTile(code: code, onTap: () => _showDtcDetails(code)),
              ],
            ),
          ),
          _ObdCard(
            title: 'Freeze frame',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                OutlinedButton.icon(
                  onPressed: _readingFreezeFrame ? null : _readFreezeFrame,
                  icon:
                      _readingFreezeFrame
                          ? const _SmallProgress()
                          : const Icon(Icons.camera_alt_outlined),
                  label: const Text('Read freeze frame'),
                ),
                const SizedBox(height: 12),
                if (_freezeFrame == null)
                  Text(
                    'Freeze-frame data is requested from mode 02 and kept only in this session.',
                    style: Theme.of(context).textTheme.bodySmall,
                  )
                else ...[
                  _StatusLine(
                    icon: Icons.flag_outlined,
                    text:
                        _freezeFrame!.triggerCode == null
                            ? 'Trigger code unavailable'
                            : 'Trigger code ${_freezeFrame!.triggerCode}',
                    color: colors.warning,
                  ),
                  const SizedBox(height: 12),
                  _LiveDataGrid(data: _freezeFrame!.data, compact: true),
                ],
              ],
            ),
          ),
          _ObdCard(
            title: 'Session log',
            child:
                _logs.isEmpty
                    ? Text(
                      'Commands and responses from this local session will appear here.',
                      style: Theme.of(context).textTheme.bodySmall,
                    )
                    : Column(
                      children: [
                        for (final log in _logs) _CommandLogTile(log: log),
                      ],
                    ),
          ),
        ],
      ),
    );
  }

  void _showDtcDetails(DiagnosticTroubleCode code) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  code.code,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 4),
                Text(code.description),
                const SizedBox(height: 16),
                Text(
                  'Local repair checks',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                for (final hint in code.repairHints)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.check_circle_outline, size: 18),
                        const SizedBox(width: 8),
                        Expanded(child: Text(hint)),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

double? parseObdPidValue(String response, String pid, {String mode = '41'}) {
  final bytes = _pidPayload(response, mode, pid);
  if (bytes.isEmpty) {
    return null;
  }
  final normalizedPid = pid.toUpperCase();
  switch (normalizedPid) {
    case '04':
      return bytes.isNotEmpty ? bytes[0] * 100 / 255 : null;
    case '05':
      return bytes.isNotEmpty ? bytes[0] - 40.0 : null;
    case '0C':
      return bytes.length >= 2 ? ((bytes[0] * 256) + bytes[1]) / 4 : null;
    case '0D':
      return bytes.isNotEmpty ? bytes[0].toDouble() : null;
    case '0F':
      return bytes.isNotEmpty ? bytes[0] - 40.0 : null;
    case '10':
      return bytes.length >= 2 ? ((bytes[0] * 256) + bytes[1]) / 100 : null;
    case '11':
      return bytes.isNotEmpty ? bytes[0] * 100 / 255 : null;
    case '2F':
      return bytes.isNotEmpty ? bytes[0] * 100 / 255 : null;
    case '42':
      return bytes.length >= 2 ? ((bytes[0] * 256) + bytes[1]) / 1000 : null;
  }
  return null;
}

List<DiagnosticTroubleCode> parseDiagnosticTroubleCodes(
  String response, {
  String status = 'Stored',
}) {
  final tokens = _hexTokens(response);
  final header = status.toLowerCase().contains('pending') ? '47' : '43';
  var start = tokens.indexOf(header);
  if (start < 0) {
    start = tokens.indexOf('4A');
  }
  if (start < 0 || _containsNoData(response)) {
    return const [];
  }
  final codes = <DiagnosticTroubleCode>[];
  for (var index = start + 1; index + 1 < tokens.length; index += 2) {
    final first = int.tryParse(tokens[index], radix: 16);
    final second = int.tryParse(tokens[index + 1], radix: 16);
    if (first == null || second == null || (first == 0 && second == 0)) {
      continue;
    }
    final code = decodeRawDtcBytes(first, second);
    codes.add(
      DiagnosticTroubleCode(
        code: code,
        status: status,
        description:
            obdDtcDescriptions[code] ?? 'No local description available',
      ),
    );
  }
  return codes;
}

String decodeRawDtcBytes(int first, int second) {
  const systems = ['P', 'C', 'B', 'U'];
  final system = systems[(first & 0xC0) >> 6];
  final digit1 = ((first & 0x30) >> 4).toString();
  final digit2 = (first & 0x0F).toRadixString(16).toUpperCase();
  final lastTwo = second.toRadixString(16).padLeft(2, '0').toUpperCase();
  return '$system$digit1$digit2$lastTwo';
}

String? parseFreezeFrameTroubleCode(String response) {
  final payload = _pidPayload(response, '42', '02');
  if (payload.length < 2 || (payload[0] == 0 && payload[1] == 0)) {
    return null;
  }
  return decodeRawDtcBytes(payload[0], payload[1]);
}

Future<void> initializeElmAdapter(ObdTransport transport) async {
  for (final command in const [
    'ATZ',
    'ATE0',
    'ATL0',
    'ATS0',
    'ATH0',
    'ATSP0',
  ]) {
    await transport.send(command, timeout: const Duration(seconds: 4));
  }
}

List<int> _pidPayload(String response, String mode, String pid) {
  if (_containsNoData(response)) {
    return const [];
  }
  final tokens = _hexTokens(response);
  final normalizedMode = mode.toUpperCase();
  final normalizedPid = pid.toUpperCase();
  for (var index = 0; index + 1 < tokens.length; index += 1) {
    if (tokens[index] == normalizedMode && tokens[index + 1] == normalizedPid) {
      return tokens
          .skip(index + 2)
          .map((token) => int.tryParse(token, radix: 16))
          .whereType<int>()
          .toList();
    }
  }
  return const [];
}

List<String> _hexTokens(String response) {
  return RegExp(
    r'[0-9A-Fa-f]{2}',
  ).allMatches(response.toUpperCase()).map((match) => match.group(0)!).toList();
}

bool _containsNoData(String response) {
  final upper = response.toUpperCase();
  return upper.contains('NO DATA') ||
      upper.contains('UNABLE TO CONNECT') ||
      upper.contains('STOPPED') ||
      upper.contains('?');
}

String _cleanElmResponse(String response, {String? command}) {
  var clean =
      response
          .replaceAll('\r', ' ')
          .replaceAll('\n', ' ')
          .replaceAll('>', ' ')
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();
  if (command != null &&
      clean.toUpperCase().startsWith(command.toUpperCase())) {
    clean = clean.substring(command.length).trim();
  }
  return clean;
}

String _bleStatusMessage(BleStatus status) {
  return switch (status) {
    BleStatus.ready => 'Bluetooth is ready.',
    BleStatus.unsupported => 'Bluetooth LE is not supported on this device.',
    BleStatus.unauthorized =>
      'Bluetooth permission is not granted for this app.',
    BleStatus.poweredOff => 'Bluetooth is turned off.',
    BleStatus.locationServicesDisabled =>
      'Location services are disabled. Android may require them for BLE scans.',
    BleStatus.unknown => 'Bluetooth status is not ready yet.',
  };
}

ObdAdapter _adapterFromDevice(DiscoveredDevice device) {
  return ObdAdapter(
    id: device.id,
    name:
        device.name.trim().isEmpty
            ? 'BLE adapter ${_shortId(device.id)}'
            : device.name.trim(),
    rssi: device.rssi,
  );
}

int _compareAdapters(ObdAdapter left, ObdAdapter right) {
  final rankCompare = _adapterRank(right).compareTo(_adapterRank(left));
  if (rankCompare != 0) {
    return rankCompare;
  }
  return (right.rssi ?? -999).compareTo(left.rssi ?? -999);
}

int _adapterRank(ObdAdapter adapter) {
  final value = '${adapter.name} ${adapter.id}'.toLowerCase();
  if (value.contains('obd') ||
      value.contains('elm') ||
      value.contains('vlink')) {
    return 3;
  }
  if (value.contains('car') || value.contains('ble')) {
    return 2;
  }
  return 1;
}

String _shortId(String id) {
  if (id.length <= 8) {
    return id;
  }
  return id.substring(id.length - 8);
}

String _hexByte(int value) =>
    value.clamp(0, 255).toRadixString(16).padLeft(2, '0').toUpperCase();

_BleSerialChannel? _findSerialChannel(List<Service> services) {
  final refs = <_DiscoveredCharacteristicRef>[
    for (final service in services)
      for (final characteristic in service.characteristics)
        _DiscoveredCharacteristicRef(
          service: service,
          characteristic: characteristic,
        ),
  ];
  if (refs.isEmpty) {
    return null;
  }

  final known = _knownSerialPairs(refs);
  if (known != null) {
    return known._toChannel();
  }

  _DiscoveredCharacteristicRef? write;
  _DiscoveredCharacteristicRef? response;
  for (final ref in refs) {
    final characteristic = ref.characteristic;
    final canWrite =
        characteristic.isWritableWithResponse ||
        characteristic.isWritableWithoutResponse;
    final canRespond =
        characteristic.isNotifiable ||
        characteristic.isIndicatable ||
        characteristic.isReadable;
    if (canWrite && canRespond) {
      return _BleSerialChannel(
        write: ref.characteristic,
        response: ref.characteristic,
        writeWithResponse: characteristic.isWritableWithResponse,
        responseCanNotify:
            characteristic.isNotifiable || characteristic.isIndicatable,
        responseCanRead: characteristic.isReadable,
      );
    }
    write ??= canWrite ? ref : null;
    response ??= canRespond ? ref : null;
  }
  if (write == null || response == null) {
    return null;
  }
  return _BleSerialChannel(
    write: write.characteristic,
    response: response.characteristic,
    writeWithResponse: write.characteristic.isWritableWithResponse,
    responseCanNotify:
        response.characteristic.isNotifiable ||
        response.characteristic.isIndicatable,
    responseCanRead: response.characteristic.isReadable,
  );
}

_KnownSerialPair? _knownSerialPairs(List<_DiscoveredCharacteristicRef> refs) {
  _DiscoveredCharacteristicRef? find(String service, String characteristic) {
    final serviceUuid = Uuid.parse(service).expanded.toString();
    final charUuid = Uuid.parse(characteristic).expanded.toString();
    for (final ref in refs) {
      if (ref.service.id.expanded.toString() == serviceUuid &&
          ref.characteristic.id.expanded.toString() == charUuid) {
        return ref;
      }
    }
    return null;
  }

  final ffe1 = find('ffe0', 'ffe1');
  if (ffe1 != null) {
    return _KnownSerialPair(write: ffe1, response: ffe1);
  }
  final fff1 = find('fff0', 'fff1');
  final fff2 = find('fff0', 'fff2');
  if (fff1 != null) {
    return _KnownSerialPair(write: fff1, response: fff2 ?? fff1);
  }
  final nordicRx = find(
    '6e400001-b5a3-f393-e0a9-e50e24dcca9e',
    '6e400002-b5a3-f393-e0a9-e50e24dcca9e',
  );
  final nordicTx = find(
    '6e400001-b5a3-f393-e0a9-e50e24dcca9e',
    '6e400003-b5a3-f393-e0a9-e50e24dcca9e',
  );
  if (nordicRx != null && nordicTx != null) {
    return _KnownSerialPair(write: nordicRx, response: nordicTx);
  }
  return null;
}

class _KnownSerialPair {
  const _KnownSerialPair({required this.write, required this.response});

  final _DiscoveredCharacteristicRef write;
  final _DiscoveredCharacteristicRef response;

  _BleSerialChannel _toChannel() {
    return _BleSerialChannel(
      write: write.characteristic,
      response: response.characteristic,
      writeWithResponse: write.characteristic.isWritableWithResponse,
      responseCanNotify:
          response.characteristic.isNotifiable ||
          response.characteristic.isIndicatable,
      responseCanRead: response.characteristic.isReadable,
    );
  }
}

String _messageForError(Object error) {
  final text = error.toString();
  if (text.startsWith('Exception: ')) {
    return text.substring('Exception: '.length);
  }
  if (text.startsWith('Bad state: ')) {
    return text.substring('Bad state: '.length);
  }
  return text;
}

class _ObdListView extends StatelessWidget {
  const _ObdListView({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: children,
          ),
        ),
      ),
    );
  }
}

class _ObdHeader extends StatelessWidget {
  const _ObdHeader({
    required this.title,
    required this.subtitle,
    required this.trailing,
  });

  final String title;
  final String subtitle;
  final Widget trailing;

  @override
  Widget build(BuildContext context) {
    final colors = MotornautsThemeColors.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: colors.textSecondary),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          trailing,
        ],
      ),
    );
  }
}

class _ObdCard extends StatelessWidget {
  const _ObdCard({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 10),
              child,
            ],
          ),
        ),
      ),
    );
  }
}

class _LocalBadge extends StatelessWidget {
  const _LocalBadge(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final colors = MotornautsThemeColors.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: colors.accentSubtle,
        border: Border.all(color: colors.borderDefault),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        text,
        style: Theme.of(
          context,
        ).textTheme.labelMedium?.copyWith(color: colors.accent),
      ),
    );
  }
}

class _StatusLine extends StatelessWidget {
  const _StatusLine({
    required this.icon,
    required this.text,
    required this.color,
  });

  final IconData icon;
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: color),
        const SizedBox(width: 8),
        Expanded(child: Text(text)),
      ],
    );
  }
}

class _LiveDataGrid extends StatelessWidget {
  const _LiveDataGrid({required this.data, this.compact = false});

  final ObdLiveData data;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final metrics = [
      _MetricValue('RPM', _number(data.rpm, fractionDigits: 0), Icons.speed),
      _MetricValue(
        'Speed',
        _number(data.speedKmh, suffix: ' km/h', fractionDigits: 0),
        Icons.route_outlined,
      ),
      _MetricValue(
        'Coolant',
        _number(data.coolantTempC, suffix: ' C', fractionDigits: 0),
        Icons.thermostat,
      ),
      _MetricValue(
        'Load',
        _number(data.engineLoadPercent, suffix: '%', fractionDigits: 0),
        Icons.av_timer,
      ),
      _MetricValue(
        'Intake',
        _number(data.intakeTempC, suffix: ' C', fractionDigits: 0),
        Icons.air,
      ),
      _MetricValue(
        'Throttle',
        _number(data.throttlePercent, suffix: '%', fractionDigits: 0),
        Icons.tune,
      ),
      _MetricValue(
        'MAF',
        _number(data.mafGramsPerSecond, suffix: ' g/s', fractionDigits: 1),
        Icons.compress,
      ),
      _MetricValue(
        'Fuel',
        _number(data.fuelLevelPercent, suffix: '%', fractionDigits: 0),
        Icons.local_gas_station_outlined,
      ),
      _MetricValue(
        'Voltage',
        _number(data.controlVoltage, suffix: ' V', fractionDigits: 1),
        Icons.electric_bolt_outlined,
      ),
    ];
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: compact ? 6 : metrics.length,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: MediaQuery.sizeOf(context).width < 420 ? 2 : 3,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        childAspectRatio: compact ? 1.8 : 1.45,
      ),
      itemBuilder: (context, index) => _MetricTile(metric: metrics[index]),
    );
  }
}

class _MetricValue {
  const _MetricValue(this.label, this.value, this.icon);

  final String label;
  final String value;
  final IconData icon;
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({required this.metric});

  final _MetricValue metric;

  @override
  Widget build(BuildContext context) {
    final colors = MotornautsThemeColors.of(context);
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: colors.elevated,
        border: Border.all(color: colors.borderDefault),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Icon(metric.icon, size: 18, color: colors.accent),
          Text(
            metric.value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          Text(metric.label, style: Theme.of(context).textTheme.labelMedium),
        ],
      ),
    );
  }
}

class _DtcTile extends StatelessWidget {
  const _DtcTile({required this.code, required this.onTap});

  final DiagnosticTroubleCode code;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = MotornautsThemeColors.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 10),
        tileColor: colors.elevated,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(color: colors.borderDefault),
        ),
        leading: Icon(Icons.warning_amber_rounded, color: colors.warning),
        title: Text('${code.code} - ${code.status}'),
        subtitle: Text(code.description),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}

class _CommandLogTile extends StatelessWidget {
  const _CommandLogTile({required this.log});

  final ObdCommandLog log;

  @override
  Widget build(BuildContext context) {
    final colors = MotornautsThemeColors.of(context);
    final time =
        '${log.timestamp.hour.toString().padLeft(2, '0')}:${log.timestamp.minute.toString().padLeft(2, '0')}:${log.timestamp.second.toString().padLeft(2, '0')}';
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: colors.elevated,
        border: Border.all(color: colors.borderDefault),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$time  ${log.command}',
            style: Theme.of(context).textTheme.labelMedium,
          ),
          const SizedBox(height: 4),
          Text(log.response, maxLines: 3, overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }
}

class _SmallProgress extends StatelessWidget {
  const _SmallProgress();

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: 16,
      child: CircularProgressIndicator(
        strokeWidth: 2,
        color: IconTheme.of(context).color,
      ),
    );
  }
}

String _number(double? value, {String suffix = '', int fractionDigits = 1}) {
  if (value == null) {
    return '--';
  }
  return '${value.toStringAsFixed(fractionDigits)}$suffix';
}
