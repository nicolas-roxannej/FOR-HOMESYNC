class Device {
  final String id;
  final String name;
  final String type;
  final String roomName;

  Device({
    required this.id,
    required this.name,
    required this.type,
    required this.roomName,
  });

  factory Device.fromMap(Map<String, dynamic> map) {
    return Device(
      id: map['id'] ?? '',
      name: map['name'] ?? 'Unknown Device',
      type: map['type'] ?? 'Unknown Type',
      roomName: map['roomName'] ?? 'Unassigned',
    );
  }
}
