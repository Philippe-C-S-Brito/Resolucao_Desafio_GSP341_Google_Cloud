#!/bin/bash

# Definição de Cores
CYAN_TEXT=$'\033[0;96m'
GREEN_TEXT=$'\033[0;92m'
YELLOW_TEXT=$'\033[0;93m'
RESET_FORMAT=$'\033[0m'
BOLD_TEXT=$'\033[1m'

clear

echo "${CYAN_TEXT}${BOLD_TEXT}==================================================================${RESET_FORMAT}"
echo "${CYAN_TEXT}${BOLD_TEXT}          INICIANDO A EXECUÇÃO DO LABORATÓRIO GSP341...           ${RESET_FORMAT}"
echo "${CYAN_TEXT}${BOLD_TEXT}==================================================================${RESET_FORMAT}"
echo

# --- TAREFA 1: Criar Dataset e Modelo Inicial ---
echo -e "${YELLOW_TEXT}${BOLD_TEXT}Tarefa 1: Criando Dataset 'ecommerce'...${RESET_FORMAT}"
bq --location=US mk -d ecommerce 2>/dev/null || true

echo -e "${YELLOW_TEXT}${BOLD_TEXT}Tarefa 1: Treinando o customer_classification_model (Aguarde, pode levar de 2 a 3 minutos)...${RESET_FORMAT}"
bq query --use_legacy_sql=false '
CREATE OR REPLACE MODEL `ecommerce.customer_classification_model`
OPTIONS
(
  model_type="logistic_reg",
  labels = ["will_buy_on_return_visit"]
) AS
SELECT * EXCEPT(fullVisitorId) FROM (
  SELECT fullVisitorId, IFNULL(totals.bounces, 0) AS bounces, IFNULL(totals.timeOnSite, 0) AS time_on_site
  FROM `data-to-insights.ecommerce.web_analytics`
  WHERE totals.newVisits = 1 AND date BETWEEN "20160801" AND "20170430"
)
JOIN (
  SELECT fullvisitorid, IF(COUNTIF(totals.transactions > 0 AND totals.newVisits IS NULL) > 0, 1, 0) AS will_buy_on_return_visit
  FROM `data-to-insights.ecommerce.web_analytics`
  GROUP BY fullvisitorid
) USING (fullVisitorId)'

# --- TAREFA 2: Avaliar o modelo ---
echo -e "\n${YELLOW_TEXT}${BOLD_TEXT}Tarefa 2: Avaliando o customer_classification_model...${RESET_FORMAT}"
bq query --use_legacy_sql=false "
SELECT roc_auc, CASE WHEN roc_auc > 0.9 THEN 'good' WHEN roc_auc > 0.8 THEN 'fair' WHEN roc_auc > 0.7 THEN 'decent' WHEN roc_auc > 0.6 THEN 'not great' ELSE 'poor' END AS model_quality
FROM ML.EVALUATE(MODEL ecommerce.customer_classification_model, (
  SELECT * EXCEPT(fullVisitorId) FROM (
    SELECT fullVisitorId, IFNULL(totals.bounces, 0) AS bounces, IFNULL(totals.timeOnSite, 0) AS time_on_site
    FROM \`data-to-insights.ecommerce.web_analytics\`
    WHERE totals.newVisits = 1 AND date BETWEEN '20170501' AND '20170630'
  )
  JOIN (
    SELECT fullVisitorId, IF(COUNTIF(totals.transactions > 0 AND totals.newVisits IS NULL) > 0, 1, 0) AS will_buy_on_return_visit
    FROM \`data-to-insights.ecommerce.web_analytics\`
    GROUP BY fullVisitorId
  ) USING (fullVisitorId)
));"

# --- TAREFA 3: Modelo Melhorado ---
echo -e "\n${YELLOW_TEXT}${BOLD_TEXT}Tarefa 3: Treinando o improved_customer_classification_model (Aguarde o treinamento)...${RESET_FORMAT}"
bq query --use_legacy_sql=false '
CREATE OR REPLACE MODEL `ecommerce.improved_customer_classification_model`
OPTIONS (
  model_type="logistic_reg",
  labels = ["will_buy_on_return_visit"]
) AS
WITH all_visitor_stats AS (
  SELECT fullvisitorid, IF(COUNTIF(totals.transactions > 0 AND totals.newVisits IS NULL) > 0, 1, 0) AS will_buy_on_return_visit
  FROM `data-to-insights.ecommerce.web_analytics`
  GROUP BY fullvisitorid
)
SELECT * EXCEPT(unique_session_id) FROM (
  SELECT CONCAT(fullvisitorid, CAST(visitId AS STRING)) AS unique_session_id, will_buy_on_return_visit, MAX(CAST(h.eCommerceAction.action_type AS INT64)) AS latest_ecommerce_progress, IFNULL(totals.bounces, 0) AS bounces, IFNULL(totals.timeOnSite, 0) AS time_on_site, IFNULL(totals.pageviews, 0) AS pageviews, trafficSource.source, trafficSource.medium, channelGrouping, device.deviceCategory, IFNULL(geoNetwork.country, "") AS country
  FROM `data-to-insights.ecommerce.web_analytics`, UNNEST(hits) AS h
  JOIN all_visitor_stats USING(fullvisitorid)
  WHERE totals.newVisits = 1 AND date BETWEEN "20160801" AND "20170430"
  GROUP BY unique_session_id, will_buy_on_return_visit, bounces, time_on_site, totals.pageviews, trafficSource.source, trafficSource.medium, channelGrouping, device.deviceCategory, country
)'

echo -e "\n${YELLOW_TEXT}${BOLD_TEXT}Tarefa 3: Avaliando o modelo melhorado...${RESET_FORMAT}"
bq query --use_legacy_sql=false "
SELECT roc_auc, CASE WHEN roc_auc > 0.9 THEN 'good' WHEN roc_auc > 0.8 THEN 'fair' WHEN roc_auc > 0.7 THEN 'decent' WHEN roc_auc > 0.6 THEN 'not great' ELSE 'poor' END AS model_quality
FROM ML.EVALUATE(MODEL \`ecommerce.improved_customer_classification_model\`, (
  WITH all_visitor_stats AS (
    SELECT fullvisitorid, IF(COUNTIF(totals.transactions > 0 AND totals.newVisits IS NULL) > 0, 1, 0) AS will_buy_on_return_visit
    FROM \`data-to-insights.ecommerce.web_analytics\`
    GROUP BY fullvisitorid
  )
  SELECT CONCAT(fullvisitorid, CAST(visitId AS STRING)) AS unique_session_id, will_buy_on_return_visit, MAX(CAST(h.eCommerceAction.action_type AS INT64)) AS latest_ecommerce_progress, IFNULL(totals.bounces, 0) AS bounces, IFNULL(totals.timeOnSite, 0) AS time_on_site, IFNULL(totals.pageviews, 0) AS pageviews, trafficSource.source, trafficSource.medium, channelGrouping, device.deviceCategory, IFNULL(geoNetwork.country, '') AS country
  FROM \`data-to-insights.ecommerce.web_analytics\`, UNNEST(hits) AS h
  JOIN all_visitor_stats USING(fullvisitorid)
  WHERE totals.newVisits = 1 AND date BETWEEN '20170501' AND '20170630'
  GROUP BY unique_session_id, will_buy_on_return_visit, bounces, time_on_site, pageviews, trafficSource.source, trafficSource.medium, channelGrouping, device.deviceCategory, country
));"

# --- TAREFA 4: Modelo Finalizado e Predição ---
echo -e "\n${YELLOW_TEXT}${BOLD_TEXT}Tarefa 4: Treinando o finalized_classification_model...${RESET_FORMAT}"
bq query --use_legacy_sql=false '
CREATE OR REPLACE MODEL `ecommerce.finalized_classification_model`
OPTIONS (
  model_type="logistic_reg",
  labels = ["will_buy_on_return_visit"]
) AS
WITH all_visitor_stats AS (
  SELECT fullvisitorid, IF(COUNTIF(totals.transactions > 0 AND totals.newVisits IS NULL) > 0, 1, 0) AS will_buy_on_return_visit
  FROM `data-to-insights.ecommerce.web_analytics`
  GROUP BY fullvisitorid
)
SELECT * EXCEPT(unique_session_id) FROM (
  SELECT CONCAT(fullvisitorid, CAST(visitId AS STRING)) AS unique_session_id, will_buy_on_return_visit, MAX(CAST(h.eCommerceAction.action_type AS INT64)) AS latest_ecommerce_progress, IFNULL(totals.bounces, 0) AS bounces, IFNULL(totals.timeOnSite, 0) AS time_on_site, IFNULL(totals.pageviews, 0) AS pageviews, trafficSource.source, trafficSource.medium, channelGrouping, device.deviceCategory, IFNULL(geoNetwork.country, "") AS country
  FROM `data-to-insights.ecommerce.web_analytics`, UNNEST(hits) AS h
  JOIN all_visitor_stats USING(fullvisitorid)
  WHERE totals.newVisits = 1 AND date BETWEEN "20160801" AND "20170430"
  GROUP BY unique_session_id, will_buy_on_return_visit, bounces, time_on_site, totals.pageviews, trafficSource.source, trafficSource.medium, channelGrouping, device.deviceCategory, country
)'

echo -e "\n${YELLOW_TEXT}${BOLD_TEXT}Tarefa 4: Gerando previsões com o modelo finalizado...${RESET_FORMAT}"
bq query --use_legacy_sql=false '
SELECT * FROM ML.PREDICT(MODEL `ecommerce.finalized_classification_model`, (
  WITH all_visitor_stats AS (
    SELECT fullvisitorid, IF(COUNTIF(totals.transactions > 0 AND totals.newVisits IS NULL) > 0, 1, 0) AS will_buy_on_return_visit
    FROM `data-to-insights.ecommerce.web_analytics`
    GROUP BY fullvisitorid
  )
  SELECT CONCAT(fullvisitorid, "-", CAST(visitId AS STRING)) AS unique_session_id, will_buy_on_return_visit, MAX(CAST(h.eCommerceAction.action_type AS INT64)) AS latest_ecommerce_progress, IFNULL(totals.bounces, 0) AS bounces, IFNULL(totals.timeOnSite, 0) AS time_on_site, totals.pageviews, trafficSource.source, trafficSource.medium, channelGrouping, device.deviceCategory, IFNULL(geoNetwork.country, "") AS country
  FROM `data-to-insights.ecommerce.web_analytics`, UNNEST(hits) AS h
  JOIN all_visitor_stats USING(fullvisitorid)
  WHERE totals.newVisits = 1 AND date BETWEEN "20170701" AND "20170801"
  GROUP BY unique_session_id, will_buy_on_return_visit, bounces, time_on_site, totals.pageviews, trafficSource.source, trafficSource.medium, channelGrouping, device.deviceCategory, country
)) ORDER BY predicted_will_buy_on_return_visit DESC'

echo
echo "${GREEN_TEXT}${BOLD_TEXT}=======================================================${RESET_FORMAT}"
echo "${GREEN_TEXT}${BOLD_TEXT}            LABORATÓRIO CONCLUÍDO COM SUCESSO!         ${RESET_FORMAT}"
echo "${GREEN_TEXT}${BOLD_TEXT}=======================================================${RESET_FORMAT}"
echo "${CYAN_TEXT}Verifique no painel do laboratório se todas as tarefas${RESET_FORMAT}"
echo "${CYAN_TEXT}foram validadas clicando em 'Verificar meu progresso'.${RESET_FORMAT}"
echo