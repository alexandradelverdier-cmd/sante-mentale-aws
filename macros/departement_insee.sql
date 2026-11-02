{% macro departement_insee(column) %}
    case
        when length({{ column }}) = 3 and substr({{ column }}, 1, 1) = '0'
            then substr({{ column }}, 2)
        else {{ column }}
    end
{% endmacro %}
