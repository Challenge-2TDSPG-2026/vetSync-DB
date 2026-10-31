package br.com.fiap.vetsync.database.exception;

/** Erro de negocio levantado pelo PL/SQL via RAISE_APPLICATION_ERROR (ORA-20000 a ORA-20999). */
public class RotinaOracleException extends RuntimeException {

    private final int codigoOracle;

    public RotinaOracleException(int codigoOracle, String mensagem, Throwable causa) {
        super(mensagem, causa);
        this.codigoOracle = codigoOracle;
    }

    public int getCodigoOracle() {
        return codigoOracle;
    }
}
