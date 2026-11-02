-- Psychiatres (spécialité 12, pédopsychiatrie incluse) au 1er janvier, par département et mode d'exercice
-- exercice_code : 0 Ensemble, 1 Libéral, 2 Mixte, 3 Salarié hospitalier, 4 Autre salarié
select
    annee,
    region_insee_code,
    departement_code,
    departement_libelle,
    exercice_code,
    exercice_libelle,
    cast(effectif as bigint) as nb_psychiatres
from {{ source('drees', 'drees_medecins_rpps') }}
where specialite_code = '12'
