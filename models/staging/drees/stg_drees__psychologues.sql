-- Psychologues au 1er janvier, par département et mode d'exercice (tous secteurs confondus)
-- exercice_code : 0 Ensemble, 1 Libéraux ou mixtes, 2 Salariés hospitaliers, 3 Autres salariés
select
    annee,
    region_insee_code,
    departement_code,
    departement_libelle,
    exercice_code,
    exercice_libelle,
    cast(effectif as bigint) as nb_psychologues
from {{ source('drees', 'drees_psychologues_adeli') }}
where secteur_code = '00'
