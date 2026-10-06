-- ============================================================
-- 01_Esquema_y_Datos.sql
-- Proyecto: EcommerceDB
-- Proyecto académico de Base de Datos Avanzada
-- Motor: MySQL 8.0 / InnoDB
-- Independiente de cualquier otro taller de la carpeta Mysql/
-- ============================================================

-- ------------------------------------------------------------
-- 1. BASE DE DATOS
-- ------------------------------------------------------------
DROP DATABASE IF EXISTS EcommerceDB;
CREATE DATABASE EcommerceDB
    CHARACTER SET utf8mb4
    COLLATE utf8mb4_unicode_ci;

USE EcommerceDB;

-- ------------------------------------------------------------
-- 2. TABLAS PADRE (sin dependencias)
-- ------------------------------------------------------------

CREATE TABLE categorias (
    id_categoria   INT AUTO_INCREMENT PRIMARY KEY,
    nombre         VARCHAR(80)  NOT NULL,
    descripcion    VARCHAR(255),
    CONSTRAINT uq_categorias_nombre UNIQUE (nombre)
) ENGINE = InnoDB;

CREATE TABLE proveedores (
    id_proveedor   INT AUTO_INCREMENT PRIMARY KEY,
    nombre         VARCHAR(120) NOT NULL,
    email          VARCHAR(150),
    telefono       VARCHAR(30),
    direccion      VARCHAR(255),
    CONSTRAINT uq_proveedores_email UNIQUE (email)
) ENGINE = InnoDB;

CREATE TABLE sucursales (
    id_sucursal    INT AUTO_INCREMENT PRIMARY KEY,
    nombre         VARCHAR(80) NOT NULL,
    ciudad         VARCHAR(80) NOT NULL,
    direccion      VARCHAR(255),
    CONSTRAINT uq_sucursales_nombre UNIQUE (nombre)
) ENGINE = InnoDB;

CREATE TABLE clientes (
    id_cliente         INT AUTO_INCREMENT PRIMARY KEY,
    nombre             VARCHAR(80)  NOT NULL,
    apellido           VARCHAR(80)  NOT NULL,
    email              VARCHAR(150) NOT NULL,
    password_hash      CHAR(64)     NOT NULL COMMENT 'SHA2-256 de la contraseña, nunca texto plano',
    direccion_envio    VARCHAR(255),
    ciudad             VARCHAR(80),
    region             VARCHAR(80),
    fecha_nacimiento   DATE,
    fecha_registro     DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    activo             BOOLEAN  NOT NULL DEFAULT TRUE,
    CONSTRAINT uq_clientes_email UNIQUE (email)
) ENGINE = InnoDB;

CREATE TABLE auditoria (
    id_auditoria          INT AUTO_INCREMENT PRIMARY KEY,
    tabla_afectada        VARCHAR(60)  NOT NULL,
    id_registro_afectado  INT          NOT NULL,
    accion                ENUM('INSERT','UPDATE','DELETE') NOT NULL,
    usuario_bd            VARCHAR(100) NOT NULL,
    fecha_hora            DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    detalle               VARCHAR(500)
) ENGINE = InnoDB;

-- ------------------------------------------------------------
-- 3. TABLAS DEPENDIENTES (nivel 1)
-- ------------------------------------------------------------

CREATE TABLE productos (
    id_producto        INT AUTO_INCREMENT PRIMARY KEY,
    sku                VARCHAR(30)  NOT NULL,
    nombre             VARCHAR(150) NOT NULL,
    descripcion        VARCHAR(500),
    precio             DECIMAL(12,2) NOT NULL,
    costo              DECIMAL(12,2) NOT NULL,
    stock              INT NOT NULL DEFAULT 0,
    stock_minimo       INT NOT NULL DEFAULT 0,
    id_categoria       INT NOT NULL,
    id_proveedor       INT NOT NULL,
    activo             BOOLEAN NOT NULL DEFAULT TRUE,
    fecha_creacion     DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    fecha_modificacion DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
                        ON UPDATE CURRENT_TIMESTAMP,
    CONSTRAINT uq_productos_sku UNIQUE (sku),
    CONSTRAINT fk_productos_categoria
        FOREIGN KEY (id_categoria) REFERENCES categorias (id_categoria)
        ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT fk_productos_proveedor
        FOREIGN KEY (id_proveedor) REFERENCES proveedores (id_proveedor)
        ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT chk_productos_precio  CHECK (precio  >= 0),
    CONSTRAINT chk_productos_costo   CHECK (costo   >= 0),
    CONSTRAINT chk_productos_stock   CHECK (stock   >= 0),
    CONSTRAINT chk_productos_stockmin CHECK (stock_minimo >= 0)
) ENGINE = InnoDB;

CREATE TABLE ventas (
    id_venta      INT AUTO_INCREMENT PRIMARY KEY,
    id_cliente    INT NOT NULL,
    id_sucursal   INT NOT NULL,
    fecha         DATETIME NOT NULL,
    estado        ENUM('pendiente','completada','cancelada') NOT NULL DEFAULT 'pendiente',
    total         DECIMAL(14,2) NOT NULL DEFAULT 0,
    CONSTRAINT fk_ventas_cliente
        FOREIGN KEY (id_cliente) REFERENCES clientes (id_cliente)
        ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT fk_ventas_sucursal
        FOREIGN KEY (id_sucursal) REFERENCES sucursales (id_sucursal)
        ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT chk_ventas_total CHECK (total >= 0)
) ENGINE = InnoDB;

CREATE TABLE historial_precios (
    id_historial    INT AUTO_INCREMENT PRIMARY KEY,
    id_producto     INT NOT NULL,
    precio_anterior DECIMAL(12,2) NOT NULL,
    precio_nuevo    DECIMAL(12,2) NOT NULL,
    fecha_cambio    DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_historial_producto
        FOREIGN KEY (id_producto) REFERENCES productos (id_producto)
        ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE = InnoDB;

-- ------------------------------------------------------------
-- 4. TABLAS DEPENDIENTES (nivel 2)
-- ------------------------------------------------------------

CREATE TABLE detalle_ventas (
    id_detalle                 INT AUTO_INCREMENT PRIMARY KEY,
    id_venta                   INT NOT NULL,
    id_producto                INT NOT NULL,
    cantidad                   INT NOT NULL,
    precio_unitario_congelado  DECIMAL(12,2) NOT NULL,
    subtotal                   DECIMAL(14,2)
        GENERATED ALWAYS AS (cantidad * precio_unitario_congelado) STORED,
    CONSTRAINT fk_detalle_venta
        FOREIGN KEY (id_venta) REFERENCES ventas (id_venta)
        ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT fk_detalle_producto
        FOREIGN KEY (id_producto) REFERENCES productos (id_producto)
        ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT chk_detalle_cantidad CHECK (cantidad > 0),
    CONSTRAINT chk_detalle_precio   CHECK (precio_unitario_congelado >= 0)
) ENGINE = InnoDB;

-- ------------------------------------------------------------
-- 5. ÍNDICES ADICIONALES
-- ------------------------------------------------------------

CREATE INDEX idx_productos_categoria_activo ON productos (id_categoria, activo);
CREATE INDEX idx_ventas_fecha              ON ventas (fecha);
CREATE INDEX idx_ventas_cliente            ON ventas (id_cliente);
CREATE INDEX idx_ventas_estado             ON ventas (estado);
CREATE INDEX idx_detalle_producto          ON detalle_ventas (id_producto);
CREATE INDEX idx_historial_producto_fecha  ON historial_precios (id_producto, fecha_cambio);

-- ============================================================
-- 6. DATOS DE PRUEBA
-- ============================================================

-- ------------------------------------------------------------
-- 6.1 categorias
-- ------------------------------------------------------------
INSERT INTO categorias (id_categoria, nombre, descripcion) VALUES
(1, 'Electrónica', 'Dispositivos electrónicos y accesorios tecnológicos'),
(2, 'Hogar',       'Artículos para el hogar y decoración'),
(3, 'Deportes',    'Equipamiento e indumentaria deportiva'),
(4, 'Moda',        'Ropa y accesorios de vestir'),
(5, 'Libros',      'Libros físicos de distintos géneros');

-- ------------------------------------------------------------
-- 6.2 proveedores
-- ------------------------------------------------------------
INSERT INTO proveedores (id_proveedor, nombre, email, telefono, direccion) VALUES
(1, 'TechGlobal SA',        'ventas@techglobal.com',   '3001234567', 'Calle 10 # 20-30, Bogotá'),
(2, 'Hogar y Confort Ltda', 'contacto@hogarconfort.co','3012345678', 'Carrera 15 # 40-12, Medellín'),
(3, 'DeportesPro',          'info@deportespro.com',    '3023456789', 'Avenida 5 # 12-45, Cali'),
(4, 'ModaViva',             'pedidos@modaviva.co',     '3034567890', 'Calle 33 # 8-19, Barranquilla'),
(5, 'Editorial Andina',     'ventas@editorialandina.com','3045678901','Carrera 7 # 22-50, Bucaramanga');

-- ------------------------------------------------------------
-- 6.3 sucursales
-- ------------------------------------------------------------
INSERT INTO sucursales (id_sucursal, nombre, ciudad, direccion) VALUES
(1, 'Sucursal Centro', 'Bucaramanga', 'Carrera 20 # 15-40'),
(2, 'Sucursal Norte',  'Bogotá',      'Calle 100 # 15-20'),
(3, 'Sucursal Sur',    'Cali',        'Avenida 3N # 25-10');

-- ------------------------------------------------------------
-- 6.4 productos
-- ------------------------------------------------------------
INSERT INTO productos
(id_producto, sku, nombre, descripcion, precio, costo, stock, stock_minimo, id_categoria, id_proveedor, activo, fecha_creacion) VALUES
(1,  'ELEC-LAP-001', 'Laptop UltraSlim 14"',   'Laptop liviana para uso profesional',        3200000.00, 2500000.00, 25, 5,  1, 1, TRUE, '2025-01-05 09:00:00'),
(2,  'ELEC-MOU-002', 'Mouse Inalámbrico',       'Mouse óptico inalámbrico 2.4GHz',              45000.00,   25000.00, 100,15, 1, 1, TRUE, '2025-01-05 09:05:00'),
(3,  'ELEC-AUD-003', 'Audífonos Bluetooth',     'Audífonos con cancelación de ruido',          120000.00,   70000.00, 60, 10, 1, 1, TRUE, '2025-01-05 09:10:00'),
(4,  'ELEC-TV-004',  'Smart TV 50"',            'Televisor 4K con sistema operativo integrado',2100000.00,1600000.00, 12, 3,  1, 1, TRUE, '2025-01-06 10:00:00'),
(5,  'HOG-SAB-005',  'Juego de Sábanas',        'Juego de sábanas 100% algodón, cama doble',    85000.00,   40000.00, 40, 8,  2, 2, TRUE, '2025-01-10 08:00:00'),
(6,  'HOG-OLL-006',  'Set de Ollas',            'Set de 5 ollas antiadherentes',               250000.00,  150000.00, 20, 5,  2, 2, TRUE, '2025-01-10 08:15:00'),
(7,  'HOG-LAM-007',  'Lámpara de Mesa',         'Lámpara LED regulable de escritorio',          60000.00,   30000.00, 35, 8,  2, 2, TRUE, '2025-01-12 11:00:00'),
(8,  'DEP-BAL-008',  'Balón de Fútbol',         'Balón profesional talla 5',                     90000.00,   45000.00, 50, 10, 3, 3, TRUE, '2025-02-01 09:00:00'),
(9,  'DEP-BIC-009',  'Bicicleta Urbana',        'Bicicleta rodado 26 para ciudad',             1200000.00,  850000.00, 8,  2,  3, 3, TRUE, '2025-02-01 09:30:00'),
(10, 'DEP-TEN-010',  'Tenis Running',           'Tenis para correr, amortiguación media',       220000.00,  130000.00, 45, 10, 3, 3, TRUE, '2025-02-03 10:00:00'),
(11, 'MOD-CAM-011',  'Camiseta Deportiva',      'Camiseta transpirable unisex',                  55000.00,   25000.00, 70, 15, 4, 4, TRUE, '2025-02-10 08:00:00'),
(12, 'MOD-CHA-012',  'Chaqueta Impermeable',    'Chaqueta rompevientos e impermeable',          180000.00,  100000.00, 25, 5,  4, 4, TRUE, '2025-02-10 08:30:00'),
(13, 'MOD-JEA-013',  'Jeans Clásico',           'Jeans corte recto unisex',                     130000.00,   70000.00, 55, 10, 4, 4, TRUE, '2025-02-12 09:00:00'),
(14, 'LIB-NOV-014',  'Novela Contemporánea',    'Novela de ficción contemporánea, tapa blanda',  48000.00,   20000.00, 30, 5,  5, 5, TRUE, '2025-03-01 09:00:00'),
(15, 'LIB-COC-015',  'Libro de Cocina',         'Recetario de cocina internacional',             65000.00,   30000.00, 22, 5,  5, 5, TRUE, '2025-03-01 09:15:00');

-- ------------------------------------------------------------
-- 6.5 clientes
-- (password_hash generado con SHA2-256 sobre una contraseña de ejemplo)
-- ------------------------------------------------------------
INSERT INTO clientes
(id_cliente, nombre, apellido, email, password_hash, direccion_envio, ciudad, region, fecha_nacimiento, fecha_registro, activo) VALUES
(1,  'Laura',    'Ramírez',  'laura.ramirez@correo.com',   SHA2('Cliente1Pass!',256), 'Calle 45 # 12-30', 'Bucaramanga', 'Santander',       '1994-03-12', '2024-11-05 10:00:00', TRUE),
(2,  'Andrés',   'Gómez',    'andres.gomez@correo.com',    SHA2('Cliente2Pass!',256), 'Carrera 8 # 20-15', 'Bogotá',      'Cundinamarca',    '1990-07-22', '2024-11-10 11:00:00', TRUE),
(3,  'María',    'Torres',   'maria.torres@correo.com',    SHA2('Cliente3Pass!',256), 'Calle 70 # 5-40',  'Medellín',    'Antioquia',       '1988-01-30', '2024-11-15 09:30:00', TRUE),
(4,  'Carlos',   'Pérez',    'carlos.perez@correo.com',    SHA2('Cliente4Pass!',256), 'Avenida 9 # 30-22', 'Cali',        'Valle del Cauca', '1995-05-18', '2024-12-01 08:45:00', TRUE),
(5,  'Sofía',    'Martínez', 'sofia.martinez@correo.com',  SHA2('Cliente5Pass!',256), 'Calle 12 # 18-05', 'Bucaramanga', 'Santander',       '1997-09-09', '2024-12-05 14:00:00', TRUE),
(6,  'Juan',     'Rodríguez','juan.rodriguez@correo.com',  SHA2('Cliente6Pass!',256), 'Carrera 22 # 14-60','Barranquilla','Atlántico',      '1985-11-02', '2025-01-02 09:00:00', TRUE),
(7,  'Daniela',  'López',    'daniela.lopez@correo.com',   SHA2('Cliente7Pass!',256), 'Calle 5 # 9-80',   'Bogotá',      'Cundinamarca',    '1993-04-25', '2025-01-10 10:20:00', TRUE),
(8,  'Felipe',   'Castro',   'felipe.castro@correo.com',   SHA2('Cliente8Pass!',256), 'Carrera 30 # 10-11','Cali',       'Valle del Cauca', '1991-02-14', '2025-01-15 16:00:00', TRUE),
(9,  'Valentina','Herrera',  'valentina.herrera@correo.com',SHA2('Cliente9Pass!',256),'Calle 18 # 22-33', 'Medellín',    'Antioquia',       '1996-08-08', '2025-02-01 09:00:00', TRUE),
(10, 'Santiago', 'Vargas',   'santiago.vargas@correo.com', SHA2('Cliente10Pass!',256),'Carrera 4 # 6-70',  'Bucaramanga', 'Santander',       '1989-12-19', '2025-02-10 11:30:00', TRUE),
(11, 'Camila',   'Ortiz',    'camila.ortiz@correo.com',    SHA2('Cliente11Pass!',256),'Calle 60 # 25-14',  'Bogotá',      'Cundinamarca',    '1992-06-06', '2025-03-01 08:00:00', TRUE),
(12, 'Diego',    'Morales',  'diego.morales@correo.com',   SHA2('Cliente12Pass!',256),'Carrera 12 # 8-90', 'Barranquilla','Atlántico',       '1998-10-27', '2025-03-15 13:00:00', TRUE);

-- ------------------------------------------------------------
-- 6.6 ventas
-- (estado: pendiente / completada / cancelada; incluye una venta
--  pendiente con fecha antigua para probar el evento de la Etapa 6)
-- ------------------------------------------------------------
INSERT INTO ventas (id_venta, id_cliente, id_sucursal, fecha, estado, total) VALUES
(1,  1,  1, '2025-01-15 10:30:00', 'completada', 0),
(2,  2,  2, '2025-01-18 15:00:00', 'completada', 0),
(3,  3,  1, '2025-02-02 09:15:00', 'completada', 0),
(4,  4,  3, '2025-02-05 11:45:00', 'completada', 0),
(5,  5,  1, '2025-02-10 16:20:00', 'completada', 0),
(6,  6,  2, '2025-02-14 12:00:00', 'cancelada',  0),
(7,  7,  2, '2025-02-20 10:00:00', 'completada', 0),
(8,  8,  3, '2025-03-01 09:30:00', 'completada', 0),
(9,  9,  1, '2025-03-05 14:15:00', 'completada', 0),
(10, 10, 1, '2025-03-10 17:00:00', 'completada', 0),
(11, 11, 2, '2025-03-15 10:45:00', 'completada', 0),
(12, 12, 3, '2025-03-20 13:30:00', 'completada', 0),
(13, 1,  1, '2025-04-02 09:00:00', 'completada', 0),
(14, 3,  1, '2025-04-08 11:20:00', 'completada', 0),
(15, 5,  2, '2025-04-15 15:40:00', 'completada', 0),
(16, 7,  2, '2025-05-01 10:10:00', 'completada', 0),
(17, 9,  3, '2025-05-10 12:50:00', 'completada', 0),
(18, 2,  2, '2025-06-05 09:20:00', 'completada', 0),
(19, 4,  3, '2025-07-12 14:00:00', 'completada', 0),
(20, 6,  1, '2025-08-20 08:00:00', 'pendiente',  0);

-- ------------------------------------------------------------
-- 6.7 detalle_ventas
-- (precio_unitario_congelado toma el precio vigente del producto
--  al momento de la venta; subtotal se calcula automáticamente)
-- ------------------------------------------------------------
INSERT INTO detalle_ventas (id_venta, id_producto, cantidad, precio_unitario_congelado) VALUES
-- venta 1
(1, 1, 1, 3200000.00),
(1, 2, 2, 45000.00),
-- venta 2
(2, 3, 1, 120000.00),
(2, 8, 1, 90000.00),
-- venta 3
(3, 5, 2, 85000.00),
(3, 7, 1, 60000.00),
-- venta 4
(4, 9, 1, 1200000.00),
-- venta 5
(5, 10, 1, 220000.00),
(5, 11, 2, 55000.00),
-- venta 6 (cancelada, pero se deja el detalle histórico)
(6, 6, 1, 250000.00),
-- venta 7
(7, 12, 1, 180000.00),
(7, 13, 1, 130000.00),
-- venta 8
(8, 14, 3, 48000.00),
-- venta 9
(9, 4, 1, 2100000.00),
-- venta 10
(10, 2, 3, 45000.00),
(10, 3, 1, 120000.00),
-- venta 11
(11, 15, 2, 65000.00),
-- venta 12
(12, 8, 2, 90000.00),
(12, 11, 1, 55000.00),
-- venta 13
(13, 1, 1, 3200000.00),
-- venta 14
(14, 9, 1, 1200000.00),
(14, 10, 1, 220000.00),
-- venta 15
(15, 5, 1, 85000.00),
(15, 6, 1, 250000.00),
-- venta 16
(16, 13, 2, 130000.00),
-- venta 17
(17, 7, 3, 60000.00),
-- venta 18
(18, 3, 2, 120000.00),
(18, 14, 1, 48000.00),
-- venta 19
(19, 12, 1, 180000.00),
(19, 15, 1, 65000.00),
-- venta 20 (pendiente, antigua, para probar el evento en 06)
(20, 4, 1, 2100000.00);

-- ------------------------------------------------------------
-- 6.8 Actualizar ventas.total a partir del detalle
-- (mientras no existe el trigger de la Etapa 5, se recalcula aquí)
-- ------------------------------------------------------------
UPDATE ventas v
JOIN (
    SELECT id_venta, SUM(subtotal) AS total_calculado
    FROM detalle_ventas
    GROUP BY id_venta
) d ON d.id_venta = v.id_venta
SET v.total = d.total_calculado;

-- ------------------------------------------------------------
-- 6.9 historial_precios
-- (simula cambios de precio ocurridos antes del precio vigente actual)
-- ------------------------------------------------------------
INSERT INTO historial_precios (id_producto, precio_anterior, precio_nuevo, fecha_cambio) VALUES
(1, 3000000.00, 3200000.00, '2025-04-20 09:00:00'),
(4, 2300000.00, 2100000.00, '2025-05-15 10:00:00'),
(9, 1250000.00, 1200000.00, '2025-06-01 08:30:00'),
(3, 110000.00,  120000.00,  '2025-03-10 11:00:00'),
(12, 190000.00, 180000.00,  '2025-06-20 15:00:00'),
(6, 240000.00,  250000.00,  '2025-07-01 09:00:00');

-- ------------------------------------------------------------
-- Nota: la tabla auditoria queda vacía en esta etapa.
-- Se poblará mediante los triggers definidos en 05_Triggers.sql.
-- ------------------------------------------------------------