package br.com.fiap.vetsync.database.repository;

import br.com.fiap.vetsync.database.dto.LinhaRelatorioCusto;
import br.com.fiap.vetsync.database.exception.RotinaOracleException;
import org.springframework.dao.DataAccessException;
import org.springframework.jdbc.core.CallableStatementCallback;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Repository;

import java.math.BigDecimal;
import java.sql.Clob;
import java.sql.Date;
import java.sql.SQLException;
import java.sql.Types;
import java.time.LocalDate;
import java.util.List;

/**
 * Camada de acesso aos pacotes PL/SQL do banco Oracle (mesma base da Sprint 3/4 de banco).
 * Toda chamada a pacote fica aqui; controllers e services nao conhecem SQL.
 */
@Repository
public class RotinasOracleRepository {

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

    private final JdbcTemplate jdbcTemplate;

    public RotinasOracleRepository(JdbcTemplate jdbcTemplate) {
        this.jdbcTemplate = jdbcTemplate;
    }

    /** PKG_JSON_PET.PRC_LISTAR_PETS_TUTORES_JSON (JOIN + JSON). idTutor nulo = todos os pets. */
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

    /** PKG_RELATORIO_CUSTOS.PRC_RESUMO_CUSTOS_CLINICA_TIPO e leitura do resultado gravado na tabela. */
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

    /** ORA-20000..20999 sao erros de negocio do PL/SQL; o resto continua sendo erro tecnico. */
    private RuntimeException traduzir(DataAccessException ex) {
        Throwable causa = ex.getMostSpecificCause();
        if (causa instanceof SQLException sql && sql.getErrorCode() >= 20000 && sql.getErrorCode() <= 20999) {
            return new RotinaOracleException(sql.getErrorCode(), extrairMensagem(sql.getMessage()), ex);
        }
        return ex;
    }

    /** "ORA-20110: texto\nORA-06512: ..." -> "texto". */
    private String extrairMensagem(String mensagemOracle) {
        String primeiraLinha = mensagemOracle.lines().findFirst().orElse(mensagemOracle);
        return primeiraLinha.replaceFirst("^ORA-\\d+:\\s*", "");
    }

    private String lerClob(Clob clob) throws SQLException {
        return clob == null ? "[]" : clob.getSubString(1, (int) clob.length());
    }
}
