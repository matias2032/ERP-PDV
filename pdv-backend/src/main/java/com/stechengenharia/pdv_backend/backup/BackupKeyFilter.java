// backup/BackupKeyFilter.java
package com.stechengenharia.pdv_backend.backup;

import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;
import org.springframework.web.filter.OncePerRequestFilter;

import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;

@Slf4j
@Component
public class BackupKeyFilter extends OncePerRequestFilter {

    private static final String HEADER = "X-Backup-Key";

    @Value("${backup.api-key:}")
    private String chaveEsperada;

    @Override
    protected boolean shouldNotFilter(HttpServletRequest req) {
        // OPTIONS (preflight CORS) passa; só filtramos /api/backup/**
        return !req.getRequestURI().startsWith("/api/backup")
                || "OPTIONS".equalsIgnoreCase(req.getMethod());
    }

    @Override
    protected void doFilterInternal(HttpServletRequest req, HttpServletResponse res, FilterChain chain)
            throws ServletException, IOException {

        if (chaveEsperada == null || chaveEsperada.isBlank()) {
            log.error("[Backup] BACKUP_API_KEY não definida: endpoint desactivado.");
            negar(res, 503, "Backup desactivado no servidor.");
            return;
        }

        String recebida = req.getHeader(HEADER);
        boolean ok = recebida != null && MessageDigest.isEqual(
                recebida.getBytes(StandardCharsets.UTF_8),
                chaveEsperada.getBytes(StandardCharsets.UTF_8));

        if (!ok) {
            log.warn("[Backup] acesso negado de {}", req.getRemoteAddr());
            negar(res, 403, "Chave de backup inválida.");
            return;
        }
        chain.doFilter(req, res);
    }

    private static void negar(HttpServletResponse res, int status, String msg) throws IOException {
        res.setStatus(status);
        res.setContentType("application/json;charset=UTF-8");
        res.getWriter().write("{\"message\":\"" + msg + "\"}");
    }
}