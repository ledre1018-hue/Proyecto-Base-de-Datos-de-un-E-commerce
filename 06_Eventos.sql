-- =============================================================================
-- 06_Eventos.sql
-- Proyecto: EcommerceDB
-- Autor: Leonel Escalona
-- Descripción: 20 eventos programados para automatización
-- =============================================================================

USE EcommerceDB;

-- Activar el programador de eventos
SET GLOBAL event_scheduler = ON;

-- =============================================================================
-- GRUPO 1: Eventos de mantenimiento de ventas
-- =============================================================================

-- 1. ev_cancelar_ventas_pendientes_antiguas
-- Cancela ventas pendientes con más de 7 días y restaura stock
DROP EVENT IF EXISTS ev_cancelar_ventas_pendientes_antiguas;

DELIMITER //
CREATE EVENT ev_cancelar_ventas_pendientes_antiguas
ON SCHEDULE EVERY 1 DAY
STARTS CURRENT_TIMESTAMP
ON COMPLETION PRESERVE
COMMENT 'Cancela ventas pendientes antiguas y restaura stock'
DO
BEGIN
    DECLARE done INT DEFAULT 0;
    DECLARE v_id_venta INT;
    DECLARE v_id_producto INT;
    DECLARE v_cantidad INT;
    
    DECLARE cur CURSOR FOR
        SELECT dv.id_producto, dv.cantidad
        FROM detalle_ventas dv
        INNER JOIN ventas v ON dv.id_venta = v.id_venta
        WHERE v.estado = 'pendiente' AND v.fecha < DATE_SUB(NOW(), INTERVAL 7 DAY);
    
    DECLARE CONTINUE HANDLER FOR NOT FOUND SET done = 1;
    
    OPEN cur;
    read_loop: LOOP
        FETCH cur INTO v_id_producto, v_cantidad;
        IF done THEN
            LEAVE read_loop;
        END IF;
        UPDATE productos SET stock = stock + v_cantidad WHERE id_producto = v_id_producto;
    END LOOP;
    CLOSE cur;
    
    UPDATE ventas SET estado = 'cancelada'
    WHERE estado = 'pendiente' AND fecha < DATE_SUB(NOW(), INTERVAL 7 DAY);
END //
DELIMITER ;


-- 2. ev_actualizar_total_ventas
-- Recalcula el total de ventas completadas del día
DROP EVENT IF EXISTS ev_actualizar_total_ventas;

DELIMITER //
CREATE EVENT ev_actualizar_total_ventas
ON SCHEDULE EVERY 1 HOUR
STARTS CURRENT_TIMESTAMP
ON COMPLETION PRESERVE
COMMENT 'Recalcula totales de ventas del día'
DO
BEGIN
    UPDATE ventas v
    SET total = (
        SELECT COALESCE(SUM(subtotal), 0.00)
        FROM detalle_ventas
        WHERE id_venta = v.id_venta
    )
    WHERE DATE(v.fecha) = CURDATE() AND v.estado = 'completada';
END //
DELIMITER ;


-- =============================================================================
-- GRUPO 2: Eventos de clientes
-- =============================================================================

-- 3. ev_actualizar_estado_lealtad_clientes
DROP EVENT IF EXISTS ev_actualizar_estado_lealtad_clientes;

DELIMITER //
CREATE EVENT ev_actualizar_estado_lealtad_clientes
ON SCHEDULE EVERY 1 DAY
STARTS CURRENT_TIMESTAMP
ON COMPLETION PRESERVE
COMMENT 'Actualiza estado de lealtad de clientes según gasto total'
DO
BEGIN
    UPDATE clientes c
    SET estado_lealtad = CASE
        WHEN (SELECT COALESCE(SUM(total),0) FROM ventas WHERE id_cliente = c.id_cliente AND estado='completada') >= 2000000 THEN 'Oro'
        WHEN (SELECT COALESCE(SUM(total),0) FROM ventas WHERE id_cliente = c.id_cliente AND estado='completada') >= 500000 THEN 'Plata'
        ELSE 'Bronce'
    END
    WHERE c.activo = 1;
END //
DELIMITER ;


-- 4. ev_suspend_cuentas_inactivas
DROP EVENT IF EXISTS ev_suspend_cuentas_inactivas;

DELIMITER //
CREATE EVENT ev_suspend_cuentas_inactivas
ON SCHEDULE EVERY 30 DAY
STARTS CURRENT_TIMESTAMP
ON COMPLETION PRESERVE
COMMENT 'Desactiva clientes sin compras en más de 1 año'
DO
BEGIN
    UPDATE clientes
    SET activo = 0
    WHERE activo = 1
      AND (ultima_compra IS NULL OR ultima_compra < DATE_SUB(CURDATE(), INTERVAL 1 YEAR))
      AND id_cliente NOT IN (SELECT id_cliente FROM ventas WHERE estado = 'pendiente');
END //
DELIMITER ;


-- 5. ev_clientes_cumpleanos
-- CORRECCIÓN: usaba fecha_registro (fecha de alta en el sistema) en vez de
-- fecha_nacimiento (la fecha de cumpleaños real del cliente).
DROP EVENT IF EXISTS ev_clientes_cumpleanos;

DELIMITER //
CREATE EVENT ev_clientes_cumpleanos
ON SCHEDULE EVERY 1 DAY
STARTS CURRENT_TIMESTAMP
ON COMPLETION PRESERVE
COMMENT 'Registra clientes que cumplen años hoy para enviar cupón'
DO
BEGIN
    INSERT INTO auditoria (tabla_afectada, id_registro_afectado, accion, usuario_bd, fecha_hora, detalle)
    SELECT 'clientes', id_cliente, 'INSERT', 'EVENT_SCHEDULER', NOW(),
           CONCAT('Cumpleaños: ', nombre, ' ', apellido, ' - Enviar cupón 10%')
    FROM clientes
    WHERE fecha_nacimiento IS NOT NULL
      AND MONTH(fecha_nacimiento) = MONTH(CURDATE())
      AND DAY(fecha_nacimiento) = DAY(CURDATE())
      AND activo = 1;
END //
DELIMITER ;


-- =============================================================================
-- GRUPO 3: Eventos de inventario
-- =============================================================================

-- 6. ev_generar_lista_reabastecimiento
DROP EVENT IF EXISTS ev_generar_lista_reabastecimiento;

DELIMITER //
CREATE EVENT ev_generar_lista_reabastecimiento
ON SCHEDULE EVERY 1 DAY
STARTS CURRENT_TIMESTAMP
ON COMPLETION PRESERVE
COMMENT 'Genera lista de productos con stock bajo'
DO
BEGIN
    INSERT INTO auditoria (tabla_afectada, id_registro_afectado, accion, usuario_bd, fecha_hora, detalle)
    SELECT 'productos', id_producto, 'UPDATE', 'EVENT_SCHEDULER', NOW(),
           CONCAT('REABASTECER: ', nombre, ' - Stock: ', stock, ' (min: ', stock_minimo, ')')
    FROM productos
    WHERE stock <= stock_minimo AND activo = 1;
END //
DELIMITER ;


-- 7. ev_actualizar_contador_categorias
DROP EVENT IF EXISTS ev_actualizar_contador_categorias;

DELIMITER //
CREATE EVENT ev_actualizar_contador_categorias
ON SCHEDULE EVERY 1 DAY
STARTS CURRENT_TIMESTAMP
ON COMPLETION PRESERVE
COMMENT 'Recalcula contador de productos por categoría'
DO
BEGIN
    UPDATE categorias c
    SET contador_productos = (
        SELECT COUNT(*) FROM productos WHERE id_categoria = c.id_categoria AND activo = 1
    );
END //
DELIMITER ;


-- 8. ev_alerta_stock_critico
DROP EVENT IF EXISTS ev_alerta_stock_critico;

DELIMITER //
CREATE EVENT ev_alerta_stock_critico
ON SCHEDULE EVERY 6 HOUR
STARTS CURRENT_TIMESTAMP
ON COMPLETION PRESERVE
COMMENT 'Alerta productos con stock en cero'
DO
BEGIN
    INSERT INTO auditoria (tabla_afectada, id_registro_afectado, accion, usuario_bd, fecha_hora, detalle)
    SELECT 'productos', id_producto, 'UPDATE', 'EVENT_SCHEDULER', NOW(),
           CONCAT('STOCK CRÍTICO: ', nombre, ' - SIN STOCK')
    FROM productos
    WHERE stock = 0 AND activo = 1;
END //
DELIMITER ;


-- =============================================================================
-- GRUPO 4: Eventos de reportes y métricas
-- =============================================================================

-- 9. ev_reporte_ventas_diario
DROP EVENT IF EXISTS ev_reporte_ventas_diario;

DELIMITER //
CREATE EVENT ev_reporte_ventas_diario
ON SCHEDULE EVERY 1 DAY
STARTS CURRENT_TIMESTAMP + INTERVAL 1 DAY
ON COMPLETION PRESERVE
COMMENT 'Genera reporte diario de ventas'
DO
BEGIN
    INSERT INTO auditoria (tabla_afectada, id_registro_afectado, accion, usuario_bd, fecha_hora, detalle)
    SELECT 'ventas', 0, 'INSERT', 'EVENT_SCHEDULER', NOW(),
           CONCAT('REPORTE DIARIO: ', COUNT(*), ' ventas, Total: $', COALESCE(SUM(total),0))
    FROM ventas
    WHERE DATE(fecha) = DATE_SUB(CURDATE(), INTERVAL 1 DAY) AND estado = 'completada';
END //
DELIMITER ;


-- 10. ev_ranking_productos
DROP EVENT IF EXISTS ev_ranking_productos;

DELIMITER //
CREATE EVENT ev_ranking_productos
ON SCHEDULE EVERY 1 HOUR
STARTS CURRENT_TIMESTAMP
ON COMPLETION PRESERVE
COMMENT 'Actualiza ranking de productos más vendidos'
DO
BEGIN
    INSERT INTO auditoria (tabla_afectada, id_registro_afectado, accion, usuario_bd, fecha_hora, detalle)
    SELECT 'productos', id_producto, 'UPDATE', 'EVENT_SCHEDULER', NOW(),
           CONCAT('TOP VENTAS: ', nombre, ' - ', 
                  (SELECT COALESCE(SUM(cantidad),0) FROM detalle_ventas WHERE id_producto = p.id_producto),
                  ' unidades')
    FROM productos p
    WHERE p.activo = 1
    ORDER BY (SELECT COALESCE(SUM(cantidad),0) FROM detalle_ventas WHERE id_producto = p.id_producto) DESC
    LIMIT 10;
END //
DELIMITER ;


-- 11. ev_kpis_mensuales
DROP EVENT IF EXISTS ev_kpis_mensuales;

DELIMITER //
CREATE EVENT ev_kpis_mensuales
ON SCHEDULE EVERY 1 MONTH
STARTS CURRENT_TIMESTAMP + INTERVAL 1 MONTH
ON COMPLETION PRESERVE
COMMENT 'Calcula KPIs mensuales'
DO
BEGIN
    INSERT INTO auditoria (tabla_afectada, id_registro_afectado, accion, usuario_bd, fecha_hora, detalle)
    SELECT 'ventas', 0, 'INSERT', 'EVENT_SCHEDULER', NOW(),
           CONCAT('KPI MES: Ventas=', COUNT(DISTINCT id_venta),
                  ', Clientes=', COUNT(DISTINCT id_cliente),
                  ', Total=$', COALESCE(SUM(total),0))
    FROM ventas
    WHERE estado = 'completada'
      AND MONTH(fecha) = MONTH(DATE_SUB(CURDATE(), INTERVAL 1 MONTH))
      AND YEAR(fecha) = YEAR(DATE_SUB(CURDATE(), INTERVAL 1 MONTH));
END //
DELIMITER ;


-- =============================================================================
-- GRUPO 5: Eventos de mantenimiento y limpieza
-- =============================================================================

-- 12. ev_limpiar_auditoria_antigua
DROP EVENT IF EXISTS ev_limpiar_auditoria_antigua;

DELIMITER //
CREATE EVENT ev_limpiar_auditoria_antigua
ON SCHEDULE EVERY 1 MONTH
STARTS CURRENT_TIMESTAMP + INTERVAL 6 MONTH
ON COMPLETION PRESERVE
COMMENT 'Elimina registros de auditoría de más de 6 meses'
DO
BEGIN
    DELETE FROM auditoria
    WHERE fecha_hora < DATE_SUB(NOW(), INTERVAL 6 MONTH);
END //
DELIMITER ;


-- 13. ev_limpiar_historial_precios_antiguo
DROP EVENT IF EXISTS ev_limpiar_historial_precios_antiguo;

DELIMITER //
CREATE EVENT ev_limpiar_historial_precios_antiguo
ON SCHEDULE EVERY 1 MONTH
STARTS CURRENT_TIMESTAMP + INTERVAL 12 MONTH
ON COMPLETION PRESERVE
COMMENT 'Elimina historial de precios de más de 1 año'
DO
BEGIN
    DELETE FROM historial_precios
    WHERE fecha_cambio < DATE_SUB(NOW(), INTERVAL 12 MONTH);
END //
DELIMITER ;


-- 14. ev_rebuild_indexes
DROP EVENT IF EXISTS ev_rebuild_indexes;

DELIMITER //
CREATE EVENT ev_rebuild_indexes
ON SCHEDULE EVERY 7 DAY
STARTS CURRENT_TIMESTAMP
ON COMPLETION PRESERVE
COMMENT 'Reconstruye índices de tablas principales'
DO
BEGIN
    ALTER TABLE productos ENGINE=InnoDB;
    ALTER TABLE ventas ENGINE=InnoDB;
    ALTER TABLE detalle_ventas ENGINE=InnoDB;
    ALTER TABLE clientes ENGINE=InnoDB;
END //
DELIMITER ;


-- 15. ev_optimize_tables
DROP EVENT IF EXISTS ev_optimize_tables;

DELIMITER //
CREATE EVENT ev_optimize_tables
ON SCHEDULE EVERY 30 DAY
STARTS CURRENT_TIMESTAMP
ON COMPLETION PRESERVE
COMMENT 'Optimiza tablas para liberar espacio'
DO
BEGIN
    OPTIMIZE TABLE productos;
    OPTIMIZE TABLE ventas;
    OPTIMIZE TABLE detalle_ventas;
    OPTIMIZE TABLE clientes;
    OPTIMIZE TABLE categorias;
    OPTIMIZE TABLE proveedores;
END //
DELIMITER ;


-- 16. ev_backup_logico
DROP EVENT IF EXISTS ev_backup_logico;

DELIMITER //
CREATE EVENT ev_backup_logico
ON SCHEDULE EVERY 1 DAY
STARTS CURRENT_TIMESTAMP + INTERVAL 1 HOUR
ON COMPLETION PRESERVE
COMMENT 'Registra conteo de registros para monitoreo'
DO
BEGIN
    INSERT INTO auditoria (tabla_afectada, id_registro_afectado, accion, usuario_bd, fecha_hora, detalle)
    VALUES ('sistema', 0, 'INSERT', 'EVENT_SCHEDULER', NOW(),
            CONCAT('BACKUP LOG: productos=', (SELECT COUNT(*) FROM productos),
                   ', ventas=', (SELECT COUNT(*) FROM ventas),
                   ', clientes=', (SELECT COUNT(*) FROM clientes)));
END //
DELIMITER ;


-- =============================================================================
-- GRUPO 6: Eventos de seguridad y monitoreo
-- =============================================================================

-- 17. ev_limpiar_intentos_login
DROP EVENT IF EXISTS ev_limpiar_intentos_login;

DELIMITER //
CREATE EVENT ev_limpiar_intentos_login
ON SCHEDULE EVERY 7 DAY
STARTS CURRENT_TIMESTAMP
ON COMPLETION PRESERVE
COMMENT 'Limpia intentos de login fallidos antiguos'
DO
BEGIN
    DELETE FROM intentos_login_fallidos
    WHERE fecha_intento < DATE_SUB(NOW(), INTERVAL 30 DAY);
END //
DELIMITER ;


-- 18. ev_detectar_actividad_sospechosa
DROP EVENT IF EXISTS ev_detectar_actividad_sospechosa;

DELIMITER //
CREATE EVENT ev_detectar_actividad_sospechosa
ON SCHEDULE EVERY 1 HOUR
STARTS CURRENT_TIMESTAMP
ON COMPLETION PRESERVE
COMMENT 'Detecta clientes con muchas ventas canceladas'
DO
BEGIN
    INSERT INTO auditoria (tabla_afectada, id_registro_afectado, accion, usuario_bd, fecha_hora, detalle)
    SELECT 'ventas', id_cliente, 'UPDATE', 'EVENT_SCHEDULER', NOW(),
           CONCAT('SOSPECHOSO: ', (SELECT CONCAT(nombre,' ',apellido) FROM clientes WHERE id_cliente = v.id_cliente LIMIT 1),
                  ' - ', COUNT(*), ' ventas canceladas')
    FROM ventas v
    WHERE v.estado = 'cancelada'
      AND v.fecha >= DATE_SUB(NOW(), INTERVAL 24 HOUR)
    GROUP BY id_cliente
    HAVING COUNT(*) >= 3;
END //
DELIMITER ;


-- 19. ev_reporte_proveedores
DROP EVENT IF EXISTS ev_reporte_proveedores;

DELIMITER //
CREATE EVENT ev_reporte_proveedores
ON SCHEDULE EVERY 30 DAY
STARTS CURRENT_TIMESTAMP
ON COMPLETION PRESERVE
COMMENT 'Genera reporte mensual de proveedores'
DO
BEGIN
    INSERT INTO auditoria (tabla_afectada, id_registro_afectado, accion, usuario_bd, fecha_hora, detalle)
    SELECT 'proveedores', p.id_proveedor, 'INSERT', 'EVENT_SCHEDULER', NOW(),
           CONCAT('PROVEEDOR: ', p.nombre, ' - Productos: ', 
                  (SELECT COUNT(*) FROM productos WHERE id_proveedor = p.id_proveedor))
    FROM proveedores p;
END //
DELIMITER ;


-- 20. ev_purge_soft_deleted
-- CORRECCIÓN: la versión anterior podía fallar completa con error de FK
-- (ON DELETE RESTRICT) si algún producto inactivo ya tenía ventas o
-- historial de precios asociado. Ahora excluye esos productos del borrado
-- físico, dejándolos solo como inactivos (soft-delete permanente), que es
-- el comportamiento correcto para preservar el historial de ventas.
DROP EVENT IF EXISTS ev_purge_soft_deleted;

DELIMITER //
CREATE EVENT ev_purge_soft_deleted
ON SCHEDULE EVERY 30 DAY
STARTS CURRENT_TIMESTAMP
ON COMPLETION PRESERVE
COMMENT 'Elimina físicamente productos inactivos sin historial asociado'
DO
BEGIN
    DELETE p FROM productos p
    WHERE p.activo = 0
      AND p.fecha_modificacion < DATE_SUB(NOW(), INTERVAL 30 DAY)
      AND NOT EXISTS (SELECT 1 FROM detalle_ventas dv WHERE dv.id_producto = p.id_producto)
      AND NOT EXISTS (SELECT 1 FROM historial_precios hp WHERE hp.id_producto = p.id_producto);
END //
DELIMITER ;


-- =============================================================================
-- VERIFICACIÓN
-- =============================================================================

SELECT '=== EVENTOS CREADOS ===' AS seccion;
SHOW EVENTS FROM EcommerceDB;

SELECT '=== EVENT SCHEDULER STATUS ===' AS seccion;
SHOW VARIABLES LIKE 'event_scheduler';


-- =============================================================================
-- FIN DEL ARCHIVO 06_Eventos.sql
-- =============================================================================