class DiscoveredDevice {
  const DiscoveredDevice({
    required this.peerId,
    required this.name,
    required this.ip,
    required this.transferPort,
    required this.lastSeen,
  });

  final String peerId;
  final String name;
  final String ip;
  final int transferPort;
  final DateTime lastSeen;

  DiscoveredDevice copyWith({
    String? peerId,
    String? name,
    String? ip,
    int? transferPort,
    DateTime? lastSeen,
  }) {
    return DiscoveredDevice(
      peerId: peerId ?? this.peerId,
      name: name ?? this.name,
      ip: ip ?? this.ip,
      transferPort: transferPort ?? this.transferPort,
      lastSeen: lastSeen ?? this.lastSeen,
    );
  }
}
