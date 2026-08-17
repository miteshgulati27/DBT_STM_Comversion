
{%- set term_table_name = 'pcx_bopsbllocationcov' -%}
{%- set lob = 'BOP' -%}
{%- set clause_type = 'COVG' -%}
{%- set cvrbl_key = 'CVRBL_KEY' -%}
{%- set cvrbl_key_text = 'BOPLocation' -%}
{%- set cvrbl_key_src_col = 'SBLLOCATION' -%}
{%- set clause_key_text = 'BOPLocationCov' -%}

{{ config(
    materialized='table'
) }}

{{ m_int_term(term_table_name, lob, clause_type, cvrbl_key, cvrbl_key_text, cvrbl_key_src_col, clause_key_text) }}