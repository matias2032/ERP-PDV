package com.stechengenharia.pdv_backend.produto.entity;

import com.stechengenharia.pdv_backend.common.entity.AuditableEntity;
import jakarta.persistence.*;
import lombok.AllArgsConstructor;
import lombok.NoArgsConstructor;
import lombok.Getter;
import lombok.Setter;

import java.math.BigDecimal;
import java.time.LocalDateTime;

@Entity
@Table(name = "produto")
@Getter @Setter @NoArgsConstructor @AllArgsConstructor
public class Produto extends AuditableEntity {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "id_produto")
    private Integer idProduto;

    @Column(name = "nome_produto", nullable = false, length = 200)
    private String nomeProduto;

    @Column(name = "descricao", columnDefinition = "TEXT")
    private String descricao;


    @Column(name = "preco", nullable = false, precision = 10, scale = 2)
    private BigDecimal preco;

    @Column(name = "preco_sem_iva", nullable = false, precision = 10, scale = 2)
    private BigDecimal precoSemIva;

    @Column(name = "iva_aplicado", nullable = false, precision = 5, scale = 2)
    private BigDecimal ivaAplicado;

    @Column(name = "quantidade_estoque", nullable = false)
    private Integer quantidadeEstoque = 0;

    @Column(name = "preco_promocional", precision = 10, scale = 2)
    private BigDecimal precoPromocional;

    @Column(name = "ativo", nullable = false)
    private Short ativo = 1;

    @Column(name = "data_cadastro", nullable = false, updatable = false)
    private LocalDateTime dataCadastro = LocalDateTime.now();

    // deleted herdado do AuditableEntity — ativo e deleted coexistem:
    // ativo = lógica de negócio (visível no PDV)
    // deleted = controlo de sync (eliminado pelo operador)

    @Override
    public boolean equals(Object o) {
        if (this == o) return true;
        if (!(o instanceof Produto)) return false;
        Produto that = (Produto) o;
        return idProduto != null && idProduto.equals(that.idProduto);
    }

    @Override
    public int hashCode() { return getClass().hashCode(); }
}