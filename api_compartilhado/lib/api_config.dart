import 'package:flutter/foundation.dart';

class ApiConfig {
  // ── Configuração de ambiente ──────────────────────────────────────

static const String _baseUrlFromEnv = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://erp-and-pdv.onrender.com',
  );

  static String? _baseUrlCache;

  // ── Resolução do baseUrl ──────────────────────────────────────────

  /// Deve ser chamado uma vez no main() antes de runApp().
  static Future<String> get baseUrlAsync async {
    if (_baseUrlCache != null) return _baseUrlCache!;

    _baseUrlCache = _baseUrlFromEnv;
    return _baseUrlCache!;
  }

  static String get baseUrl {
    if (_baseUrlCache != null) return _baseUrlCache!;
    return _baseUrlFromEnv;
  }

  // ── Caminhos relativos ────────────────────────────────────────────

  static const String _usuarios = '/api/usuarios';
  static const String _auth = '/api/auth';
  static const String _perfis = '/api/perfis';
  static const String _pedidos = '/api/pedidos';
  static const String _produtos = '/api/produtos';
  static const String _servicos = '/api/servicos';
  static const String _tiposPagamento = '/api/tipos-pagamento';
  static const String _estoque = '/api/estoque';
  static const String _movimentosEstoque = '/api/movimentos-estoque';
  static const String _dashboard = '/api/dashboard';
  static const String categorias = '/api/categorias';
  static const String marcas = '/api/marcas';
  static const String clientes = '/api/clientes';
  static const String fornecedores = '/api/fornecedores';
  static const String _documentosFiscais = '/api/documentos-fiscais';
  static const String cotacoes = '/api/cotacoes';
  static const String despesas = '/api/despesas';
  static const String _sync = '/api/sync';

  // ── URLs completas ────────────────────────────────────────────────

  static String get usuariosUrl => '$baseUrl$_usuarios';
  static String get authUrl => '$baseUrl$_auth';
  static String get loginUrl => '$baseUrl$_auth/login';
  static String get perfisUrl => '$baseUrl$_perfis';
  static String get pedidosUrl => '$baseUrl$_pedidos';
  static String get produtosUrl => '$baseUrl$_produtos';
  static String get servicosUrl => '$baseUrl$_servicos';
  static String get tiposPagamentoUrl => '$baseUrl$_tiposPagamento';
  static String get estoqueUrl => '$baseUrl$_estoque';
  static String get movimentosEstoqueUrl => '$baseUrl$_movimentosEstoque';
  static String get dashboardUrl => '$baseUrl$_dashboard';
  static String get categoriasUrl => '$baseUrl$categorias';
  static String get marcasUrl => '$baseUrl$marcas';
  static String get clientesUrl => '$baseUrl$clientes';
  static String get fornecedoresUrl => '$baseUrl$fornecedores';
  static String get documentosFiscaisUrl => '$baseUrl$_documentosFiscais';
  static String get cotacoesUrl => '$baseUrl$cotacoes';
  static String get despesasUrl => '$baseUrl$despesas';
  static String get syncBatchUrl => '$baseUrl$_sync/batch';

  // ── Configurações gerais ──────────────────────────────────────────

  static const Duration timeout = Duration(seconds: 30);

  static Map<String, String> get defaultHeaders => const {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      };

  static void printConfig() {
    debugPrint('🚀 API CONFIG — ${kIsWeb ? "Web" : "Desktop/Mobile"}');
    debugPrint('🔗 Base URL: $baseUrl');
    debugPrint(
      '🌍 API_BASE_URL env: ${const String.fromEnvironment('API_BASE_URL')}',
    );
  }
}