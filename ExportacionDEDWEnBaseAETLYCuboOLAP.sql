SELECT 
    -- 1. IDENTIFICADORES (Tendrás que darles el rol "id" o quitarlos en Altair)
    f.order_id, f.customer_id, f.product_id, f.seller_id,
    
    -- 2. CLIENTE Y GEOGRAFÍA
    c.customer_unique_id, c.customer_city AS Ciudad_Cliente, c.customer_state AS Estado_Cliente, c.customer_zip_code_prefix,
    
    -- 3. VENDEDOR
    v.seller_city AS Ciudad_Vendedor, v.seller_state AS Estado_Vendedor,
    
    -- 4. PRODUCTO
    p.Categoria, p.Peso_g, p.Largo_cm, p.Alto_cm, p.Ancho_cm,
    
    -- 5. TIEMPO (Fechas desglosadas)
    f.Fecha_ID, t.Anio, t.Mes, t.Dia,
    
    -- 6. PAGOS (Agrupados por orden)
    pg.Tipo_Pago, pg.Cuotas, pg.Valor_Pago,
    
    -- 7. RESEÑAS
    r.Calificacion,
    
    -- 8. VENTAS Y LOGÍSTICA
    f.Estado_Pedido, f.Precio_Producto, f.Valor_Flete, f.Monto_Total_Linea, 
    f.Dias_Despacho_Vendedor, f.Dias_Total_Entrega, f.Es_Entrega_Tardia

FROM (
    -- FACT PRINCIPAL
    SELECT oi.order_id, oi.product_id, oi.seller_id, o.customer_id, CAST(o.order_purchase_timestamp AS DATE) AS Fecha_ID, 
           o.order_status AS Estado_Pedido, oi.price AS Precio_Producto, oi.freight_value AS Valor_Flete, 
           oi.price + oi.freight_value AS Monto_Total_Linea, 
           DATEDIFF([DAY], o.order_purchase_timestamp, o.order_delivered_carrier_date) AS Dias_Despacho_Vendedor, 
           DATEDIFF([DAY], o.order_purchase_timestamp, o.order_delivered_customer_date) AS Dias_Total_Entrega, 
           CASE WHEN o.order_delivered_customer_date > o.order_estimated_delivery_date THEN 1 ELSE 0 END AS Es_Entrega_Tardia
    FROM OrderItems AS oi INNER JOIN Orders AS o ON oi.order_id = o.order_id
) AS f

-- JOIN CLIENTES
LEFT JOIN Customers AS c ON f.customer_id = c.customer_id

-- JOIN PRODUCTOS
LEFT JOIN (
    SELECT p.product_id, ISNULL(t.product_category_name_english, N'Unknown Category') AS Categoria, 
           p.product_weight_g AS Peso_g, p.product_length_cm AS Largo_cm, p.product_height_cm AS Alto_cm, p.product_width_cm AS Ancho_cm
    FROM Products AS p LEFT JOIN ProductCategoryTranslation AS t ON p.product_category_name = t.product_category_name
) AS p ON f.product_id = p.product_id

-- JOIN TIEMPO
LEFT JOIN (
    SELECT DISTINCT CAST(order_purchase_timestamp AS DATE) AS Fecha_ID, YEAR(order_purchase_timestamp) AS Anio, MONTH(order_purchase_timestamp) AS Mes, DAY(order_purchase_timestamp) AS Dia
    FROM Orders WHERE order_purchase_timestamp IS NOT NULL
) AS t ON f.Fecha_ID = t.Fecha_ID

-- JOIN VENDEDORES
LEFT JOIN Sellers AS v ON f.seller_id = v.seller_id

-- JOIN PAGOS (Protegido contra duplicados con MAX y SUM)
LEFT JOIN (
    SELECT order_id, MAX(payment_type) AS Tipo_Pago, MAX(payment_installments) AS Cuotas, SUM(payment_value) AS Valor_Pago
    FROM OrderPayments GROUP BY order_id
) AS pg ON f.order_id = pg.order_id

-- JOIN RESEÑAS
LEFT JOIN (
    SELECT order_id, AVG(CAST(review_score AS FLOAT)) AS Calificacion
    FROM OrderReviews GROUP BY order_id
) AS r ON f.order_id = r.order_id;