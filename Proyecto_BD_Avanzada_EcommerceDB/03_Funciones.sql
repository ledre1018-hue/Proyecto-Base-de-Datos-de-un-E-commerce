-- =============================================================================
-- 03_Funciones.sql
-- Proyecto: EcommerceDB
-- Autor: Leonel Escalona
-- Descripción: 20 funciones definidas por el usuario (UDF)
-- =============================================================================

USE EcommerceDB;

-- =============================================================================
-- GRUPO 1: Funciones de cálculo monetario
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 1. fn_CalcularTotalVenta
-- Calcula el monto total de una venta específica sumando los subtotales
-- de sus líneas de detalle.
-- -----------------------------------------------------------------------------
DROP FUNCTION IF EXISTS fn_CalcularTotalVenta;

DELIMITER //

CREATE FUNCTION fn_CalcularTotalVenta(p_id_venta INT)
RETURNS DECIMAL(14,2)
READS SQL DATA
DETERMINISTIC
BEGIN
    DECLARE v_total DECIMAL(14,2);
    
    SELECT COALESCE(SUM(subtotal), 0.00)
    INTO v_total
    FROM detalle_ventas
    WHERE id_venta = p_id_venta;
    
    RETURN v_total;
END //

DELIMITER ;


-- -----------------------------------------------------------------------------
-- 2. fn_CalcularIVA
-- Calcula el impuesto (IVA) sobre un monto dado.
-- Tasa por defecto: 19% (Colombia)
-- -----------------------------------------------------------------------------
DROP FUNCTION IF EXISTS fn_CalcularIVA;

DELIMITER //

CREATE FUNCTION fn_CalcularIVA(
    p_monto DECIMAL(14,2),
    p_tasa DECIMAL(5,2)
)
RETURNS DECIMAL(14,2)
DETERMINISTIC
BEGIN
    RETURN ROUND(p_monto * (p_tasa / 100.0), 2);
END //

DELIMITER ;


-- -----------------------------------------------------------------------------
-- 3. fn_AplicarDescuento
-- Aplica un porcentaje de descuento a un monto dado.
-- -----------------------------------------------------------------------------
DROP FUNCTION IF EXISTS fn_AplicarDescuento;

DELIMITER //

CREATE FUNCTION fn_AplicarDescuento(
    p_monto DECIMAL(14,2),
    p_porcentaje DECIMAL(5,2)
)
RETURNS DECIMAL(14,2)
DETERMINISTIC
BEGIN
    RETURN ROUND(p_monto * (1 - p_porcentaje / 100.0), 2);
END //

DELIMITER ;


-- -----------------------------------------------------------------------------
-- 4. fn_ConvertirMoneda
-- Convierte un monto a otra moneda usando una tasa de cambio fija.
-- -----------------------------------------------------------------------------
DROP FUNCTION IF EXISTS fn_ConvertirMoneda;

DELIMITER //

CREATE FUNCTION fn_ConvertirMoneda(
    p_monto DECIMAL(14,2),
    p_tasa_cambio DECIMAL(10,4)
)
RETURNS DECIMAL(14,2)
DETERMINISTIC
BEGIN
    RETURN ROUND(p_monto * p_tasa_cambio, 2);
END //

DELIMITER ;


-- =============================================================================
-- GRUPO 2: Funciones de inventario y productos
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 5. fn_VerificarDisponibilidadStock
-- Valida si hay stock suficiente para un producto.
-- Retorna 1 (TRUE) si hay stock, 0 (FALSE) si no.
-- -----------------------------------------------------------------------------
DROP FUNCTION IF EXISTS fn_VerificarDisponibilidadStock;

DELIMITER //

CREATE FUNCTION fn_VerificarDisponibilidadStock(
    p_id_producto INT,
    p_cantidad INT
)
RETURNS TINYINT(1)
READS SQL DATA
DETERMINISTIC
BEGIN
    DECLARE v_stock INT;
    
    SELECT stock INTO v_stock
    FROM productos
    WHERE id_producto = p_id_producto;
    
    IF v_stock IS NULL THEN
        RETURN 0;
    END IF;
    
    RETURN (v_stock >= p_cantidad);
END //

DELIMITER ;


-- -----------------------------------------------------------------------------
-- 6. fn_ObtenerPrecioProducto
-- Devuelve el precio actual de un producto.
-- -----------------------------------------------------------------------------
DROP FUNCTION IF EXISTS fn_ObtenerPrecioProducto;

DELIMITER //

CREATE FUNCTION fn_ObtenerPrecioProducto(p_id_producto INT)
RETURNS DECIMAL(12,2)
READS SQL DATA
DETERMINISTIC
BEGIN
    DECLARE v_precio DECIMAL(12,2);
    
    SELECT precio INTO v_precio
    FROM productos
    WHERE id_producto = p_id_producto;
    
    RETURN COALESCE(v_precio, 0.00);
END //

DELIMITER ;


-- -----------------------------------------------------------------------------
-- 7. fn_ObtenerNombreCategoria
-- Devuelve el nombre de la categoría a partir del ID de un producto.
-- -----------------------------------------------------------------------------
DROP FUNCTION IF EXISTS fn_ObtenerNombreCategoria;

DELIMITER //

CREATE FUNCTION fn_ObtenerNombreCategoria(p_id_producto INT)
RETURNS VARCHAR(50)
READS SQL DATA
DETERMINISTIC
BEGIN
    DECLARE v_categoria VARCHAR(50);
    
    SELECT c.nombre INTO v_categoria
    FROM productos p
    INNER JOIN categorias c ON p.id_categoria = c.id_categoria
    WHERE p.id_producto = p_id_producto;
    
    RETURN COALESCE(v_categoria, 'Sin categoría');
END //

DELIMITER ;


-- -----------------------------------------------------------------------------
-- 8. fn_ObtenerStockTotalPorCategoria
-- Suma el stock de todos los productos de una categoría.
-- -----------------------------------------------------------------------------
DROP FUNCTION IF EXISTS fn_ObtenerStockTotalPorCategoria;

DELIMITER //

CREATE FUNCTION fn_ObtenerStockTotalPorCategoria(p_id_categoria INT)
RETURNS INT
READS SQL DATA
DETERMINISTIC
BEGIN
    DECLARE v_total INT;
    
    SELECT COALESCE(SUM(stock), 0) INTO v_total
    FROM productos
    WHERE id_categoria = p_id_categoria AND activo = 1;
    
    RETURN v_total;
END //

DELIMITER ;


-- -----------------------------------------------------------------------------
-- 9. fn_GenerarSKU
-- Genera un código SKU único basado en categoría y un identificador.
-- -----------------------------------------------------------------------------
DROP FUNCTION IF EXISTS fn_GenerarSKU;

DELIMITER //

CREATE FUNCTION fn_GenerarSKU(
    p_id_categoria INT,
    p_id_producto INT
)
RETURNS VARCHAR(20)
DETERMINISTIC
BEGIN
    DECLARE v_prefijo VARCHAR(3);
    DECLARE v_sku VARCHAR(20);
    
    SELECT UPPER(LEFT(nombre, 3)) INTO v_prefijo
    FROM categorias
    WHERE id_categoria = p_id_categoria;
    
    SET v_prefijo = COALESCE(v_prefijo, 'GEN');
    SET v_sku = CONCAT(v_prefijo, '-', LPAD(p_id_producto, 5, '0'));
    
    RETURN v_sku;
END //

DELIMITER ;


-- =============================================================================
-- GRUPO 3: Funciones de clientes
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 10. fn_FormatearNombreCompleto
-- Devuelve el nombre y apellido de un cliente en formato estandarizado
-- (primera letra mayúscula, resto minúsculas).
-- -----------------------------------------------------------------------------
DROP FUNCTION IF EXISTS fn_FormatearNombreCompleto;

DELIMITER //

CREATE FUNCTION fn_FormatearNombreCompleto(
    p_nombre VARCHAR(50),
    p_apellido VARCHAR(50)
)
RETURNS VARCHAR(101)
DETERMINISTIC
BEGIN
    RETURN CONCAT(
        CONCAT(UPPER(LEFT(p_nombre, 1)), LOWER(SUBSTRING(p_nombre, 2))),
        ' ',
        CONCAT(UPPER(LEFT(p_apellido, 1)), LOWER(SUBSTRING(p_apellido, 2)))
    );
END //

DELIMITER ;


-- -----------------------------------------------------------------------------
-- 11. fn_CalcularEdadCliente
-- Calcula la edad de un cliente a partir de su fecha de nacimiento.
-- -----------------------------------------------------------------------------
DROP FUNCTION IF EXISTS fn_CalcularEdadCliente;

DELIMITER //

CREATE FUNCTION fn_CalcularEdadCliente(p_fecha_nacimiento DATE)
RETURNS INT
DETERMINISTIC
BEGIN
    IF p_fecha_nacimiento IS NULL THEN
        RETURN NULL;
    END IF;
    
    RETURN TIMESTAMPDIFF(YEAR, p_fecha_nacimiento, CURDATE());
END //

DELIMITER ;


-- -----------------------------------------------------------------------------
-- 12. fn_ContarVentasCliente
-- Cuenta el número total de compras completadas de un cliente.
-- -----------------------------------------------------------------------------
DROP FUNCTION IF EXISTS fn_ContarVentasCliente;

DELIMITER //

CREATE FUNCTION fn_ContarVentasCliente(p_id_cliente INT)
RETURNS INT
READS SQL DATA
DETERMINISTIC
BEGIN
    DECLARE v_total INT;
    
    SELECT COUNT(*) INTO v_total
    FROM ventas
    WHERE id_cliente = p_id_cliente AND estado = 'completada';
    
    RETURN v_total;
END //

DELIMITER ;


-- -----------------------------------------------------------------------------
-- 13. fn_ObtenerUltimaFechaCompra
-- Devuelve la fecha de la última compra completada de un cliente.
-- -----------------------------------------------------------------------------
DROP FUNCTION IF EXISTS fn_ObtenerUltimaFechaCompra;

DELIMITER //

CREATE FUNCTION fn_ObtenerUltimaFechaCompra(p_id_cliente INT)
RETURNS DATETIME
READS SQL DATA
DETERMINISTIC
BEGIN
    DECLARE v_fecha DATETIME;
    
    SELECT MAX(fecha) INTO v_fecha
    FROM ventas
    WHERE id_cliente = p_id_cliente AND estado = 'completada';
    
    RETURN v_fecha;
END //

DELIMITER ;


-- -----------------------------------------------------------------------------
-- 14. fn_CalcularDiasDesdeUltimaCompra
-- Devuelve el número de días transcurridos desde la última compra.
-- -----------------------------------------------------------------------------
DROP FUNCTION IF EXISTS fn_CalcularDiasDesdeUltimaCompra;

DELIMITER //

CREATE FUNCTION fn_CalcularDiasDesdeUltimaCompra(p_id_cliente INT)
RETURNS INT
READS SQL DATA
DETERMINISTIC
BEGIN
    DECLARE v_ultima DATETIME;
    
    SELECT MAX(fecha) INTO v_ultima
    FROM ventas
    WHERE id_cliente = p_id_cliente AND estado = 'completada';
    
    IF v_ultima IS NULL THEN
        RETURN NULL;
    END IF;
    
    RETURN DATEDIFF(CURDATE(), v_ultima);
END //

DELIMITER ;


-- -----------------------------------------------------------------------------
-- 15. fn_EsClienteNuevo
-- Devuelve 1 (TRUE) si el cliente realizó su primera compra en los últimos 30 días.
-- -----------------------------------------------------------------------------
DROP FUNCTION IF EXISTS fn_EsClienteNuevo;

DELIMITER //

CREATE FUNCTION fn_EsClienteNuevo(p_id_cliente INT)
RETURNS TINYINT(1)
READS SQL DATA
DETERMINISTIC
BEGIN
    DECLARE v_primera DATETIME;
    
    SELECT MIN(fecha) INTO v_primera
    FROM ventas
    WHERE id_cliente = p_id_cliente AND estado = 'completada';
    
    IF v_primera IS NULL THEN
        RETURN 0;
    END IF;
    
    RETURN (DATEDIFF(CURDATE(), v_primera) <= 30);
END //

DELIMITER ;


-- -----------------------------------------------------------------------------
-- 16. fn_DeterminarEstadoLealtad
-- Asigna un estado de lealtad (Bronce, Plata, Oro) según el gasto total.
-- Bronce: < 500,000
-- Plata: 500,000 - 2,000,000
-- Oro: > 2,000,000
-- -----------------------------------------------------------------------------
DROP FUNCTION IF EXISTS fn_DeterminarEstadoLealtad;

DELIMITER //

CREATE FUNCTION fn_DeterminarEstadoLealtad(p_id_cliente INT)
RETURNS VARCHAR(10)
READS SQL DATA
DETERMINISTIC
BEGIN
    DECLARE v_total DECIMAL(14,2);
    
    SELECT COALESCE(SUM(total), 0.00) INTO v_total
    FROM ventas
    WHERE id_cliente = p_id_cliente AND estado = 'completada';
    
    IF v_total >= 2000000 THEN
        RETURN 'Oro';
    ELSEIF v_total >= 500000 THEN
        RETURN 'Plata';
    ELSE
        RETURN 'Bronce';
    END IF;
END //

DELIMITER ;


-- =============================================================================
-- GRUPO 4: Funciones de validación y utilidades
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 17. fn_ValidarFormatoEmail
-- Comprueba si una cadena tiene formato de email válido.
-- -----------------------------------------------------------------------------
DROP FUNCTION IF EXISTS fn_ValidarFormatoEmail;

DELIMITER //

CREATE FUNCTION fn_ValidarFormatoEmail(p_email VARCHAR(100))
RETURNS TINYINT(1)
DETERMINISTIC
BEGIN
    IF p_email IS NULL THEN
        RETURN 0;
    END IF;
    
    RETURN (p_email REGEXP '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}$');
END //

DELIMITER ;


-- -----------------------------------------------------------------------------
-- 18. fn_ValidarComplejidadContraseña
-- Verifica si una contraseña cumple criterios mínimos de seguridad:
-- - Longitud >= 8 caracteres
-- - Al menos una mayúscula
-- - Al menos un número
-- Retorna 1 si cumple, 0 si no.
-- -----------------------------------------------------------------------------
DROP FUNCTION IF EXISTS fn_ValidarComplejidadContraseña;

DELIMITER //

CREATE FUNCTION fn_ValidarComplejidadContraseña(p_password VARCHAR(255))
RETURNS TINYINT(1)
DETERMINISTIC
BEGIN
    IF p_password IS NULL THEN
        RETURN 0;
    END IF;
    
    IF CHAR_LENGTH(p_password) < 8 THEN
        RETURN 0;
    END IF;
    
    IF p_password NOT REGEXP '[A-Z]' THEN
        RETURN 0;
    END IF;
    
    IF p_password NOT REGEXP '[0-9]' THEN
        RETURN 0;
    END IF;
    
    RETURN 1;
END //

DELIMITER ;


-- -----------------------------------------------------------------------------
-- 19. fn_CalcularCostoEnvio
-- Calcula el costo de envío basado en la cantidad total de productos
-- de una venta. Tarifa base + costo por unidad.
-- -----------------------------------------------------------------------------
DROP FUNCTION IF EXISTS fn_CalcularCostoEnvio;

DELIMITER //

CREATE FUNCTION fn_CalcularCostoEnvio(p_id_venta INT)
RETURNS DECIMAL(10,2)
READS SQL DATA
DETERMINISTIC
BEGIN
    DECLARE v_unidades INT;
    DECLARE v_tarifa_base DECIMAL(10,2) DEFAULT 5000.00;
    DECLARE v_costo_unidad DECIMAL(10,2) DEFAULT 1500.00;
    
    SELECT COALESCE(SUM(cantidad), 0) INTO v_unidades
    FROM detalle_ventas
    WHERE id_venta = p_id_venta;
    
    RETURN v_tarifa_base + (v_unidades * v_costo_unidad);
END //

DELIMITER ;


-- -----------------------------------------------------------------------------
-- 20. fn_EstimarFechaEntrega
-- Calcula la fecha estimada de entrega según la región del cliente.
-- - Capital (Bogotá, Medellín, Cali, Barranquilla, Bucaramanga): 3 días
-- - Otras regiones: 7 días
-- -----------------------------------------------------------------------------
DROP FUNCTION IF EXISTS fn_EstimarFechaEntrega;

DELIMITER //

CREATE FUNCTION fn_EstimarFechaEntrega(p_id_cliente INT)
RETURNS DATE
READS SQL DATA
DETERMINISTIC
BEGIN
    DECLARE v_ciudad VARCHAR(50);
    DECLARE v_dias INT;
    
    SELECT ciudad INTO v_ciudad
    FROM clientes
    WHERE id_cliente = p_id_cliente;
    
    IF v_ciudad IN ('Bogotá', 'Medellín', 'Cali', 'Barranquilla', 'Bucaramanga') THEN
        SET v_dias = 3;
    ELSE
        SET v_dias = 7;
    END IF;
    
    RETURN DATE_ADD(CURDATE(), INTERVAL v_dias DAY);
END //

DELIMITER ;


-- =============================================================================
-- PRUEBAS DE FUNCIONES
-- =============================================================================

-- Prueba 1: fn_CalcularTotalVenta
SELECT fn_CalcularTotalVenta(1) AS total_venta_1;

-- Prueba 2: fn_CalcularIVA
SELECT fn_CalcularIVA(100000.00, 19) AS iva_19;

-- Prueba 3: fn_AplicarDescuento
SELECT fn_AplicarDescuento(100000.00, 15) AS precio_con_descuento;

-- Prueba 4: fn_ConvertirMoneda (COP a USD, tasa aprox 0.00025)
SELECT fn_ConvertirMoneda(1000000.00, 0.00025) AS monto_usd;

-- Prueba 5: fn_VerificarDisponibilidadStock
SELECT fn_VerificarDisponibilidadStock(1, 5) AS stock_disponible;

-- Prueba 6: fn_ObtenerPrecioProducto
SELECT fn_ObtenerPrecioProducto(1) AS precio_producto_1;

-- Prueba 7: fn_ObtenerNombreCategoria
SELECT fn_ObtenerNombreCategoria(1) AS categoria_producto_1;

-- Prueba 8: fn_ObtenerStockTotalPorCategoria
SELECT fn_ObtenerStockTotalPorCategoria(1) AS stock_categoria_1;

-- Prueba 9: fn_GenerarSKU
SELECT fn_GenerarSKU(1, 100) AS sku_generado;

-- Prueba 10: fn_FormatearNombreCompleto
SELECT fn_FormatearNombreCompleto('leonel', 'escalona') AS nombre_formateado;

-- Prueba 11: fn_CalcularEdadCliente
SELECT fn_CalcularEdadCliente('1995-06-15') AS edad;

-- Prueba 12: fn_ContarVentasCliente
SELECT fn_ContarVentasCliente(1) AS total_compras_cliente_1;

-- Prueba 13: fn_ObtenerUltimaFechaCompra
SELECT fn_ObtenerUltimaFechaCompra(1) AS ultima_compra_cliente_1;

-- Prueba 14: fn_CalcularDiasDesdeUltimaCompra
SELECT fn_CalcularD
