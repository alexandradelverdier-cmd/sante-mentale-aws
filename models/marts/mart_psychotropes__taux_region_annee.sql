-- Grain : région x classe de psychotropes x année (régions connues uniquement)
-- Taux brut et taux standardisé (âge x sexe, population de référence : France entière 2025)
with conso as (
    select
        c.annee, c.region_code, c.tranche_age_code, c.sexe_code,
        p.classe_courte, p.classe_libelle,
        sum(c.nb_consommants) as nb_consommants
    from {{ ref('stg_open_medic__consommants_atc3') }} as c
    inner join {{ ref('ref_classes_psychotropes') }} as p
        on c.atc3_code = p.atc3_code
    group by 1, 2, 3, 4, 5, 6
),

pop as (
    select * from {{ ref('int_insee__population_open_medic') }}
),

pop_reference as (
    select
        tranche_age_code,
        sexe_code,
        sum(population_moyenne) * 1.0
          / sum(sum(population_moyenne)) over () as poids
    from pop
    where annee = 2025
    group by 1, 2
),

-- Taux par strate âge x sexe (les âges et sexes inconnus n'ont pas de population : exclus ici)
strates as (
    select
        c.annee, c.region_code, c.classe_courte,
        c.nb_consommants * 1.0 / p.population_moyenne * r.poids as taux_pondere
    from conso as c
    inner join pop as p
        on  c.annee = p.annee
        and c.region_code = p.region_code
        and c.tranche_age_code = p.tranche_age_code
        and c.sexe_code = p.sexe_code
    inner join pop_reference as r
        on  c.tranche_age_code = r.tranche_age_code
        and c.sexe_code = r.sexe_code
),

standardise as (
    select annee, region_code, classe_courte, sum(taux_pondere) as taux_standardise
    from strates
    group by 1, 2, 3
),

-- Taux brut : tous les consommants de la région, y compris âge ou sexe inconnu
brut as (
    select
        c.annee, c.region_code, c.classe_courte, c.classe_libelle,
        sum(c.nb_consommants) as nb_consommants,
        sum(case when c.tranche_age_code = '99' or c.sexe_code = '9'
                 then c.nb_consommants else 0 end) as nb_consommants_age_sexe_inconnu
    from conso as c
    group by 1, 2, 3, 4
),

pop_totale as (
    select annee, region_code, sum(population_moyenne) as population_moyenne
    from pop
    group by 1, 2
)

select
    b.annee,
    b.region_code,
    r.region_libelle,
    b.classe_courte,
    b.classe_libelle,
    b.nb_consommants,
    t.population_moyenne,
    round(1000 * b.nb_consommants / t.population_moyenne, 2) as taux_brut_pour_1000,
    round(1000 * s.taux_standardise, 2)                       as taux_standardise_pour_1000,
    round(1.0 * b.nb_consommants_age_sexe_inconnu / b.nb_consommants, 4) as part_age_sexe_inconnu
from brut as b
inner join pop_totale as t
    on b.annee = t.annee and b.region_code = t.region_code
inner join standardise as s
    on b.annee = s.annee and b.region_code = s.region_code and b.classe_courte = s.classe_courte
inner join {{ ref('ref_regions') }} as r
    on b.region_code = r.region_code
