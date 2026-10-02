/* Проект «Секреты Тёмнолесья»
 * Цель проекта: изучить влияние характеристик игроков и их игровых персонажей 
 * на покупку внутриигровой валюты «райские лепестки», а также оценить 
 * активность игроков при совершении внутриигровых покупок
 * 
 * Автор: Авдеев Николай
 * Дата: 27.10.2025
 */

/* Исследование доли платящих игроков
 * Доля платящих пользователей по всем данным:
 */

   SELECT COUNT(id) AS total_users,
          SUM(payer) AS total_users_payer,
          SUM(payer) / COUNT(id)::numeric AS dolya_payer_users
   FROM fantasy.users; 
   

/* Доля платящих пользователей в разрезе расы персонажа:
 */  
   WITH 
   total_payer_r AS (
   SELECT race,
          COUNT(payer) AS total_payer_race
   FROM fantasy.users AS u
   JOIN fantasy.race AS r ON u.race_id = r.race_id
   WHERE payer = 1
   GROUP BY race
   ),
   total_payer_r_u AS (
   SELECT race,
          COUNT(id) OVER (PARTITION BY race) AS total_user_race
   FROM fantasy.users AS u
   JOIN fantasy.race AS r ON u.race_id = r.race_id
   )  
   SELECT DISTINCT pr.race,
          total_payer_race,
          total_user_race,
          total_payer_race / total_user_race::numeric AS dolya_payer_race
   FROM total_payer_r_u AS pru
   JOIN total_payer_r AS pr ON pru.race = pr.race
   ORDER BY total_payer_race DESC; 

   
/*
 * ВЫВОДЫ ПО ДОЛЕ ПЛАТЯЩИХ ИГРОКОВ:
 * Всего на 22214 пользователей приходится 3929 платящих игроков, что составляет около 18%. 
 * Несмотря на большой размах в кол-ве игроков каждой расы, соотношение пользователей,
 * покупающих валюту «райские лепестки» к общему числу игроков данной расы составляет около 17,4%, исключая только 2 расы,
 * которые преодолели данную отметку: «Hobbit» и «Demon», с показателями 18% и 19,4% соответственно. 
 * Делаем вывод, что раса персонажа не имеет особого влияния на покупку валюты «райские лепестки».
 */
 

/* Исследование внутриигровых покупок 
 * Статистические показатели по полю amount:
 */
   
   SELECT COUNT(amount) AS total_amount, 
          SUM(amount) AS sum_amount, 
          MIN(amount) AS min_amount, 
          MAX(amount) AS max_amount, 
          AVG(amount) AS avg_amount, 
          PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY amount) AS median_amount,
          STDDEV(amount) AS standart_div_amount
   FROM fantasy.events;
   
/*
 * ВЫВОДЫ ПО СТАТИСТИКЕ ПОКУПОК:
 * Всего было совершено 1307678 игровых покупок. Стоимость варьируется от самой минимальной (0) до максимальной (486615.1). 
 * Большинство покупок имеют малую стоимость (менее 75 лепестков), но есть и крупные, что поднимают среднее значение вверх до отметки около 525.7 лепестков,
 * что во много раз превышает медиану с показателем 75 лепестков. 
 * Это подтверждает высокий максимум и большое стандартное отклонение, свидетельствуя о значительном разбросе в стоимости покупок - 2517.3 лепестков.
 */

/* Аномальные нулевые покупки:
 */
   
   SELECT (SELECT COUNT(amount) FROM fantasy.events WHERE amount = 0) AS zero_amount, 
          COUNT(amount) AS total_amount, 
          (SELECT COUNT(amount) FROM fantasy.events WHERE amount = 0) / COUNT(amount)::numeric AS dolya_zero_amount
   FROM fantasy.events; 
   
/*
 * ВЫВОДЫ ПО АНОМАЛИЯМ:
 * Всего на 1307678 внутриигровых транзакций приходится 907 с нулевой стоимостью покупки, что составляет около 0.07% от общего кол-ва покупок.
 */
   
   
/* Популярные эпические предметы:
 */
   
   WITH
   total_epic_sales_zap AS (
   SELECT i.game_items,
          COUNT(transaction_id) AS total_epic_sales
   FROM fantasy.items AS i
   JOIN fantasy.events AS e ON i.item_code = e.item_code
   WHERE amount <> 0
   GROUP BY i.game_items  
   ),
   total_sales_zap AS (
   SELECT COUNT(transaction_id) AS total_sales
   FROM fantasy.events
   WHERE amount <> 0  
   ),
   players_count_zap AS (
   SELECT i.game_items, 
          COUNT(DISTINCT e.id) AS players_count
   FROM fantasy.events AS e
   JOIN fantasy.items AS i ON e.item_code = i.item_code
   WHERE amount <> 0
   GROUP BY i.game_items
   ORDER BY players_count DESC  
   ),
   total_players_zap AS (
   SELECT COUNT(DISTINCT id) AS total_players
   FROM fantasy.events
   WHERE amount <> 0  
   )
   SELECT tes.game_items, 
          total_epic_sales,  
          (SELECT total_sales FROM total_sales_zap) AS total_sales,
          total_epic_sales::numeric / (SELECT total_sales FROM total_sales_zap) AS dolya_epic_sales, 
          players_count,
          (SELECT total_players FROM total_players_zap) AS total_players,
          players_count::numeric / (SELECT total_players FROM total_players_zap) AS dolya_players_sales
   FROM total_epic_sales_zap AS tes 
   LEFT JOIN players_count_zap AS pc ON tes.game_items = pc.game_items 
   ORDER BY players_count DESC;
   
/*
 * ВЫВОДЫ ПО ЭПИЧЕСКИМ ПРЕДМЕТАМ:
 * Данные таблицы показывают, что среди эпических предметов наиболее популярными являются «Book of Legends» и «Bag of Holding». 
 * На них приходится примерно 76.9% и 20.8% всех покупок соответственно. Эти предметы также наиболее часто 
 * приобретаются игроками - около 88.4% и 86.8% игроков, совершавших покупки, покупали эти предметы хотя бы раз. 
 * Остальные предметы, такие как «Necklace of Wisdom», «Gems of Insight» и «Treasure Map», занимают значительно меньшую долю продаж и их покупают 
 * меньшее кол-во игроков, что свидетельствует о меньшей популярности или редкости этих предметов. 
 * Также среди предметов есть те, что не покупаются вовсе их кол-во составляет – 29 шт.
 */
   
/* Решение ad hoc-задач 
 * Зависимость активности игроков от расы персонажа:
 */

   WITH
   count_users_race_zap AS (
   SELECT race_id,
          COUNT(id) AS count_users_race
   FROM fantasy.users
   GROUP BY race_id 
   ),
   dolya_sales_users_zap AS (
   SELECT u.race_id,
          COUNT(DISTINCT e.id) AS total_users_sales, 
          curz.count_users_race,
          COUNT(DISTINCT e.id)::numeric / curz.count_users_race AS dolya_sales_users
   FROM fantasy.users AS u
   JOIN fantasy.events AS e ON u.id = e.id
   JOIN count_users_race_zap AS curz ON u.race_id = curz.race_id
   WHERE e.amount > 0
   GROUP BY u.race_id, curz.count_users_race 
   ),
   payer_sales_user AS (
   SELECT u.race_id,
          COUNT(DISTINCT u.id) AS user_id
   FROM fantasy.users AS u
   JOIN fantasy.events AS e ON u.id = e.id
   WHERE u.payer = 1 AND e.amount > 0
   GROUP BY u.race_id 
   ),
   purchases AS (
   SELECT u.race_id,
          u.id AS user_id,
          COUNT(e.id) AS count_purchases,
          SUM(e.amount) AS total_amount
   FROM fantasy.users AS u
   JOIN fantasy.events AS e ON u.id = e.id
   WHERE e.amount > 0 
   GROUP BY u.race_id, u.id 
   ),
   purchases_agg AS (
   SELECT race_id,
          SUM(count_purchases) AS total_purchases,
          SUM(total_amount) AS total_spent
   FROM purchases
   GROUP BY race_id
   )   
   SELECT r.race,
          c.count_users_race, 
          dsu.total_users_sales, 
          dolya_sales_users, 
          psu.user_id AS count_payers_sales, 
          psu.user_id::numeric / dsu.total_users_sales AS dolya_payer_sales_users, 
          pa.total_purchases::numeric / dsu.total_users_sales AS avg_purchases_per_buyer, 
          pa.total_spent::numeric / pa.total_purchases AS avg_cost_per_purchase, 
          pa.total_spent::numeric / dsu.total_users_sales AS avg_total_spent_per_buyer 
   FROM count_users_race_zap AS c
   LEFT JOIN dolya_sales_users_zap AS dsu ON c.race_id = dsu.race_id
   LEFT JOIN payer_sales_user AS psu ON c.race_id = psu.race_id
   LEFT JOIN purchases_agg AS pa ON c.race_id = pa.race_id
   JOIN fantasy.race AS r ON c.race_id = r.race_id
   ORDER BY c.count_users_race DESC;
   
/*
 * ВЫВОДЫ ПО АКТИВНОСТИ РАС И ОБЩИЕ РЕКОМЕНДАЦИИ:
 * Активность игроков по покупке эпических предметов практически не зависит от расы - показатели схожи для всех рас, около 60-63%. 
 * Однако, расам «Angel» и «Human» требуется покупать больше предметов, несмотря на меньшую среднюю стоимость, 
 * что указывает на более высокую частоту покупок. Раса «Northman» при этом тратит существенно больше в абсолютных цифрах. 
 * Также среди игроков есть как малоактивные, так и очень активные, что искажает средние показатели. 
 * Поэтому для точных выводов важно учитывать не только внутриигровые затраты, но и реальные деньги, а также особенности внутриигрового обмена, 
 * которые могут влиять на общий объем покупок.
 */
  
    
/*
 * Рекомендуется сосредоточить усилия на популярных предметах, таких как «Book of Legends» и «Bag of Holding», 
 * т.к. они занимают основную долю продаж. 
 * Активность по покупке у разных рас примерно равна, но рассматривать необходимо активность внутри рас и уровень затрат 
 * с учетом особенностей поведения и обмена.  Это поможет сбалансировать маркетинговую стратегию и повысить эффективность.
 */
   
