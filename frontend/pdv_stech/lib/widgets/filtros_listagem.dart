import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

const _kPrimary = Color(0xFF1B2A6B);

enum EstadoFiltro { todos, ativos, inativos }

/// Barra de pesquisa por nome (igual à do catálogo).
class FiltroPesquisa extends StatelessWidget {
  const FiltroPesquisa({
    super.key,
    required this.controller,
    required this.hint,
    required this.onChanged,
    required this.onClear,
  });

  final TextEditingController controller;
  final String hint;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      onChanged: onChanged,
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: const Icon(Icons.search, color: _kPrimary),
        suffixIcon: controller.text.isNotEmpty
            ? IconButton(icon: const Icon(Icons.clear), onPressed: onClear)
            : null,
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}

/// Botão "Faixa de Preço" com modal de RangeSlider (igual ao do catálogo).
class FiltroPrecoRow extends StatelessWidget {
  const FiltroPrecoRow({
    super.key,
    required this.precoMin,
    required this.precoMax,
    required this.precoMaxAbsoluto,
    required this.onChanged,
  });

  final double precoMin;
  final double precoMax;
  final double precoMaxAbsoluto;
  final void Function(double min, double max) onChanged;

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat.compactCurrency(locale: 'pt_PT', symbol: 'MZN');
    final safeMin = precoMin.clamp(0.0, precoMaxAbsoluto);
    final safeMax = precoMax.clamp(safeMin, precoMaxAbsoluto);
    final ativo = safeMin > 0 || safeMax < precoMaxAbsoluto;

    return GestureDetector(
      onTap: () => _abrirModal(context),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: ativo ? _kPrimary : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: ativo ? _kPrimary : Colors.grey.shade300),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.tune, size: 15, color: ativo ? Colors.white : Colors.grey[600]),
          const SizedBox(width: 5),
          Text(
            ativo
                ? '${fmt.format(safeMin)} – ${fmt.format(safeMax)}'
                : 'Faixa de Preço',
            style: TextStyle(
              fontSize: 12,
              color: ativo ? Colors.white : Colors.grey[700],
              fontWeight: FontWeight.w500,
            ),
          ),
          if (ativo) ...[
            const SizedBox(width: 6),
            GestureDetector(
              onTap: () => onChanged(0, double.infinity),
              child: const Icon(Icons.close, size: 13, color: Colors.white),
            ),
          ],
        ]),
      ),
    );
  }

  void _abrirModal(BuildContext context) {
    if (precoMaxAbsoluto <= 0) return;
    double tempMin = precoMin.clamp(0.0, precoMaxAbsoluto);
    double tempMax = precoMax.clamp(tempMin, precoMaxAbsoluto);

    showModalBottomSheet(
      context: context,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => StatefulBuilder(
        builder: (ctx, setModal) {
          final fmt = NumberFormat.currency(locale: 'pt_PT', symbol: 'MZN');
          return Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Faixa de Preço',
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: _kPrimary)),
                const SizedBox(height: 12),
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Text(fmt.format(tempMin), style: const TextStyle(fontSize: 12)),
                  Text(fmt.format(tempMax), style: const TextStyle(fontSize: 12)),
                ]),
                RangeSlider(
                  values: RangeValues(tempMin, tempMax),
                  min: 0,
                  max: precoMaxAbsoluto,
                  divisions: (precoMaxAbsoluto / 100).ceil().clamp(1, 100),
                  activeColor: _kPrimary,
                  inactiveColor: _kPrimary.withOpacity(0.15),
                  onChanged: (v) => setModal(() {
                    tempMin = v.start;
                    tempMax = v.end;
                  }),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: _kPrimary),
                    onPressed: () {
                      onChanged(tempMin, tempMax);
                      Navigator.pop(ctx);
                    },
                    child: const Text('Aplicar',
                        style: TextStyle(color: Colors.white)),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// Botão de selecção múltipla (categorias / marcas) com modal de checkboxes.
class FiltroSelecaoMultipla extends StatelessWidget {
  const FiltroSelecaoMultipla({
    super.key,
    required this.rotulo,
    required this.icone,
    required this.opcoes,
    required this.selecionados,
    required this.onChanged,
  });

  final String rotulo;
  final IconData icone;
  final Map<int, String> opcoes;
  final Set<int> selecionados;
  final ValueChanged<Set<int>> onChanged;

  @override
  Widget build(BuildContext context) {
    final ativo = selecionados.isNotEmpty;
    return GestureDetector(
      onTap: () => _abrirModal(context),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: ativo ? _kPrimary : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: ativo ? _kPrimary : Colors.grey.shade300),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icone, size: 15, color: ativo ? Colors.white : Colors.grey[600]),
          const SizedBox(width: 5),
          Text(
            ativo ? '$rotulo (${selecionados.length})' : rotulo,
            style: TextStyle(
              fontSize: 12,
              color: ativo ? Colors.white : Colors.grey[700],
              fontWeight: FontWeight.w500,
            ),
          ),
          if (ativo) ...[
            const SizedBox(width: 6),
            GestureDetector(
              onTap: () => onChanged({}),
              child: const Icon(Icons.close, size: 13, color: Colors.white),
            ),
          ],
        ]),
      ),
    );
  }

  void _abrirModal(BuildContext context) {
    final temp = Set<int>.from(selecionados);
    final entradas = opcoes.entries.toList()
      ..sort((a, b) => a.value.toLowerCase().compareTo(b.value.toLowerCase()));

    showModalBottomSheet(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => StatefulBuilder(
        builder: (ctx, setModal) => ConstrainedBox(
          constraints: BoxConstraints(
              maxHeight: MediaQuery.of(ctx).size.height * 0.7),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Expanded(
                    child: Text(rotulo,
                        style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: _kPrimary)),
                  ),
                  TextButton(
                    onPressed: () => setModal(temp.clear),
                    child: const Text('Limpar'),
                  ),
                ]),
                Flexible(
                  child: ListView(
                    shrinkWrap: true,
                    children: entradas
                        .map((e) => CheckboxListTile(
                              dense: true,
                              contentPadding: EdgeInsets.zero,
                              activeColor: _kPrimary,
                              title: Text(e.value,
                                  style: const TextStyle(fontSize: 13)),
                              value: temp.contains(e.key),
                              onChanged: (v) => setModal(() =>
                                  v == true ? temp.add(e.key) : temp.remove(e.key)),
                            ))
                        .toList(),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: _kPrimary),
                    onPressed: () {
                      onChanged(Set<int>.from(temp));
                      Navigator.pop(ctx);
                    },
                    child: const Text('Aplicar',
                        style: TextStyle(color: Colors.white)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Chips Todos / Ativos / Inativos.
class FiltroEstadoChips extends StatelessWidget {
  const FiltroEstadoChips({
    super.key,
    required this.selecionado,
    required this.onChanged,
  });

  final EstadoFiltro selecionado;
  final ValueChanged<EstadoFiltro> onChanged;

  @override
  Widget build(BuildContext context) {
    const rotulos = {
      EstadoFiltro.todos: 'Todos',
      EstadoFiltro.ativos: 'Ativos',
      EstadoFiltro.inativos: 'Inativos',
    };
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: rotulos.entries.map((e) {
        final sel = selecionado == e.key;
        return Padding(
          padding: const EdgeInsets.only(right: 4),
          child: ChoiceChip(
            label: Text(e.value),
            selected: sel,
            selectedColor: _kPrimary,
            visualDensity: VisualDensity.compact,
            labelStyle: TextStyle(
              fontSize: 11,
              color: sel ? Colors.white : Colors.grey[700],
            ),
            onSelected: (_) => onChanged(e.key),
          ),
        );
      }).toList(),
    );
  }
}