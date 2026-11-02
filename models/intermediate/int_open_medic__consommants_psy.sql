-- Consommants de psychotropes, grain : molécule (ATC5) x âge x sexe x région x année
-- Attention : ne pas sommer nb_consommants entre molécules (une personne peut en prendre plusieurs)
with consommants as (
    select
        *,
        substr(atc5_code, 1, 4) as atc3_code
    from {{ ref('stg_open_medic__consommants') }}
)

select
    c.annee,
    c.region_code,
    c.tranche_age_code,
    c.sexe_code,
    c.atc3_code,
    p.classe_courte,
    p.classe_libelle,
    c.atc5_code,
    coalesce(c.atc5_libelle, r.atc5_libelle, k.atc5_libelle) as atc5_libelle,
    c.nb_consommants,
    c.nb_boites,
    c.montant_rembourse
from consommants as c
inner join {{ ref('ref_classes_psychotropes') }} as p
    on c.atc3_code = p.atc3_code
left join {{ ref('int_atc__referentiel') }} as r
    on c.atc5_code = r.atc5_code
left join {{ ref('ref_atc5_complements') }} as k
    on c.atc5_code = k.atc5_code
