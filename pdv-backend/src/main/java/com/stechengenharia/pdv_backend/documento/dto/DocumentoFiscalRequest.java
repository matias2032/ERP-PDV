package com.stechengenharia.pdv_backend.documento.dto;

import jakarta.validation.constraints.DecimalMin;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotEmpty;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;
import java.math.BigDecimal;
import java.util.List;

// ─── REQUEST ────────────────────────────────────────────────────────────────

public class DocumentoFiscalRequest {

    /**
     * Emitir um documento fiscal.
     * Reflecte os parâmetros da função PL/pgSQL emitir_documento_fiscal().
     */
    public record EmitirDocumentoRequest(

            @NotNull(message = "O id do pedido é obrigatório")
            Integer idPedido,

            @NotBlank(message = "O código do tipo de documento é obrigatório")
            @Size(max = 10)
            String codigoTipo,        // ex: "FAT", "COT", "REC", "NCO"

            @NotNull(message = "O id do utilizador é obrigatório")
            Long idUsuario,

            @NotBlank(message = "O código AT é obrigatório")
            @Size(max = 50)
            String codigoAt
    ) {}

    /**
     * Anular um documento já emitido.
     */
    public record AnularDocumentoRequest(

            @NotBlank(message = "O motivo da anulação é obrigatório")
            String motivoAnulacao
    ) {}


    public record EmitirDocumentoMultiplosRequest(

        @NotEmpty(message = "A lista de pedidos não pode estar vazia")
        List<@NotNull Integer> idsPedido,

        @NotBlank(message = "O código do tipo de documento é obrigatório")
        @Size(max = 10)
        String codigoTipo,

        @NotNull(message = "O id do utilizador é obrigatório")
        Long idUsuario,

// DEPOIS
        @NotBlank(message = "O código AT é obrigatório")
        @Size(max = 50)
        String codigoAt
) {}

    /**
     * Emitir uma Nota de Crédito (NCR) ou Nota de Débito (NDB) associada
     * a um documento de origem (id vem do path, não deste record).
     * Reflecte os parâmetros de emitir_nota_retificativa(...).
     */
public record ItemRetificadoRequest(
            String descricao,
            Integer quantidade,
            BigDecimal precoUnitario
    ) {}

public record EmitirNotaRetificativaRequest(

            @NotBlank(message = "O código do tipo de documento é obrigatório")
            @Size(max = 10)
            String codigoTipo,        // "NCR" ou "NDB"

            @NotNull(message = "O id do utilizador é obrigatório")
            Long idUsuario,

            @NotBlank(message = "O código AT é obrigatório")
            @Size(max = 50)
            String codigoAt,

            @NotBlank(message = "O motivo da retificação é obrigatório")
            String motivo,            // ERRO_PREENCHIMENTO | TROCA_PRODUTO | DEVOLUCAO | IVA_INCORRETO | OUTRO

            @NotNull(message = "O valor é obrigatório")
            @DecimalMin(value = "0.01", message = "O valor deve ser positivo")
            BigDecimal valor,

            String observacoes,

            // Vazio/nulo para ERRO_PREENCHIMENTO (anulação total).
            List<ItemRetificadoRequest> itensDevolvidos
    ) {}

    
    
}

