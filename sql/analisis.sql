-- 01. Chequeo de granularidad


-- Beneficiary-year: una fila por beneficiario y año
SELECT
    COUNT(*) AS total_rows,
    COUNT(DISTINCT ("DESYNPUF_ID", "YEAR")) AS unique_beneficiary_year
FROM beneficiary_year;


-- Inpatient: una fila por claim
SELECT
    COUNT(*) AS total_rows,
    COUNT(DISTINCT "CLM_ID") AS unique_claims
FROM inpatient_claim;


-- Outpatient: una fila por claim
SELECT
    COUNT(*) AS total_rows,
    COUNT(DISTINCT "CLM_ID") AS unique_claims
FROM outpatient_claim;


--------------------------------------------------------------------------------------------

-- 2) Volumen de pagos y claims medicar por anio y servicio
-- Comparamos la utilizacion y los pagos en Inpatient y Outpatitnt entre 2008-2010


SELECT
    "ANALYSIS_YEAR" AS year,
    'Inpatient' AS service_type,
    COUNT(*) AS claims,
    ROUND(SUM("MEDICARE_REIMBURSEMENT"::numeric), 2) AS total_medicare_payment,
    ROUND(AVG("MEDICARE_REIMBURSEMENT"::numeric), 2) AS avg_medicare_payment_per_claim
FROM inpatient_claim
WHERE "ANALYSIS_YEAR" IS NOT NULL
GROUP BY "ANALYSIS_YEAR"

UNION ALL

SELECT
    "ANALYSIS_YEAR" AS year,
    'Outpatient' AS service_type,
    COUNT(*) AS claims,
    ROUND(SUM("MEDICARE_REIMBURSEMENT"::numeric), 2) AS total_medicare_payment,
    ROUND(AVG("MEDICARE_REIMBURSEMENT"::numeric), 2) AS avg_medicare_payment_per_claim
FROM outpatient_claim
WHERE "ANALYSIS_YEAR" IS NOT NULL
GROUP BY "ANALYSIS_YEAR"

ORDER BY year, service_type;



--------------------------------------------------------------------------------------------

-- 3) Utilizaicon segun las enfermedades cronicas
-- Analizamos como varia el uso anula de los servicios en Impatient y Outpatint segun las enfermedades cronicas



SELECT
    "CHRONIC_CONDITION_COUNT" AS chronic_conditions,
    COUNT(*) AS beneficiary_years,
    ROUND(AVG("INPATIENT_FINANCIAL_CLAIMS")::numeric, 2) AS avg_inpatient_claims,
    ROUND(AVG("OUTPATIENT_FINANCIAL_CLAIMS")::numeric, 2) AS avg_outpatient_claims
FROM beneficiary_year
GROUP BY "CHRONIC_CONDITION_COUNT"
ORDER BY chronic_conditions;


--------------------------------------------------------------------------------------------


-- 4) Pagos de Medicare segun enfermedades cronicas
-- Analizamos como varia el pago anual promedio de Medicare por beneficiario segun la cantidad de enfermedades cronicas


SELECT
    "CHRONIC_CONDITION_COUNT" AS chronic_conditions,
    COUNT(*) AS beneficiary_years,

    ROUND(
        AVG("INPATIENT_MEDICARE_PAYMENT"::numeric),
        2
    ) AS avg_annual_inpatient_payment,

    ROUND(
        AVG("OUTPATIENT_MEDICARE_PAYMENT"::numeric),
        2
    ) AS avg_annual_outpatient_payment,

    ROUND(
        AVG(
            COALESCE("INPATIENT_MEDICARE_PAYMENT"::numeric, 0)
            + COALESCE("OUTPATIENT_MEDICARE_PAYMENT"::numeric, 0)
        ),
        2
    ) AS avg_annual_total_payment

FROM beneficiary_year
GROUP BY "CHRONIC_CONDITION_COUNT"
ORDER BY chronic_conditions;


--------------------------------------------------------------------------------------------

-- 5) Frecuencia de uso vs Pago por claim
-- Analizamos si el aumento del pago anual asociado a una mayor carga de enfermedades cronicas del beneficiario esta relacionado
-- con una mayor frecuencia de claims, con mayor pago promedio por claim o con ambos.


SELECT
    "CHRONIC_CONDITION_COUNT" AS chronic_conditions,
    COUNT(*) AS beneficiary_years,

    ROUND(
        AVG("INPATIENT_FINANCIAL_CLAIMS")::numeric,
        2
    ) AS avg_inpatient_claims,

    ROUND(
        SUM("INPATIENT_MEDICARE_PAYMENT"::numeric)
        / NULLIF(SUM("INPATIENT_FINANCIAL_CLAIMS"), 0),
        2
    ) AS inpatient_payment_per_claim,

    ROUND(
        AVG("OUTPATIENT_FINANCIAL_CLAIMS")::numeric,
        2
    ) AS avg_outpatient_claims,

    ROUND(
        SUM("OUTPATIENT_MEDICARE_PAYMENT"::numeric)
        / NULLIF(SUM("OUTPATIENT_FINANCIAL_CLAIMS"), 0),
        2
    ) AS outpatient_payment_per_claim

FROM beneficiary_year
GROUP BY "CHRONIC_CONDITION_COUNT"
ORDER BY chronic_conditions;

--------------------------------------------------------------------------------


-- 6) Diferencias de uso por zona geografica 
-- Comparamos el uso promedio de servicios Inpatient y Outpatient entre estados y obtenenemos rankings. (Excluimos OTHERS)


WITH state_utilization AS (
    SELECT
        "State" AS state,
        COUNT(*) AS beneficiary_years,

        AVG("INPATIENT_FINANCIAL_CLAIMS") AS avg_inpatient_claims,
        AVG("OUTPATIENT_FINANCIAL_CLAIMS") AS avg_outpatient_claims

    FROM beneficiary_year
    WHERE "State" IS NOT NULL
  AND TRIM("State") <> ''
  AND "State" <> 'OTHERS'

    GROUP BY "State"
)

SELECT
    state,
    beneficiary_years,

    ROUND(avg_inpatient_claims::numeric, 3) AS avg_inpatient_claims,
    RANK() OVER (
        ORDER BY avg_inpatient_claims DESC
    ) AS inpatient_utilization_rank,

    ROUND(avg_outpatient_claims::numeric, 3) AS avg_outpatient_claims,
    RANK() OVER (
        ORDER BY avg_outpatient_claims DESC
    ) AS outpatient_utilization_rank

FROM state_utilization
ORDER BY inpatient_utilization_rank;


--------------------------------------------------------------------------

-- 7) Cuantos pagos hace Medicare por estado
-- Comparamo el pago promedio por claim entre estados para Inpatient y Outpatient. (OTHERS excluidos)


-- 7) Pago promedio por claim según estado
-- Comparamos los pagos de Medicare por claim entre estados
-- para Inpatient y Outpatient. Se excluye OTHERS.

WITH state_payments AS (

    SELECT
        "State" AS state,

        SUM("INPATIENT_MEDICARE_PAYMENT"::numeric)
            / NULLIF(SUM("INPATIENT_FINANCIAL_CLAIMS"), 0)
            AS inpatient_payment_per_claim,

        SUM("OUTPATIENT_MEDICARE_PAYMENT"::numeric)
            / NULLIF(SUM("OUTPATIENT_FINANCIAL_CLAIMS"), 0)
            AS outpatient_payment_per_claim

    FROM beneficiary_year

    WHERE "State" IS NOT NULL
      AND TRIM("State") <> ''
      AND "State" <> 'OTHERS'

    GROUP BY "State"
)

SELECT
    state,

    ROUND(inpatient_payment_per_claim, 2)
        AS inpatient_payment_per_claim,

    RANK() OVER (
        ORDER BY inpatient_payment_per_claim DESC
    ) AS inpatient_payment_rank,

    ROUND(outpatient_payment_per_claim, 2)
        AS outpatient_payment_per_claim,

    RANK() OVER (
        ORDER BY outpatient_payment_per_claim DESC
    ) AS outpatient_payment_rank

FROM state_payments
ORDER BY inpatient_payment_rank;



-----------------------------------------------------------------------------------


-- CONCLUSIONES

-- Se verifico que las tres tablas mantienen la granularidad esperada, una fila por beneficiario y año y una fila por claim en cada servicio.

-- Outpatient concentra una cantidad mucho mayor de claims, pero Inpatient representa un importe total de pagos de Medicare mas alto. 
-- La diferencia se explica por el mayor pago promedio por claim de las internaciones.

-- Al analizar las enfermedades cronicas, se ve que los beneficiarios con mas condiciones registradas tienden a utilizar mas servicios 
--y presentan mayores pagos anuales de Medicare.

-- En Inpatient, el pago por claim se mantiene relativamente estable entre los distintos niveles de cronicidad. Lo que sugiere que el aumento del 
--pago anual esta mas relacionado con la frecuencia de utilizacion. En Outpatient, en cambio, aumentan tanto la cantidad de claims como el pago 
--promedio por claim.

-- En el analisis por estado, Illinois presenta la mayor utilizacion promedio de ambos servicios. Sin embargo, los mayores pagos por claim 
--corresponden a Nebraska en Inpatient y Alaska en Outpatient. Por lo tanto, los estados con mayor utilizacion no necesariamente son 
--los que registran los pagos mas altos por atencion.

-- Durante la preparacion de los datos se identificaron 68 claims Inpatient con multiples segmentos, que se conservaron para contabilizar 
--la utilizacion pero se excluyeron de los calculos financieros porque sus importes no podian reconstruirse de forma confiable. 
--En Outpatient se utilizo unicamente el segmento 1 para evitar duplicar pagos y se excluyeron de los calculos anuales 278 claims sin fechas validas. 
--En SQL se ajusto la precision de los calculos monetarios y se verificaron los resultados obtenidos en Python. Las diferencias de Inpatient quedaron 
--explicadas por los claims excluidos, mientras que los pagos de Outpatient conciliaron con los importes anuales originales.





