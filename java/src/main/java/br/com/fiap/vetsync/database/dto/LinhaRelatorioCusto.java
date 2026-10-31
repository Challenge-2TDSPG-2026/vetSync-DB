package br.com.fiap.vetsync.database.dto;

import java.math.BigDecimal;

/** Uma linha de TB_RELATORIO_CUSTOS_CLINICA (tipoLinha: DETALHE, SUBTOTAL ou TOTAL). */
public record LinhaRelatorioCusto(
        Long idLinha,
        String clinica,
        String tipoEvento,
        BigDecimal valorTotal,
        String tipoLinha
) {
}
