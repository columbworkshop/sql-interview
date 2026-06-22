-- 1. Иерархический справочник категорий (для проверки рекурсивных запросов)
CREATE TABLE categories (
                            id SERIAL PRIMARY KEY,
                            name VARCHAR(100) NOT NULL,
                            parent_id INT REFERENCES categories(id)
);

-- 2. Справочник товаров
CREATE TABLE products (
                          id SERIAL PRIMARY KEY,
                          name VARCHAR(100) NOT NULL,
                          category_id INT REFERENCES categories(id),
                          price NUMERIC(10, 2) NOT NULL,
                          is_active BOOLEAN DEFAULT TRUE
);

-- 3. Пользователи
CREATE TABLE users (
                       id SERIAL PRIMARY KEY,
                       name VARCHAR(100) NOT NULL,
                       email VARCHAR(100) UNIQUE NOT NULL,
                       registration_date DATE NOT NULL,
                       utm_source VARCHAR(50)
);

-- 4. Заказы
CREATE TABLE orders (
                        id SERIAL PRIMARY KEY,
                        user_id INT REFERENCES users(id),
                        order_date TIMESTAMP NOT NULL,
                        status VARCHAR(20) NOT NULL, -- 'CREATED', 'PAID', 'COMPLETED', 'CANCELLED'
                        promo_discount_pct INT DEFAULT 0
);

-- 5. Позиции в заказе
CREATE TABLE order_items (
                             order_id INT REFERENCES orders(id),
                             product_id INT REFERENCES products(id),
                             quantity INT NOT NULL,
                             price_at_purchase NUMERIC(10, 2) NOT NULL,
                             PRIMARY KEY (order_id, product_id)
);

-- 6. Таблица возвратов (сложная логика сопоставления)
CREATE TABLE order_returns (
                               id SERIAL PRIMARY KEY,
                               order_id INT REFERENCES orders(id),
                               product_id INT REFERENCES products(id),
                               return_date TIMESTAMP NOT NULL,
                               refund_amount NUMERIC(10, 2) NOT NULL
);

-- 7. Сырой лог действий (Кликстрим для аналитики больших данных)
CREATE TABLE user_actions_log (
                                  id BIGSERIAL PRIMARY KEY,
                                  user_id INT REFERENCES users(id),
                                  action_type VARCHAR(50) NOT NULL, -- 'page_view', 'add_to_cart', 'purchase_click'
                                  page_url VARCHAR(255),
                                  created_at TIMESTAMP NOT NULL
);

-- ========================================================
-- НАПОЛНЕНИЕ ДАННЫМИ (с граблями и пограничными случаями)
-- ========================================================

-- Дерево категорий: Электроника -> Смартфоны -> Аксессуары
INSERT INTO categories (id, name, parent_id) VALUES
                                                 (1, 'Электроника', NULL),
                                                 (2, 'Одежда', NULL),
                                                 (3, 'Смартфоны', 1),
                                                 (4, 'Ноутбуки', 1),
                                                 (5, 'Чехлы и стекла', 3),
                                                 (6, 'Мужская одежда', 2);

INSERT INTO products (id, name, category_id, price, is_active) VALUES
                                                                   (1, 'iPhone 15', 3, 100000.00, TRUE),
                                                                   (2, 'MacBook Air', 4, 130000.00, TRUE),
                                                                   (3, 'Чехол Silicone Case', 5, 3000.00, TRUE),
                                                                   (4, 'Защитное стекло', 5, 1500.00, TRUE),
                                                                   (5, 'Футболка хлопковая', 6, 2000.00, TRUE),
                                                                   (6, 'Архивный кабель', 1, 500.00, FALSE); -- Неактивный товар

INSERT INTO users (id, name, email, registration_date, utm_source) VALUES
                                                                       (1, 'Иван', 'ivan@test.com', '2025-01-10', 'google'),
                                                                       (2, 'Анна', 'anna@test.com', '2025-01-15', 'yandex'),
                                                                       (3, 'Сергей', 'serg@test.com', '2025-02-01', NULL), -- Органический трафик
                                                                       (4, 'Ольга', 'olga@test.com', '2025-02-20', 'google'),
                                                                       (5, 'Дмитрий', 'dima@test.com', '2025-03-01', 'yandex');

-- Заказы со скидками и разными статусами
INSERT INTO orders (id, user_id, order_date, status, promo_discount_pct) VALUES
                                                                             (1, 1, '2025-01-12 10:00:00', 'COMPLETED', 10), -- Скидка 10%
                                                                             (2, 1, '2025-01-20 15:30:00', 'COMPLETED', 0),
                                                                             (3, 2, '2025-02-05 14:00:00', 'CANCELLED', 0),  -- Отменен
                                                                             (4, 3, '2025-02-10 11:00:00', 'COMPLETED', 0),
                                                                             (5, 4, '2025-02-22 16:00:00', 'COMPLETED', 20), -- Скидка 20%
                                                                             (6, 1, '2025-03-05 09:00:00', 'PAID', 0);

INSERT INTO order_items (order_id, product_id, quantity, price_at_purchase) VALUES
                                                                                (1, 1, 1, 100000.00),
                                                                                (1, 3, 1, 3000.00),
                                                                                (2, 4, 2, 1500.00),
                                                                                (3, 2, 1, 130000.00),
                                                                                (4, 1, 1, 100000.00),
                                                                                (5, 5, 5, 2000.00),
                                                                                (6, 3, 1, 3000.00);

-- Возвраты
INSERT INTO order_returns (order_id, product_id, return_date, refund_amount) VALUES
    (1, 3, '2025-01-14 12:00:00', 2700.00); -- Вернули чехол (с учетом скидки 10%)

-- Лог кликстрима (для сессионизации и расчета продуктовых метрик)
INSERT INTO user_actions_log (user_id, action_type, page_url, created_at) VALUES
                                                                              (1, 'page_view', '/catalog', '2025-01-12 09:45:00'),
                                                                              (1, 'add_to_cart', '/catalog/item1', '2025-01-12 09:50:00'),
                                                                              (1, 'purchase_click', '/order/checkout', '2025-01-12 10:00:00'),
-- Сессия 2 пользователя 1 через несколько часов
                                                                              (1, 'page_view', '/profile', '2025-01-12 14:00:00'),
                                                                              (1, 'page_view', '/catalog', '2025-01-12 14:05:00'),
-- Активность в феврале и марте для Retention
                                                                              (3, 'page_view', '/catalog', '2025-02-10 10:30:00'),
                                                                              (3, 'purchase_click', '/order/checkout', '2025-02-10 11:00:00'),
                                                                              (1, 'page_view', '/catalog', '2025-02-15 12:00:00'), -- Возврат юзера 1 в феврале
                                                                              (1, 'page_view', '/catalog', '2025-03-05 08:45:00'); -- Возврат юзера 1 в марте