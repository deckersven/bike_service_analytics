select count(*)
from lr_contract as lc
where lc.lrv_sign_date < '2025-06-25'
and lc.bike_service_consent_option = 'opt-out'

select
lc.bike_service_consent_option as option,
lc.bike_service_consent_status as status,
lc.bike_services_version as version,
lc.bike_service_consent_date as date,
lc.lrv_sign_date as lrv_sign_date
from lr_contract as lc
where lc.lrv_sign_date < '2025-06-25'
--and lc.bike_service_consent_option is not null





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



---
---
--- old service world

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


---
---
SELECT
    DATE_TRUNC('month', lcl.start_leasing) AS month,
    SUM(CASE WHEN lcl.service_configuration_id = 1 THEN 1 ELSE 0 END) AS config_id_1_count,
    SUM(CASE WHEN lcl.service_configuration_id = 3 THEN 1 ELSE 0 END) AS config_id_3_count,
    SUM(CASE WHEN lcl.service_configuration_id IS NULL THEN 1 ELSE 0 END) AS config_id_null_count
FROM
    lr_contract_leasing AS lcl
WHERE
    lcl.start_leasing > '2025-06-25'
    AND lcl.elv_change_type_id IS NULL
    AND lcl.state IN ('active', 'ending') -- Falls nur aktive oder endende gewünscht sind
GROUP BY
    DATE_TRUNC('month', lcl.start_leasing)
ORDER BY
    month;





    select
--        CASE
--            WHEN DATE_TRUNC('month', lcl.create_date) = DATE_TRUNC('month', CURRENT_DATE)
--                THEN DATE_TRUNC('week', lcl.create_date)
--            ELSE DATE_TRUNC('month', lcl.create_date)
--        END as month,
--        sum(case when bsc.name like '%JobRad Basis%' then 1 else 0 end) as JobRad_Basis,
--        sum(case when bsc.name like '%JobRad Komfort%' then 1 else 0 end) as JobRad_Komfort,
--        sum(case when bsc.name like '%JobRad Unlimited%' then 1 else 0 end) as JobRad_Unlimited,
--        sum(case when lcl.service_configuration_id is Null then 1 else 0 end) as no_service
        DATE_TRUNC('month', lcl.create_date) as month,
        count(*),
--        lcl.state
        lcl.service_configuration_id,
        bsc.name
    from
        lr_contract_leasing as lcl
    join lr_contract as lr on lcl.contract_id = lr.id
    left join bike_service_configuration as bsc on bsc.id = lcl.service_configuration_id
    where lr.bike_services_version = '1.0'
    and lcl.start_leasing > '2025-06-25'
    and lcl.elv_change_type_id is Null
    --and Date(TO_CHAR(lcl.create_date::date, 'YYYY-MM-DD')) != case when lr.bike_service_consent_date is Null then lr.lrv_sign_date else lr.bike_service_consent_date end
    and lcl.state IN ('active','ending') --?
    and lcl.service_configuration_id in (1,3)
    group by lcl.service_configuration_id, bsc.name, lcl.create_date--lr.bike_services_version--lcl.state
    --group by month


    SELECT
    DATE_TRUNC('month', lcl.create_date) AS month,
    lcl.service_configuration_id,
    bsc.name,
    COUNT(*) AS config_count
FROM
    lr_contract_leasing AS lcl
JOIN
    lr_contract AS lr ON lcl.contract_id = lr.id
LEFT JOIN
    bike_service_configuration AS bsc ON bsc.id = lcl.service_configuration_id
WHERE
    lr.bike_services_version = '1.0'
    AND lcl.start_leasing > '2025-06-25'
    AND lcl.elv_change_type_id IS NULL
    AND lcl.state IN ('active', 'ending') -- Muss geklärt werden: Ist das korrekt?
    AND lcl.service_configuration_id IN (1, 3)
GROUP BY
    DATE_TRUNC('month', lcl.create_date),
    lcl.service_configuration_id,
    bsc.name
ORDER BY
    month, lcl.service_configuration_id;


select
    month,
    elv1zero
    insp,
    fs,
    no_service





-- ELVs eligible to service 2.0 but no service (wrong)
select
    count(*)
from lr_contract_leasing as lcl
join lr_contract as lr on lcl.contract_id = lr.id
where lr.bike_services_version = '2.0'
and lcl.state IN ('active','ending') --?
and lcl.create_date > lr.bike_service_consent_date
and service_configuration_id is NULL




select
    count(*),
    lcl.state
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
--and lcl.service_configuration_id not in (1,3)
group by lcl.state





--- Es gibt ELVs deren LRV auf 2.0 steht, aber deren ELV Service Pakete aus 1.0 (JFS und Ivo) nutzen !!!

select
    lcl.name as elv_name,
    lcl.elv_change_type_id,
    ect.name,
    lcl.elv_changed,
    bsc.name as booked_bike_service,
    rp.name as Hauptarbeitgeber,
    lrv_sign_date as lrv_sign_date,
    lcl.create_date as elv_create_date,
    lcl.create_date - lrv_sign_date as timedelta_elv_create_lrv_sign,
    case when lr.bike_service_consent_date is Null then lr.lrv_sign_date else lr.bike_service_consent_date end as start_service_v2,
    Date(TO_CHAR(lcl.create_date::date, 'YYYY-MM-DD')) - case when lr.bike_service_consent_date is Null then lr.lrv_sign_date else lr.bike_service_consent_date end
from
    lr_contract_leasing as lcl
join lr_contract as lr on lcl.contract_id = lr.id
left join bike_service_configuration as bsc on bsc.id = lcl.service_configuration_id
join res_partner as rp on rp.id = lr.partner_id
left join elv_change_type as ect on ect.id = lcl.elv_change_type_id
where lr.bike_services_version = '2.0'
and (
     lcl.create_date > lr.bike_service_consent_date
     or (lr.bike_service_consent_date is Null and lcl.create_date > '2025-06-25'))
and lcl.elv_change_type_id is Null
and Date(TO_CHAR(lcl.create_date::date, 'YYYY-MM-DD')) != case when lr.bike_service_consent_date is Null then lr.lrv_sign_date else lr.bike_service_consent_date end
and lcl.state IN ('active','ending') --?
and lcl.service_configuration_id in (1,3)






select
    *
from
    elv_change_type




select
lc.partner_id,
lc.bike_service_consent_option,
rs.name
from lr_contract as lc
join res_partner as rs on lc.partner_id = rs.id
where lc.lrv_sign_date < '2025-06-25'
and lc.bike_services_version = '2.0'
and lc.bike_service_consent_option is null


select
    extract(year from lc.bike_service_consent_date) as year, -- Year extracted
    extract(week from lc.bike_service_consent_date) as calendar_week, -- Week extracted
    count(*) as lrv_count -- Count of LRVs
from lr_contract as lc
where lc.lrv_sign_date < '2025-06-25'
  and lc.bike_services_version = '2.0' -- Filter for Version 2.0
group by extract(year from lc.bike_service_consent_date), extract(week from lc.bike_service_consent_date)
order by year, calendar_week;



with db as (
    SELECT
        distinct lc.id,
        lc.authorised_employee_count,
        lc.bike_services_version,
        SUM(lc.authorised_employee_count) OVER (ORDER BY lc.authorised_employee_count DESC) AS cumsum,
        rp.id,
        rp.name
    FROM lr_contract AS lc
    join res_partner as rp on lc.partner_id = rp.id
    where lc.state_id IN (5,7,8,12,13,14,16)
    ORDER BY lc.authorised_employee_count DESC
    limit 4000
)

select
    count(authorised_employee_count),
    sum(authorised_employee_count),
    bike_services_version
from db
group by bike_services_version






SELECT cumsum
FROM (
    SELECT
        lr.authorised_employee_count,
        lr.bike_services_version,
        SUM(lr.authorised_employee_count) OVER (ORDER BY lr.authorised_employee_count DESC) AS cumsum
    FROM lr_contract AS lr
    ORDER BY lr.authorised_employee_count DESC
    limit 4000
) AS subquery
ORDER BY cumsum desc;





select -- 14155401 (70% sind 10 mio)
    sum(lr.authorised_employee_count)
from lr_contract as lr

