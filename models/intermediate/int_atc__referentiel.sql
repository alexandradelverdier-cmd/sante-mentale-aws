-- Référentiel ATC : une ligne par molécule, libellés de l'année la plus récente
-- Sert à compléter les libellés absents des fichiers 2014-2015
select
    atc5_code,
    max_by(atc5_libelle, annee) as atc5_libelle,
    max_by(atc4_code, annee)    as atc4_code,
    max_by(atc4_libelle, annee) as atc4_libelle,
    max_by(atc3_code, annee)    as atc3_code,
    max_by(atc3_libelle, annee) as atc3_libelle,
    max_by(atc2_code, annee)    as atc2_code,
    max_by(atc2_libelle, annee) as atc2_libelle,
    max_by(atc1_code, annee)    as atc1_code,
    max_by(atc1_libelle, annee) as atc1_libelle,
    min(annee)                  as premiere_annee,
    max(annee)                  as derniere_annee
from {{ ref('stg_open_medic__base') }}
where atc5_libelle is not null
group by atc5_code
