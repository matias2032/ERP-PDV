library api_compartilhado;

// 1. Configuração da API
export 'api_config.dart';

// 2. Models
export 'models/usuario_model.dart';
export 'models/resultado_autenticacao.dart';
export 'models/api_response.dart';
export 'models/produto_model.dart';
export 'models/disponibilidade_produto_model.dart';
export 'models/servico_model.dart';
export 'models/preco_produto_model.dart';
export 'models/estoque_model.dart';
export 'models/movimento_estoque_model.dart';
export 'models/pedido_model.dart';
export 'models/categoria_model.dart';
export 'models/marca_model.dart';
export 'models/cliente_model.dart';
export 'models/documento_fiscal_model.dart'; // ← TipoDocumentoModel + DocumentoFiscalModel (API)
export 'models/extrato_model.dart';
export 'models/cotacao_model.dart';
export 'models/fornecedor_model.dart';
export 'models/despesa_model.dart';
export 'models/configuracao_model.dart';

// 3. Services
export 'services/sessao_service.dart';
export 'services/servico_autenticacao.dart';
export 'services/pedido_service.dart';
export 'services/estoque_service.dart';
export 'services/produto_service.dart';
export 'services/impressora_service.dart';
export 'services/cotacao_service.dart';
// pdf_service.dart NÃO é exportado aqui — usa DocumentoPdfModel (local)
// e deve ser importado directamente onde for usado:
export 'package:api_compartilhado/services/pdf_service.dart';
export 'services/firebase_listener_service.dart';
export 'services/sync_queue_service.dart';
export 'services/usuario_service.dart';
export 'services/marca_service.dart';
export 'services/categoria_service.dart';
export 'services/servico_service.dart';
export 'services/cliente_service.dart';
export 'services/documento_fiscal_service.dart'; // ← DocumentoFiscalService
export 'services/extrato_service.dart'; 
export 'services/extrato_pdf_service.dart'; 
export 'services/cotacao_pdf_service.dart'; 
export 'services/fornecedor_service.dart';
export 'services/despesa_service.dart';
export 'services/configuracao_service.dart';
export 'services/extrato_pdf_interno_service.dart';




// 4. Providers
export 'providers/produto_provider.dart';
export 'providers/estoque_provider.dart';
export 'providers/pedido_provider.dart';
export 'providers/servico_provider.dart';
export 'providers/cliente_provider.dart';
export 'providers/usuario_provider.dart' hide UsuarioService;
export 'providers/documento_fiscal_provider.dart'; // ← DocumentoFiscalProvider
export 'providers/cotacao_provider.dart';
export 'providers/fornecedor_provider.dart';
export 'providers/marca_provider.dart';         // novo
export 'providers/categoria_provider.dart';     // novo
export 'providers/despesa_provider.dart';
export 'providers/configuracao_provider.dart';
export 'core/utils/iva_util.dart';


// 5. Controllers
export 'controllers/pedido_ativo_controller.dart';
export 'controllers/cotacao_ativa_controller.dart';


export 'core/database/local_database.dart';
export 'core/database/daos/cliente_dao.dart';
export 'core/database/daos/marca_dao.dart';
export 'core/database/daos/sync_queue_dao.dart';
export 'core/connectivity/connectivity_service.dart';
export 'core/sync/sync_scheduler.dart';
export 'core/database/daos/categoria_dao.dart';
export 'core/database/daos/pedido_dao.dart';
export 'core/database/daos/despesa_dao.dart';
export 'core/database/daos/cotacao_dao.dart';
export 'core/database/daos/fornecedor_dao.dart';
export 'core/database/daos/servico_dao.dart';
export 'core/database/daos/usuario_dao.dart';
export 'core/database/daos/documento_fiscal_dao.dart';
export 'core/database/daos/produto_dao.dart';
export 'core/constants/constantes_fiscais.dart';
export 'core/backup/backup_import_service.dart';
export 'core/backup/backup_export_service.dart';



// 6. repositories
export 'repository/cliente_repository.dart';
export 'repository/usuario_repository.dart';
export 'repository/marca_repository.dart';
export 'repository/cotacao_repository.dart';
export 'repository/fornecedor_repository.dart';
export 'repository/despesa_repository.dart';
export 'repository/categoria_repository.dart';
export 'repository/produto_repository.dart';
export 'repository/pedido_repository.dart';
export 'repository/documento_fiscal_repository.dart';
export 'repository/servico_repository.dart';






