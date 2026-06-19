-- ========================================================
-- 1. ТАБЛИЦЫ-СПРАВОЧНИКИ (Независимые сущности)
-- ========================================================

-- Роли пользователей (Администратор, Менеджер, Клиент)
CREATE TABLE [Role] (
    [RoleID] INT IDENTITY(1,1) PRIMARY KEY,
    [RoleName] NVARCHAR(100) NOT NULL
);

-- Пункты выдачи заказов
CREATE TABLE [PickupPoint] (
    [PickupPointID] INT IDENTITY(1,1) PRIMARY KEY,
    [PostalCode] NVARCHAR(20) NULL,
    [City] NVARCHAR(100) NULL,
    [Street] NVARCHAR(150) NULL,
    [House] NVARCHAR(20) NULL
);

-- Категории товаров (Женская обувь, Мужская обувь и т.д.)
CREATE TABLE [Category] (
    [CategoryID] INT IDENTITY(1,1) PRIMARY KEY,
    [CategoryName] NVARCHAR(150) NOT NULL
);

-- Производители (Kari, Rieker, Marco Tozzi...)
CREATE TABLE [Manufacturer] (
    [ManufacturerID] INT IDENTITY(1,1) PRIMARY KEY,
    [ManufacturerName] NVARCHAR(150) NOT NULL
);

-- Поставщики (Kari, Обувь для вас...)
CREATE TABLE [Supplier] (
    [SupplierID] INT IDENTITY(1,1) PRIMARY KEY,
    [SupplierName] NVARCHAR(150) NOT NULL
);

-- Статусы заказов (Новый, Завершен...)
CREATE TABLE [OrderStatus] (
    [StatusID] INT IDENTITY(1,1) PRIMARY KEY,
    [StatusName] NVARCHAR(100) NOT NULL
);


-- ========================================================
-- 2. ОСНОВНЫЕ СУЩНОСТИ (Связи 1:N)
-- ========================================================

-- Пользователи
CREATE TABLE [User] (
    [UserID] INT IDENTITY(1,1) PRIMARY KEY,
    [RoleID] INT FOREIGN KEY REFERENCES [Role]([RoleID]) NOT NULL,
    [FullName] NVARCHAR(150) NOT NULL,
    [Login] NVARCHAR(100) NOT NULL UNIQUE,
    [Password] NVARCHAR(100) NOT NULL
);

-- Товары (Все текстовые справочники заменены на внешние ключи INT)
CREATE TABLE [Product] (
    [ProductArticleNumber] NVARCHAR(100) PRIMARY KEY, -- Строковый PK из файла (например, 'А112Т4')
    [Title] NVARCHAR(150) NOT NULL,
    [Unit] NVARCHAR(20) NOT NULL,                    -- Ед. измерения (шт.)
    [Price] DECIMAL(18,2) NOT NULL,
    [CategoryID] INT FOREIGN KEY REFERENCES [Category]([CategoryID]) NOT NULL,
    [ManufacturerID] INT FOREIGN KEY REFERENCES [Manufacturer]([ManufacturerID]) NOT NULL,
    [SupplierID] INT FOREIGN KEY REFERENCES [Supplier]([SupplierID]) NOT NULL,
    [CurrentDiscount] INT NOT NULL,                   -- Действующая скидка
    [QuantityInStock] INT NOT NULL,                   -- Кол-во на складе
    [Description] NVARCHAR(MAX) NULL,
    [Photo] NVARCHAR(100) NULL                        -- Имя файла картинки
);

-- Заказы (Связь с User через UserID, статус через StatusID)
CREATE TABLE [Order] (
    [OrderID] INT IDENTITY(1,1) PRIMARY KEY,
    [OrderDate] DATE NOT NULL,
    [DeliveryDate] DATE NOT NULL,
    [PickupPointID] INT FOREIGN KEY REFERENCES [PickupPoint]([PickupPointID]) NOT NULL,
    [UserID] INT FOREIGN KEY REFERENCES [User]([UserID]) NULL, -- NULL разрешен для Гостей
    [ReceiveCode] INT NOT NULL,                       
    [StatusID] INT FOREIGN KEY REFERENCES [OrderStatus]([StatusID]) NOT NULL
);


-- ========================================================
-- 3. ПРОМЕЖУТОЧНЫЕ ТАБЛИЦЫ (Связи M:N)
-- ========================================================

-- Состав заказа (Полная нормализация состава)
CREATE TABLE [OrderProduct] (
    [OrderID] INT FOREIGN KEY REFERENCES [Order]([OrderID]),
    [ProductArticleNumber] NVARCHAR(100) FOREIGN KEY REFERENCES [Product]([ProductArticleNumber]),
    [Count] INT NOT NULL,
    PRIMARY KEY ([OrderID], [ProductArticleNumber]) -- Составной ПК
);











-- Шаг 1: Роли (Задаем вручную, так как это системный справочник)
INSERT INTO [dbo].[Role] ([RoleName]) VALUES 
(N'Администратор'), 
(N'Менеджер'), 
(N'Авторизированный клиент');

-- Шаг 2: Статусы заказов (Из temp_zakaz)
INSERT INTO [dbo].[OrderStatus] ([StatusName])
SELECT DISTINCT LTRIM(RTRIM([Статус_заказа])) 
FROM [dbo].[temp_zakaz] 
WHERE [Статус_заказа] IS NOT NULL;

-- Шаг 3: Категории товаров (Из temp_tovar)
INSERT INTO [dbo].[Category] ([CategoryName])
SELECT DISTINCT LTRIM(RTRIM([Категория_товара])) 
FROM [dbo].[temp_tovar] 
WHERE [Категория_товара] IS NOT NULL;

-- Шаг 4: Производители (Из temp_tovar)
INSERT INTO [dbo].[Manufacturer] ([ManufacturerName])
SELECT DISTINCT LTRIM(RTRIM([Производитель])) 
FROM [dbo].[temp_tovar] 
WHERE [Производитель] IS NOT NULL;

-- Шаг 5: Поставщики (Из temp_tovar)
INSERT INTO [dbo].[Supplier] ([SupplierName])
SELECT DISTINCT LTRIM(RTRIM([Поставщик])) 
FROM [dbo].[temp_tovar] 
WHERE [Поставщик] IS NOT NULL;

-- Шаг 6: Пункты выдачи (Из temp_point с атомарным разделением)
INSERT INTO [dbo].[PickupPoint] ([PostalCode], [City], [Street], [House])
SELECT 
    LTRIM(RTRIM([column1])), 
    LTRIM(RTRIM([column2])), 
    LTRIM(RTRIM([column3])), 
    LTRIM(RTRIM([column4]))
FROM [dbo].[temp_point];

-- Шаг 7: Пользователи (Связываем текстовую роль с ID роли)
INSERT INTO [dbo].[User] ([RoleID], [FullName], [Login], [Password])
SELECT 
    r.[RoleID], 
    LTRIM(RTRIM(u.[ФИО])), 
    LTRIM(RTRIM(u.[Логин])), 
    LTRIM(RTRIM(u.[Пароль]))
FROM [dbo].[temp_user] u
JOIN [dbo].[Role] r ON LTRIM(RTRIM(u.[Роль_сотрудника])) = r.[RoleName];

-- Шаг 8: Товары (Связываем все текстовые справочники, чтобы получить их ID)
INSERT INTO [dbo].[Product] ([ProductArticleNumber], [Title], [Unit], [Price], [CategoryID], [ManufacturerID], [SupplierID], [CurrentDiscount], [QuantityInStock], [Description], [Photo])
SELECT 
    LTRIM(RTRIM(t.[Артикул])), 
    LTRIM(RTRIM(t.[Наименование_товара])), 
    LTRIM(RTRIM(t.[Единица_измерения])), 
    CAST(t.[Цена] AS DECIMAL(18,2)),
    c.[CategoryID], 
    m.[ManufacturerID], 
    s.[SupplierID], 
    CAST(t.[Действующая_скидка] AS INT), 
    t.[Кол_во_на_складе], 
    LTRIM(RTRIM(t.[Описание_товара])), 
    LTRIM(RTRIM(t.[Фото]))
FROM [dbo].[temp_tovar] t
JOIN [dbo].[Category] c ON LTRIM(RTRIM(t.[Категория_товара])) = c.[CategoryName]
JOIN [dbo].[Manufacturer] m ON LTRIM(RTRIM(t.[Производитель])) = m.[ManufacturerName]
JOIN [dbo].[Supplier] s ON LTRIM(RTRIM(t.[Поставщик])) = s.[SupplierName];

-- Шаг 9: Заказы (Включаем IDENTITY_INSERT для сохранения ID из файла, связываем клиента по ФИО)
-- Удаляем строку с несуществующей датой (30 февраля)
DELETE FROM [dbo].[temp_zakaz] 
WHERE [Дата_заказа] LIKE '30.02.%';

-- Теперь спокойно запускаем вставку
SET IDENTITY_INSERT [dbo].[Order] ON;

INSERT INTO [dbo].[Order] ([OrderID], [OrderDate], [DeliveryDate], [PickupPointID], [UserID], [ReceiveCode], [StatusID])
SELECT 
    z.[Номер_заказа], 
    CONVERT(DATE, LTRIM(RTRIM(z.[Дата_заказа])), 104), -- 104 теперь отработает идеально
    z.[Дата_доставки], 
    z.[Адрес_пункта_выдачи], 
    u.[UserID], 
    z.[Код_для_получения], 
    os.[StatusID]
FROM [dbo].[temp_zakaz] z
LEFT JOIN [dbo].[User] u ON LTRIM(RTRIM(z.[ФИО_авторизированного_клиента])) = u.[FullName]
JOIN [dbo].[OrderStatus] os ON LTRIM(RTRIM(z.[Статус_заказа])) = os.[StatusName];

SET IDENTITY_INSERT [dbo].[Order] OFF;

TRUNCATE TABLE [dbo].[OrderProduct];

;WITH SplitOrders AS (
    SELECT 
        [Номер_заказа] AS OrderID,
        -- Превращаем строку с запятыми в XML-теги, чтобы точно сохранить позиции
        CAST('<x>' + REPLACE([Артикул_заказа], ',', '</x><x>') + '</x>' AS XML) AS XMLData
    FROM [dbo].[temp_zakaz]
),
NumberedItems AS (
    SELECT 
        OrderID,
        LTRIM(RTRIM(T.x.value('.', 'NVARCHAR(100)'))) AS Item,
        ROW_NUMBER() OVER (PARTITION BY OrderID ORDER BY (SELECT NULL)) AS Position
    FROM SplitOrders
    CROSS APPLY XMLData.nodes('/x') AS T(x)
),
Pairs AS (
    SELECT 
        a.OrderID,
        a.Item AS ProductArticleNumber,
        TRY_CAST(LTRIM(RTRIM(b.Item)) AS INT) AS [Count]
    FROM NumberedItems a
    JOIN NumberedItems b ON a.OrderID = b.OrderID AND a.Position = b.Position - 1
    WHERE a.Position % 2 != 0
)
INSERT INTO [dbo].[OrderProduct] ([OrderID], [ProductArticleNumber], [Count])
SELECT OrderID, ProductArticleNumber, [Count]
FROM Pairs
WHERE [Count] IS NOT NULL 
  AND ProductArticleNumber IN (SELECT [ProductArticleNumber] FROM [dbo].[Product]);