package com.stechengenharia.pdv_backend.configuracao.entity;

import com.stechengenharia.pdv_backend.common.entity.AuditableEntity;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

import jakarta.persistence.*;
import java.math.BigDecimal;

@Entity
@Table(name = "configuracao_sistema")
@Getter @Setter @NoArgsConstructor
public class ConfiguracaoSistema extends AuditableEntity {

    @Id
    @Column(name = "id_configuracao_sistema")
    private Integer idConfiguracaoSistema = 1;

    @Column(nullable = false, length = 10)
    private String idioma = "pt";

    @Column(nullable = false, length = 10)
    private String moeda = "MZN";

    @Column(name = "nome_empresa", nullable = false, length = 200)
    private String nomeEmpresa;

    @Column(name = "iva_percentual", nullable = false, precision = 5, scale = 2)
    private BigDecimal ivaPercentual = new BigDecimal("16.00");
}