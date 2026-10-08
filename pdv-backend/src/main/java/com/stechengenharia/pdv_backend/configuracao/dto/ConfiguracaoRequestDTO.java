package com.stechengenharia.pdv_backend.configuracao.dto;

import jakarta.validation.constraints.*;
import java.math.BigDecimal;

public class ConfiguracaoRequestDTO {
    @NotBlank @Pattern(regexp = "pt|en")
    public String idioma;
    @NotBlank
    public String moeda;
    @NotBlank @Size(max = 200)
    public String nomeEmpresa;
    @NotNull @DecimalMin("0.00") @DecimalMax("100.00")
    public BigDecimal ivaPercentual;
}