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
    device.operating_system AS device_os,
    ecommerce.transaction_id AS transaction_id,
    ecommerce.purchase_revenue AS revenue
  FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`
  WHERE _TABLE_SUFFIX BETWEEN '20201101' AND '20210131'
    AND event_name IN ('session_start', 'view_item', 'add_to_cart',
                       'begin_checkout', 'add_shipping_info',
                       'add_payment_info', 'purchase')
)
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
  MAX(IF(event_name = 'purchase', 1, 0)) AS has_purchase,
  COUNT(DISTINCT IF(event_name = 'purchase', transaction_id, NULL)) AS orders,
  SUM(IF(event_name = 'purchase', revenue, 0)) AS revenue
FROM events
GROUP BY session_id
HAVING session_id IS NOT NULL
   AND has_session_start = 1
