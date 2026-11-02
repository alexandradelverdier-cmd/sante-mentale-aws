-- Grain : région x classe de psychotropes x année
-- Les tranches d'âge et sexes sont disjoints, on peut donc les additionner
with base as (
    select
        c.annee,
        c.region_code,
        p.classe_courte,
        p.classe_libelle,
        sum(c.nb_consommants)    as nb_consommants,
        sum(c.nb_boites)         as nb_boites,
        sum(c.montant_rembourse) as montant_rembourse
    from {{ ref('stg_open_medic__consommants_atc3') }} as c
    inner join {{ ref('ref_classes_psychotropes') }} as p
        on c.atc3_code = p.atc3_code
    group by 1, 2, 3, 4
)

select
    b.annee,
    b.region_code,
    r.region_libelle,
    r.est_region_connue,
    b.classe_courte,
    b.classe_libelle,
    b.nb_consommants,
    b.nb_boites,
    b.montant_rembourse,
    -- Évolution annuelle
    lag(b.nb_consommants) over (
        partition by b.region_code, b.classe_courte order by b.annee
    ) as nb_consommants_annee_prec,
    -- Part de la classe non attribuée à une région (secret statistique, inconnus)
    sum(case when not r.est_region_connue then b.nb_consommants else 0 end) over (
        partition by b.classe_courte, b.annee
    ) * 1.0 / sum(b.nb_consommants) over (partition by b.classe_courte, b.annee)
      as part_nationale_non_regionalisee
from base as b
inner join {{ ref('ref_regions') }} as r
    on b.region_code = r.region_code
