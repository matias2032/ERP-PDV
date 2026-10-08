import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:api_compartilhado/api_compartilhado.dart';
import '../theme/app_theme.dart';

/// Mostra "IVA 16% → Preço final: 34,80 MZN" por baixo do campo de preço.
class PrecoIvaPreview extends StatelessWidget {
  final double? precoSemIva;
  const PrecoIvaPreview({super.key, required this.precoSemIva});

  @override
  Widget build(BuildContext context) {
    final iva = ConfiguracaoService.instance.ivaPercentual;
    final fmt = NumberFormat.currency(locale: 'pt_PT', symbol: 'MZN');
    final c = context.cores;
    final base = precoSemIva ?? 0;
    final final_ = IvaUtil.comIva(base, iva);

    return Container(
      margin: const EdgeInsets.only(top: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: c.infoFundo,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(children: [
        Icon(Icons.percent_rounded, size: 14, color: c.info),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            'IVA ${iva.toStringAsFixed(iva % 1 == 0 ? 0 : 2)}% · '
            'Preço final: ${fmt.format(final_)}',
            style: TextStyle(fontSize: 12, color: c.info, fontWeight: FontWeight.w600),
          ),
        ),
      ]),
    );
  }
}