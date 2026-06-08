WITH sessions_info AS (
  SELECT
    user_pseudo_id,

    (
      SELECT ep.value.int_value
      FROM UNNEST(event_params) ep
      WHERE ep.key = 'ga_session_id'
    ) AS ga_session_id,

    CONCAT(
      'sid_',
      CAST(user_pseudo_id AS STRING),
      '_',
      CAST((
        SELECT ep.value.int_value
        FROM UNNEST(event_params) ep
        WHERE ep.key = 'ga_session_id'
      ) AS STRING)
    ) AS user_session_id,

    TIMESTAMP_MICROS(event_timestamp) AS session_start_ts,

    REGEXP_EXTRACT(
      (
        SELECT ep.value.string_value
        FROM UNNEST(event_params) ep
        WHERE ep.key = 'page_location'
      ),
      r'(?:https:\/\/)?[^\/]+\/(.*)'
    ) AS landing_page_location,

    geo.country AS country,

    device.category AS device_category,
    device.language AS device_language,
    device.operating_system AS operating_system,

    traffic_source.source AS source,
    traffic_source.medium AS medium,
    traffic_source.name AS campaign

  FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`
  WHERE _TABLE_SUFFIX BETWEEN '20201101' AND '20210131'
    AND event_name = 'session_start'
),


events_raw AS (
  SELECT
    user_pseudo_id,

    (
      SELECT ep.value.int_value
      FROM UNNEST(event_params) ep
      WHERE ep.key = 'ga_session_id'
    ) AS ga_session_id,

    CONCAT(
      'sid_',
      CAST(user_pseudo_id AS STRING),
      '_',
      CAST((
        SELECT ep.value.int_value
        FROM UNNEST(event_params) ep
        WHERE ep.key = 'ga_session_id'
      ) AS STRING)
    ) AS user_session_id,

    event_timestamp,
    TIMESTAMP_MICROS(event_timestamp) AS event_timestamp_ts,
    event_name,
    ecommerce.purchase_revenue AS revenue

  FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`
  WHERE _TABLE_SUFFIX BETWEEN '20201101' AND '20210131'
    AND event_name IN (
      'session_start',
      'view_item',
      'add_to_cart',
      'begin_checkout',
      'add_shipping_info',
      'add_payment_info',
      'purchase'
    )
),


final AS (
  SELECT
    s.user_pseudo_id,
    s.ga_session_id,
    s.user_session_id,
    s.session_start_ts,
    s.landing_page_location,
    s.country,
    s.device_category,
    s.device_language,
    s.operating_system,
    s.source,
    s.medium,
    s.campaign,

    e.event_timestamp,
    e.event_timestamp_ts,
    e.event_name,
    e.revenue,

    CASE e.event_name
      WHEN 'session_start' THEN 1
      WHEN 'view_item' THEN 2
      WHEN 'add_to_cart' THEN 3
      WHEN 'begin_checkout' THEN 4
      WHEN 'add_shipping_info' THEN 5
      WHEN 'add_payment_info' THEN 6
      WHEN 'purchase' THEN 7
    END AS funnel_step,

    CASE e.event_name
      WHEN 'session_start' THEN '1. Session start'
      WHEN 'view_item' THEN '2. View item'
      WHEN 'add_to_cart' THEN '3. Add to cart'
      WHEN 'begin_checkout' THEN '4. Begin checkout'
      WHEN 'add_shipping_info' THEN '5. Add shipping info'
      WHEN 'add_payment_info' THEN '6. Add payment info'
      WHEN 'purchase' THEN '7. Purchase'
    END AS funnel_step_name

  FROM sessions_info s
  LEFT JOIN events_raw e USING(user_session_id)
)

SELECT *
FROM final;

/* контрольна перевірка КРІ:
SELECT
  COUNT(*) AS total_rows,

  COUNT(DISTINCT user_session_id) AS user_session_count,

  COUNT(DISTINCT IF(event_name = 'purchase', user_session_id, NULL)) AS purchases,

  ROUND(
    COUNT(DISTINCT IF(event_name = 'purchase', user_session_id, NULL))
    / COUNT(DISTINCT user_session_id) * 100,
    2
  ) AS cr_to_purchase_percent

FROM final;*/