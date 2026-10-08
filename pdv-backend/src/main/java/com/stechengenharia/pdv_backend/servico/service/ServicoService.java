package com.stechengenharia.pdv_backend.servico.service;

import com.stechengenharia.pdv_backend.common.util.IvaUtil;
import com.stechengenharia.pdv_backend.configuracao.service.ConfiguracaoService;
import com.stechengenharia.pdv_backend.servico.dto.ServicoRequestDTO;
import com.stechengenharia.pdv_backend.servico.dto.ServicoResponseDTO;
import com.stechengenharia.pdv_backend.servico.entity.Servico;
import com.stechengenharia.pdv_backend.servico.exception.ServicoException.ServicoInativoException;
import com.stechengenharia.pdv_backend.servico.exception.ServicoException.ServicoNaoEncontradoException;
import com.stechengenharia.pdv_backend.servico.exception.ServicoException.ServicoNomeDuplicadoException;
import com.stechengenharia.pdv_backend.servico.repository.ServicoRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.util.List;
import java.util.stream.Collectors;

@Slf4j
@Service
@RequiredArgsConstructor
public class ServicoService {

    private final ServicoRepository servicoRepository;
    private final ConfiguracaoService configuracaoService;

    // ════════════════════════════════════════════════════════════════════════
    // CRIAR
    // ════════════════════════════════════════════════════════════════════════

    @Transactional
public ServicoResponseDTO criar(ServicoRequestDTO dto) {
    log.info("Criando serviço: {}", dto.nomeServico);

    if (servicoRepository.existsByNomeServicoIgnoreCase(dto.nomeServico)) {
        throw new ServicoNomeDuplicadoException(dto.nomeServico);
    }

    Servico servico = new Servico();
    servico.setNomeServico(dto.nomeServico);
    servico.setDescricao(dto.descricao);
    BigDecimal iva = configuracaoService.getIvaPercentual();
    servico.setPrecoSemIva(dto.precoUnitario);
    servico.setIvaAplicado(iva);
    servico.setPrecoUnitario(IvaUtil.comIva(dto.precoUnitario, iva));
    servico.setUnidade(dto.unidade);
    servico.setAtivo(true);
    servico.setSyncStatus("PENDING_CREATE"); // AuditableEntity já define, mas explícito

    servico = servicoRepository.save(servico);
    log.info("Serviço criado: id={}, nome={}", servico.getIdServico(), servico.getNomeServico());
    return toResponseDTO(servico);
}

    // ════════════════════════════════════════════════════════════════════════
    // ACTUALIZAR
    // ════════════════════════════════════════════════════════════════════════
@Transactional
public ServicoResponseDTO actualizar(Integer id, ServicoRequestDTO dto) {
    log.info("Actualizando serviço id={}", id);

    // era: buscarEntidade(id) → findById sem filtro deleted
    Servico servico = servicoRepository.findByIdServicoAndDeletedFalse(id)
            .orElseThrow(() -> new ServicoNaoEncontradoException(id));

    if (servicoRepository.existsByNomeServicoIgnoreCaseAndIdServicoNot(dto.nomeServico, id)) {
        throw new ServicoNomeDuplicadoException(dto.nomeServico);
    }

    servico.setNomeServico(dto.nomeServico);
    servico.setDescricao(dto.descricao);
    servico.setPrecoUnitario(dto.precoUnitario);
    servico.setUnidade(dto.unidade);
    // @PreUpdate do AuditableEntity muda syncStatus → PENDING_UPDATE automaticamente

    servico = servicoRepository.save(servico);
    log.info("Serviço id={} actualizado", id);
    return toResponseDTO(servico);
}

    // ════════════════════════════════════════════════════════════════════════
    // TOGGLE ACTIVO/INACTIVO  (em vez de delete físico)
    // ════════════════════════════════════════════════════════════════════════

    @Transactional
    public ServicoResponseDTO toggleAtivo(Integer id) {
        Servico servico = buscarEntidade(id);
        Boolean novoEstado = !servico.getAtivo();

        // UPDATE directo na BD — sem carregar a entidade completa duas vezes
        servicoRepository.updateAtivo(id, novoEstado);
        servico.setAtivo(novoEstado);

        log.info("Serviço id={} → ativo={}", id, novoEstado);
        return toResponseDTO(servico);
    }

    @Transactional
public void deletar(Integer id) {
    Servico servico = servicoRepository.findByIdServicoAndDeletedFalse(id)
            .orElseThrow(() -> new ServicoNaoEncontradoException(id));
    servico.setDeleted(true);
    servico.setAtivo(false);              // invisível no PDV também
    servico.setSyncStatus("PENDING_DELETE");
    servicoRepository.save(servico);
    log.info("Serviço id={} marcado como eliminado", id);
}

    // ════════════════════════════════════════════════════════════════════════
    // CONSULTAS
    // ════════════════════════════════════════════════════════════════════════

    @Transactional(readOnly = true)
    public ServicoResponseDTO buscarPorId(Integer id) {
        return toResponseDTO(buscarEntidade(id));
    }

    /** Lista todos os serviços (activos e inactivos) — para o painel de gestão. */
@Transactional(readOnly = true)
public List<ServicoResponseDTO> listarTodos() {
    return servicoRepository.findByDeletedFalse()           // era findAllByOrderByNomeServicoAsc
            .stream()
            .map(this::toResponseDTO)
            .collect(Collectors.toList());
}

@Transactional(readOnly = true)
public List<ServicoResponseDTO> listarAtivos() {
    return servicoRepository.findByAtivoTrueAndDeletedFalse() // era findByAtivoTrue
            .stream()
            .map(this::toResponseDTO)
            .collect(Collectors.toList());
}

    // ════════════════════════════════════════════════════════════════════════
    // MÉTODO PARA USO INTERNO (ex: PedidoService)
    // ════════════════════════════════════════════════════════════════════════

    /**
     * Valida que o serviço existe e está activo.
     * Lança ServicoNaoEncontradoException ou ServicoInativoException conforme o caso.
     * Chamado pelo PedidoService antes de adicionar um item de serviço ao pedido.
     */
    @Transactional(readOnly = true)
    public Servico validarServicoDisponivel(Integer idServico) {
        Servico servico = buscarEntidade(idServico);
        if (!servico.getAtivo()) {
            throw new ServicoInativoException(idServico);
        }
        return servico;
    }

    // ════════════════════════════════════════════════════════════════════════
    // PRIVADOS
    // ════════════════════════════════════════════════════════════════════════

private Servico buscarEntidade(Integer id) {
    return servicoRepository.findByIdServicoAndDeletedFalse(id) // era findById
            .orElseThrow(() -> new ServicoNaoEncontradoException(id));
}

    private ServicoResponseDTO toResponseDTO(Servico s) {
        return ServicoResponseDTO.of(
                s.getIdServico(),
                s.getNomeServico(),
                s.getDescricao(),
                s.getPrecoUnitario(),
                s.getPrecoSemIva(),
                s.getIvaAplicado(),
                s.getUnidade(),
                s.getAtivo()
        );
    }
}