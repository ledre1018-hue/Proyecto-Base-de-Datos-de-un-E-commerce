USE EcommerceDB;

-- Drop triggers que usan columnas incorrectas
DROP TRIGGER IF EXISTS trg_log_new_customer_after_insert;
DROP TRIGGER IF EXISTS trg_audit_product_insert;
DROP TRIGGER IF EXISTS trg_audit_product_delete;
DROP TRIGGER IF EXISTS trg_send_stock_alert_on_low_stock;
DROP TRIGGER IF EXISTS trg_audit_venta_insert;
DROP TRIGGER IF EXISTS trg_log_order_status_change;
DROP TRIGGER IF EXISTS trg_archive_deleted_venta;
DROP TRIGGER IF EXISTS trg_audit_precio_producto_after_update;

-- Recrear con columnas correctas

-- 1. trg_log_new_customer_after_insert
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

-- 2. trg_audit_product_insert
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

-- 3. trg_audit_product_delete
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

-- 4. trg_send_stock_alert_on_low_stock
DELIMITER //
CREATE TRIGGER trg_send_stock_alert_on_low_stock
AFTER UPDATE ON productos
FOR EACH ROW
BEGIN
    IF NEW.stock <= NEW.stock_minimo AND OLD.stock > OLD.stock_minimo THEN
        INSERT INTO auditoria (tabla_afectada, id_registro_afectado, accion, usuario_bd, fecha_hora, detalle)
        VALUES ('productos', NEW.id_producto, 'UPDATE', CURRENT_USER(), NOW(),
                CONCAT('ALERTA STOCK: ', NEW.stock, ' (min: ', NEW.stock_minimo, ') - ', NEW.nombre));
    END IF;
END //
DELIMITER ;

-- 5. trg_audit_venta_insert
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

-- 6. trg_log_order_status_change
DELIMITER //
CREATE TRIGGER trg_log_order_status_change
AFTER UPDATE ON ventas
FOR EACH ROW
BEGIN
    IF OLD.estado <> NEW.estado THEN
        INSERT INTO auditoria (tabla_afectada, id_registro_afectado, accion, usuario_bd, fecha_hora, detalle)
        VALUES ('ventas', NEW.id_venta, 'UPDATE', CURRENT_USER(), NOW(),
                CONCAT('Estado: "', OLD.estado, '" -> "', NEW.estado, '"'));
    END IF;
END //
DELIMITER ;

-- 7. trg_archive_deleted_venta
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

-- 8. trg_audit_precio_producto_after_update (sin columna motivo)
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

SELECT 'Triggers corregidos exitosamente' AS resultado;
