-- ========================================================
-- 0. УДАЛЕНИЕ СУЩЕСТВУЮЩИХ ТАБЛИЦ (Для предотвращения ошибок при повторном запуске)
-- Сначала удаляем таблицы со связями M:N, затем 1:N, затем справочники
-- ========================================================
DROP TABLE IF EXISTS [OrderProduct];
DROP TABLE IF EXISTS [Order];
DROP TABLE IF EXISTS [Product];
DROP TABLE IF EXISTS [User];
DROP TABLE IF EXISTS [OrderStatus];
DROP TABLE IF EXISTS [Supplier];
DROP TABLE IF EXISTS [Manufacturer];
DROP TABLE IF EXISTS [Category];
DROP TABLE IF EXISTS [PickupPoint];
DROP TABLE IF EXISTS [Role];
GO

-- ========================================================
-- 1. ТАБЛИЦЫ-СПРАВОЧНИКИ (Независимые сущности)
-- ========================================================

-- Роли пользователей (Администратор, Менеджер, Клиент)
CREATE TABLE [Role] (
    [RoleID] INT IDENTITY(1,1) PRIMARY KEY,
    [RoleName] NVARCHAR(100) NOT NULL
);
GO

-- Пункты выдачи заказов
CREATE TABLE [PickupPoint] (
    [PickupPointID] INT IDENTITY(1,1) PRIMARY KEY,
    [PostalCode] NVARCHAR(20) NULL,
    [City] NVARCHAR(100) NULL,
    [Street] NVARCHAR(100) NULL,
    [House] NVARCHAR(20) NULL
);
GO

-- Категории товаров
CREATE TABLE [Category] (
    [CategoryID] INT IDENTITY(1,1) PRIMARY KEY,
    [CategoryName] NVARCHAR(100) NOT NULL
);
GO

-- Производители
CREATE TABLE [Manufacturer] (
    [ManufacturerID] INT IDENTITY(1,1) PRIMARY KEY,
    [ManufacturerName] NVARCHAR(100) NOT NULL
);
GO

-- Поставщики
CREATE TABLE [Supplier] (
    [SupplierID] INT IDENTITY(1,1) PRIMARY KEY,
    [SupplierName] NVARCHAR(100) NOT NULL
);
GO

-- Статусы заказов (Новый, Завершен...)
CREATE TABLE [OrderStatus] (
    [StatusID] INT IDENTITY(1,1) PRIMARY KEY,
    [StatusName] NVARCHAR(100) NOT NULL
);
GO


-- ========================================================
-- 2. ОСНОВНЫЕ СУЩНОСТИ (Связи 1:N)
-- ========================================================

-- Пользователи
CREATE TABLE [User] (
    [UserID] INT IDENTITY(1,1) PRIMARY KEY,
    [RoleID] INT FOREIGN KEY REFERENCES [Role]([RoleID]) NOT NULL,
    [FullName] NVARCHAR(250) NOT NULL,
    [Login] NVARCHAR(100) NOT NULL UNIQUE,
    [Password] NVARCHAR(100) NOT NULL
);
GO

-- Товары
CREATE TABLE [Product] (
    [ProductArticleNumber] NVARCHAR(100) PRIMARY KEY, 
    [Title] NVARCHAR(250) NOT NULL,
    [Unit] NVARCHAR(20) NOT NULL,                    
    [Price] DECIMAL(18,2) NOT NULL,
    [CategoryID] INT FOREIGN KEY REFERENCES [Category]([CategoryID]) NOT NULL,
    [ManufacturerID] INT FOREIGN KEY REFERENCES [Manufacturer]([ManufacturerID]) NOT NULL,
    [SupplierID] INT FOREIGN KEY REFERENCES [Supplier]([SupplierID]) NOT NULL,
    [CurrentDiscount] INT NOT NULL,                   
    [QuantityInStock] INT NOT NULL,                   
    [Description] NVARCHAR(1000) NULL,
    [Photo] NVARCHAR(150) NULL                        
);
GO

-- Заказы
CREATE TABLE [Order] (
    [OrderID] INT IDENTITY(1,1) PRIMARY KEY,
    [OrderDate] DATE NOT NULL,
    [DeliveryDate] DATE NOT NULL,
    [PickupPointID] INT FOREIGN KEY REFERENCES [PickupPoint]([PickupPointID]) NOT NULL,
    [UserID] INT FOREIGN KEY REFERENCES [User]([UserID]) NULL, -- NULL разрешен для Гостей
    [ReceiveCode] INT NOT NULL,                       
    [StatusID] INT FOREIGN KEY REFERENCES [OrderStatus]([StatusID]) NOT NULL
);
GO


-- ========================================================
-- 3. ПРОМЕЖУТОЧНЫЕ ТАБЛИЦЫ (Связи M:N)
-- ========================================================

-- Состав заказа
CREATE TABLE [OrderProduct] (
    [OrderID] INT FOREIGN KEY REFERENCES [Order]([OrderID]),
    [ProductArticleNumber] NVARCHAR(100) FOREIGN KEY REFERENCES [Product]([ProductArticleNumber]),
    [Count] INT NOT NULL,
    PRIMARY KEY ([OrderID], [ProductArticleNumber]) 
);
GO












