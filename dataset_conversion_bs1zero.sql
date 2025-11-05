with elvs1zero as(
    -- ELVs with Service 2.0 (4732)
    select
        --CASE
            --WHEN DATE_TRUNC('month', lcl.create_date) = DATE_TRUNC('month', CURRENT_DATE)
            --    THEN DATE_TRUNC('week', lcl.create_date)
            --ELSE DATE_TRUNC('month', lcl.create_date)
        --END AS month,
        DATE_TRUNC('month', lcl.start_leasing) as month,
        --count(*),
        sum(Case when lcl.service_configuration_id is Null or lcl.service_configuration_id in (1,3) then 1 else 0 end) as sum
        --lcl.state
    from
        lr_contract_leasing as lcl
    join lr_contract as lr on lcl.contract_id = lr.id
    left join bike_service_configuration as bsc on bsc.id = lcl.service_configuration_id
    where lr.bike_services_version = '1.0'
    and (
         lcl.create_date > lr.bike_service_consent_date
         or (lr.bike_service_consent_date is Null and lcl.create_date > '2025-06-25'))
    and lcl.start_leasing > '2025-06-25'
    and lcl.elv_change_type_id is Null
    --and Date(TO_CHAR(lcl.create_date::date, 'YYYY-MM-DD')) != case when lr.bike_service_consent_date is Null then lr.lrv_sign_date else lr.bike_service_consent_date end
    and lcl.state IN ('active','ending') --?
    --and lcl.service_configuration_id in (1,3)
    group by month
),

elvs1zeroFoC as(
    -- ELVs with Service 2.0 (4732)
    select
        --CASE
            --WHEN DATE_TRUNC('month', lcl.create_date) = DATE_TRUNC('month', CURRENT_DATE)
            --    THEN DATE_TRUNC('week', lcl.create_date)
            --ELSE DATE_TRUNC('month', lcl.create_date)
        --END AS month,
        DATE_TRUNC('month', lcl.start_leasing) as month,
        --count(*),
        sum(Case when lcl.service_configuration_id is Null or lcl.service_configuration_id in (1,3) then 1 else 0 end) as sum
        --lcl.state
    from
        lr_contract_leasing as lcl
    join lr_contract as lr on lcl.contract_id = lr.id
    left join bike_service_configuration as bsc on bsc.id = lcl.service_configuration_id
    where lr.bike_services_version = '1.0'
    and lr.is_bike_service_mandatory = False
    and (
         lcl.create_date > lr.bike_service_consent_date
         or (lr.bike_service_consent_date is Null and lcl.create_date > '2025-06-25'))
    and lcl.start_leasing > '2025-06-25'
    and lcl.elv_change_type_id is Null
    --and Date(TO_CHAR(lcl.create_date::date, 'YYYY-MM-DD')) != case when lr.bike_service_consent_date is Null then lr.lrv_sign_date else lr.bike_service_consent_date end
    and lcl.state IN ('active','ending') --?
    --and lcl.service_configuration_id in (1,3)
    group by month
),

service_split as(
    -- split by package
    SELECT
        DATE_TRUNC('month', lcl.start_leasing) AS month,
        SUM(CASE WHEN lcl.service_configuration_id = 1 THEN 1 ELSE 0 END) AS JobRad_Inspektion,
        SUM(CASE WHEN lcl.service_configuration_id = 3 THEN 1 ELSE 0 END) AS JobRad_FullService,
        SUM(CASE WHEN lcl.service_configuration_id IS NULL THEN 1 ELSE 0 END) AS no_service
    FROM
        lr_contract_leasing AS lcl
    join lr_contract as lr on lcl.contract_id = lr.id
    left join bike_service_configuration as bsc on bsc.id = lcl.service_configuration_id
    where lr.bike_services_version = '1.0'
    and (
         lcl.create_date > lr.bike_service_consent_date
         or (lr.bike_service_consent_date is Null and lcl.create_date > '2025-06-25'))
    and lcl.start_leasing > '2025-06-25'
    AND lcl.elv_change_type_id IS NULL
    AND lcl.state IN ('active', 'ending') -- Falls nur aktive oder endende gewünscht sind
    GROUP BY
        DATE_TRUNC('month', lcl.start_leasing)
    ORDER BY
        month
),

service_split_FoC as (
    -- split by package
    SELECT DATE_TRUNC('month', lcl.start_leasing)                                AS month,
           SUM(CASE WHEN lcl.service_configuration_id = 1 THEN 1 ELSE 0 END)     AS JobRad_Inspektion_foc,
           SUM(CASE WHEN lcl.service_configuration_id = 3 THEN 1 ELSE 0 END)     AS JobRad_FullService_foc,
           SUM(CASE WHEN lcl.service_configuration_id IS NULL THEN 1 ELSE 0 END) AS no_service_foc
    FROM lr_contract_leasing AS lcl
             join lr_contract as lr on lcl.contract_id = lr.id
             left join bike_service_configuration as bsc on bsc.id = lcl.service_configuration_id
    where lr.bike_services_version = '1.0'
    and lr.is_bike_service_mandatory = False
      and (
        lcl.create_date > lr.bike_service_consent_date
            or (lr.bike_service_consent_date is Null and lcl.create_date > '2025-06-25'))
      and lcl.start_leasing > '2025-06-25'
      AND lcl.elv_change_type_id IS NULL
      AND lcl.state IN ('active', 'ending') -- Falls nur aktive oder endende gewünscht sind
    GROUP BY DATE_TRUNC('month', lcl.start_leasing)
    ORDER BY month
)

select
    COALESCE(elvs1zero.month, service_split.month) AS month,
    elvs1zero.sum as elvs1zero,
    elvs1zeroFoC.sum as elvs1zeroFoC,
    service_split.JobRad_Inspektion, service_split.JobRad_FullService, service_split.no_service,
    service_split_FoC.JobRad_Inspektion_foc, service_split_FoC.JobRad_FullService_foc, service_split_FoC.no_service_foc
from
    elvs1zero
FULL OUTER JOIN service_split ON elvs1zero.month = service_split.month
FULL OUTER JOIN elvs1zeroFoC ON elvs1zeroFoC.month = elvs1zero.month
FULL OUTER JOIN service_split_FoC ON elvs1zero.month = service_split_FoC.month
ORDER BY month;