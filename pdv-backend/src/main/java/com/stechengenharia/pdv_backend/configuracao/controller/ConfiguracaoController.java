package com.stechengenharia.pdv_backend.configuracao.controller;

import com.stechengenharia.pdv_backend.configuracao.dto.ConfiguracaoRequestDTO;
import com.stechengenharia.pdv_backend.configuracao.entity.ConfiguracaoSistema;
import com.stechengenharia.pdv_backend.configuracao.service.ConfiguracaoService;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/configuracoes")
@RequiredArgsConstructor
public class ConfiguracaoController {

    private final ConfiguracaoService service;

    @GetMapping
    public ResponseEntity<ConfiguracaoSistema> obter() {
        return ResponseEntity.ok(service.obter());
    }

    @PutMapping   // restringir a Administrador no Security
    public ResponseEntity<ConfiguracaoSistema> actualizar(
            @Valid @RequestBody ConfiguracaoRequestDTO dto) {
        return ResponseEntity.ok(service.actualizar(dto));
    }
}