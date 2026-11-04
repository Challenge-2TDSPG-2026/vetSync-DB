// MongoDB local - ClyvoVet
// Execute:  mongosh "mongodb://localhost:27017" mongo/01_criar_colecao.js
//
// Modelo: UM DOCUMENTO POR TUTOR, com o ARRAY DE PETS embutido.
// Motivo: o app sempre abre "o tutor e seus pets" juntos, entao o embedding evita
// JOINs ($lookup) nas leituras mais frequentes. Os eventos de saude (crescem sem
// limite) ficam fora do documento, para nao estourar o limite de 16 MB.

const bd = db.getSiblingDB("clyvovet");

bd.tutores.drop();

bd.createCollection("tutores", {
  validator: {
    $jsonSchema: {
      bsonType: "object",
      required: ["_id", "nome", "email", "pets"],
      properties: {
        _id:           { bsonType: "number" },
        nome:          { bsonType: "string", minLength: 1 },
        email:         { bsonType: "string", pattern: "^.+@.+$" },
        telefone:      { bsonType: ["string", "null"] },
        data_cadastro: { bsonType: "date" },
        pets: {
          bsonType: "array",
          items: {
            bsonType: "object",
            required: ["id_pet", "nome", "raca", "especie"],
            properties: {
              id_pet:          { bsonType: "number" },
              nome:            { bsonType: "string", minLength: 1 },
              data_nascimento: { bsonType: "date" },
              sexo:            { enum: ["M", "F", null] },
              peso_kg:         { bsonType: ["number", "null"] },
              raca:            { bsonType: "string" },
              especie:         { bsonType: "string" }
            }
          }
        }
      }
    }
  },
  validationLevel: "strict",
  validationAction: "error"
});

bd.tutores.createIndex({ email: 1 }, { unique: true, name: "ux_tutores_email" });
bd.tutores.createIndex({ "pets.nome": 1 }, { name: "ix_tutores_pets_nome" });
bd.tutores.createIndex({ "pets.especie": 1 }, { name: "ix_tutores_pets_especie" });

print("Colecao 'tutores' criada em clyvovet (validador + 3 indices).");
printjson(bd.tutores.getIndexes().map(i => i.name));
