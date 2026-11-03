WITH events AS (
  SELECT
    CONCAT(user_pseudo_id, '-',
      CAST((SELECT value.int_value
            FROM UNNEST(event_params)
            WHERE key = 'ga_session_id') AS STRING)) AS session_id,
    event_name,
    TIMESTAMP_MICROS(event_timestamp) AS event_time,
    CASE WHEN event_name = 'session_start' THEN
      REGEXP_EXTRACT(
        (SELECT value.string_value
         FROM UNNEST(event_params)
         WHERE key = 'page_location'),
        r'https?://[^/]+(/[^?]*)')
    END AS landing_page,
    traffic_source.source AS source,
    traffic_source.medium AS medium,
    traffic_source.name AS campaign,
    device.category AS device_category,
    device.language AS device_language,
    device.operating_system AS device_os
  FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`
  WHERE _TABLE_SUFFIX BETWEEN '20201101' AND '20210131'
    AND event_name IN ('session_start', 'view_item', 'add_to_cart',
                       'begin_checkout', 'add_shipping_info',
                       'add_payment_info', 'purchase')
),
sessions AS (
  SELECT
    session_id,
    MIN(IF(event_name = 'session_start', event_time, NULL)) AS session_start_time,
    DATE(MIN(IF(event_name = 'session_start', event_time, NULL))) AS session_date,
    MAX(landing_page) AS landing_page,
    MAX(source) AS source,
    MAX(medium) AS medium,
    MAX(campaign) AS campaign,
    MAX(device_category) AS device_category,
    MAX(device_language) AS device_language,
    MAX(device_os) AS device_os,
    MAX(IF(event_name = 'session_start', 1, 0)) AS has_session_start,
    MAX(IF(event_name = 'view_item', 1, 0)) AS has_view_item,
    MAX(IF(event_name = 'add_to_cart', 1, 0)) AS has_add_to_cart,
    MAX(IF(event_name = 'begin_checkout', 1, 0)) AS has_begin_checkout,
    MAX(IF(event_name = 'add_shipping_info', 1, 0)) AS has_add_shipping_info,
    MAX(IF(event_name = 'add_payment_info', 1, 0)) AS has_add_payment_info,
    MAX(IF(event_name = 'purchase', 1, 0)) AS has_purchase
  FROM events
  GROUP BY session_id
  HAVING session_id IS NOT NULL
     AND has_session_start = 1
)
SELECT
  s.session_id,
  s.session_start_time,
  s.session_date,
  s.landing_page,
  s.source,
  s.medium,
  s.campaign,
  s.device_category,
  s.device_language,
  s.device_os,
  step.step_no,
  step.step_name
FROM sessions s,
UNNEST([
  STRUCT(1 AS step_no, '1 Oturum' AS step_name, s.has_session_start AS reached),
  STRUCT(2, '2 Urun Inceleme', s.has_view_item),
  STRUCT(3, '3 Sepete Ekleme', s.has_add_to_cart),
  STRUCT(4, '4 Siparis Baslatma', s.has_begin_checkout),
  STRUCT(5, '5 Gonderi Bilgisi', s.has_add_shipping_info),
  STRUCT(6, '6 Odeme Bilgisi', s.has_add_payment_info),
  STRUCT(7, '7 Satin Alma', s.has_purchase)
]) AS step
WHERE step.reached = 1   
