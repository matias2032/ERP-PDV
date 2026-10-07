package com.stechengenharia.pdv_backend.backup.writer;

import com.fasterxml.jackson.core.JsonEncoding;
import com.fasterxml.jackson.core.JsonFactory;
import com.fasterxml.jackson.core.JsonGenerator;
import com.stechengenharia.pdv_backend.backup.BackupFormato;
import com.stechengenharia.pdv_backend.backup.schema.*;
import org.springframework.stereotype.Component;

import java.io.OutputStream;
import java.math.BigDecimal;
import java.time.OffsetDateTime;
import java.util.List;

@Component
public class JsonBackupWriter implements BackupWriter {

    @Override public BackupFormato formato() { return BackupFormato.JSON; }

    @Override
    public void escrever(List<TableMeta> tabelas, LeitorTabelas leitor, OutputStream out) throws Exception {
        JsonGenerator g = new JsonFactory().createGenerator(out, JsonEncoding.UTF8);
        g.useDefaultPrettyPrinter();

        g.writeStartObject();
        g.writeObjectFieldStart("meta");
        g.writeNumberField("versaoFormato", 1);
        g.writeStringField("origem", "stech_pdv_postgres");
        g.writeStringField("geradoEm", OffsetDateTime.now().toString());
        g.writeArrayFieldStart("tabelas");
        for (TableMeta t : tabelas) g.writeString(t.nome());
        g.writeEndArray();
        g.writeEndObject();

        g.writeObjectFieldStart("dados");
        for (TableMeta t : tabelas) {
            g.writeArrayFieldStart(t.nome());
            List<ColumnMeta> cols = t.colunas();
            leitor.percorrer(t.nome(), cols, v -> {
                g.writeStartObject();
                for (int i = 0; i < v.length; i++) {
                    g.writeFieldName(cols.get(i).nome());
                    Object x = v[i];
                    if (x == null)                    g.writeNull();
                    else if (x instanceof Boolean b)  g.writeBoolean(b);
                    else if (x instanceof Long l)     g.writeNumber(l);
                    else if (x instanceof BigDecimal d) g.writeNumber(d);
                    else                              g.writeString(x.toString());
                }
                g.writeEndObject();
            });
            g.writeEndArray();
        }
        g.writeEndObject();
        g.writeEndObject();
        g.flush();
    }
}