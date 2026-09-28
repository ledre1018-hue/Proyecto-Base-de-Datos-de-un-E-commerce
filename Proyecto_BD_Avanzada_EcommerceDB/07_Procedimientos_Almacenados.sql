-- =============================================================================
-- 07_Procedimientos_Almacenados.sql
-- Proyecto: EcommerceDB
-- Autor: Leonel Escalona
-- Descripción: 20 procedimientos almacenados transaccionales
-- =============================================================================

USE EcommerceDB;

-- =============================================================================
-- GRUPO 1: Procedimientos de ventas
-- =============================================================================

-- 1. sp_registrar_venta
-- Procesa una nueva venta de forma transaccional
DROP PROCEDURE IF EXISTS sp_registrar_venta;

DELIMITER //

CREATE PROCEDURE sp_registrar_venta(
    IN p_id_cliente INT,
    IN p_id_sucursal INT,
    OUT p_id_venta_generado INT,
    OUT p_mensaje VARCHAR(255)
)
BEGIN
    DECLARE v_error INT DEFAULT 0;
    DECLARE CONTINUE HANDLER FOR SQLEXCEPTION SET v_error = 1;
    
    START TRANSACTION;
    
    INSERT INTO ventas (id_cliente, id_sucursal, fecha, estado, total)
    VALUES (p_id_cliente, p_id_sucursal, NOW(), 'pendiente', 0.00);
    
    SET p_id_venta_generado = LAST_INSERT_ID();
    SET p_mensaje = CONCAT('Venta ', p_id_venta_generado, ' creada en estado pendiente');
    
    IF v_error = 1 THEN
        ROLLBACK;
        SET p_mensaje = 'Error al crear la venta';
        SET p_id_venta_generado = NULL;
    ELSE
        COMMIT;
    END IF;
END //

DELIMITER ;


-- 2. sp_agregar_detalle_venta
-- Agrega un producto a una venta existente (valida stock)
DROP PROCEDURE IF EXISTS sp_agregar_detalle_venta;

DELIMITER //

CREATE PROCEDURE sp_agregar_detalle_venta(
    IN p_id_venta INT,
    IN p_id_producto INT,
    IN p_cantidad INT,
    OUT p_mensaje VARCHAR(255)
)
BEGIN
    DECLARE v_stock INT;
    DECLARE v_precio DECIMAL(12,2);
    DECLARE v_estado VARCHAR(20);
    
    SELECT estado INTO v_estado FROM ventas WHERE id_venta = p_id_venta;
    
    IF v_estado IS NULL THEN
        SET p_mensaje = 'La venta no existe';
    ELSEIF v_estado <> 'pendiente' THEN
        SET p_mensaje = 'Solo se pueden agregar detalles a ventas pendientes';
    ELSE
        SELECT stock, precio INTO v_stock, v_precio
        FROM productos WHERE id_producto = p_id_producto;
        
        IF v_stock IS NULL THEN
            SET p_mensaje = 'El producto no existe';
        ELSEIF v_stock < p_cantidad THEN
            SET p_mensaje = CONCAT('Stock insuficiente. Disponible: ', v_stock);
        ELSE
            INSERT INTO detalle_ventas (id_venta, id_producto, cantidad, precio_unitario_congelado)
            VALUES (p_id_venta, p_id_producto, p_cantidad, v_precio);
            
            SET p_mensaje = CONCAT('Producto agregado. Subtotal: ', v_precio * p_cantidad);
        END IF;
    END IF;
END //

DELIMITER ;


-- 3. sp_procesar_pago
-- Cambia estado de venta a 'completada' y descuenta stock
DROP PROCEDURE IF EXISTS sp_procesar_pago;

DELIMITER //

CREATE PROCEDURE sp_procesar_pago(
    IN p_id_venta INT,
    OUT p_mensaje VARCHAR(255)
)
BEGIN
    DECLARE v_estado VARCHAR(20);
    DECLARE v_total DECIMAL(14,2);
    
    SELECT estado, total INTO v_estado, v_total
    FROM ventas WHERE id_venta = p_id_venta;
    
    IF v_estado IS NULL THEN
        SET p_mensaje = 'Venta no encontrada';
    ELSEIF v_estado <> 'pendiente' THEN
        SET p_mensaje = CONCAT('No se puede procesar. Estado actual: ', v_estado);
    ELSEIF v_total = 0 THEN
        SET p_mensaje = 'La venta no tiene detalles';
    ELSE
        UPDATE ventas SET estado = 'completada' WHERE id_venta = p_id_venta;
        SET p_mensaje = CONCAT('Pago procesado. Total: $', v_total);
    END IF;
END //

DELIMITER ;


-- 4. sp_cambiar_estado_pedido
-- Cambia el estado de un pedido con validación de transición
DROP PROCEDURE IF EXISTS sp_cambiar_estado_pedido;

DELIMITER //

CREATE PROCEDURE sp_cambiar_estado_pedido(
    IN p_id_venta INT,
    IN p_nuevo_estado VARCHAR(20),
    OUT p_mensaje VARCHAR(255)
)
BEGIN
    DECLARE v_estado_actual VARCHAR(20);
    
    SELECT estado INTO v_estado_actual FROM ventas WHERE id_venta = p_id_venta;
    
    IF v_estado_actual IS NULL THEN
        SET p_mensaje = 'Venta no encontrada';
    ELSEIF p_nuevo_estado NOT IN ('pendiente', 'completada', 'cancelada') THEN
        SET p_mensaje = 'Estado no válido';
    ELSEIF v_estado_actual = p_nuevo_estado THEN
        SET p_mensaje = 'La venta ya tiene ese estado';
    ELSE
        UPDATE ventas SET estado = p_nuevo_estado WHERE id_venta = p_id_venta;
        SET p_mensaje = CONCAT('Estado cambiado de "', v_estado_actual, '" a "', p_nuevo_estado, '"');
    END IF;
END //

DELIMITER ;


-- 5. sp_procesar_devolucion
-- Cancela una venta completada y restaura stock
DROP PROCEDURE IF EXISTS sp_procesar_devolucion;

DELIMITER //

CREATE PROCEDURE sp_procesar_devolucion(
    IN p_id_venta INT,
    OUT p_mensaje VARCHAR(255)
)
BEGIN
    DECLARE v_estado VARCHAR(20);
    DECLARE v_error INT DEFAULT 0;
    DECLARE CONTINUE HANDLER FOR SQLEXCEPTION SET v_error = 1;
    
    SELECT estado INTO v_estado FROM ventas WHERE id_venta = p_id_venta;
    
    IF v_estado IS NULL THEN
        SET p_mensaje = 'Venta no encontrada';
    ELSEIF v_estado <> 'completada' THEN
        SET p_mensaje = 'Solo se pueden devolver ventas completadas';
    ELSE
        START TRANSACTION;
        
        UPDATE ventas SET estado = 'cancelada' WHERE id_venta = p_id_venta;
        
        UPDATE productos p
        INNER JOIN detalle_ventas dv ON p.id_producto = dv.id_producto
        SET p.stock = p.stock + dv.cantidad
        WHERE dv.id_venta = p_id_venta;
        
        IF v_error = 1 THEN
            ROLLBACK;
            SET p_mensaje = 'Error al procesar la devolución';
        ELSE
            COMMIT;
            SET p_mensaje = 'Devolución procesada. Stock restaurado.';
        END IF;
    END IF;
END //

DELIMITER ;


-- =============================================================================
-- GRUPO 2: Procedimientos de productos
-- =============================================================================

-- 6. sp_agregar_nuevo_producto
DROP PROCEDURE IF EXISTS sp_agregar_nuevo_producto;

DELIMITER //

CREATE PROCEDURE sp_agregar_nuevo_producto(
    IN p_nombre VARCHAR(100),
    IN p_descripcion TEXT,
    IN p_precio DECIMAL(12,2),
    IN p_costo DECIMAL(12,2),
    IN p_stock INT,
    IN p_stock_minimo INT,
    IN p_id_categoria INT,
    IN p_id_proveedor INT,
    OUT p_id_producto INT,
    OUT p_mensaje VARCHAR(255)
)
BEGIN
    IF p_precio <= 0 THEN
        SET p_mensaje = 'El precio debe ser mayor a cero';
    ELSEIF p_costo < 0 THEN
        SET p_mensaje = 'El costo no puede ser negativo';
    ELSEIF p_stock < 0 THEN
        SET p_mensaje = 'El stock no puede ser negativo';
    ELSE
        INSERT INTO productos (nombre, descripcion, precio, costo, stock, stock_minimo, id_categoria, id_proveedor, activo)
        VALUES (p_nombre, p_descripcion, p_precio, p_costo, p_stock, p_stock_minimo, p_id_categoria, p_id_proveedor, 1);
        
        SET p_id_producto = LAST_INSERT_ID();
        SET p_mensaje = CONCAT('Producto creado con ID: ', p_id_producto);
    END IF;
END //

DELIMITER ;


-- 7. sp_ajustar_nivel_stock
DROP PROCEDURE IF EXISTS sp_ajustar_nivel_stock;

DELIMITER //

CREATE PROCEDURE sp_ajustar_nivel_stock(
    IN p_id_producto INT,
    IN p_nuevo_stock INT,
    IN p_motivo VARCHAR(255),
    OUT p_mensaje VARCHAR(255)
)
BEGIN
    DECLARE v_stock_actual INT;
    
    SELECT stock INTO v_stock_actual FROM productos WHERE id_producto = p_id_producto;
    
    IF v_stock_actual IS NULL THEN
        SET p_mensaje = 'Producto no encontrado';
    ELSEIF p_nuevo_stock < 0 THEN
        SET p_mensaje = 'El stock no puede ser negativo';
    ELSE
        UPDATE productos SET stock = p_nuevo_stock WHERE id_producto = p_id_producto;
        SET p_mensaje = CONCAT('Stock ajustado de ', v_stock_actual, ' a ', p_nuevo_stock, '. Motivo: ', p_motivo);
    END IF;
END //

DELIMITER ;


-- 8. sp_aplicar_descuento_por_categoria
DROP PROCEDURE IF EXISTS sp_aplicar_descuento_por_categoria;

DELIMITER //

CREATE PROCEDURE sp_aplicar_descuento_por_categoria(
    IN p_id_categoria INT,
    IN p_porcentaje DECIMAL(5,2),
    OUT p_mensaje VARCHAR(255)
)
BEGIN
    DECLARE v_count INT;
    
    SELECT COUNT(*) INTO v_count FROM productos WHERE id_categoria = p_id_categoria AND activo = 1;
    
    IF v_count = 0 THEN
        SET p_mensaje = 'No hay productos activos en esa categoría';
    ELSEIF p_porcentaje < 0 OR p_porcentaje > 100 THEN
        SET p_mensaje = 'Porcentaje no válido (0-100)';
    ELSE
        UPDATE productos
        SET precio = ROUND(precio * (1 - p_porcentaje / 100), 2)
        WHERE id_categoria = p_id_categoria AND activo = 1;
        
        SET p_mensaje = CONCAT('Descuento del ', p_porcentaje, '% aplicado a ', v_count, ' productos');
    END IF;
END //

DELIMITER ;


-- 9. sp_mover_productos_entre_categorias
DROP PROCEDURE IF EXISTS sp_mover_productos_entre_categorias;

DELIMITER //

CREATE PROCEDURE sp_mover_productos_entre_categorias(
    IN p_categoria_origen INT,
    IN p_categoria_destino INT,
    OUT p_mensaje VARCHAR(255)
)
BEGIN
    DECLARE v_count INT;
    
    IF p_categoria_origen = p_categoria_destino THEN
        SET p_mensaje = 'Las categorías son iguales';
    ELSE
        SELECT COUNT(*) INTO v_count FROM productos WHERE id_categoria = p_categoria_origen AND activo = 1;
        
        UPDATE productos SET id_categoria = p_categoria_destino
        WHERE id_categoria = p_categoria_origen AND activo = 1;
        
        SET p_mensaje = CONCAT(v_count, ' productos movidos de categoría ', p_categoria_origen, ' a ', p_categoria_destino);
    END IF;
END //

DELIMITER ;


-- 10. sp_asignar_producto_a_proveedor
DROP PROCEDURE IF EXISTS sp_asignar_producto_a_proveedor;

DELIMITER //

CREATE PROCEDURE sp_asignar_producto_a_proveedor(
    IN p_id_producto INT,
    IN p_nuevo_proveedor INT,
    OUT p_mensaje VARCHAR(255)
)
BEGIN
    DECLARE v_prov_actual INT;
    
    SELECT id_proveedor INTO v_prov_actual FROM productos WHERE id_producto = p_id_producto;
    
    IF v_prov_actual IS NULL THEN
        SET p_mensaje = 'Producto no encontrado';
    ELSEIF v_prov_actual = p_nuevo_proveedor THEN
        SET p_mensaje = 'El producto ya tiene ese proveedor';
    ELSE
        UPDATE productos SET id_proveedor = p_nuevo_proveedor WHERE id_producto = p_id_producto;
        SET p_mensaje = CONCAT('Proveedor cambiado de ', v_prov_actual, ' a ', p_nuevo_proveedor);
    END IF;
END //

DELIMITER ;


-- 11. sp_buscar_productos
DROP PROCEDURE IF EXISTS sp_buscar_productos;

DELIMITER //

CREATE PROCEDURE sp_buscar_productos(
    IN p_nombre VARCHAR(100),
    IN p_id_categoria INT,
    IN p_precio_min DECIMAL(12,2),
    IN p_precio_max DECIMAL(12,2)
)
BEGIN
    SELECT p.id_producto, p.nombre, p.precio, p.stock, c.nombre AS categoria, pr.nombre AS proveedor
    FROM productos p
    LEFT JOIN categorias c ON p.id_categoria = c.id_categoria
    LEFT JOIN proveedores pr ON p.id_proveedor = pr.id_proveedor
    WHERE p.activo = 1
      AND (p_nombre IS NULL OR p.nombre LIKE CONCAT('%', p_nombre, '%'))
      AND (p_id_categoria IS NULL OR p.id_categoria = p_id_categoria)
      AND (p_precio_min IS NULL OR p.precio >= p_precio_min)
      AND (p_precio_max IS NULL OR p.precio <= p_precio_max)
    ORDER BY p.nombre;
END //

DELIMITER ;


-- 12. sp_obtener_detalles_producto_completo
DROP PROCEDURE IF EXISTS sp_obtener_detalles_producto_completo;

DELIMITER //

CREATE PROCEDURE sp_obtener_detalles_producto_completo(
    IN p_id_producto INT
)
BEGIN
    SELECT 
        p.id_producto, p.sku, p.nombre, p.descripcion, p.precio, p.costo,
        p.stock, p.stock_minimo, p.activo, p.fecha_creacion, p.fecha_modificacion,
        c.nombre AS categoria, c.descripcion AS desc_categoria,
        pr.nombre AS proveedor, pr.email AS email_proveedor, pr.telefono
    FROM productos p
    LEFT JOIN categorias c ON p.id_categoria = c.id_categoria
    LEFT JOIN proveedores pr ON p.id_proveedor = pr.id_proveedor
    WHERE p.id_producto = p_id_producto;
END //

DELIMITER ;


-- =============================================================================
-- GRUPO 3: Procedimientos de clientes
-- =============================================================================

-- 13. sp_registrar_nuevo_cliente
DROP PROCEDURE IF EXISTS sp_registrar_nuevo_cliente;

DELIMITER //

CREATE PROCEDURE sp_registrar_nuevo_cliente(
    IN p_nombre VARCHAR(50),
    IN p_apellido VARCHAR(50),
    IN p_email VARCHAR(100),
    IN p_password VARCHAR(255),
    IN p_direccion VARCHAR(200),
    IN p_ciudad VARCHAR(50),
    IN p_region VARCHAR(50),
    OUT p_id_cliente INT,
    OUT p_mensaje VARCHAR(255)
)
BEGIN
    DECLARE v_existe INT;
    
    SELECT COUNT(*) INTO v_existe FROM clientes WHERE email = p_email;
    
    IF v_existe > 0 THEN
        SET p_mensaje = 'El email ya está registrado';
        SET p_id_cliente = NULL;
    ELSEIF p_email NOT REGEXP '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}$' THEN
        SET p_mensaje = 'Email no válido';
        SET p_id_cliente = NULL;
    ELSE
        INSERT INTO clientes (nombre, apellido, email, password_hash, direccion_envio, ciudad, region)
        VALUES (p_nombre, p_apellido, p_email, SHA2(p_password, 256), p_direccion, p_ciudad, p_region);
        
        SET p_id_cliente = LAST_INSERT_ID();
        SET p_mensaje = CONCAT('Cliente registrado con ID: ', p_id_cliente);
    END IF;
END //

DELIMITER ;


-- 14. sp_actualizar_direccion_cliente
DROP PROCEDURE IF EXISTS sp_actualizar_direccion_cliente;

DELIMITER //

CREATE PROCEDURE sp_actualizar_direccion_cliente(
    IN p_id_cliente INT,
    IN p_nueva_direccion VARCHAR(200),
    IN p_nueva_ciudad VARCHAR(50),
    IN p_nueva_region VARCHAR(50),
    OUT p_mensaje VARCHAR(255)
)
BEGIN
    DECLARE v_existe INT;
    
    SELECT COUNT(*) INTO v_existe FROM clientes WHERE id_cliente = p_id_cliente;
    
    IF v_existe = 0 THEN
        SET p_mensaje = 'Cliente no encontrado';
    ELSE
        UPDATE clientes
        SET direccion_envio = p_nueva_direccion,
            ciudad = p_nueva_ciudad,
            region = p_nueva_region
        WHERE id_cliente = p_id_cliente;
        
        SET p_mensaje = 'Dirección actualizada correctamente';
    END IF;
END //

DELIMITER ;


-- 15. sp_eliminar_cliente_de_forma_segura
-- Anonimiza datos del cliente en lugar de borrarlo
DROP PROCEDURE IF EXISTS sp_eliminar_cliente_de_forma_segura;

DELIMITER //

CREATE PROCEDURE sp_eliminar_cliente_de_forma_segura(
    IN p_id_cliente INT,
    OUT p_mensaje VARCHAR(255)
)
BEGIN
    DECLARE v_existe INT;
    DECLARE v_ventas_pendientes INT;
    
    SELECT COUNT(*) INTO v_existe FROM clientes WHERE id_cliente = p_id_cliente;
    SELECT COUNT(*) INTO v_ventas_pendientes FROM ventas WHERE id_cliente = p_id_cliente AND estado = 'pendiente';
    
    IF v_existe = 0 THEN
        SET p_mensaje = 'Cliente no encontrado';
    ELSEIF v_ventas_pendientes > 0 THEN
        SET p_mensaje = 'No se puede anonimizar: tiene ventas pendientes';
    ELSE
        UPDATE clientes
        SET nombre = 'ANONIMIZADO',
            apellido = 'ANONIMIZADO',
            email = CONCAT('anon_', p_id_cliente, '@eliminado.com'),
            password_hash = SHA2(CONCAT('anon_', p_id_cliente, '_', NOW()), 256),
            direccion_envio = NULL,
            ciudad = NULL,
            region = NULL,
            activo = 0
        WHERE id_cliente = p_id_cliente;
        
        SET p_mensaje = CONCAT('Cliente ', p_id_cliente, ' anonimizado correctamente');
    END IF;
END //

DELIMITER ;


-- 16. sp_fusionar_cuentas_cliente
DROP PROCEDURE IF EXISTS sp_fusionar_cuentas_cliente;

DELIMITER //

CREATE PROCEDURE sp_fusionar_cuentas_cliente(
    IN p_id_cliente_principal INT,
    IN p_id_cliente_secundario INT,
    OUT p_mensaje VARCHAR(255)
)
BEGIN
    DECLARE v_existe1 INT;
    DECLARE v_existe2 INT;
    DECLARE v_error INT DEFAULT 0;
    DECLARE CONTINUE HANDLER FOR SQLEXCEPTION SET v_error = 1;
    
    SELECT COUNT(*) INTO v_existe1 FROM clientes WHERE id_cliente = p_id_cliente_principal;
    SELECT COUNT(*) INTO v_existe2 FROM clientes WHERE id_cliente = p_id_cliente_secundario;
    
    IF v_existe1 = 0 OR v_existe2 = 0 THEN
        SET p_mensaje = 'Uno de los clientes no existe';
    ELSEIF p_id_cliente_principal = p_id_cliente_secundario THEN
        SET p_mensaje = 'Los IDs son iguales';
    ELSE
        START TRANSACTION;
        
        UPDATE ventas SET id_cliente = p_id_cliente_principal WHERE id_cliente = p_id_cliente_secundario;
        
        UPDATE clientes SET activo = 0 WHERE id_cliente = p_id_cliente_secundario;
        
        IF v_error = 1 THEN
            ROLLBACK;
            SET p_mensaje = 'Error al fusionar';
        ELSE
            COMMIT;
            SET p_mensaje = CONCAT('Cuenta ', p_id_cliente_secundario, ' fusionada en ', p_id_cliente_principal);
        END IF;
    END IF;
END //

DELIMITER ;


-- 17. sp_obtener_historial_compras_cliente
DROP PROCEDURE IF EXISTS sp_obtener_historial_compras_cliente;

DELIMITER //

CREATE PROCEDURE sp_obtener_historial_compras_cliente(
    IN p_id_cliente INT
)
BEGIN
    SELECT 
        v.id_venta, v.fecha, v.estado, v.total,
        COUNT(dv.id_detalle) AS num_productos,
        GROUP_CONCAT(CONCAT(p.nombre, ' x', dv.cantidad) SEPARATOR ', ') AS productos
    FROM ventas v
    LEFT JOIN detalle_ventas dv ON v.id_venta = dv.id_venta
    LEFT JOIN productos p ON dv.id_producto = p.id_producto
    WHERE v.id_cliente = p_id_cliente
    GROUP BY v.id_venta, v.fecha, v.estado, v.total
    ORDER BY v.fecha DESC;
END //

DELIMITER ;


-- =============================================================================
-- GRUPO 4: Procedimientos de reportes
-- =============================================================================

-- 18. sp_generar_reporte_mensual_ventas
DROP PROCEDURE IF EXISTS sp_generar_reporte_mensual_ventas;

DELIMITER //

CREATE PROCEDURE sp_generar_reporte_mensual_ventas(
    IN p_anio INT,
    IN p_mes INT
)
BEGIN
    SELECT 
        COUNT(*) AS total_ventas,
        SUM(total) AS ingresos_totales,
        AVG(total) AS ticket_promedio,
        COUNT(DISTINCT id_cliente) AS clientes_unicos,
        SUM(CASE WHEN estado = 'completada' THEN 1 ELSE 0 END) AS ventas_completadas,
        SUM(CASE WHEN estado = 'cancelada' THEN 1 ELSE 0 END) AS ventas_canceladas
    FROM ventas
    WHERE YEAR(fecha) = p_anio AND MONTH(fecha) = p_mes;
END //

DELIMITER ;


-- 19. sp_obtener_dashboard_admin
DROP PROCEDURE IF EXISTS sp_obtener_dashboard_admin;

DELIMITER //

CREATE PROCEDURE sp_obtener_dashboard_admin()
BEGIN
    SELECT 'productos_activos' AS metrica, COUNT(*) AS valor FROM productos WHERE activo = 1
    UNION ALL
    SELECT 'clientes_activos', COUNT(*) FROM clientes WHERE activo = 1
    UNION ALL
    SELECT 'ventas_hoy', COUNT(*) FROM ventas WHERE DATE(fecha) = CURDATE()
    UNION ALL
    SELECT 'ventas_mes', COUNT(*) FROM ventas WHERE MONTH(fecha) = MONTH(CURDATE()) AND YEAR(fecha) = YEAR(CURDATE())
    UNION ALL
    SELECT 'ingresos_mes', COALESCE(SUM(total),0) FROM ventas WHERE MONTH(fecha) = MONTH(CURDATE()) AND YEAR(fecha) = YEAR(CURDATE()) AND estado = 'completada'
    UNION ALL
    SELECT 'productos_stock_bajo', COUNT(*) FROM productos WHERE stock <= stock_minimo AND activo = 1;
END //

DELIMITER ;


-- 20. sp_obtener_productos_relacionados
DROP PROCEDURE IF EXISTS sp_obtener_productos_relacionados;

DELIMITER //

CREATE PROCEDURE sp_obtener_productos_relacionados(
    IN p_id_producto INT,
    IN p_limite INT
)
BEGIN
    SELECT p2.id_producto, p2.nombre, p2.precio, COUNT(*) AS veces_comprados_juntos
    FROM detalle_ventas dv1
    INNER JOIN detalle_ventas dv2 ON dv1.id_venta = dv2.id_venta AND dv1.id_producto <> dv2.id_producto
    INNER JOIN productos p2 ON dv2.id_producto = p2.id_producto
    WHERE dv1.id_producto = p_id_producto AND p2.activo = 1
    GROUP BY p2.id_producto, p2.nombre, p2.precio
    ORDER BY veces_comprados_juntos DESC
    LIMIT p_limite;
END //

DELIMITER ;


-- =============================================================================
-- VERIFICACIÓN
-- =============================================================================

SELECT '=== PROCEDIMIENTOS CREADOS ===' AS seccion;
SHOW PROCEDURE STATUS WHERE Db = 'EcommerceDB';


-- =============================================================================
-- PRUEBAS DE PROCEDIMIENTOS
-- =============================================================================

-- Prueba 1: sp_obtener_dashboard_admin
CALL sp_obtener_dashboard_admin();

-- Prueba 2: sp_generar_reporte_mensual_ventas
CALL sp_generar_reporte_mensual_ventas(2025, 3);

-- Prueba 3: sp_registrar_nuevo_cliente
CALL sp_registrar_nuevo_cliente('Juan', 'Prueba', 'juan.prueba@test.com', 'Password123!', 'Calle 123', 'Bogotá', 'Cundinamarca', @id, @msg);
SELECT @id AS id_cliente, @msg AS mensaje;

-- Prueba 4: sp_buscar_productos
CALL sp_buscar_productos(NULL, NULL, 100000, 500000);

-- Prueba 5: sp_obtener_historial_compras_cliente
CALL sp_obtener_historial_compras_cliente(1);


-- =============================================================================
-- OTORGAR PERMISOS DE EJECUCIÓN A ROLES (pendiente en 04_Seguridad)
-- =============================================================================

GRANT EXECUTE ON PROCEDURE EcommerceDB.sp_generar_reporte_mensual_ventas TO 'Gerente_Marketing';
GRANT EXECUTE ON PROCEDURE EcommerceDB.sp_obtener_dashboard_admin TO 'Administrador_Sistema';
GRANT EXECUTE ON PROCEDURE EcommerceDB.sp_registrar_nuevo_cliente TO 'Atencion_Cliente';
GRANT EXECUTE ON PROCEDURE EcommerceDB.sp_buscar_productos TO 'Visitante';


-- =============================================================================
-- FIN DEL ARCHIVO 07_Procedimientos_Almacenados.sql
-- =============================================================================