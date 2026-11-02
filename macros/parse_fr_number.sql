{% macro parse_fr_number(column) %}
    try_cast(replace(replace(trim({{ column }}), '.', ''), ',', '.') as double)
{% endmacro %}
