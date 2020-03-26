-- Для SingleDB и CitusDB
-- Найдем кампании с самым большим бюджетом

SELECT name, cost_model, state, monthly_budget
  FROM campaigns
 WHERE company_id = 5
 ORDER BY monthly_budget DESC
 LIMIT 10;

-- Удвоим бюджет

UPDATE campaigns
   SET monthly_budget = monthly_budget*2
 WHERE company_id = 5;

-- Поработаем в транзакции

BEGIN;

UPDATE campaigns
   SET monthly_budget = monthly_budget + 1000
 WHERE company_id = 5
   AND id = 40;

UPDATE campaigns
   SET monthly_budget = monthly_budget - 1000
 WHERE company_id = 5
   AND id = 41;

COMMIT;

-- CitusDB
-- Запрос, который включает в себя агрегаты и оконные функции. 
-- Запрос ранжирует объявления в каждой кампании по количеству впечатлений.

SELECT a.campaign_id,
       RANK() OVER (
         PARTITION BY a.campaign_id
         ORDER BY a.campaign_id, count(*) desc
       ), count(*) as n_impressions, a.id
  FROM ads as a
  JOIN impressions as i
    ON i.company_id = a.company_id
   AND i.ad_id      = a.id
   WHERE a.company_id = 76 
GROUP BY a.campaign_id, a.id
ORDER BY a.campaign_id, n_impressions desc;


-- Single DB
-- Запрос ранжирует объявления в каждой рекламной кампании по количеству впечатлений.

EXPLAIN 
SELECT a.campaign_id,
      RANK() OVER (
         PARTITION BY a.campaign_id
         ORDER BY a.campaign_id, count(*) desc
       ), count(*) as n_impressions, a.id
FROM ads as a
LEFT JOIN campaigns AS c ON a.campaign_id = c.id 
JOIN impressions AS i ON i.ad_id = a.id 
WHERE c.company_id = 5
GROUP BY a.campaign_id, a.id
ORDER BY a.campaign_id, n_impressions desc;

-- CitusDB и SingleDB
-- Местоположение всех, кто кликнул на объявление 290.

SELECT c.id, clicked_at, latlon
  FROM geo_ips, clicks c
 WHERE addrs >> c.user_ip;
   AND e.company_id = 5
   AND c.ad_id = 290;

-- CitusDB
-- Попробуем изменить таблицу ads

ALTER TABLE ads ADD COLUMN caption text;