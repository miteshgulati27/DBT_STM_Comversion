{%- macro m_remove_duplicate_cl_keys(
    in_relation,
    in_cl_key_col,
    in_order_by_col,
    in_order_direction='DESC'
) -%}

{#--
    Removes duplicate CL (Client/Cluster) key records, keeping only
    the most recent based on the specified ordering.

    Arguments:
        in_relation: Source relation to deduplicate
        in_cl_key_col: The CL key column to deduplicate on
        in_order_by_col: Column to order by for selecting the keeper
        in_order_direction: ASC or DESC (default: DESC - keeps latest)
--#}

WITH ranked AS (
    SELECT
        *,
        ROW_NUMBER() OVER (
            PARTITION BY {{ in_cl_key_col }}
            ORDER BY {{ in_order_by_col }} {{ in_order_direction }}
        ) AS dup_rank
    FROM {{ in_relation }}
)

SELECT *
FROM ranked
WHERE dup_rank = 1

{%- endmacro -%}
