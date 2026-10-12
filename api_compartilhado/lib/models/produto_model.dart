import 'package:api_compartilhado/api_compartilhado.dart';

class ProdutoModel {
  final int idProduto;
  final String nomeProduto;
  final String? descricao;
  /// Preço FINAL (com IVA) — é o que o PDV vende.
  final double preco;
  final double precoSemIva;
  final double ivaAplicado;
  final int quantidadeEstoque;
  final double? precoPromocional;
  final int ativo; // 1 = activo, 0 = inactivo (smallint no schema)
  final DateTime? dataCadastro;
  final List<int> categorias;
  final List<int> marcas;
  final String? imagemPrincipalUrl;

  const ProdutoModel({
    required this.idProduto,
    required this.nomeProduto,
    this.descricao,
    required this.preco,
    required this.precoSemIva,
    required this.ivaAplicado,
    required this.quantidadeEstoque,
    this.precoPromocional,
    required this.ativo,
    this.dataCadastro,
    this.categorias = const [],
    this.marcas = const [],
    this.imagemPrincipalUrl,
  });

  bool get estaAtivo => ativo == 1;

  /// Retorna preço promocional se existir, caso contrário preço normal.
  double get precoEfectivo => precoPromocional ?? preco;

  factory ProdutoModel.fromJson(Map<String, dynamic> json) {


    final preco = (json['preco'] as num).toDouble();
    final iva = (json['ivaAplicado'] as num?)?.toDouble() ??
        ConfiguracaoService.instance.ivaPercentual;

    return ProdutoModel(
      idProduto: json['idProduto'] as int,
      nomeProduto: json['nomeProduto'] as String,
      descricao: json['descricao'] as String?,
      preco: preco,
      precoSemIva: (json['precoSemIva'] as num?)?.toDouble() ??
          IvaUtil.semIva(preco, iva),
      ivaAplicado: iva,
      quantidadeEstoque: json['quantidadeEstoque'] as int,
      precoPromocional: json['precoPromocional'] != null
          ? (json['precoPromocional'] as num).toDouble()
          : null,
      ativo: (json['ativo'] as num?)?.toInt() ?? 1,
      dataCadastro: json['dataCadastro'] != null
          ? DateTime.tryParse(json['dataCadastro'] as String)
          : null,
      categorias: (json['categorias'] as List<dynamic>?)
              ?.map((e) => e as int)
              .toList() ??
          [],
      marcas: (json['marcas'] as List<dynamic>?)
              ?.map((e) => e as int)
              .toList() ??
          [],
      imagemPrincipalUrl: json['imagemPrincipalUrl'] as String?,
    );
  }

  // Adicionar dentro de ProdutoModel, após fromJson():

factory ProdutoModel.fromLocalDb(Map<String, dynamic> row) {
  final preco = (row['preco'] as num).toDouble();
  final iva = (row['iva_aplicado'] as num?)?.toDouble() ??
      ConfiguracaoService.instance.ivaPercentual;

  return ProdutoModel(
    idProduto:         row['id']                 as int,
    nomeProduto:       row['nome_produto']        as String,
    descricao:         row['descricao']           as String?,
    preco:             preco,
    precoSemIva:       (row['preco_sem_iva'] as num?)?.toDouble() ??
        IvaUtil.semIva(preco, iva),
    ivaAplicado:       iva,
    quantidadeEstoque: row['quantidade_estoque']  as int,
    precoPromocional:  row['preco_promocional'] != null
        ? (row['preco_promocional'] as num).toDouble()
        : null,
    ativo:             row['ativo']               as int? ?? 1,
    categorias:        const [],
    marcas:            const [],
  );
}

Map<String, dynamic> toLocalDb() => {
      'id':                 idProduto,
      'local_id':           null,
      'nome_produto':       nomeProduto,
      'descricao':          descricao,
      'preco':              preco,
      'preco_sem_iva':      precoSemIva,
      'iva_aplicado':       ivaAplicado,
      'preco_promocional':  precoPromocional,
      'quantidade_estoque': quantidadeEstoque,
      'ativo':              ativo,
      'sync_status':        'synced',
      'updated_at':         DateTime.now().toIso8601String(),
    };

    

  Map<String, dynamic> toJson() => {
        'idProduto': idProduto,
        'nomeProduto': nomeProduto,
        'descricao': descricao,
       'preco': precoSemIva,
        'precoSemIva': precoSemIva,
        'ivaAplicado': ivaAplicado,
        'quantidadeEstoque': quantidadeEstoque,
        'precoPromocional': precoPromocional,
        'ativo': ativo,
        'dataCadastro': dataCadastro?.toIso8601String(),
        'categorias': categorias,
        'marcas': marcas,
        'imagemPrincipalUrl': imagemPrincipalUrl,
      };

  ProdutoModel copyWith({
    int? idProduto,
    String? nomeProduto,
    String? descricao,
    double? preco,
    double? precoSemIva,
    double? ivaAplicado,
    int? quantidadeEstoque,
    double? precoPromocional,
    int? ativo,
    DateTime? dataCadastro,
    List<int>? categorias,
    List<int>? marcas,
    String? imagemPrincipalUrl,
  }) {
    return ProdutoModel(
      idProduto: idProduto ?? this.idProduto,
      nomeProduto: nomeProduto ?? this.nomeProduto,
      descricao: descricao ?? this.descricao,
      preco: preco ?? this.preco,
      precoSemIva: precoSemIva ?? this.precoSemIva,
      ivaAplicado: ivaAplicado ?? this.ivaAplicado,
      quantidadeEstoque: quantidadeEstoque ?? this.quantidadeEstoque,
      precoPromocional: precoPromocional ?? this.precoPromocional,
      ativo: ativo ?? this.ativo,
      dataCadastro: dataCadastro ?? this.dataCadastro,
      categorias: categorias ?? this.categorias,
      marcas: marcas ?? this.marcas,
      imagemPrincipalUrl: imagemPrincipalUrl ?? this.imagemPrincipalUrl,
    );
  }

  @override
  String toString() => 'ProdutoModel(id: $idProduto, nome: $nomeProduto)';
}

// ─── Request DTO ─────────────────────────────────────────────────────────────

class ProdutoRequestModel {
  final String nomeProduto;
  final String? descricao;
  final double precoSemIva;
  final int quantidadeEstoque;
  final double? precoPromocional;
  final List<int> categorias;
  final List<int> marcas;

  const ProdutoRequestModel({
    required this.nomeProduto,
    this.descricao,
     required this.precoSemIva,
    required this.quantidadeEstoque,
    this.precoPromocional,
    this.categorias = const [],
    this.marcas = const [],
  });

  Map<String, dynamic> toJson() => {
        'nomeProduto': nomeProduto,
        'descricao': descricao,
        'preco': precoSemIva,
        'quantidadeEstoque': quantidadeEstoque,
        'precoPromocional': precoPromocional,
        'categorias': categorias,
        'marcas': marcas,
      };
}

// ─── Imagem DTO ───────────────────────────────────────────────────────────────

class ProdutoImagemModel {
  final int idImagem;
  final int idProduto;
  final String caminhoImagem;
  final String? legenda;
  final int imagemPrincipal; // 0 ou 1

  const ProdutoImagemModel({
    required this.idImagem,
    required this.idProduto,
    required this.caminhoImagem,
    this.legenda,
    required this.imagemPrincipal,
  });

  factory ProdutoImagemModel.fromJson(Map<String, dynamic> json) {
    return ProdutoImagemModel(
      idImagem: json['idImagem'] as int,
      idProduto: json['idProduto'] as int,
      caminhoImagem: json['caminhoImagem'] as String,
      legenda: json['legenda'] as String?,
      imagemPrincipal: (json['imagemPrincipal'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
        'idImagem': idImagem,
        'idProduto': idProduto,
        'caminhoImagem': caminhoImagem,
        'legenda': legenda,
        'imagemPrincipal': imagemPrincipal,
      };
}