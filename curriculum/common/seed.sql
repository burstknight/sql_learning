-- ============================================================
-- 範例資料庫：模擬公司訂單系統（全課程共用）
-- 目標版本：SQL Server 2014 相容
-- 載入方式（推薦用 sqlcmd，支援 GO 批次分隔符）：
--     sqlcmd -S localhost,1433 -U sa -P 'LearningP@ssw0rd' -i seed.sql
-- 公司環境請改用：
--     sqlcmd -S localhost\SQLEXPRESS -E -i seed.sql
-- ============================================================

-- 建立資料庫（不存在才建）
IF DB_ID('learning_db') IS NULL
	CREATE DATABASE learning_db;
GO
USE learning_db;
GO

-- 刪除舊資料表（由外而內，注意：2014 沒有 DROP ... IF EXISTS，要用 OBJECT_ID）
IF OBJECT_ID('dbo.OrderDetails', 'U') IS NOT NULL DROP TABLE dbo.OrderDetails;
IF OBJECT_ID('dbo.Orders',       'U') IS NOT NULL DROP TABLE dbo.Orders;
IF OBJECT_ID('dbo.Products',     'U') IS NOT NULL DROP TABLE dbo.Products;
IF OBJECT_ID('dbo.Customers',    'U') IS NOT NULL DROP TABLE dbo.Customers;
IF OBJECT_ID('dbo.Employees',    'U') IS NOT NULL DROP TABLE dbo.Employees;
IF OBJECT_ID('dbo.Departments',  'U') IS NOT NULL DROP TABLE dbo.Departments;
GO

-- --------------------- 資料表 ---------------------

CREATE TABLE dbo.Departments (
	DepartmentID   INT IDENTITY(1,1) PRIMARY KEY,
	DepartmentName NVARCHAR(50) NOT NULL
);

CREATE TABLE dbo.Employees (
	EmployeeID     INT IDENTITY(1,1) PRIMARY KEY,
	LastName       NVARCHAR(50) NOT NULL,
	FirstName      NVARCHAR(50) NOT NULL,
	DepartmentID   INT NULL REFERENCES dbo.Departments(DepartmentID),
	HireDate       DATE NOT NULL
);

CREATE TABLE dbo.Customers (
	CustomerID     INT IDENTITY(1,1) PRIMARY KEY,
	CompanyName    NVARCHAR(100) NOT NULL,
	ContactName    NVARCHAR(100) NULL,	-- 部分客戶沒填（練 NULL 用）
	Phone          NVARCHAR(25) NULL,	-- 部分客戶沒電話（練 IS NULL 用）
	City           NVARCHAR(50) NULL
);

CREATE TABLE dbo.Products (
	ProductID      INT IDENTITY(1,1) PRIMARY KEY,
	ProductName    NVARCHAR(100) NOT NULL,
	Category       NVARCHAR(50) NOT NULL,
	UnitPrice      DECIMAL(10,2) NOT NULL,
	Discontinued   BIT NOT NULL DEFAULT 0
);

CREATE TABLE dbo.Orders (
	OrderID        INT IDENTITY(1,1) PRIMARY KEY,
	CustomerID     INT NOT NULL REFERENCES dbo.Customers(CustomerID),
	EmployeeID     INT NULL REFERENCES dbo.Employees(EmployeeID),	-- 可為 NULL：接單員工已離職
	OrderDate      DATE NOT NULL,
	ShipFee        DECIMAL(10,2) NULL
);

CREATE TABLE dbo.OrderDetails (
	OrderDetailID  INT IDENTITY(1,1) PRIMARY KEY,
	OrderID        INT NOT NULL REFERENCES dbo.Orders(OrderID),
	ProductID      INT NOT NULL REFERENCES dbo.Products(ProductID),
	Quantity       INT NOT NULL,
	UnitPrice      DECIMAL(10,2) NOT NULL	-- 成交價，刻意與 Products.UnitPrice 不同，練習時注意
);
GO

-- --------------------- 資料 ---------------------

INSERT INTO dbo.Departments (DepartmentName) VALUES
	(N'業務部'),
	(N'客服部'),
	(N'資訊部'),
	(N'財務部');
GO

-- 8 名員工；DepartmentID 為 NULL 的是借調人員（LEFT JOIN 練習用）
INSERT INTO dbo.Employees (LastName, FirstName, DepartmentID, HireDate) VALUES
	(N'陳', N'大明', 1, '2010-03-15'),
	(N'林', N'小芳', 1, '2012-07-01'),
	(N'黃', N'志強', 2, '2011-11-20'),
	(N'吳', N'雅婷', 2, '2014-02-10'),
	(N'張', N'俊傑', 3, '2013-06-17'),
	(N'劉', N'美玲', 4, '2009-09-09'),
	(N'王', N'建國', NULL, '2014-08-01'),
	(N'李', N'惠雯', 1, '2013-12-01');
GO

-- 12 家客戶；第 11、12 家從未下單（LEFT JOIN 練習用）
-- 部分 ContactName / Phone 為 NULL（IS NULL 練習用）
INSERT INTO dbo.Customers (CompanyName, ContactName, Phone, City) VALUES
	(N'阿里巴巴貿易', N'胡經理', N'02-2345-6789', N'台北'),
	(N'貝塔科技',     N'錢主任', N'03-555-1234', N'新竹'),
	(N'藍鵡食品',     N'孫小姐', N'07-888-2222', N'高雄'),
	(N'大同工廠',     N'周廠長', N'02-2999-1010', N'台北'),
	(N'飛鷹物流',     N'吳司機', N'04-2222-3333', N'台中'),
	(N'高雄五金',     NULL,      N'07-333-4444', N'高雄'),
	(N'晨光文具',     N'鄭老闆', NULL,           N'台中'),
	(N'星河電子',     N'馮工程師', N'03-666-7777', N'新竹'),
	(N'台北咖啡坊',   N'韓店長', N'02-2777-8888', N'台北'),
	(N'台中機械',     N'曹襄理', N'04-555-6666', N'台中'),
	(N'新竹生技',     NULL,      NULL,           N'新竹'),
	(N'高雄運通',     N'許課長', N'07-999-0000', N'高雄');
GO

-- 12 項產品；「進口耳機」已停產（Discontinued = 1）
INSERT INTO dbo.Products (ProductName, Category, UnitPrice, Discontinued) VALUES
	(N'鐵觀音茶葉', N'飲料', 350.00, 0),
	(N'柳橙汁',     N'飲料',  45.00, 0),
	(N'蜂蜜',       N'飲料', 280.00, 0),
	(N'洋芋片',     N'零食',  35.00, 0),
	(N'花生',       N'零食',  60.00, 0),
	(N'巧克力',     N'零食', 120.00, 0),
	(N'圓珠筆',     N'文具',  15.00, 0),
	(N'筆記本',     N'文具',  40.00, 0),
	(N'印表機耗材', N'文具', 890.00, 0),
	(N'滑鼠',       N'電子', 250.00, 0),
	(N'鍵盤',       N'電子', 480.00, 0),
	(N'進口耳機',   N'電子', 1200.00, 1);
GO

-- 訂單：前 16 筆為歷史資料（2014 年），後 4 筆用 GETDATE() 動態產生「最近的訂單」，
-- 讓「近 30 天訂單」這類日期練習有資料可查。
-- EmployeeID 有一筆 NULL：接單人離職後被刪掉的場景
INSERT INTO dbo.Orders (CustomerID, EmployeeID, OrderDate, ShipFee) VALUES
	(1,  1, '2014-01-15', 120.00),
	(2,  1, '2014-02-20', 80.00),
	(3,  2, '2014-03-08', NULL),
	(1,  8, '2014-04-01', 200.00),
	(4,  2, '2014-05-19', 150.00),
	(5,  NULL, '2014-06-30', 90.00),
	(6,  1, '2014-07-12', NULL),
	(7,  8, '2014-08-05', 60.00),
	(8,  2, '2014-09-17', 180.00),
	(9,  1, '2014-10-02', 100.00),
	(10, 8, '2014-10-25', NULL),
	(3,  2, '2014-11-11', 75.00),
	(5,  1, '2014-11-28', 130.00),
	(1,  8, '2014-12-05', 95.00),
	(8,  NULL, '2014-12-19', 210.00),
	(4,  2, '2014-12-30', NULL),
	-- 最近的訂單（動態日期）
	(2,  1, DATEADD(DAY, -3,  GETDATE()),  80.00),
	(5,  2, DATEADD(DAY, -10, GETDATE()), 110.00),
	(9,  8, DATEADD(DAY, -25, GETDATE()),  NULL),
	(1,  1, DATEADD(DAY, -40, GETDATE()), 160.00);
GO

-- 訂單明細：UnitPrice 與 Products.UnitPrice 不同（模擬歷史成交價）
INSERT INTO dbo.OrderDetails (OrderID, ProductID, Quantity, UnitPrice) VALUES
	(1, 1,  2, 320.00),
	(1, 4, 10,  30.00),
	(2, 10, 3, 230.00),
	(3, 2, 24,  40.00),
	(4, 9,  1, 850.00),
	(4, 7, 20,  12.00),
	(5, 3,  4, 260.00),
	(6, 11, 2, 450.00),
	(7, 4,  6,  35.00),
	(7, 5,  3,  55.00),
	(8, 8, 15,  38.00),
	(9, 12, 1, 1100.00),
	(9, 10, 2, 240.00),
	(10, 1, 1, 350.00),
	(11, 6, 8, 110.00),
	(12, 2, 12, 42.00),
	(13, 9, 2, 870.00),
	(14, 7, 30, 13.00),
	(14, 8, 5, 38.00),
	(15, 11, 1, 480.00),
	(16, 3, 3, 270.00),
	(17, 4, 4, 35.00),
	(17, 6, 2, 120.00),
	(18, 10, 1, 250.00),
	(19, 8, 10, 40.00),
	(20, 1, 5, 330.00),
	(20, 5, 2, 60.00);
GO

PRINT 'seed 完成：learning_db 六張資料表已建立並填入資料。';
GO
