




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
    LTRIM(RTRIM([Почтовый_индекс])), 
    LTRIM(RTRIM([Город])), 
    LTRIM(RTRIM([Улица])), 
    LTRIM(RTRIM([Дом]))
FROM [dbo].[temp_points];

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
SET IDENTITY_INSERT [dbo].[Order] ON;

INSERT INTO [dbo].[Order] ([OrderID], [OrderDate], [DeliveryDate], [PickupPointID], [UserID], [ReceiveCode], [StatusID])
SELECT 
    z.[Номер_заказа], 
    z.[Дата_заказа],
    z.[Дата_доставки], 
    z.[Адрес_пункта_выдачи], 
    u.[UserID], -- Сюда попадет только ID клиента, дубля не будет
    z.[Код_для_получения], 
    os.[StatusID]
FROM [dbo].[temp_zakaz] z
-- Привязываемся к пользователю, но строго фильтруем, чтобы это был клиент:
LEFT JOIN [dbo].[User] u ON LTRIM(RTRIM(z.[ФИО_авторизированного_клиента])) = u.[FullName]
                        AND u.[RoleID] = 3 -- Или u.RoleID = (ID роли клиента)
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