package com.stechengenharia.pdv_backend.produto.service;

import com.stechengenharia.pdv_backend.categoria.repository.ProdutoCategoriaRepository;
import com.stechengenharia.pdv_backend.common.util.IvaUtil;
import com.stechengenharia.pdv_backend.configuracao.service.ConfiguracaoService;
import com.stechengenharia.pdv_backend.categoria.entity.ProdutoCategoria;
import com.stechengenharia.pdv_backend.produto.dto.ProdutoImagemRequestDTO;
import com.stechengenharia.pdv_backend.produto.dto.ProdutoRequestDTO;
import com.stechengenharia.pdv_backend.produto.dto.ProdutoResponseDTO;
import com.stechengenharia.pdv_backend.produto.entity.Produto;
import com.stechengenharia.pdv_backend.produto.entity.ProdutoImagem;
import com.stechengenharia.pdv_backend.produto.entity.ProdutoMarca;
import com.stechengenharia.pdv_backend.produto.repository.ProdutoImagemRepository;
import com.stechengenharia.pdv_backend.produto.repository.ProdutoRepository;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;


import jakarta.persistence.EntityManager;

import com.stechengenharia.pdv_backend.produto.repository.ProdutoMarcaRepository;

import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.util.List;
import java.util.stream.Collectors;

@Service
@RequiredArgsConstructor
@Slf4j
public class ProdutoService {
    
    private final ProdutoRepository produtoRepository;
    private final ProdutoCategoriaRepository produtoCategoriaRepository;
    private final ProdutoImagemRepository produtoImagemRepository;
    private final ProdutoMarcaRepository produtoMarcaRepository; 
    private final EntityManager entityManager;
    private final ConfiguracaoService configuracaoService;
    private static final Logger log = LoggerFactory.getLogger(ProdutoService.class);


    // ===== CRUD BÁSICO =====
    
@Transactional
public ProdutoResponseDTO criar(ProdutoRequestDTO dto) {
    log.info("Criando novo produto: {}", dto.getNomeProduto());

    Produto produto = new Produto();
    produto.setNomeProduto(dto.getNomeProduto());
    produto.setDescricao(dto.getDescricao());
    BigDecimal iva = configuracaoService.getIvaPercentual();
    produto.setPrecoSemIva(dto.getPreco());
    produto.setIvaAplicado(iva);
    produto.setPreco(IvaUtil.comIva(dto.getPreco(), iva));
    produto.setQuantidadeEstoque(dto.getQuantidadeEstoque());
    produto.setPrecoPromocional(dto.getPrecoPromocional());
    produto.setSyncStatus("PENDING_CREATE"); // AuditableEntity já faz isto por defeito

    Produto produtoSalvo = produtoRepository.save(produto);
    log.info("Produto criado com ID: {}", produtoSalvo.getIdProduto());

    if (dto.getCategorias() != null && !dto.getCategorias().isEmpty())
        associarCategorias(produtoSalvo.getIdProduto(), dto.getCategorias());

    if (dto.getMarcas() != null && !dto.getMarcas().isEmpty())
        associarMarcas(produtoSalvo.getIdProduto(), dto.getMarcas());

    return mapToResponseDTO(produtoSalvo);
}

@Transactional
public ProdutoResponseDTO atualizar(Integer id, ProdutoRequestDTO dto) {
    log.info("========================================");
    log.info("🔍 ATUALIZANDO PRODUTO ID: {}", id);
    log.info("📥 Dados recebidos:");
    log.info("   - Nome: {}", dto.getNomeProduto());
    log.info("   - Categorias: {}", dto.getCategorias());
    log.info("   - Marcas: {}", dto.getMarcas());
    log.info("========================================");
    
   // linha a alterar dentro do método atualizar:
Produto produto = produtoRepository.findByIdProdutoAndDeletedFalse(id)
        .orElseThrow(() -> new RuntimeException("Produto não encontrado com ID: " + id));
// (@PreUpdate no AuditableEntity muda syncStatus para PENDING_UPDATE automaticamente)
    
    produto.setNomeProduto(dto.getNomeProduto());
    produto.setDescricao(dto.getDescricao());
    // recalcula com o IVA vigente; o preço base vem sempre do DTO, sem cascata
    BigDecimal iva = configuracaoService.getIvaPercentual();
    produto.setPrecoSemIva(dto.getPreco());
    produto.setIvaAplicado(iva);
    produto.setPreco(IvaUtil.comIva(dto.getPreco(), iva));
    produto.setQuantidadeEstoque(dto.getQuantidadeEstoque());
    produto.setPrecoPromocional(dto.getPrecoPromocional());
    
    Produto produtoAtualizado = produtoRepository.save(produto);
    log.info("✅ Produto básico atualizado");
    
    // Atualizar categorias
    if (dto.getCategorias() != null && !dto.getCategorias().isEmpty()) {
        log.info("🔄 Atualizando categorias...");
        removerTodasCategorias(id);
        entityManager.flush(); // ✅ FLUSH após deletar
        entityManager.clear(); // ✅ LIMPAR cache
        
        log.info("   ❌ Categorias antigas removidas");
        associarCategorias(id, dto.getCategorias());
        entityManager.flush(); // ✅ FLUSH após inserir
        entityManager.clear(); // ✅ LIMPAR cache
        
        log.info("   ✅ Novas categorias associadas: {}", dto.getCategorias());
    }
    
    // Atualizar marcas
    if (dto.getMarcas() != null && !dto.getMarcas().isEmpty()) {
        log.info("🔄 Atualizando marcas...");
        removerTodasMarcas(id);
        entityManager.flush(); // ✅ FLUSH após deletar
        entityManager.clear(); // ✅ LIMPAR cache
        
        log.info("   ❌ Marcas antigas removidas");
        associarMarcas(id, dto.getMarcas());
        entityManager.flush(); // ✅ FLUSH após inserir
        entityManager.clear(); // ✅ LIMPAR cache
        
        log.info("   ✅ Novas marcas associadas: {}", dto.getMarcas());
    }
    
    // ✅ BUSCAR O PRODUTO NOVAMENTE DO BANCO
    Produto produtoFinal = produtoRepository.findById(id)
            .orElseThrow(() -> new RuntimeException("Produto não encontrado"));
    
    ProdutoResponseDTO response = mapToResponseDTO(produtoFinal);
    log.info("📤 Resposta final:");
    log.info("   - Categorias: {}", response.getCategorias());
    log.info("   - Marcas: {}", response.getMarcas());
    log.info("========================================");
    
    return response;
}

private void associarMarcas(Integer idProduto, List<Integer> marcas) {
    log.info("   📝 Associando {} marca(s) ao produto {}", marcas.size(), idProduto);
    marcas.forEach(idMarca -> {
        log.info("      - Associando marca ID: {}", idMarca);
        associarMarca(idProduto, idMarca);
    });
}

private void removerTodasMarcas(Integer idProduto) {
    List<ProdutoMarca> associacoes = produtoMarcaRepository.findByIdProduto(idProduto);
    associacoes.forEach(assoc -> 
        produtoMarcaRepository.deleteByIdMarcaAndIdProduto(assoc.getIdMarca(), idProduto)
    );
}
    
@Transactional
public void toggleAtivo(Integer id) {
    log.info("Alternando status de ativação do produto ID: {}", id);
    
    Produto produto = produtoRepository.findById(id)
            .orElseThrow(() -> new RuntimeException("Produto não encontrado com ID: " + id));
    
    // ✅ MUDANÇA: Comparação com Short
    produto.setAtivo(produto.getAtivo() == 1 ? (short) 0 : (short) 1);
    produtoRepository.save(produto);
    
    log.info("Produto ID {} agora está: {}", id, produto.getAtivo() == 1 ? "ATIVO" : "INATIVO");
}
    

    @Transactional
public void deletar(Integer id) {
    Produto produto = produtoRepository.findByIdProdutoAndDeletedFalse(id)
            .orElseThrow(() -> new RuntimeException("Produto não encontrado com ID: " + id));
    produto.setDeleted(true);
    produto.setAtivo((short) 0);          // invisível no PDV também
    produto.setSyncStatus("PENDING_DELETE");
    produtoRepository.save(produto);
    log.info("Produto ID {} marcado como eliminado", id);
}
    
@Transactional(readOnly = true)
public List<ProdutoResponseDTO> listar() {
    return produtoRepository.findByDeletedFalse().stream()   // era findAll()
            .map(this::mapToResponseDTO)
            .collect(Collectors.toList());
}

@Transactional(readOnly = true)
public List<ProdutoResponseDTO> listarAtivos() {
    return produtoRepository.findByAtivoAndDeletedFalse((short) 1).stream() // era findByAtivo
            .map(this::mapToResponseDTO)
            .collect(Collectors.toList());
}
@Transactional(readOnly = true)
public ProdutoResponseDTO buscarPorId(Integer id) {
    Produto produto = produtoRepository.findByIdProdutoAndDeletedFalse(id)  // era findById
            .orElseThrow(() -> new RuntimeException("Produto não encontrado com ID: " + id));
    return mapToResponseDTO(produto);
}
    // ===== ASSOCIAÇÕES COM CATEGORIAS =====
    
    @Transactional
public void associarCategoria(Integer idProduto, Integer idCategoria) {
    log.info("Associando categoria {} ao produto {}", idCategoria, idProduto);
    
    if (!produtoRepository.existsById(idProduto)) {
        throw new RuntimeException("Produto não encontrado com ID: " + idProduto);
    }
    
    if (produtoCategoriaRepository.existsByIdCategoriaAndIdProduto(idCategoria, idProduto)) {
        log.warn("Associação já existe entre produto {} e categoria {}", idProduto, idCategoria);
        return;
    }
    
    ProdutoCategoria pc = new ProdutoCategoria();
    pc.setIdProduto(idProduto);
    pc.setIdCategoria(idCategoria);
    
    // ✅ MUDANÇA: saveAndFlush() em vez de save()
    produtoCategoriaRepository.saveAndFlush(pc);
    
    log.info("Categoria {} associada ao produto {} com sucesso", idCategoria, idProduto);
    log.info("🔍 DEBUG: Verificando se foi salvo...");
    
    // ✅ ADICIONE: Verificação imediata
    boolean existe = produtoCategoriaRepository.existsByIdCategoriaAndIdProduto(idCategoria, idProduto);
    log.info("🔍 DEBUG: Associação existe após save? {}", existe);
}
    
    @Transactional
    public void desassociarCategoria(Integer idProduto, Integer idCategoria) {
        log.info("Desassociando categoria {} do produto {}", idCategoria, idProduto);
        produtoCategoriaRepository.deleteByIdCategoriaAndIdProduto(idCategoria, idProduto);
        log.info("Categoria {} desassociada do produto {} com sucesso", idCategoria, idProduto);
    }
    
 private void associarCategorias(Integer idProduto, List<Integer> categorias) {
    log.info("   📝 Associando {} categoria(s) ao produto {}", categorias.size(), idProduto);
    categorias.forEach(idCategoria -> {
        log.info("      - Associando categoria ID: {}", idCategoria);
        associarCategoria(idProduto, idCategoria);
    });
}

    private void removerTodasCategorias(Integer idProduto) {
        List<ProdutoCategoria> associacoes = produtoCategoriaRepository.findByIdProduto(idProduto);
        associacoes.forEach(assoc -> 
            produtoCategoriaRepository.deleteByIdCategoriaAndIdProduto(assoc.getIdCategoria(), idProduto)
        );
    }
    
    @Transactional(readOnly = true)
    public List<Integer> listarCategoriasDoProduto(Integer idProduto) {
        log.info("Listando categorias do produto: {}", idProduto);
        return produtoCategoriaRepository.findByIdProduto(idProduto)
                .stream()
                .map(ProdutoCategoria::getIdCategoria)
                .collect(Collectors.toList());
    }
    
    // ===== GESTÃO DE IMAGENS =====
    
    @Transactional
public void adicionarImagem(Integer idProduto, ProdutoImagemRequestDTO dto) {
    log.info("Adicionando imagem ao produto ID: {}", idProduto);
    
    if (!produtoRepository.existsById(idProduto)) {
        throw new RuntimeException("Produto não encontrado com ID: " + idProduto);
    }
    
    // ✅ MUDANÇA: comparação com Short
    if (dto.getImagemPrincipal() != null && dto.getImagemPrincipal() == 1) {
        produtoImagemRepository.desmarcarTodasImagensPrincipais(idProduto);
    }
    
    ProdutoImagem imagem = new ProdutoImagem();
    imagem.setIdProduto(idProduto);
    imagem.setCaminhoImagem(dto.getCaminhoImagem());
    imagem.setLegenda(dto.getLegenda());
    
    // ✅ MUDANÇA: cast para Short
    imagem.setImagemPrincipal(dto.getImagemPrincipal() != null ? dto.getImagemPrincipal() : (short) 0);
    
    produtoImagemRepository.save(imagem);
    log.info("Imagem adicionada ao produto {} com sucesso", idProduto);
}

@Transactional
public void alterarImagemPrincipal(Integer idProduto, Integer idImagem) {
    log.info("Alterando imagem principal do produto {} para imagem ID: {}", idProduto, idImagem);
    
    ProdutoImagem imagem = produtoImagemRepository.findById(idImagem)
            .orElseThrow(() -> new RuntimeException("Imagem não encontrada com ID: " + idImagem));
    
    if (!imagem.getIdProduto().equals(idProduto)) {
        throw new RuntimeException("A imagem não pertence ao produto informado");
    }
    
    produtoImagemRepository.desmarcarTodasImagensPrincipais(idProduto);
    
    // ✅ MUDANÇA: cast para Short
    imagem.setImagemPrincipal((short) 1);
    produtoImagemRepository.save(imagem);
    
    log.info("Imagem principal do produto {} alterada com sucesso", idProduto);
}

@Transactional
public void removerImagem(Integer idImagem) {
    log.info("Removendo imagem ID: {}", idImagem);
    produtoImagemRepository.deleteById(idImagem);
    log.info("Imagem {} removida com sucesso", idImagem);
}

@Transactional(readOnly = true)
public List<ProdutoImagem> listarImagensDoProduto(Integer idProduto) {
    log.info("Listando imagens do produto: {}", idProduto);
    return produtoImagemRepository.findByIdProduto(idProduto);
}

// No mapToResponseDTO:
private ProdutoResponseDTO mapToResponseDTO(Produto produto) {
    ProdutoResponseDTO dto = new ProdutoResponseDTO();
    dto.setIdProduto(produto.getIdProduto());
    dto.setNomeProduto(produto.getNomeProduto());
    dto.setDescricao(produto.getDescricao());
    dto.setPreco(produto.getPreco());
    dto.setPrecoSemIva(produto.getPrecoSemIva());
    dto.setIvaAplicado(produto.getIvaAplicado());
    dto.setQuantidadeEstoque(produto.getQuantidadeEstoque());
    dto.setPrecoPromocional(produto.getPrecoPromocional());
    dto.setAtivo(produto.getAtivo());
    dto.setDataCadastro(produto.getDataCadastro());
    
    // Buscar categorias associadas
    List<Integer> categorias = listarCategoriasDoProduto(produto.getIdProduto());
    dto.setCategorias(categorias);
    
    // ✅ ADICIONE ESTAS LINHAS: Buscar marcas associadas
    List<Integer> marcas = listarMarcasDoProduto(produto.getIdProduto());
    dto.setMarcas(marcas);
    
    // Buscar imagem principal
    produtoImagemRepository.findByIdProdutoAndImagemPrincipal(produto.getIdProduto(), (short) 1)
            .ifPresent(img -> dto.setImagemPrincipalUrl(img.getCaminhoImagem()));
    
    return dto;
}

// ===== ASSOCIAÇÕES COM MARCAS =====

@Transactional
public void associarMarca(Integer idProduto, Integer idMarca) {
    log.info("Associando marca {} ao produto {}", idMarca, idProduto);
    
    if (!produtoRepository.existsById(idProduto)) {
        throw new RuntimeException("Produto não encontrado com ID: " + idProduto);
    }
    
    if (produtoMarcaRepository.existsByIdMarcaAndIdProduto(idMarca, idProduto)) {
        log.warn("Associação já existe entre produto {} e marca {}", idProduto, idMarca);
        return;
    }
    
    ProdutoMarca pm = new ProdutoMarca();
    pm.setIdProduto(idProduto);
    pm.setIdMarca(idMarca);
    
    // ✅ MUDANÇA: saveAndFlush() em vez de save()
    produtoMarcaRepository.saveAndFlush(pm);
    
    log.info("Marca {} associada ao produto {} com sucesso", idMarca, idProduto);
    log.info("🔍 DEBUG: Verificando se foi salvo...");
    
    // ✅ ADICIONE: Verificação imediata
    boolean existe = produtoMarcaRepository.existsByIdMarcaAndIdProduto(idMarca, idProduto);
    log.info("🔍 DEBUG: Associação existe após save? {}", existe);
}

@Transactional
public void desassociarMarca(Integer idProduto, Integer idMarca) {
    log.info("Desassociando marca {} do produto {}", idMarca, idProduto);
    produtoMarcaRepository.deleteByIdMarcaAndIdProduto(idMarca, idProduto);
    log.info("Marca {} desassociada do produto {} com sucesso", idMarca, idProduto);
}

@Transactional(readOnly = true)
public List<Integer> listarMarcasDoProduto(Integer idProduto) {
    log.info("Listando marcas do produto: {}", idProduto);
    return produtoMarcaRepository.findByIdProduto(idProduto)
            .stream()
            .map(ProdutoMarca::getIdMarca)
            .collect(Collectors.toList());
}

@Transactional(readOnly = true)
public List<Integer> listarProdutosDaMarca(Integer idMarca) {
    log.info("Listando produtos da marca: {}", idMarca);
    return produtoMarcaRepository.findByIdMarca(idMarca)
            .stream()
            .map(ProdutoMarca::getIdProduto)
            .collect(Collectors.toList());
}
}