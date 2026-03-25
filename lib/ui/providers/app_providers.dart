import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:zentflow/models/app_theme_mode.dart';
import 'package:zentflow/models/discovered_device.dart';
import 'package:zentflow/models/transfer_item.dart';
import 'package:zentflow/services/discovery_service.dart';
import 'package:zentflow/services/download_path.dart';
import 'package:zentflow/services/settings_store.dart';
import 'package:zentflow/services/transfer_service.dart';

class ClipboardEntry {
  const ClipboardEntry({
    required this.text,
    required this.timestamp,
    required this.fromDevice,
  });

  final String text;
  final DateTime timestamp;
  final String fromDevice;
}

class AppState {
  const AppState({
    required this.currentTab,
    required this.themeMode,
    required this.deviceName,
    required this.peerId,
    required this.devices,
    required this.selectedDevice,
    required this.transfers,
    required this.clipboardHistory,
    required this.isSendingNow,
    required this.autoClipboardSync,
    required this.warpSpeed,
    required this.downloadDir,
    required this.isConnected,
    required this.connectedDeviceName,
    required this.connectedDeviceIp,
  });

  factory AppState.initial() => AppState(
        currentTab: 0,
        themeMode: AppThemeMode.amoled,
        deviceName: 'My device',
        peerId: (1000 + Random().nextInt(9000)).toString(),
        devices: const [],
        selectedDevice: null,
        transfers: const [],
        clipboardHistory: const [],
        isSendingNow: false,
        autoClipboardSync: false,
        warpSpeed: false,
        downloadDir: null,
        isConnected: false,
        connectedDeviceName: null,
        connectedDeviceIp: null,
      );

  final int currentTab;
  final AppThemeMode themeMode;
  final String deviceName;
  final String peerId;
  final List<DiscoveredDevice> devices;
  final DiscoveredDevice? selectedDevice;
  final List<TransferItem> transfers;
  final List<ClipboardEntry> clipboardHistory;
  final bool isSendingNow;
  final bool autoClipboardSync;
  final bool warpSpeed;
  final String? downloadDir;
  final bool isConnected;
  final String? connectedDeviceName;
  final String? connectedDeviceIp;

  AppState copyWith({
    int? currentTab,
    AppThemeMode? themeMode,
    String? deviceName,
    String? peerId,
    List<DiscoveredDevice>? devices,
    Object? selectedDevice = _keepValue,
    List<TransferItem>? transfers,
    List<ClipboardEntry>? clipboardHistory,
    bool? isSendingNow,
    bool? autoClipboardSync,
    bool? warpSpeed,
    String? downloadDir,
    bool? isConnected,
    String? connectedDeviceName,
    Object? connectedDeviceIp = _keepValue,
  }) {
    return AppState(
      currentTab: currentTab ?? this.currentTab,
      themeMode: themeMode ?? this.themeMode,
      deviceName: deviceName ?? this.deviceName,
      peerId: peerId ?? this.peerId,
      devices: devices ?? this.devices,
      selectedDevice:
          selectedDevice == _keepValue ? this.selectedDevice : selectedDevice as DiscoveredDevice?,
      transfers: transfers ?? this.transfers,
      clipboardHistory: clipboardHistory ?? this.clipboardHistory,
      isSendingNow: isSendingNow ?? this.isSendingNow,
      autoClipboardSync: autoClipboardSync ?? this.autoClipboardSync,
      warpSpeed: warpSpeed ?? this.warpSpeed,
      downloadDir: downloadDir ?? this.downloadDir,
      isConnected: isConnected ?? this.isConnected,
      connectedDeviceName: connectedDeviceName ?? this.connectedDeviceName,
      connectedDeviceIp: connectedDeviceIp == _keepValue ? this.connectedDeviceIp : connectedDeviceIp as String?,
    );
  }
}

const _keepValue = Object();

final discoveryServiceProvider = Provider<DiscoveryService>((ref) {
  final service = DiscoveryService();
  ref.onDispose(service.dispose);
  return service;
});

final transferServiceProvider = Provider<TransferService>((ref) {
  final service = TransferService();
  ref.onDispose(service.dispose);
  return service;
});

final settingsStoreProvider = Provider<SettingsStore>((ref) {
  return SettingsStore();
});

final appControllerProvider = StateNotifierProvider<AppController, AppState>((ref) {
  return AppController(
    ref.read(discoveryServiceProvider),
    ref.read(transferServiceProvider),
    ref.read(settingsStoreProvider),
  )..init();
});

class AppController extends StateNotifier<AppState> {
  AppController(this._discovery, this._transfer, this._store) : super(AppState.initial());

  final DiscoveryService _discovery;
  final TransferService _transfer;
  final SettingsStore _store;
  StreamSubscription<List<DiscoveredDevice>>? _deviceSub;
  StreamSubscription<TransferItem>? _transferSub;
  StreamSubscription<ClipboardMessage>? _clipSub;
  StreamSubscription<ConnectionEvent>? _connectionSub;
  final List<_QueuedSend> _sendQueue = [];
  bool _processingQueue = false;

  Future<void> init() async {
    final storedName = await _store.getDeviceName();
    final storedPeerId = await _store.getPeerId();
    final peerId = storedPeerId ?? (1000 + Random().nextInt(9000)).toString();
    if (storedPeerId == null) {
      await _store.setPeerId(peerId);
    }
    state = state.copyWith(
      deviceName: storedName ?? state.deviceName,
      peerId: peerId,
    );

    final storedDownload = await _store.getDownloadDir();
    final effectiveDownload = storedDownload ?? defaultDownloadsDir();
    state = state.copyWith(downloadDir: effectiveDownload);
    _transfer.setDownloadDirectory(effectiveDownload);
    await _ensureStoragePermission();

    await _transfer.startServer(localPeerName: state.deviceName);
    await _discovery.start(
      peerId: state.peerId,
      deviceName: state.deviceName,
      transferPort: _transfer.port,
    );
    _deviceSub = _discovery.devicesStream.listen((devices) {
      final stillSelected = state.selectedDevice == null
          ? null
          : devices.cast<DiscoveredDevice?>().firstWhere(
                (d) => d?.peerId == state.selectedDevice!.peerId,
                orElse: () => null,
              );
      state = state.copyWith(devices: devices, selectedDevice: stillSelected);
    });
    _transferSub = _transfer.updates.listen((item) {
      final list = [...state.transfers];
      final index = list.indexWhere((t) => t.id == item.id);
      if (index == -1) {
        list.insert(0, item);
      } else {
        list[index] = item;
      }
      state = state.copyWith(
        transfers: list,
        isSendingNow: list.any((t) => t.status == TransferStatus.sending || t.status == TransferStatus.receiving),
      );
    });

    _clipSub = _transfer.clipboardIncoming.listen((clip) async {
      final updated = [
        ClipboardEntry(text: clip.text, timestamp: DateTime.now(), fromDevice: clip.from),
        ...state.clipboardHistory,
      ];
      state = state.copyWith(clipboardHistory: updated);
    });
    _connectionSub = _transfer.connectionEvents.listen((event) {
      if (event.type == ConnectionEventType.connected) {
        final matched = state.devices.cast<DiscoveredDevice?>().firstWhere(
              (d) => d?.ip == event.ip,
              orElse: () => null,
            );
        final selected = matched ??
            DiscoveredDevice(
              peerId: state.peerId,
              name: event.deviceName,
              ip: event.ip,
              transferPort: _transfer.port,
              lastSeen: DateTime.now(),
            );
        state = state.copyWith(
          isConnected: true,
          connectedDeviceName: event.deviceName,
          connectedDeviceIp: event.ip,
          selectedDevice: selected,
        );
      } else {
        state = state.copyWith(
          isConnected: false,
          connectedDeviceName: null,
          connectedDeviceIp: null,
          selectedDevice: null,
        );
      }
    });
  }

  void setTab(int index) => state = state.copyWith(currentTab: index);
  void setTheme(AppThemeMode mode) => state = state.copyWith(themeMode: mode);
  void setDeviceName(String name) {
    state = state.copyWith(deviceName: name);
    _store.setDeviceName(name);
    _discovery.updateLocalDeviceName(name);
  }

  Future<void> setDownloadDir(String path) async {
    state = state.copyWith(downloadDir: path);
    await _store.setDownloadDir(path);
    _transfer.setDownloadDirectory(path);
  }

  Future<void> chooseDownloadDir() async {
    final chosen = await FilePicker.platform.getDirectoryPath();
    if (chosen == null || chosen.trim().isEmpty) return;
    await setDownloadDir(chosen);
  }
  void selectDevice(DiscoveredDevice? device) => state = state.copyWith(selectedDevice: device);
  void toggleAutoClipboard(bool value) => state = state.copyWith(autoClipboardSync: false);
  void toggleWarp(bool value) {
    state = state.copyWith(warpSpeed: value);
    _transfer.setWarpEnabled(value);
  }

  Future<void> sendClipboardText(String text) async {
    if (text.trim().isEmpty) return;
    final updated = [
      ClipboardEntry(text: text.trim(), timestamp: DateTime.now(), fromDevice: '${state.deviceName} (you)'),
      ...state.clipboardHistory,
    ];
    state = state.copyWith(clipboardHistory: updated);

    for (final d in state.devices) {
      try {
        await _transfer.sendClipboardText(
          text: text.trim(),
          targetIp: d.ip,
          targetPort: d.transferPort,
          fromDeviceName: state.deviceName,
        );
      } catch (_) {
        try {
          await _transfer.sendClipboardText(
            text: text.trim(),
            targetIp: d.ip,
            targetPort: d.transferPort,
            fromDeviceName: state.deviceName,
          );
        } catch (_) {}
      }
    }
  }

  Future<void> pickAndSendFile() async {
    await addMoreFiles();
  }

  Future<void> addMoreFiles() async {
    final selected = state.selectedDevice ??
        (state.connectedDeviceIp == null
            ? null
            : DiscoveredDevice(
                peerId: state.peerId,
                name: state.connectedDeviceName ?? 'Peer',
                ip: state.connectedDeviceIp!,
                transferPort: _transfer.port,
                lastSeen: DateTime.now(),
              ));
    if (selected == null) return;
    final result = await FilePicker.platform.pickFiles(withData: false, allowMultiple: true);
    if (result == null) return;
    final files = result.files.where((f) => f.path != null).map((f) => File(f.path!)).toList();
    if (files.isEmpty) return;
    for (final file in files) {
      final id = _transfer.newTransferId();
      final total = await file.length();
      final queueItem = _QueuedSend(id: id, file: file, target: selected);
      _sendQueue.add(queueItem);
      final list = [...state.transfers];
      list.insert(
        0,
        TransferItem(
          id: id,
          fileName: file.uri.pathSegments.last,
          bytesTotal: total,
          bytesDone: 0,
          speedBytesPerSec: 0,
          direction: TransferDirection.send,
          status: TransferStatus.queued,
          peerName: selected.name,
          startedAt: DateTime.now(),
          canControl: true,
        ),
      );
      state = state.copyWith(transfers: list);
    }
    await _processSendQueue();
  }

  Future<void> connectToDevice(DiscoveredDevice device) async {
    state = state.copyWith(selectedDevice: device);
    await _transfer.connectToPeer(
      targetIp: device.ip,
      targetPort: device.transferPort,
      localDeviceName: state.deviceName,
    );
    state = state.copyWith(
      isConnected: true,
      connectedDeviceName: device.name,
      connectedDeviceIp: device.ip,
    );
  }

  Future<void> disconnectCurrent() async {
    final selected = state.selectedDevice;
    if (selected != null) {
      await _transfer.disconnectFromPeer(targetIp: selected.ip, targetPort: selected.transferPort);
    } else if (state.connectedDeviceIp != null) {
      await _transfer.disconnectFromPeer(targetIp: state.connectedDeviceIp!, targetPort: _transfer.port);
    }
    state = state.copyWith(
      isConnected: false,
      connectedDeviceName: null,
      connectedDeviceIp: null,
      selectedDevice: null,
    );
    _sendQueue.clear();
    _processingQueue = false;
    _discovery.clearPeers();
    await _discovery.start(
      peerId: state.peerId,
      deviceName: state.deviceName,
      transferPort: _transfer.port,
    );
  }

  Future<void> _processSendQueue() async {
    if (_processingQueue) return;
    _processingQueue = true;
    try {
      while (_sendQueue.isNotEmpty) {
        if (state.warpSpeed) {
          final batch = List<_QueuedSend>.from(_sendQueue.take(4));
          _sendQueue.removeRange(0, batch.length);
          await Future.wait(
            batch.map(
              (entry) => _transfer.sendFile(
                transferId: entry.id,
                file: entry.file,
                targetIp: entry.target.ip,
                targetPort: entry.target.transferPort,
                peerName: entry.target.name,
                fromDeviceName: state.deviceName,
              ),
            ),
          );
        } else {
          final next = _sendQueue.removeAt(0);
          await _transfer.sendFile(
            transferId: next.id,
            file: next.file,
            targetIp: next.target.ip,
            targetPort: next.target.transferPort,
            peerName: next.target.name,
            fromDeviceName: state.deviceName,
          );
        }
      }
    } finally {
      _processingQueue = false;
    }
  }

  void pauseTransfer(String id) => _transfer.pause(id);
  void resumeTransfer(String id) => _transfer.resume(id);
  void cancelTransfer(String id) {
    _sendQueue.removeWhere((e) => e.id == id);
    _transfer.cancel(id);
  }
  Future<void> retryTransfer(String id) => _transfer.retry(id);

  void pauseIncomingTransfer(String id) => _transfer.pauseIncoming(id);
  void resumeIncomingTransfer(String id) => _transfer.resumeIncoming(id);
  void cancelIncomingTransfer(String id) => _transfer.cancelIncoming(id);

  Future<void> _ensureStoragePermission() async {
    if (!Platform.isAndroid) return;
    final storage = await Permission.storage.request();
    if (storage.isGranted) return;
    await Permission.manageExternalStorage.request();
  }

  @override
  void dispose() {
    _deviceSub?.cancel();
    _transferSub?.cancel();
    _clipSub?.cancel();
    _connectionSub?.cancel();
    super.dispose();
  }
}

class _QueuedSend {
  _QueuedSend({
    required this.id,
    required this.file,
    required this.target,
  });
  final String id;
  final File file;
  final DiscoveredDevice target;
}
