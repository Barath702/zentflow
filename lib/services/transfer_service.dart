import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:zentflow/models/transfer_item.dart';
import 'package:zentflow/services/download_path.dart';

class TransferService {
  TransferService({this.port = 45455});

  final int port;
  final _updates = StreamController<TransferItem>.broadcast();
  Stream<TransferItem> get updates => _updates.stream;
  final _rand = Random();
  ServerSocket? _serverSocket;
  final Map<String, Future<void>> _sendLocks = {};
  final Map<String, _OutgoingSession> _outgoing = {};
  final Map<String, _OutgoingSnapshot> _outgoingSnapshots = {};
  final Map<String, _IncomingSession> _incoming = {};
  String? _downloadDirOverride;

  void setDownloadDirectory(String? path) {
    _downloadDirOverride = path;
  }
  final _clipboardIn = StreamController<ClipboardMessage>.broadcast();
  Stream<ClipboardMessage> get clipboardIncoming => _clipboardIn.stream;
  final _connectionEvents = StreamController<ConnectionEvent>.broadcast();
  Stream<ConnectionEvent> get connectionEvents => _connectionEvents.stream;
  bool _warpEnabled = false;

  void setWarpEnabled(bool enabled) {
    _warpEnabled = enabled;
  }

  Future<void> startServer({required String localPeerName}) async {
    _serverSocket ??= await ServerSocket.bind(
      InternetAddress.anyIPv4,
      port,
      shared: true,
    );
    _serverSocket!.listen((client) => _handleIncoming(client));
  }

  Future<void> connectToPeer({
    required String targetIp,
    required int targetPort,
    required String localDeviceName,
  }) async {
    final socket = await Socket.connect(targetIp, targetPort, timeout: const Duration(seconds: 5));
    _writeFrame(
      socket,
      _FrameKind.json,
      _encodeJson({'type': 'connect', 'from': localDeviceName}),
    );
    final reader = _FrameReader(socket);
    final frame = await reader.nextFrame(timeout: const Duration(seconds: 5));
    if (frame == null || frame.kind != _FrameKind.json) {
      await socket.close();
      return;
    }
    final msg = _decodeJson(frame.payload);
    if (msg['type'] == 'connect_ack') {
      _connectionEvents.add(
        ConnectionEvent(
          type: ConnectionEventType.connected,
          deviceName: (msg['from'] as String?) ?? 'Peer',
          ip: targetIp,
        ),
      );
    }
    await socket.close();
  }

  Future<void> disconnectFromPeer({
    required String targetIp,
    required int targetPort,
  }) async {
    try {
      final socket = await Socket.connect(targetIp, targetPort, timeout: const Duration(seconds: 3));
      _writeFrame(socket, _FrameKind.json, _encodeJson({'type': 'disconnect'}));
      await socket.close();
    } catch (_) {}
    _connectionEvents.add(
      const ConnectionEvent(type: ConnectionEventType.disconnected, deviceName: '', ip: ''),
    );
  }

  String newTransferId() => '${DateTime.now().millisecondsSinceEpoch}-${_rand.nextInt(99999)}';

  Future<void> sendFile({
    required File file,
    required String targetIp,
    required int targetPort,
    required String peerName,
    required String fromDeviceName,
    String? transferId,
  }) async {
    final resolvedTransferId = transferId ?? newTransferId();
    final totalBytes = await file.length();
    final started = DateTime.now();
    final chunkSize = _pickChunkSize(totalBytes, _warpEnabled);
    final totalChunks = (totalBytes / chunkSize).ceil();
    var doneBytes = 0;
    _updates.add(
      TransferItem(
        id: resolvedTransferId,
        fileName: file.uri.pathSegments.last,
        bytesTotal: totalBytes,
        bytesDone: 0,
        speedBytesPerSec: 0,
        direction: TransferDirection.send,
        status: TransferStatus.sending,
        peerName: peerName,
        startedAt: started,
        canControl: true,
      ),
    );

    final lockKey = '$targetIp:$targetPort';
    await _enqueueSend(lockKey, () async {
      try {
        final socket = await Socket.connect(targetIp, targetPort, timeout: const Duration(seconds: 8));
        final session = _OutgoingSession(
          id: resolvedTransferId,
          file: file,
          fileName: file.uri.pathSegments.last,
          bytesTotal: totalBytes,
          chunkSize: chunkSize,
          totalChunks: totalChunks,
          startedAt: started,
          peerName: peerName,
          fromDeviceName: fromDeviceName,
          socket: socket,
        );
        _outgoingSnapshots[resolvedTransferId] = _OutgoingSnapshot(
          file: file,
          targetIp: targetIp,
          targetPort: targetPort,
          peerName: peerName,
          fromDeviceName: fromDeviceName,
        );
        _outgoing[resolvedTransferId] = session;
        await _sendFileSession(session);
      } catch (_) {
        _updates.add(
          TransferItem(
            id: resolvedTransferId,
            fileName: file.uri.pathSegments.last,
            bytesTotal: totalBytes,
            bytesDone: doneBytes,
            speedBytesPerSec: 0,
            direction: TransferDirection.send,
            status: TransferStatus.failed,
            peerName: peerName,
            startedAt: started,
            canControl: true,
          ),
        );
      }
    });
  }

  Future<void> sendClipboardText({
    required String text,
    required String targetIp,
    required int targetPort,
    required String fromDeviceName,
  }) async {
    final socket = await Socket.connect(targetIp, targetPort, timeout: const Duration(seconds: 5));
    final payload = _encodeJson({
      'type': 'clipboard',
      'text': text,
      'from': fromDeviceName,
      'ts': DateTime.now().millisecondsSinceEpoch,
    });
    _writeFrame(socket, _FrameKind.json, payload);
    await socket.flush();
    await socket.close();
  }

  void pause(String transferId) {
    final s = _outgoing[transferId];
    if (s == null) return;
    s.paused = true;
    _updates.add(
      TransferItem(
        id: s.id,
        fileName: s.fileName,
        bytesTotal: s.bytesTotal,
        bytesDone: s.bytesDone,
        speedBytesPerSec: s.speedBytesPerSec,
        direction: TransferDirection.send,
        status: TransferStatus.paused,
        peerName: s.peerName,
        startedAt: s.startedAt,
        canControl: true,
      ),
    );
    _writeFrame(s.socket, _FrameKind.json, _encodeJson({'type': 'control', 'cmd': 'pause', 'id': transferId}));
  }

  void resume(String transferId) {
    final s = _outgoing[transferId];
    if (s == null) return;
    s.paused = false;
    s.resumeSignal?.complete();
    s.resumeSignal = null;
    _writeFrame(s.socket, _FrameKind.json, _encodeJson({'type': 'control', 'cmd': 'resume', 'id': transferId}));
  }

  void cancel(String transferId) {
    final s = _outgoing.remove(transferId);
    if (s == null) return;
    s.cancelled = true;
    _writeFrame(s.socket, _FrameKind.json, _encodeJson({'type': 'control', 'cmd': 'cancel', 'id': transferId}));
    s.socket.destroy();
    _updates.add(
      TransferItem(
        id: s.id,
        fileName: s.fileName,
        bytesTotal: s.bytesTotal,
        bytesDone: s.bytesDone,
        speedBytesPerSec: 0,
        direction: TransferDirection.send,
        status: TransferStatus.cancelled,
        peerName: s.peerName,
        startedAt: s.startedAt,
        canControl: true,
      ),
    );
  }

  Future<void> retry(String transferId) async {
    final snap = _outgoingSnapshots[transferId];
    if (snap == null) return;
    await sendFile(
      file: snap.file,
      targetIp: snap.targetIp,
      targetPort: snap.targetPort,
      peerName: snap.peerName,
      fromDeviceName: snap.fromDeviceName,
    );
  }

  void pauseIncoming(String transferId) {
    final s = _incoming[transferId];
    if (s == null) return;
    s.paused = true;
    _updates.add(
      TransferItem(
        id: s.id,
        fileName: s.fileName,
        bytesTotal: s.bytesTotal,
        bytesDone: s.bytesDone,
        speedBytesPerSec: s.speedBytesPerSec,
        direction: TransferDirection.receive,
        status: TransferStatus.paused,
        peerName: s.peerName,
        startedAt: s.startedAt,
        canControl: true,
      ),
    );
    _writeFrame(s.socket, _FrameKind.json, _encodeJson({'type': 'control', 'cmd': 'pause', 'id': transferId}));
  }

  void resumeIncoming(String transferId) {
    final s = _incoming[transferId];
    if (s == null) return;
    s.paused = false;
    _updates.add(
      TransferItem(
        id: s.id,
        fileName: s.fileName,
        bytesTotal: s.bytesTotal,
        bytesDone: s.bytesDone,
        speedBytesPerSec: s.speedBytesPerSec,
        direction: TransferDirection.receive,
        status: TransferStatus.receiving,
        peerName: s.peerName,
        startedAt: s.startedAt,
        canControl: true,
      ),
    );
    _writeFrame(s.socket, _FrameKind.json, _encodeJson({'type': 'control', 'cmd': 'resume', 'id': transferId}));
  }

  void cancelIncoming(String transferId) {
    final s = _incoming.remove(transferId);
    if (s == null) return;
    _updates.add(
      TransferItem(
        id: s.id,
        fileName: s.fileName,
        bytesTotal: s.bytesTotal,
        bytesDone: s.bytesDone,
        speedBytesPerSec: 0,
        direction: TransferDirection.receive,
        status: TransferStatus.cancelled,
        peerName: s.peerName,
        startedAt: s.startedAt,
        canControl: true,
      ),
    );
    _writeFrame(s.socket, _FrameKind.json, _encodeJson({'type': 'control', 'cmd': 'cancel', 'id': transferId}));
    s.socket.destroy();
  }

  Future<void> _sendFileSession(_OutgoingSession s) async {
    final reader = _FrameReader(s.socket);
    s.socket.done.then((_) {
      _outgoing.remove(s.id);
    });

    _writeFrame(
      s.socket,
      _FrameKind.json,
      _encodeJson({
        'type': 'file_meta',
        'id': s.id,
        'name': s.fileName,
        'size': s.bytesTotal,
        'chunkSize': s.chunkSize,
        'totalChunks': s.totalChunks,
        'from': s.fromDeviceName,
      }),
    );

    final raf = await s.file.open(mode: FileMode.read);
    try {
      var resendAttempts = 0;
      var lastUiEmit = DateTime.fromMillisecondsSinceEpoch(0);
      final samples = <_SpeedSample>[];
      var nextChunkToSend = 0;
      var window = _warpEnabled ? 10 : 3;
      final minWindow = _warpEnabled ? 6 : 2;
      final maxWindow = _warpEnabled ? 12 : 4;
      var lastTune = DateTime.now();
      while (!s.cancelled && s.lastAckedChunk < s.totalChunks - 1) {
        if (s.paused) {
          final controlFrame = await reader.nextFrame(timeout: const Duration(seconds: 30));
          if (controlFrame == null) {
            continue;
          }
          if (controlFrame.kind == _FrameKind.json) {
            final msg = _decodeJson(controlFrame.payload);
            if (msg['type'] == 'control') {
              final cmd = msg['cmd'];
              if (cmd == 'resume') {
                s.paused = false;
              } else if (cmd == 'cancel') {
                s.cancelled = true;
                break;
              }
            }
          }
          continue;
        }
        while (nextChunkToSend < s.totalChunks && nextChunkToSend <= s.lastAckedChunk + window) {
          final offset = nextChunkToSend * s.chunkSize;
          await raf.setPosition(offset);
          final remaining = s.bytesTotal - offset;
          final readLen = remaining < s.chunkSize ? remaining : s.chunkSize;
          final buf = Uint8List(readLen);
          final n = await raf.readInto(buf, 0, readLen);
          final payload = Uint8List(4 + n);
          ByteData.sublistView(payload).setUint32(0, nextChunkToSend, Endian.big);
          payload.setRange(4, 4 + n, buf.take(n));
          _writeFrame(s.socket, _FrameKind.chunk, payload);
          nextChunkToSend++;
        }

        final frame = await reader.nextFrame(timeout: const Duration(seconds: 30));
        if (frame == null) {
          // Timeout: if paused, keep waiting; otherwise resend same chunk.
          if (s.paused) continue;
          resendAttempts++;
          if (resendAttempts <= 3) continue;
          _updates.add(
            TransferItem(
              id: s.id,
              fileName: s.fileName,
              bytesTotal: s.bytesTotal,
              bytesDone: s.bytesDone,
              speedBytesPerSec: s.speedBytesPerSec,
              direction: TransferDirection.send,
              status: TransferStatus.failed,
              peerName: s.peerName,
              startedAt: s.startedAt,
              canControl: true,
            ),
          );
          break;
        }
        resendAttempts = 0;
        if (frame.kind == _FrameKind.ack) {
          final ackIndex = ByteData.sublistView(frame.payload).getUint32(0, Endian.big);
          if (ackIndex > s.lastAckedChunk) {
            s.lastAckedChunk = ackIndex;
            s.bytesDone = min(s.bytesTotal, (ackIndex + 1) * s.chunkSize);
            final now = DateTime.now();
            samples.add(_SpeedSample(tsMs: now.millisecondsSinceEpoch, bytesDone: s.bytesDone));
            samples.removeWhere((e) => now.millisecondsSinceEpoch - e.tsMs > 1500);
            s.speedBytesPerSec = _movingAvgSpeed(samples);
            if (now.difference(lastUiEmit).inMilliseconds >= 300 || s.bytesDone >= s.bytesTotal) {
              _updates.add(
                TransferItem(
                  id: s.id,
                  fileName: s.fileName,
                  bytesTotal: s.bytesTotal,
                  bytesDone: s.bytesDone,
                  speedBytesPerSec: s.speedBytesPerSec,
                  direction: TransferDirection.send,
                  status: s.bytesDone >= s.bytesTotal ? TransferStatus.done : TransferStatus.sending,
                  peerName: s.peerName,
                  startedAt: s.startedAt,
                  canControl: true,
                ),
              );
              lastUiEmit = now;
            }
            if (now.difference(lastTune).inMilliseconds >= 1000) {
              if (resendAttempts == 0 && s.speedBytesPerSec > 8 * 1024 * 1024) {
                window = min(maxWindow, window + 1);
              } else if (resendAttempts > 0 || s.speedBytesPerSec < 2 * 1024 * 1024) {
                window = max(minWindow, window - 1);
              }
              lastTune = now;
            }
          }
        } else if (frame.kind == _FrameKind.json) {
          final msg = _decodeJson(frame.payload);
          if (msg['type'] == 'control') {
            final cmd = msg['cmd'];
            if (cmd == 'pause') {
              s.paused = true;
            } else if (cmd == 'resume') {
              s.paused = false;
              s.resumeSignal?.complete();
              s.resumeSignal = null;
            } else if (cmd == 'cancel') {
              s.cancelled = true;
              break;
            }
          }
        }
      }
    } finally {
      await raf.close();
      await s.socket.flush();
      await s.socket.close();
      _outgoing.remove(s.id);
    }
  }

  Future<void> _handleIncoming(Socket client) async {
    final reader = _FrameReader(client);
    File? outFile;
    String transferId = newTransferId();
    String fileName = 'received_file';
    int size = 0;
    int chunkSize = 128 * 1024;
    int totalChunks = 0;
    int lastReceived = -1;
    final started = DateTime.now();
    String peerName = 'Peer';
    bool isFile = false;
    var paused = false;

    var lastRxUiEmit = DateTime.fromMillisecondsSinceEpoch(0);
    final rxSamples = <_SpeedSample>[];
    try {
      while (true) {
        final frame = await reader.nextFrame(timeout: const Duration(minutes: 5));
        if (frame == null) break;

        if (frame.kind == _FrameKind.json) {
          final msg = _decodeJson(frame.payload);
          final type = msg['type'];
          if (type == 'connect') {
            final from = (msg['from'] as String?) ?? 'Peer';
            _writeFrame(client, _FrameKind.json, _encodeJson({'type': 'connect_ack', 'from': from}));
            _connectionEvents.add(
              ConnectionEvent(
                type: ConnectionEventType.connected,
                deviceName: from,
                ip: client.remoteAddress.address,
              ),
            );
            break;
          }
          if (type == 'disconnect') {
            _connectionEvents.add(
              const ConnectionEvent(type: ConnectionEventType.disconnected, deviceName: '', ip: ''),
            );
            break;
          }
          if (type == 'connect_ack') {
            _connectionEvents.add(
              ConnectionEvent(
                type: ConnectionEventType.connected,
                deviceName: (msg['from'] as String?) ?? 'Peer',
                ip: client.remoteAddress.address,
              ),
            );
            break;
          }
          if (type == 'clipboard') {
            _clipboardIn.add(
              ClipboardMessage(
                text: (msg['text'] as String?) ?? '',
                from: (msg['from'] as String?) ?? 'Peer',
              ),
            );
            break;
          }
          if (type == 'file_meta') {
            isFile = true;
            transferId = (msg['id'] as String?) ?? transferId;
            fileName = (msg['name'] as String?) ?? fileName;
            size = (msg['size'] as num?)?.toInt() ?? 0;
            chunkSize = (msg['chunkSize'] as num?)?.toInt() ?? chunkSize;
            totalChunks = (msg['totalChunks'] as num?)?.toInt() ?? ((size / chunkSize).ceil());
            peerName = (msg['from'] as String?) ?? peerName;

            final targetDir = _downloadDirOverride?.trim().isNotEmpty == true
                ? _downloadDirOverride!
                : defaultDownloadsDir();
            final incomingDir = Directory(targetDir);
            if (!incomingDir.existsSync()) incomingDir.createSync(recursive: true);
            outFile = File('${incomingDir.path}/$fileName');
            if (outFile.existsSync()) outFile.deleteSync();
            outFile.createSync(recursive: true);

            _updates.add(
              TransferItem(
                id: transferId,
                fileName: fileName,
                bytesTotal: size,
                bytesDone: 0,
                speedBytesPerSec: 0,
                direction: TransferDirection.receive,
                status: TransferStatus.receiving,
                peerName: peerName,
                startedAt: started,
                canControl: true,
              ),
            );
            _incoming[transferId] = _IncomingSession(
              id: transferId,
              socket: client,
              fileName: fileName,
              bytesTotal: size,
              peerName: peerName,
              startedAt: started,
            );
          } else if (type == 'control' && isFile) {
            final cmd = msg['cmd'];
            if (cmd == 'pause') {
              paused = true;
              _updates.add(
                TransferItem(
                  id: transferId,
                  fileName: fileName,
                  bytesTotal: size,
                  bytesDone: max(0, (lastReceived + 1) * chunkSize),
                  speedBytesPerSec: 0,
                  direction: TransferDirection.receive,
                  status: TransferStatus.paused,
                  peerName: peerName,
                  startedAt: started,
                  canControl: true,
                ),
              );
            } else if (cmd == 'cancel') {
              _incoming.remove(transferId);
              _updates.add(
                TransferItem(
                  id: transferId,
                  fileName: fileName,
                  bytesTotal: size,
                  bytesDone: max(0, (lastReceived + 1) * chunkSize),
                  speedBytesPerSec: 0,
                  direction: TransferDirection.receive,
                  status: TransferStatus.cancelled,
                  peerName: peerName,
                  startedAt: started,
                  canControl: true,
                ),
              );
              break;
            } else if (cmd == 'resume') {
              paused = false;
              _updates.add(
                TransferItem(
                  id: transferId,
                  fileName: fileName,
                  bytesTotal: size,
                  bytesDone: max(0, (lastReceived + 1) * chunkSize),
                  speedBytesPerSec: 0,
                  direction: TransferDirection.receive,
                  status: TransferStatus.receiving,
                  peerName: peerName,
                  startedAt: started,
                  canControl: true,
                ),
              );
            }
          }
        } else if (frame.kind == _FrameKind.chunk && outFile != null) {
          if (paused) {
            // Do not ACK while paused to stop the sender.
            continue;
          }
          final bd = ByteData.sublistView(frame.payload);
          final index = bd.getUint32(0, Endian.big);
          final chunkBytes = frame.payload.sublist(4);
          if (index == lastReceived + 1) {
            await outFile.writeAsBytes(chunkBytes, mode: FileMode.append, flush: false);
            lastReceived = index;
          }
          final ackPayload = Uint8List(4);
          ByteData.sublistView(ackPayload).setUint32(0, lastReceived, Endian.big);
          _writeFrame(client, _FrameKind.ack, ackPayload);

          final doneBytes = min(size, (lastReceived + 1) * chunkSize);
          final now = DateTime.now();
          rxSamples.add(_SpeedSample(tsMs: now.millisecondsSinceEpoch, bytesDone: doneBytes));
          rxSamples.removeWhere((e) => now.millisecondsSinceEpoch - e.tsMs > 1500);
          final incomingSession = _incoming[transferId];
          if (incomingSession != null) {
            incomingSession.bytesDone = doneBytes;
            incomingSession.speedBytesPerSec = _movingAvgSpeed(rxSamples);
          }
          if (now.difference(lastRxUiEmit).inMilliseconds >= 300 || doneBytes >= size) {
            _updates.add(
              TransferItem(
                id: transferId,
                fileName: fileName,
                bytesTotal: size,
                bytesDone: doneBytes,
                speedBytesPerSec: _movingAvgSpeed(rxSamples),
                direction: TransferDirection.receive,
                status: doneBytes >= size ? TransferStatus.done : TransferStatus.receiving,
                peerName: peerName,
                startedAt: started,
                canControl: true,
              ),
            );
            lastRxUiEmit = now;
          }
          if (totalChunks > 0 && lastReceived >= totalChunks - 1) break;
        }
      }
    } catch (_) {
      if (isFile) {
        _updates.add(
          TransferItem(
            id: transferId,
            fileName: fileName,
            bytesTotal: size,
            bytesDone: max(0, (lastReceived + 1) * chunkSize),
            speedBytesPerSec: 0,
            direction: TransferDirection.receive,
            status: TransferStatus.failed,
            peerName: peerName,
            startedAt: started,
            canControl: true,
          ),
        );
      }
    } finally {
      _incoming.remove(transferId);
      if (outFile != null && lastReceived >= 0) {
        final exists = await outFile.exists();
        if (exists) {
          final finalLen = await outFile.length();
          if (size > 0 && finalLen != size) {
            _updates.add(
              TransferItem(
                id: transferId,
                fileName: fileName,
                bytesTotal: size,
                bytesDone: finalLen,
                speedBytesPerSec: 0,
                direction: TransferDirection.receive,
                status: TransferStatus.failed,
                peerName: peerName,
                startedAt: started,
                canControl: true,
              ),
            );
          }
          // Best-effort log; UI toast will be wired separately.
          // ignore: avoid_print
          print('Saved received file to: ${outFile.path}');
        }
      }
      await client.flush();
      await client.close();
    }
  }

  Future<void> dispose() async {
    await _serverSocket?.close();
    await _updates.close();
    await _clipboardIn.close();
    await _connectionEvents.close();
  }

  Future<void> _enqueueSend(String key, Future<void> Function() task) {
    final previous = _sendLocks[key] ?? Future.value();
    final next = previous.catchError((_) {}).then((_) => task());
    _sendLocks[key] = next.whenComplete(() {
      if (identical(_sendLocks[key], next)) {
        _sendLocks.remove(key);
      }
    });
    return next;
  }
}

int _pickChunkSize(int totalBytes, bool warp) {
  if (warp) {
    if (totalBytes > 200 * 1024 * 1024) return 2 * 1024 * 1024;
    return 1024 * 1024;
  }
  if (totalBytes > 150 * 1024 * 1024) return 1024 * 1024;
  return 512 * 1024;
}

double _movingAvgSpeed(List<_SpeedSample> samples) {
  if (samples.length < 2) return 0;
  final first = samples.first;
  final last = samples.last;
  final deltaBytes = last.bytesDone - first.bytesDone;
  final deltaMs = (last.tsMs - first.tsMs).clamp(1, 1 << 30);
  return deltaBytes * 1000 / deltaMs;
}

class _SpeedSample {
  _SpeedSample({required this.tsMs, required this.bytesDone});
  final int tsMs;
  final int bytesDone;
}

enum ConnectionEventType { connected, disconnected }

class ConnectionEvent {
  const ConnectionEvent({
    required this.type,
    required this.deviceName,
    required this.ip,
  });
  final ConnectionEventType type;
  final String deviceName;
  final String ip;
}

class ClipboardMessage {
  const ClipboardMessage({required this.text, required this.from});
  final String text;
  final String from;
}

enum _FrameKind { json, chunk, ack }

class _Frame {
  const _Frame(this.kind, this.payload);
  final _FrameKind kind;
  final Uint8List payload;
}

class _FrameReader {
  _FrameReader(this._socket) {
    _sub = _socket.listen((data) {
      _buffer.addAll(data);
      _pump();
    }, onDone: () {
      _done = true;
      _pump();
    }, onError: (_) {
      _done = true;
      _pump();
    });
  }

  final Socket _socket;
  late final StreamSubscription<List<int>> _sub;
  final _buffer = <int>[];
  final _queue = <_Frame>[];
  final _waiters = <Completer<_Frame?>>[];
  bool _done = false;

  void _pump() {
    while (true) {
      if (_buffer.length < 5) break;
      final kindByte = _buffer[0];
      final len = ByteData.sublistView(Uint8List.fromList(_buffer.sublist(1, 5))).getUint32(0, Endian.big);
      if (_buffer.length < 5 + len) break;
      final payload = Uint8List.fromList(_buffer.sublist(5, 5 + len));
      _buffer.removeRange(0, 5 + len);
      final kind = _FrameKind.values[kindByte];
      _queue.add(_Frame(kind, payload));
    }
    while (_queue.isNotEmpty && _waiters.isNotEmpty) {
      _waiters.removeAt(0).complete(_queue.removeAt(0));
    }
    if (_done && _waiters.isNotEmpty) {
      for (final w in _waiters) {
        if (!w.isCompleted) w.complete(null);
      }
      _waiters.clear();
    }
  }

  Future<_Frame?> nextFrame({required Duration timeout}) async {
    if (_queue.isNotEmpty) return _queue.removeAt(0);
    if (_done) return null;
    final c = Completer<_Frame?>();
    _waiters.add(c);
    return c.future.timeout(timeout, onTimeout: () => null);
  }

  Future<void> dispose() async {
    await _sub.cancel();
  }
}

Uint8List _encodeJson(Map<String, Object?> msg) {
  return Uint8List.fromList(utf8.encode(jsonEncode(msg)));
}

Map<String, dynamic> _decodeJson(Uint8List payload) {
  return (jsonDecode(utf8.decode(payload)) as Map).cast<String, dynamic>();
}

void _writeFrame(Socket socket, _FrameKind kind, Uint8List payload) {
  final header = Uint8List(5);
  header[0] = kind.index;
  ByteData.sublistView(header, 1, 5).setUint32(0, payload.length, Endian.big);
  socket.add(header);
  socket.add(payload);
}

class _OutgoingSession {
  _OutgoingSession({
    required this.id,
    required this.file,
    required this.fileName,
    required this.bytesTotal,
    required this.chunkSize,
    required this.totalChunks,
    required this.startedAt,
    required this.peerName,
    required this.fromDeviceName,
    required this.socket,
  });

  final String id;
  final File file;
  final String fileName;
  final int bytesTotal;
  final int chunkSize;
  final int totalChunks;
  final DateTime startedAt;
  final String peerName;
  final String fromDeviceName;
  final Socket socket;

  int lastAckedChunk = -1;
  int bytesDone = 0;
  double speedBytesPerSec = 0;
  bool paused = false;
  bool cancelled = false;
  Completer<void>? resumeSignal;
}

class _IncomingSession {
  _IncomingSession({
    required this.id,
    required this.socket,
    required this.fileName,
    required this.bytesTotal,
    required this.peerName,
    required this.startedAt,
  });
  final String id;
  final Socket socket;
  final String fileName;
  final int bytesTotal;
  final String peerName;
  final DateTime startedAt;
  int bytesDone = 0;
  double speedBytesPerSec = 0;
  bool paused = false;
}

class _OutgoingSnapshot {
  _OutgoingSnapshot({
    required this.file,
    required this.targetIp,
    required this.targetPort,
    required this.peerName,
    required this.fromDeviceName,
  });
  final File file;
  final String targetIp;
  final int targetPort;
  final String peerName;
  final String fromDeviceName;
}
