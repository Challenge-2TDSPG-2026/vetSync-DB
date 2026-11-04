package br.com.fiap.VetSync.repository;

import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentMatchers;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.http.HttpStatus;
import org.springframework.jdbc.UncategorizedSQLException;
import org.springframework.jdbc.core.CallableStatementCallback;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.web.server.ResponseStatusException;

import java.sql.SQLException;
import java.time.LocalDate;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class RotinasOracleRepositoryTest {

    @Mock
    private JdbcTemplate jdbcTemplate;

    @InjectMocks
    private RotinasOracleRepository repository;

    private UncategorizedSQLException erroOracle(int codigo, String mensagem) {
        // o driver Oracle embrulha o erro: SQLException -> OracleDatabaseException (não é SQLException)
        return new UncategorizedSQLException("CallableStatementCallback", "{call ...}",
                new SQLException(mensagem, "72000", codigo, new Exception("oracle.jdbc.OracleDatabaseException")));
    }

    @Test
    @DisplayName("listarPetsJson - devolve o JSON retornado pelo pacote")
    void listarPetsJsonSucesso() {
        when(jdbcTemplate.execute(anyString(), ArgumentMatchers.<CallableStatementCallback<String>>any()))
                .thenReturn("[{\"id_pet\":1}]");

        assertThat(repository.listarPetsJson(null)).isEqualTo("[{\"id_pet\":1}]");
    }

    @Test
    @DisplayName("listarPetsJson - ORA-20110 (sem pets) vira 404 com a mensagem do banco")
    void listarPetsJsonSemDados() {
        when(jdbcTemplate.execute(anyString(), ArgumentMatchers.<CallableStatementCallback<String>>any()))
                .thenThrow(erroOracle(20110, "ORA-20110: Nenhum pet encontrado.\nORA-06512: at \"PKG_JSON_PET\""));

        assertThatThrownBy(() -> repository.listarPetsJson(99L))
                .isInstanceOfSatisfying(ResponseStatusException.class, ex -> {
                    assertThat(ex.getStatusCode().value()).isEqualTo(HttpStatus.NOT_FOUND.value());
                    assertThat(ex.getReason()).isEqualTo("Nenhum pet encontrado.");
                });
    }

    @Test
    @DisplayName("calcularIdade - ORA-20121 (data no futuro) vira 422")
    void calcularIdadeDataFutura() {
        when(jdbcTemplate.execute(anyString(), ArgumentMatchers.<CallableStatementCallback<java.math.BigDecimal>>any()))
                .thenThrow(erroOracle(20121, "ORA-20121: Data de nascimento no futuro."));

        assertThatThrownBy(() -> repository.calcularIdade(LocalDate.now().plusDays(10)))
                .isInstanceOfSatisfying(ResponseStatusException.class,
                        ex -> assertThat(ex.getStatusCode().value()).isEqualTo(HttpStatus.UNPROCESSABLE_ENTITY.value()));
    }

    @Test
    @DisplayName("calcularIdade - devolve a idade calculada pelo banco")
    void calcularIdadeSucesso() {
        when(jdbcTemplate.execute(anyString(), ArgumentMatchers.<CallableStatementCallback<java.math.BigDecimal>>any()))
                .thenReturn(java.math.BigDecimal.valueOf(4));

        assertThat(repository.calcularIdade(LocalDate.of(2022, 9, 2))).isEqualTo(4);
    }

    @Test
    @DisplayName("Erro técnico (fora de ORA-20xxx) não é traduzido")
    void erroTecnicoPermanece() {
        when(jdbcTemplate.execute(anyString(), ArgumentMatchers.<CallableStatementCallback<String>>any()))
                .thenThrow(erroOracle(1017, "ORA-01017: invalid username/password"));

        assertThatThrownBy(() -> repository.exportarTutoresJson())
                .isInstanceOf(UncategorizedSQLException.class);
    }
}
