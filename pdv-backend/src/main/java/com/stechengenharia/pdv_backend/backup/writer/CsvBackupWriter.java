package com.stechengenharia.pdv_backend.backup.writer;

import com.stechengenharia.pdv_backend.backup.BackupFormato;
import com.stechengenharia.pdv_backend.backup.schema.*;
import org.springframework.stereotype.Component;

import java.io.*;
import java.math.BigDecimal;
import java.nio.charset.StandardCharsets;
import java.util.List;
import java.util.stream.Collectors;
import java.util.zip.*;

@Component
public class CsvBackupWriter implements BackupWriter {

    // ';' abre bem no Excel com locale PT; BOM garante acentos correctos
    private static final char SEP = ';';

    @Override public BackupFormato formato() { return BackupFormato.CSV; }

    @Override
    public void escrever(List<TableMeta> tabelas, LeitorTabelas leitor, OutputStream out) throws Exception {
        ZipOutputStream zip = new ZipOutputStream(out, StandardCharsets.UTF_8);
        BufferedWriter w = new BufferedWriter(new OutputStreamWriter(zip, StandardCharsets.UTF_8));

        for (TableMeta t : tabelas) {
            zip.putNextEntry(new ZipEntry(t.nome() + ".csv"));
            w.write('\uFEFF');
            w.write(t.colunas().stream().map(ColumnMeta::nome).collect(Collectors.joining(String.valueOf(SEP))));
            w.write("\r\n");

            leitor.percorrer(t.nome(), t.colunas(), v -> {
                for (int i = 0; i < v.length; i++) {
                    if (i > 0) w.write(SEP);
                    w.write(campo(v[i]));
                }
                w.write("\r\n");
            });
            w.flush();
            zip.closeEntry();
        }
        zip.finish();
    }

    private static String campo(Object v) {
        if (v == null) return "";
        String s = v instanceof BigDecimal d ? d.toPlainString() : v.toString();
        if (s.indexOf(SEP) >= 0 || s.indexOf('"') >= 0 || s.indexOf('\n') >= 0 || s.indexOf('\r') >= 0)
            return "\"" + s.replace("\"", "\"\"") + "\"";
        return s;
    }
}