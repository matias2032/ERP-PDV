package com.stechengenharia.pdv_backend.configuracao.service;
import com.stechengenharia.pdv_backend.configuracao.dto.ConfiguracaoRequestDTO;
import com.stechengenharia.pdv_backend.configuracao.entity.ConfiguracaoSistema;
import com.stechengenharia.pdv_backend.configuracao.repository.ConfiguracaoSistemaRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import java.math.BigDecimal;

@Service
@RequiredArgsConstructor
public class ConfiguracaoService {

    private final ConfiguracaoSistemaRepository repository;

    @Transactional(readOnly = true)
    public ConfiguracaoSistema obter() {
        return repository.findById(1)
                .orElseThrow(() -> new RuntimeException("Configurações do sistema não inicializadas"));
    }

    @Transactional(readOnly = true)
    public BigDecimal getIvaPercentual() {
        return obter().getIvaPercentual();
    }

    @Transactional
    public ConfiguracaoSistema actualizar(ConfiguracaoRequestDTO dto) {
        ConfiguracaoSistema c = obter();
        c.setIdioma(dto.idioma);
        c.setMoeda(dto.moeda);
        c.setNomeEmpresa(dto.nomeEmpresa);
        c.setIvaPercentual(dto.ivaPercentual);
        return repository.save(c);
    }
}