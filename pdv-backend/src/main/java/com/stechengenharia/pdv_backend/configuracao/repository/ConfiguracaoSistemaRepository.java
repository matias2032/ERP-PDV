package com.stechengenharia.pdv_backend.configuracao.repository;

import com.stechengenharia.pdv_backend.configuracao.entity.ConfiguracaoSistema;
import org.springframework.data.jpa.repository.JpaRepository;

public interface ConfiguracaoSistemaRepository
        extends JpaRepository<ConfiguracaoSistema, Integer> { }