import 'dart:async';
import 'package:flutter/material.dart';
import '../api/client.dart';
import '../api/models.dart';
import '../config/app_config.dart';

enum ConnectionStatus { offline, connecting, online, error }

class RelayState extends ChangeNotifier {
  DaemonClient? _client;
  DeviceStatus? _status;
  ConnectionStatus _connectionStatus = ConnectionStatus.offline;
  String? _errorMessage;
  DateTime? _lastSuccessfulPoll;
  Timer? _pollTimer;
  int _pollInterval = 15;

  DeviceStatus? get status => _status;
  ConnectionStatus get connectionStatus => _connectionStatus;
  String? get errorMessage => _errorMessage;
  DateTime? get lastSuccessfulPoll => _lastSuccessfulPoll;
  int get pollInterval => _pollInterval;

  Future<void> initialize() async {
    final serverUrl = await AppConfig.getServerUrl();
    final secret = await AppConfig.getSecret();
    _pollInterval = await AppConfig.getPollInterval();

    if (serverUrl.isNotEmpty && secret.isNotEmpty) {
      _client = DaemonClient(baseUrl: serverUrl, secret: secret);
      startPolling();
    }
  }

  Future<void> updateConfiguration(String serverUrl, String secret) async {
    await AppConfig.setServerUrl(serverUrl);
    await AppConfig.setSecret(secret);
    _client = DaemonClient(baseUrl: serverUrl, secret: secret);
    notifyListeners();
  }

  Future<void> updatePollInterval(int seconds) async {
    _pollInterval = seconds;
    await AppConfig.setPollInterval(seconds);
    if (_pollTimer != null) {
      _pollTimer!.cancel();
      startPolling();
    }
    notifyListeners();
  }

  void startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(Duration(seconds: _pollInterval), (_) {
      pollStatus();
    });
    pollStatus(); // Initial poll
  }

  void stopPolling() {
    _pollTimer?.cancel();
    _connectionStatus = ConnectionStatus.offline;
    notifyListeners();
  }

  Future<void> pollStatus() async {
    if (_client == null) return;

    _connectionStatus = ConnectionStatus.connecting;
    _errorMessage = null;
    notifyListeners();

    final response = await _client!.getStatus();

    if (response.success && response.data != null) {
      _status = response.data;
      _connectionStatus = ConnectionStatus.online;
      _errorMessage = null;
      _lastSuccessfulPoll = DateTime.now();
    } else {
      _connectionStatus = ConnectionStatus.error;
      _errorMessage = response.message ?? 'Unknown error';
    }

    notifyListeners();
  }

  Future<void> toggleDataEnabled() async {
    if (_client == null || _status == null) return;

    final response = await _client!.setDataEnabled(!_status!.dataEnabled);
    if (response.success) {
      await pollStatus();
    } else {
      _errorMessage = response.message;
      notifyListeners();
    }
  }

  Future<void> toggleAirplaneMode() async {
    if (_client == null || _status == null) return;

    final response = await _client!.setAirplaneMode(!_status!.airplaneMode);
    if (response.success) {
      await pollStatus();
    } else {
      _errorMessage = response.message;
      notifyListeners();
    }
  }

  Future<void> toggleCallForwarding({String? number}) async {
    if (_client == null || _status == null) return;

    final response = await _client!.setCallForwarding(
      enable: !_status!.callForwardingActive,
      number: number,
    );

    if (response.success) {
      await pollStatus();
    } else {
      _errorMessage = response.message;
      notifyListeners();
    }
  }

  Future<void> dialNumber(String number) async {
    if (_client == null) return;

    final response = await _client!.dialNumber(number);
    if (!response.success) {
      _errorMessage = response.message;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }
}
