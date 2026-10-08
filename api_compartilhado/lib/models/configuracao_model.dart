class ConfiguracaoModel {
  final String idioma;
  final String moeda;
  final String nomeEmpresa;
  final double ivaPercentual;

  const ConfiguracaoModel({
    required this.idioma,
    required this.moeda,
    required this.nomeEmpresa,
    required this.ivaPercentual,
  });

  /// Valores por omissão (usados se nunca houve ligação ao servidor).
  static const padrao = ConfiguracaoModel(
    idioma: 'pt',
    moeda: 'MZN',
    nomeEmpresa: 'Stech Engenharia',
    ivaPercentual: 16.0,
  );

  factory ConfiguracaoModel.fromJson(Map<String, dynamic> json) =>
      ConfiguracaoModel(
        idioma: json['idioma'] as String? ?? 'pt',
        moeda: json['moeda'] as String? ?? 'MZN',
        nomeEmpresa: json['nomeEmpresa'] as String? ?? 'Stech Engenharia',
        ivaPercentual: (json['ivaPercentual'] as num?)?.toDouble() ?? 16.0,
      );

  Map<String, dynamic> toJson() => {
        'idioma': idioma,
        'moeda': moeda,
        'nomeEmpresa': nomeEmpresa,
        'ivaPercentual': ivaPercentual,
      };

  ConfiguracaoModel copyWith({
    String? idioma,
    String? moeda,
    String? nomeEmpresa,
    double? ivaPercentual,
  }) =>
      ConfiguracaoModel(
        idioma: idioma ?? this.idioma,
        moeda: moeda ?? this.moeda,
        nomeEmpresa: nomeEmpresa ?? this.nomeEmpresa,
        ivaPercentual: ivaPercentual ?? this.ivaPercentual,
      );
}