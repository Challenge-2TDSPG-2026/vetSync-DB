package br.com.fiap.vetsync.database.service;

import br.com.fiap.vetsync.database.dto.IdadePetResponse;
import br.com.fiap.vetsync.database.dto.LinhaRelatorioCusto;
import br.com.fiap.vetsync.database.repository.RotinasOracleRepository;
import org.springframework.stereotype.Service;

import java.time.LocalDate;
import java.util.List;

@Service
public class RotinasOracleService {

    private final RotinasOracleRepository repository;

    public RotinasOracleService(RotinasOracleRepository repository) {
        this.repository = repository;
    }

    public String listarPetsJson(Long idTutor) {
        return repository.listarPetsJson(idTutor);
    }

    public String exportarTutoresJson() {
        return repository.exportarTutoresJson();
    }

    public IdadePetResponse calcularIdade(LocalDate dataNascimento) {
        return new IdadePetResponse(dataNascimento, repository.calcularIdade(dataNascimento));
    }

    public List<LinhaRelatorioCusto> gerarRelatorioCustos(Long idClinica) {
        return repository.gerarRelatorioCustos(idClinica);
    }
}
