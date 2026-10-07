package com.stechengenharia.pdv_backend.backup;

import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.*;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.servlet.mvc.method.annotation.StreamingResponseBody;

import java.time.LocalDateTime;
import java.time.format.DateTimeFormatter;
import java.util.List;

@RestController
@RequestMapping("/api/backup")
@RequiredArgsConstructor
// TODO: proteger (só perfil Administrador). Não vi a sua config de segurança;
// aplique o mesmo mecanismo que já usa nos outros endpoints sensíveis.
public class BackupController {

    private final BackupService backupService;

    @GetMapping("/tabelas")
    public List<TabelaInfoDTO> tabelas() {
        return backupService.listarTabelas();
    }

    @PostMapping("/exportar")
    public ResponseEntity<StreamingResponseBody> exportar(@Valid @RequestBody BackupExportRequest req) {
        StreamingResponseBody body = backupService.exportar(req);

        String nome = "stech_backup_"
                + LocalDateTime.now().format(DateTimeFormatter.ofPattern("yyyyMMdd_HHmmss"))
                + (req.tabelas() == null || req.tabelas().isEmpty() ? "_completo" : "_parcial")
                + "." + req.formato().extensao;

        return ResponseEntity.ok()
                .header(HttpHeaders.CONTENT_DISPOSITION, ContentDisposition.attachment().filename(nome).build().toString())
                .header(HttpHeaders.CACHE_CONTROL, "no-store")
                .contentType(MediaType.parseMediaType(req.formato().mime))
                .body(body);
    }
}