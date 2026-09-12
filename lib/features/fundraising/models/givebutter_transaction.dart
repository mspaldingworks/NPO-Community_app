class GivebutterTransaction {
  const GivebutterTransaction({
    required this.id,
    required this.amount,
    required this.status,
    this.number,
    this.campaignId,
    this.campaignTitle,
    this.firstName,
    this.lastName,
    this.email,
    this.paymentMethod,
    this.transactedAt,
    this.currency = 'USD',
  });

  final String id;
  final String? number;
  final String? campaignId;
  final String? campaignTitle;
  final String? firstName;
  final String? lastName;
  final String? email;
  final double amount;
  final String status;
  final String? paymentMethod;
  final DateTime? transactedAt;
  final String currency;

  String get donorName {
    final parts = [
      firstName,
      lastName,
    ].whereType<String>().where((p) => p.isNotEmpty);
    return parts.isEmpty ? 'Anonymous' : parts.join(' ');
  }

  String get amountLabel {
    final symbol = currency.toUpperCase() == 'USD' ? r'$' : currency;
    return '$symbol${amount.toStringAsFixed(2)}';
  }

  factory GivebutterTransaction.fromJson(Map<String, dynamic> json) {
    return GivebutterTransaction(
      id: json['id']?.toString() ?? '',
      number: json['number'] as String?,
      campaignId: json['campaign_id']?.toString(),
      campaignTitle: json['campaign_title'] as String?,
      firstName: json['first_name'] as String?,
      lastName: json['last_name'] as String?,
      email: json['email'] as String?,
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      status: json['status'] as String? ?? 'pending',
      paymentMethod: json['payment_method'] as String?,
      transactedAt: json['transacted_at'] != null
          ? DateTime.tryParse(json['transacted_at'] as String)
          : null,
      currency: json['currency'] as String? ?? 'USD',
    );
  }
}
