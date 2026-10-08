package com.stechengenharia.pdv_backend.produto.dto;

import lombok.Data;
import java.math.BigDecimal;
import java.time.LocalDateTime;
import java.util.List;

@Data
public class ProdutoResponseDTO {
    private Integer idProduto;
    private String nomeProduto;
    private String descricao;
    private BigDecimal preco;          // com IVA
    private BigDecimal precoSemIva;
    private BigDecimal ivaAplicado;
    private Integer quantidadeEstoque;
    private BigDecimal precoPromocional;
        private List<Integer> marcas; // ✅ ADICIONE ESTA LINHA
        
    // ✅ MUDANÇA: Integer → Short
    private Short ativo;
    
    private LocalDateTime dataCadastro;
    private List<Integer> categorias;
    private String imagemPrincipalUrl;
}