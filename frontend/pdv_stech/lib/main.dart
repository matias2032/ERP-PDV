// frontend/lib/main.dart

import 'app_imports.dart';
import 'package:flutter/foundation.dart'; // ← Adicionado para fornecer a constante kIsWeb
import 'dart:io' show Platform; // ← Adicionado para acesso seguro às verificações de plataforma
import 'package:http/http.dart' as http;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

// ── Inicialização condicional do SQLite (Apenas fora da Web) ───────
  if (!kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }

  await ApiConfig.baseUrlAsync;
  ApiConfig.printConfig();

  // ─────────────────────────────────────────────────────────────
  // RESET TEMPORÁRIO DO SQLITE — REMOVER DEPOIS DO PRIMEIRO RUN
  // ─────────────────────────────────────────────────────────────
  const resetarSqliteNoArranque = false;

  if (resetarSqliteNoArranque) {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'stech_pdv.db');

    debugPrint('🧨 Apagando BD SQLite local: $path');

    await deleteDatabase(path);

    debugPrint('✅ BD SQLite local apagada. Será recriada no init().');
  }
  // ─────────────────────────────────────────────────────────────

  await LocalDatabase.instance.init();

  await ConnectivityService.instance.init();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

 @override
Widget build(BuildContext context) {
  final connectivity = ConnectivityService.instance;

  // ── Serviços HTTP ─────────────────────────────────────────────────
  final clienteService = ClienteService(
    baseUrl:    ApiConfig.baseUrl,
    httpClient: http.Client(),
  );
final marcaService     = MarcaService();
  final categoriaService = CategoriaService();
  final produtoService   = ProdutoService.instance;
  final servicoService   = ServicoService.instance;
  final pedidoService    = PedidoService();
  final docFiscalService = DocumentoFiscalService();
  final cotacaoService = CotacaoService();
final despesaService = DespesaService();
final fornecedorService = FornecedorService();

  // ── Repositórios ──────────────────────────────────────────────────
  final clienteRepository = ClienteRepository(
    service:      clienteService,
    dao:          ClienteDao(),
    syncQueueDao: SyncQueueDao(),
    connectivity: connectivity,
  );

  final marcaRepository = MarcaRepository(
    service:      marcaService,
    dao:          MarcaDao(),
    syncQueueDao: SyncQueueDao(),
    connectivity: connectivity,
  );

  final categoriaRepository = CategoriaRepository(
    service:      categoriaService,
    dao:          CategoriaDao(),
    syncQueueDao: SyncQueueDao(),
    connectivity: connectivity,
  );

  final produtoRepository = ProdutoRepository(
    service:      produtoService,
    dao:          ProdutoDao(),
    syncQueueDao: SyncQueueDao(),
    connectivity: connectivity,
  );

  final servicoRepository = ServicoRepository(
    service:      servicoService,
    dao:          ServicoDao(),
    syncQueueDao: SyncQueueDao(),
    connectivity: connectivity,
  );

final pedidoRepository = PedidoRepository(
  service:      pedidoService,
  dao:          PedidoDao(),
  syncQueueDao: SyncQueueDao(),
  connectivity: connectivity,
  produtoDao:   ProdutoDao(), 
  servicoDao:   ServicoDao()         // ← linha que faltava
);

  final docFiscalRepository = DocumentoFiscalRepository(
    service:      docFiscalService,
    dao:          DocumentoFiscalDao(),
    syncQueueDao: SyncQueueDao(),
    connectivity: connectivity,
  );

final usuarioRepository = UsuarioRepository(
  service: UsuarioService(),
  dao: UsuarioDao(),
  syncQueueDao: SyncQueueDao(),
  connectivity: connectivity,
);

final cotacaoRepository = CotacaoRepository(
  service:      cotacaoService,
  dao:          CotacaoDao(),
  syncQueueDao: SyncQueueDao(),
  connectivity: connectivity,
  produtoDao:   ProdutoDao(),
  servicoDao:   ServicoDao(),
);

final despesaRepository = DespesaRepository(
  service: despesaService,
  dao: DespesaDao(),
  syncQueueDao: SyncQueueDao(),
  connectivityService: connectivity,
);

final fornecedorRepository = FornecedorRepository(
  service: fornecedorService,
  dao: FornecedorDao(),
  syncQueueDao: SyncQueueDao(),
  connectivityService: connectivity,
);


SyncScheduler.instance.init(
  connectivity:           connectivity,
  syncQueueDao:           SyncQueueDao(),
  clienteDao:             ClienteDao(),
  clienteService:         clienteService,
   despesaDao: DespesaDao(),
despesaService: despesaService,
fornecedorDao: FornecedorDao(),
fornecedorService: fornecedorService,
  marcaDao:               MarcaDao(),
  marcaService:           marcaService,
  categoriaDao:           CategoriaDao(),
  categoriaService:       categoriaService,
  produtoDao:             ProdutoDao(),
  produtoService:         produtoService,
  servicoDao:             ServicoDao(),
  servicoService:         servicoService,
  pedidoDao:              PedidoDao(),
  pedidoService:          pedidoService,
  documentoFiscalDao:     DocumentoFiscalDao(),
  documentoFiscalService: docFiscalService,
    cotacaoDao:     CotacaoDao(),
  cotacaoService: cotacaoService,
);

  return MultiProvider(
    providers: [
      // ── Utilizador ────────────────────────────────────────────────
     ChangeNotifierProvider(
  create: (_) => UsuarioProvider(repository: usuarioRepository),
),

      // ── Cliente ───────────────────────────────────────────────────
      ChangeNotifierProvider(
        create: (_) => ClienteListaProvider(
          repository:   clienteRepository,
          connectivity: connectivity,
        ),
      ),
      ChangeNotifierProvider(
        create: (_) => ClienteFormProvider(repository: clienteRepository),
      ),
      ChangeNotifierProvider(
        create: (_) => ClienteExclusaoProvider(repository: clienteRepository),
      ),
ChangeNotifierProvider(
  create: (_) => FornecedorProvider(repository: fornecedorRepository),
),

      // ── Marca ─────────────────────────────────────────────────────
      ChangeNotifierProvider(
        create: (_) => MarcaProvider(repository: marcaRepository),
      ),

      // ── Categoria ─────────────────────────────────────────────────
      ChangeNotifierProvider(
        create: (_) => CategoriaProvider(repository: categoriaRepository),
      ),

      // ── Produto ───────────────────────────────────────────────────
    ChangeNotifierProvider(
  create: (_) => ProdutoProvider(
    repository: produtoRepository,
  ),
),

      // ── Serviço ───────────────────────────────────────────────────
      ChangeNotifierProvider(
        create: (_) => ServicoProvider(repository: servicoRepository),
      ),

      // ── Pedido ────────────────────────────────────────────────────
   ChangeNotifierProvider(
  create: (ctx) => PedidoProvider(
    repository:      pedidoRepository,
    produtoProvider: ctx.read<ProdutoProvider>(), // ← linha que faltava
  ),
),

      // ── Documento Fiscal ──────────────────────────────────────────
      ChangeNotifierProvider(
        create: (_) => DocumentoFiscalProvider(repository: docFiscalRepository),
      ),

       ChangeNotifierProvider(
        create: (_) => CotacaoProvider(repository: cotacaoRepository),
      ),

      ChangeNotifierProvider(
  create: (_) => DespesaProvider(repository: despesaRepository),
),
      ],


      child: MaterialApp(
        title: 'Gestor STech',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF1B2A6B),
            primary:   const Color(0xFF1B2A6B),
          ),
          useMaterial3: true,
        ),

        initialRoute: '/splash',

        routes: {
          '/'                         : (_) => const LoginScreen(),
          '/primeira_troca_senha'     : (_) => const PrimeiraTrocaSenhaScreen(),
          '/gerenciar_usuarios'       : (_) => const UsuariosListScreen(),
          '/usuarios/criar'           : (_) => const CriarUsuarioScreen(),
          '/gerenciar_marcas'         : (_) => const MarcasListScreen(),
          '/gerenciar_categorias'     : (_) => const CategoriasListScreen(),
          '/cadastrar_marcas'         : (_) => const MarcaFormScreen(),
          '/cadastrar_categorias'     : (_) => const CategoriaFormScreen(),
          '/cadastrar_servicos'       : (_) => const ServicoFormScreen(),
          '/gerenciar_servicos'       : (_) => const ServicoListScreen(),
          '/cadastrar_produtos'       : (_) => const ProdutoFormScreen(),
          '/gerenciar_produtos'       : (_) => const ProdutoListScreen(),
          '/catalogo'                 : (_) => const CatalogoScreen(),
          '/configuracoes_impressora' : (_) => const ConfiguracoesImpressoraScreen(),
          '/pedidos_finalizados'      : (_) => const PedidosFinalizadosScreen(),
          '/alterar_senha'            : (_) => const AlterarSenhaScreen(),
          '/editar_usuario'           : (_) => const EditarUsuarioScreen(),
          '/dashboard'                : (_) => const DashboardScreen(),
          '/splash'                   : (_) => const SplashScreen(),
          '/gerenciar_clientes'       : (_) => const ClienteListScreen(),
           '/gerenciar_fornecedores'       : (_) => const FornecedorListScreen(),
           
          '/gerenciar_documentos'     : (_) => const DocumentosListScreen(),
          '/cadastrar_documentos'     : (_) => const DocumentosFormScreen(),
          '/gerenciar_extractos'      : (_) => const ExtratosListScreen(),
          '/cadastrar_extractos'      : (_) => const ExtratosFormScreen(),
          '/criar_cotacao'      : (_) => const CotacaoCatalogoScreen(),
          '/cotacoes_prontas'      : (_) => const CotacaoListScreen(),
          '/historico_cotacoes'      : (_) => const HistoricoCotacoesScreen(),
           '/pedidos_credito'      : (_) => const PedidosCreditoScreen(),  
           '/gerenciar_despesas': (_) => const DespesaListScreen(),
           '/despesas_excluidas': (_) => const DespesasExcluidasScreen(),
           
           
        },

        onGenerateRoute: (settings) {
          if (settings.name == '/usuarios/detalhes') {
            return MaterialPageRoute(
              builder:  (_) => const DetalhesUsuarioScreen(),
              settings: settings,
            );
          }

            if (settings.name == '/pedidos_credito/detalhes') {
    final pedido = settings.arguments as PedidoModel;

    return MaterialPageRoute(
      builder: (_) => DetalhesPedidoCreditoScreen(
        pedido: pedido,
      ),
      settings: settings,
    );
  }

  if (settings.name == '/cadastrar_fornecedores') {
  final fornecedor = settings.arguments as FornecedorModel?;

  return MaterialPageRoute(
    builder: (_) => FornecedorFormScreen(
      fornecedor: fornecedor,
    ),
    settings: settings,
  );
}

  if (settings.name == '/cadastrar_despesas') {
  final despesa = settings.arguments as DespesaModel?;

  return MaterialPageRoute(
    builder: (_) => DespesaFormScreen(
      despesa: despesa,
    ),
    settings: settings,
  );
}

  if (settings.name == '/detalhes_cliente') {
  final cliente = settings.arguments as ClienteModel;

  return MaterialPageRoute(
    builder: (_) => DetalhesClienteScreen(
      cliente: cliente,
    ),
    settings: settings,
  );
}

if (settings.name == '/cadastrar_despesas') {
  final despesa = settings.arguments as DespesaModel?;

  return MaterialPageRoute(
    builder: (_) => DespesaFormScreen(despesa: despesa),
    settings: settings,
  );
}
  
          if (settings.name == '/clientes/empresa/form') {
            final cliente = settings.arguments as ClienteModel?;
            return MaterialPageRoute(
              builder:  (_) => ClienteFormScreen(cliente: cliente),
              settings: settings,
            );
          }

if (settings.name == '/devolucao_troca') {
  final args = settings.arguments as DevolucaoTrocaArgs;

  return MaterialPageRoute(
    builder: (_) => DevolucaoTrocaScreen(
      idPedido: args.idPedido,
      idDocumentoOrigem: args.idDocumentoOrigem,
      pedidoInicial: args.pedidoInicial,
      documentoOrigem: args.documentoOrigem,
    ),
    settings: settings,
  );
}

// if (settings.name == '/nota_debito') {
//     final idDocumentoOrigem = settings.arguments as int;

//     return MaterialPageRoute(
//       builder: (_) => NotaDebitoScreen(
//         idDocumentoOrigem: idDocumentoOrigem,
//       ),
//       settings: settings,
//     );
//   }
          return null;
        },

        onUnknownRoute: (settings) => MaterialPageRoute(
          builder: (_) => Scaffold(
            appBar: AppBar(
              backgroundColor: const Color(0xFF1B2A6B),
              foregroundColor: Colors.white,
              title: const Text('Página não encontrada'),
            ),
            body: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.search_off_rounded,
                      size: 64, color: Color(0xFF6B7280)),
                  const SizedBox(height: 12),
                  Text(
                    'Rota "${settings.name}" não encontrada.',
                    style: const TextStyle(color: Color(0xFF6B7280)),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

