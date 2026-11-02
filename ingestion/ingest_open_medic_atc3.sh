#!/usr/bin/env bash
# Ingestion des consommants Open Medic par classe ATC3 x âge x sexe x région -> S3 raw
# Exécuté depuis AWS CloudShell. Usage : bash ingest_open_medic_atc3.sh [annees...]
# Le schéma est détecté via l'en-tête : sans libellé (2014-2015) -> préfixe *_v2014
set -euo pipefail

BUCKET="alex-sante-mentale-620176731553"
BASE="https://open-data-assurance-maladie.ameli.fr/medicaments"
TMP="/tmp/om"
YEARS="${*:-$(seq 2014 2025)}"
mkdir -p "$TMP"

for Y in $YEARS; do
  LINK=$(curl -sL "$BASE/download2.php?Dir_Rep=${Y}_ATC3" \
         | grep -io 'download_file.php?[^"]*atc3_age_sexe_reg\.csv\.gz' | head -1 || true)
  if [ -z "$LINK" ]; then
    echo "$Y : LIEN INTROUVABLE"
    continue
  fi
  curl -sfL -o "$TMP/atc3_$Y.gz" "$BASE/$LINK"
  HEADER=$(zcat "$TMP/atc3_$Y.gz" | head -1 | iconv -f latin1 -t utf-8 || true)
  if echo "$HEADER" | grep -qi 'l_atc3'; then
    PREFIX="consommants_atc3_reg"
  else
    PREFIX="consommants_atc3_reg_v2014"
  fi
  zcat "$TMP/atc3_$Y.gz" | iconv -f latin1 -t utf-8 | gzip \
    | aws s3 cp - "s3://$BUCKET/raw/open_medic/$PREFIX/annee=$Y/nb_atc3_age_sexe_reg_$Y.csv.gz" --only-show-errors
  rm -f "$TMP/atc3_$Y.gz"
  echo "$Y -> $PREFIX : $HEADER"
done
echo "Termine."
