enum TransferDirection { send, receive }

enum TransferStatus { queued, sending, receiving, paused, cancelled, done, failed }

class TransferItem {
  const TransferItem({
    required this.id,
    required this.fileName,
    required this.bytesTotal,
    required this.bytesDone,
    required this.speedBytesPerSec,
    required this.direction,
    required this.status,
    required this.peerName,
    required this.startedAt,
    required this.canControl,
  });

  final String id;
  final String fileName;
  final int bytesTotal;
  final int bytesDone;
  final double speedBytesPerSec;
  final TransferDirection direction;
  final TransferStatus status;
  final String peerName;
  final DateTime startedAt;
  final bool canControl;

  double get progress => bytesTotal == 0 ? 0 : bytesDone / bytesTotal;

  TransferItem copyWith({
    String? id,
    String? fileName,
    int? bytesTotal,
    int? bytesDone,
    double? speedBytesPerSec,
    TransferDirection? direction,
    TransferStatus? status,
    String? peerName,
    DateTime? startedAt,
    bool? canControl,
  }) {
    return TransferItem(
      id: id ?? this.id,
      fileName: fileName ?? this.fileName,
      bytesTotal: bytesTotal ?? this.bytesTotal,
      bytesDone: bytesDone ?? this.bytesDone,
      speedBytesPerSec: speedBytesPerSec ?? this.speedBytesPerSec,
      direction: direction ?? this.direction,
      status: status ?? this.status,
      peerName: peerName ?? this.peerName,
      startedAt: startedAt ?? this.startedAt,
      canControl: canControl ?? this.canControl,
    );
  }
}
