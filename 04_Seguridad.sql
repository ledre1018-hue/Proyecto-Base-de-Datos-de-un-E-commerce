-- =============================================================================
-- 04_Seguridad.sql
-- Proyecto: EcommerceDB
-- Autor: Leonel Escalona
-- Descripción: Roles, usuarios, permisos y políticas de seguridad
-- =============================================================================

USE EcommerceDB;

-- =============================================================================
-- SECCIÓN 1: LIMPIEZA
-- =============================================================================

DROP USER IF EXISTS 'admin_user'@'%';
DROP USER IF EXISTS 'marketing_user'@'%';
DROP USER IF EXISTS 'inventory_user'@'%';
DROP USER IF EXISTS 'support_user'@'%';
DROP USER IF EXISTS 'analista_user'@'%';
DROP USER IF EXISTS 'auditor_user'@'%';
DROP USER IF EXISTS 'visitante_user'@'%';

DROP ROLE IF EXISTS 'Administrador_Sistema';
DROP ROLE IF EXISTS 'Gerente_Marketing';
DROP ROLE IF EXISTS 'Analista_Datos';
DROP ROLE IF EXISTS 'Empleado_Inventario';
DROP ROLE IF EXISTS 'Atencion_Cliente';
DROP ROLE IF EXISTS 'Auditor_Financiero';
DROP ROLE IF EXISTS 'Visitante';


-- =============================================================================
-- SECCIÓN 2: CREACIÓN DE ROLES
-- =============================================================================

CREATE ROLE IF NOT EXISTS 'Administrador_Sistema';
GRANT ALL PRIVILEGES ON EcommerceDB.* TO 'Administrador_Sistema';

CREATE ROLE IF NOT EXISTS 'Gerente_Marketing';
GRANT SELECT ON EcommerceDB.ventas TO 'Gerente_Marketing';
GRANT SELECT ON EcommerceDB.clientes TO 'Gerente_Marketing';
GRANT SELECT ON EcommerceDB.detalle_ventas TO 'Gerente_Marketing';
GRANT SELECT ON EcommerceDB.productos TO 'Gerente_Marketing';
GRANT SELECT ON EcommerceDB.vw_clientes_resumen TO 'Gerente_Marketing';
GRANT SELECT ON EcommerceDB.vw_catalogo_publico TO 'Gerente_Marketing';

CREATE ROLE IF NOT EXISTS 'Analista_Datos';
GRANT SELECT ON EcommerceDB.categorias TO 'Analista_Datos';
GRANT SELECT ON EcommerceDB.proveedores TO 'Analista_Datos';
GRANT SELECT ON EcommerceDB.sucursales TO 'Analista_Datos';
GRANT SELECT ON EcommerceDB.productos TO 'Analista_Datos';
GRANT SELECT ON EcommerceDB.clientes TO 'Analista_Datos';
GRANT SELECT ON EcommerceDB.ventas TO 'Analista_Datos';
GRANT SELECT ON EcommerceDB.detalle_ventas TO 'Analista_Datos';
GRANT SELECT ON EcommerceDB.historial_precios TO 'Analista_Datos';
GRANT SELECT ON EcommerceDB.vw_clientes_resumen TO 'Analista_Datos';
GRANT SELECT ON EcommerceDB.vw_catalogo_publico TO 'Analista_Datos';

CREATE ROLE IF NOT EXISTS 'Empleado_Inventario';
GRANT SELECT ON EcommerceDB.productos TO 'Empleado_Inventario';
GRANT UPDATE (stock, stock_minimo, activo) ON EcommerceDB.productos TO 'Empleado_Inventario';
GRANT SELECT ON EcommerceDB.categorias TO 'Empleado_Inventario';
GRANT SELECT ON EcommerceDB.proveedores TO 'Empleado_Inventario';

CREATE ROLE IF NOT EXISTS 'Atencion_Cliente';
GRANT SELECT ON EcommerceDB.vw_clientes_resumen TO 'Atencion_Cliente';
GRANT SELECT ON EcommerceDB.ventas TO 'Atencion_Cliente';
GRANT SELECT ON EcommerceDB.detalle_ventas TO 'Atencion_Cliente';
GRANT SELECT ON EcommerceDB.productos TO 'Atencion_Cliente';
GRANT SELECT ON EcommerceDB.vw_catalogo_publico TO 'Atencion_Cliente';

CREATE ROLE IF NOT EXISTS 'Auditor_Financiero';
GRANT SELECT ON EcommerceDB.ventas TO 'Auditor_Financiero';
GRANT SELECT ON EcommerceDB.detalle_ventas TO 'Auditor_Financiero';
GRANT SELECT ON EcommerceDB.productos TO 'Auditor_Financiero';
GRANT SELECT ON EcommerceDB.historial_precios TO 'Auditor_Financiero';
GRANT SELECT ON EcommerceDB.auditoria TO 'Auditor_Financiero';

CREATE ROLE IF NOT EXISTS 'Visitante';
GRANT SELECT ON EcommerceDB.vw_catalogo_publico TO 'Visitante';


-- =============================================================================
-- SECCIÓN 3: CREACIÓN DE USUARIOS
-- =============================================================================

CREATE USER IF NOT EXISTS 'admin_user'@'%'
    IDENTIFIED BY 'Admin#2026Secure!'
    PASSWORD EXPIRE INTERVAL 90 DAY;
GRANT 'Administrador_Sistema' TO 'admin_user'@'%';
SET DEFAULT ROLE 'Administrador_Sistema' TO 'admin_user'@'%';

CREATE USER IF NOT EXISTS 'marketing_user'@'%'
    IDENTIFIED BY 'Mkt$Marketing2026'
    PASSWORD EXPIRE INTERVAL 90 DAY;
GRANT 'Gerente_Marketing' TO 'marketing_user'@'%';
SET DEFAULT ROLE 'Gerente_Marketing' TO 'marketing_user'@'%';

CREATE USER IF NOT EXISTS 'inventory_user'@'%'
    IDENTIFIED BY 'Inv#Inventario26'
    PASSWORD EXPIRE INTERVAL 90 DAY;
GRANT 'Empleado_Inventario' TO 'inventory_user'@'%';
SET DEFAULT ROLE 'Empleado_Inventario' TO 'inventory_user'@'%';

CREATE USER IF NOT EXISTS 'support_user'@'%'
    IDENTIFIED BY 'Sup@Soporte2026!'
    PASSWORD EXPIRE INTERVAL 90 DAY;
GRANT 'Atencion_Cliente' TO 'support_user'@'%';
SET DEFAULT ROLE 'Atencion_Cliente' TO 'support_user'@'%';

CREATE USER IF NOT EXISTS 'analista_user'@'%'
    IDENTIFIED BY 'An@lisis2026Data'
    PASSWORD EXPIRE INTERVAL 90 DAY;
GRANT 'Analista_Datos' TO 'analista_user'@'%';
SET DEFAULT ROLE 'Analista_Datos' TO 'analista_user'@'%';

CREATE USER IF NOT EXISTS 'auditor_user'@'%'
    IDENTIFIED BY 'Aud!Finanzas2026'
    PASSWORD EXPIRE INTERVAL 90 DAY;
GRANT 'Auditor_Financiero' TO 'auditor_user'@'%';
SET DEFAULT ROLE 'Auditor_Financiero' TO 'auditor_user'@'%';

CREATE USER IF NOT EXISTS 'visitante_user'@'%'
    IDENTIFIED BY 'Vis!itante2026'
    PASSWORD EXPIRE INTERVAL 90 DAY;
GRANT 'Visitante' TO 'visitante_user'@'%';
SET DEFAULT ROLE 'Visitante' TO 'visitante_user'@'%';


-- =============================================================================
-- SECCIÓN 4: VISTA PARA OCULTAR INFORMACIÓN SENSIBLE
-- =============================================================================

DROP VIEW IF EXISTS v_info_clientes_basica;

CREATE VIEW v_info_clientes_basica AS
SELECT
    id_cliente,
    nombre,
    apellido,
    email,
    ciudad,
    region,
    fecha_registro,
    fn_DeterminarEstadoLealtad(id_cliente) AS estado_lealtad,
    fn_ContarVentasCliente(id_cliente) AS total_compras
FROM clientes
WHERE activo = 1;

GRANT SELECT ON EcommerceDB.v_info_clientes_basica TO 'Atencion_Cliente';
GRANT SELECT ON EcommerceDB.v_info_clientes_basica TO 'Gerente_Marketing';


-- =============================================================================
-- SECCIÓN 5: POLÍTICAS DE SEGURIDAD ADICIONALES
-- =============================================================================

ALTER USER 'analista_user'@'%' WITH MAX_QUERIES_PER_HOUR 500;

DROP TABLE IF EXISTS intentos_login_fallidos;

CREATE TABLE intentos_login_fallidos (
    id_intento INT AUTO_INCREMENT PRIMARY KEY,
    usuario_intento VARCHAR(100) NOT NULL,
    host_origen VARCHAR(45) NOT NULL,
    fecha_intento DATETIME DEFAULT CURRENT_TIMESTAMP,
    motivo VARCHAR(255),
    INDEX idx_fecha (fecha_intento),
    INDEX idx_usuario (usuario_intento)
) ENGINE=InnoDB;


-- =============================================================================
-- SECCIÓN 6: VERIFICACIÓN
-- =============================================================================

SELECT '=== USUARIOS CREADOS ===' AS seccion;
SELECT user, host FROM mysql.user 
WHERE user IN ('admin_user','marketing_user','inventory_user','support_user',
               'analista_user','auditor_user','visitante_user')
ORDER BY user;

SELECT '=== GRANTS DE admin_user ===' AS seccion;
SHOW GRANTS FOR 'admin_user'@'%';

SELECT '=== GRANTS DE inventory_user ===' AS seccion;
SHOW GRANTS FOR 'inventory_user'@'%';

SELECT '=== VISTA v_info_clientes_basica ===' AS seccion;
SELECT * FROM v_info_clientes_basica LIMIT 5;


-- =============================================================================
-- NOTA: El GRANT EXECUTE sobre procedimientos se otorgará en 07_Procedimientos_Almacenados.sql
-- =============================================================================

-- =============================================================================
-- FIN DEL ARCHIVO 04_Seguridad.sql
-- =============================================================================
