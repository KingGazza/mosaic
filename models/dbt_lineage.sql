{{ config(materialized='table') }}

{% set nodes = graph.nodes.values() | selectattr('resource_type', 'equalto', 'model') | list %}
{% set rows = [] %}
{% for node in nodes %}
    {% for dep_id in node.depends_on.nodes %}
        {% set dep = graph.nodes.get(dep_id) or graph.sources.get(dep_id) %}
        {% if dep %}
            {% do rows.append("select '" ~ node.name ~ "' as model_name, '" ~ dep.name ~ "' as depends_on, '" ~ dep.resource_type ~ "' as depends_on_type") %}
        {% endif %}
    {% endfor %}
{% endfor %}

{{ rows | join('\nunion all\n') }}