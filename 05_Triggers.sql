-- =============================================================================
-- 05_Triggers.sql
-- Proyecto: EcommerceDB
-- Autor: Leonel Escalona
-- Descripción: 21 triggers para automatización e integridad de datos
-- Tablas usadas: productos, categorias, clientes, ventas, detalle_ventas,
--                historial_precios, auditoria

USE EcommerceDB;

-- -----------------------------------------------------------------------------
-- 0. ALTERACIONES DE ESQUEMA NECESARIAS PARA ESTE ARCHIVO
-- (columnas derivadas mantenidas por trigger/evento, ver justificación arriba)
-- NOTA: "ADD COLUMN IF NOT EXISTS" requiere MySQL 8.0.29 o superior.
-- Si tu instancia es más antigua, quita "IF NOT EXISTS" de las 3 líneas
-- siguientes (el DROP DATABASE de 01 garantiza que el ALTER solo corre una vez
-- en una instalación limpia).
-- -----------------------------------------------------------------------------
ALTER TABLE clientes
    ADD COLUMN IF NOT EXISTS ultima_compra DATETIME NULL
        COMMENT 'Mantenido por trigger; fuente de verdad: MAX(ventas.fecha)',
    ADD COLUMN IF NOT EXISTS estado_lealtad ENUM('Bronce','Plata','Oro') NOT NULL DEFAULT 'Bronce'
        COMMENT 'Mantenido por trigger/evento; fuente de verdad: fn_DeterminarEstadoLealtad()';

ALTER TABLE categorias
    ADD COLUMN IF NOT EXISTS contador_productos INT NOT NULL DEFAULT 0
        COMMENT 'Mantenido por trigger; fuente de verdad: COUNT(productos activos)';

-- Inicializar los valores derivados a partir de los datos ya cargados en 01/02
UPDATE clientes c
SET c.ultima_compra = (
        SELECT MAX(v.fecha) FROM ventas v
        WHERE v.id_cliente = c.id_cliente AND v.estado = 'completada'
    );

UPDATE clientes c
SET c.estado_lealtad = CASE
    WHEN (SELECT COALESCE(SUM(v.total),0) FROM ventas v
          WHERE v.id_cliente = c.id_cliente AND v.estado = 'completada') >= 2000000 THEN 'Oro'
    WHEN (SELECT COALESCE(SUM(v.total),0) FROM ventas v
          WHERE v.id_cliente = c.id_cliente AND v.estado = 'completada') >= 500000 THEN 'Plata'
    ELSE 'Bronce'
END;

UPDATE categorias c
SET c.contador_productos = (
        SELECT COUNT(*) FROM productos p
        WHERE p.id_categoria = c.id_categoria AND p.activo = 1
    );

-- =============================================================================
-- GRUPO 1: Triggers de productos (precios, stock, categoría)
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 1. trg_audit_precio_producto_after_update
-- Registra cambios de precio en historial_precios
-- -----------------------------------------------------------------------------
DROP TRIGGER IF EXISTS trg_audit_precio_producto_after_update;

DELIMITER //

CREATE TRIGGER trg_audit_precio_producto_after_update
AFTER UPDATE ON productos
FOR EACH ROW
BEGIN
    IF OLD.precio <> NEW.precio THEN
        INSERT INTO historial_precios (id_producto, precio_anterior, precio_nuevo, fecha_cambio)
        VALUES (NEW.id_producto, OLD.precio, NEW.precio, NOW());
    END IF;
END //

DELIMITER ;


-- -----------------------------------------------------------------------------
-- 2. trg_prevent_price_zero_or_less
-- Impide que el precio sea cero o negativo
-- -----------------------------------------------------------------------------
DROP TRIGGER IF EXISTS trg_prevent_price_zero_or_less;

DELIMITER //

CREATE TRIGGER trg_prevent_price_zero_or_less
BEFORE UPDATE ON productos
FOR EACH ROW
BEGIN
    IF NEW.precio <= 0 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'El precio del producto debe ser mayor a cero';
    END IF;
END //

DELIMITER ;


-- -----------------------------------------------------------------------------
-- 3. trg_prevent_negative_stock
-- Impide que el stock sea negativo
-- -----------------------------------------------------------------------------
DROP TRIGGER IF EXISTS trg_prevent_negative_stock;

DELIMITER //

CREATE TRIGGER trg_prevent_negative_stock
BEFORE UPDATE ON productos
FOR EACH ROW
BEGIN
    IF NEW.stock < 0 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'El stock no puede ser negativo';
    END IF;
END //

DELIMITER ;


-- -----------------------------------------------------------------------------
-- 4. trg_set_fecha_modificacion_producto
-- Actualiza fecha_modificacion automáticamente
-- -----------------------------------------------------------------------------
DROP TRIGGER IF EXISTS trg_set_fecha_modificacion_producto;

DELIMITER //

CREATE TRIGGER trg_set_fecha_modificacion_producto
BEFORE UPDATE ON productos
FOR EACH ROW
BEGIN
    SET NEW.fecha_modificacion = NOW();
END //

DELIMITER ;


-- -----------------------------------------------------------------------------
-- 5. trg_assign_default_category_on_null
-- Asigna categoría "General" si se inserta producto sin categoría.
-- Nota: id_categoria es NOT NULL en el esquema, por lo que este trigger solo
-- actúa como defensa si en el futuro la columna se vuelve nullable.
-- -----------------------------------------------------------------------------
DROP TRIGGER IF EXISTS trg_assign_default_category_on_null;

DELIMITER //

CREATE TRIGGER trg_assign_default_category_on_null
BEFORE INSERT ON productos
FOR EACH ROW
BEGIN
    IF NEW.id_categoria IS NULL THEN
        SET NEW.id_categoria = (SELECT id_categoria FROM categorias WHERE nombre = 'General' LIMIT 1);
    END IF;
END //

DELIMITER ;


-- -----------------------------------------------------------------------------
-- 6. trg_update_producto_count_in_categoria (INSERT y DELETE)
-- Mantiene el contador de productos por categoría
-- -----------------------------------------------------------------------------
DROP TRIGGER IF EXISTS trg_update_producto_count_in_categoria_insert;

DELIMITER //

CREATE TRIGGER trg_update_producto_count_in_categoria_insert
AFTER INSERT ON productos
FOR EACH ROW
BEGIN
    IF NEW.id_categoria IS NOT NULL AND NEW.activo = 1 THEN
        UPDATE categorias
        SET contador_productos = contador_productos + 1
        WHERE id_categoria = NEW.id_categoria;
    END IF;
END //

DELIMITER ;

DROP TRIGGER IF EXISTS trg_update_producto_count_in_categoria_delete;

DELIMITER //

CREATE TRIGGER trg_update_producto_count_in_categoria_delete
AFTER DELETE ON productos
FOR EACH ROW
BEGIN
    IF OLD.id_categoria IS NOT NULL AND OLD.activo = 1 THEN
        UPDATE categorias
        SET contador_productos = GREATEST(contador_productos - 1, 0)
        WHERE id_categoria = OLD.id_categoria;
    END IF;
END //

DELIMITER ;


-- -----------------------------------------------------------------------------
-- 7. trg_prevent_delete_categoria_with_products
-- Impide eliminar categoría si tiene productos asociados
-- -----------------------------------------------------------------------------
DROP TRIGGER IF EXISTS trg_prevent_delete_categoria_with_products;

DELIMITER //

CREATE TRIGGER trg_prevent_delete_categoria_with_products
BEFORE DELETE ON categorias
FOR EACH ROW
BEGIN
    DECLARE v_count INT;
    SELECT COUNT(*) INTO v_count FROM productos WHERE id_categoria = OLD.id_categoria;
    IF v_count > 0 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'No se puede eliminar la categoría porque tiene productos asociados';
    END IF;
END //

DELIMITER ;


-- =============================================================================
-- GRUPO 2: Triggers de clientes
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 8. trg_log_new_customer_after_insert
-- Registra nuevo cliente en tabla auditoria
-- -----------------------------------------------------------------------------
DROP TRIGGER IF EXISTS trg_log_new_customer_after_insert;

DELIMITER //

CREATE TRIGGER trg_log_new_customer_after_insert
AFTER INSERT ON clientes
FOR EACH ROW
BEGIN
    INSERT INTO auditoria (tabla_afectada, id_registro_afectado, accion, usuario_bd, fecha_hora, detalle)
    VALUES ('clientes', NEW.id_cliente, 'INSERT', CURRENT_USER(), NOW(),
            CONCAT('Nuevo cliente: ', NEW.nombre, ' ', NEW.apellido));
END //

DELIMITER ;


-- -----------------------------------------------------------------------------
-- 9. trg_capitalize_nombre_cliente
-- Capitaliza primera letra de nombre y apellido
-- -----------------------------------------------------------------------------
DROP TRIGGER IF EXISTS trg_capitalize_nombre_cliente;

DELIMITER //

CREATE TRIGGER trg_capitalize_nombre_cliente
BEFORE INSERT ON clientes
FOR EACH ROW
BEGIN
    SET NEW.nombre = CONCAT(UPPER(LEFT(NEW.nombre, 1)), LOWER(SUBSTRING(NEW.nombre, 2)));
    SET NEW.apellido = CONCAT(UPPER(LEFT(NEW.apellido, 1)), LOWER(SUBSTRING(NEW.apellido, 2)));
END //

DELIMITER ;


-- -----------------------------------------------------------------------------
-- 10. trg_validate_email_format_on_customer
-- Valida formato de email antes de insertar
-- -----------------------------------------------------------------------------
DROP TRIGGER IF EXISTS trg_validate_email_format_on_customer;

DELIMITER //

CREATE TRIGGER trg_validate_email_format_on_customer
BEFORE INSERT ON clientes
FOR EACH ROW
BEGIN
    IF NEW.email NOT REGEXP '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}$' THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'El formato del email no es válido';
    END IF;
END //

DELIMITER ;


-- -----------------------------------------------------------------------------
-- 11. trg_update_last_order_date_customer
-- Actualiza ultima_compra y estado_lealtad del cliente cuando se completa
-- una venta (columnas ya agregadas en la sección 0 de este archivo).
-- -----------------------------------------------------------------------------
DROP TRIGGER IF EXISTS trg_update_last_order_date_customer;

DELIMITER //

CREATE TRIGGER trg_update_last_order_date_customer
AFTER UPDATE ON ventas
FOR EACH ROW
BEGIN
    IF NEW.estado = 'completada' AND OLD.estado <> 'completada' THEN
        UPDATE clientes
        SET ultima_compra = NEW.fecha,
            estado_lealtad = CASE
                WHEN (SELECT COALESCE(SUM(total),0) FROM ventas
                      WHERE id_cliente = NEW.id_cliente AND estado = 'completada') >= 2000000 THEN 'Oro'
                WHEN (SELECT COALESCE(SUM(total),0) FROM ventas
                      WHERE id_cliente = NEW.id_cliente AND estado = 'completada') >= 500000 THEN 'Plata'
                ELSE 'Bronce'
            END
        WHERE id_cliente = NEW.id_cliente;
    END IF;
END //

DELIMITER ;


-- =============================================================================
-- GRUPO 3: Triggers de ventas y detalle_ventas
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 12. trg_check_stock_before_insert_venta
-- Valida stock suficiente antes de insertar detalle de venta
-- (defensa de integridad de respaldo, ver decisión de Etapa 0)
-- -----------------------------------------------------------------------------
DROP TRIGGER IF EXISTS trg_check_stock_before_insert_venta;

DELIMITER //

CREATE TRIGGER trg_check_stock_before_insert_venta
BEFORE INSERT ON detalle_ventas
FOR EACH ROW
BEGIN
    DECLARE v_stock INT;
    SELECT stock INTO v_stock FROM productos WHERE id_producto = NEW.id_producto;
    IF v_stock IS NULL OR v_stock < NEW.cantidad THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Stock insuficiente para el producto';
    END IF;
END //

DELIMITER ;


-- -----------------------------------------------------------------------------
-- 13. trg_update_stock_after_insert_venta
-- Descuenta stock después de insertar detalle de venta
-- -----------------------------------------------------------------------------
DROP TRIGGER IF EXISTS trg_update_stock_after_insert_venta;

DELIMITER //

CREATE TRIGGER trg_update_stock_after_insert_venta
AFTER INSERT ON detalle_ventas
FOR EACH ROW
BEGIN
    UPDATE productos
    SET stock = stock - NEW.cantidad
    WHERE id_producto = NEW.id_producto;
END //

DELIMITER ;


-- -----------------------------------------------------------------------------
-- 14. trg_recalculate_total_venta_on_detalle_change
-- Recalcula total de venta cuando se inserta un detalle
-- -----------------------------------------------------------------------------
DROP TRIGGER IF EXISTS trg_recalculate_total_venta_on_detalle_change;

DELIMITER //

CREATE TRIGGER trg_recalculate_total_venta_on_detalle_change
AFTER INSERT ON detalle_ventas
FOR EACH ROW
BEGIN
    UPDATE ventas
    SET total = (
        SELECT COALESCE(SUM(subtotal), 0.00)
        FROM detalle_ventas
        WHERE id_venta = NEW.id_venta
    )
    WHERE id_venta = NEW.id_venta;
END //

DELIMITER ;


-- -----------------------------------------------------------------------------
-- 15. trg_log_order_status_change
-- Audita cambios de estado en ventas
-- -----------------------------------------------------------------------------
DROP TRIGGER IF EXISTS trg_log_order_status_change;

DELIMITER //

CREATE TRIGGER trg_log_order_status_change
AFTER UPDATE ON ventas
FOR EACH ROW
BEGIN
    IF OLD.estado <> NEW.estado THEN
        INSERT INTO auditoria (tabla_afectada, id_registro_afectado, accion, usuario_bd, fecha_hora, detalle)
        VALUES ('ventas', NEW.id_venta, 'UPDATE', CURRENT_USER(), NOW(),
                CONCAT('Estado cambió de "', OLD.estado, '" a "', NEW.estado, '"'));
    END IF;
END //

DELIMITER ;


-- -----------------------------------------------------------------------------
-- 16. trg_archive_deleted_venta
-- Registra venta eliminada en auditoria (log de borrado)
-- -----------------------------------------------------------------------------
DROP TRIGGER IF EXISTS trg_archive_deleted_venta;

DELIMITER //

CREATE TRIGGER trg_archive_deleted_venta
BEFORE DELETE ON ventas
FOR EACH ROW
BEGIN
    INSERT INTO auditoria (tabla_afectada, id_registro_afectado, accion, usuario_bd, fecha_hora, detalle)
    VALUES ('ventas', OLD.id_venta, 'DELETE', CURRENT_USER(), NOW(),
            CONCAT('Venta eliminada - Cliente: ', OLD.id_cliente, ', Total: ', OLD.total));
END //

DELIMITER ;


-- =============================================================================
-- GRUPO 4: Triggers de auditoría general
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 17. trg_audit_product_insert
-- Registra inserción de producto en auditoria
-- -----------------------------------------------------------------------------
DROP TRIGGER IF EXISTS trg_audit_product_insert;

DELIMITER //

CREATE TRIGGER trg_audit_product_insert
AFTER INSERT ON productos
FOR EACH ROW
BEGIN
    INSERT INTO auditoria (tabla_afectada, id_registro_afectado, accion, usuario_bd, fecha_hora, detalle)
    VALUES ('productos', NEW.id_producto, 'INSERT', CURRENT_USER(), NOW(),
            CONCAT('Producto creado: ', NEW.nombre, ' - Precio: ', NEW.precio));
END //

DELIMITER ;


-- -----------------------------------------------------------------------------
-- 18. trg_audit_product_delete
-- Registra eliminación de producto en auditoria
-- -----------------------------------------------------------------------------
DROP TRIGGER IF EXISTS trg_audit_product_delete;

DELIMITER //

CREATE TRIGGER trg_audit_product_delete
BEFORE DELETE ON productos
FOR EACH ROW
BEGIN
    INSERT INTO auditoria (tabla_afectada, id_registro_afectado, accion, usuario_bd, fecha_hora, detalle)
    VALUES ('productos', OLD.id_producto, 'DELETE', CURRENT_USER(), NOW(),
            CONCAT('Producto eliminado: ', OLD.nombre));
END //

DELIMITER ;


-- -----------------------------------------------------------------------------
-- 19. trg_audit_venta_insert
-- Registra creación de venta en auditoria
-- -----------------------------------------------------------------------------
DROP TRIGGER IF EXISTS trg_audit_venta_insert;

DELIMITER //

CREATE TRIGGER trg_audit_venta_insert
AFTER INSERT ON ventas
FOR EACH ROW
BEGIN
    INSERT INTO auditoria (tabla_afectada, id_registro_afectado, accion, usuario_bd, fecha_hora, detalle)
    VALUES ('ventas', NEW.id_venta, 'INSERT', CURRENT_USER(), NOW(),
            CONCAT('Venta creada - Cliente: ', NEW.id_cliente, ', Total: ', NEW.total));
END //

DELIMITER ;


-- -----------------------------------------------------------------------------
-- 20. trg_send_stock_alert_on_low_stock
-- Registra alerta en auditoria cuando stock baja del mínimo
-- -----------------------------------------------------------------------------
DROP TRIGGER IF EXISTS trg_send_stock_alert_on_low_stock;

DELIMITER //

CREATE TRIGGER trg_send_stock_alert_on_low_stock
AFTER UPDATE ON productos
FOR EACH ROW
BEGIN
    IF NEW.stock <= NEW.stock_minimo AND OLD.stock > OLD.stock_minimo THEN
        INSERT INTO auditoria (tabla_afectada, id_registro_afectado, accion, usuario_bd, fecha_hora, detalle)
        VALUES ('productos', NEW.id_producto, 'UPDATE', CURRENT_USER(), NOW(),
                CONCAT('ALERTA STOCK BAJO: ', NEW.stock, ' (mínimo: ', NEW.stock_minimo, ') - Producto: ', NEW.nombre));
    END IF;
END //

DELIMITER ;


-- -----------------------------------------------------------------------------
-- 21. trg_update_categoria_count_on_producto_categoria_change
-- Ajusta los contadores de ambas categorías cuando un producto cambia de
-- categoría (ej. mediante sp_mover_productos_entre_categorias en 07)
-- -----------------------------------------------------------------------------
DROP TRIGGER IF EXISTS trg_update_categoria_count_on_producto_categoria_change;

DELIMITER //

CREATE TRIGGER trg_update_categoria_count_on_producto_categoria_change
AFTER UPDATE ON productos
FOR EACH ROW
BEGIN
    IF NEW.id_categoria <> OLD.id_categoria AND NEW.activo = 1 THEN
        UPDATE categorias SET contador_productos = GREATEST(contador_productos - 1, 0)
        WHERE id_categoria = OLD.id_categoria;
        UPDATE categorias SET contador_productos = contador_productos + 1
        WHERE id_categoria = NEW.id_categoria;
    END IF;
END //

DELIMITER ;


-- =============================================================================
-- VERIFICACIÓN: Listar todos los triggers creados
-- =============================================================================

SELECT '=== TRIGGERS CREADOS ===' AS seccion;
SHOW TRIGGERS FROM EcommerceDB;

SELECT '=== VALORES DERIVADOS INICIALIZADOS ===' AS seccion;
SELECT id_cliente, nombre, ultima_compra, estado_lealtad FROM clientes LIMIT 5;
SELECT id_categoria, nombre, contador_productos FROM categorias;

-- =============================================================================
-- FIN DEL ARCHIVO 05_Triggers.sql
-- =============================================================================