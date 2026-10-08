class IvaUtil {
  IvaUtil._();

  /// Mesma regra do backend: base × (1 + iva/100), 2 casas decimais.
  static double comIva(double precoSemIva, double ivaPercentual) {
    final v = precoSemIva * (1 + ivaPercentual / 100);
    return (v * 100).roundToDouble() / 100;
  }

  /// Inverso (só para dados antigos sem preco_sem_iva).
  static double semIva(double precoComIva, double ivaPercentual) {
    final v = precoComIva / (1 + ivaPercentual / 100);
    return (v * 100).roundToDouble() / 100;
  }
}