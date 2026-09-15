/*
  PROYECTO ACADÉMICO - VERSIÓN PREPARADA PARA PORTFOLIO
  ------------------------------------------------------
  Base de datos Oracle SQL/PLSQL desarrollada con fines docentes.
  Los identificadores, nombres y correos del dataset de ejemplo son ficticios.
  No contiene datos personales reales.
*/

/* ==========================================================
  INICIALIZACIÓN
   ========================================================== */

SET AUTOCOMMIT on;
SET SERVEROUTPUT on;

/* ==========================================================
  BORRADO DE TRIGGERS DEFINIDOS (P4)
   ========================================================== */

BEGIN
  EXECUTE IMMEDIATE 'DROP TRIGGER TRG_CURSO_PLAZAS';
EXCEPTION WHEN OTHERS THEN NULL; END;
/
BEGIN
  EXECUTE IMMEDIATE 'DROP TRIGGER TRG_FUNCIONARIO_CATEGORIA';
EXCEPTION WHEN OTHERS THEN NULL; END;
/
BEGIN
  EXECUTE IMMEDIATE 'DROP TRIGGER TRG_SOLICITA_UNICA_ACTIVA';
EXCEPTION WHEN OTHERS THEN NULL; END;
/
BEGIN
  EXECUTE IMMEDIATE 'DROP TRIGGER TRG_CONTRATO_FECHAS';
EXCEPTION WHEN OTHERS THEN NULL; END;
/
BEGIN
  EXECUTE IMMEDIATE 'DROP TRIGGER TRG_PAGO_NUM';
EXCEPTION WHEN OTHERS THEN NULL; END;
/
BEGIN
  EXECUTE IMMEDIATE 'DROP TRIGGER TRG_CURSO_NO_BORRAR_CON_MATRICULADOS';
EXCEPTION WHEN OTHERS THEN NULL; END;
/


DROP TABLE PAGO CASCADE CONSTRAINTS;
DROP TABLE PRESTAMO CASCADE CONSTRAINTS;
DROP TABLE SOLICITA CASCADE CONSTRAINTS;
DROP TABLE CONTRATO CASCADE CONSTRAINTS;
DROP TABLE OFERTA CASCADE CONSTRAINTS;
DROP TABLE CURSO CASCADE CONSTRAINTS;
DROP TABLE FUNCIONARIO CASCADE CONSTRAINTS;
DROP TABLE CIUDADANO CASCADE CONSTRAINTS;
DROP TABLE EMPRESA CASCADE CONSTRAINTS;
DROP TABLE OFICINA CASCADE CONSTRAINTS;
DROP TABLE ORGANIZADOR CASCADE CONSTRAINTS;
DROP TABLE PERSONA CASCADE CONSTRAINTS;

/* ==========================================================
  BORRADO DE PROCEDIMIENTOS / FUNCIONES (P3)
   ========================================================== */

BEGIN
  EXECUTE IMMEDIATE 'DROP PROCEDURE PROC_ALTA_SOLICITUD_OFERTA';
EXCEPTION
  WHEN OTHERS THEN
    NULL; -- Si no existe, ignoramos el error
END;
/

BEGIN
  EXECUTE IMMEDIATE 'DROP PROCEDURE PROC_BAJA_CIUDADANO_CURSO';
EXCEPTION
  WHEN OTHERS THEN
    NULL;
END;
/

BEGIN
  EXECUTE IMMEDIATE 'DROP FUNCTION FN_IMPORTE_TOTAL_PAGADO';
EXCEPTION
  WHEN OTHERS THEN
    NULL;
END;
/




/* ==========================================================
  CREACIÓN DE TABLAS
   ========================================================== */

/* Superclase PERSONA */
CREATE TABLE PERSONA (
  DNI         VARCHAR2(9)   PRIMARY KEY,
  NOMBRE      VARCHAR2(40)  NOT NULL,
  APELLIDOS   VARCHAR2(80)  NOT NULL,
  FECHA_NAC   DATE
);

/* Categoría ORGANIZADOR */
CREATE TABLE ORGANIZADOR (
  ID_ORGANIZADOR NUMBER(8) PRIMARY KEY,
  TIPO VARCHAR2(8),
  RESPONSABLE VARCHAR2(40),
  EMAIL VARCHAR2(50),
  /*Check necesario para que el tipo del organizador sea o bien de una OFICINA o de una EMPRESA */
  CHECK (TIPO IN ('EMPRESA','OFICINA'))
);


/* CURSO */
CREATE TABLE CURSO (
  ID_CURSO NUMBER(8) PRIMARY KEY,
  NOMBRE VARCHAR2(50),
  DURACION NUMBER(4) CHECK (DURACION > 0),
  PLAZAS NUMBER(4) CHECK (PLAZAS > 0),
  ID_ORGANIZADOR NUMBER(8),
  FOREIGN KEY (ID_ORGANIZADOR) REFERENCES ORGANIZADOR (ID_ORGANIZADOR) ON DELETE SET NULL
);








/* Subclase CIUDADANO */
CREATE TABLE CIUDADANO (
  DNI_CIUDADANO   VARCHAR2(9) PRIMARY KEY,
  EXP_LABORAL     VARCHAR2(200),
  DISPONIBILIDAD  VARCHAR2(20),
  NIVEL_FORMACION VARCHAR2(40),
  ID_CURSO        NUMBER(8),
  FOREIGN KEY (DNI_CIUDADANO) REFERENCES PERSONA(DNI) ON DELETE CASCADE,
  FOREIGN KEY (ID_CURSO) REFERENCES CURSO(ID_CURSO) ON DELETE SET NULL
);



/* =======================================================================
  Trigger de restricción semántica sobre CIUDADANO y CURSO.
  Controla que no se superen las plazas disponibles de un curso
  al asignar ciudadanos.
  La validación depende del número de registros existentes
  y no puede implementarse mediante restricciones estándar.
   ======================================================================= */

CREATE OR REPLACE TRIGGER TRG_CURSO_PLAZAS
BEFORE INSERT OR UPDATE ON CIUDADANO
FOR EACH ROW
DECLARE
  v_ocupadas NUMBER;
  v_plazas   NUMBER;
BEGIN
  IF :NEW.ID_CURSO IS NOT NULL THEN


  -- Se excluye al propio ciudadano en actualizaciones para evitar contar su plaza dos veces
    SELECT COUNT(*)
    INTO v_ocupadas
    FROM CIUDADANO
    WHERE ID_CURSO = :NEW.ID_CURSO
      AND DNI_CIUDADANO <> NVL(:OLD.DNI_CIUDADANO, '##');

    SELECT PLAZAS
    INTO v_plazas
    FROM CURSO
    WHERE ID_CURSO = :NEW.ID_CURSO;

    IF v_ocupadas >= v_plazas THEN
      RAISE_APPLICATION_ERROR(
        -20005,
        'No se puede asignar el ciudadano al curso: no quedan plazas disponibles'
      );
    END IF;

  END IF;
END;
/




/* OFICINA (superclase de categoría) */
CREATE TABLE OFICINA (
  ID_OFICINA NUMBER(6) PRIMARY KEY,
  LOCALIDAD VARCHAR2(30),
  TELEFONO VARCHAR2(15),
  ID_ORGANIZADOR NUMBER(8),
  FOREIGN KEY (ID_ORGANIZADOR) REFERENCES ORGANIZADOR (ID_ORGANIZADOR) ON DELETE CASCADE
);

/* EMPRESA (superclase de categoría) */
CREATE TABLE EMPRESA (
  ID_EMPRESA NUMBER(8) PRIMARY KEY,
  CIF VARCHAR2(9) NOT NULL UNIQUE,
  NOMBRE VARCHAR2(40),
  DIRECCION VARCHAR2(50),
  ID_ORGANIZADOR NUMBER(8),
  FOREIGN KEY (ID_ORGANIZADOR) REFERENCES ORGANIZADOR (ID_ORGANIZADOR) ON DELETE CASCADE
);

/* Subclase FUNCIONARIO */
CREATE TABLE FUNCIONARIO (
  DNI_FUNCIONARIO VARCHAR2(9) PRIMARY KEY,
  PUESTO VARCHAR2(30),
  CATEGORIA VARCHAR2(20),
  FECHA_ALTA DATE,
  ID_OFICINA NUMBER(6),
  DNI_SUPERVISOR VARCHAR2(9),
  FOREIGN KEY (DNI_FUNCIONARIO) REFERENCES PERSONA(DNI) ON DELETE CASCADE,
  FOREIGN KEY (ID_OFICINA) REFERENCES OFICINA (ID_OFICINA) ON DELETE CASCADE,
  FOREIGN KEY (DNI_SUPERVISOR) REFERENCES FUNCIONARIO(DNI_FUNCIONARIO) ON DELETE SET NULL
);


/* =======================================================================
  Trigger automático sobre la tabla FUNCIONARIO.
  Asigna automáticamente la categoría del funcionario
  en función del puesto desempeñado.
  Esta lógica de negocio no puede implementarse mediante
  restricciones estándar y centraliza la coherencia de datos.
   ======================================================================= */


CREATE OR REPLACE TRIGGER TRG_FUNCIONARIO_CATEGORIA
BEFORE INSERT OR UPDATE ON FUNCIONARIO
FOR EACH ROW
BEGIN
  IF :NEW.PUESTO IS NOT NULL THEN
    IF UPPER(:NEW.PUESTO) = 'ADMINISTRATIVO' THEN
      :NEW.CATEGORIA := 'AUXILIAR';
    ELSIF UPPER(:NEW.PUESTO) = 'INSPECTOR' THEN
      :NEW.CATEGORIA := 'SUPERIOR';
    ELSE
      :NEW.CATEGORIA := 'GENERAL';
    END IF;
  END IF;
END;
/





/* OFERTA */
CREATE TABLE OFERTA (
  ID_OFERTA NUMBER(8) PRIMARY KEY,
  PUESTO VARCHAR2(50),
  REQUISITOS VARCHAR2(100),
  ID_EMPRESA NUMBER(8),
  FOREIGN KEY (ID_EMPRESA) REFERENCES EMPRESA (ID_EMPRESA) ON DELETE CASCADE
);




/* =======================================================================
  Tabla SOLICITA particionada por FECHA_SOLICITUD.
  Se usa particionado RANGE porque las solicitudes crecen por años
  y la mayoría de las consultas se filtran por rangos de fechas.
  Cada partición representa un año diferente y se añade una partición
  MAXVALUE para solicitudes futuras. Esto mejora el rendimiento en
  búsquedas por fecha y facilita el mantenimiento anual.
   ======================================================================= */


CREATE TABLE SOLICITA (
  DNI_CIUDADANO   VARCHAR2(9),               
  ID_OFERTA       NUMBER(8),                 
  ESTADO          VARCHAR2(20),             
  FECHA_SOLICITUD DATE,                      -- columna de particionado (por año)
  CONSTRAINT PK_SOLICITA PRIMARY KEY (DNI_CIUDADANO, ID_OFERTA),
  CONSTRAINT FK_SOLICITA_CIUD FOREIGN KEY (DNI_CIUDADANO)
    REFERENCES CIUDADANO (DNI_CIUDADANO) ON DELETE CASCADE,
  CONSTRAINT FK_SOLICITA_OFERTA FOREIGN KEY (ID_OFERTA)
    REFERENCES OFERTA (ID_OFERTA) ON DELETE CASCADE,
  CONSTRAINT CHK_SOLICITA_EST CHECK (ESTADO IN ('PENDIENTE','ACEPTADA','RECHAZADA'))
)



PARTITION BY RANGE (FECHA_SOLICITUD)
(
  PARTITION SOLI_2021 VALUES LESS THAN (DATE '2022-01-01'),
  PARTITION SOLI_2022 VALUES LESS THAN (DATE '2023-01-01'),
  PARTITION SOLI_2023 VALUES LESS THAN (DATE '2024-01-01'),
  PARTITION SOLI_2024 VALUES LESS THAN (DATE '2025-01-01'),
  PARTITION SOLI_2025 VALUES LESS THAN (DATE '2026-01-01'),

  -- Cola para años futuros
  PARTITION SOLI_MAX  VALUES LESS THAN (MAXVALUE)
);

/* =======================================================================
  Trigger de restricción semántica sobre la tabla SOLICITA.
  A diferencia del CHECK CHK_SOLICITA_EST, que solo valida
  valores permitidos del estado, este trigger controla la
  coexistencia de varias filas activas para un mismo ciudadano
  y oferta, una regla que no puede expresarse con restricciones estándar.
   ======================================================================= */


CREATE OR REPLACE TRIGGER TRG_SOLICITA_UNICA_ACTIVA
BEFORE INSERT OR UPDATE ON SOLICITA
FOR EACH ROW
DECLARE
  v_contador NUMBER;
BEGIN
  -- Solo se controla cuando la solicitud pasa a estar activa
  IF :NEW.ESTADO IN ('PENDIENTE', 'ACEPTADA') THEN

    SELECT COUNT(*)
    INTO v_contador
    FROM SOLICITA
    WHERE DNI_CIUDADANO = :NEW.DNI_CIUDADANO
      AND ID_OFERTA = :NEW.ID_OFERTA
      AND ESTADO IN ('PENDIENTE', 'ACEPTADA');

    IF v_contador > 0 THEN
      RAISE_APPLICATION_ERROR(
        -20002,
        'El ciudadano ya tiene una solicitud activa para esta oferta'
      );
    END IF;

  END IF;
END;
/








/* =======================================================================
  Tabla CONTRATO particionada por FECHA_INICIO.
  Se usa particionado RANGE porque los contratos se organizan por años
  y es habitual consultarlos por periodos de tiempo. Cada partición
  representa un año distinto y la partición MAXVALUE permite almacenar
  contratos futuros sin modificar la tabla. Este diseño mejora el
  rendimiento en búsquedas por fecha y facilita el mantenimiento anual.
   ======================================================================= */


CREATE TABLE CONTRATO (
  ID_CONTRATO    NUMBER(8) PRIMARY KEY,      
  TIPO           VARCHAR2(20),
  FECHA_INICIO   DATE,                       -- columna de particionado (por año)
  FECHA_FIN      DATE,
  ID_EMPRESA     NUMBER(8),                  
  DNI_CIUDADANO  VARCHAR2(9),                
  CONSTRAINT FK_CONTR_EMP FOREIGN KEY (ID_EMPRESA)
    REFERENCES EMPRESA (ID_EMPRESA) ON DELETE CASCADE,
  CONSTRAINT FK_CONTR_CIUD FOREIGN KEY (DNI_CIUDADANO)
    REFERENCES CIUDADANO (DNI_CIUDADANO) ON DELETE CASCADE,
  CONSTRAINT CHK_CONTR_FECHAS CHECK (FECHA_INICIO < FECHA_FIN)
)



PARTITION BY RANGE (FECHA_INICIO)
(
  PARTITION CTR_2021 VALUES LESS THAN (DATE '2022-01-01'),
  PARTITION CTR_2022 VALUES LESS THAN (DATE '2023-01-01'),
  PARTITION CTR_2023 VALUES LESS THAN (DATE '2024-01-01'),
  PARTITION CTR_2024 VALUES LESS THAN (DATE '2025-01-01'),
  PARTITION CTR_2025 VALUES LESS THAN (DATE '2026-01-01'),

  -- Partición "infinita" para lo que venga después
  PARTITION CTR_MAX  VALUES LESS THAN (MAXVALUE)
);


/* =======================================================================
  Trigger de restricción semántica sobre la tabla CONTRATO.
  Garantiza la coherencia temporal del contrato impidiendo
  que la fecha de fin sea anterior o igual a la fecha de inicio.
  Se implementa mediante trigger para reforzar la validación
  del CHECK existente y permitir mensajes de error más claros.
   ======================================================================= */

CREATE OR REPLACE TRIGGER TRG_CONTRATO_FECHAS
BEFORE INSERT OR UPDATE ON CONTRATO
FOR EACH ROW
BEGIN
  IF :NEW.FECHA_INICIO >= :NEW.FECHA_FIN THEN
    RAISE_APPLICATION_ERROR(
      -20001,
      'La fecha de fin del contrato debe ser posterior a la fecha de inicio'
    );
  END IF;
END;
/





/* PRESTAMO (1:1 con CIUDADANO) */
CREATE TABLE PRESTAMO (
  ID_PRESTAMO NUMBER(8) PRIMARY KEY,
  FORMA_OTORGAMIENTO VARCHAR2(30),
  FECHA_RESOLUCION DATE,
  DNI_CIUDADANO VARCHAR2(9) UNIQUE,
  FOREIGN KEY (DNI_CIUDADANO) REFERENCES CIUDADANO (DNI_CIUDADANO) ON DELETE CASCADE
);




/* PAGO (1:N con PRESTAMO) */
CREATE TABLE PAGO (
  ID_PRESTAMO   NUMBER(8),
  NUM_PAGO      NUMBER(4),  -- identificador parcial dentro del préstamo
  IMPORTE       NUMBER(10,2) CHECK (IMPORTE >= 0),
  PRIMARY KEY (ID_PRESTAMO, NUM_PAGO),
  FOREIGN KEY (ID_PRESTAMO) REFERENCES PRESTAMO (ID_PRESTAMO) ON DELETE CASCADE
);



/* =======================================================================
  Trigger automático sobre la tabla PAGO.
  Genera automáticamente el número de pago dentro de un préstamo
  asignando el siguiente valor disponible.
  Este comportamiento depende del estado actual de la tabla
  y no puede implementarse mediante restricciones estándar.
   ======================================================================= */


CREATE OR REPLACE TRIGGER TRG_PAGO_NUM
BEFORE INSERT ON PAGO
FOR EACH ROW
DECLARE
  v_max_pago NUMBER;
BEGIN
  IF :NEW.NUM_PAGO IS NULL THEN

    SELECT NVL(MAX(NUM_PAGO), 0)
    INTO v_max_pago
    FROM PAGO
    WHERE ID_PRESTAMO = :NEW.ID_PRESTAMO;

    :NEW.NUM_PAGO := v_max_pago + 1;

  END IF;
END;
/

/* =======================================================================
  Trigger DELETE: impedir borrar cursos con ciudadanos matriculados.
  Cubre el evento de BORRADO (DELETE) exigido en la práctica.
   ======================================================================= */
CREATE OR REPLACE TRIGGER TRG_CURSO_NO_BORRAR_CON_MATRICULADOS
BEFORE DELETE ON CURSO
FOR EACH ROW
DECLARE
  v_count NUMBER;
BEGIN
  SELECT COUNT(*)
    INTO v_count
    FROM CIUDADANO
   WHERE ID_CURSO = :OLD.ID_CURSO;

  IF v_count > 0 THEN
    RAISE_APPLICATION_ERROR(
      -20006,
      'No se puede borrar el curso ' || :OLD.ID_CURSO || ' porque hay ciudadanos matriculados'
    );
  END IF;
END;
/





/* ==========================================================
  CREACIÓN DE ÍNDICES
   ========================================================== */

/* ----------------------------------------------------------
   Índices de tablas NO particionadas
   ---------------------------------------------------------- */

/* Cada curso pertenece a un organizador. 
   Este índice acelera los JOIN entre CURSO y ORGANIZADOR,
   optimizando la relación 1:N (Organiza). */
CREATE INDEX IDX_CURSO_ORGANIZADOR
  ON CURSO (ID_ORGANIZADOR);

/*  Índice sobre la FK de empresa en OFERTA.
    Mejora la obtención de las ofertas publicadas por una empresa
    y acelera los JOIN en la relación 1:N (Crea). */
CREATE INDEX IDX_OFERTA_EMPRESA
  ON OFERTA (ID_EMPRESA);



/* 
   Índices LOCAL para tablas particionadas
   (CONTRATO y SOLICITA)
   Nota:
   Las tablas particionadas requieren que los índices NO únicos 
   también se creen como LOCAL. De esta forma se genera un índice 
   por partición, lo que  mejora la carga ye l borrado de las mismas particiones
   y acelera busqeudas filtradas por las claves particionadas */

/*  Índice LOCAL por partición sobre la FK ID_OFERTA.
    Útil para localizar candidatos por oferta en la relación N:M. */
CREATE INDEX IDX_SOLICITA_OFERTA
  ON SOLICITA (ID_OFERTA)
  LOCAL;

/*  Índice LOCAL por partición sobre la FK DNI_CIUDADANO.
    Acelera búsquedas por ciudadano en sus solicitudes,
    manteniendo un índice por partición coherente con el 
    particionado anual de FECHA_SOLICITUD. */
CREATE INDEX IDX_SOLICITA_CIUDADANO
  ON SOLICITA (DNI_CIUDADANO)
  LOCAL;



/*  Índice LOCAL por partición sobre la FK DNI_CIUDADANO.
    Optimiza los accesos al historial laboral del ciudadano,
    generando un índice por año que facilita mantener y 
    consultar los contratos en tablas particionadas por FECHA_INICIO. */
CREATE INDEX IDX_CONTRATO_CIUDADANO
  ON CONTRATO (DNI_CIUDADANO)
  LOCAL;

/*  Índice LOCAL por partición sobre la FK ID_EMPRESA.
    Permite búsquedas rápidas de contratos por empresa y 
    mantiene consistencia con el particionado anual de CONTRATO. */
CREATE INDEX IDX_CONTRATO_EMPRESA
  ON CONTRATO (ID_EMPRESA)
  LOCAL;





/* ==========================================================
  VISTAS
   ========================================================== */

-- Vista no actualizable
/*Esta vista se basa en 2 tablas , OFERTA y EMPRESA , esta se diseña para consultar de forma conjunta la información de las ofertas publicadas y los datos de la empresa publicadora de ellos
sin la necesidad de tener que hacer un Join entre ambas tablas
Aunque no sea actualizable es muy util porque permite enlistar informes , listados o busquedas dentro del sistema SEPE para enlistar los puestos ofertados junto con el nombre y CIF de la empresa responsable
Su uso es consultivo y de presentación , no para modificar nada */
CREATE OR REPLACE VIEW V_OFERTAS_EMPRESAS AS
SELECT
  o.ID_OFERTA,
  o.PUESTO,
  o.REQUISITOS,
  e.NOMBRE AS NOMBRE_EMPRESA,
  e.CIF
FROM OFERTA o
JOIN EMPRESA e ON o.ID_EMPRESA = e.ID_EMPRESA;

-- Vista actualizable
/*Esta vista se crea para mostrar unicamente los cursos con plazas disponibles. Es actualizable al derivar de una sola tabla , en este caso CURSO
y no incluir funciones ni agregaciones , lo que permite modificar directamente los datos base (aumentar o disminuir el numero de plazas de un curso activo por inscripción o cancelación de un ciudadano
Su objetivo es simplificar la gestión de cursos activos en el SEPE y optimizar las operación de mantenimiento */
CREATE OR REPLACE VIEW V_CURSOS_CON_PLAZAS AS
SELECT
  ID_CURSO,
  NOMBRE,
  DURACION,
  PLAZAS
FROM CURSO
WHERE PLAZAS > 0;









/* ==========================================================
  INSERCIÓN DE DATOS
   ========================================================== */

/* PERSONA */
INSERT INTO PERSONA VALUES ('TST00001A', 'Gabriela', 'Rosales', DATE '1985-11-16');
INSERT INTO PERSONA VALUES ('TST00002B', 'Oscar', 'Rodriguez', DATE '1979-01-19');
INSERT INTO PERSONA VALUES ('TST00003C', 'Elena', 'Ortiz', DATE '1977-01-05');
INSERT INTO PERSONA VALUES ('TST00004D', 'Daniela', 'Garcia', DATE '2004-03-14');
INSERT INTO PERSONA VALUES ('TST00005E', 'Ignacio', 'Ramirez', DATE '1980-07-04');
INSERT INTO PERSONA VALUES ('TST00006F', 'Luis', 'Santos', DATE '2003-10-23');
INSERT INTO PERSONA VALUES ('TST00007G', 'Pablo', 'Hernandez', DATE '1985-10-16');
INSERT INTO PERSONA VALUES ('TST00008H', 'Emilio', 'Cruz', DATE '1975-11-16');
INSERT INTO PERSONA VALUES ('TST00009J', 'Roberto', 'Montes', DATE '2002-11-15');
INSERT INTO PERSONA VALUES ('TST00010K', 'Clara', 'Aguirre', DATE '2012-05-16');
INSERT INTO PERSONA VALUES ('TST00011L', 'Alejandro', 'Castillo', DATE '1998-12-15');

/* ORGANIZADOR */
INSERT INTO ORGANIZADOR VALUES (1001,'EMPRESA','Responsable Empresa 1','responsable1@example.invalid');
INSERT INTO ORGANIZADOR VALUES (1002,'EMPRESA','Responsable Empresa 2','responsable2@example.invalid');
INSERT INTO ORGANIZADOR VALUES (1003,'OFICINA','Responsable Oficina 1','oficina1@example.invalid');
INSERT INTO ORGANIZADOR VALUES (1004,'OFICINA','Responsable Oficina 2','oficina2@example.invalid');
INSERT INTO ORGANIZADOR VALUES (1005,'EMPRESA','Responsable Empresa 3','responsable3@example.invalid');

/* EMPRESA */
INSERT INTO EMPRESA VALUES (2001,'TESTCIF1A','Tech Solutions','Calle Mayor 10',1001);
INSERT INTO EMPRESA VALUES (2002,'TESTCIF2B','Consultores SA','Avenida Sol 45',1002);
INSERT INTO EMPRESA VALUES (2003,'TESTCIF3C','Marketing Plus','Plaza España 8',1005);
INSERT INTO EMPRESA VALUES (2004,'TESTCIF4D','Logística Express','Calle Norte 22',1001);
INSERT INTO EMPRESA VALUES (2005,'TESTCIF5E','SoftDev SL','Calle Sur 33',1002);

/* OFICINA */
INSERT INTO OFICINA VALUES (3001,'Madrid','911223344',1003);
INSERT INTO OFICINA VALUES (3002,'Barcelona','934556677',1004);
INSERT INTO OFICINA VALUES (3003,'Valencia','963112233',1003);
INSERT INTO OFICINA VALUES (3004,'Sevilla','954998877',1004);
INSERT INTO OFICINA VALUES (3005,'Bilbao','944556677',1003);


/* CURSO */
INSERT INTO CURSO VALUES (4001,'Curso Java Básico',60,20,1001);
INSERT INTO CURSO VALUES (4002,'Curso SQL Avanzado',40,15,1002);
INSERT INTO CURSO VALUES (4003,'Marketing Digital',30,25,1005);
INSERT INTO CURSO VALUES (4004,'Gestión de Proyectos',50,10,1003);
INSERT INTO CURSO VALUES (4005,'Atención al Cliente',20,30,1004);



/* CIUDADANO */
INSERT INTO CIUDADANO VALUES ('TST00001A','5 años en administración','Tiempo Completo','Grado',4001);
INSERT INTO CIUDADANO VALUES ('TST00002B','10 años en logística','Tiempo Parcial','Doctorado',4002);
INSERT INTO CIUDADANO VALUES ('TST00003C','3 años en ventas','Tiempo Completo','Bachillerato',4003);
INSERT INTO CIUDADANO VALUES ('TST00004D','1 año como becaria','Tiempo Parcial','Grado en ADE',4004);
INSERT INTO CIUDADANO VALUES ('TST00005E','7 años en informática','Tiempo Completo','Grado en Ingeniería Informática',4005);


/* FUNCIONARIO */
/* FUNCIONARIO (con relación reflexiva SUPERVISA) */
INSERT INTO FUNCIONARIO VALUES ('TST00011L','Director','A1',DATE '2010-11-30',3005,NULL);
INSERT INTO FUNCIONARIO VALUES ('TST00009J','Inspector','A1',DATE '2018-01-20',3003,'TST00011L');
INSERT INTO FUNCIONARIO VALUES ('TST00008H','Gestor','A2',DATE '2012-07-10',3002,'TST00011L');
INSERT INTO FUNCIONARIO VALUES ('TST00007G','Técnico','A1',DATE '2015-03-01',3001,'TST00009J');
INSERT INTO FUNCIONARIO VALUES ('TST00010K','Auxiliar','C1',DATE '2020-09-14',3004,'TST00008H');




/* OFERTA */
INSERT INTO OFERTA VALUES (5001,'Programador Junior','Conocimientos básicos en Java',2001);
INSERT INTO OFERTA VALUES (5002,'Consultor SAP','Experiencia mínima 2 años en SAP',2002);
INSERT INTO OFERTA VALUES (5003,'Community Manager','Gestión de redes sociales y marketing',2003);
INSERT INTO OFERTA VALUES (5004,'Mozo de almacén','Experiencia en logística',2004);
INSERT INTO OFERTA VALUES (5005,'Desarrollador Frontend','React, JavaScript, CSS',2005);

/* CONTRATO */
INSERT INTO CONTRATO VALUES (6001,'Temporal',DATE '2023-01-01',DATE '2023-06-30',2001,'TST00001A');
INSERT INTO CONTRATO VALUES (6002,'Indefinido',DATE '2022-05-01',DATE '2030-12-31',2002,'TST00002B');
INSERT INTO CONTRATO VALUES (6003,'Prácticas',DATE '2023-03-01',DATE '2023-09-01',2003,'TST00003C');
INSERT INTO CONTRATO VALUES (6004,'Temporal',DATE '2023-02-01',DATE '2023-05-31',2004,'TST00004D');
INSERT INTO CONTRATO VALUES (6005,'Indefinido',DATE '2021-10-01',DATE '2029-10-01',2005,'TST00005E');

/* SOLICITA */
INSERT INTO SOLICITA VALUES ('TST00001A',5001,'PENDIENTE',DATE '2023-01-15');
INSERT INTO SOLICITA VALUES ('TST00002B',5002,'ACEPTADA',DATE '2023-02-10');
INSERT INTO SOLICITA VALUES ('TST00003C',5003,'RECHAZADA',DATE '2023-03-12');
INSERT INTO SOLICITA VALUES ('TST00004D',5004,'PENDIENTE',DATE '2023-04-01');
INSERT INTO SOLICITA VALUES ('TST00005E',5005,'ACEPTADA',DATE '2023-05-20');

/* PRESTAMO */
INSERT INTO PRESTAMO VALUES (7001,'Subvención estatal',DATE '2023-01-20','TST00001A');
INSERT INTO PRESTAMO VALUES (7002,'Beca formación',DATE '2023-02-15','TST00002B');
INSERT INTO PRESTAMO VALUES (7003,'Ayuda empleo joven',DATE '2023-03-10','TST00003C');
INSERT INTO PRESTAMO VALUES (7004,'Subvención autonómica',DATE '2023-04-05','TST00004D');
INSERT INTO PRESTAMO VALUES (7005,'Ayuda transporte',DATE '2023-05-25','TST00005E');

/* PAGO */
INSERT INTO PAGO VALUES (7001, 1, 500.00);
INSERT INTO PAGO VALUES (7002, 1, 300.00);
INSERT INTO PAGO VALUES (7003, 1, 200.00);
INSERT INTO PAGO VALUES (7004, 1, 450.00);
INSERT INTO PAGO VALUES (7005, 1, 600.00);




/* ==========================================================
  CONSULTAS DE COMPROBACIÓN
   ========================================================== */

-- Ciudadano y su nivel de formación
SELECT NOMBRE, NIVEL_FORMACION
FROM PERSONA
JOIN CIUDADANO ON PERSONA.DNI = CIUDADANO.DNI_CIUDADANO
WHERE CIUDADANO.DNI_CIUDADANO = 'TST00005E';

-- Pagos realizados a un ciudadano concreto
SELECT p.NUM_PAGO, p.IMPORTE, pr.FORMA_OTORGAMIENTO
FROM PAGO p
JOIN PRESTAMO pr ON p.ID_PRESTAMO = pr.ID_PRESTAMO
WHERE pr.DNI_CIUDADANO = 'TST00002B';

-- 1. Listar todas las personas registradas
SELECT * FROM PERSONA;

-- 2. Mostrar todos los ciudadanos con su experiencia laboral y formación
SELECT DNI_CIUDADANO, EXP_LABORAL, DISPONIBILIDAD, NIVEL_FORMACION
FROM CIUDADANO;

-- 3. Mostrar todas las empresas y sus organizadores
SELECT ID_EMPRESA, NOMBRE, CIF, ID_ORGANIZADOR
FROM EMPRESA;

-- 4. Mostrar oficinas y la localidad
SELECT ID_OFICINA, LOCALIDAD, TELEFONO, ID_ORGANIZADOR
FROM OFICINA;

-- 5. Mostrar funcionarios y su oficina
SELECT DNI_FUNCIONARIO, PUESTO, CATEGORIA, ID_OFICINA
FROM FUNCIONARIO;

-- 6. Ciudadanos junto con su información personal (join 1:1)
SELECT p.NOMBRE, p.APELLIDOS, c.NIVEL_FORMACION, c.DISPONIBILIDAD
FROM PERSONA p
JOIN CIUDADANO c ON p.DNI = c.DNI_CIUDADANO;

-- 7. Ofertas con el nombre de la empresa (1:N)
SELECT o.ID_OFERTA, o.PUESTO, e.NOMBRE AS EMPRESA, e.CIF
FROM OFERTA o
JOIN EMPRESA e ON o.ID_EMPRESA = e.ID_EMPRESA;

-- 8. Cursos con su organizador (1:N)
SELECT c.ID_CURSO, c.NOMBRE, o.TIPO AS ORGANIZADOR, o.RESPONSABLE
FROM CURSO c
JOIN ORGANIZADOR o ON c.ID_ORGANIZADOR = o.ID_ORGANIZADOR;

-- 9. Contratos con ciudadano y empresa (dos FKs)
SELECT co.ID_CONTRATO, co.TIPO, p.NOMBRE AS CIUDADANO, e.NOMBRE AS EMPRESA
FROM CONTRATO co
JOIN CIUDADANO c ON co.DNI_CIUDADANO = c.DNI_CIUDADANO
JOIN PERSONA p ON c.DNI_CIUDADANO = p.DNI
JOIN EMPRESA e ON co.ID_EMPRESA = e.ID_EMPRESA;
-- 10. Ofertas solicitadas por ciudadanos con estado de solicitud
SELECT p.NOMBRE AS CIUDADANO, o.PUESTO, s.ESTADO, s.FECHA_SOLICITUD
FROM SOLICITA s
JOIN CIUDADANO c ON s.DNI_CIUDADANO = c.DNI_CIUDADANO
JOIN PERSONA p ON c.DNI_CIUDADANO = p.DNI
JOIN OFERTA o ON s.ID_OFERTA = o.ID_OFERTA
ORDER BY s.FECHA_SOLICITUD DESC;

-- 11. Préstamos y pagos asociados (1:N)
SELECT pr.ID_PRESTAMO, pr.FORMA_OTORGAMIENTO, pr.FECHA_RESOLUCION,
      pa.NUM_PAGO, pa.IMPORTE
FROM PRESTAMO pr
LEFT JOIN PAGO pa ON pr.ID_PRESTAMO = pa.ID_PRESTAMO
ORDER BY pr.ID_PRESTAMO;

-- 12. Listar funcionarios y sus supervisores (relación reflexiva)
SELECT f1.DNI_FUNCIONARIO AS FUNCIONARIO, f1.PUESTO,
      f2.DNI_FUNCIONARIO AS SUPERVISOR, f2.PUESTO AS PUESTO_SUPERVISOR
FROM FUNCIONARIO f1
LEFT JOIN FUNCIONARIO f2 ON f1.DNI_SUPERVISOR = f2.DNI_FUNCIONARIO;

-- 13. Ciudadanos con sus préstamos y pagos (combinación 1:1 + 1:N)
SELECT p.NOMBRE AS CIUDADANO, pr.FORMA_OTORGAMIENTO, pa.NUM_PAGO, pa.IMPORTE
FROM PERSONA p
JOIN CIUDADANO c ON p.DNI = c.DNI_CIUDADANO
JOIN PRESTAMO pr ON pr.DNI_CIUDADANO = c.DNI_CIUDADANO
LEFT JOIN PAGO pa ON pa.ID_PRESTAMO = pr.ID_PRESTAMO
ORDER BY p.NOMBRE;

/*Comprobacion de existencia de indices */
SELECT INDEX_NAME, TABLE_NAME, COLUMN_NAME
FROM USER_IND_COLUMNS
WHERE TABLE_NAME IN ('CURSO','OFERTA','SOLICITA','CONTRATO')
ORDER BY TABLE_NAME;

-- Cursos ordenados por duración (vista actualizable)
SELECT NOMBRE, DURACION, PLAZAS
FROM V_CURSOS_CON_PLAZAS
ORDER BY DURACION ;

-- Busca todas las ofertas que mencionen la palabra 'Java' en sus requisitos
SELECT 
  NOMBRE_EMPRESA, 
  PUESTO, 
  REQUISITOS
FROM V_OFERTAS_EMPRESAS
WHERE LOWER(REQUISITOS) LIKE '%java%'
ORDER BY NOMBRE_EMPRESA;



/* ==========================================================
  PROCESOS PL/SQL - PRÁCTICA 3
   ========================================================== */




/* ----------------------------------------------------------
  1) PROC_ALTA_SOLICITUD_OFERTA
     Este procedimiento da de alta una nueva solicitud en la 
     tabla SOLICITA, asignándole el estado inicial 'PENDIENTE'.

     Para validar la existencia del ciudadano se emplea un 
     cursor explícito, lo cual permite comprobar la existencia del registro de 
     forma controlada. La oferta se valida mediante una consulta 
     directa al tratarse de una comprobación sencilla.

     Si ambos existen, se inserta la solicitud con la fecha del 
     día. Además, se controla la excepción DUP_VAL_ON_INDEX, 
     que se genera cuando ya existe una solicitud previa para 
     esa pareja (DNI_CIUDADANO, ID_OFERTA), garantizando así 
     que no haya duplicados en la clave primaria compuesta.
   ---------------------------------------------------------- */


CREATE OR REPLACE PROCEDURE PROC_ALTA_SOLICITUD_OFERTA (
    p_dni_ciudadano IN CIUDADANO.DNI_CIUDADANO%TYPE,
    p_id_oferta     IN OFERTA.ID_OFERTA%TYPE
) IS
    v_dummy NUMBER;
    v_existe_oferta NUMBER;

    -- Cursor  para validar existencia del ciudadano
    CURSOR c_ciudadano IS
        SELECT 1
        FROM CIUDADANO
        WHERE DNI_CIUDADANO = p_dni_ciudadano;

BEGIN
    -- Validar ciudadano mediante cursor
    OPEN c_ciudadano;
    FETCH c_ciudadano INTO v_dummy;
    IF c_ciudadano%NOTFOUND THEN
        CLOSE c_ciudadano;
        RAISE_APPLICATION_ERROR(-20010,
            'No existe ningún ciudadano con DNI ' || p_dni_ciudadano);
    END IF;
    CLOSE c_ciudadano;

    -- Comprobar que la oferta existe (esto lo dejamos igual)
    SELECT COUNT(*)
    INTO v_existe_oferta
    FROM OFERTA
    WHERE ID_OFERTA = p_id_oferta;

    IF v_existe_oferta = 0 THEN
        RAISE_APPLICATION_ERROR(
            -20011,
            'No existe ninguna oferta con ID ' || p_id_oferta
        );
    END IF;

    -- Intentar crear la solicitud en estado PENDIENTE
    INSERT INTO SOLICITA (
        DNI_CIUDADANO,
        ID_OFERTA,
        ESTADO,
        FECHA_SOLICITUD
    )
    VALUES (
        p_dni_ciudadano,
        p_id_oferta,
        'PENDIENTE',
        TRUNC(SYSDATE)
    );

    DBMS_OUTPUT.PUT_LINE(
        'Solicitud creada correctamente para ' || p_dni_ciudadano ||
        ' en la oferta ' || p_id_oferta
    );

EXCEPTION
    WHEN DUP_VAL_ON_INDEX THEN
        RAISE_APPLICATION_ERROR(
            -20012,
            'Ya existe una solicitud para ese ciudadano y esa oferta.'
        );
    WHEN OTHERS THEN
        RAISE_APPLICATION_ERROR(
            -20999,
            'Error inesperado en PROC_ALTA_SOLICITUD_OFERTA: ' || SQLERRM
        );
END;
/




/* ----------------------------------------------------------
  2) PROC_BAJA_CIUDADANO_CURSO
    Este procedimiento desmatricula a un ciudadano de su curso actual. 
    Para validar la existencia del ciudadano se emplea un cursor explícito 
    que recupera por completo su registro, permitiendo comprobar de forma 
    controlada tanto que el DNI existe como si tiene o no un curso asignado.

    Una vez verificado que el ciudadano está matriculado, se utiliza un 
    segundo cursor para comprobar la existencia del curso asociado antes 
    de devolver la plaza correspondiente. Tras recuperar el registro del 
    curso, se incrementa su número de plazas y se deja el campo ID_CURSO 
    del ciudadano a NULL para completar la baja.

    El procedimiento gestiona de forma específica el caso de ciudadanos 
    sin matrícula y controla también la situación en la que el DNI no 
    existe. Cualquier otro error inesperado se captura mediante una 
    excepción controlada para asegurar la consistencia del sistema.

   ---------------------------------------------------------- */

CREATE OR REPLACE PROCEDURE PROC_BAJA_CIUDADANO_CURSO (
    p_dni_ciudadano IN CIUDADANO.DNI_CIUDADANO%TYPE
) IS
    regCiu    CIUDADANO%ROWTYPE;
    regCurso  CURSO%ROWTYPE;

    CURSOR c_ciu IS
        SELECT *
        FROM CIUDADANO
        WHERE DNI_CIUDADANO = p_dni_ciudadano;

    CURSOR c_curso IS
        SELECT *
        FROM CURSO
        WHERE ID_CURSO = regCiu.ID_CURSO;

BEGIN
    -- Recuperar ciudadano usando cursor
    OPEN c_ciu;
    FETCH c_ciu INTO regCiu;

    IF c_ciu%NOTFOUND THEN
        CLOSE c_ciu;
        RAISE_APPLICATION_ERROR(
            -20022,
            'No existe ningún ciudadano con DNI ' || p_dni_ciudadano
        );
    END IF;

    CLOSE c_ciu;

    -- Comprobar si no está matriculado en ningún curso
    IF regCiu.ID_CURSO IS NULL THEN
        RAISE_APPLICATION_ERROR(
            -20020,
            'El ciudadano ' || p_dni_ciudadano ||
            ' no está matriculado en ningún curso.'
        );
    END IF;

    -- Validar curso mediante cursor
    OPEN c_curso;
    FETCH c_curso INTO regCurso;

    IF c_curso%NOTFOUND THEN
        CLOSE c_curso;
        RAISE_APPLICATION_ERROR(
            -20021,
            'No se ha encontrado el curso ' || regCiu.ID_CURSO
        );
    END IF;

    CLOSE c_curso;

    -- Devolver la plaza al curso
    UPDATE CURSO
    SET PLAZAS = PLAZAS + 1
    WHERE ID_CURSO = regCiu.ID_CURSO;

    -- Desmatricular ciudadano
    UPDATE CIUDADANO
    SET ID_CURSO = NULL
    WHERE DNI_CIUDADANO = p_dni_ciudadano;

    DBMS_OUTPUT.PUT_LINE(
        'Ciudadano ' || p_dni_ciudadano ||
        ' dado de baja del curso ' || regCiu.ID_CURSO
    );

EXCEPTION
    WHEN OTHERS THEN
        RAISE_APPLICATION_ERROR(
            -20998,
            'Error inesperado en PROC_BAJA_CIUDADANO_CURSO: ' || SQLERRM
        );
END;
/





/* ----------------------------------------------------------
  3) FN_IMPORTE_TOTAL_PAGADO
     Esta función calcula el importe total pagado por un 
     ciudadano recorriendo individualmente todos los pagos 
     asociados a sus préstamos mediante un cursor explícito.

     Antes de realizar cualquier operación valida que el 
     ciudadano exista, lanzando una excepción específica si 
     no se encuentra en el sistema.

     El cursor recupera los importes de todos los pagos 
     vinculados al ciudadano (incluyendo préstamos sin pagos, 
     que simplemente no aportan valor a la suma). Dentro del 
     bucle se van acumulando los importes válidos hasta 
     obtener el total final.

     El uso del cursor permite controlar de forma explícita 
     cada fila procesada, siguiendo la misma lógica aplicada 
     en otros procesos de la práctica basados en navegación 
     secuencial de registros.

     Cualquier error inesperado se captura y se reporta 
     mediante una excepción controlada , ademas se gestiona de forma
     especifica la posible aparicion de errores de conversion numericas.
   ---------------------------------------------------------- */


CREATE OR REPLACE FUNCTION FN_IMPORTE_TOTAL_PAGADO (
    p_dni_ciudadano IN CIUDADANO.DNI_CIUDADANO%TYPE
) RETURN NUMBER IS

    v_existe_ciud NUMBER;
    v_total       NUMBER := 0;
    v_importe     PAGO.IMPORTE%TYPE;

    CURSOR c_pagos IS
        SELECT pa.IMPORTE
        FROM PRESTAMO pr
        LEFT JOIN PAGO pa ON pa.ID_PRESTAMO = pr.ID_PRESTAMO
        WHERE pr.DNI_CIUDADANO = p_dni_ciudadano;

BEGIN
    -- Validar existencia del ciudadano
    SELECT COUNT(*) INTO v_existe_ciud
    FROM CIUDADANO
    WHERE DNI_CIUDADANO = p_dni_ciudadano;

    IF v_existe_ciud = 0 THEN
        RAISE_APPLICATION_ERROR(
            -20030,
            'No existe ningún ciudadano con DNI ' || p_dni_ciudadano
        );
    END IF;

    -- Recorrer pagos 
    OPEN c_pagos;
    LOOP
        FETCH c_pagos INTO v_importe;
        EXIT WHEN c_pagos%NOTFOUND;

        IF v_importe IS NOT NULL THEN
            v_total := v_total + v_importe;
        END IF;
    END LOOP;
    CLOSE c_pagos;

    RETURN v_total;

EXCEPTION
  WHEN VALUE_ERROR THEN
    RAISE_APPLICATION_ERROR(
        -20031,
        'Error en la conversión de importes de pagos.'
    );

    WHEN OTHERS THEN
        RAISE_APPLICATION_ERROR(
            -20997,
            'Error inesperado en FN_IMPORTE_TOTAL_PAGADO: ' || SQLERRM
        );
END;
/



/* ----------------------------------------------------------
  4) PROC_MATRICULAR_CIUD
     Este procedimiento matricula a un ciudadano en un curso.
     Utiliza dos cursores explícitos para recuperar los 
     registros completos de CIUDADANO y CURSO, permitiendo 
     validar varias condiciones antes de actualizar los datos 
     (existencia, plazas disponibles y si ya está matriculado).

     Una vez validadas todas las reglas de negocio, se asigna 
     el curso al ciudadano y se decrementa el número de plazas 
     del curso correspondiente. El procedimiento define 
     excepciones específicas para cada situación de error 
     (ciudadano inexistente, curso inexistente, sin plazas o 
     matrícula duplicada), garantizando así un control preciso 
     de la lógica de inscripción.
   ---------------------------------------------------------- */



CREATE OR REPLACE PROCEDURE proc_matricular_ciudad(
  p_dni_ciudadano IN VARCHAR2,
  p_id_curso      IN NUMBER
)
IS
  regCiu    CIUDADANO%ROWTYPE;
  regCurso  CURSO%ROWTYPE;

  CIUD_YA_MATRICULADO EXCEPTION;
  CIUD_NO_EXISTE EXCEPTION;
  CURSO_NO_EXISTE EXCEPTION;
  SIN_PLAZAS EXCEPTION;

  CURSOR c_ciu IS
    SELECT * FROM CIUDADANO WHERE DNI_CIUDADANO = p_dni_ciudadano;

  CURSOR c_curso IS
    SELECT * FROM CURSO WHERE ID_CURSO = p_id_curso;

BEGIN
  -- Validar ciudadano
  OPEN c_ciu;
  FETCH c_ciu INTO regCiu;
  IF c_ciu%NOTFOUND THEN
    CLOSE c_ciu;
    RAISE CIUD_NO_EXISTE;
  END IF;

  IF regCiu.ID_CURSO = p_id_curso THEN
    CLOSE c_ciu;
    RAISE CIUD_YA_MATRICULADO;
  END IF;
  CLOSE c_ciu;

  -- Validar curso
  OPEN c_curso;
  FETCH c_curso INTO regCurso;
  IF c_curso%NOTFOUND THEN
    CLOSE c_curso;
    RAISE CURSO_NO_EXISTE;
  END IF;

  IF regCurso.PLAZAS <= 0 THEN
    CLOSE c_curso;
    RAISE SIN_PLAZAS;
  END IF;
  CLOSE c_curso;

  -- Actualizar datos
  UPDATE CIUDADANO
    SET ID_CURSO = p_id_curso
  WHERE DNI_CIUDADANO = p_dni_ciudadano;

  UPDATE CURSO
    SET PLAZAS = PLAZAS - 1
  WHERE ID_CURSO = p_id_curso;

  COMMIT;
  DBMS_OUTPUT.PUT_LINE('Ciudadano matriculado con éxito.');

EXCEPTION
  WHEN CIUD_YA_MATRICULADO THEN
    RAISE_APPLICATION_ERROR(-20031,'El ciudadano ya está matriculado en ese curso.');
  WHEN CIUD_NO_EXISTE THEN
    RAISE_APPLICATION_ERROR(-20032,'El ciudadano no existe.');
  WHEN CURSO_NO_EXISTE THEN
    RAISE_APPLICATION_ERROR(-20033,'El curso no existe.');
  WHEN SIN_PLAZAS THEN
    RAISE_APPLICATION_ERROR(-20034,'El curso no tiene plazas disponibles.');
  WHEN OTHERS THEN
    RAISE;
END proc_matricular_ciudad;
/


/* ----------------------------------------------------------
  5) PROC_CONCEDER_PRESTAMO
     Este procedimiento concede un nuevo préstamo a un ciudadano. 
     Utiliza un cursor para validar la existencia del ciudadano 
     antes de continuar, ya que se necesita acceder a su registro 
     completo. También comprueba que el número de pagos solicitado 
     sea válido, calculando el importe de cada uno mediante una 
     división proporcional del total.

     Una vez insertado el préstamo, se generan automáticamente 
     los pagos asociados mediante un bucle FOR, creando para cada 
     uno una entrada en la tabla PAGO con su número de pago y el 
     importe correspondiente. El procedimiento define excepciones 
     específicas para controlar situaciones comunes como ciudadanos 
     inexistentes o número de pagos no válido, garantizando así un 
     flujo consistente y seguro en la creación del préstamo.
   ---------------------------------------------------------- */


CREATE OR REPLACE PROCEDURE proc_conceder_prestamo(
  p_id_prestamo   IN NUMBER,
  p_dni_ciudadano IN VARCHAR2,
  p_forma         IN VARCHAR2,
  p_fecha         IN DATE,
  p_importe_total IN NUMBER,
  p_num_pagos     IN NUMBER
)
IS
  v_importe_pago NUMBER;

  PAGOS_INVALIDOS EXCEPTION;
  CIUDANO_NO_EXISTE EXCEPTION;

  regCiu CIUDADANO%ROWTYPE;

  CURSOR c_ciu IS
    SELECT * FROM CIUDADANO WHERE DNI_CIUDADANO = p_dni_ciudadano;

BEGIN
  -- Validar ciudadano
  OPEN c_ciu;
  FETCH c_ciu INTO regCiu;
  IF c_ciu%NOTFOUND THEN
    CLOSE c_ciu;
    RAISE CIUDANO_NO_EXISTE;
  END IF;
  CLOSE c_ciu;

  -- Validar número de pagos
  IF p_num_pagos <= 0 THEN
    RAISE PAGOS_INVALIDOS;
  END IF;

  v_importe_pago := p_importe_total / p_num_pagos;

  
  -- Insertar préstamo
  
  INSERT INTO PRESTAMO(ID_PRESTAMO, FORMA_OTORGAMIENTO, FECHA_RESOLUCION, DNI_CIUDADANO)
  VALUES (p_id_prestamo, p_forma, p_fecha, p_dni_ciudadano);

  DBMS_OUTPUT.PUT_LINE('Préstamo registrado. Generando pagos...');

  ---------------------------------------------------------
  -- Insertar pagos (PK = ID_PRESTAMO + NUM_PAGO)
  ---------------------------------------------------------
  FOR i IN 1..p_num_pagos LOOP
    INSERT INTO PAGO(ID_PRESTAMO, NUM_PAGO, IMPORTE)
    VALUES (p_id_prestamo, i, v_importe_pago);
  END LOOP;

  COMMIT;
  DBMS_OUTPUT.PUT_LINE('Pagos generados correctamente.');

EXCEPTION
  WHEN PAGOS_INVALIDOS THEN
    RAISE_APPLICATION_ERROR(-20035, 'El número de pagos debe ser mayor que cero.');
  WHEN CIUDANO_NO_EXISTE THEN
    RAISE_APPLICATION_ERROR(-20036, 'El ciudadano no existe.');
  WHEN OTHERS THEN
    RAISE;
END proc_conceder_prestamo;
/

/* ----------------------------------------------------------
  6) PROC_RESOLVER_OFERTAS
     Este procedimiento resuelve todas las solicitudes en 
     estado 'PENDIENTE' para una oferta concreta. Primero 
     valida que la oferta exista y, a continuación, utiliza 
     un cursor FOR UPDATE para recorrer las solicitudes y 
     bloquear cada registro mientras se procesa.

     El uso de FOR UPDATE es necesario porque garantiza que 
     ninguna otra sesión pueda modificar esas mismas filas 
     de SOLICITA durante la resolución. Esto evita condiciones 
     de carrera, asegura que el recuento de plazas sea coherente 
     y permite actualizar cada fila de forma segura mediante 
     la cláusula WHERE CURRENT OF.

     Cada solicitud se marca como 'ACEPTADA' o 'RECHAZADA' en 
     función del número de plazas disponibles, el cual se 
     decrementa conforme se aceptan solicitudes. Si la oferta 
     no existe, se lanza una excepción específica; cualquier 
     otro error se captura mediante la gestión general.
   ---------------------------------------------------------- */


CREATE OR REPLACE PROCEDURE proc_resolver_ofertas (
  p_id_oferta            IN NUMBER,
  p_plazas_disponibles   IN NUMBER
)
IS
  regSol SOLICITA%ROWTYPE;
  v_plazas NUMBER := p_plazas_disponibles;

  OFERTA_NO_EXISTE EXCEPTION;

  CURSOR c_solicitudes IS
    SELECT *
    FROM SOLICITA
    WHERE ID_OFERTA = p_id_oferta
      AND ESTADO = 'PENDIENTE'
    FOR UPDATE;
    
BEGIN
  
  -- Validar existencia de la oferta
  
  DECLARE
    v_tmp NUMBER;
  BEGIN
    SELECT COUNT(*) INTO v_tmp FROM OFERTA WHERE ID_OFERTA = p_id_oferta;
    IF v_tmp = 0 THEN
      RAISE OFERTA_NO_EXISTE;
    END IF;
  END;

  DBMS_OUTPUT.PUT_LINE('Procesando solicitudes...');

  ----------------------------------------------------
  -- Cursor FOR UPDATE
  ----------------------------------------------------
  OPEN c_solicitudes;

  LOOP
    FETCH c_solicitudes INTO regSol;
    EXIT WHEN c_solicitudes%NOTFOUND;

    IF v_plazas > 0 THEN
      UPDATE SOLICITA
        SET ESTADO = 'ACEPTADA'
      WHERE CURRENT OF c_solicitudes;

      v_plazas := v_plazas - 1;
    ELSE
      UPDATE SOLICITA
        SET ESTADO = 'RECHAZADA'
      WHERE CURRENT OF c_solicitudes;
    END IF;
  END LOOP;

  CLOSE c_solicitudes;

  COMMIT;

  DBMS_OUTPUT.PUT_LINE('Solicitudes resueltas correctamente.');

EXCEPTION
  WHEN OFERTA_NO_EXISTE THEN
    RAISE_APPLICATION_ERROR(-20037, 'La oferta no existe.');
  WHEN OTHERS THEN
    RAISE;
END proc_resolver_ofertas;
/



/* ==========================================================
    BLOQUE PRINCIPAL DE EJECUCIÓN DE PROCESOS
   ========================================================== */

SET SERVEROUTPUT ON;

DECLARE
    v_total_pagado NUMBER;
BEGIN
    DBMS_OUTPUT.NEW_LINE;

    ----------------------------------------------------------
    -- 1) PROC_ALTA_SOLICITUD_OFERTA
    ----------------------------------------------------------
    BEGIN
        DBMS_OUTPUT.PUT_LINE('======> INICIO: PROC_ALTA_SOLICITUD_OFERTA');
        PROC_ALTA_SOLICITUD_OFERTA('TST00001A', 5003);
        DBMS_OUTPUT.PUT_LINE('======> FIN: PROC_ALTA_SOLICITUD_OFERTA');
        DBMS_OUTPUT.NEW_LINE;
    EXCEPTION
        WHEN OTHERS THEN
            DBMS_OUTPUT.PUT_LINE('[EXCEPCIÓN en PROC_ALTA_SOLICITUD_OFERTA]');
            DBMS_OUTPUT.PUT_LINE('[Código]: ' || SQLCODE);
            DBMS_OUTPUT.PUT_LINE('[Mensaje]: ' || SQLERRM);
            DBMS_OUTPUT.NEW_LINE;
    END;


    ----------------------------------------------------------
    -- 2) PROC_BAJA_CIUDADANO_CURSO
    ----------------------------------------------------------
    BEGIN
        DBMS_OUTPUT.PUT_LINE('======> INICIO: PROC_BAJA_CIUDADANO_CURSO');
        PROC_BAJA_CIUDADANO_CURSO('TST00005E');
        DBMS_OUTPUT.PUT_LINE('======> FIN: PROC_BAJA_CIUDADANO_CURSO');
        DBMS_OUTPUT.NEW_LINE;
    EXCEPTION
        WHEN OTHERS THEN
            DBMS_OUTPUT.PUT_LINE('[EXCEPCIÓN en PROC_BAJA_CIUDADANO_CURSO]');
            DBMS_OUTPUT.PUT_LINE('[Código]: ' || SQLCODE);
            DBMS_OUTPUT.PUT_LINE('[Mensaje]: ' || SQLERRM);
            DBMS_OUTPUT.NEW_LINE;
    END;


    ----------------------------------------------------------
    -- 3) FN_IMPORTE_TOTAL_PAGADO
    ----------------------------------------------------------
    BEGIN
        DBMS_OUTPUT.PUT_LINE('======> INICIO: FN_IMPORTE_TOTAL_PAGADO');
        v_total_pagado := FN_IMPORTE_TOTAL_PAGADO('TST00002B');
        DBMS_OUTPUT.PUT_LINE('Importe total pagado por TST00002B: ' || v_total_pagado);
        DBMS_OUTPUT.PUT_LINE('======> FIN: FN_IMPORTE_TOTAL_PAGADO');
        DBMS_OUTPUT.NEW_LINE;
    EXCEPTION
        WHEN OTHERS THEN
            DBMS_OUTPUT.PUT_LINE('[EXCEPCIÓN en FN_IMPORTE_TOTAL_PAGADO]');
            DBMS_OUTPUT.PUT_LINE('[Código]: ' || SQLCODE);
            DBMS_OUTPUT.PUT_LINE('[Mensaje]: ' || SQLERRM);
            DBMS_OUTPUT.NEW_LINE;
    END;


    ----------------------------------------------------------
    -- 4) PROC_MATRICULAR_CIUDAD (tras la baja anterior)
    ----------------------------------------------------------
    BEGIN
        DBMS_OUTPUT.PUT_LINE('======> INICIO: PROC_MATRICULAR_CIUDAD');
        proc_matricular_ciudad('TST00005E', 4001);
        DBMS_OUTPUT.PUT_LINE('======> FIN: PROC_MATRICULAR_CIUDAD');
        DBMS_OUTPUT.NEW_LINE;
    EXCEPTION
        WHEN OTHERS THEN
            DBMS_OUTPUT.PUT_LINE('[EXCEPCIÓN en PROC_MATRICULAR_CIUDAD]');
            DBMS_OUTPUT.PUT_LINE('[Código]: ' || SQLCODE);
            DBMS_OUTPUT.PUT_LINE('[Mensaje]: ' || SQLERRM);
            DBMS_OUTPUT.NEW_LINE;
    END;


----------------------------------------------------------
-- 5) PROC_CONCEDER_PRESTAMO
-- Nota: Este proceso generará una excepción controlada si el
-- ciudadano ya tiene un préstamo asociado, porque la tabla
-- PRESTAMO define la columna DNI_CIUDADANO como UNIQUE.
-- En este caso el ciudadano TST00001A si ya dispone del préstamo 7001,
-- por lo que al intentar crear el préstamo 8001 se lanza 
-- ORA-00001 (violación de restricción única), lo cual es 
-- un comportamiento correcto y esperado del sistema.
----------------------------------------------------------

    BEGIN
        DBMS_OUTPUT.PUT_LINE('======> INICIO: PROC_CONCEDER_PRESTAMO');
        proc_conceder_prestamo(
            p_id_prestamo   => 8001,
            p_dni_ciudadano => 'TST00001A',
            p_forma         => 'Nuevo préstamo',
            p_fecha         => SYSDATE,
            p_importe_total => 1000,
            p_num_pagos     => 4
        );
        DBMS_OUTPUT.PUT_LINE('======> FIN: PROC_CONCEDER_PRESTAMO');
        DBMS_OUTPUT.NEW_LINE;
    EXCEPTION
        WHEN OTHERS THEN
            DBMS_OUTPUT.PUT_LINE('[EXCEPCIÓN en PROC_CONCEDER_PRESTAMO]');
            DBMS_OUTPUT.PUT_LINE('[Código]: ' || SQLCODE);
            DBMS_OUTPUT.PUT_LINE('[Mensaje]: ' || SQLERRM);
            DBMS_OUTPUT.NEW_LINE;
    END;


    ----------------------------------------------------------
    -- 6) PROC_RESOLVER_OFERTAS
    ----------------------------------------------------------
    BEGIN
        DBMS_OUTPUT.PUT_LINE('======> INICIO: PROC_RESOLVER_OFERTAS');
        proc_resolver_ofertas(5001, 1);
        DBMS_OUTPUT.PUT_LINE('======> FIN: PROC_RESOLVER_OFERTAS');
        DBMS_OUTPUT.NEW_LINE;
    EXCEPTION
        WHEN OTHERS THEN
            DBMS_OUTPUT.PUT_LINE('[EXCEPCIÓN en PROC_RESOLVER_OFERTAS]');
            DBMS_OUTPUT.PUT_LINE('[Código]: ' || SQLCODE);
            DBMS_OUTPUT.PUT_LINE('[Mensaje]: ' || SQLERRM);
            DBMS_OUTPUT.NEW_LINE;
    END;

EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('[EXCEPCIÓN NO CONTROLADA EN EL BLOQUE PRINCIPAL]');
        DBMS_OUTPUT.PUT_LINE('[Código]: ' || SQLCODE);
        DBMS_OUTPUT.PUT_LINE('[Mensaje]: ' || SQLERRM);
END;
/



/* ==========================================================
  BLOQUE ANÓNIMO DE PRUEBAS DE TRIGGERS (P4)
  - Fuerza ejecución de triggers.
  - Muestra casos OK y casos con excepción.
   ========================================================== */

DECLARE
  -- IDs y DNIs de prueba (fuera del rango de los datos iniciales)
  c_id_curso     CURSO.ID_CURSO%TYPE := 9001;
  c_id_oficina   OFICINA.ID_OFICINA%TYPE := 9001;
  c_id_oferta    OFERTA.ID_OFERTA%TYPE := 9001;

  c_id_contrato_bad CONTRATO.ID_CONTRATO%TYPE := 9001;
  c_id_contrato_ok  CONTRATO.ID_CONTRATO%TYPE := 9002;

  c_id_prestamo  PRESTAMO.ID_PRESTAMO%TYPE := 9001;

  c_dni_c1 PERSONA.DNI%TYPE := 'TST90001A';
  c_dni_c2 PERSONA.DNI%TYPE := 'TST90002B';
  c_dni_fun PERSONA.DNI%TYPE := 'TST90003F';

  v_categoria FUNCIONARIO.CATEGORIA%TYPE;
  v_estado    SOLICITA.ESTADO%TYPE;
BEGIN
  DBMS_OUTPUT.PUT_LINE('====================================================');
  DBMS_OUTPUT.PUT_LINE('PRUEBAS TRIGGERS (P4)');
  DBMS_OUTPUT.PUT_LINE('====================================================');

  -------------------------------------------------------------------------
  -- SETUP datos mínimos de prueba (para disparar triggers sin tocar datos base)
  -------------------------------------------------------------------------
  DBMS_OUTPUT.PUT_LINE('--- SETUP datos de prueba ---');

  INSERT INTO CURSO (ID_CURSO, NOMBRE, DURACION, PLAZAS, ID_ORGANIZADOR)
  VALUES (c_id_curso, 'Curso Test Trigger', 10, 1, NULL);

  INSERT INTO OFICINA (ID_OFICINA, LOCALIDAD, TELEFONO, ID_ORGANIZADOR)
  VALUES (c_id_oficina, 'Oficina Test', '000000000', NULL);

  INSERT INTO OFERTA (ID_OFERTA, PUESTO, REQUISITOS, ID_EMPRESA)
  VALUES (c_id_oferta, 'Puesto Test', 'Req Test', NULL);

  INSERT INTO PERSONA (DNI, NOMBRE, APELLIDOS, FECHA_NAC)
  VALUES (c_dni_c1, 'Test', 'Ciudadano A', DATE '1990-01-01');

  INSERT INTO PERSONA (DNI, NOMBRE, APELLIDOS, FECHA_NAC)
  VALUES (c_dni_c2, 'Test', 'Ciudadano B', DATE '1991-01-01');

  INSERT INTO PERSONA (DNI, NOMBRE, APELLIDOS, FECHA_NAC)
  VALUES (c_dni_fun, 'Test', 'Funcionario', DATE '1980-01-01');

  -- CIUDADANO 1 entra en el curso (plazas=1) => OK (dispara TRG_CURSO_PLAZAS en INSERT)
  INSERT INTO CIUDADANO (DNI_CIUDADANO, EXP_LABORAL, DISPONIBILIDAD, NIVEL_FORMACION, ID_CURSO)
  VALUES (c_dni_c1, 'N/A', 'TOTAL', 'N/A', c_id_curso);

  -- CIUDADANO 2 sin curso => OK y además NO entra en la condición del trigger (ID_CURSO NULL)
  INSERT INTO CIUDADANO (DNI_CIUDADANO, EXP_LABORAL, DISPONIBILIDAD, NIVEL_FORMACION, ID_CURSO)
  VALUES (c_dni_c2, 'N/A', 'TOTAL', 'N/A', NULL);

  DBMS_OUTPUT.PUT_LINE('SETUP OK');
  DBMS_OUTPUT.NEW_LINE;

  -------------------------------------------------------------------------
  -- 1) TRG_CURSO_PLAZAS (INSERT/UPDATE en CIUDADANO)
  -------------------------------------------------------------------------
  DBMS_OUTPUT.PUT_LINE('--- TRG_CURSO_PLAZAS ---');
  DBMS_OUTPUT.PUT_LINE('Caso ERROR esperado: asignar ciudadano 2 al curso ya lleno (UPDATE).');

  BEGIN
    UPDATE CIUDADANO
       SET ID_CURSO = c_id_curso
     WHERE DNI_CIUDADANO = c_dni_c2;

    DBMS_OUTPUT.PUT_LINE('!! ERROR: se esperaba -20005 y no ocurrió');
  EXCEPTION
    WHEN OTHERS THEN
      DBMS_OUTPUT.PUT_LINE('OK (saltó como se esperaba): ' || SQLCODE || ' - ' || SQLERRM);
  END;

  DBMS_OUTPUT.NEW_LINE;

  -------------------------------------------------------------------------
  -- 2) TRG_FUNCIONARIO_CATEGORIA (INSERT/UPDATE en FUNCIONARIO)
  -------------------------------------------------------------------------
  DBMS_OUTPUT.PUT_LINE('--- TRG_FUNCIONARIO_CATEGORIA ---');

  DBMS_OUTPUT.PUT_LINE('Caso OK: INSERT con PUESTO=INSPECTOR => CATEGORIA=SUPERIOR.');
  INSERT INTO FUNCIONARIO (DNI_FUNCIONARIO, PUESTO, CATEGORIA, FECHA_ALTA, ID_OFICINA, DNI_SUPERVISOR)
  VALUES (c_dni_fun, 'INSPECTOR', NULL, SYSDATE, c_id_oficina, NULL);

  SELECT CATEGORIA INTO v_categoria
    FROM FUNCIONARIO
   WHERE DNI_FUNCIONARIO = c_dni_fun;

  DBMS_OUTPUT.PUT_LINE('CATEGORIA tras INSERT: ' || v_categoria);

  DBMS_OUTPUT.PUT_LINE('Caso OK: UPDATE PUESTO=ADMINISTRATIVO => CATEGORIA=AUXILIAR.');
  UPDATE FUNCIONARIO
     SET PUESTO = 'ADMINISTRATIVO'
   WHERE DNI_FUNCIONARIO = c_dni_fun;

  SELECT CATEGORIA INTO v_categoria
    FROM FUNCIONARIO
   WHERE DNI_FUNCIONARIO = c_dni_fun;

  DBMS_OUTPUT.PUT_LINE('CATEGORIA tras UPDATE: ' || v_categoria);

  DBMS_OUTPUT.NEW_LINE;

  -------------------------------------------------------------------------
  -- 3) TRG_SOLICITA_UNICA_ACTIVA (INSERT/UPDATE en SOLICITA)
  --    Nota: con vuestro trigger, el caso típico que falla es actualizar a estado activo
  --    cuando ya existe una fila activa (se cuenta a sí misma).
  -------------------------------------------------------------------------
  DBMS_OUTPUT.PUT_LINE('--- TRG_SOLICITA_UNICA_ACTIVA ---');

  DBMS_OUTPUT.PUT_LINE('Caso OK (no entra condición): INSERT con ESTADO=RECHAZADA.');
  INSERT INTO SOLICITA (DNI_CIUDADANO, ID_OFERTA, ESTADO, FECHA_SOLICITUD)
  VALUES (c_dni_c1, c_id_oferta, 'RECHAZADA', DATE '2025-01-10');

  DBMS_OUTPUT.PUT_LINE('Caso OK: UPDATE RECHAZADA -> PENDIENTE (debe dejarlo).');
  UPDATE SOLICITA
     SET ESTADO = 'PENDIENTE'
   WHERE DNI_CIUDADANO = c_dni_c1
     AND ID_OFERTA = c_id_oferta;

  SELECT ESTADO INTO v_estado
    FROM SOLICITA
   WHERE DNI_CIUDADANO = c_dni_c1
     AND ID_OFERTA = c_id_oferta;

  DBMS_OUTPUT.PUT_LINE('ESTADO actual: ' || v_estado);

  DBMS_OUTPUT.PUT_LINE('Caso ERROR esperado: UPDATE PENDIENTE -> ACEPTADA (salta -20002).');
  BEGIN
    UPDATE SOLICITA
       SET ESTADO = 'ACEPTADA'
     WHERE DNI_CIUDADANO = c_dni_c1
       AND ID_OFERTA = c_id_oferta;

    DBMS_OUTPUT.PUT_LINE('!! ERROR: se esperaba -20002 y no ocurrió');
  EXCEPTION
    WHEN OTHERS THEN
      DBMS_OUTPUT.PUT_LINE('OK (saltó como se esperaba): ' || SQLCODE || ' - ' || SQLERRM);
  END;

  DBMS_OUTPUT.NEW_LINE;

  -------------------------------------------------------------------------
  -- 4) TRG_CONTRATO_FECHAS (INSERT/UPDATE en CONTRATO)
  -------------------------------------------------------------------------
  DBMS_OUTPUT.PUT_LINE('--- TRG_CONTRATO_FECHAS ---');

  DBMS_OUTPUT.PUT_LINE('Caso ERROR esperado: FECHA_INICIO >= FECHA_FIN (INSERT).');
  BEGIN
    INSERT INTO CONTRATO (ID_CONTRATO, TIPO, FECHA_INICIO, FECHA_FIN, ID_EMPRESA, DNI_CIUDADANO)
    VALUES (c_id_contrato_bad, 'TEMP', DATE '2025-02-01', DATE '2025-02-01', NULL, c_dni_c1);

    DBMS_OUTPUT.PUT_LINE('!! ERROR: se esperaba -20001 y no ocurrió');
  EXCEPTION
    WHEN OTHERS THEN
      DBMS_OUTPUT.PUT_LINE('OK (saltó como se esperaba): ' || SQLCODE || ' - ' || SQLERRM);
  END;

  DBMS_OUTPUT.PUT_LINE('Caso OK: FECHA_INICIO < FECHA_FIN (INSERT).');
  INSERT INTO CONTRATO (ID_CONTRATO, TIPO, FECHA_INICIO, FECHA_FIN, ID_EMPRESA, DNI_CIUDADANO)
  VALUES (c_id_contrato_ok, 'TEMP', DATE '2025-02-01', DATE '2025-06-01', NULL, c_dni_c1);

  DBMS_OUTPUT.NEW_LINE;

  -------------------------------------------------------------------------
  -- 5) TRG_PAGO_NUM (INSERT en PAGO)
  -------------------------------------------------------------------------
  DBMS_OUTPUT.PUT_LINE('--- TRG_PAGO_NUM ---');

  DBMS_OUTPUT.PUT_LINE('Setup préstamo para pruebas de pago.');
  INSERT INTO PRESTAMO (ID_PRESTAMO, FORMA_OTORGAMIENTO, FECHA_RESOLUCION, DNI_CIUDADANO)
  VALUES (c_id_prestamo, 'TEST', SYSDATE, c_dni_c2);

  DBMS_OUTPUT.PUT_LINE('Caso OK: INSERT pago con NUM_PAGO NULL => auto numera.');
  INSERT INTO PAGO (ID_PRESTAMO, NUM_PAGO, IMPORTE) VALUES (c_id_prestamo, NULL, 100);

  DBMS_OUTPUT.PUT_LINE('Caso OK: otro pago con NUM_PAGO NULL => siguiente.');
  INSERT INTO PAGO (ID_PRESTAMO, NUM_PAGO, IMPORTE) VALUES (c_id_prestamo, NULL, 200);

  DBMS_OUTPUT.PUT_LINE('Caso "no entra condición": INSERT con NUM_PAGO explícito (99) => se respeta.');
  INSERT INTO PAGO (ID_PRESTAMO, NUM_PAGO, IMPORTE) VALUES (c_id_prestamo, 99, 999);

  DBMS_OUTPUT.PUT_LINE('Pagos generados (NUM_PAGO / IMPORTE):');
  FOR r IN (SELECT NUM_PAGO, IMPORTE FROM PAGO WHERE ID_PRESTAMO = c_id_prestamo ORDER BY NUM_PAGO) LOOP
    DBMS_OUTPUT.PUT_LINE('  - ' || r.NUM_PAGO || ' / ' || r.IMPORTE);
  END LOOP;

  DBMS_OUTPUT.NEW_LINE;

  -------------------------------------------------------------------------
  -- 6) TRG_CURSO_NO_BORRAR_CON_MATRICULADOS (DELETE en CURSO)
  -------------------------------------------------------------------------
  DBMS_OUTPUT.PUT_LINE('--- TRG_CURSO_NO_BORRAR_CON_MATRICULADOS ---');

  DBMS_OUTPUT.PUT_LINE('Caso ERROR esperado: borrar curso con ciudadano matriculado.');
  BEGIN
    DELETE FROM CURSO WHERE ID_CURSO = c_id_curso;
    DBMS_OUTPUT.PUT_LINE('!! ERROR: se esperaba -20006 y no ocurrió');
  EXCEPTION
    WHEN OTHERS THEN
      DBMS_OUTPUT.PUT_LINE('OK (saltó como se esperaba): ' || SQLCODE || ' - ' || SQLERRM);
  END;

  DBMS_OUTPUT.PUT_LINE('Caso OK: desmatricular y borrar curso.');
  UPDATE CIUDADANO SET ID_CURSO = NULL WHERE DNI_CIUDADANO = c_dni_c1;
  DELETE FROM CURSO WHERE ID_CURSO = c_id_curso;
  DBMS_OUTPUT.PUT_LINE('Curso borrado correctamente tras desmatricular.');

  DBMS_OUTPUT.NEW_LINE;
  DBMS_OUTPUT.PUT_LINE('=== FIN PRUEBAS TRIGGERS (P4) ===');

END;
/



