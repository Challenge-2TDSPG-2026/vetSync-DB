package br.com.fiap.VetSync.controller;

import br.com.fiap.VetSync.repository.RotinasOracleRepository.LinhaRelatorioCusto;
import br.com.fiap.VetSync.service.RotinasOracleService;
import br.com.fiap.VetSync.service.RotinasOracleService.IdadePet;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.test.mock.mockito.MockBean;
import org.springframework.http.HttpStatus;
import org.springframework.security.test.context.support.WithMockUser;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.web.server.ResponseStatusException;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.List;

import static org.mockito.Mockito.when;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.content;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

@SpringBootTest
@AutoConfigureMockMvc
class RotinasOracleControllerTest {

    @Autowired
    private MockMvc mockMvc;

    @MockBean
    private RotinasOracleService service;

    @Test
    @DisplayName("GET /banco/pets/json - ADMIN recebe o JSON do pacote")
    @WithMockUser(roles = "ADMIN")
    void listarPetsJson() throws Exception {
        when(service.listarPetsJson(3L)).thenReturn("[{\"id_pet\":1}]");

        mockMvc.perform(get("/banco/pets/json").param("tutorId", "3"))
                .andExpect(status().isOk())
                .andExpect(content().json("[{\"id_pet\":1}]"));
    }

    @Test
    @DisplayName("GET /banco/pets/json - tutor sem pets devolve 404 com a mensagem do banco")
    @WithMockUser(roles = "ADMIN")
    void listarPetsJsonSemDados() throws Exception {
        when(service.listarPetsJson(99L))
                .thenThrow(new ResponseStatusException(HttpStatus.NOT_FOUND, "Nenhum pet encontrado."));

        mockMvc.perform(get("/banco/pets/json").param("tutorId", "99"))
                .andExpect(status().isNotFound())
                .andExpect(jsonPath("$.mensagem").value("Nenhum pet encontrado."));
    }

    @Test
    @DisplayName("GET /banco/pets/json - TUTOR não acessa (403)")
    @WithMockUser(roles = "TUTOR")
    void listarPetsJsonProibidoParaTutor() throws Exception {
        mockMvc.perform(get("/banco/pets/json"))
                .andExpect(status().isForbidden());
    }

    @Test
    @DisplayName("GET /banco/pets/idade - TUTOR pode calcular a idade")
    @WithMockUser(roles = "TUTOR")
    void calcularIdade() throws Exception {
        LocalDate nascimento = LocalDate.of(2022, 9, 2);
        when(service.calcularIdade(nascimento)).thenReturn(new IdadePet(nascimento, 4));

        mockMvc.perform(get("/banco/pets/idade").param("dataNascimento", "2022-09-02"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.idadeAnos").value(4));
    }

    @Test
    @DisplayName("GET /banco/relatorios/custos - ADMIN recebe detalhe, subtotal e total")
    @WithMockUser(roles = "ADMIN")
    void relatorioCustos() throws Exception {
        when(service.gerarRelatorioCustos(null)).thenReturn(List.of(
                new LinhaRelatorioCusto(1L, "Clínica Centro", "Consulta", new BigDecimal("150.00"), "DETALHE"),
                new LinhaRelatorioCusto(2L, null, null, new BigDecimal("150.00"), "TOTAL")));

        mockMvc.perform(get("/banco/relatorios/custos"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$[0].tipoLinha").value("DETALHE"))
                .andExpect(jsonPath("$[1].tipoLinha").value("TOTAL"));
    }

    @Test
    @DisplayName("GET /banco/exportacao/tutores - sem autenticação devolve 401")
    void exportarSemAutenticacao() throws Exception {
        mockMvc.perform(get("/banco/exportacao/tutores"))
                .andExpect(status().isUnauthorized());
    }

    @Test
    @DisplayName("GET /banco/exportacao/tutores - ADMIN recebe o JSON dos tutores")
    @WithMockUser(roles = "ADMIN")
    void exportarTutores() throws Exception {
        when(service.exportarTutoresJson()).thenReturn("[{\"_id\":1,\"pets\":[]}]");

        mockMvc.perform(get("/banco/exportacao/tutores"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$[0]._id").value(1));
    }
}
