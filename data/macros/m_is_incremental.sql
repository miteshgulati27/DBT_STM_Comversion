{%- macro m_is_incremental() -%}

    {#-- Custom incremental check macro.
         Returns TRUE if the model is running in incremental mode,
         FALSE if running a full refresh. --#}

    {%- if execute -%}
        {%- set ns = namespace(is_incremental=false) -%}

        {%- if flags.FULL_REFRESH -%}
            {%- set ns.is_incremental = false -%}
        {%- elif model.config.materialized == 'incremental' -%}
            {#-- Check if the target relation already exists --#}
            {%- set target_relation = adapter.get_relation(
                database=model.database,
                schema=model.schema,
                identifier=model.alias
            ) -%}
            {%- if target_relation is not none -%}
                {%- set ns.is_incremental = true -%}
            {%- else -%}
                {%- set ns.is_incremental = false -%}
            {%- endif -%}
        {%- else -%}
            {%- set ns.is_incremental = false -%}
        {%- endif -%}

        {{ return(ns.is_incremental) }}
    {%- endif -%}

{%- endmacro -%}
