package com.stechengenharia.pdv_backend.backup;

import jakarta.validation.constraints.NotNull;
import java.util.List;

/** tabelas null/vazio = dump completo. */
public record BackupExportRequest(
        List<String> tabelas,
        @NotNull BackupFormato formato,
        boolean incluirSensiveis
) {}