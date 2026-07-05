{{ config(materialized='view') }}

select
    fct_sales.store_id,
    fct_sales.date_key,
    fct_sales.item_id,
    fct_sales.transaction_number,
    fct_sales.line_number,
    fct_sales.transaction_code,
    fct_sales.units,
    fct_sales.unit_retail,
    fct_sales.unit_cost as transaction_unit_cost,
    fct_sales.extended_price,
    fct_sales.extended_discount,
    fct_sales.cost_amount,
    dim_store.store_name,
    dim_store.banner,
    dim_store.store_type,
    dim_store.district,
    dim_store.state,
    dim_store.city,
    dim_store.latitude,
    dim_store.longitude,
    dim_store.selling_sq_ft,
    dim_store.active_flag as store_active_flag,
    dim_store.open_date,
    dim_calendar.day_name,
    dim_calendar.month_name,
    dim_calendar.day_of_week,
    dim_calendar.calendar_year,
    dim_calendar.fiscal_year,
    dim_calendar.fiscal_quarter,
    dim_calendar.fiscal_period,
    dim_calendar.fiscal_year_week,
    dim_calendar.is_weekend,
    dim_calendar.is_holiday,
    dim_item.item_description,
    dim_item.condition,
    dim_item.unit_cost as item_standard_unit_cost,
    dim_item.retail_price,
    dim_item.active_flag as item_active_flag,
    dim_class.class_name,
    dim_subclass.subclass_name,
    dim_department.department_name,
    dim_department.catalog_sku_pct,
    dim_transaction_type.description as transaction_description,
    dim_transaction_type.category as transaction_category,
    dim_transaction_type.in_sample_data,
    dim_transaction_type.pct_of_sample_lines
from {{ source('bam', 'fct_sales') }} as fct_sales
left join {{ source('bam', 'dim_store') }} as dim_store
    on fct_sales.store_id = dim_store.store_id
left join {{ source('bam', 'dim_calendar') }} as dim_calendar
    on fct_sales.date_key = dim_calendar.date_key
left join {{ source('bam', 'dim_item') }} as dim_item
    on fct_sales.item_id = dim_item.item_id
left join {{ source('bam', 'dim_transaction_type') }} as dim_transaction_type
    on fct_sales.transaction_code = dim_transaction_type.transaction_code
left join {{ source('bam', 'dim_class') }} as dim_class
    on dim_item.class_id = dim_class.class_id
left join {{ source('bam', 'dim_subclass') }} as dim_subclass
    on dim_item.subclass_id = dim_subclass.subclass_id
left join {{ source('bam', 'dim_department') }} as dim_department
    on dim_item.department_id = dim_department.department_id