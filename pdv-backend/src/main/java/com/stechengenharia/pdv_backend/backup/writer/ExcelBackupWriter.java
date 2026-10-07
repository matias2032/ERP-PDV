package com.stechengenharia.pdv_backend.backup.writer;

import com.stechengenharia.pdv_backend.backup.BackupFormato;
import com.stechengenharia.pdv_backend.backup.schema.*;
import org.apache.poi.ss.usermodel.*;
import org.apache.poi.xssf.streaming.SXSSFSheet;
import org.apache.poi.xssf.streaming.SXSSFWorkbook;
import org.springframework.stereotype.Component;

import java.io.OutputStream;
import java.math.BigDecimal;
import java.util.List;
import java.util.concurrent.atomic.AtomicInteger;

@Component
public class ExcelBackupWriter implements BackupWriter {

    private static final int MAX_LINHAS = 1_048_575;  // limite do Excel (1 linha = cabeçalho)
    private static final int MAX_CELULA = 32_767;

    @Override public BackupFormato formato() { return BackupFormato.XLSX; }

    @Override
    public void escrever(List<TableMeta> tabelas, LeitorTabelas leitor, OutputStream out) throws Exception {
        SXSSFWorkbook wb = new SXSSFWorkbook(100); // mantém só 100 linhas em memória
        try {
            CellStyle negrito = wb.createCellStyle();
            Font f = wb.createFont(); f.setBold(true); negrito.setFont(f);

            for (TableMeta t : tabelas) {
                SXSSFSheet sh = wb.createSheet(nomeFolha(t.nome()));
                List<ColumnMeta> cols = t.colunas();

                Row h = sh.createRow(0);
                for (int i = 0; i < cols.size(); i++) {
                    Cell c = h.createCell(i);
                    c.setCellValue(cols.get(i).nome());
                    c.setCellStyle(negrito);
                }
                sh.createFreezePane(0, 1);

                AtomicInteger linha = new AtomicInteger(1);
                leitor.percorrer(t.nome(), cols, v -> {
                    if (linha.get() > MAX_LINHAS) return; // truncado: use CSV/JSON/SQL para tabelas gigantes
                    Row r = sh.createRow(linha.getAndIncrement());
                    for (int i = 0; i < v.length; i++) {
                        Object x = v[i];
                        if (x == null) continue;
                        Cell c = r.createCell(i);
                        if (x instanceof Boolean b)         c.setCellValue(b);
                        else if (x instanceof Long l)       c.setCellValue(l.doubleValue());
                        else if (x instanceof BigDecimal d) c.setCellValue(d.doubleValue());
                        else {
                            String s = x.toString();
                            c.setCellValue(s.length() > MAX_CELULA ? s.substring(0, MAX_CELULA) : s);
                        }
                    }
                });
            }
            wb.write(out);
            out.flush();
        } finally {
            wb.dispose(); // apaga ficheiros temporários
            wb.close();
        }
    }

    /** Excel: máx. 31 chars e sem : \ / ? * [ ] */
    private static String nomeFolha(String n) {
        String s = n.replaceAll("[:\\\\/?*\\[\\]]", "_");
        return s.length() > 31 ? s.substring(0, 31) : s;
    }
}