package br.com.fiap.VetSync.controller;

import br.com.fiap.VetSync.repository.RotinasOracleRepository.LinhaRelatorioCusto;
import br.com.fiap.VetSync.service.RotinasOracleService;
import br.com.fiap.VetSync.service.RotinasOracleService.IdadePet;
import io.swagger.v3.oas.annotations.tags.Tag;
import lombok.RequiredArgsConstructor;
import org.springframework.format.annotation.DateTimeFormat;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import java.time.LocalDate;
import java.util.List;

/** Endpoints que executam os pacotes PL/SQL do Oracle (disciplina de banco de dados, Sprint 4). */
@RestController
@RequestMapping("/banco")
@RequiredArgsConstructor
@Tag(name = "Rotinas do banco (PL/SQL)")
public class RotinasOracleController {

    private final RotinasOracleService service;

    /** JSON de pets com tutor, raça e espécie (PKG_JSON_PET). Sem {@code tutorId}, lista todos. */
    @GetMapping(value = "/pets/json", produces = MediaType.APPLICATION_JSON_VALUE)
    @PreAuthorize("hasRole('ADMIN')")
    public ResponseEntity<String> listarPetsJson(@RequestParam(required = false) Long tutorId) {
        return ResponseEntity.ok(service.listarPetsJson(tutorId));
    }

    /** Idade em anos completos calculada pelo banco (PKG_PET). */
    @GetMapping("/pets/idade")
    @PreAuthorize("hasAnyRole('ADMIN','ADMIN_CLINICA','VETERINARIO','TUTOR')")
    public IdadePet calcularIdade(
            @RequestParam @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate dataNascimento) {
        return service.calcularIdade(dataNascimento);
    }

    /** Custos por clínica e tipo de evento, com subtotais e total geral (PKG_RELATORIO_CUSTOS). */
    @GetMapping("/relatorios/custos")
    @PreAuthorize("hasRole('ADMIN')")
    public List<LinhaRelatorioCusto> relatorioCustos(@RequestParam(required = false) Long clinicaId) {
        return service.gerarRelatorioCustos(clinicaId);
    }

    /** Tutores com array de pets no formato importado pelo MongoDB (PKG_EXPORTACAO_JSON). */
    @GetMapping(value = "/exportacao/tutores", produces = MediaType.APPLICATION_JSON_VALUE)
    @PreAuthorize("hasRole('ADMIN')")
    public ResponseEntity<String> exportarTutores() {
        return ResponseEntity.ok(service.exportarTutoresJson());
    }
}
