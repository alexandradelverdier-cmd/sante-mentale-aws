with

v2016 as (
    select annee, trim(atc3) as atc3_code, trim(age) as tranche_age_code,
           trim(sexe) as sexe_code, trim(ben_reg) as region_code,
           nbc, boites, rem
    from {{ source('open_medic', 'open_medic_consommants_atc3') }}
),

v2014 as (
    select annee, trim(atc3) as atc3_code, trim(age) as tranche_age_code,
           trim(sexe) as sexe_code, trim(ben_reg) as region_code,
           nbc, boites, rem
    from {{ source('open_medic', 'open_medic_consommants_atc3_v2014') }}
),

unioned as (
    select * from v2016
    union all
    select * from v2014
)

select
    annee,
    atc3_code,
    tranche_age_code,
    sexe_code,
    region_code,
    cast({{ parse_fr_number('nbc') }} as bigint)    as nb_consommants,
    cast({{ parse_fr_number('boites') }} as bigint) as nb_boites,
    {{ parse_fr_number('rem') }}                    as montant_rembourse
from unioned
