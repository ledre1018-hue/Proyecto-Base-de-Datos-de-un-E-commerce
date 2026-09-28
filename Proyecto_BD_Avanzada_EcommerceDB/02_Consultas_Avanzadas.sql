-- =============================================================================
-- 02_Consultas_Avanzadas.sql
-- Proyecto: EcommerceDB
-- Autor: Leonel Escalona
-- Descripción: Vistas reutilizables y 20 consultas avanzadas de análisis
-- =============================================================================

USE EcommerceDB;

-- =============================================================================
-- SECCIÓN 1: VISTAS REUTILIZABLES
-- =============================================================================

-- Vista 1: Resumen de clientes (sin datos sensibles como password_hash)
-- Se usa en 04_Seguridad.sql para otorgar permisos al rol Atencion_Cliente
DROP VIEW IF EXISTS vw_clientes_resumen;

CREATE VIEW vw_clientes_resumen AS
SELECT
    c.id_cliente,
    c.nombre,
    c.apellido,
    c.email,
    c.direccion_envio,
    c.ciudad,
    c.region,
    c.fecha_registro,
    COUNT(DISTINCT v.id_venta) AS total_compras,
    COALESCE(SUM(v.total), 0.00) AS total_gastado,
    MAX(v.fecha) AS ultima_compra
FROM clientes c
LEFT JOIN ventas v ON c.id_cliente = v.id_cliente AND v.estado = 'completada'
GROUP BY
    c.id_cliente, c.nombre, c.apellido, c.email,
    c.direccion_envio, c.ciudad, c.region, c.fecha_registro;


-- Vista 2: Catálogo público de productos (para rol Visitante)
-- Oculta información de costos y proveedores
DROP VIEW IF EXISTS vw_catalogo_publico;

CREATE VIEW vw_catalogo_publico AS
SELECT
    p.id_producto,
    p.sku,
    p.nombre,
    p.descripcion,
    p.precio,
    p.stock,
    p.activo,
    cat.nombre AS categoria,
    prov.nombre AS proveedor
FROM productos p
INNER JOIN categorias cat ON p.id_categoria = cat.id_categoria
INNER JOIN proveedores prov ON p.id_proveedor = prov.id_proveedor
WHERE p.activo = 1;


-- =============================================================================
-- SECCIÓN 2: CONSULTAS AVANZADAS DE NEGOCIO
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 1. Top 10 Productos Más Vendidos (por ingresos generados)
-- -----------------------------------------------------------------------------
SELECT
    p.id_producto,
    p.nombre AS producto,
    cat.nombre AS categoria,
    SUM(dv.cantidad) AS unidades_vendidas,
    SUM(dv.subtotal) AS ingresos_totales
FROM detalle_ventas dv
INNER JOIN productos p ON dv.id_producto = p.id_producto
INNER JOIN categorias cat ON p.id_categoria = cat.id_categoria
INNER JOIN ventas v ON dv.id_venta = v.id_venta
WHERE v.estado = 'completada'
GROUP BY p.id_producto, p.nombre, cat.nombre
ORDER BY ingresos_totales DESC
LIMIT 10;


-- -----------------------------------------------------------------------------
-- 2. Productos con Bajas Ventas (10% inferior - candidatos a descontinuación)
-- -----------------------------------------------------------------------------
WITH ventas_producto AS (
    SELECT
        p.id_producto,
        p.nombre,
        COALESCE(SUM(dv.cantidad), 0) AS unidades_vendidas
    FROM productos p
    LEFT JOIN detalle_ventas dv ON p.id_producto = dv.id_producto
    LEFT JOIN ventas v ON dv.id_venta = v.id_venta AND v.estado = 'completada'
    GROUP BY p.id_producto, p.nombre
),
percentil AS (
    SELECT
        id_producto,
        nombre,
        unidades_vendidas,
        PERCENT_RANK() OVER (ORDER BY unidades_vendidas ASC) AS percentil
    FROM ventas_producto
)
SELECT id_producto, nombre, unidades_vendidas, percentil
FROM percentil
WHERE percentil <= 0.10
ORDER BY unidades_vendidas ASC;


-- -----------------------------------------------------------------------------
-- 3. Clientes VIP (Top 5 por valor de vida - LTV)
-- -----------------------------------------------------------------------------
SELECT
    c.id_cliente,
    CONCAT(c.nombre, ' ', c.apellido) AS cliente,
    c.email,
    COUNT(DISTINCT v.id_venta) AS total_compras,
    SUM(v.total) AS ltv
FROM clientes c
INNER JOIN ventas v ON c.id_cliente = v.id_cliente
WHERE v.estado = 'completada'
GROUP BY c.id_cliente, c.nombre, c.apellido, c.email
ORDER BY ltv DESC
LIMIT 5;


-- -----------------------------------------------------------------------------
-- 4. Análisis de Ventas Mensuales (ventas totales por mes y año)
-- -----------------------------------------------------------------------------
SELECT
    YEAR(v.fecha) AS anio,
    MONTH(v.fecha) AS mes,
    COUNT(DISTINCT v.id_venta) AS num_ventas,
    SUM(v.total) AS ventas_totales,
    AVG(v.total) AS ticket_promedio
FROM ventas v
WHERE v.estado = 'completada'
GROUP BY YEAR(v.fecha), MONTH(v.fecha)
ORDER BY anio, mes;


-- -----------------------------------------------------------------------------
-- 5. Crecimiento de Clientes por Trimestre
-- -----------------------------------------------------------------------------
SELECT
    YEAR(c.fecha_registro) AS anio,
    QUARTER(c.fecha_registro) AS trimestre,
    COUNT(*) AS nuevos_clientes
FROM clientes c
GROUP BY YEAR(c.fecha_registro), QUARTER(c.fecha_registro)
ORDER BY anio, trimestre;


-- -----------------------------------------------------------------------------
-- 6. Tasa de Compra Repetida (% de clientes con más de una compra)
-- -----------------------------------------------------------------------------
SELECT
    COUNT(*) AS total_clientes,
    SUM(CASE WHEN num_compras > 1 THEN 1 ELSE 0 END) AS clientes_repetidos,
    ROUND(
        SUM(CASE WHEN num_compras > 1 THEN 1 ELSE 0 END) * 100.0 / COUNT(*),
        2
    ) AS tasa_repetida_porcentaje
FROM (
    SELECT
        c.id_cliente,
        COUNT(DISTINCT v.id_venta) AS num_compras
    FROM clientes c
    LEFT JOIN ventas v ON c.id_cliente = v.id_cliente AND v.estado = 'completada'
    GROUP BY c.id_cliente
) sub;


-- -----------------------------------------------------------------------------
-- 7. Productos Comprados Juntos Frecuentemente
-- -----------------------------------------------------------------------------
SELECT
    p1.nombre AS producto_1,
    p2.nombre AS producto_2,
    COUNT(*) AS veces_comprados_juntos
FROM detalle_ventas dv1
INNER JOIN detalle_ventas dv2
    ON dv1.id_venta = dv2.id_venta AND dv1.id_producto < dv2.id_producto
INNER JOIN productos p1 ON dv1.id_producto = p1.id_producto
INNER JOIN productos p2 ON dv2.id_producto = p2.id_producto
INNER JOIN ventas v ON dv1.id_venta = v.id_venta
WHERE v.estado = 'completada'
GROUP BY p1.nombre, p2.nombre
HAVING COUNT(*) >= 1
ORDER BY veces_comprados_juntos DESC
LIMIT 10;


-- -----------------------------------------------------------------------------
-- 8. Rotación de Inventario por Categoría
-- -----------------------------------------------------------------------------
SELECT
    cat.nombre AS categoria,
    SUM(p.stock) AS stock_actual,
    COALESCE(SUM(dv.cantidad), 0) AS unidades_vendidas,
    CASE
        WHEN SUM(p.stock) > 0
        THEN ROUND(COALESCE(SUM(dv.cantidad), 0) * 1.0 / SUM(p.stock), 2)
        ELSE 0
    END AS tasa_rotacion
FROM categorias cat
LEFT JOIN productos p ON cat.id_categoria = p.id_categoria
LEFT JOIN detalle_ventas dv ON p.id_producto = dv.id_producto
LEFT JOIN ventas v ON dv.id_venta = v.id_venta AND v.estado = 'completada'
GROUP BY cat.id_categoria, cat.nombre
ORDER BY tasa_rotacion DESC;


-- -----------------------------------------------------------------------------
-- 9. Productos que Necesitan Reabastecimiento (stock <= stock_minimo)
-- -----------------------------------------------------------------------------
SELECT
    p.id_producto,
    p.sku,
    p.nombre,
    p.stock,
    p.stock_minimo,
    (p.stock_minimo - p.stock) AS unidades_faltantes,
    cat.nombre AS categoria
FROM productos p
INNER JOIN categorias cat ON p.id_categoria = cat.id_categoria
WHERE p.stock <= p.stock_minimo AND p.activo = 1
ORDER BY (p.stock_minimo - p.stock) DESC;


-- -----------------------------------------------------------------------------
-- 10. Análisis de Carrito Abandonado (ventas pendientes sin completar)
-- -----------------------------------------------------------------------------
SELECT
    v.id_venta,
    v.fecha,
    CONCAT(c.nombre, ' ', c.apellido) AS cliente,
    c.email,
    v.total AS valor_carrito,
    DATEDIFF(CURRENT_DATE, v.fecha) AS dias_abandonado
FROM ventas v
INNER JOIN clientes c ON v.id_cliente = c.id_cliente
WHERE v.estado = 'pendiente'
ORDER BY v.fecha ASC;


-- -----------------------------------------------------------------------------
-- 11. Rendimiento de Proveedores (por volumen de ventas)
-- -----------------------------------------------------------------------------
SELECT
    prov.id_proveedor,
    prov.nombre AS proveedor,
    COUNT(DISTINCT p.id_producto) AS productos_vendidos,
    SUM(dv.cantidad) AS unidades_totales,
    SUM(dv.subtotal) AS ingresos_generados
FROM proveedores prov
INNER JOIN productos p ON prov.id_proveedor = p.id_proveedor
INNER JOIN detalle_ventas dv ON p.id_producto = dv.id_producto
INNER JOIN ventas v ON dv.id_venta = v.id_venta AND v.estado = 'completada'
GROUP BY prov.id_proveedor, prov.nombre
ORDER BY ingresos_generados DESC;


-- -----------------------------------------------------------------------------
-- 12. Análisis Geográfico de Ventas (por ciudad/región del cliente)
-- -----------------------------------------------------------------------------
SELECT
    COALESCE(c.ciudad, 'Sin ciudad') AS ciudad,
    COALESCE(c.region, 'Sin región') AS region,
    COUNT(DISTINCT v.id_venta) AS num_ventas,
    SUM(v.total) AS ventas_totales
FROM clientes c
INNER JOIN ventas v ON c.id_cliente = v.id_cliente
WHERE v.estado = 'completada'
GROUP BY c.ciudad, c.region
ORDER BY ventas_totales DESC;


-- -----------------------------------------------------------------------------
-- 13. Ventas por Hora del Día (identificar horas pico)
-- -----------------------------------------------------------------------------
SELECT
    HOUR(v.fecha) AS hora,
    COUNT(DISTINCT v.id_venta) AS num_ventas,
    SUM(v.total) AS ventas_totales
FROM ventas v
WHERE v.estado = 'completada'
GROUP BY HOUR(v.fecha)
ORDER BY hora;


-- -----------------------------------------------------------------------------
-- 14. Comparación de Ventas por Período (simulación de impacto de promociones)
-- -----------------------------------------------------------------------------
-- Compara ventas del primer mes vs segundo mes de los datos
SELECT
    CASE
        WHEN MONTH(v.fecha) <= (SELECT MIN(MONTH(fecha)) FROM ventas WHERE estado='completada') + 1
        THEN 'Período 1 (Antes)'
        ELSE 'Período 2 (Después)'
    END AS periodo,
    COUNT(DISTINCT v.id_venta) AS num_ventas,
    SUM(v.total) AS ventas_totales,
    AVG(v.total) AS ticket_promedio
FROM ventas v
WHERE v.estado = 'completada'
GROUP BY periodo
ORDER BY periodo;


-- -----------------------------------------------------------------------------
-- 15. Análisis de Cohort (retención de clientes desde su primera compra)
-- -----------------------------------------------------------------------------
WITH primera_compra AS (
    SELECT
        id_cliente,
        MIN(fecha) AS fecha_primera_compra
    FROM ventas
    WHERE estado = 'completada'
    GROUP BY id_cliente
),
cohortes AS (
    SELECT
        pc.id_cliente,
        DATE_FORMAT(pc.fecha_primera_compra, '%Y-%m') AS mes_cohorte,
        DATE_FORMAT(v.fecha, '%Y-%m') AS mes_compra,
        TIMESTAMPDIFF(MONTH, pc.fecha_primera_compra, v.fecha) AS mes_numero
    FROM primera_compra pc
    INNER JOIN ventas v ON pc.id_cliente = v.id_cliente
    WHERE v.estado = 'completada'
)
SELECT
    mes_cohorte,
    mes_numero,
    COUNT(DISTINCT id_cliente) AS clientes_activos
FROM cohortes
GROUP BY mes_cohorte, mes_numero
ORDER BY mes_cohorte, mes_numero;


-- -----------------------------------------------------------------------------
-- 16. Margen de Beneficio por Producto
-- -----------------------------------------------------------------------------
SELECT
    p.id_producto,
    p.nombre,
    p.costo,
    p.precio,
    ROUND((p.precio - p.costo), 2) AS margen_unitario,
    ROUND(((p.precio - p.costo) / NULLIF(p.precio, 0)) * 100, 2) AS margen_porcentaje,
    COALESCE(SUM(dv.cantidad), 0) AS unidades_vendidas,
    ROUND(SUM(dv.cantidad) * (p.precio - p.costo), 2) AS beneficio_total
FROM productos p
LEFT JOIN detalle_ventas dv ON p.id_producto = dv.id_producto
LEFT JOIN ventas v ON dv.id_venta = v.id_venta AND v.estado = 'completada'
GROUP BY p.id_producto, p.nombre, p.costo, p.precio
ORDER BY beneficio_total DESC;


-- -----------------------------------------------------------------------------
-- 17. Tiempo Promedio Entre Compras por Cliente
-- -----------------------------------------------------------------------------
SELECT
    c.id_cliente,
    CONCAT(c.nombre, ' ', c.apellido) AS cliente,
    COUNT(DISTINCT v.id_venta) AS num_compras,
    MIN(v.fecha) AS primera_compra,
    MAX(v.fecha) AS ultima_compra,
    CASE
        WHEN COUNT(DISTINCT v.id_venta) > 1
        THEN ROUND(
            DATEDIFF(MAX(v.fecha), MIN(v.fecha)) * 1.0 /
            NULLIF(COUNT(DISTINCT v.id_venta) - 1, 0),
            1
        )
        ELSE NULL
    END AS dias_promedio_entre_compras
FROM clientes c
INNER JOIN ventas v ON c.id_cliente = v.id_cliente
WHERE v.estado = 'completada'
GROUP BY c.id_cliente, c.nombre, c.apellido
HAVING COUNT(DISTINCT v.id_venta) > 1
ORDER BY dias_promedio_entre_compras ASC;


-- -----------------------------------------------------------------------------
-- 18. Productos Más Vendidos vs. Menos Vendidos (comparación)
-- -----------------------------------------------------------------------------
-- Simula "vistos vs comprados" comparando productos en historial_precios (interés)
-- vs productos en detalle_ventas (compra real)
SELECT
    p.id_producto,
    p.nombre,
    COALESCE(hp.num_cambios, 0) AS veces_en_historial,
    COALESCE(dv.unidades_vendidas, 0) AS unidades_vendidas,
    CASE
        WHEN COALESCE(dv.unidades_vendidas, 0) > 0 THEN 'Alta conversión'
        WHEN COALESCE(hp.num_cambios, 0) > 0 THEN 'Baja conversión'
        ELSE 'Sin actividad'
    END AS estado_conversion
FROM productos p
LEFT JOIN (
    SELECT id_producto, COUNT(*) AS num_cambios
    FROM historial_precios
    GROUP BY id_producto
) hp ON p.id_producto = hp.id_producto
LEFT JOIN (
    SELECT dv2.id_producto, SUM(dv2.cantidad) AS unidades_vendidas
    FROM detalle_ventas dv2
    INNER JOIN ventas v2 ON dv2.id_venta = v2.id_venta AND v2.estado = 'completada'
    GROUP BY dv2.id_producto
) dv ON p.id_producto = dv.id_producto
ORDER BY unidades_vendidas DESC, veces_en_historial DESC;


-- -----------------------------------------------------------------------------
-- 19. Segmentación de Clientes RFM (Recencia, Frecuencia, Monetario)
-- -----------------------------------------------------------------------------
WITH rfm_base AS (
    SELECT
        c.id_cliente,
        CONCAT(c.nombre, ' ', c.apellido) AS cliente,
        DATEDIFF(CURRENT_DATE, MAX(v.fecha)) AS recencia,
        COUNT(DISTINCT v.id_venta) AS frecuencia,
        SUM(v.total) AS monetario
    FROM clientes c
    INNER JOIN ventas v ON c.id_cliente = v.id_cliente
    WHERE v.estado = 'completada'
    GROUP BY c.id_cliente, c.nombre, c.apellido
),
rfm_scores AS (
    SELECT
        id_cliente,
        cliente,
        recencia,
        frecuencia,
        monetario,
        NTILE(3) OVER (ORDER BY recencia DESC) AS r_score,
        NTILE(3) OVER (ORDER BY frecuencia ASC) AS f_score,
        NTILE(3) OVER (ORDER BY monetario ASC) AS m_score
    FROM rfm_base
)
SELECT
    id_cliente,
    cliente,
    recencia,
    frecuencia,
    monetario,
    CONCAT('R', r_score, '-F', f_score, '-M', m_score) AS segmento_rfm,
    CASE
        WHEN r_score = 3 AND f_score = 3 AND m_score = 3 THEN 'Campeones'
        WHEN r_score >= 2 AND f_score >= 2 AND m_score >= 2 THEN 'Leales'
        WHEN r_score = 3 AND f_score <= 2 THEN 'Nuevos'
        WHEN r_score = 1 AND f_score >= 2 THEN 'En riesgo'
        ELSE 'Dormidos'
    END AS categoria
FROM rfm_scores
ORDER BY monetario DESC;


-- -----------------------------------------------------------------------------
-- 20. Predicción Simple de Demanda (promedio mensual por categoría)
-- -----------------------------------------------------------------------------
WITH ventas_mensuales_cat AS (
    SELECT
        cat.id_categoria,
        cat.nombre AS categoria,
        YEAR(v.fecha) AS anio,
        MONTH(v.fecha) AS mes,
        SUM(dv.cantidad) AS unidades_vendidas
    FROM categorias cat
    INNER JOIN productos p ON cat.id_categoria = p.id_categoria
    INNER JOIN detalle_ventas dv ON p.id_producto = dv.id_producto
    INNER JOIN ventas v ON dv.id_venta = v.id_venta AND v.estado = 'completada'
    GROUP BY cat.id_categoria, cat.nombre, YEAR(v.fecha), MONTH(v.fecha)
),
promedio_categoria AS (
    SELECT
        id_categoria,
        categoria,
        ROUND(AVG(unidades_vendidas), 2) AS promedio_mensual,
        ROUND(STDDEV(unidades_vendidas), 2) AS desviacion_estandar
    FROM ventas_mensuales_cat
    GROUP BY id_categoria, categoria
)
SELECT
    categoria,
    promedio_mensual AS demanda_promedio_mensual,
    desviacion_estandar,
    ROUND(promedio_mensual * 1.10, 2) AS prediccion_proximo_mes_10,
    ROUND(promedio_mensual * 1.20, 2) AS prediccion_proximo_mes_20
FROM promedio_categoria
ORDER BY demanda_promedio_mensual DESC;


-- =============================================================================
-- FIN DEL ARCHIVO 02_Consultas_Avanzadas.sql
-- =============================================================================
