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

{% set column_blocks = [] %}
{% if execute %}
    {% set discover_query %}
        select table_name from information_schema.views where table_schema = 'BAM'
    {% endset %}
    {% set view_results = run_query(discover_query) %}
    {% for row in view_results.rows %}
        {% set view_name = row['TABLE_NAME'] | lower %}
        {% set matching_node = nodes | selectattr('name', 'equalto', view_name) | list | first %}
        {% if matching_node %}
            {% set qualified_name = matching_node.database ~ '.' ~ matching_node.schema ~ '.' ~ matching_node.alias %}
            {% set block %}
(
with ddl_{{ view_name }} as (
    select get_ddl('view', '{{ qualified_name }}') as ddl_text
),
table_alias_pairs_{{ view_name }} as (
    select
        t.value::string as source_table,
        a.value::string as alias
    from ddl_{{ view_name }},
    lateral flatten(input => regexp_substr_all(ddl_text, '(from|join)\\s+([\\w.]+)\\s+(as\\s+)?(\\w+)', 1, 1, 'ei', 2)) t,
    lateral flatten(input => regexp_substr_all(ddl_text, '(from|join)\\s+([\\w.]+)\\s+(as\\s+)?(\\w+)', 1, 1, 'ei', 4)) a
    where t.index = a.index
),
col_refs_{{ view_name }} as (
    select
        al.value::string as alias,
        col.value::string as column_name
    from ddl_{{ view_name }},
    lateral flatten(input => regexp_substr_all(ddl_text, '(\\w+)\\.(\\w+)', 1, 1, 'e', 1)) al,
    lateral flatten(input => regexp_substr_all(ddl_text, '(\\w+)\\.(\\w+)', 1, 1, 'e', 2)) col
    where al.index = col.index
)
select distinct
    '{{ view_name }}' as model_name,
    split_part(tap.source_table, '.', -1) as depends_on,
    'source' as depends_on_type,
    cr.column_name
from col_refs_{{ view_name }} cr
join table_alias_pairs_{{ view_name }} tap
    on lower(cr.alias) = lower(tap.alias)
)
            {% endset %}
            {% do column_blocks.append(block) %}
        {% endif %}
    {% endfor %}
{% endif %}

{{ rows | join('\nunion all\n') }}
{% if column_blocks %}
union all
{{ column_blocks | join('\nunion all\n') }}
{% endif %}