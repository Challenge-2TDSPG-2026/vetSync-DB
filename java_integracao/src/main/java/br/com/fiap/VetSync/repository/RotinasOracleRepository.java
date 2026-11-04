package br.com.fiap.VetSync.repository;

import lombok.RequiredArgsConstructor;
import org.springframework.dao.DataAccessException;
import org.springframework.http.HttpStatus;
import org.springframework.jdbc.core.CallableStatementCallback;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Repository;
import org.springframework.web.server.ResponseStatusException;

import java.math.BigDecimal;
import java.sql.Clob;
import java.sql.Date;
import java.sql.SQLException;
import java.sql.Types;
import java.time.LocalDate;
import java.util.List;
import java.util.Set;

/**
 * Acesso aos pacotes PL/SQL do Oracle criados na migration V57 (disciplina de banco de dados).
 * É o único ponto da aplicação que conhece essas chamadas; controller e service só enxergam métodos Java.
 * Os erros de negócio dos pacotes (ORA-20000 a ORA-20999) viram {@link ResponseStatusException}, que o
 * {@code GlobalExceptionHandler} já converte em resposta HTTP.
 */
@Repository
@RequiredArgsConstructor
public class RotinasOracleRepository {

    public record LinhaRelatorioCusto(Long idLinha, String clinica, String tipoEvento,
                                      BigDecimal valorTotal, String tipoLinha) {}

    private static final String CALL_LISTAR_PETS_JSON =
            "{call pkg_json_pet.prc_listar_pets_tutores_json(?, ?)}";
    private static final String CALL_EXPORTAR_TUTORES_JSON =
            "{call pkg_exportacao_json.prc_exportar_tutores_json(?)}";
    private static final String CALL_CALCULAR_IDADE =
            "{? = call pkg_pet.fnc_calcular_idade(?)}";
    private static final String CALL_RESUMO_CUSTOS =
            "{call pkg_relatorio_custos.prc_resumo_custos_clinica_tipo(?)}";
    private static final String SELECT_RELATORIO = """
            SELECT id_linha, nm_clinica, nm_tipo_evento, vl_total, ds_tipo_linha
            FROM TB_RELATORIO_CUSTOS_CLINICA
            ORDER BY id_linha
            """;

    /** Códigos dos pacotes que significam "não há dados": pets (20110), eventos (20130) e tutores (20150). */
    private static final Set<Integer> CODIGOS_SEM_DADOS = Set.of(20110, 20130, 20150);
    private static final int ORA_NEGOCIO_MIN = 20000;
    private static final int ORA_NEGOCIO_MAX = 20999;

    private final JdbcTemplate jdbcTemplate;

    /** PKG_JSON_PET.PRC_LISTAR_PETS_TUTORES_JSON (JOIN + JSON manual). {@code idTutor} nulo lista todos os pets. */
    public String listarPetsJson(Long idTutor) {
        return executar(CALL_LISTAR_PETS_JSON, (CallableStatementCallback<String>) cs -> {
            cs.registerOutParameter(1, Types.CLOB);
            if (idTutor == null) {
                cs.setNull(2, Types.NUMERIC);
            } else {
                cs.setLong(2, idTutor);
            }
            cs.execute();
            return lerClob(cs.getClob(1));
        });
    }

    /** PKG_EXPORTACAO_JSON.PRC_EXPORTAR_TUTORES_JSON (tutores com array de pets, formato do MongoDB). */
    public String exportarTutoresJson() {
        return executar(CALL_EXPORTAR_TUTORES_JSON, (CallableStatementCallback<String>) cs -> {
            cs.registerOutParameter(1, Types.CLOB);
            cs.execute();
            return lerClob(cs.getClob(1));
        });
    }

    /** PKG_PET.FNC_CALCULAR_IDADE (idade em anos completos). */
    public int calcularIdade(LocalDate dataNascimento) {
        BigDecimal idade = executar(CALL_CALCULAR_IDADE, (CallableStatementCallback<BigDecimal>) cs -> {
            cs.registerOutParameter(1, Types.NUMERIC);
            cs.setDate(2, Date.valueOf(dataNascimento));
            cs.execute();
            return cs.getBigDecimal(1);
        });
        return idade.intValue();
    }

    /**
     * PKG_RELATORIO_CUSTOS.PRC_RESUMO_CUSTOS_CLINICA_TIPO e leitura do relatório gravado em
     * TB_RELATORIO_CUSTOS_CLINICA. A procedure refaz a tabela a cada chamada, então duas
     * execuções simultâneas se sobrepõem.
     */
    public List<LinhaRelatorioCusto> gerarRelatorioCustos(Long idClinica) {
        executar(CALL_RESUMO_CUSTOS, (CallableStatementCallback<Void>) cs -> {
            if (idClinica == null) {
                cs.setNull(1, Types.NUMERIC);
            } else {
                cs.setLong(1, idClinica);
            }
            cs.execute();
            return null;
        });

        return jdbcTemplate.query(SELECT_RELATORIO, (rs, i) -> new LinhaRelatorioCusto(
                rs.getLong("id_linha"),
                rs.getString("nm_clinica"),
                rs.getString("nm_tipo_evento"),
                rs.getBigDecimal("vl_total"),
                rs.getString("ds_tipo_linha")));
    }

    private <T> T executar(String chamada, CallableStatementCallback<T> callback) {
        try {
            return jdbcTemplate.execute(chamada, callback);
        } catch (DataAccessException ex) {
            throw traduzir(ex);
        }
    }

    /**
     * ORA-20000..20999 são erros de negócio dos pacotes; qualquer outro erro segue como falha técnica.
     * O driver Oracle embrulha o erro em outras exceções, então a cadeia de causas é percorrida inteira.
     */
    private RuntimeException traduzir(DataAccessException ex) {
        for (Throwable causa = ex; causa != null; causa = causa.getCause() == causa ? null : causa.getCause()) {
            if (causa instanceof SQLException sql
                    && sql.getErrorCode() >= ORA_NEGOCIO_MIN && sql.getErrorCode() <= ORA_NEGOCIO_MAX) {
                HttpStatus status = CODIGOS_SEM_DADOS.contains(sql.getErrorCode())
                        ? HttpStatus.NOT_FOUND
                        : HttpStatus.UNPROCESSABLE_ENTITY;
                return new ResponseStatusException(status, extrairMensagem(sql.getMessage()), ex);
            }
        }
        return ex;
    }

    /** "ORA-20110: texto\nORA-06512: ..." vira "texto". */
    private String extrairMensagem(String mensagemOracle) {
        String primeiraLinha = mensagemOracle.lines().findFirst().orElse(mensagemOracle);
        return primeiraLinha.replaceFirst("^ORA-\\d+:\\s*", "");
    }

    private String lerClob(Clob clob) throws SQLException {
        return clob == null ? "[]" : clob.getSubString(1, (int) clob.length());
    }
}
