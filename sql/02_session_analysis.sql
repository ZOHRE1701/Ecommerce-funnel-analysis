SELECT
  CONCAT(user_pseudo_id, '-',
    CAST((SELECT value.int_value
          FROM UNNEST(event_params)
          WHERE key = 'ga_session_id') AS STRING)) AS session_id,
  TIMESTAMP_MICROS(event_timestamp) AS session_start_time,
  DATE(TIMESTAMP_MICROS(event_timestamp)) AS session_date,
  REGEXP_EXTRACT(
    (SELECT value.string_value
     FROM UNNEST(event_params)
     WHERE key = 'page_location'),
    r'https?://[^/]+(/[^?]*)') AS landing_page,
  traffic_source.source AS source,
  traffic_source.medium AS medium,
  traffic_source.name AS campaign,
  device.category AS device_category,
  device.language AS device_language,
  device.operating_system AS device_os
FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`
WHERE _TABLE_SUFFIX BETWEEN '20201101' AND '20210131'
  AND event_name = 'session_start'
