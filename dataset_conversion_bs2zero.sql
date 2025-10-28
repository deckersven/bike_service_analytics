with new_lrvs as(
    --new AG and neu Berechtigte
    select
        --CASE
            --WHEN DATE_TRUNC('month', lc.lrv_sign_date) = DATE_TRUNC('month', CURRENT_DATE)
            --    THEN DATE_TRUNC('week', lc.lrv_sign_date)
            --ELSE DATE_TRUNC('month', lc.lrv_sign_date)
        --END AS month,
        DATE_TRUNC('month', lc.lrv_sign_date) as month,
    count(*) as new_AG,
    sum(lc.authorised_employee_count) as Berechtigte
    from lr_contract as lc
    where lc.lrv_sign_date >= '2025-06-25'
    and lc.bike_services_version = '2.0'
    and lc.state_id IN (5,7,8,12,13,14,16)
    GROUP BY month
),

all_eligibles as(
    -- alle Berechtigte with service 2.0
    select
        --CASE
            --WHEN DATE_TRUNC('month', lc.bike_service_consent_date) = DATE_TRUNC('month', CURRENT_DATE)
            --    THEN DATE_TRUNC('week', lc.bike_service_consent_date)
            --ELSE DATE_TRUNC('month', lc.bike_service_consent_date)
        --END AS month,
        DATE_TRUNC('month', lc.bike_service_consent_date) as month,
        sum(lc.authorised_employee_count)
        --sum(case when lc.bike_services_version = '2.0' then lc.authorised_employee_count else 0 end)
    from
        lr_contract as lc
    --where lc.lrv_sign_date < '2025-06-25'
    where lc.bike_services_version = '2.0'
    and lc.state_id IN (5,7,8,12,13,14,16)
    GROUP BY month

),

elvs2zero as(
    -- ELVs with Service 2.0 (4732)
    select
        --CASE
            --WHEN DATE_TRUNC('month', lcl.create_date) = DATE_TRUNC('month', CURRENT_DATE)
            --    THEN DATE_TRUNC('week', lcl.create_date)
            --ELSE DATE_TRUNC('month', lcl.create_date)
        --END AS month,
        DATE_TRUNC('month', lcl.start_leasing) as month,
        count(*)
        --lcl.state
    from
        lr_contract_leasing as lcl
    join lr_contract as lr on lcl.contract_id = lr.id
    where lr.bike_services_version = '2.0'
    and (
         lcl.create_date > lr.bike_service_consent_date
         or (lr.bike_service_consent_date is Null and lcl.create_date > '2025-06-25'))
    and lcl.elv_change_type_id is Null
    --and Date(TO_CHAR(lcl.create_date::date, 'YYYY-MM-DD')) != case when lr.bike_service_consent_date is Null then lr.lrv_sign_date else lr.bike_service_consent_date end
    and lcl.state IN ('active','ending') --?
    and (
         lcl.service_configuration_id not in (1,3)
        OR lcl.service_configuration_id IS NULL)
    group by month
),

elvs2zero_foc as(
    -- ELVs with Service 2.0 (4732)
    select
        --CASE
            --WHEN DATE_TRUNC('month', lcl.create_date) = DATE_TRUNC('month', CURRENT_DATE)
            --    THEN DATE_TRUNC('week', lcl.create_date)
            --ELSE DATE_TRUNC('month', lcl.create_date)
        --END AS month,
        DATE_TRUNC('month', lcl.start_leasing) as month,
        count(*)
        --lcl.state
    from
        lr_contract_leasing as lcl
    join lr_contract as lr on lcl.contract_id = lr.id
    where lr.bike_services_version = '2.0'
    and lr.is_bike_service_mandatory = False
    and (
         lcl.create_date > lr.bike_service_consent_date
         or (lr.bike_service_consent_date is Null and lcl.create_date > '2025-06-25'))
    and lcl.elv_change_type_id is Null
    --and Date(TO_CHAR(lcl.create_date::date, 'YYYY-MM-DD')) != case when lr.bike_service_consent_date is Null then lr.lrv_sign_date else lr.bike_service_consent_date end
    and lcl.state IN ('active','ending') --?
    and (
         lcl.service_configuration_id not in (1,3)
        OR lcl.service_configuration_id IS NULL)
    group by month
),

service_split as(
    -- split by package
    select
--        count(*),
        --CASE
            --WHEN DATE_TRUNC('month', lcl.create_date) = DATE_TRUNC('month', CURRENT_DATE)
            --    THEN DATE_TRUNC('week', lcl.create_date)
            --ELSE DATE_TRUNC('month', lcl.create_date)
        --END as month,
        DATE_TRUNC('month', lcl.start_leasing) as month,
        sum(case when bsc.name like '%JobRad Basis%' then 1 else 0 end) as JobRad_Basis,
        sum(case when bsc.name like '%JobRad Komfort%' then 1 else 0 end) as JobRad_Komfort,
        sum(case when bsc.name like '%JobRad Unlimited%' then 1 else 0 end) as JobRad_Unlimited,
        sum(case when lcl.service_configuration_id is Null then 1 else 0 end) as no_service
        --lcl.state
        --lcl.service_configuration_id,
        --bsc.name
    from
        lr_contract_leasing as lcl
    join lr_contract as lr on lcl.contract_id = lr.id
    left join bike_service_configuration as bsc on bsc.id = lcl.service_configuration_id
    where lr.bike_services_version = '2.0'
    and (
         lcl.create_date > lr.bike_service_consent_date
         or (lr.bike_service_consent_date is Null and lcl.create_date > '2025-06-25'))
    and lcl.elv_change_type_id is Null
    --and Date(TO_CHAR(lcl.create_date::date, 'YYYY-MM-DD')) != case when lr.bike_service_consent_date is Null then lr.lrv_sign_date else lr.bike_service_consent_date end
    and lcl.state IN ('active','ending') --?
    --and lcl.service_configuration_id in (1,3)
    --group by lcl.service_configuration_id, bsc.name--lr.bike_services_version--lcl.state
    group by month
    order by month

),

service_split_foc as(
    -- split by package
    select
--        count(*),
        --CASE
            --WHEN DATE_TRUNC('month', lcl.create_date) = DATE_TRUNC('month', CURRENT_DATE)
            --    THEN DATE_TRUNC('week', lcl.create_date)
            --ELSE DATE_TRUNC('month', lcl.create_date)
        --END as month,
        DATE_TRUNC('month', lcl.start_leasing) as month,
        sum(case when bsc.name like '%JobRad Basis%' then 1 else 0 end) as JobRad_Basis_foc,
        sum(case when bsc.name like '%JobRad Komfort%' then 1 else 0 end) as JobRad_Komfort_foc,
        sum(case when bsc.name like '%JobRad Unlimited%' then 1 else 0 end) as JobRad_Unlimited_foc,
        sum(case when lcl.service_configuration_id is Null then 1 else 0 end) as no_service_foc
        --lcl.state
        --lcl.service_configuration_id,
        --bsc.name
    from
        lr_contract_leasing as lcl
    join lr_contract as lr on lcl.contract_id = lr.id
    left join bike_service_configuration as bsc on bsc.id = lcl.service_configuration_id
    where lr.bike_services_version = '2.0'
    and lr.is_bike_service_mandatory = False
    and (
         lcl.create_date > lr.bike_service_consent_date
         or (lr.bike_service_consent_date is Null and lcl.create_date > '2025-06-25'))
    and lcl.elv_change_type_id is Null
    --and Date(TO_CHAR(lcl.create_date::date, 'YYYY-MM-DD')) != case when lr.bike_service_consent_date is Null then lr.lrv_sign_date else lr.bike_service_consent_date end
    and lcl.state IN ('active','ending') --?
    --and lcl.service_configuration_id in (1,3)
    --group by lcl.service_configuration_id, bsc.name--lr.bike_services_version--lcl.state
    group by month
    order by month

)

select
    new_lrvs.*,
    all_eligibles.sum as berechtigte_gesamt,
    elvs2zero.count as elvs2zero,
    elvs2zero_foc.count as elvs2zero_foc,
    service_split.JobRad_Basis, service_split.JobRad_Komfort, service_split.JobRad_Unlimited, service_split.no_service,
    service_split_foc.JobRad_Basis_foc, service_split_foc.JobRad_Komfort_foc, service_split_foc.JobRad_Unlimited_foc, service_split_foc.no_service_foc
from
    new_lrvs
FULL OUTER JOIN all_eligibles ON new_lrvs.month = all_eligibles.month
FULL OUTER JOIN elvs2zero ON COALESCE(new_lrvs.month, all_eligibles.month) = elvs2zero.month
FULL OUTER JOIN service_split ON COALESCE(new_lrvs.month, all_eligibles.month, elvs2zero.month) = service_split.month
FULL OUTER JOIN elvs2zero_foc ON COALESCE(new_lrvs.month, all_eligibles.month) = elvs2zero_foc.month
FULL OUTER JOIN service_split_foc ON COALESCE(new_lrvs.month, all_eligibles.month, elvs2zero_foc.month) = service_split_foc.month
ORDER BY new_lrvs.month;
