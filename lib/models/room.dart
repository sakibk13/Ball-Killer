class Room {
  final String id;
  final String code; // 6-character room code (e.g., SPK13)
  final String name;
  final String adminPhone;
  final DateTime createdAt;

  // Payment Configuration
  final String bkash1Number;
  final String bkash1Name;
  final String bkash1Qr; // Asset path (assets/1.jpeg) or Base64 string
  final String bkash2Number;
  final String bkash2Name;
  final String bkash2Qr; // Asset path (assets/2.jpeg) or Base64 string

  final String bankName;
  final String bankAccountName;
  final String bankAccountNumber;
  final String routingNumber;
  final String bankBranch;
  final String bankLogo;

  final String noticeText;
  final String referenceNote;

  Room({
    required this.id,
    required this.code,
    required this.name,
    required this.adminPhone,
    required this.createdAt,
    this.bkash1Number = '01724293453',
    this.bkash1Name = 'bKash Personal',
    this.bkash1Qr = 'assets/1.jpeg',
    this.bkash2Number = '01832465446',
    this.bkash2Name = 'bKash Personal',
    this.bkash2Qr = 'assets/2.jpeg',
    this.bankName = 'BRAC Bank PLC',
    this.bankAccountName = 'SAKIB KHAN',
    this.bankAccountNumber = '1062020640001',
    this.routingNumber = '060261726',
    this.bankBranch = 'Gulshan Principal Branch',
    this.bankLogo = 'assets/brack_bank.jpg',
    this.noticeText = 'Please clear your fine or contribution before or during match sessions. You can scan the QR code or send directly to the numbers below.',
    this.referenceNote = 'Always write your Player Name in the Reference so we can credit your payment.',
  });

  Room copyWith({
    String? id,
    String? code,
    String? name,
    String? adminPhone,
    DateTime? createdAt,
    String? bkash1Number,
    String? bkash1Name,
    String? bkash1Qr,
    String? bkash2Number,
    String? bkash2Name,
    String? bkash2Qr,
    String? bankName,
    String? bankAccountName,
    String? bankAccountNumber,
    String? routingNumber,
    String? bankBranch,
    String? bankLogo,
    String? noticeText,
    String? referenceNote,
  }) {
    return Room(
      id: id ?? this.id,
      code: code ?? this.code,
      name: name ?? this.name,
      adminPhone: adminPhone ?? this.adminPhone,
      createdAt: createdAt ?? this.createdAt,
      bkash1Number: bkash1Number ?? this.bkash1Number,
      bkash1Name: bkash1Name ?? this.bkash1Name,
      bkash1Qr: bkash1Qr ?? this.bkash1Qr,
      bkash2Number: bkash2Number ?? this.bkash2Number,
      bkash2Name: bkash2Name ?? this.bkash2Name,
      bkash2Qr: bkash2Qr ?? this.bkash2Qr,
      bankName: bankName ?? this.bankName,
      bankAccountName: bankAccountName ?? this.bankAccountName,
      bankAccountNumber: bankAccountNumber ?? this.bankAccountNumber,
      routingNumber: routingNumber ?? this.routingNumber,
      bankBranch: bankBranch ?? this.bankBranch,
      bankLogo: bankLogo ?? this.bankLogo,
      noticeText: noticeText ?? this.noticeText,
      referenceNote: referenceNote ?? this.referenceNote,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'code': code.toUpperCase(),
      'name': name,
      'adminPhone': adminPhone,
      'createdAt': createdAt.toIso8601String(),
      'bkash1Number': bkash1Number,
      'bkash1Name': bkash1Name,
      'bkash1Qr': bkash1Qr,
      'bkash2Number': bkash2Number,
      'bkash2Name': bkash2Name,
      'bkash2Qr': bkash2Qr,
      'bankName': bankName,
      'bankAccountName': bankAccountName,
      'bankAccountNumber': bankAccountNumber,
      'routingNumber': routingNumber,
      'bankBranch': bankBranch,
      'bankLogo': bankLogo,
      'noticeText': noticeText,
      'referenceNote': referenceNote,
    };
  }

  factory Room.fromMap(Map<String, dynamic> map) {
    final roomCode = (map['code'] ?? '').toString().toUpperCase();
    final isSPK13 = roomCode == 'SPK13';

    return Room(
      id: map['id'] ?? '',
      code: roomCode,
      name: map['name'] ?? '',
      adminPhone: map['adminPhone'] ?? '',
      createdAt: map['createdAt'] != null ? DateTime.parse(map['createdAt']) : DateTime.now(),
      bkash1Number: (map['bkash1Number'] != null && map['bkash1Number'].toString().isNotEmpty)
          ? map['bkash1Number']
          : (isSPK13 ? '01724293453' : '01724293453'),
      bkash1Name: (map['bkash1Name'] != null && map['bkash1Name'].toString().isNotEmpty)
          ? map['bkash1Name'].toString().replaceAll(RegExp(r'\s*\([^)]*\)'), '').trim()
          : 'bKash Personal',
      bkash1Qr: (map['bkash1Qr'] != null && map['bkash1Qr'].toString().isNotEmpty)
          ? map['bkash1Qr']
          : 'assets/1.jpeg',
      bkash2Number: (map['bkash2Number'] != null && map['bkash2Number'].toString().isNotEmpty)
          ? map['bkash2Number']
          : (isSPK13 ? '01832465446' : '01832465446'),
      bkash2Name: (map['bkash2Name'] != null && map['bkash2Name'].toString().isNotEmpty)
          ? map['bkash2Name'].toString().replaceAll(RegExp(r'\s*\([^)]*\)'), '').trim()
          : 'bKash Personal',
      bkash2Qr: (map['bkash2Qr'] != null && map['bkash2Qr'].toString().isNotEmpty)
          ? map['bkash2Qr']
          : 'assets/2.jpeg',
      bankName: (map['bankName'] != null && map['bankName'].toString().isNotEmpty) ? map['bankName'] : 'BRAC Bank PLC',
      bankAccountName: (map['bankAccountName'] != null && map['bankAccountName'].toString().isNotEmpty) ? map['bankAccountName'] : 'SAKIB KHAN',
      bankAccountNumber: (map['bankAccountNumber'] != null && map['bankAccountNumber'].toString().isNotEmpty) ? map['bankAccountNumber'] : '1062020640001',
      routingNumber: (map['routingNumber'] != null && map['routingNumber'].toString().isNotEmpty) ? map['routingNumber'] : '060261726',
      bankBranch: (map['bankBranch'] != null && map['bankBranch'].toString().isNotEmpty && map['bankBranch'] != 'Principal Branch')
          ? map['bankBranch']
          : 'Gulshan Principal Branch',
      bankLogo: map['bankLogo'] ?? 'assets/brack_bank.jpg',
      noticeText: (map['noticeText'] != null && map['noticeText'].toString().isNotEmpty)
          ? map['noticeText']
          : 'Please clear your fine or contribution before or during match sessions. You can scan the QR code or send directly to the numbers below.',
      referenceNote: (map['referenceNote'] != null && map['referenceNote'].toString().isNotEmpty)
          ? map['referenceNote']
          : 'Always write your Player Name in the Reference so we can credit your payment.',
    );
  }
}
