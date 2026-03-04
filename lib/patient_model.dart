class Patient {
  final int? id;
  final String name;
  final String phone;
  final String fileNumber;
  final String birthDate;

  Patient({this.id, required this.name, required this.phone, required this.fileNumber, required this.birthDate});

  factory Patient.fromMap(Map<String, dynamic> json) => Patient(
    id: json['id'],
    name: json['name'],
    phone: json['phone'],
    fileNumber: json['fileNumber'],
    birthDate: json['birthDate'] ?? '',
  );

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'phone': phone,
    'fileNumber': fileNumber,
    'birthDate': birthDate,
  };
}