// Consultas de demonstracao (video).
// Execute:  mongosh "mongodb://localhost:27017" mongo/03_consultas.js

const bd = db.getSiblingDB("clyvovet");

print("\n1) Total de tutores:");
print(bd.tutores.countDocuments());

print("\n2) Tutores com seus pets (nome do tutor + nomes dos pets):");
bd.tutores.find({}, { nome: 1, "pets.nome": 1 }).forEach(printjson);

print("\n3) Tutores com 2 ou mais pets:");
bd.tutores.find({ $expr: { $gte: [{ $size: "$pets" }, 2] } }, { nome: 1 }).forEach(printjson);

print("\n4) Tutores SEM pets:");
bd.tutores.find({ pets: { $size: 0 } }, { nome: 1 }).forEach(printjson);

print("\n5) Quem e o tutor do pet 'Rex'? (usa o indice pets.nome)");
printjson(bd.tutores.findOne({ "pets.nome": "Rex" }, { nome: 1, email: 1 }));

print("\n6) Quantidade de pets e peso medio por especie:");
bd.tutores.aggregate([
  { $unwind: "$pets" },
  { $group: { _id: "$pets.especie", qtd_pets: { $sum: 1 }, peso_medio_kg: { $avg: "$pets.peso_kg" } } },
  { $sort: { _id: 1 } }
]).forEach(printjson);

print("\n7) Teste do validador (deve falhar: e-mail invalido):");
try {
  bd.tutores.insertOne({ _id: 999, nome: "Teste", email: "invalido", pets: [] });
} catch (e) {
  print("Rejeitado como esperado: " + e.codeName);
}
