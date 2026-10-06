class ContractType {
  const ContractType({
    required this.id,
    required this.code,
    required this.labelFr,
  });

  final String id;
  final String code;
  final String labelFr;

  factory ContractType.fromJson(Map<String, dynamic> json) {
    return ContractType(
      id: json['id'] as String,
      code: json['code'] as String,
      labelFr: json['label_fr'] as String,
    );
  }
}
