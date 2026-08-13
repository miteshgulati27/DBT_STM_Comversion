{%- macro m_lel_pit_dt(
    in_date_col,
    in_pit_date=none,
    in_effective_date_col='EFFECTIVE_DATE',
    in_expiry_date_col='EXPIRY_DATE'
) -%}

{#--
    Point-In-Time Date filter macro (LEL variant).
    Filters records to show the state as of a specific date.

    Arguments:
        in_date_col: The reference date column (or literal)
        in_pit_date: Point-in-time date (default: CURRENT_DATE)
        in_effective_date_col: Effective date column name
        in_expiry_date_col: Expiry date column name
--#}

    {% if in_pit_date is not none %}
        {{ in_effective_date_col }} <= '{{ in_pit_date }}'::DATE
        AND {{ in_expiry_date_col }} >= '{{ in_pit_date }}'::DATE
    {% else %}
        {{ in_effective_date_col }} <= CURRENT_DATE()
        AND {{ in_expiry_date_col }} >= CURRENT_DATE()
    {% endif %}

{%- endmacro -%}
