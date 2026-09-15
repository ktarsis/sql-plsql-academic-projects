# Oracle SQL/PLSQL - Proyecto académico de base de datos

Proyecto académico desarrollado para **Bases de Datos II** sobre un escenario inspirado en la gestión de empleo y formación.

## Contenido

El script incluye:

- Modelo relacional con tablas y restricciones de integridad.
- Relaciones de especialización y claves foráneas.
- Particionado por rango en tablas con información temporal.
- Índices para apoyar consultas y relaciones frecuentes.
- Vistas de consulta.
- Procedimientos y funciones PL/SQL.
- Triggers para implementar restricciones semánticas y reglas de negocio.
- Dataset de prueba y consultas de comprobación.

## Elementos PL/SQL destacados

Entre las reglas implementadas se incluyen:

- Control de plazas disponibles en cursos.
- Validación de categorías de funcionarios.
- Restricciones sobre solicitudes activas.
- Comprobación de fechas de contratos.
- Numeración y validación de pagos.
- Restricción del borrado de cursos con ciudadanos matriculados.
- Procedimientos para alta/baja de solicitudes y matrículas.
- Gestión de préstamos y resolución de ofertas.
- Funciones de cálculo sobre pagos.

## Tecnologías

- Oracle SQL
- PL/SQL
- Triggers
- Procedures / Functions
- Views
- Indexes
- Partitioning

## Ejecución

El archivo principal es:

```text
sepe_database_oracle.sql
```

Está pensado para ejecutarse en un entorno Oracle compatible con PL/SQL y con `SERVEROUTPUT` habilitado.

## Nota sobre los datos

Esta versión ha sido preparada para publicación pública en GitHub.  
Los identificadores, nombres y correos incluidos en los datos de ejemplo son **ficticios** y se utilizan únicamente para demostrar el funcionamiento del esquema.

## Contexto

Proyecto realizado con fines académicos dentro del Grado en Ingeniería Informática.
