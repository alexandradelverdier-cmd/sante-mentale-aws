with

v2016 as (
    select
        annee,
        trim(atc5)    as atc5_code,
        trim(l_atc5)  as atc5_libelle,
        trim(age)     as tranche_age_code,
        trim(sexe)    as sexe_code,
        trim(ben_reg) as region_code,
        nbc, boites, rem, bse
    from {{ source('open_medic', 'open_medic_consommants') }}
),

v2014 as (
    select
        annee,
        trim(atc5)              as atc5_code,
        cast(null as varchar)   as atc5_libelle,  -- absent avant 2016, récupéré via le référentiel ATC
        trim(age)               as tranche_age_code,
        trim(sexe)              as sexe_code,
        trim(ben_reg)           as region_code,
        nbc, boites, rem, bse
    from {{ source('open_medic', 'open_medic_consommants_v2014') }}
),

unioned as (
    select * from v2016
    union all
    select * from v2014
)

select
    annee,
    atc5_code,
    atc5_libelle,
    tranche_age_code,
    sexe_code,
    region_code,
    cast({{ parse_fr_number('nbc') }} as bigint)    as nb_consommants,
    cast({{ parse_fr_number('boites') }} as bigint) as nb_boites,
    {{ parse_fr_number('rem') }}                    as montant_rembourse,
    {{ parse_fr_number('bse') }}                    as base_remboursement
from unioned
