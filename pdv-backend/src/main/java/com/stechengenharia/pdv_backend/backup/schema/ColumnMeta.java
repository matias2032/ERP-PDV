package com.stechengenharia.pdv_backend.backup.schema;

import java.sql.ResultSet;
import java.sql.SQLException;

public record ColumnMeta(String nome, Tipo tipo, boolean gerada, String sequenciaSql) {

    public enum Tipo {
        BOOLEANO, INTEIRO, DECIMAL, TEXTO;

        static Tipo de(String dataType) {
            return switch (dataType) {
                case "boolean" -> BOOLEANO;
                case "smallint", "integer", "bigint" -> INTEIRO;
                case "numeric", "real", "double precision" -> DECIMAL;
                default -> TEXTO; // datas, jsonb, inet, text... saem como texto
            };
        }
    }

    /** Devolve null, Boolean, Long, BigDecimal ou String. */
    public Object ler(ResultSet rs, int i) throws SQLException {
        Object v = switch (tipo) {
            case BOOLEANO -> rs.getBoolean(i);
            case INTEIRO  -> rs.getLong(i);
            case DECIMAL  -> rs.getBigDecimal(i);
            case TEXTO    -> rs.getString(i);
        };
        return rs.wasNull() ? null : v;
    }
}