package com.stechengenharia.pdv_backend.backup;

public enum BackupFormato {
    SQL ("sql",  "application/sql"),
    CSV ("zip",  "application/zip"),   // um .csv por tabela, dentro de um ZIP
    JSON("json", "application/json"),
    XLSX("xlsx", "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet");

    public final String extensao;
    public final String mime;
    BackupFormato(String extensao, String mime) { this.extensao = extensao; this.mime = mime; }
}