import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:api_compartilhado/api_compartilhado.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:api_compartilhado/services/pdf_service.dart';
import 'devolucao_troca_screen.dart';

// ── Cores STech Engenharia ────────────────────────────────────────────────────
const _kVermelho = Color(0xFFC8102E);
const _kAzul = Color(0xFF1B2A6B);
const _kBranco = Colors.white;
const _kCinzaClaro = Color(0xFFF4F5F7);
const _kCinzaTexto = Color(0xFF6B7280);

class DetalhesPedidoCreditoScreen extends StatefulWidget {
  final PedidoModel pedido;

  const DetalhesPedidoCreditoScreen({
    super.key,
    required this.pedido,
  });

  @override
  State<DetalhesPedidoCreditoScreen> createState() =>
      _DetalhesPedidoCreditoScreenState();
}

class _DetalhesPedidoCreditoScreenState
    extends State<DetalhesPedidoCreditoScreen> {
  final _currencyFmt = NumberFormat.currency(locale: 'pt_PT', symbol: 'MZN');
  final _dateFmt = DateFormat('dd/MM/yyyy');

  late PedidoModel _pedido;

  bool _carregando = true;
  bool _operacaoEmAndamento = false;
  String? _erroLocal;
  ClienteModel? _cliente;
bool _carregandoCliente = false;

  @override
  void initState() {
    super.initState();
    _pedido = widget.pedido;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _carregar();
    });
  }

  Future<void> _carregar() async {
    if (mounted) {
      setState(() {
        _carregando = true;
        _erroLocal = null;
      });
    }

    try {
      final provider = context.read<PedidoProvider>();

await provider.carregarTiposPagamento();

// Parcelas desactivadas por enquanto.
// await provider.carregarParcelas(_pedido.idPedido);

await provider.carregarPagamentosCredito(_pedido.idPedido);

_sincronizarPedidoDoProvider();
await _carregarCliente();
    } catch (e) {
      _erroLocal = e.toString();
    } finally {
      if (mounted) {
        setState(() => _carregando = false);
      }
    }
  }

  void _sincronizarPedidoDoProvider() {
    final provider = context.read<PedidoProvider>();

    PedidoModel? actualizado;

    final actual = provider.pedidoActual;
    if (actual != null && actual.idPedido == _pedido.idPedido) {
      actualizado = actual;
    } else {
      try {
        actualizado = provider.pedidos.firstWhere(
          (p) => p.idPedido == _pedido.idPedido,
        );
      } catch (_) {}
    }

    if (actualizado != null) {
      _pedido = actualizado;
    }
  }

Future<void> _carregarCliente() async {
  if (_cliente != null || _pedido.idCliente == null) return;

  if (mounted) {
    setState(() => _carregandoCliente = true);
  }

  try {
    final service = ClienteService(
      baseUrl: ApiConfig.baseUrl,
      httpClient: http.Client(),
    );

    final cliente = await service.buscarPorId(_pedido.idCliente!);

    if (mounted) {
      setState(() => _cliente = cliente);
    }
  } catch (_) {
    // silencioso — mantém fallback para ID
  } finally {
    if (mounted) {
      setState(() => _carregandoCliente = false);
    }
  }
}



  double _totalPagoEfetivo(List<PagamentoCreditoModel> pagamentos) {
    final somaPagamentos = pagamentos.fold<double>(
      0,
      (soma, p) => soma + p.valorPago,
    );

    return somaPagamentos > _pedido.valorPago
        ? somaPagamentos
        : _pedido.valorPago;
  }

  double _saldoEfetivo(List<PagamentoCreditoModel> pagamentos) {
    final saldo = _pedido.total - _totalPagoEfetivo(pagamentos);
    return saldo < 0 ? 0 : saldo;
  }

  double _progressoPagamento(List<PagamentoCreditoModel> pagamentos) {
    if (_pedido.total <= 0) return 0;

    return (_totalPagoEfetivo(pagamentos) / _pedido.total)
        .clamp(0.0, 1.0)
        .toDouble();
  }

  bool _pedidoVencido() {
    if (_pedido.pagamentoPago) return false;

    final vencimento = _pedido.dataVencimentoCredito;
    if (vencimento == null) return false;

    final hoje = DateTime.now();
    final hojeLimpo = DateTime(hoje.year, hoje.month, hoje.day);
    final vencLimpo = DateTime(
      vencimento.year,
      vencimento.month,
      vencimento.day,
    );

    return vencLimpo.isBefore(hojeLimpo);
  }

  Future<void> _abrirDialogoPagamento({
    // required List<ParcelaCreditoModel> parcelas,
    required double saldoAtual,
  }) async {
    if (_operacaoEmAndamento) return;

    if (saldoAtual <= 0) {
      _snack('Esta dívida já está liquidada.', Colors.green);
      return;
    }

    final provider = context.read<PedidoProvider>();

    if (provider.tiposPagamento.isEmpty) {
      await provider.carregarTiposPagamento();
    }

    final tiposPagamento = provider.tiposPagamento;
    if (tiposPagamento.isEmpty) {
      _snack('Nenhum método de pagamento disponível.', _kVermelho);
      return;
    }

    int? idTipoPagamento = tiposPagamento.first.idTipoPagamento;
// Parcelas desactivadas por enquanto.
// ParcelaCreditoModel? parcelaSelecionada = _proximaParcelaPendente(parcelas);

    final valorCtrl = TextEditingController();
    final obsCtrl = TextEditingController();

    String? erro;

    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            final valor = double.tryParse(
                  valorCtrl.text.replaceAll(',', '.'),
                ) ??
                0.0;

            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              title: const Text(
                'Registar pagamento',
                style: TextStyle(
                  color: _kAzul,
                  fontWeight: FontWeight.w700,
                ),
              ),
              content: SizedBox(
                width: 460,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _DialogInfoBox(
                        icon: Icons.account_balance_wallet_outlined,
                        texto:
                            'Saldo actual: ${_currencyFmt.format(saldoAtual)}',
                        cor: _kAzul,
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: valorCtrl,
                        keyboardType:
                            const TextInputType.numberWithOptions(decimal: true),
                        decoration: _dialogInputDecoration(
                          'Valor pago',
                          prefixText: 'MZN  ',
                        ),
                        onChanged: (_) => setDialogState(() {}),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<int>(
                        value: idTipoPagamento,
                        decoration:
                            _dialogInputDecoration('Método de pagamento'),
                        items: tiposPagamento
                            .map(
                              (t) => DropdownMenuItem<int>(
                                value: t.idTipoPagamento,
                                child: Text(t.tipoPagamento),
                              ),
                            )
                            .toList(),
                        onChanged: (v) {
                          setDialogState(() => idTipoPagamento = v);
                        },
                      ),
                      // const SizedBox(height: 12),
                      // DropdownButtonFormField<ParcelaCreditoModel?>(
                      //   value: parcelaSelecionada,
                      //   decoration: _dialogInputDecoration(
                      //     'Parcela associada',
                      //   ),
                      //   items: [
                      //     const DropdownMenuItem<ParcelaCreditoModel?>(
                      //       value: null,
                      //       child: Text('Pagamento geral da dívida'),
                      //     ),
                      //     ...parcelas.map(
                      //       (p) => DropdownMenuItem<ParcelaCreditoModel?>(
                      //         value: p,
                      //         child: Text(
                      //           'Parcela ${p.numeroParcela} — '
                      //           '${_currencyFmt.format(p.saldoParcela ?? (p.valorParcela - p.valorPago))}',
                      //         ),
                      //       ),
                      //     ),
                      //   ],
                      //   onChanged: (v) {
                      //     setDialogState(() => parcelaSelecionada = v);
                      //   },
                      // ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: obsCtrl,
                        maxLines: 2,
                        decoration: _dialogInputDecoration(
                          'Observações (opcional)',
                        ),
                      ),
                      const SizedBox(height: 10),
                      _DialogInfoBox(
                        icon: Icons.receipt_long_outlined,
                        texto:
                            'Será gerado um recibo associado à factura principal da dívida.',
                        cor: Colors.green,
                      ),
                      if (erro != null) ...[
                        const SizedBox(height: 10),
                        _DialogInfoBox(
                          icon: Icons.warning_amber_rounded,
                          texto: erro!,
                          cor: _kVermelho,
                        ),
                      ],
                      if (valor > saldoAtual) ...[
                        const SizedBox(height: 10),
                        _DialogInfoBox(
                          icon: Icons.info_outline,
                          texto:
                              'O valor informado excede o saldo actual. Ajuste antes de confirmar.',
                          cor: Colors.orange,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text(
                    'Cancelar',
                    style: TextStyle(color: _kCinzaTexto),
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: () {
                    final valorInformado = double.tryParse(
                          valorCtrl.text.replaceAll(',', '.'),
                        ) ??
                        0.0;

                    if (valorInformado <= 0) {
                      setDialogState(() {
                        erro = 'Informe um valor maior que zero.';
                      });
                      return;
                    }

                    if (valorInformado > saldoAtual) {
                      setDialogState(() {
                        erro = 'O valor pago não pode exceder o saldo actual.';
                      });
                      return;
                    }

                    if (idTipoPagamento == null) {
                      setDialogState(() {
                        erro = 'Seleccione o método de pagamento.';
                      });
                      return;
                    }

                    Navigator.pop(ctx, true);
                  },
                  icon: const Icon(Icons.check_rounded),
                  label: const Text('Confirmar pagamento'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _kAzul,
                    foregroundColor: _kBranco,
                  ),
                ),
              ],
            );
          },
        );
      },
    );

    if (confirmar != true) {
      valorCtrl.dispose();
      obsCtrl.dispose();
      return;
    }

    final valorPago = double.tryParse(
          valorCtrl.text.replaceAll(',', '.'),
        ) ??
        0.0;

    final observacoes = obsCtrl.text.trim().nullIfEmpty;

    valorCtrl.dispose();
    obsCtrl.dispose();

    setState(() => _operacaoEmAndamento = true);

    try {
      final result = await provider.registarPagamentoCredito(
        _pedido.idPedido,
        RegistarPagamentoCreditoRequestModel(
       idParcela: null, // Parcelas desactivadas por enquanto.
idTipoPagamento: idTipoPagamento!,
idUsuario: SessaoService.instance.idUsuario,
valorPago: valorPago,
observacoes: observacoes ?? 'Pagamento parcial da dívida',
        ),
      );

      if (!mounted) return;

      if (result != null && provider.errorMessage == null) {
        _snack('Pagamento registado com sucesso.', Colors.green);
        await _carregar();
      } else {
        _snack(
          provider.errorMessage ?? 'Não foi possível registar o pagamento.',
          _kVermelho,
        );
      }
    } finally {
      if (mounted) setState(() => _operacaoEmAndamento = false);
    }
  }

  Future<DocumentoFiscalModel> _buscarDocumentoFiscal(int idDocumento) async {
  final uri = Uri.parse('${ApiConfig.documentosFiscaisUrl}/$idDocumento');

  final response = await http
      .get(uri, headers: ApiConfig.defaultHeaders)
      .timeout(ApiConfig.timeout);

  if (response.statusCode != 200) {
    throw Exception(
      'Não foi possível buscar documento fiscal #$idDocumento. '
      'HTTP ${response.statusCode}: ${response.body}',
    );
  }

  final json = jsonDecode(response.body) as Map<String, dynamic>;
  return DocumentoFiscalModel.fromJson(json);
}

Future<ClienteModel> _buscarClienteDoPedido() async {
  if (_cliente != null) return _cliente!;

  final idCliente = _pedido.idCliente;

  if (idCliente == null) {
    throw Exception('Este pedido não tem cliente associado.');
  }

  final uri = Uri.parse('${ApiConfig.clientesUrl}/$idCliente');

  final response = await http
      .get(uri, headers: ApiConfig.defaultHeaders)
      .timeout(ApiConfig.timeout);

  if (response.statusCode != 200) {
    throw Exception(
      'Não foi possível buscar cliente #$idCliente. '
      'HTTP ${response.statusCode}: ${response.body}',
    );
  }

  final json = jsonDecode(response.body) as Map<String, dynamic>;
  return ClienteModel.fromJson(json);
}

String _nomeTipoPagamento(int idTipoPagamento) {
  final provider = context.read<PedidoProvider>();

  try {
    return provider.tiposPagamento
        .firstWhere((t) => t.idTipoPagamento == idTipoPagamento)
        .tipoPagamento;
  } catch (_) {
    return 'Pagamento #$idTipoPagamento';
  }
}

Future<void> _abrirFacturaCredito() async {
  if (_operacaoEmAndamento) return;

  final idDocumento = _pedido.idDocumentoFacturaCredito;

  if (idDocumento == null || idDocumento == 0) {
    _snack(
      'Factura ainda não disponível. Sincronize o pedido primeiro.',
      Colors.orange,
    );
    return;
  }

  setState(() => _operacaoEmAndamento = true);

  try {
    final documentoFiscal = await _buscarDocumentoFiscal(idDocumento);
    final cliente = await _buscarClienteDoPedido();

    final docPdf = DocumentoPdfModel.deApiModel(
      apiModel: documentoFiscal,
      pedido: _pedido,
      cliente: cliente,
      tipoPagamento: 'Crédito',
      prazoPagamento: 'Venda a crédito',
    );

    final file = await PdfService.instance.gerarDocumentoFiscal(docPdf);
    await PdfService.instance.abrirPdf(file);
  } catch (e) {
    if (mounted) {
      _snack('Erro ao abrir factura: $e', _kVermelho);
    }
  } finally {
    if (mounted) {
      setState(() => _operacaoEmAndamento = false);
    }
  }
}

/// Restrição temporária (decisão pendente): só permitido quando
/// statusPagamento == PENDENTE — decidido no botão que chama este método.
Future<void> _abrirDevolucao() async {
  if (_operacaoEmAndamento) return;

  final idDocumento = _pedido.idDocumentoFacturaCredito;

  if (idDocumento == null || idDocumento == 0) {
    _snack(
      'Factura ainda não disponível. Sincronize o pedido primeiro.',
      Colors.orange,
    );
    return;
  }

  final resultado = await Navigator.push<dynamic>(
    context,
    MaterialPageRoute(
      builder: (_) => DevolucaoTrocaScreen(
        idPedido: _pedido.idPedido,
        idDocumentoOrigem: idDocumento,
        pedidoInicial: _pedido,
      ),
    ),
  );

  if (resultado != null && mounted) {
    await _carregar();
  }
}

double _calcularSaldoAnteriorDoPagamento(
  PagamentoCreditoModel pagamento,
  List<PagamentoCreditoModel> pagamentos,
) {
  final ordenados = [...pagamentos]
    ..sort((a, b) => a.dataPagamento.compareTo(b.dataPagamento));

  double pagoAntes = 0;

  for (final p in ordenados) {
    if (p.idPagamentoCredito == pagamento.idPagamentoCredito) {
      break;
    }

    pagoAntes += p.valorPago;
  }

  final saldoAnterior = _pedido.total - pagoAntes;

  return saldoAnterior < 0 ? 0 : saldoAnterior;
}

Future<void> _abrirReciboCredito(
  PagamentoCreditoModel pagamento,
  List<PagamentoCreditoModel> pagamentos,
  // List<ParcelaCreditoModel> parcelas,
) async {
  if (_operacaoEmAndamento) return;

  final idRecibo = pagamento.idDocumentoRecibo;
  final idFactura = _pedido.idDocumentoFacturaCredito;

  if (idFactura == null || idFactura == 0) {
    _snack(
      'Factura principal ainda não disponível.',
      Colors.orange,
    );
    return;
  }

  if (idRecibo == null || idRecibo == 0) {
    _snack(
      'Recibo ainda não disponível. Sincronize o pagamento primeiro.',
      Colors.orange,
    );
    return;
  }

  setState(() => _operacaoEmAndamento = true);

  try {
    final facturaFiscal = await _buscarDocumentoFiscal(idFactura);
    final reciboFiscal = await _buscarDocumentoFiscal(idRecibo);
    final cliente = await _buscarClienteDoPedido();

    final saldoAnterior = _calcularSaldoAnteriorDoPagamento(
      pagamento,
      pagamentos,
    );

    final saldoRemanescente = (saldoAnterior - pagamento.valorPago) < 0
        ? 0.0
        : saldoAnterior - pagamento.valorPago;

    // ParcelaCreditoModel? parcela;

    // if (pagamento.idParcela != null) {
    //   try {
    //     parcela = parcelas.firstWhere(
    //       (p) => p.idParcela == pagamento.idParcela,
    //     );
    //   } catch (_) {}
    // }

    final reciboPdf = ReciboCreditoPdfModel.deApiModel(
      apiModel: reciboFiscal,
      referenciaFactura: facturaFiscal.referencia,
      pedido: _pedido,
      cliente: cliente,
      pagamento: pagamento,
      tipoPagamento: _nomeTipoPagamento(pagamento.idTipoPagamento),
      saldoAnterior: saldoAnterior,
      saldoRemanescente: saldoRemanescente,
      // numeroParcela: parcela?.numeroParcela,
      // totalParcelas: parcelas.isEmpty ? null : parcelas.length,
      observacoes: pagamento.observacoes,
    );

    final file = await PdfService.instance.gerarReciboCredito(reciboPdf);
    await PdfService.instance.abrirPdf(file);
  } catch (e) {
    if (mounted) {
      _snack('Erro ao abrir recibo: $e', _kVermelho);
    }
  } finally {
    if (mounted) {
      setState(() => _operacaoEmAndamento = false);
    }
  }
}



  // Future<void> _abrirDialogoParcelas({
  //   required List<ParcelaCreditoModel> parcelas,
  //   required double saldoAtual,
  // }) async {
  //   if (_operacaoEmAndamento) return;

  //   if (saldoAtual <= 0) {
  //     _snack('Esta dívida já está liquidada.', Colors.green);
  //     return;
  //   }

  //   int numeroParcelas = 3;
  //   DateTime primeiroVencimento =
  //       DateTime.now().add(const Duration(days: 30));

  //   String? erro;

  //   final confirmar = await showDialog<bool>(
  //     context: context,
  //     builder: (ctx) {
  //       return StatefulBuilder(
  //         builder: (ctx, setDialogState) {
  //           return AlertDialog(
  //             shape: RoundedRectangleBorder(
  //               borderRadius: BorderRadius.circular(14),
  //             ),
  //             title: const Text(
  //               'Criar parcelas',
  //               style: TextStyle(
  //                 color: _kAzul,
  //                 fontWeight: FontWeight.w700,
  //               ),
  //             ),
  //             content: SizedBox(
  //               width: 440,
  //               child: Column(
  //                 mainAxisSize: MainAxisSize.min,
  //                 children: [
  //                   _DialogInfoBox(
  //                     icon: Icons.account_balance_wallet_outlined,
  //                     texto:
  //                         'Saldo a parcelar: ${_currencyFmt.format(saldoAtual)}',
  //                     cor: _kAzul,
  //                   ),
  //                   if (parcelas.isNotEmpty) ...[
  //                     const SizedBox(height: 10),
  //                     _DialogInfoBox(
  //                       icon: Icons.warning_amber_rounded,
  //                       texto:
  //                           'Esta dívida já possui parcelas. Criar novas parcelas pode substituir ou sobrepor o plano actual, conforme a regra do repository/backend.',
  //                       cor: Colors.orange,
  //                     ),
  //                   ],
  //                   const SizedBox(height: 12),
  //                   DropdownButtonFormField<int>(
  //                     value: numeroParcelas,
  //                     decoration:
  //                         _dialogInputDecoration('Número de parcelas'),
  //                     items: List.generate(12, (i) => i + 1)
  //                         .map(
  //                           (n) => DropdownMenuItem<int>(
  //                             value: n,
  //                             child: Text('$n parcela(s)'),
  //                           ),
  //                         )
  //                         .toList(),
  //                     onChanged: (v) {
  //                       if (v == null) return;
  //                       setDialogState(() => numeroParcelas = v);
  //                     },
  //                   ),
  //                   const SizedBox(height: 12),
  //                   InkWell(
  //                     borderRadius: BorderRadius.circular(10),
  //                     onTap: () async {
  //                       final data = await showDatePicker(
  //                         context: ctx,
  //                         initialDate: primeiroVencimento,
  //                         firstDate: DateTime.now(),
  //                         lastDate: DateTime.now().add(
  //                           const Duration(days: 3650),
  //                         ),
  //                       );

  //                       if (data != null) {
  //                         setDialogState(() => primeiroVencimento = data);
  //                       }
  //                     },
  //                     child: InputDecorator(
  //                       decoration: _dialogInputDecoration(
  //                         'Primeiro vencimento',
  //                       ),
  //                       child: Row(
  //                         mainAxisAlignment: MainAxisAlignment.spaceBetween,
  //                         children: [
  //                           Text(_dateFmt.format(primeiroVencimento)),
  //                           const Icon(
  //                             Icons.calendar_month_outlined,
  //                             color: _kAzul,
  //                           ),
  //                         ],
  //                       ),
  //                     ),
  //                   ),
  //                   const SizedBox(height: 12),
  //                   _PreviewParcelas(
  //                     total: saldoAtual,
  //                     numeroParcelas: numeroParcelas,
  //                     primeiroVencimento: primeiroVencimento,
  //                     currencyFmt: _currencyFmt,
  //                     dateFmt: _dateFmt,
  //                   ),
  //                   if (erro != null) ...[
  //                     const SizedBox(height: 10),
  //                     _DialogInfoBox(
  //                       icon: Icons.warning_amber_rounded,
  //                       texto: erro!,
  //                       cor: _kVermelho,
  //                     ),
  //                   ],
  //                 ],
  //               ),
  //             ),
  //             actions: [
  //               TextButton(
  //                 onPressed: () => Navigator.pop(ctx, false),
  //                 child: const Text(
  //                   'Cancelar',
  //                   style: TextStyle(color: _kCinzaTexto),
  //                 ),
  //               ),
  //               ElevatedButton.icon(
  //                 onPressed: () {
  //                   if (numeroParcelas <= 0) {
  //                     setDialogState(() {
  //                       erro = 'Informe um número válido de parcelas.';
  //                     });
  //                     return;
  //                   }

  //                   Navigator.pop(ctx, true);
  //                 },
  //                 icon: const Icon(Icons.check_rounded),
  //                 label: const Text('Criar parcelas'),
  //                 style: ElevatedButton.styleFrom(
  //                   backgroundColor: _kAzul,
  //                   foregroundColor: _kBranco,
  //                 ),
  //               ),
  //             ],
  //           );
  //         },
  //       );
  //     },
  //   );

  //   if (confirmar != true) return;

  //   setState(() => _operacaoEmAndamento = true);

  //   try {
  //     final provider = context.read<PedidoProvider>();

  //     final parcelasRequest = _gerarParcelasRequest(
  //       total: saldoAtual,
  //       numeroParcelas: numeroParcelas,
  //       primeiroVencimento: primeiroVencimento,
  //     );

  //     final criadas = await provider.criarParcelas(
  //       _pedido.idPedido,
  //       CriarParcelasRequestModel(parcelas: parcelasRequest),
  //     );

  //     if (!mounted) return;

  //     if (criadas.isNotEmpty && provider.errorMessage == null) {
  //       _snack('Parcelas criadas com sucesso.', Colors.green);
  //       await _carregar();
  //     } else {
  //       _snack(
  //         provider.errorMessage ?? 'Não foi possível criar as parcelas.',
  //         _kVermelho,
  //       );
  //     }
  //   } finally {
  //     if (mounted) setState(() => _operacaoEmAndamento = false);
  //   }
  // }

  // List<CriarParcelaItemRequestModel> _gerarParcelasRequest({
  //   required double total,
  //   required int numeroParcelas,
  //   required DateTime primeiroVencimento,
  // }) {
  //   final parcelas = <CriarParcelaItemRequestModel>[];

  //   final valorBase =
  //       double.parse((total / numeroParcelas).toStringAsFixed(2));

  //   double acumulado = 0;

  //   for (var i = 1; i <= numeroParcelas; i++) {
  //     final isUltima = i == numeroParcelas;

  //     final valor = isUltima
  //         ? double.parse((total - acumulado).toStringAsFixed(2))
  //         : valorBase;

  //     acumulado += valor;

  //     parcelas.add(
  //       CriarParcelaItemRequestModel(
  //         numeroParcela: i,
  //         valorParcela: valor,
  //         dataVencimento: DateTime(
  //           primeiroVencimento.year,
  //           primeiroVencimento.month + (i - 1),
  //           primeiroVencimento.day,
  //         ),
  //       ),
  //     );
  //   }

  //   return parcelas;
  // }

  // ParcelaCreditoModel? _proximaParcelaPendente(
  //   List<ParcelaCreditoModel> parcelas,
  // ) {
  //   final pendentes = parcelas
  //       .where((p) => p.statusParcela.toUpperCase() != 'PAGA')
  //       .toList()
  //     ..sort((a, b) => a.numeroParcela.compareTo(b.numeroParcela));

  //   return pendentes.isEmpty ? null : pendentes.first;
  // }

  InputDecoration _dialogInputDecoration(
    String label, {
    String? prefixText,
  }) {
    return InputDecoration(
      labelText: label,
      prefixText: prefixText,
      filled: true,
      fillColor: _kCinzaClaro,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 10,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: _kAzul.withOpacity(0.15)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: _kAzul.withOpacity(0.15)),
      ),
    );
  }

  void _snack(String mensagem, Color cor) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(mensagem),
        backgroundColor: cor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  void _pdfEmBreve(String tipo) {
    _snack(
      '$tipo será ligado na próxima etapa de documentos/PDF.',
      _kAzul,
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<PedidoProvider>();

// Parcelas desactivadas por enquanto.
// final parcelas = provider.parcelasCredito;
    final pagamentos = provider.pagamentosCredito;

    final totalPago = _totalPagoEfetivo(pagamentos);
    final saldo = _saldoEfetivo(pagamentos);
    final progresso = _progressoPagamento(pagamentos);

    return Scaffold(
      backgroundColor: _kCinzaClaro,
      appBar: _buildAppBar(),
      body: _carregando
          ? const Center(child: CircularProgressIndicator(color: _kAzul))
          : _erroLocal != null
              ? _ErroState(
                  erro: _erroLocal!,
                  onRecarregar: _carregar,
                )
              : RefreshIndicator(
                  color: _kAzul,
                  onRefresh: _carregar,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(14, 14, 14, 30),
                    children: [
                _ResumoCreditoCard(
  pedido: _pedido,
  totalPago: totalPago,
  saldo: saldo,
  progresso: progresso,
  vencido: _pedidoVencido(),
  currencyFmt: _currencyFmt,
  dateFmt: _dateFmt,
  carregandoCliente: _carregandoCliente,
  clienteLabel: _cliente?.nomeCompleto ??
      (_pedido.idCliente != null
          ? 'ID: ${_pedido.idCliente}'
          : 'Cliente não informado'),
),
                      const SizedBox(height: 12),
                      _FacturaPrincipalCard(
  pedido: _pedido,
  onAbrirFactura: _abrirFacturaCredito,
),
_AcoesCreditoCard(
  operacaoEmAndamento: _operacaoEmAndamento,
  saldo: saldo,
  podeDevolver: _pedido.statusPagamento == 'PENDENTE',
  onRegistarPagamento: () => _abrirDialogoPagamento(
    saldoAtual: saldo,
  ),
  onDevolver: _abrirDevolucao,
),
                      // const SizedBox(height: 12),
                      // _ParcelasCard(
                      //   parcelas: parcelas,
                      //   currencyFmt: _currencyFmt,
                      //   dateFmt: _dateFmt,
                      //   onCriarParcelas: () => _abrirDialogoParcelas(
                      //     parcelas: parcelas,
                      //     saldoAtual: saldo,
                      //   ),
                      // ),
                      const SizedBox(height: 12),
                    _PagamentosCard(
  pagamentos: pagamentos,
  currencyFmt: _currencyFmt,
  dateFmt: _dateFmt,
  onAbrirRecibo: (pagamento) => _abrirReciboCredito(
    pagamento,
    pagamentos,
    // parcelas,
  ),
),
                    ],
                  ),
                ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: _kAzul,
      foregroundColor: _kBranco,
      elevation: 0,
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: _kVermelho,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.receipt_long_rounded,
              color: _kBranco,
              size: 20,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Dívida — ${_pedido.referencia}',
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.3,
              ),
            ),
          ),
        ],
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh_rounded),
          tooltip: 'Recarregar',
          onPressed: _carregar,
        ),
        const SizedBox(width: 8),
      ],
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// Resumo
// ═════════════════════════════════════════════════════════════════════════════

class _ResumoCreditoCard extends StatelessWidget {
  final PedidoModel pedido;
  final double totalPago;
  final double saldo;
  final double progresso;
  final bool vencido;
  final NumberFormat currencyFmt;
  final DateFormat dateFmt;
  final String clienteLabel;
  final bool carregandoCliente;

  const _ResumoCreditoCard({
    required this.pedido,
    required this.totalPago,
    required this.saldo,
    required this.progresso,
    required this.vencido,
    required this.currencyFmt,
    required this.dateFmt,
    required this.clienteLabel,
    required this.carregandoCliente,
  });

  @override
  Widget build(BuildContext context) {
    return _CardBase(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const _SectionTitle(
                icon: Icons.account_balance_wallet_outlined,
                title: 'Resumo da dívida',
              ),
              const Spacer(),
              _StatusBadge(
                label: _statusLabel(pedido),
                color: _statusColor(pedido),
              ),
              if (vencido) ...[
                const SizedBox(width: 6),
                const _StatusBadge(
                  label: 'Vencido',
                  color: Colors.orange,
                ),
              ],
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _InfoMetric(
                  label: 'Total facturado',
                  value: currencyFmt.format(pedido.total),
                  icon: Icons.receipt_long_rounded,
                  color: _kAzul,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _InfoMetric(
                  label: 'Total pago',
                  value: currencyFmt.format(totalPago),
                  icon: Icons.payments_rounded,
                  color: Colors.green,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _InfoMetric(
                  label: 'Saldo',
                  value: currencyFmt.format(saldo),
                  icon: Icons.warning_amber_rounded,
                  color: saldo <= 0 ? Colors.green : _kVermelho,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: progresso,
              minHeight: 8,
              backgroundColor: _kCinzaClaro,
              color: progresso >= 1 ? Colors.green : _kAzul,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 14,
            runSpacing: 8,
            children: [
             if (carregandoCliente)
  const Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      SizedBox(
        width: 12,
        height: 12,
        child: CircularProgressIndicator(strokeWidth: 2),
      ),
      SizedBox(width: 6),
      Text(
        'A carregar cliente...',
        style: TextStyle(
          color: _kCinzaTexto,
          fontSize: 12,
        ),
      ),
    ],
  )
else
  _MiniInfo(
    icon: Icons.business_outlined,
    label: clienteLabel,
  ),
              _MiniInfo(
                icon: Icons.calendar_today_outlined,
                label:
                    'Abertura: ${_formatarData(pedido.dataAberturaCredito ?? pedido.dataPedido, dateFmt)}',
              ),
              _MiniInfo(
                icon: Icons.event_available_outlined,
                label:
                    'Vencimento: ${_formatarData(pedido.dataVencimentoCredito, dateFmt)}',
              ),
              _MiniInfo(
                icon: Icons.payments_outlined,
                label:
                    'Modalidade: ${_modalidadeLabel(pedido.modalidadeCredito)}',
              ),
            ],
          ),
          if (pedido.observacoesCredito?.trim().isNotEmpty == true) ...[
            const SizedBox(height: 12),
            _InfoBox(
              icon: Icons.info_outline,
              texto: pedido.observacoesCredito!,
              cor: _kAzul,
            ),
          ],
        ],
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// Factura
// ═════════════════════════════════════════════════════════════════════════════

class _FacturaPrincipalCard extends StatelessWidget {
  final PedidoModel pedido;
  final VoidCallback onAbrirFactura;

  const _FacturaPrincipalCard({
    required this.pedido,
    required this.onAbrirFactura,
  });

  @override
  Widget build(BuildContext context) {
    final temFactura = pedido.idDocumentoFacturaCredito != null;

    return _CardBase(
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(11),
            decoration: BoxDecoration(
              color: _kAzul.withOpacity(0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.description_outlined,
              color: _kAzul,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Factura principal',
                  style: TextStyle(
                    color: _kAzul,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  temFactura
                      ? 'Documento fiscal #${pedido.idDocumentoFacturaCredito}'
                      : 'Factura ainda pendente de emissão/sincronização',
                  style: TextStyle(
                    color: temFactura ? _kCinzaTexto : Colors.orange,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          OutlinedButton.icon(
            onPressed: temFactura ? onAbrirFactura : null,
            icon: const Icon(Icons.picture_as_pdf_outlined, size: 17),
            label: const Text('Factura'),
            style: OutlinedButton.styleFrom(
              foregroundColor: _kAzul,
              side: const BorderSide(color: _kAzul),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// Acções
// ═════════════════════════════════════════════════════════════════════════════

class _AcoesCreditoCard extends StatelessWidget {
  final bool operacaoEmAndamento;
  final double saldo;
  final bool podeDevolver;
  final VoidCallback onRegistarPagamento;
  final VoidCallback onDevolver;

  const _AcoesCreditoCard({
    required this.operacaoEmAndamento,
    required this.saldo,
    required this.podeDevolver,
    required this.onRegistarPagamento,
    required this.onDevolver,
  });

  @override
  Widget build(BuildContext context) {
    final liquidada = saldo <= 0;

    return _CardBase(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: _SectionTitle(
                  icon: Icons.tune_rounded,
                  title: 'Acções da dívida',
                ),
              ),
              ElevatedButton.icon(
                onPressed: operacaoEmAndamento || liquidada
                    ? null
                    : onRegistarPagamento,
                icon: const Icon(Icons.payments_outlined, size: 18),
                label: const Text('Registar pagamento'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _kAzul,
                  foregroundColor: _kBranco,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ],
          ),
          if (podeDevolver) ...[
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: operacaoEmAndamento ? null : onDevolver,
                icon: const Icon(Icons.assignment_return_outlined, size: 18),
                label: const Text('Devolver / Anular'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: _kVermelho,
                  side: const BorderSide(color: _kVermelho),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// Parcelas
// ═════════════════════════════════════════════════════════════════════════════

// class _ParcelasCard extends StatelessWidget {
//   final List<ParcelaCreditoModel> parcelas;
//   final NumberFormat currencyFmt;
//   final DateFormat dateFmt;
//   final VoidCallback onCriarParcelas;

//   const _ParcelasCard({
//     required this.parcelas,
//     required this.currencyFmt,
//     required this.dateFmt,
//     required this.onCriarParcelas,
//   });

//   @override
//   Widget build(BuildContext context) {
//     return _CardBase(
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           Row(
//             children: [
//               const _SectionTitle(
//                 icon: Icons.view_timeline_outlined,
//                 title: 'Parcelas',
//               ),
//               const Spacer(),
//               TextButton.icon(
//                 onPressed: onCriarParcelas,
//                 icon: const Icon(Icons.add_rounded, size: 17),
//                 label: const Text('Criar'),
//                 style: TextButton.styleFrom(foregroundColor: _kAzul),
//               ),
//             ],
//           ),
//           const SizedBox(height: 10),
//           if (parcelas.isEmpty)
//             const _EmptyBox(
//               icon: Icons.view_timeline_outlined,
//               text: 'Nenhuma parcela criada para esta dívida.',
//             )
//           else
//             Column(
//               children: parcelas
//                   .map(
//                     (p) => _LinhaParcela(
//                       parcela: p,
//                       currencyFmt: currencyFmt,
//                       dateFmt: dateFmt,
//                     ),
//                   )
//                   .toList(),
//             ),
//         ],
//       ),
//     );
//   }
// }

// class _LinhaParcela extends StatelessWidget {
//   final ParcelaCreditoModel parcela;
//   final NumberFormat currencyFmt;
//   final DateFormat dateFmt;

//   const _LinhaParcela({
//     required this.parcela,
//     required this.currencyFmt,
//     required this.dateFmt,
//   });

//   @override
//   Widget build(BuildContext context) {
//     final saldo = parcela.saldoParcela ??
//         (parcela.valorParcela - parcela.valorPago).clamp(0, double.infinity);

//     final status = parcela.statusParcela.toUpperCase();
//     final paga = status == 'PAGA';
//     final parcial = status == 'PARCIAL';

//     final cor = paga
//         ? Colors.green
//         : parcial
//             ? _kAzul
//             : _kVermelho;

//     return Container(
//       margin: const EdgeInsets.only(bottom: 8),
//       padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
//       decoration: BoxDecoration(
//         color: _kCinzaClaro,
//         borderRadius: BorderRadius.circular(10),
//         border: Border.all(color: const Color(0xFFE5E7EB)),
//       ),
//       child: Row(
//         children: [
//           CircleAvatar(
//             radius: 15,
//             backgroundColor: cor.withOpacity(0.10),
//             child: Text(
//               '${parcela.numeroParcela}',
//               style: TextStyle(
//                 color: cor,
//                 fontWeight: FontWeight.w800,
//                 fontSize: 12,
//               ),
//             ),
//           ),
//           const SizedBox(width: 10),
//           Expanded(
//             flex: 2,
//             child: _TextPair(
//               label: 'Vencimento',
//               value: dateFmt.format(parcela.dataVencimento),
//             ),
//           ),
//           Expanded(
//             flex: 2,
//             child: _TextPair(
//               label: 'Valor',
//               value: currencyFmt.format(parcela.valorParcela),
//             ),
//           ),
//           Expanded(
//             flex: 2,
//             child: _TextPair(
//               label: 'Pago',
//               value: currencyFmt.format(parcela.valorPago),
//             ),
//           ),
//           Expanded(
//             flex: 2,
//             child: _TextPair(
//               label: 'Saldo',
//               value: currencyFmt.format(saldo),
//               valueColor: saldo <= 0 ? Colors.green : _kVermelho,
//             ),
//           ),
//           _StatusBadge(
//             label: _statusParcelaLabel(parcela.statusParcela),
//             color: cor,
//           ),
//         ],
//       ),
//     );
//   }
// }

// ═════════════════════════════════════════════════════════════════════════════
// Pagamentos
// ═════════════════════════════════════════════════════════════════════════════

class _PagamentosCard extends StatelessWidget {
  final List<PagamentoCreditoModel> pagamentos;
  final NumberFormat currencyFmt;
  final DateFormat dateFmt;
final void Function(PagamentoCreditoModel pagamento) onAbrirRecibo;

  const _PagamentosCard({
    required this.pagamentos,
    required this.currencyFmt,
    required this.dateFmt,
    required this.onAbrirRecibo,
  });

  @override
  Widget build(BuildContext context) {
    return _CardBase(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionTitle(
            icon: Icons.payments_outlined,
            title: 'Pagamentos e recibos',
          ),
          const SizedBox(height: 10),
          if (pagamentos.isEmpty)
            const _EmptyBox(
              icon: Icons.payments_outlined,
              text: 'Nenhum pagamento registado nesta dívida.',
            )
          else
            Column(
              children: pagamentos
                  .map(
                    (p) => _LinhaPagamento(
  pagamento: p,
  currencyFmt: currencyFmt,
  dateFmt: dateFmt,
  onAbrirRecibo: onAbrirRecibo,
),
                  )
                  .toList(),
            ),
        ],
      ),
    );
  }
}

class _LinhaPagamento extends StatelessWidget {
  final PagamentoCreditoModel pagamento;
  final NumberFormat currencyFmt;
  final DateFormat dateFmt;
final void Function(PagamentoCreditoModel pagamento) onAbrirRecibo;

  const _LinhaPagamento({
    required this.pagamento,
    required this.currencyFmt,
    required this.dateFmt,
    required this.onAbrirRecibo,
  });

  @override
  Widget build(BuildContext context) {
    final temRecibo = pagamento.idDocumentoRecibo != null &&
        pagamento.idDocumentoRecibo != 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(
        color: _kCinzaClaro,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 15,
            backgroundColor: Colors.green.withOpacity(0.10),
            child: const Icon(
              Icons.check_rounded,
              color: Colors.green,
              size: 17,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            flex: 2,
            child: _TextPair(
              label: 'Data',
              value: dateFmt.format(pagamento.dataPagamento),
            ),
          ),
          Expanded(
            flex: 2,
            child: _TextPair(
              label: 'Valor pago',
              value: currencyFmt.format(pagamento.valorPago),
              valueColor: Colors.green,
            ),
          ),
          Expanded(
            flex: 2,
            child: _TextPair(
              label: 'Parcela',
              value: pagamento.idParcela != null
                  ? '#${pagamento.idParcela}'
                  : 'Geral',
            ),
          ),
          Expanded(
            flex: 2,
            child: _TextPair(
              label: 'Recibo',
              value: temRecibo
                  ? 'Doc. #${pagamento.idDocumentoRecibo}'
                  : 'Pendente',
              valueColor: temRecibo ? _kAzul : Colors.orange,
            ),
          ),
         IconButton(
  tooltip: 'Abrir recibo',
  onPressed: temRecibo ? () => onAbrirRecibo(pagamento) : null,
  icon: Icon(
    Icons.picture_as_pdf_outlined,
    color: temRecibo ? _kAzul : _kCinzaTexto,
  ),
),
        ],
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// Subwidgets comuns
// ═════════════════════════════════════════════════════════════════════════════

class _CardBase extends StatelessWidget {
  final Widget child;

  const _CardBase({required this.child});

  @override
  Widget build(BuildContext context) {
    return Card(
      color: _kBranco,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Color(0xFFE5E7EB)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: child,
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final IconData icon;
  final String title;

  const _SectionTitle({
    required this.icon,
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: _kAzul, size: 18),
        const SizedBox(width: 7),
        Text(
          title,
          style: const TextStyle(
            color: _kAzul,
            fontSize: 14,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

class _InfoMetric extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _InfoMetric({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 10,
      ),
      decoration: BoxDecoration(
        color: color.withOpacity(0.07),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.18)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: _kCinzaTexto,
                    fontSize: 11,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniInfo extends StatelessWidget {
  final IconData icon;
  final String label;

  const _MiniInfo({
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: _kCinzaTexto),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(
            color: _kCinzaTexto,
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}

class _TextPair extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;

  const _TextPair({
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: _kCinzaTexto,
            fontSize: 10,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: valueColor ?? _kAzul,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String label;
  final Color color;

  const _StatusBadge({
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _InfoBox extends StatelessWidget {
  final IconData icon;
  final String texto;
  final Color cor;

  const _InfoBox({
    required this.icon,
    required this.texto,
    required this.cor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 8,
      ),
      decoration: BoxDecoration(
        color: cor.withOpacity(0.07),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: cor.withOpacity(0.25)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 15, color: cor),
          const SizedBox(width: 7),
          Expanded(
            child: Text(
              texto,
              style: TextStyle(
                color: cor,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DialogInfoBox extends StatelessWidget {
  final IconData icon;
  final String texto;
  final Color cor;

  const _DialogInfoBox({
    required this.icon,
    required this.texto,
    required this.cor,
  });

  @override
  Widget build(BuildContext context) {
    return _InfoBox(
      icon: icon,
      texto: texto,
      cor: cor,
    );
  }
}

class _EmptyBox extends StatelessWidget {
  final IconData icon;
  final String text;

  const _EmptyBox({
    required this.icon,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 18,
      ),
      decoration: BoxDecoration(
        color: _kCinzaClaro,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        children: [
          Icon(icon, color: _kCinzaTexto, size: 34),
          const SizedBox(height: 8),
          Text(
            text,
            style: const TextStyle(
              color: _kCinzaTexto,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}

class _ErroState extends StatelessWidget {
  final String erro;
  final Future<void> Function() onRecarregar;

  const _ErroState({
    required this.erro,
    required this.onRecarregar,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline,
              color: _kVermelho,
              size: 52,
            ),
            const SizedBox(height: 12),
            Text(
              erro,
              textAlign: TextAlign.center,
              style: const TextStyle(color: _kVermelho),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: onRecarregar,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Tentar novamente'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _kAzul,
                foregroundColor: _kBranco,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PreviewParcelas extends StatelessWidget {
  final double total;
  final int numeroParcelas;
  final DateTime primeiroVencimento;
  final NumberFormat currencyFmt;
  final DateFormat dateFmt;

  const _PreviewParcelas({
    required this.total,
    required this.numeroParcelas,
    required this.primeiroVencimento,
    required this.currencyFmt,
    required this.dateFmt,
  });

  @override
  Widget build(BuildContext context) {
    final valorBase =
        double.parse((total / numeroParcelas).toStringAsFixed(2));

    final linhas = <Widget>[];
    double acumulado = 0;

    for (var i = 1; i <= numeroParcelas; i++) {
      final isUltima = i == numeroParcelas;

      final valor = isUltima
          ? double.parse((total - acumulado).toStringAsFixed(2))
          : valorBase;

      acumulado += valor;

      final data = DateTime(
        primeiroVencimento.year,
        primeiroVencimento.month + (i - 1),
        primeiroVencimento.day,
      );

      linhas.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Parcela $i',
                  style: const TextStyle(
                    color: _kCinzaTexto,
                    fontSize: 12,
                  ),
                ),
              ),
              Text(
                currencyFmt.format(valor),
                style: const TextStyle(
                  color: _kAzul,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                dateFmt.format(data),
                style: const TextStyle(
                  color: _kCinzaTexto,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: _kCinzaClaro,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Pré-visualização',
            style: TextStyle(
              color: _kAzul,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          ...linhas,
        ],
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// Helpers
// ═════════════════════════════════════════════════════════════════════════════

String _formatarData(DateTime? data, DateFormat fmt) {
  if (data == null) return '—';
  return fmt.format(data);
}

String _modalidadeLabel(String? modalidade) {
  return 'Sem parcelas';
}

String _statusLabel(PedidoModel pedido) {
  switch (pedido.statusPagamento.toUpperCase()) {
    case 'PAGO':
      return 'Pago';
    case 'PARCIAL':
      return 'Parcial';
    case 'PENDENTE':
      return 'Pendente';
    default:
      return pedido.statusPagamento;
  }
}

Color _statusColor(PedidoModel pedido) {
  switch (pedido.statusPagamento.toUpperCase()) {
    case 'PAGO':
      return Colors.green;
    case 'PARCIAL':
      return _kAzul;
    case 'PENDENTE':
      return _kVermelho;
    default:
      return _kCinzaTexto;
  }
}

String _statusParcelaLabel(String status) {
  switch (status.toUpperCase()) {
    case 'PAGA':
      return 'Paga';
    case 'PARCIAL':
      return 'Parcial';
    case 'PENDENTE':
      return 'Pendente';
    default:
      return status;
  }
}

extension _Str on String {
  String? get nullIfEmpty => trim().isEmpty ? null : trim();
}