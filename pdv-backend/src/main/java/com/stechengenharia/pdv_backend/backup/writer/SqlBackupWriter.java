package com.stechengenharia.pdv_backend.backup.writer;

import com.stechengenharia.pdv_backend.backup.BackupFormato;
import com.stechengenharia.pdv_backend.backup.schema.*;
import org.springframework.stereotype.Component;

import java.io.*;
import java.math.BigDecimal;
import java.nio.charset.StandardCharsets;
import java.time.OffsetDateTime;
import java.util.List;
import java.util.stream.Collectors;

@Component
public class SqlBackupWriter implements BackupWriter {

    @Override public BackupFormato formato() { return BackupFormato.SQL; }

    @Override
    public void escrever(List<TableMeta> tabelas, LeitorTabelas leitor, OutputStream out) throws Exception {
        PrintWriter w = new PrintWriter(new BufferedWriter(new OutputStreamWriter(out, StandardCharsets.UTF_8)));

        w.println("-- STech PDV · backup de DADOS (PostgreSQL)");
        w.println("-- Gerado em " + OffsetDateTime.now());
        w.println("-- Tabelas: " + tabelas.stream().map(TableMeta::nome).collect(Collectors.joining(", ")));
        w.println("-- Requer que o schema já exista (Flyway/Hibernate).");
        w.println("-- Ciclo cotacao<->pedido: se falhar por FK, descomente (requer superuser):");
        w.println("-- SET session_replication_role = replica;");
        w.println("SET client_encoding = 'UTF8';");
        w.println("BEGIN;");
        w.println();

        for (TableMeta t : tabelas) {
            List<ColumnMeta> cols = t.insertaveis();
            String colunas = cols.stream().map(c -> LeitorTabelas.ident(c.nome()))
                                 .collect(Collectors.joining(", "));
            String prefixo = "INSERT INTO \"public\"." + LeitorTabelas.ident(t.nome())
                           + " (" + colunas + ") VALUES (";

            w.println("-- ── " + t.nome() + " ──");
            long n = leitor.percorrer(t.nome(), cols, v -> {
                StringBuilder sb = new StringBuilder(prefixo);
                for (int i = 0; i < v.length; i++) {
                    if (i > 0) sb.append(", ");
                    sb.append(literal(v[i]));
                }
                w.println(sb.append(");"));
            });
            w.println("-- " + n + " linhas");
            w.println();
        }

        // Reposiciona sequences para o próximo INSERT não colidir
        w.println("-- ── sequences ──");
        for (TableMeta t : tabelas) {
            for (ColumnMeta c : t.colunas()) {
                if (c.sequenciaSql() == null) continue;
                String tab = "\"public\"." + LeitorTabelas.ident(t.nome());
                w.println("SELECT setval(" + c.sequenciaSql() + ", COALESCE((SELECT MAX("
                        + LeitorTabelas.ident(c.nome()) + ") FROM " + tab + "), 0) + 1, false);");
            }
        }
        w.println("COMMIT;");
        w.flush();
    }

    private static String literal(Object v) {
        if (v == null) return "NULL";
        if (v instanceof Boolean b) return b ? "TRUE" : "FALSE";
        if (v instanceof BigDecimal d) return d.toPlainString();
        if (v instanceof Number n) return n.toString();
        return "'" + v.toString().replace("'", "''") + "'";
    }
}