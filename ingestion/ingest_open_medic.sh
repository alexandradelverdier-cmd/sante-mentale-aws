#!/usr/bin/env bash
# Ingestion Open Medic -> S3 (couche raw), UTF-8 gzip, partitionné par année
# Exécuté depuis AWS CloudShell. Usage : bash ingest_open_medic.sh [annees...]
# Note : 2014-2015 ont un schéma sans libellés, déplacés ensuite vers les préfixes *_v2014/
set -euo pipefail

BUCKET="alex-sante-mentale-620176731553"
BASE="https://open-data-assurance-maladie.ameli.fr/medicaments"
TMP="/tmp/om"
YEARS="${*:-$(seq 2014 2025)}"
mkdir -p "$TMP"

for Y in $YEARS; do
  echo "=== $Y ==="

  LINK=$(curl -sL "$BASE/download.php?Dir_Rep=Open_MEDIC_Base_Complete&Annee=$Y" \
         | grep -io 'download_file.php?[^"]*\.zip' | head -1 || true)
  if [ -n "$LINK" ]; then
    curl -sfL -o "$TMP/base_$Y.zip" "$BASE/$LINK"
    HEADER=$(unzip -p "$TMP/base_$Y.zip" | head -1 | iconv -f latin1 -t utf-8 || true)
    unzip -p "$TMP/base_$Y.zip" | iconv -f latin1 -t utf-8 | gzip \
      | aws s3 cp - "s3://$BUCKET/raw/open_medic/base_complete/annee=$Y/open_medic_$Y.csv.gz" --only-show-errors
    rm -f "$TMP/base_$Y.zip"
    echo "  base complete OK : $HEADER"
  else
    echo "  base complete : LIEN INTROUVABLE"
  fi

  LINK=$(curl -sL "$BASE/download2.php?Dir_Rep=${Y}_ATC5" \
         | grep -io 'download_file.php?[^"]*atc5_age_sexe_reg\.csv\.gz' | head -1 || true)
  if [ -n "$LINK" ]; then
    curl -sfL -o "$TMP/conso_$Y.gz" "$BASE/$LINK"
    HEADER=$(zcat "$TMP/conso_$Y.gz" | head -1 | iconv -f latin1 -t utf-8 || true)
    zcat "$TMP/conso_$Y.gz" | iconv -f latin1 -t utf-8 | gzip \
      | aws s3 cp - "s3://$BUCKET/raw/open_medic/consommants_atc5_reg/annee=$Y/nb_atc5_age_sexe_reg_$Y.csv.gz" --only-show-errors
    rm -f "$TMP/conso_$Y.gz"
    echo "  consommants OK : $HEADER"
  else
    echo "  consommants : LIEN INTROUVABLE"
  fi
done
echo "Termine."
