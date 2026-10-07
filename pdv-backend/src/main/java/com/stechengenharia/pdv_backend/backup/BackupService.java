package com.stechengenharia.pdv_backend.backup;

import com.stechengenharia.pdv_backend.backup.schema.*;
import com.stechengenharia.pdv_backend.backup.writer.BackupWriter;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.web.servlet.mvc.method.annotation.StreamingResponseBody;

import javax.sql.DataSource;
import java.io.IOException;
import java.sql.Connection;
import java.util.List;
import java.util.Map;
import java.util.function.Function;
import java.util.stream.Collectors;

@Slf4j
@Service
public class BackupService {

    private final DataSource dataSource;
    private final SchemaInspector inspector;
    private final Map<BackupFormato, BackupWriter> writers;

    public BackupService(DataSource dataSource, SchemaInspector inspector, List<BackupWriter> lista) {
        this.dataSource = dataSource;
        this.inspector = inspector;
        this.writers = lista.stream().collect(Collectors.toMap(BackupWriter::formato, Function.identity()));
    }

    public List<TabelaInfoDTO> listarTabelas() { return inspector.listarInfo(); }

    public StreamingResponseBody exportar(BackupExportRequest req) {
        // valida ANTES de começar a stream (erros viram 400, não ficheiro corrompido)
        List<TableMeta> tabelas = inspector.resolver(req.tabelas(), req.incluirSensiveis());
        BackupWriter writer = writers.get(req.formato());

        return out -> {
            try (Connection con = dataSource.getConnection()) {
                con.setReadOnly(true);
                con.setTransactionIsolation(Connection.TRANSACTION_REPEATABLE_READ); // snapshot consistente
                con.setAutoCommit(false);
                writer.escrever(tabelas, new LeitorTabelas(con), out);
                con.commit();
                log.info("[Backup] {} exportado: {} tabelas", req.formato(), tabelas.size());
            } catch (Exception e) {
                log.error("[Backup] falha na exportação", e);
                throw new IOException("Falha ao gerar o backup", e);
            }
        };
    }
}