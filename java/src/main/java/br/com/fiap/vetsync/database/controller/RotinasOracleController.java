package br.com.fiap.vetsync.database.controller;

import br.com.fiap.vetsync.database.dto.IdadePetResponse;
import br.com.fiap.vetsync.database.dto.LinhaRelatorioCusto;
import br.com.fiap.vetsync.database.service.RotinasOracleService;
import org.springframework.format.annotation.DateTimeFormat;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import java.time.LocalDate;
import java.util.List;

/** Endpoints que executam os pacotes PL/SQL do Oracle (usados na demonstracao em video). */
@RestController
@RequestMapping("/api/db")
public class RotinasOracleController {

    private final RotinasOracleService service;

    public RotinasOracleController(RotinasOracleService service) {
        this.service = service;
    }

    /** GET /api/db/pets/json?tutorId=1 (tutorId opcional) */
    @GetMapping(value = "/pets/json", produces = MediaType.APPLICATION_JSON_VALUE)
    public ResponseEntity<String> listarPetsJson(@RequestParam(required = false) Long tutorId) {
        return ResponseEntity.ok(service.listarPetsJson(tutorId));
    }

    /** GET /api/db/pets/idade?dataNascimento=2022-09-02 */
    @GetMapping("/pets/idade")
    public IdadePetResponse calcularIdade(
            @RequestParam @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate dataNascimento) {
        return service.calcularIdade(dataNascimento);
    }

    /** GET /api/db/relatorios/custos?clinicaId=1 (clinicaId opcional) */
    @GetMapping("/relatorios/custos")
    public List<LinhaRelatorioCusto> relatorioCustos(@RequestParam(required = false) Long clinicaId) {
        return service.gerarRelatorioCustos(clinicaId);
    }

    /** GET /api/db/exportacao/tutores -> mesmo JSON que o mongoimport recebe */
    @GetMapping(value = "/exportacao/tutores", produces = MediaType.APPLICATION_JSON_VALUE)
    public ResponseEntity<String> exportarTutores() {
        return ResponseEntity.ok(service.exportarTutoresJson());
    }
}
