import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:zentflow/models/discovered_device.dart';

class DiscoveryService {
  DiscoveryService({
    this.discoveryPort = 45454,
    this.broadcastAddress = '255.255.255.255',
  });

  final int discoveryPort;
  final String broadcastAddress;

  final _devicesController = StreamController<List<DiscoveredDevice>>.broadcast();
  Stream<List<DiscoveredDevice>> get devicesStream => _devicesController.stream;

  RawDatagramSocket? _socket;
  Timer? _announceTimer;
  Timer? _sweepTimer;
  final Map<String, DiscoveredDevice> _peers = {};
  String? _localPeerId;
  String? _localDeviceName;
  int? _localTransferPort;

  Future<void> start({
    required String peerId,
    required String deviceName,
    required int transferPort,
  }) async {
    _localPeerId = peerId;
    _localDeviceName = deviceName;
    _localTransferPort = transferPort;
    _socket ??= await RawDatagramSocket.bind(
      InternetAddress.anyIPv4,
      discoveryPort,
      reuseAddress: true,
      reusePort: true,
    );
    _socket!.broadcastEnabled = true;
    _socket!.listen((event) {
      if (event != RawSocketEvent.read) return;
      final datagram = _socket!.receive();
      if (datagram == null) return;
      try {
        final payload = jsonDecode(utf8.decode(datagram.data)) as Map<String, dynamic>;
        final incomingPeerId = payload['peerId'] as String?;
        if (incomingPeerId == null || incomingPeerId == _localPeerId) return;
        final now = DateTime.now();
        final device = DiscoveredDevice(
          peerId: incomingPeerId,
          name: (payload['deviceName'] as String?) ?? 'Unknown',
          ip: datagram.address.address,
          transferPort: (payload['transferPort'] as num?)?.toInt() ?? 45455,
          lastSeen: now,
        );
        _peers[incomingPeerId] = device;
        _emit();
      } catch (_) {
        // Ignore malformed packets.
      }
    });

    _announceTimer?.cancel();
    _announceTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      final msg = jsonEncode({
        'peerId': _localPeerId,
        'deviceName': _localDeviceName,
        'transferPort': _localTransferPort,
        't': DateTime.now().millisecondsSinceEpoch,
      });
      _socket?.send(utf8.encode(msg), InternetAddress(broadcastAddress), discoveryPort);
    });

    _sweepTimer?.cancel();
    _sweepTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      final threshold = DateTime.now().subtract(const Duration(seconds: 8));
      _peers.removeWhere((_, value) => value.lastSeen.isBefore(threshold));
      _emit();
    });
  }

  void updateLocalDeviceName(String deviceName) {
    _localDeviceName = deviceName;
  }

  void _emit() {
    final list = _peers.values.toList()
      ..sort((a, b) => b.lastSeen.compareTo(a.lastSeen));
    _devicesController.add(list);
  }

  void clearPeers() {
    _peers.clear();
    _emit();
  }

  Future<void> dispose() async {
    _announceTimer?.cancel();
    _sweepTimer?.cancel();
    _socket?.close();
    await _devicesController.close();
  }
}
