package com.stechengenharia.pdv_backend.servico.dto;

import java.math.BigDecimal;

/**
 * Resposta devolvida em todas as operações de serviço.
 */
public class ServicoResponseDTO {

    public Integer    idServico;
    public String     nomeServico;
    public String     descricao;
    public BigDecimal precoUnitario;
    public BigDecimal precoSemIva;
    public BigDecimal ivaAplicado;
    public String     unidade;
    public Boolean    ativo;

    // ─── Factory ──────────────────────────────────────────────────────────────

    public static ServicoResponseDTO of(
            Integer idServico,
            String nomeServico,
            String descricao,
            BigDecimal precoUnitario,
            BigDecimal precoSemIva,
            BigDecimal ivaAplicado,
            String unidade,
            Boolean ativo) {

        ServicoResponseDTO dto = new ServicoResponseDTO();
        dto.idServico     = idServico;
        dto.nomeServico   = nomeServico;
        dto.descricao     = descricao;
        dto.precoUnitario = precoUnitario;
        dto.precoSemIva   = precoSemIva;
        dto.ivaAplicado   = ivaAplicado;
        dto.unidade       = unidade;
        dto.ativo         = ativo;
        return dto;
    }
}