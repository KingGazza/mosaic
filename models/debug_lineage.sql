{{ config(materialized='table') }}

with ddl as (
    select get_ddl('view', 'SALESENGINEERINGDEMODB.BAM.DBT_GL_MODEL') as ddl_text
),
table_alias_pairs as (
    select
        t.value::string as source_table,
        a.value::string as alias
    from ddl,
    lateral flatten(input => regexp_substr_all(ddl_text, '(from|join)\\s+([\\w.]+)\\s+(as\\s+)?(\\w+)', 1, 1, 'ei', 2)) t,
    lateral flatten(input => regexp_substr_all(ddl_text, '(from|join)\\s+([\\w.]+)\\s+(as\\s+)?(\\w+)', 1, 1, 'ei', 4)) a
    where t.index = a.index
),
col_refs as (
    select
        al.value::string as alias,
        col.value::string as column_name
    from ddl,
    lateral flatten(input => regexp_substr_all(ddl_text, '(\\w+)\\.(\\w+)', 1, 1, 'e', 1)) al,
    lateral flatten(input => regexp_substr_all(ddl_text, '(\\w+)\\.(\\w+)', 1, 1, 'e', 2)) col
    where al.index = col.index
)
select distinct
    split_part(tap.source_table, '.', -1) as depends_on,
    cr.column_name
from col_refs cr
join table_alias_pairs tap
    on lower(cr.alias) = lower(tap.alias)