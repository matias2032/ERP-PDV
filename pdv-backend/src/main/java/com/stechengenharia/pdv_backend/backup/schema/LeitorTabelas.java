package com.stechengenharia.pdv_backend.backup.schema;

import java.sql.*;
import java.util.List;
import java.util.stream.Collectors;

/** Lê uma tabela em streaming (fetchSize) para não carregar tudo em memória. */
public class LeitorTabelas {

    @FunctionalInterface
    public interface Linha { void aceitar(Object[] valores) throws Exception; }

    private final Connection con;
    public LeitorTabelas(Connection con) { this.con = con; }

    public static String ident(String s) { return "\"" + s.replace("\"", "\"\"") + "\""; }

    public long percorrer(String tabela, List<ColumnMeta> cols, Linha handler) throws Exception {
        String sql = "SELECT " + cols.stream().map(c -> ident(c.nome())).collect(Collectors.joining(", "))
                   + " FROM \"public\"." + ident(tabela) + " ORDER BY 1";
        try (Statement st = con.createStatement(ResultSet.TYPE_FORWARD_ONLY, ResultSet.CONCUR_READ_ONLY)) {
            st.setFetchSize(1000); // com autoCommit=false o Postgres usa cursor
            try (ResultSet rs = st.executeQuery(sql)) {
                long n = 0;
                Object[] v = new Object[cols.size()];
                while (rs.next()) {
                    for (int i = 0; i < v.length; i++) v[i] = cols.get(i).ler(rs, i + 1);
                    handler.aceitar(v);
                    n++;
                }
                return n;
            }
        }
    }
}