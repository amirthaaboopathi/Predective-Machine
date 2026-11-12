// ignore_for_file: non_constant_identifier_names

import 'dart:async';
import 'dart:convert';
import 'dart:ffi';
import 'dart:io';
import 'package:ffi/ffi.dart';
import 'package:flutter/foundation.dart';
import '../models/hardware_telemetry_model.dart';
import 'hardware_mapping_service.dart';
import 'sensor_service.dart';
import 'appliance_service.dart';

enum HardwareConnectionStatus {
  disconnected,
  connecting,
  connected,
  simulated,
  error,
}

// =============================================================================
// Win32 FFI Bindings for Kernel32.dll Serial Port
// =============================================================================

final class _DCB extends Struct {
  @Uint32()
  external int DCBlength;
  @Uint32()
  external int BaudRate;
  @Uint32()
  external int flags;
  @Uint16()
  external int wReserved;
  @Uint16()
  external int XonLim;
  @Uint16()
  external int XoffLim;
  @Uint8()
  external int ByteSize;
  @Uint8()
  external int Parity;
  @Uint8()
  external int StopBits;
  @Uint8()
  external int XonChar;
  @Uint8()
  external int XoffChar;
  @Uint8()
  external int ErrorChar;
  @Uint8()
  external int EofChar;
  @Uint8()
  external int EvtChar;
  @Uint16()
  external int wReserved1;
}

final class _COMMTIMEOUTS extends Struct {
  @Uint32()
  external int ReadIntervalTimeout;
  @Uint32()
  external int ReadTotalTimeoutMultiplier;
  @Uint32()
  external int ReadTotalTimeoutConstant;
  @Uint32()
  external int WriteTotalTimeoutMultiplier;
  @Uint32()
  external int WriteTotalTimeoutConstant;
}

typedef _CreateFileNative = IntPtr Function(
  Pointer<Utf16> lpFileName,
  Uint32 dwDesiredAccess,
  Uint32 dwShareMode,
  Pointer<Void> lpSecurityAttributes,
  Uint32 dwCreationDisposition,
  Uint32 dwFlagsAndAttributes,
  IntPtr hTemplateFile,
);
typedef _CreateFileDart = int Function(
  Pointer<Utf16> lpFileName,
  int dwDesiredAccess,
  int dwShareMode,
  Pointer<Void> lpSecurityAttributes,
  int dwCreationDisposition,
  int dwFlagsAndAttributes,
  int hTemplateFile,
);

typedef _CloseHandleNative = Int32 Function(IntPtr hObject);
typedef _CloseHandleDart = int Function(int hObject);

typedef _ReadFileNative = Int32 Function(
  IntPtr hFile,
  Pointer<Uint8> lpBuffer,
  Uint32 nNumberOfBytesToRead,
  Pointer<Uint32> lpNumberOfBytesRead,
  Pointer<Void> lpOverlapped,
);
typedef _ReadFileDart = int Function(
  int hFile,
  Pointer<Uint8> lpBuffer,
  int nNumberOfBytesToRead,
  Pointer<Uint32> lpNumberOfBytesRead,
  Pointer<Void> lpOverlapped,
);

typedef _WriteFileNative = Int32 Function(
  IntPtr hFile,
  Pointer<Uint8> lpBuffer,
  Uint32 nNumberOfBytesToWrite,
  Pointer<Uint32> lpNumberOfBytesWritten,
  Pointer<Void> lpOverlapped,
);
typedef _WriteFileDart = int Function(
  int hFile,
  Pointer<Uint8> lpBuffer,
  int nNumberOfBytesToWrite,
  Pointer<Uint32> lpNumberOfBytesWritten,
  Pointer<Void> lpOverlapped,
);

typedef _SetCommStateNative = Int32 Function(IntPtr hFile, Pointer<_DCB> lpDCB);
typedef _SetCommStateDart = int Function(int hFile, Pointer<_DCB> lpDCB);

typedef _GetCommStateNative = Int32 Function(IntPtr hFile, Pointer<_DCB> lpDCB);
typedef _GetCommStateDart = int Function(int hFile, Pointer<_DCB> lpDCB);

typedef _SetCommTimeoutsNative = Int32 Function(IntPtr hFile, Pointer<_COMMTIMEOUTS> lpCommTimeouts);
typedef _SetCommTimeoutsDart = int Function(int hFile, Pointer<_COMMTIMEOUTS> lpCommTimeouts);

typedef _PurgeCommNative = Int32 Function(IntPtr hFile, Uint32 dwFlags);
typedef _PurgeCommDart = int Function(int hFile, int dwFlags);

/// Core hardware manager connecting to Arduino/ESP32 via Serial COM port (e.g. COM3 @ 115200 baud).
///
/// Features:
/// 1. Direct Win32 serial communication with kernel32.dll
/// 2. Parsing of Arduino JSON mode output (MPU6050, DS18B20, INMP441, Relay)
/// 3. Two-way hardware control (RELAY_ON, RELAY_OFF, RELAY_TOGGLE, START, STOP, STATUS)
/// 4. Strict 1-appliance-per-device routing via HardwareMappingService
/// 5. Throttled cloud persistence into Supabase public.sensor_readings
/// 6. Realistic simulation fallback when hardware is disconnected
class HardwareSerialService extends ChangeNotifier {
  static final HardwareSerialService _instance = HardwareSerialService._internal();
  factory HardwareSerialService() => _instance;
  HardwareSerialService._internal() {
    _initWin32();
  }

  // Active configuration
  String _activePort = 'COM3';
  final int _baudRate = 115200;
  bool _autoSyncToCloud = true;
  int _cloudSyncIntervalSeconds = 5;

  // Connection State
  HardwareConnectionStatus _status = HardwareConnectionStatus.disconnected;
  String? _lastErrorMessage;
  int _totalPacketsReceived = 0;
  DateTime? _lastPacketTime;

  // Hardware state
  bool _hardwareRelayState = false;
  HardwareTelemetryModel? _latestTelemetry;
  final StreamController<HardwareTelemetryModel> _telemetryStreamController =
      StreamController<HardwareTelemetryModel>.broadcast();

  // Internal Win32 handles
  DynamicLibrary? _kernel32;
  _CreateFileDart? _createFile;
  _CloseHandleDart? _closeHandle;
  _ReadFileDart? _readFile;
  _WriteFileDart? _writeFile;
  _GetCommStateDart? _getCommState;
  _SetCommStateDart? _setCommState;
  _SetCommTimeoutsDart? _setCommTimeouts;
  _PurgeCommDart? _purgeComm;

  int _portHandle = -1;
  Timer? _pollingTimer;
  Timer? _simulationTimer;
  Timer? _cloudSyncTimer;

  // Stream parsing buffer
  final StringBuffer _rxBuffer = StringBuffer();

  // Getters
  String get activePort => _activePort;
  int get baudRate => _baudRate;
  HardwareConnectionStatus get status => _status;
  bool get isConnected => _status == HardwareConnectionStatus.connected;
  bool get isSimulated => _status == HardwareConnectionStatus.simulated;
  bool get isActive => isConnected || isSimulated;
  String? get lastErrorMessage => _lastErrorMessage;
  int get totalPacketsReceived => _totalPacketsReceived;
  DateTime? get lastPacketTime => _lastPacketTime;
  bool get relayState => _hardwareRelayState;
  HardwareTelemetryModel? get latestTelemetry => _latestTelemetry;
  Stream<HardwareTelemetryModel> get telemetryStream => _telemetryStreamController.stream;
  bool get autoSyncToCloud => _autoSyncToCloud;
  int get cloudSyncIntervalSeconds => _cloudSyncIntervalSeconds;

  void _initWin32() {
    if (!Platform.isWindows) return;
    try {
      _kernel32 = DynamicLibrary.open('kernel32.dll');
      _createFile = _kernel32!.lookupFunction<_CreateFileNative, _CreateFileDart>('CreateFileW');
      _closeHandle = _kernel32!.lookupFunction<_CloseHandleNative, _CloseHandleDart>('CloseHandle');
      _readFile = _kernel32!.lookupFunction<_ReadFileNative, _ReadFileDart>('ReadFile');
      _writeFile = _kernel32!.lookupFunction<_WriteFileNative, _WriteFileDart>('WriteFile');
      _getCommState = _kernel32!.lookupFunction<_GetCommStateNative, _GetCommStateDart>('GetCommState');
      _setCommState = _kernel32!.lookupFunction<_SetCommStateNative, _SetCommStateDart>('SetCommState');
      _setCommTimeouts =
          _kernel32!.lookupFunction<_SetCommTimeoutsNative, _SetCommTimeoutsDart>('SetCommTimeouts');
      _purgeComm = _kernel32!.lookupFunction<_PurgeCommNative, _PurgeCommDart>('PurgeComm');
    } catch (e) {
      debugPrint('Failed to load kernel32 Win32 bindings: $e');
    }
  }

  /// Scans Windows for available physical and virtual COM ports.
  Future<List<String>> scanAvailablePorts() async {
    final List<String> ports = [];
    if (!Platform.isWindows) return ['COM3'];

    try {
      final result = await Process.run(
        'powershell',
        ['-NoProfile', '-Command', '[System.IO.Ports.SerialPort]::getportnames()'],
      );
      if (result.exitCode == 0) {
        final lines = (result.stdout as String).split(RegExp(r'[\r\n]+'));
        for (final line in lines) {
          final trimmed = line.trim().toUpperCase();
          if (trimmed.startsWith('COM') && !ports.contains(trimmed)) {
            ports.add(trimmed);
          }
        }
      }
    } catch (e) {
      debugPrint('Error scanning COM ports: $e');
    }

    if (!ports.contains('COM3')) {
      ports.insert(0, 'COM3');
    }
    return ports;
  }

  /// Changes the target COM port (e.g. COM3, COM4).
  void setActivePort(String port) {
    if (_activePort != port.toUpperCase().trim()) {
      _activePort = port.toUpperCase().trim();
      notifyListeners();
      if (isConnected) {
        disconnect();
        connect();
      }
    }
  }

  /// Toggles automatic cloud telemetry saving to Supabase.
  void setAutoSyncToCloud(bool value) {
    _autoSyncToCloud = value;
    notifyListeners();
  }

  /// Sets cloud sync interval.
  void setCloudSyncInterval(int seconds) {
    _cloudSyncIntervalSeconds = seconds.clamp(1, 60);
    notifyListeners();
  }

  /// Initiates connection to the hardware device on the active port (COM3).
  Future<bool> connect([String? portName]) async {
    if (portName != null && portName.isNotEmpty) {
      _activePort = portName.toUpperCase().trim();
    }

    _stopSimulation();
    _status = HardwareConnectionStatus.connecting;
    _lastErrorMessage = null;
    notifyListeners();

    if (!Platform.isWindows || _createFile == null) {
      debugPrint('Non-Windows platform or Win32 unavailable; starting simulation mode.');
      startSimulation();
      return true;
    }

    try {
      final comPath = r'\\.\' + _activePort;
      final portNameUtf16 = comPath.toNativeUtf16();

      // GENERIC_READ | GENERIC_WRITE = 0xC0000000
      // OPEN_EXISTING = 3
      final handle = _createFile!(
        portNameUtf16,
        0xC0000000,
        0, // Exclusive access
        nullptr,
        3, // OPEN_EXISTING
        0,
        0,
      );
      calloc.free(portNameUtf16);

      if (handle == -1 || handle == 0xFFFFFFFFFFFFFFFF || handle == 0xFFFFFFFF) {
        throw Exception(
          'Could not open $_activePort. Ensure your ESP32 is plugged in and no other program (such as Arduino Serial Monitor) has the port open.',
        );
      }

      _portHandle = handle;

      // Configure DCB (Baud Rate, Data bits, Stop bits, Parity)
      final dcbPtr = calloc<_DCB>();
      dcbPtr.ref.DCBlength = sizeOf<_DCB>();

      if (_getCommState!(_portHandle, dcbPtr) != 0) {
        dcbPtr.ref.BaudRate = _baudRate;
        dcbPtr.ref.ByteSize = 8;
        dcbPtr.ref.Parity = 0; // NOPARITY
        dcbPtr.ref.StopBits = 0; // ONESTOPBIT
        dcbPtr.ref.flags = 0x0001; // fBinary
        _setCommState!(_portHandle, dcbPtr);
      }
      calloc.free(dcbPtr);

      // Configure Comm Timeouts (non-blocking reads with 20ms timeout)
      final timeoutsPtr = calloc<_COMMTIMEOUTS>();
      timeoutsPtr.ref.ReadIntervalTimeout = 50;
      timeoutsPtr.ref.ReadTotalTimeoutConstant = 20;
      timeoutsPtr.ref.ReadTotalTimeoutMultiplier = 0;
      timeoutsPtr.ref.WriteTotalTimeoutConstant = 50;
      timeoutsPtr.ref.WriteTotalTimeoutMultiplier = 0;
      _setCommTimeouts!(_portHandle, timeoutsPtr);
      calloc.free(timeoutsPtr);

      // Purge buffers
      // PURGE_TXABORT | PURGE_RXABORT | PURGE_TXCLEAR | PURGE_RXCLEAR = 0x000F
      _purgeComm!(_portHandle, 0x000F);

      _status = HardwareConnectionStatus.connected;
      _lastErrorMessage = null;
      notifyListeners();

      // Send initial handshake commands to ESP32:
      // Request JSON output mode and start streaming
      await Future.delayed(const Duration(milliseconds: 300));
      sendRawCommand('OUTPUT_JSON');
      await Future.delayed(const Duration(milliseconds: 200));
      sendRawCommand('START');

      // Start asynchronous polling loop
      _startSerialPolling();
      _startCloudSyncTimer();

      return true;
    } catch (e) {
      debugPrint('Connection error on $_activePort: $e');
      _status = HardwareConnectionStatus.error;
      _lastErrorMessage = e.toString();
      _cleanupPort();
      notifyListeners();
      return false;
    }
  }

  /// Disconnects from the serial hardware port.
  void disconnect() {
    _cleanupPort();
    _stopSimulation();
    _cloudSyncTimer?.cancel();
    _status = HardwareConnectionStatus.disconnected;
    notifyListeners();
  }

  void _cleanupPort() {
    _pollingTimer?.cancel();
    _pollingTimer = null;
    if (_portHandle != -1 && _closeHandle != null) {
      try {
        _closeHandle!(_portHandle);
      } catch (_) {}
      _portHandle = -1;
    }
    _rxBuffer.clear();
  }

  /// Starts polling the serial port for incoming telemetry bytes.
  void _startSerialPolling() {
    _pollingTimer?.cancel();
    _pollingTimer = Timer.periodic(const Duration(milliseconds: 50), (_) {
      _readSerialBytes();
    });
  }

  void _readSerialBytes() {
    if (_portHandle == -1 || _readFile == null) return;

    final buffer = calloc<Uint8>(512);
    final bytesReadPtr = calloc<Uint32>();

    try {
      final success = _readFile!(_portHandle, buffer, 512, bytesReadPtr, nullptr);
      final bytesRead = bytesReadPtr.value;

      if (success != 0 && bytesRead > 0) {
        final data = buffer.asTypedList(bytesRead);
        final text = utf8.decode(data, allowMalformed: true);
        _rxBuffer.write(text);

        _processBuffer();
      }
    } catch (e) {
      debugPrint('Error reading serial data: $e');
    } finally {
      calloc.free(buffer);
      calloc.free(bytesReadPtr);
    }
  }

  void _processBuffer() {
    var content = _rxBuffer.toString();
    while (content.contains('\n')) {
      final newlineIdx = content.indexOf('\n');
      final line = content.substring(0, newlineIdx).trim();
      content = content.substring(newlineIdx + 1);

      if (line.isNotEmpty) {
        _handleIncomingLine(line);
      }
    }
    _rxBuffer.clear();
    _rxBuffer.write(content);
  }

  void _handleIncomingLine(String line) {
    try {
      // 1. Check if line is a JSON object
      if (line.startsWith('{') && line.endsWith('}')) {
        final decoded = jsonDecode(line);
        if (decoded is Map<String, dynamic>) {
          final type = decoded['type'];
          if (type == 'sensor_data') {
            final telemetry = HardwareTelemetryModel.fromJson(decoded);
            _onNewTelemetry(telemetry);
          } else if (type == 'status') {
            final relay = decoded['relay']?.toString().toUpperCase();
            if (relay != null) {
              _hardwareRelayState = (relay == 'ON');
              notifyListeners();
            }
          }
          return;
        }
      }

      // 2. Check for human-readable mode responses
      if (line.startsWith('[RESPONSE] relay :')) {
        final state = line.split(':').last.trim().toUpperCase();
        _hardwareRelayState = (state == 'ON');
        notifyListeners();
      } else if (line.contains('Accel :') || line.contains('Temperature :')) {
        final telemetry = HardwareTelemetryModel.fromReadableText(line);
        _onNewTelemetry(telemetry);
      }
    } catch (e) {
      debugPrint('Error parsing serial line "$line": $e');
    }
  }

  void _onNewTelemetry(HardwareTelemetryModel telemetry) {
    _totalPacketsReceived++;
    _lastPacketTime = DateTime.now();
    _hardwareRelayState = telemetry.relayOn;
    _latestTelemetry = telemetry;

    // Immediately ingest reading into SensorService so all charts,
    // analytics, and predictive failure engines update in real-time!
    final mappingService = HardwareMappingService();
    String targetId = mappingService.getApplianceIdForPort(_activePort) ?? '';
    String targetName = 'Smart Appliance';

    if (targetId.isNotEmpty) {
      final app = ApplianceService().getApplianceById(targetId);
      if (app != null) targetName = app.name;
    } else if (ApplianceService().appliances.isNotEmpty) {
      final firstApp = ApplianceService().appliances.first;
      targetId = firstApp.id;
      targetName = firstApp.name;
    } else {
      targetId = 'main_appliance';
    }

    SensorService().addLiveTelemetryReading(
      applianceId: targetId,
      applianceName: targetName,
      temperature: telemetry.temperature,
      vibration: telemetry.vibrationMagnitude,
      sound: telemetry.soundDb,
      recordedAt: telemetry.receivedAt,
    );

    _telemetryStreamController.add(telemetry);
    notifyListeners();
  }

  /// Sends a raw string command (with newline) to the hardware.
  bool sendRawCommand(String command) {
    final cmdWithNewline = '${command.trim()}\n';

    if (isSimulated) {
      _handleSimulatedCommand(command.trim());
      return true;
    }

    if (_portHandle == -1 || _writeFile == null) {
      debugPrint('Cannot send command "$command": Port not open.');
      return false;
    }

    try {
      final utf8Bytes = utf8.encode(cmdWithNewline);
      final buffer = calloc<Uint8>(utf8Bytes.length);
      for (int i = 0; i < utf8Bytes.length; i++) {
        buffer[i] = utf8Bytes[i];
      }
      final bytesWrittenPtr = calloc<Uint32>();

      final success = _writeFile!(
        _portHandle,
        buffer,
        utf8Bytes.length,
        bytesWrittenPtr,
        nullptr,
      );

      calloc.free(buffer);
      calloc.free(bytesWrittenPtr);

      return success != 0;
    } catch (e) {
      debugPrint('Error sending command to serial port: $e');
      return false;
    }
  }

  // Hardware Control Helpers
  bool setRelay(bool on) {
    final cmd = on ? 'RELAY_ON' : 'RELAY_OFF';
    _hardwareRelayState = on;
    notifyListeners();
    return sendRawCommand(cmd);
  }

  bool toggleRelay() {
    return setRelay(!_hardwareRelayState);
  }

  bool startStreaming() {
    return sendRawCommand('START');
  }

  bool stopStreaming() {
    return sendRawCommand('STOP');
  }

  bool requestStatus() {
    return sendRawCommand('STATUS');
  }

  // =============================================================================
  // Throttled Cloud Persistence into Supabase
  // =============================================================================

  void _startCloudSyncTimer() {
    _cloudSyncTimer?.cancel();
    _cloudSyncTimer = Timer.periodic(
      Duration(seconds: _cloudSyncIntervalSeconds),
      (_) => saveTelemetrySnapshotToCloud(),
    );
  }

  /// Stores the latest telemetry into Supabase public.sensor_readings
  /// for the ONE appliance specifically bound to this COM port.
  Future<bool> saveTelemetrySnapshotToCloud() async {
    if (!_autoSyncToCloud || _latestTelemetry == null) return false;

    // Retrieve which appliance is designated to this COM port
    final mappingService = HardwareMappingService();
    String? targetApplianceId = mappingService.getApplianceIdForPort(_activePort);
    String targetName = 'Smart Appliance';

    if (targetApplianceId != null) {
      final appliance = ApplianceService().getApplianceById(targetApplianceId);
      if (appliance != null) {
        targetName = appliance.name;
      }
    } else if (ApplianceService().appliances.isNotEmpty) {
      // Auto-bind the first available appliance to this active hardware port
      final firstApp = ApplianceService().appliances.first;
      targetApplianceId = firstApp.id;
      targetName = firstApp.name;
      mappingService.bindApplianceToPort(firstApp.id, _activePort);
    }

    if (targetApplianceId == null) {
      // No registered appliance found to associate this telemetry with yet
      return false;
    }

    try {
      final sensorService = SensorService();
      await sensorService.recordSensorReading(
        applianceId: targetApplianceId,
        applianceName: targetName,
        temperature: _latestTelemetry!.temperature,
        vibration: _latestTelemetry!.vibrationMagnitude,
        sound: _latestTelemetry!.soundDb,
      );
      debugPrint('Cloud Telemetry stored for "$targetName" ($_activePort)');
      return true;
    } catch (e) {
      debugPrint('Failed to auto-save telemetry snapshot: $e');
      return false;
    }
  }

  // =============================================================================
  // Simulation Mode (for testing or when COM3 is disconnected)
  // =============================================================================

  void startSimulation() {
    _cleanupPort();
    _stopSimulation();

    _status = HardwareConnectionStatus.simulated;
    _lastErrorMessage = null;
    notifyListeners();

    _simulationTimer = Timer.periodic(const Duration(milliseconds: 500), (_) {
      final telemetry = HardwareTelemetryModel.simulated(
        relayOn: _hardwareRelayState,
        baseTemp: 34.5,
        baseVib: 0.22,
        baseSound: 46.0,
      );
      _onNewTelemetry(telemetry);
    });

    _startCloudSyncTimer();
  }

  void _stopSimulation() {
    _simulationTimer?.cancel();
    _simulationTimer = null;
  }

  void _handleSimulatedCommand(String command) {
    if (command == 'RELAY_ON') {
      _hardwareRelayState = true;
    } else if (command == 'RELAY_OFF') {
      _hardwareRelayState = false;
    } else if (command == 'RELAY_TOGGLE') {
      _hardwareRelayState = !_hardwareRelayState;
    }
    notifyListeners();
  }

  @override
  void dispose() {
    disconnect();
    _telemetryStreamController.close();
    super.dispose();
  }
}
