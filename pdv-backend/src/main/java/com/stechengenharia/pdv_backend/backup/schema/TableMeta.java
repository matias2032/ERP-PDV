package com.stechengenharia.pdv_backend.backup.schema;

import java.util.List;

public record TableMeta(String nome, List<ColumnMeta> colunas) {
    /** Colunas que aceitam INSERT (exclui GENERATED ALWAYS). */
    public List<ColumnMeta> insertaveis() {
        return colunas.stream().filter(c -> !c.gerada()).toList();
    }
}