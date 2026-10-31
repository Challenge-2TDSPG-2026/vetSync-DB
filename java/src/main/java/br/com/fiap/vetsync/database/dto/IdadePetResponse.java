package br.com.fiap.vetsync.database.dto;

import java.time.LocalDate;

public record IdadePetResponse(LocalDate dataNascimento, int idadeAnos) {
}
