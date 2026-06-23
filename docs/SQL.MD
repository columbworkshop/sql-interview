# Задания по теме SQL

## Уровень 1

Базовый синтаксис, понимание агрегаций GROUP BY, умение соединять таблицы и работать с базовыми функциями NULL.

### Задача 1: Статистика активности пользователей

Условие: 
1. Выведите имена пользователей, их email и количество оформленных ими заказов. 
2. Если пользователь не сделал ни одного заказа, он тоже должен быть в списке со значением 0. 
3. Отсортируйте результат по убыванию количества заказов.

Решение:

```sql
SELECT 
    u.name, 
    u.email, 
    COUNT(o.id) AS orders_count
FROM users u
LEFT JOIN orders o ON u.id = o.user_id
GROUP BY u.name, u.email
ORDER BY orders_count DESC;
```

### Задача 2: Каталог активных товаров

Условие: 
1. Выведите названия всех активных товаров, их цену и название категории. 
2. Если у товара нет категории, в колонке категории нужно вывести текст 'Без категории'.

Решение:
```sql
SELECT
    p.name AS product_name,
    p.price,
    COALESCE(c.name, 'Без категории') AS category_name
FROM products p
         LEFT JOIN categories c ON p.category_id = c.id
WHERE p.is_active = TRUE
ORDER BY p.price DESC;
```

## Уровень 2

Работа с оконными функциями, временными таблицами (CTE), математические вычисления и отсутствие дублирования строк.

### Задача 3: Топ-1 самых дорогих товаров по категориям

Условие: 
1. Для каждой категории найдите 1 самый дорогой товар. 
2. Выведите название категории, название товара и цену.

Решение:
```sql
WITH RankedProducts AS (
    SELECT 
        c.name AS category_name,
        p.name AS product_name,
        p.price,
        ROW_NUMBER() OVER (PARTITION BY c.id ORDER BY p.price DESC) AS rn
    FROM products p
    JOIN categories c ON p.category_id = c.id
)
SELECT category_name, product_name, price
FROM RankedProducts
WHERE rn = 1;
```

### Задача 4: Расчет чистой выручки

Условие: 
1. Посчитайте чистую выручку для каждого успешно завершенного заказа (status = 'COMPLETED'). 
2. Выручка считается так: (сумма всех товаров в заказе минус процент скидки по промокоду) минус возвраты.

Решение:
```sql
WITH OrderTotals AS (
    -- базовые суммы заказов
    SELECT order_id, SUM(quantity * price_at_purchase) AS gross_total
    FROM order_items 
    GROUP BY order_id
),
OrderRefunds AS (
    -- суммы возвратов по каждому заказу
    SELECT order_id, SUM(refund_amount) AS total_refund
    FROM order_returns 
    GROUP BY order_id
)
--сборка
SELECT 
    o.id AS order_id,
    -- Применяем процентную скидку и вычитаем возвраты
    (ot.gross_total * (1 - o.promo_discount_pct / 100.0)) - COALESCE(orf.total_refund, 0) AS net_revenue
FROM orders o
JOIN OrderTotals ot ON o.id = ot.order_id
LEFT JOIN OrderRefunds orf ON o.id = orf.order_id
WHERE o.status = 'COMPLETED';
```

### Задача 5: Динамика новых и повторных заказов (Условная агрегация)

Условие: 
1. Бизнес хочет понимать структуру продаж. 
2. Выведите статистику по каждому месяцу:
   * Месяц оформления заказа (только для статуса COMPLETED). 
   * Количество первых заказов пользователей в этом месяце. 
   * Количество повторных заказов пользователей в этом месяце.

Решение:

```sql
WITH OrderRanks AS (
    -- Шаг 1: Нумеруем успешно завершенные заказы для каждого пользователя
    SELECT 
        id,
        user_id,
        DATE_TRUNC('month', order_date) AS order_month,
        ROW_NUMBER() OVER (PARTITION BY user_id ORDER BY order_date) AS rn
    FROM orders
    WHERE status = 'COMPLETED'
)
-- Шаг 2: Считаем метрики с помощью условной агрегации (FILTER)
SELECT 
    order_month,
    COUNT(id) FILTER (WHERE rn = 1) AS first_orders_count,
    COUNT(id) FILTER (WHERE rn > 1) AS repeat_orders_count
FROM OrderRanks
GROUP BY order_month
ORDER BY order_month;

/* Примечание: Если кандидат напишет классический CASE 
(SUM(CASE WHEN rn = 1 THEN 1 ELSE 0 END)) — это тоже верный ответ, 
но использование FILTER в PostgreSQL показывает более глубокое знание СУБД.
*/
```

Что проверяется:

1. Способность комбинировать оконную функцию ROW_NUMBER (для поиска первого заказа) с группировкой внешнего запроса.
2. Умение делать Pivot (сводку) данных с помощью агрегатных функций с условием (FILTER или CASE внутри агрегата). Это важнейший навык для построения дашбордов.

### Задача 6: Брошенные корзины

Условие: 
1. Маркетологам нужно найти сегмент пользователей, которые добавляли товары в корзину (add_to_cart), но ни разу за всю свою историю не нажимали кнопку покупки (purchase_click). 
2. Выведите список user_id таких пользователей.


Решение:

```sql
SELECT user_id
FROM user_actions_log
GROUP BY user_id
-- Оставляем только тех, кто выполнил первое условие, но НЕ выполнил второе
HAVING
    COUNT(*) FILTER (WHERE action_type = 'add_to_cart') > 0
    AND COUNT(*) FILTER (WHERE action_type = 'purchase_click') = 0;
```

Что проверяется:

1. Понимание того, как работает HAVING не просто с COUNT > 0, а со сложной логикой внутри группы.
2. Частая ошибка кандидатов: Попытка решить это через подзапросы WHERE action_type = 'add_to_cart' AND user_id NOT IN (SELECT ...) или сложные LEFT JOIN. 
3. Решение через условный HAVING работает в разы эффективнее, так как сканирует таблицу логов всего один раз.


### Задача 7: Time to First Purchase

Условие: 
1. Анализ скорости принятия решения. 
2. Напишите запрос, который посчитает среднее количество дней от даты регистрации пользователя до его первого успешно завершенного заказа (status = 'COMPLETED'). 
3. Сгруппируйте результат по источникам трафика (utm_source). Если utm_source пустой, считайте его источником 'organic'.

Решение:

```sql
WITH FirstOrders AS (
    -- Находим дату первой покупки для каждого пользователя
    SELECT 
        user_id, 
        MIN(DATE(order_date)) AS first_order_date
    FROM orders
    WHERE status = 'COMPLETED'
    GROUP BY user_id
)
SELECT 
    COALESCE(u.utm_source, 'organic') AS traffic_source,
    -- В PostgreSQL вычитание дат дает число (количество дней)
    ROUND(AVG(fo.first_order_date - u.registration_date), 1) AS avg_days_to_purchase
FROM users u
JOIN FirstOrders fo ON u.id = fo.user_id
GROUP BY COALESCE(u.utm_source, 'organic')
ORDER BY avg_days_to_purchase ASC;
```

Что проверяется:

1. Умение работать с арифметикой дат (разница между датами). 
2. Способность сопоставить данные из справочника юзеров и пред-агрегированной таблицы заказов (если использовать обычный JOIN таблицы orders без предварительной группировки MIN(order_date), среднее значение исказится из-за пользователей с несколькими покупками).
3. Правильная обработка NULL при группировке.

## Уровень 3

Сложные аналитические запросы.

### Задача 8: Генерация "Хлебных крошек" (Рекурсия)

Условие: 
1. Напишите запрос, который выведет все товары, но вместо простого `category_id` сгенерирует колонку с полным путем категории от корня. 
2. Формат колонки: `Электроника -> Смартфоны -> Чехлы и стекла`.

Решение:

```sql
WITH RECURSIVE CategoryTree AS (
    -- Базовая часть (Корневые категории)
    SELECT 
        id, 
        name::TEXT AS full_path
    FROM categories
    WHERE parent_id IS NULL

    UNION ALL

    -- Рекурсивная часть (Спускаемся по дереву вниз)
    SELECT 
        c.id, 
        ct.full_path || ' -> ' || c.name
    FROM categories c
    JOIN CategoryTree ct ON c.parent_id = ct.id
)
SELECT 
    p.name AS product_name, 
    ct.full_path AS category_path, 
    p.price
FROM products p
JOIN CategoryTree ct ON p.category_id = ct.id;
```

### Задача 9: Сессионизация логов

Условие:
1. Таблица `user_actions_log` содержит сырой кликстрим. 
2. Разбейте действия пользователей на логические "сессии". 
3. Правило: новая сессия пользователя начинается, если между его текущим и предыдущим действием прошло более 30 минут. 
4. Назначьте каждому действию номер сессии этого пользователя (1, 2, 3...).

Решение:

```sql
WITH TimeDiffs AS (
    -- Шаг 1: Находим время предыдущего действия для расчета разницы
    SELECT 
        id,
        user_id,
        action_type,
        created_at,
        LAG(created_at) OVER (PARTITION BY user_id ORDER BY created_at) AS prev_time
    FROM user_actions_log
),
SessionMarkers AS (
    -- Шаг 2: Ставим флаг "1", если это начало новой сессии
    SELECT 
        *,
        CASE 
            WHEN prev_time IS NULL THEN 1 -- Самое первое действие
            WHEN EXTRACT(EPOCH FROM (created_at - prev_time)) / 60 > 30 THEN 1 -- Прошло > 30 минут
            ELSE 0 
        END AS is_new_session
    FROM TimeDiffs
)
-- Шаг 3: Нарастающий итог (Running Total) для нумерации сессий
SELECT 
    id,
    user_id,
    action_type,
    created_at,
    SUM(is_new_session) OVER (PARTITION BY user_id ORDER BY created_at) AS session_number
FROM SessionMarkers
ORDER BY user_id, created_at;
```

Задача проверяет способности:
1. Использования оконной функции LAG() для доступа к предыдущей строке.
2. Знание функций работы со временем (EXTRACT EPOCH в PostgreSQL).
3. Использование нарастающего итога SUM() OVER () по бинарному флагу 1/0, который автоматически создает инкрементальные ID сессий.