enum Currency {
  idr(code: 'IDR', decimalDigits: 0),
  usd(code: 'USD', decimalDigits: 2),
  eur(code: 'EUR', decimalDigits: 2);

  const Currency({required this.code, required this.decimalDigits});

  final String code;
  final int decimalDigits;
}

final class Money {
  Money({required this.minorUnits, required this.currency}) {
    if (minorUnits < 0) {
      throw RangeError.range(minorUnits, 0, null, 'minorUnits');
    }
  }

  final int minorUnits;
  final Currency currency;

  Money operator +(Money other) {
    _requireSameCurrency(other);
    return Money(minorUnits: minorUnits + other.minorUnits, currency: currency);
  }

  void _requireSameCurrency(Money other) {
    if (currency != other.currency) {
      throw ArgumentError(
        'Uang dengan currency berbeda tidak dapat dijumlahkan.',
      );
    }
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Money &&
          minorUnits == other.minorUnits &&
          currency == other.currency;

  @override
  int get hashCode => Object.hash(minorUnits, currency);
}
