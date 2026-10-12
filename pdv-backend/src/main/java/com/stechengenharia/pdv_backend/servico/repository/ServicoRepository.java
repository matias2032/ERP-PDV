package com.stechengenharia.pdv_backend.servico.repository;

import com.stechengenharia.pdv_backend.servico.entity.Servico;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;

@Repository
public interface ServicoRepository extends JpaRepository<Servico, Integer> {

    // ── Queries existentes — sem alterações ──────────────────────────
    List<Servico> findByAtivoTrue();
    List<Servico> findAllByOrderByNomeServicoAsc();
    List<Servico> findByDeletedFalseOrderByNomeServicoAsc();
    List<Servico> findByAtivoTrueAndDeletedFalseOrderByNomeServicoAsc();
    boolean existsByNomeServicoIgnoreCaseAndIdServicoNot(String nomeServico, Integer idServico);
    boolean existsByNomeServicoIgnoreCase(String nomeServico);
    Optional<Servico> findByIdServicoAndAtivoTrue(Integer idServico);
    
    @Modifying
    @Query("UPDATE Servico s SET s.ativo = :ativo WHERE s.idServico = :id")
    void updateAtivo(@Param("id") Integer id, @Param("ativo") Boolean ativo);

    // ── Novas queries — soft delete e sync ───────────────────────────
    List<Servico> findByDeletedFalse();

    List<Servico> findByAtivoTrueAndDeletedFalse();

    Optional<Servico> findByIdServicoAndDeletedFalse(Integer idServico);

    List<Servico> findBySyncStatusIn(List<String> statuses);
}