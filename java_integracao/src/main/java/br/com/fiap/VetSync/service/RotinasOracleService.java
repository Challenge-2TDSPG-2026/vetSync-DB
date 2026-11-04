package br.com.fiap.VetSync.service;

import br.com.fiap.VetSync.repository.RotinasOracleRepository;
import br.com.fiap.VetSync.repository.RotinasOracleRepository.LinhaRelatorioCusto;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;

import java.time.LocalDate;
import java.util.List;

/** Casos de uso que executam os pacotes PL/SQL do banco (migration V57). */
@Service
@RequiredArgsConstructor
public class RotinasOracleService {

    public record IdadePet(LocalDate dataNascimento, int idadeAnos) {}

    private final RotinasOracleRepository repository;

    public String listarPetsJson(Long idTutor) {
        return repository.listarPetsJson(idTutor);
    }

    public String exportarTutoresJson() {
        return repository.exportarTutoresJson();
    }

    public IdadePet calcularIdade(LocalDate dataNascimento) {
        return new IdadePet(dataNascimento, repository.calcularIdade(dataNascimento));
    }

    public List<LinhaRelatorioCusto> gerarRelatorioCustos(Long idClinica) {
        return repository.gerarRelatorioCustos(idClinica);
    }
}
