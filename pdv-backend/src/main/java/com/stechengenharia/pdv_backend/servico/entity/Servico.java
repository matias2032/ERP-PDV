package com.stechengenharia.pdv_backend.servico.entity;

import com.stechengenharia.pdv_backend.common.entity.AuditableEntity;
import jakarta.persistence.*;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;
import java.math.BigDecimal;

@Entity
@Table(name = "servico")
@Getter
@Setter
@NoArgsConstructor
public class Servico extends AuditableEntity {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "id_servico")
    private Integer idServico;

    @Column(name = "nome_servico", nullable = false, length = 150)
    private String nomeServico;

    @Column(name = "descricao", columnDefinition = "TEXT")
    private String descricao;

    /** Preço final (já com IVA) */
    @Column(name = "preco_unitario", nullable = false, precision = 12, scale = 2)
    private BigDecimal precoUnitario;

    @Column(name = "preco_sem_iva", nullable = false, precision = 12, scale = 2)
    private BigDecimal precoSemIva;

    @Column(name = "iva_aplicado", nullable = false, precision = 5, scale = 2)
    private BigDecimal ivaAplicado;

    @Column(name = "unidade", nullable = false, length = 50)
    private String unidade;

    // ativo = lógica de negócio (visível no PDV)
    // deleted herdado = controlo de sync (eliminado pelo operador)
    @Column(name = "ativo", nullable = false)
    private Boolean ativo = true;

    /** Construtor de referência mínima — mantido para compatibilidade com PedidoService */
    public Servico(Integer idServico) {
        this.idServico = idServico;
    }
}