{{ config(materialized='table') }}

{% set nodes = graph.nodes.values() | selectattr('resource_type', 'equalto', 'model') | list %}
{% set rows = [] %}
{% for node in nodes %}
    {% for dep_id in node.depends_on.nodes %}
        {% set dep = graph.nodes.get(dep_id) or graph.sources.get(dep_id) %}
        {% if dep %}
            {% do rows.append("select '" ~ node.name ~ "' as model_name, '" ~ dep.name ~ "' as depends_on, '" ~ dep.resource_type ~ "' as depends_on_type, cast(null as varchar) as column_name") %}
        {% endif %}
    {% endfor %}
{% endfor %}

{% set gl_relation = ref('dbt_gl_model') %}

with ddl as (
    select get_ddl('view', '{{ gl_relation.database }}.{{ gl_relation.schema }}.{{ gl_relation.identifier }}') as ddl_text
),
table_alias_pairs as (
    select
        t.value::string as source_table,
        a.value::string as alias
    from ddl,
    lateral flatten(input => regexp_substr_all(ddl_text, '(?i)(?:from|join)\s+([\w.]+)\s+(?:as\s+)?(\w+)', 1, 1, 'e', 1)) t,
    lateral flatten(input => regexp_substr_all(ddl_text, '(?i)(?:from|join)\s+([\w.]+)\s+(?:as\s+)?(\w+)', 1, 1, 'e', 2)) a
    where t.index = a.index
),
col_refs as (
    select
        al.value::string as alias,
        col.value::string as column_name
    from ddl,
    lateral flatten(input => regexp_substr_all(ddl_text, '(\w+)\.(\w+)', 1, 1, 'e', 1)) al,
    lateral flatten(input => regexp_substr_all(ddl_text, '(\w+)\.(\w+)', 1, 1, 'e', 2)) col
    where al.index = col.index
),
dynamic_column_lineage as (
    select distinct
        'dbt_gl_model' as model_name,
        split_part(tap.source_table, '.', -1) as depends_on,
        'source' as depends_on_type,
        cr.column_name
    from col_refs cr
    join table_alias_pairs tap
        on lower(cr.alias) = lower(tap.alias)
)

{{ rows | join('\nunion all\n') }}
union all
select * from dynamic_column_lineage