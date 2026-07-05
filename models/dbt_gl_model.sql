{{ config(materialized='view') }}

select
    fct_gl.date_key,
    fct_gl.account_id,
    fct_gl.cost_center,
    fct_gl.fiscal_period,
    fct_gl.fiscal_year,
    fct_gl.debit_amount,
    fct_gl.credit_amount,
    fct_gl.net_amount,
    fct_gl.store_id,
    dim_gl_account.account_description,
    dim_gl_account.account_type,
    dim_gl_account.department_mapping,
    dim_store.store_name,
    dim_store.store_type,
    dim_store.banner as store_banner,
    dim_calendar.day_name,
    dim_calendar.month_name,
    dim_calendar.fiscal_quarter,
    dim_calendar.is_weekend,
    dim_calendar.is_holiday,
    (dim_calendar.is_weekend or dim_calendar.is_holiday) as posted_on_non_business_day,
    div0(
        sum(case when dim_calendar.is_weekend or dim_calendar.is_holiday then 1 else 0 end)
            over (partition by dim_calendar.fiscal_quarter, dim_gl_account.account_type, dim_store.store_name),
        count(*) over (partition by dim_calendar.fiscal_quarter, dim_gl_account.account_type, dim_store.store_name)
    ) as non_business_day_posting_rate
from {{ source('bam', 'fct_gl') }} as fct_gl
left join {{ source('bam', 'dim_gl_account') }} as dim_gl_account
    on fct_gl.account_id = dim_gl_account.account_id
left join {{ source('bam', 'dim_store') }} as dim_store
    on fct_gl.store_id = dim_store.store_id
left join {{ source('bam', 'dim_calendar') }} as dim_calendar
    on fct_gl.date_key = dim_calendar.date_key