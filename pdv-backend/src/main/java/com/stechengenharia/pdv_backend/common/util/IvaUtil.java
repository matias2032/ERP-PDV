package com.stechengenharia.pdv_backend.common.util;

import java.math.BigDecimal;
import java.math.RoundingMode;

public final class IvaUtil {
    private IvaUtil() {}

    public static BigDecimal comIva(BigDecimal precoSemIva, BigDecimal ivaPercentual) {
        BigDecimal fator = BigDecimal.ONE.add(
                ivaPercentual.divide(new BigDecimal("100"), 6, RoundingMode.HALF_UP));
        return precoSemIva.multiply(fator).setScale(2, RoundingMode.HALF_UP);
    }
}