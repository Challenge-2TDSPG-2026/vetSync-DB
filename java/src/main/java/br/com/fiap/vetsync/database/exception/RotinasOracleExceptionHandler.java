package br.com.fiap.vetsync.database.exception;

import org.springframework.http.HttpStatus;
import org.springframework.http.ProblemDetail;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.RestControllerAdvice;

import java.util.Set;

/** Converte os erros ORA-20xxx dos pacotes em respostas HTTP (404 sem dados, 422 dado invalido). */
@RestControllerAdvice
public class RotinasOracleExceptionHandler {

    /** ORA-20110 sem pets, ORA-20130 sem eventos, ORA-20150 sem tutores. */
    private static final Set<Integer> SEM_DADOS = Set.of(20110, 20130, 20150);

    @ExceptionHandler(RotinaOracleException.class)
    public ProblemDetail tratar(RotinaOracleException ex) {
        HttpStatus status = SEM_DADOS.contains(ex.getCodigoOracle())
                ? HttpStatus.NOT_FOUND
                : HttpStatus.UNPROCESSABLE_ENTITY;

        ProblemDetail problema = ProblemDetail.forStatusAndDetail(status, ex.getMessage());
        problema.setTitle("Erro de regra no banco de dados (ORA-" + ex.getCodigoOracle() + ")");
        problema.setProperty("codigoOracle", ex.getCodigoOracle());
        return problema;
    }
}
