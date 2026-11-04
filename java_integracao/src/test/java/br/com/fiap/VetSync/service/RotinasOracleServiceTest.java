package br.com.fiap.VetSync.service;

import br.com.fiap.VetSync.repository.RotinasOracleRepository;
import br.com.fiap.VetSync.repository.RotinasOracleRepository.LinhaRelatorioCusto;
import br.com.fiap.VetSync.service.RotinasOracleService.IdadePet;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.List;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class RotinasOracleServiceTest {

    @Mock
    private RotinasOracleRepository repository;

    @InjectMocks
    private RotinasOracleService service;

    @Test
    @DisplayName("calcularIdade - monta o DTO com a data e a idade do banco")
    void calcularIdade() {
        LocalDate nascimento = LocalDate.of(2022, 9, 2);
        when(repository.calcularIdade(nascimento)).thenReturn(4);

        IdadePet resposta = service.calcularIdade(nascimento);

        assertThat(resposta.dataNascimento()).isEqualTo(nascimento);
        assertThat(resposta.idadeAnos()).isEqualTo(4);
    }

    @Test
    @DisplayName("listarPetsJson - repassa o filtro de tutor ao pacote")
    void listarPetsJson() {
        when(repository.listarPetsJson(7L)).thenReturn("[]");

        assertThat(service.listarPetsJson(7L)).isEqualTo("[]");
        verify(repository).listarPetsJson(7L);
    }

    @Test
    @DisplayName("exportarTutoresJson - devolve o JSON gerado pelo pacote")
    void exportarTutoresJson() {
        when(repository.exportarTutoresJson()).thenReturn("[{\"_id\":1}]");

        assertThat(service.exportarTutoresJson()).isEqualTo("[{\"_id\":1}]");
    }

    @Test
    @DisplayName("gerarRelatorioCustos - devolve as linhas do relatório")
    void gerarRelatorioCustos() {
        LinhaRelatorioCusto total = new LinhaRelatorioCusto(9L, null, null, new BigDecimal("1500.00"), "TOTAL");
        when(repository.gerarRelatorioCustos(null)).thenReturn(List.of(total));

        assertThat(service.gerarRelatorioCustos(null)).containsExactly(total);
    }
}
