cat > README.md << 'EOF'
# Proyecto de Base de Datos Avanzada - EcommerceDB

## Descripcion

Sistema de base de datos relacional para una tienda en linea (E-commerce) que gestiona productos, inventario, clientes y el ciclo de vida completo de las ventas. Implementa diseno normalizado (3FN), seguridad mediante roles y usuarios, triggers de integridad, eventos programados y procedimientos almacenados transaccionales.

Proyecto academico de Base de Datos Avanzada, independiente de cualquier otro taller del repositorio.

## Integrante

- Leonel Escalona

## Tecnologias

- Motor de Base de Datos: MySQL 8.0 (InnoDB)
- Entorno de Ejecucion: Docker (contenedor MySQL en el puerto 3307)
- Control de Versiones: Git con Conventional Commits
- Editor: Visual Studio Code (terminal integrada, Bash, Ubuntu)
- Inspeccion y comprobacion: DBeaver

## Estructura de Archivos

Los archivos 01 a 07 se ejecutan en orden secuencial. El archivo del examen se ejecuta al final.

1. 01_Esquema_y_Datos.sql - Base de datos, 9 tablas, restricciones, indices y datos de prueba.
2. 02_Consultas_Avanzadas.sql - 2 vistas (vw_clientes_resumen, vw_catalogo_publico) y 20 consultas avanzadas.
3. 03_Funciones.sql - 20 funciones definidas por el usuario.
4. 04_Seguridad.sql - 7 roles, 7 usuarios, vista v_info_clientes_basica y tabla intentos_login_fallidos.
5. 05_Triggers.sql - 22 triggers de automatizacion e integridad y columnas derivadas (ultima_compra, estado_lealtad, contador_productos).
6. 06_Eventos.sql - 20 eventos programados.
7. 07_Procedimientos_Almacenados.sql - 20 procedimientos almacenados transaccionales.
8. auditorias_clientes.sql - Examen: tabla Auditoria_Clientes y trigger trg_audit_cliente_after_update.

Nota: corregir_triggers.sql fue un archivo de apoyo durante el desarrollo; sus correcciones quedaron en 05_Triggers.sql.

## Instrucciones de Ejecucion

Requisitos: MySQL 8.0 en Docker accesible en 127.0.0.1:3307 y cliente mysql en la terminal.

    cd ~/Mysql/Proyecto_BD_Avanzada_EcommerceDB/
    mysql -h 127.0.0.1 -P 3307 -u root -p < 01_Esquema_y_Datos.sql
    mysql -h 127.0.0.1 -P 3307 -u root -p < 02_Consultas_Avanzadas.sql
    mysql -h 127.0.0.1 -P 3307 -u root -p < 03_Funciones.sql
    mysql -h 127.0.0.1 -P 3307 -u root -p < 04_Seguridad.sql
    mysql -h 127.0.0.1 -P 3307 -u root -p < 05_Triggers.sql
    mysql -h 127.0.0.1 -P 3307 -u root -p < 06_Eventos.sql
    mysql -h 127.0.0.1 -P 3307 -u root -p < 07_Procedimientos_Almacenados.sql
    mysql -h 127.0.0.1 -P 3307 -u root -p < auditorias_clientes.sql

Verificacion rapida:

    mysql -h 127.0.0.1 -P 3307 -u root -p -e "USE EcommerceDB; SHOW TABLES;"

## Usuarios de Prueba

Las contrasenas estan definidas en 04_Seguridad.sql y son solo para el entorno academico local.

| Usuario | Rol asignado |
|---|---|
| admin_user | Administrador_Sistema |
| marketing_user | Gerente_Marketing |
| inventory_user | Empleado_Inventario |
| support_user | Atencion_Cliente |
| analista_user | Analista_Datos |
| auditor_user | Auditor_Financiero |
| visitante_user | Visitante |

Todos tienen PASSWORD EXPIRE INTERVAL 90 DAY y un rol por defecto asignado con SET DEFAULT ROLE.

## Arquitectura de la Base de Datos

### Tablas

Principales: categorias, proveedores, productos, clientes, ventas, detalle_ventas.
Auxiliares: sucursales, historial_precios.
Auditoria: auditoria (bitacora general) y Auditoria_Clientes (examen, cambios de email y direccion_envio).
Seguridad: intentos_login_fallidos (creada en 04_Seguridad.sql).

### Relaciones Principales

    categorias   (1)---(N) productos
    proveedores  (1)---(N) productos
    sucursales   (1)---(N) ventas
    clientes     (1)---(N) ventas
    clientes     (1)---(N) Auditoria_Clientes
    ventas       (1)---(N) detalle_ventas
    productos    (1)---(N) detalle_ventas
    productos    (1)---(N) historial_precios

### Decisiones de Normalizacion

- Modelo normalizado hasta 3FN en las tablas base.
- Desnormalizacion deliberada 1: detalle_ventas.precio_unitario_congelado conserva el precio al momento de la venta.
- Desnormalizacion deliberada 2: clientes.ultima_compra, clientes.estado_lealtad y categorias.contador_productos, mantenidas por triggers y eventos. La fuente de verdad sigue siendo vw_clientes_resumen y las funciones fn_DeterminarEstadoLealtad y fn_ContarVentasCliente.

## Examen: Trigger de Auditoria de Cambios en Clientes

Archivo: auditorias_clientes.sql

Registra cualquier cambio en la informacion sensible de los clientes (email y direccion_envio).

### Tabla Auditoria_Clientes

| Columna | Tipo | Descripcion |
|---|---|---|
| id_auditoria | INT AUTO_INCREMENT PK | Identificador del registro |
| id_cliente | INT NOT NULL, FK a clientes | Cliente afectado |
| campo_modificado | VARCHAR(30), CHECK | Solo 'email' o 'direccion_envio' |
| valor_antiguo | VARCHAR(255) NULL | Valor antes del cambio |
| valor_nuevo | VARCHAR(255) NULL | Valor despues del cambio |
| fecha_modificacion | DATETIME DEFAULT CURRENT_TIMESTAMP | Momento del cambio |

Integridad y rendimiento: FK con ON DELETE RESTRICT (la auditoria no se pierde al borrar un cliente), indice (id_cliente, fecha_modificacion) e indice (fecha_modificacion).

### Trigger trg_audit_cliente_after_update

- Se dispara AFTER UPDATE ON clientes, cuando el cambio ya fue aplicado.
- Usa NOT (OLD.campo <=> NEW.campo), comparacion segura con NULL.
- Usa dos IF independientes, uno por campo: si cambian ambos se insertan 2 registros.
- Si cambia otra columna (por ejemplo ciudad) no inserta nada.

### Prueba

    mysql -h 127.0.0.1 -P 3307 -u root -p EcommerceDB -e "
    START TRANSACTION;
    UPDATE clientes SET email='nuevo@test.com' WHERE id_cliente=1;
    UPDATE clientes SET email='otro@test.com', direccion_envio='Calle 1 # 2-3' WHERE id_cliente=2;
    UPDATE clientes SET ciudad='Cali' WHERE id_cliente=3;
    SELECT * FROM Auditoria_Clientes;
    ROLLBACK;"

Resultado esperado: 3 filas (1 del cliente 1 y 2 del cliente 2).

## Resumen de Entregables

- Vistas (3): vw_clientes_resumen, vw_catalogo_publico, v_info_clientes_basica.
- Consultas avanzadas (20): ventas, clientes, inventario, proveedores, cohortes, RFM y demanda.
- Funciones UDF (20): calculo monetario, inventario, clientes y validacion/utilidades.
- Seguridad (7 roles): Administrador_Sistema, Gerente_Marketing, Analista_Datos, Empleado_Inventario, Atencion_Cliente, Auditor_Financiero, Visitante.
- Triggers (23): 22 en 05_Triggers.sql mas trg_audit_cliente_after_update del examen.
- Eventos (20): requieren SET GLOBAL event_scheduler = ON.
- Procedimientos almacenados (20): ventas, productos, clientes y reportes.

## Matriz de Trazabilidad de Requisitos

| Requisito | Implementacion | Archivo |
|---|---|---|
| Diseno normalizado 3FN | Tablas con PK, FK, UNIQUE, CHECK | 01 |
| Precio historico inmutable | precio_unitario_congelado | 01 |
| Historial de cambios de precio | historial_precios + trigger AFTER UPDATE | 01 / 05 |
| Password segura | password_hash SHA2-256 | 01 |
| Consultas avanzadas | JOIN, CTE, funciones de ventana | 02 |
| Funciones definidas por el usuario | 20 UDF | 03 |
| Minimo privilegio por rol | GRANT especificos por rol | 04 |
| Validacion e integridad | Triggers con SIGNAL SQLSTATE | 05 |
| Automatizacion programada | Eventos con ON SCHEDULE | 06 |
| Operaciones atomicas | START TRANSACTION, COMMIT, ROLLBACK | 07 |
| Auditoria de datos sensibles de clientes | Auditoria_Clientes + trg_audit_cliente_after_update | auditorias_clientes.sql |

## Convencion de Commits

Se usa Conventional Commits. Ejemplos:

    feat(audit): crear Auditoria_Clientes y trigger trg_audit_cliente_after_update
    fix(triggers): corregir columnas de auditoria
    docs(readme): documentar proyecto

## Licencia

Proyecto academico de uso educativo, desarrollado como entrega para la asignatura de Base de Datos Avanzada.
EOF