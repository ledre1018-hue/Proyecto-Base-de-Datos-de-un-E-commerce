USE EcommerceDB;

DROP TRIGGER IF EXISTS trg_audit_cliente_after_update;
DROP TABLE IF EXISTS Auditoria_Clientes;

CREATE TABLE Auditoria_Clientes (
    id_auditoria       INT AUTO_INCREMENT PRIMARY KEY,
    id_cliente         INT NOT NULL,
    campo_modificado   VARCHAR(30) NOT NULL,
    valor_antiguo      VARCHAR(255) NULL,
    valor_nuevo        VARCHAR(255) NULL,
    fecha_modificacion DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_audcli_cliente
        FOREIGN KEY (id_cliente) REFERENCES clientes (id_cliente)
        ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT chk_audcli_campo
        CHECK (campo_modificado IN ('email', 'direccion_envio')),
    INDEX idx_audcli_cliente_fecha (id_cliente, fecha_modificacion),
    INDEX idx_audcli_fecha (fecha_modificacion)
) ENGINE = InnoDB;

DELIMITER //

CREATE TRIGGER trg_audit_cliente_after_update
AFTER UPDATE ON clientes
FOR EACH ROW
BEGIN
    -- AFTER: se audita solo cuando el UPDATE ya fue validado y aplicado.
    -- <=> compara de forma segura con NULL; <> devolvería NULL y ocultaría el cambio.
    IF NOT (OLD.email <=> NEW.email) THEN
        INSERT INTO Auditoria_Clientes (id_cliente, campo_modificado, valor_antiguo, valor_nuevo)
        VALUES (NEW.id_cliente, 'email', OLD.email, NEW.email);
    END IF;

    -- IF independiente: si cambian ambos campos se generan dos registros.
    IF NOT (OLD.direccion_envio <=> NEW.direccion_envio) THEN
        INSERT INTO Auditoria_Clientes (id_cliente, campo_modificado, valor_antiguo, valor_nuevo)
        VALUES (NEW.id_cliente, 'direccion_envio', OLD.direccion_envio, NEW.direccion_envio);
    END IF;
END //

DELIMITER ;