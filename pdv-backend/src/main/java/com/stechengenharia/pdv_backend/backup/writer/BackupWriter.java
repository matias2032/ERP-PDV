package com.stechengenharia.pdv_backend.backup.writer;

import com.stechengenharia.pdv_backend.backup.BackupFormato;
import com.stechengenharia.pdv_backend.backup.schema.LeitorTabelas;
import com.stechengenharia.pdv_backend.backup.schema.TableMeta;
import java.io.OutputStream;
import java.util.List;

public interface BackupWriter {
    BackupFormato formato();
    void escrever(List<TableMeta> tabelas, LeitorTabelas leitor, OutputStream out) throws Exception;
}