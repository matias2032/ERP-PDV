package com.stechengenharia.pdv_backend.backup.schema;

import com.stechengenharia.pdv_backend.backup.TabelaInfoDTO;
import lombok.RequiredArgsConstructor;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Component;

import java.util.*;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

@Component
@RequiredArgsConstructor
public class SchemaInspector {

    private static final Set<String> NUNCA = Set.of("flyway_schema_history");
    private static final Set<String> TABELAS_SENSIVEIS = Set.of("historico_senhas", "password_resets");
    private static final Map<String, Set<String>> COLUNAS_SENSIVEIS =
            Map.of("usuario", Set.of("senha_hash"));
    private static final Pattern NEXTVAL = Pattern.compile("nextval\\('([^']+)'");

    private final JdbcTemplate jdbc;

    // ── Listagem para a UI ────────────────────────────────────────────

    public List<TabelaInfoDTO> listarInfo() {
        return jdbc.query("""
            SELECT t.table_name, GREATEST(COALESCE(c.reltuples, 0), 0)::bigint AS linhas
            FROM information_schema.tables t
            LEFT JOIN pg_class c
                   ON c.relname = t.table_name
                  AND c.relnamespace = 'public'::regnamespace
            WHERE t.table_schema = 'public' AND t.table_type = 'BASE TABLE'
            ORDER BY t.table_name
            """,
            (rs, i) -> new TabelaInfoDTO(
                    rs.getString(1), rs.getLong(2),
                    TABELAS_SENSIVEIS.contains(rs.getString(1))))
            .stream().filter(t -> !NUNCA.contains(t.nome())).toList();
}

    // ── Resolução para exportar ───────────────────────────────────────

    public List<TableMeta> resolver(List<String> selecionadas, boolean incluirSensiveis) {
        Map<String, List<ColumnMeta>> todas = carregarColunas();
        todas.keySet().removeAll(NUNCA);

        Set<String> alvo = new LinkedHashSet<>();
        if (selecionadas == null || selecionadas.isEmpty()) {
            alvo.addAll(todas.keySet());
        } else {
            for (String s : selecionadas) {
                // whitelist: só nomes que existem no schema (evita SQL injection)
                if (!todas.containsKey(s))
                    throw new IllegalArgumentException("Tabela inválida: " + s);
                alvo.add(s);
            }
        }
        if (!incluirSensiveis) alvo.removeAll(TABELAS_SENSIVEIS);
        if (alvo.isEmpty())
            throw new IllegalArgumentException("Nenhuma tabela elegível para exportar.");

        List<TableMeta> metas = new ArrayList<>();
        for (String nome : ordenarPorDependencias(alvo)) {
            List<ColumnMeta> cols = new ArrayList<>(todas.get(nome));
            if (!incluirSensiveis) {
                Set<String> proibidas = COLUNAS_SENSIVEIS.getOrDefault(nome, Set.of());
                cols.removeIf(c -> proibidas.contains(c.nome()));
            }
            metas.add(new TableMeta(nome, cols));
        }
        return metas;
    }

    // ── Internos ──────────────────────────────────────────────────────

    private Map<String, List<ColumnMeta>> carregarColunas() {
        Map<String, List<ColumnMeta>> mapa = new LinkedHashMap<>();
        jdbc.query("""
            SELECT c.table_name, c.column_name, c.data_type, c.is_generated,
                   c.is_identity, c.column_default
            FROM information_schema.columns c
            JOIN information_schema.tables t
              ON t.table_schema = c.table_schema AND t.table_name = c.table_name
            WHERE c.table_schema = 'public' AND t.table_type = 'BASE TABLE'
            ORDER BY c.table_name, c.ordinal_position
            """,
            rs -> {
                String tabela = rs.getString("table_name");
                String coluna = rs.getString("column_name");
                String def    = rs.getString("column_default");

                String seq = null;
                if ("YES".equals(rs.getString("is_identity"))) {
                    seq = "pg_get_serial_sequence('public.\"" + tabela + "\"', '" + coluna + "')";
                } else if (def != null) {
                    Matcher m = NEXTVAL.matcher(def);
                    if (m.find()) seq = "'" + m.group(1) + "'";
                }
                mapa.computeIfAbsent(tabela, k -> new ArrayList<>()).add(new ColumnMeta(
                        coluna,
                        ColumnMeta.Tipo.de(rs.getString("data_type")),
                        "ALWAYS".equals(rs.getString("is_generated")),
                        seq));
            });
        return mapa;
    }

    /** Pais antes dos filhos. Ciclos (cotacao↔pedido) vão para o fim. */
    private List<String> ordenarPorDependencias(Set<String> alvo) {
        Map<String, Set<String>> deps = new HashMap<>();
        jdbc.query("""
            SELECT conrelid::regclass::text, confrelid::regclass::text
            FROM pg_constraint
            WHERE contype = 'f' AND connamespace = 'public'::regnamespace
            """,
            rs -> {
                String filha = limpar(rs.getString(1));
                String pai   = limpar(rs.getString(2));
                if (!filha.equals(pai) && alvo.contains(filha) && alvo.contains(pai))
                    deps.computeIfAbsent(filha, k -> new HashSet<>()).add(pai);
            });

        List<String> ordem = new ArrayList<>();
        Set<String> pendentes = new TreeSet<>(alvo);
        while (!pendentes.isEmpty()) {
            List<String> prontos = pendentes.stream()
                    .filter(t -> deps.getOrDefault(t, Set.of()).stream().noneMatch(pendentes::contains))
                    .toList();
            if (prontos.isEmpty()) { ordem.addAll(pendentes); break; } // ciclo
            ordem.addAll(prontos);
            pendentes.removeAll(prontos);
        }
        return ordem;
    }

    private static String limpar(String s) {
        return s.replace("public.", "").replace("\"", "");
    }
}