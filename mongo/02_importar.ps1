# Importa o tutores.json (gerado pelo Oracle) para o MongoDB local.
# Execute:   .\02_importar.ps1      (ou  .\mongo\02_importar.ps1  a partir da raiz do repositorio)
# Pre-requisitos: MongoDB em localhost:27017 e MongoDB Database Tools (mongoimport) no PATH.
# Rode antes: mongosh "mongodb://localhost:27017" 01_criar_colecao.js
# (sem --drop, para nao apagar o validador e os indices da colecao).

$candidatos = @(
  (Join-Path $PSScriptRoot "tutores.json"),
  (Join-Path $PSScriptRoot "..\dados\tutores.json")
)
$arquivo = $candidatos | Where-Object { Test-Path $_ } | Select-Object -First 1
if (-not $arquivo) { Write-Error "tutores.json nao encontrado."; exit 1 }

mongoimport `
  --uri "mongodb://localhost:27017" `
  --db clyvovet `
  --collection tutores `
  --jsonArray `
  --file $arquivo

mongosh "mongodb://localhost:27017/clyvovet" --quiet --eval "print('Documentos importados: ' + db.tutores.countDocuments())"
