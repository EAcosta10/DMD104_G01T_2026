/* ============================================================
   BASE DE DATOS DESTINO - OLIST BRAZILIAN E-COMMERCE - Proyecto ETL

   Base de datos destinada a almacenar la información procesada
   mediante un proceso ETL a partir de los archivos CSV de Olist. 
   ============================================================ */


/* ============================================================
   1. CREAR BASE DE DATOS
   ============================================================ */

IF DB_ID('OlistDW') IS NULL
BEGIN
    CREATE DATABASE OlistDW;
END
GO

USE OlistDW;
GO


/* ============================================================
   2. TABLA CUSTOMERS
   Fuente: olist_customers_dataset.csv
   
   Uso: Esta tabla almacena la información de los clientes.

   customer_id: Es el identificador utilizado por Olist para relacionar
   al cliente con sus pedidos.

   customer_unique_id: Identifica de manera única al cliente y puede aparecer
   asociado a diferentes customer_id.

   VARCHAR(32): Los identificadores originales de Olist son cadenas de
   caracteres de 32 posiciones, no números.

   CHAR(5): El código postal tiene 5 caracteres. Se utiliza CHAR
   porque todos los códigos tienen la misma longitud.

   NVARCHAR: Se utiliza para ciudades porque permite almacenar
   caracteres especiales y nombres con acentos.
   ============================================================ */

CREATE TABLE dbo.Customers
(
    customer_id VARCHAR(32) NOT NULL,
    customer_unique_id VARCHAR(32) NOT NULL,

    -- Se mantiene como texto para no perder ceros iniciales.
    customer_zip_code_prefix CHAR(5) NOT NULL,

    -- NVARCHAR permite caracteres especiales y acentos.
    customer_city NVARCHAR(100) NOT NULL,

    -- Los estados brasileños utilizan abreviaturas de 2 caracteres.
    customer_state CHAR(2) NOT NULL,

    CONSTRAINT PK_Customers
        PRIMARY KEY (customer_id)
);
GO


/* ============================================================
   3. TABLA GEOLOCATION
   Fuente: olist_geolocation_dataset.csv

   Uso: Esta tabla contiene información geográfica relacionada
   con los códigos postales.

   IMPORTANTE:
   No le coloque PRIMARY KEY porque un mismo código postal
   puede aparecer múltiples veces con diferentes coordenadas y de hecho en los datos asi aparece.

   DECIMAL(18,16): Se utiliza para conservar precisión suficiente en las
   coordenadas de latitud y longitud.

   CHAR(5): Se utiliza para conservar los códigos postales tal como
   aparecen en el CSV.
   ============================================================ */

CREATE TABLE dbo.Geolocation
(
    -- Código postal brasileño.
    geolocation_zip_code_prefix CHAR(5) NOT NULL,

    -- Coordenadas geográficas.
    -- 7 decimales permiten conservar bastante precisión.
    geolocation_lat DECIMAL(18,16) NOT NULL,
    geolocation_lng DECIMAL(18,16) NOT NULL,

    -- Nombre de la ciudad.
    geolocation_city NVARCHAR(100) NOT NULL,

    -- Estado brasileño de dos caracteres.
    geolocation_state CHAR(2) NOT NULL
);
GO


/* ============================================================
   4. TABLA ORDERS
   Fuente: olist_orders_dataset.csv

   Uso: Esta tabla almacena la información general de cada pedido.

   order_id: Identificador único del pedido.

   customer_id: Identifica al cliente que realizó el pedido.

   order_status: Guarda estados como: delivered, shipped, canceled, invoiced, etc.
   Segun los datos de los csv

   VARCHAR(20): Es suficiente para los estados presentes en el dataset.

   DATETIME2(0): Se utiliza para las fechas y horas del pedido.
   Lo utilice porque permite almacenar fechas con precisión.

   NULL: Algunas fechas pueden estar vacías en el CSV dependiendo
   del estado del pedido.

   Por ejemplo, un pedido cancelado puede no tener fecha
   de entrega al cliente.
   ============================================================ */

CREATE TABLE dbo.Orders
(
    order_id VARCHAR(32) NOT NULL,

    -- Cliente relacionado con el pedido.
    customer_id VARCHAR(32) NOT NULL,

    -- Estado actual del pedido.
    order_status  VARCHAR(20) NOT NULL,

    -- Fechas importantes del proceso del pedido.
    order_purchase_timestamp DATETIME2(0) NOT NULL,
    order_approved_at DATETIME2(0) NULL,
    order_delivered_carrier_date  DATETIME2(0) NULL,
    order_delivered_customer_date DATETIME2(0) NULL,
    order_estimated_delivery_date DATETIME2(0) NULL,

    CONSTRAINT PK_Orders
        PRIMARY KEY (order_id),

    CONSTRAINT FK_Orders_Customers
        FOREIGN KEY (customer_id)
        REFERENCES dbo.Customers(customer_id)
);
GO


/* ============================================================
   5. TABLA PRODUCTS
   Fuente: olist_products_dataset.csv

   Uso: Contiene la información de los productos vendidos.

   product_id: Identificador único del producto.

   product_category_name: Categoría original del producto.

   Nota: Los campos de longitud, fotografías, peso y dimensiones
   utilizan INT porque son cantidades numéricas enteras.
   Se permite NULL porque el dataset contiene valores faltantes
   en algunas características de los productos.

   NVARCHAR: La categoría puede contener caracteres especiales.
   ============================================================ */

CREATE TABLE dbo.Products
(
    product_id VARCHAR(32) NOT NULL,

    -- Categoría original del producto.
    -- Puede ser NULL porque existen registros sin categoría.
    product_category_name NVARCHAR(100) NULL,

    -- Características descriptivas del producto.
    product_name_lenght INT NULL,
    product_description_lenght INT NULL,
    product_photos_qty INT NULL,

    -- Características físicas del producto.
    -- Se almacenan como enteros porque el dataset utiliza
    -- valores enteros para estas medidas.
    product_weight_g INT NULL,
    product_length_cm INT NULL,
    product_height_cm INT NULL,
    product_width_cm  INT NULL,

    CONSTRAINT PK_Products
        PRIMARY KEY (product_id)
);
GO


/* ============================================================
   6. TABLA SELLERS
   Fuente: olist_sellers_dataset.csv

   Uso: Contiene la información de los vendedores.

   seller_id: Identificador único del vendedor.

   seller_zip_code_prefix: Código postal del vendedor.

   Se utiliza CHAR(5) para mantener posibles ceros iniciales.

   seller_state: Código de dos caracteres correspondiente al estado.
   ============================================================ */

CREATE TABLE dbo.Sellers
(
    seller_id VARCHAR(32) NOT NULL,

    -- Código postal del vendedor.
    seller_zip_code_prefix CHAR(5) NOT NULL,

    -- Ubicación del vendedor.
    seller_city NVARCHAR(100) NOT NULL,
    seller_state CHAR(2) NOT NULL,

    CONSTRAINT PK_Sellers
        PRIMARY KEY (seller_id)
);
GO


/* ============================================================
   7. TABLA ORDER ITEMS
   Fuente:
   olist_order_items_dataset.csv

   Uso: Esta tabla almacena los productos que forman parte
   de cada pedido.

   Nota: Un pedido puede contener varios productos.
   Por eso se utilizamos una CLAVE COMPUESTA:
       order_id + order_item_id

   order_id: Identifica el pedido.

   order_item_id: Identifica la posición del producto dentro del pedido.

   product_id: Identifica el producto vendido.

   seller_id: Identifica el vendedor que realizó la venta.

   price: Precio del producto.

   freight_value: Valor del flete/envío.

   DECIMAL(18,2): Se utiliza para valores monetarios porque necesitamos
   almacenar decimales correctamente.

   No usamos FLOAT para dinero porque puede producir
   pequeñas diferencias de precisión.
   ============================================================ */

CREATE TABLE dbo.OrderItems
(
    order_id VARCHAR(32) NOT NULL,

    -- Número del artículo dentro del pedido.
    order_item_id INT NOT NULL,

    -- Producto y vendedor relacionados.
    product_id VARCHAR(32) NOT NULL,
    seller_id  VARCHAR(32) NOT NULL,

    -- Fecha límite para el envío.
    shipping_limit_date DATETIME2(0) NOT NULL,

    -- Valores monetarios.
    price DECIMAL(18,2) NOT NULL,
    freight_value DECIMAL(18,2) NOT NULL,

    CONSTRAINT PK_OrderItems
        PRIMARY KEY (order_id, order_item_id),

    /* ========================================================
       FK 1 - Relaciona el artículo con su pedido.
       ======================================================== */

    CONSTRAINT FK_OrderItems_Orders
        FOREIGN KEY (order_id)
        REFERENCES dbo.Orders(order_id),

    /* ========================================================
       FK 2 - Relaciona el artículo con el producto.
       ======================================================== */

    CONSTRAINT FK_OrderItems_Products
        FOREIGN KEY (product_id)
        REFERENCES dbo.Products(product_id),

    /* ========================================================
       FK 3 - Relaciona el artículo con el vendedor.
       ======================================================== */

    CONSTRAINT FK_OrderItems_Sellers
        FOREIGN KEY (seller_id)
        REFERENCES dbo.Sellers(seller_id)
);
GO


/* ============================================================
   8. TABLA ORDER PAYMENTS
   Fuente: olist_order_payments_dataset.csv

   Uso: Almacena la información de los pagos realizados
   para cada pedido.

   Nota: Un pedido puede tener varios registros de pago.
   Por eso la clave primaria es:
       order_id + payment_sequential

   payment_type: Tipo de pago utilizado.

   payment_installments: Número de cuotas.

   payment_value: Valor del pago.

   DECIMAL(18,2): Se utiliza porque payment_value representa dinero.
   ============================================================ */

CREATE TABLE dbo.OrderPayments
(
    order_id VARCHAR(32) NOT NULL,

    -- Secuencia del pago dentro del pedido.
    payment_sequential INT NOT NULL,

    -- Información del método de pago.
    payment_type VARCHAR(20) NOT NULL,

    -- Cantidad de cuotas.
    payment_installments INT NOT NULL,

    -- Valor monetario del pago.
    payment_value DECIMAL(18,2) NOT NULL,

    CONSTRAINT PK_OrderPayments
        PRIMARY KEY (order_id, payment_sequential),

    /* ========================================================
       Relación entre pagos y pedidos.
       ======================================================== */

    CONSTRAINT FK_OrderPayments_Orders
        FOREIGN KEY (order_id)
        REFERENCES dbo.Orders(order_id)
);
GO


/* ============================================================
   9. TABLA ORDER REVIEWS
   Fuente: olist_order_reviews_dataset.csv

   Uso: Contiene las opiniones realizadas por los clientes
   después de sus pedidos.

   review_score: Calificación otorgada por el cliente.
   Se utiliza TINYINT porque la calificación solamente
   necesita valores pequeños, específicamente del 1 al 5.

   review_comment_title: Título del comentario.

   review_comment_message: Mensaje completo del comentario.

   NVARCHAR: Se utiliza porque los comentarios pueden contener
   caracteres especiales.

   NVARCHAR(MAX): Se utiliza para el mensaje porque puede ser bastante
   más largo que un VARCHAR convencional.

   CHECK: Se utiliza para impedir que se introduzca una calificación
   fuera del rango válido de 1 a 5.
   ============================================================ */

CREATE TABLE dbo.OrderReviews
(
    review_id VARCHAR(32) NOT NULL,
    order_id  VARCHAR(32) NOT NULL,

    -- Calificación del cliente.
    review_score TINYINT NOT NULL,

    -- Comentarios escritos por el cliente.
    review_comment_title   NVARCHAR(500) NULL,
    review_comment_message NVARCHAR(MAX) NULL,

    -- Fechas de creación y respuesta de la review.
    review_creation_date    DATETIME2(0) NOT NULL,
    review_answer_timestamp DATETIME2(0) NOT NULL,

    /* ========================================================
       La combinación review_id + order_id permite identificar
       el registro de review conservando la estructura original.
       ======================================================== */

    CONSTRAINT PK_OrderReviews
        PRIMARY KEY (review_id, order_id),

    /* ========================================================
       Relación entre la review y el pedido.
       ======================================================== */

    CONSTRAINT FK_OrderReviews_Orders
        FOREIGN KEY (order_id)
        REFERENCES dbo.Orders(order_id),

    /* ========================================================
       Validación de la calificación.

       Solo se permiten valores entre 1 y 5.
       ======================================================== */

    CONSTRAINT CK_OrderReviews_Score
        CHECK (review_score BETWEEN 1 AND 5)
);
GO


/* ============================================================
   10. TABLA PRODUCT CATEGORY TRANSLATION
   Fuente: product_category_name_translation.csv

   Uso: Esta tabla permite relacionar el nombre original de una
   categoría en portugués con su traducción al inglés.

   Ejemplo:
       product_category_name
       -------------------------
       beleza_saude

       product_category_name_english
       ------------------------------
       health_beauty

   NVARCHAR: Se utiliza porque las categorías pueden contener caracteres
   especiales.

   La categoría original funciona como PRIMARY KEY porque
   cada categoría aparece una vez en este archivo de traducción.
   ============================================================ */

CREATE TABLE dbo.ProductCategoryTranslation
(
    -- Nombre original de la categoría.
    product_category_name NVARCHAR(100) NOT NULL,

    -- Traducción de la categoría al inglés.
    product_category_name_english NVARCHAR(100) NOT NULL,

    CONSTRAINT PK_ProductCategoryTranslation
        PRIMARY KEY (product_category_name)
);
GO


/* ============================================================
   11. RELACIÓN PRODUCTOS - CATEGORÍAS
   ============================================================

   Se agrega la clave foránea después de crear ambas tablas.

   Esto se hace porque Products depende de
   ProductCategoryTranslation.

   product_category_name en Products:
                ↓
   product_category_name en ProductCategoryTranslation

   De esta manera evitamos categorías que no existan
   en la tabla de traducciones.

   Nota:
   product_category_name permite NULL en Products.
   Por lo tanto, un producto sin categoría puede permanecer
   en la tabla sin violar esta FK.
   ============================================================ */

ALTER TABLE dbo.Products
ADD CONSTRAINT FK_Products_Category
    FOREIGN KEY (product_category_name)
    REFERENCES dbo.ProductCategoryTranslation(product_category_name);
GO


/* ============================================================
   FIN DE LA BASE DE DATOS DESTINO
   ============================================================ */