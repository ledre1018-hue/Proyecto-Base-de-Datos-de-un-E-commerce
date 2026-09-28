rm -f README.md README.md.save README.md.save.1 README.MD .README.md.swp .*.swp && cat > README.md << 'FIN'
# Proyecto de Base de Datos Avanzada - EcommerceDB

## Descripcion

Sistema de base de datos relacional para una tienda en linea (E-commerce) que gestiona productos, inventario, clientes y el ciclo de vida completo de las ventas. Implementa diseno normalizado (3FN), seguridad mediante roles y usuarios, triggers de integridad referencial, eventos programados automaticos y procedimientos almacenados transaccionales.

Proyecto academico de Base de Datos Avanzada, completamente independiente de cualquier otro taller del repositorio.

## Integrante

- Leonel Escalona

## Tecnologias

- Motor de Base de Datos: MySQL 8.0
- Motor de Almacenamiento: InnoDB
- Entorno de Ejecucion: Docker (contenedor MySQL en el puerto 3307)
- Control de Versiones: Git con Conventional Commits
- Editor: Visual Studio Code (terminal integrada, Bash, Linux Ubuntu)
- Inspeccion y comprobacion: DBeaver

## Arquitectura General

    Visual Studio Code
            |
      Terminal integrada (Bash)
            |
      MySQL 8.0 (Docker, puerto 3307)
            |
        EcommerceDB
            |
      DBeaver (inspeccion y comprobacion)

## Estructura de Archivos

El proyecto esta organizado en 7 archivos SQL que deben ejecutarse en orden secuencial, mas el README:

1. 01_Esquema_y_Datos.sql - Crea la base de datos EcommerceDB, las 9 tablas (categorias, proveedores, sucursales, productos, clientes, ventas, detalle_ventas, historial_precios, auditoria), sus restricciones, indices, y los datos de prueba (15 productos, 12 clientes, 20 ventas, 32 lineas de detalle, 6 registros de historial de precios).
2. 02_Consultas_Avanzadas.sql - 2 vistas reutilizables (vw_clientes_resumen, vw_catalogo_publico) y 20 consultas avanzadas de analisis de negocio.
3. 03_Funciones.sql - 20 funciones definidas por el usuario (UDF), agrupadas en calculo monetario, inventario, clientes y validacion/utilidades.
4. 04_Seguridad.sql - 7 roles, 7 usuarios con politicas de contrasena, y una vista adicional para ocultar informacion sensible de clientes.
5. 05_Triggers.sql - 21 triggers de automatizacion e integridad, incluye ALTER TABLE para las columnas derivadas ultima_compra, estado_lealtad y contador_productos.
6. 06_Eventos.sql - 20 eventos programados agrupados en mantenimiento de ventas, clientes, inventario, reportes/metricas, mantenimiento/limpieza y seguridad/monitoreo.
7. 07_Procedimientos_Almacenados.sql - 20 procedimientos almacenados transaccionales agrupados en ventas, productos, clientes y reportes.

Nota: el archivo corregir_triggers.sql que existio durante el desarrollo ya no es necesario; sus correcciones quedaron integradas directamente en 05_Triggers.sql.

## Instrucciones de Ejecucion

### Requisitos Previos

- MySQL 8.0 corriendo en Docker, accesible en 127.0.0.1:3307
- Usuario root con contrasena configurada (no se documenta aqui por seguridad)
- Cliente mysql disponible en la terminal

### Pasos de Instalacion

Ejecutar en orden desde la carpeta del proyecto:

    cd ~/Mysql/Proyecto_BD_Avanzada_EcommerceDB/
    mysql -h 127.0.0.1 -P 3307 -u root -p < 01_Esquema_y_Datos.sql
    mysql -h 127.0.0.1 -P 3307 -u root -p < 02_Consultas_Avanzadas.sql
    mysql -h 127.0.0.1 -P 3307 -u root -p < 03_Funciones.sql
    mysql -h 127.0.0.1 -P 3307 -u root -p < 04_Seguridad.sql
    mysql -h 127.0.0.1 -P 3307 -u root -p < 05_Triggers.sql
    mysql -h 127.0.0.1 -P 3307 -u root -p < 06_Eventos.sql
    mysql -h 127.0.0.1 -P 3307 -u root -p < 07_Procedimientos_Almacenados.sql

### Verificacion Rapida desde la Terminal

    mysql -h 127.0.0.1 -P 3307 -u root -p -e "USE EcommerceDB; SHOW TABLES;"
    mysql -h 127.0.0.1 -P 3307 -u root -p -e "USE EcommerceDB; SELECT COUNT(*) FROM productos;"

### Verificacion desde DBeaver

1. Crear una nueva conexion MySQL con host 127.0.0.1, puerto 3307, usuario root.
2. Conectar y expandir el arbol de la base de datos EcommerceDB.
3. Revisar el diagrama ER para confirmar relaciones entre las 9 tablas.
4. Ejecutar SELECT COUNT(*) sobre cada tabla para confirmar la carga de datos de prueba.
5. Revisar en el arbol las vistas, funciones, triggers, eventos y procedimientos creados.

## Credenciales de Usuarios de Prueba

Estas contrasenas son unicamente para el entorno academico local (Docker, puerto 3307) y no deben usarse en un entorno real.

| Usuario | Rol asignado | Contrasena |
|---|---|---|
| admin_user | Administrador_Sistema | Admin#2026Secure! |
| marketing_user | Gerente_Marketing | Mkt$Marketing2026 |
| inventory_user | Empleado_Inventario | Inv#Inventario26 |
| support_user | Atencion_Cliente | Sup@Soporte2026! |
| analista_user | Analista_Datos | An@lisis2026Data |
| auditor_user | Auditor_Financiero | Aud!Finanzas2026 |
| visitante_user | Visitante | Vis!itante2026 |

Todos los usuarios tienen politica PASSWORD EXPIRE INTERVAL 90 DAY y un rol por defecto asignado con SET DEFAULT ROLE.

## Arquitectura de la Base de Datos

### Tablas (9)

Principales:
- categorias: clasificacion de productos.
- proveedores: origen de los productos.
- productos: catalogo, precio vigente, costo, stock y stock minimo.
- clientes: datos base de compradores, mas 2 columnas derivadas mantenidas por trigger (ultima_compra, estado_lealtad).
- ventas: cabecera de cada transaccion (cliente, sucursal, fecha, estado, total).
- detalle_ventas: lineas de venta con precio congelado y subtotal calculado.

Auxiliares:
- sucursales: puntos de venta fisicos.
- historial_precios: bitacora de cambios de precio de catalogo.

Auditoria:
- auditoria: bitacora de operaciones sensibles (INSERT/UPDATE/DELETE) sobre productos, clientes y ventas.

### Relaciones Principales

    categorias   (1)---(N) productos
    proveedores  (1)---(N) productos
    sucursales   (1)---(N) ventas
    clientes     (1)---(N) ventas
    ventas       (1)---(N) detalle_ventas
    productos    (1)---(N) detalle_ventas
    productos    (1)---(N) historial_precios

### Decisiones de Normalizacion

- Modelo normalizado hasta 3FN en todas las tablas base.
- Desnormalizacion deliberada 1: detalle_ventas.precio_unitario_congelado, que copia el precio del producto en el momento de la venta para que el historial de ventas no dependa del precio actual del catalogo.
- Desnormalizacion deliberada 2: clientes.ultima_compra, clientes.estado_lealtad y categorias.contador_productos. Se agregaron como columnas fisicas (ALTER TABLE en 05_Triggers.sql) mantenidas exclusivamente por triggers y eventos, para poder demostrar esos requisitos con automatizacion real. La fuente de verdad alternativa sigue siendo la vista vw_clientes_resumen y las funciones fn_DeterminarEstadoLealtad y fn_ContarVentasCliente (03_Funciones.sql), que permiten auditar que el valor desnormalizado sea correcto.

## Resumen de Entregables

### Vistas (2)

1. vw_clientes_resumen - resumen de compras y gasto por cliente.
2. vw_catalogo_publico - catalogo de productos activos sin datos de costos ni proveedor sensible.

### Consultas Avanzadas (20)

1. Top 10 productos mas vendidos por ingresos
2. Productos con bajas ventas (percentil inferior al 10%)
3. Clientes VIP (Top 5 por valor de vida - LTV)
4. Analisis de ventas mensuales
5. Crecimiento de clientes por trimestre
6. Tasa de compra repetida
7. Productos comprados juntos frecuentemente
8. Rotacion de inventario por categoria
9. Productos que necesitan reabastecimiento
10. Analisis de carritos abandonados (ventas pendientes)
11. Rendimiento de proveedores por volumen de ventas
12. Analisis geografico de ventas por ciudad y region
13. Ventas por hora del dia
14. Comparacion de ventas por periodo
15. Analisis de cohortes de clientes
16. Margen de beneficio por producto
17. Tiempo promedio entre compras por cliente
18. Comparacion de productos mas vendidos vs menos vendidos
19. Segmentacion de clientes RFM (Recencia, Frecuencia, Monetario)
20. Prediccion simple de demanda mensual por categoria

### Funciones UDF (20)

Grupo 1 - Calculo monetario:
- fn_CalcularTotalVenta, fn_CalcularIVA, fn_AplicarDescuento, fn_ConvertirMoneda

Grupo 2 - Inventario y productos:
- fn_VerificarDisponibilidadStock, fn_ObtenerPrecioProducto, fn_ObtenerNombreCategoria, fn_ObtenerStockTotalPorCategoria, fn_GenerarSKU

Grupo 3 - Clientes:
- fn_FormatearNombreCompleto, fn_CalcularEdadCliente, fn_ContarVentasCliente, fn_ObtenerUltimaFechaCompra, fn_CalcularDiasDesdeUltimaCompra, fn_EsClienteNuevo, fn_DeterminarEstadoLealtad

Grupo 4 - Validacion y utilidades:
- fn_ValidarFormatoEmail, fn_ValidarComplejidadContrasena, fn_CalcularCostoEnvio, fn_EstimarFechaEntrega

### Seguridad (7 roles)

- Administrador_Sistema, Gerente_Marketing, Analista_Datos, Empleado_Inventario, Atencion_Cliente, Auditor_Financiero, Visitante

### Triggers (21)

Productos y categorias (11):
- trg_audit_precio_producto_after_update, trg_prevent_price_zero_or_less, trg_prevent_negative_stock, trg_set_fecha_modificacion_producto, trg_assign_default_category_on_null, trg_update_producto_count_in_categoria_insert, trg_update_producto_count_in_categoria_delete, trg_prevent_delete_categoria_with_products, trg_audit_product_insert, trg_audit_product_delete, trg_send_stock_alert_on_low_stock

Clientes (4):
- trg_log_new_customer_after_insert, trg_capitalize_nombre_cliente, trg_validate_email_format_on_customer, trg_update_last_order_date_customer

Ventas y detalle_ventas (6):
- trg_check_stock_before_insert_venta, trg_update_stock_after_insert_venta, trg_recalculate_total_venta_on_detalle_change, trg_log_order_status_change, trg_archive_deleted_venta, trg_audit_venta_insert

### Eventos Programados (20)

Mantenimiento de ventas: ev_cancelar_ventas_pendientes_antiguas, ev_actualizar_total_ventas

Clientes: ev_actualizar_estado_lealtad_clientes, ev_suspend_cuentas_inactivas, ev_clientes_cumpleanos

Inventario: ev_generar_lista_reabastecimiento, ev_actualizar_contador_categorias, ev_alerta_stock_critico

Reportes y metricas: ev_reporte_ventas_diario, ev_ranking_productos, ev_kpis_mensuales

Mantenimiento y limpieza: ev_limpiar_auditoria_antigua, ev_limpiar_historial_precios_antiguo, ev_rebuild_indexes, ev_optimize_tables, ev_backup_logico

Seguridad y monitoreo: ev_limpiar_intentos_login, ev_detectar_actividad_sospechosa, ev_reporte_proveedores, ev_purge_soft_deleted

Nota: requieren SET GLOBAL event_scheduler = ON para ejecutarse automaticamente; tambien pueden probarse manualmente ejecutando el cuerpo del evento como bloque BEGIN...END.

### Procedimientos Almacenados (20)

Ventas (5): sp_registrar_venta, sp_agregar_detalle_venta, sp_procesar_pago, sp_cambiar_estado_pedido, sp_procesar_devolucion

Productos (7): sp_agregar_nuevo_producto, sp_ajustar_nivel_stock, sp_aplicar_descuento_por_categoria, sp_mover_productos_entre_categorias, sp_asignar_producto_a_proveedor, sp_buscar_productos, sp_obtener_detalles_producto_completo

Clientes (5): sp_registrar_nuevo_cliente, sp_actualizar_direccion_cliente, sp_eliminar_cliente_de_forma_segura, sp_fusionar_cuentas_cliente, sp_obtener_historial_compras_cliente

Reportes (3): sp_generar_reporte_mensual_ventas, sp_obtener_dashboard_admin, sp_obtener_productos_relacionados

## Matriz de Trazabilidad de Requisitos

| Requisito | Implementacion | Archivo | Prueba |
|---|---|---|---|
| Diseno normalizado 3FN | 9 tablas con PK, FK, UNIQUE, CHECK | 01 | DESCRIBE tabla / diagrama ER en DBeaver |
| Precio historico inmutable en la venta | Columna precio_unitario_congelado + trigger de congelamiento | 01 / 05 | Comparar venta antigua tras cambiar productos.precio |
| Historial de cambios de precio | Tabla historial_precios + trigger AFTER UPDATE | 01 / 05 | UPDATE productos.precio y SELECT historial_precios |
| Password segura de clientes | Columna password_hash (SHA2-256), nunca texto plano | 01 | Verificar longitud y formato del hash |
| Consultas avanzadas de negocio | JOIN, CTE, funciones de ventana, agregaciones | 02 | Ejecutar cada consulta y revisar resultado |
| Funciones definidas por el usuario | 20 UDF documentadas y probadas | 03 | SELECT funcion(parametros) |
| Minimo privilegio por rol | 7 roles con GRANT especificos, sin GRANT ALL indiscriminado | 04 | SHOW GRANTS FOR usuario |
| Proteccion de datos sensibles | Vistas que ocultan password_hash y costos | 02 / 04 | SELECT sobre la vista vs la tabla base |
| Validacion e integridad de datos | Triggers BEFORE INSERT/UPDATE con SIGNAL SQLSTATE | 05 | Intentar insertar datos invalidos |
| Datos derivados de cliente y categoria | Columnas mantenidas por trigger, con auditoria en auditoria(tabla_afectada, id_registro_afectado, accion, usuario_bd, fecha_hora, detalle) | 05 | UPDATE ventas.estado y verificar clientes.ultima_compra/estado_lealtad |
| Automatizacion programada | Eventos con ON SCHEDULE y logica de negocio real | 06 | SHOW EVENTS / ejecucion manual del bloque |
| Operaciones transaccionales atomicas | Procedimientos con START TRANSACTION, COMMIT, ROLLBACK | 07 | CALL forzando un error y verificar ROLLBACK |
| Documentacion del proyecto | README con arquitectura, instalacion y entregables | README.md | Lectura y verificacion de cada seccion |

## Convencion de Commits

Este proyecto usa Conventional Commits. Ejemplos:

    git add 01_Esquema_y_Datos.sql
    git commit -m "feat(schema): crear esquema y datos iniciales"

    git add 05_Triggers.sql
    git commit -m "fix(triggers): corregir columnas de auditoria y agregar columnas derivadas"

    git add README.md
    git commit -m "docs(readme): documentar proyecto"

## Independencia del Proyecto

Este proyecto (Proyecto_BD_Avanzada_EcommerceDB) es completamente independiente de cualquier otro taller del repositorio Mysql/ (biblioteca_campus, Practica_hospital_mysql, Reto1_transferencia_bancaria, compose.yml de la raiz, mi_base_datos.sql). No comparte tablas, datos, usuarios, roles ni configuraciones con ellos.

## Licencia

Proyecto academico de uso educativo, desarrollado como entrega para la asignatura de Base de Datos Avanzada.
FIN
git add README.md && git commit -m "docs(readme): actualizar documentacion con correcciones de triggers y eventos"