class Peer {
  final String ip;
  final String id;
  final String name;
  final int port;
  final DateTime discoveredAt;

  Peer({
    required this.ip,
    required this.id,
    required this.name,
    required this.port,
    DateTime? discoveredAt,
  }) : discoveredAt = discoveredAt ?? DateTime.now();

  factory Peer.fromJson(Map<String, dynamic> json) {
    return Peer(
      ip: json['ip'] as String,
      id: json['id'] as String? ?? json['ip'] as String,
      name: json['name'] as String,
      port: json['port'] as int,
    );
  }

  Map<String, dynamic> toJson() {
    return {'ip': ip, 'id': id, 'name': name, 'port': port};
  }

  String get displayName {
    // Clean up the mDNS name format
    String cleanName = name;
    if (cleanName.contains('._hydra-share._tcp')) {
      cleanName = cleanName.split('.').first;
    }
    return cleanName;
  }

  @override
  String toString() => 'Peer($displayName @ $ip:$port)';
}
