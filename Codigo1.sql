-- =====================================================================
-- ERROR DE NORMALIZACIÓN (EXPLICACIÓN)
-- =====================================================================
-- En el diseño original de la tabla CITA se incluía el atributo:
--     MedicamentosRecetados VARCHAR(500)
--
-- Problema:
-- - En ese campo se pretendía guardar varios medicamentos para una misma
--   cita (por ejemplo, una lista separada por comas).
-- - Esto viola la Primera Forma Normal (1NF), que exige que todos los
--   atributos sean atómicos (un solo valor por celda).
-- - Además dificulta:
--     * Buscar un medicamento específico.
--     * Actualizar o eliminar un solo medicamento de la lista.
--     * Contar o analizar medicamentos por paciente, doctor, etc.
--
-- Corrección:
-- - Eliminar el atributo MedicamentosRecetados de la tabla CITA.
-- - Crear una nueva tabla RECETA (o detalle de medicamentos), donde
--   cada fila represente UN medicamento asociado a UNA cita.
-- - De esta forma:
--     * CITA mantiene información general de la cita.
--     * RECETA guarda el detalle de medicamentos recetados,
--       cumpliendo con 1NF y facilitando consultas y mantenimientos.
-- =====================================================================


-- =====================================================================
-- CREACIÓN DE TABLAS
-- =====================================================================

-- TABLA PACIENTE
CREATE TABLE paciente (
    paciente_id      SERIAL PRIMARY KEY,
    nombre           VARCHAR(100) NOT NULL,
    fecha_nacimiento DATE NOT NULL,
    telefono         VARCHAR(15),
    email            VARCHAR(100),
    direccion        VARCHAR(200)
);

-- TABLA DOCTOR
CREATE TABLE doctor (
    doctor_id        SERIAL PRIMARY KEY,
    nombre           VARCHAR(100) NOT NULL,
    especialidad     VARCHAR(50)  NOT NULL,
    telefono         VARCHAR(15),
    email            VARCHAR(100),
    horario_consulta VARCHAR(100)
);

-- TABLA CITA (ya SIN medicamentos_recetados)
CREATE TABLE cita (
    cita_id     SERIAL PRIMARY KEY,
    paciente_id INTEGER NOT NULL REFERENCES paciente(paciente_id),
    doctor_id   INTEGER NOT NULL REFERENCES doctor(doctor_id),
    fecha_cita  DATE NOT NULL,
    hora_cita   TIME NOT NULL,
    motivo      VARCHAR(200),
    estado      VARCHAR(20)
);

-- TABLA HISTORIAL MÉDICO
CREATE TABLE historial_medico (
    historial_id SERIAL PRIMARY KEY,
    paciente_id  INTEGER NOT NULL REFERENCES paciente(paciente_id),
    doctor_id    INTEGER NOT NULL REFERENCES doctor(doctor_id),
    fecha_visita DATE NOT NULL,
    diagnostico  TEXT,
    tratamiento  TEXT
);

-- TABLA RECETA (DETALLE DE MEDICAMENTOS NORMALIZADO)
CREATE TABLE receta (
    receta_id   SERIAL PRIMARY KEY,
    cita_id     INTEGER NOT NULL REFERENCES cita(cita_id),
    medicamento VARCHAR(100) NOT NULL,
    dosis       VARCHAR(100),
    frecuencia  VARCHAR(100)
);


-- =====================================================================
-- INSERTS DE EJEMPLO (MÍNIMO 3 POR TABLA)
-- =====================================================================

-- PACIENTE
INSERT INTO paciente (nombre, fecha_nacimiento, telefono, email, direccion) VALUES
('Juan Pérez',    '1990-03-15', '3001112233', 'juan.perez@example.com',    'Calle 10 #12-34'),
('María Gómez',   '1985-07-20', '3002223344', 'maria.gomez@example.com',   'Carrera 45 #67-89'),
('Carlos López',  '2000-11-05', '3003334455', 'carlos.lopez@example.com',  'Transversal 30 #15-20');

-- DOCTOR
INSERT INTO doctor (nombre, especialidad, telefono, email, horario_consulta) VALUES
('Andrés Ruiz',  'Cardiología',        '6041111111', 'aruiz@clinica.com',  'Lunes a Viernes 8-12'),
('Laura Ríos',   'Pediatría',          '6042222222', 'lrios@clinica.com',  'Lunes a Viernes 14-18'),
('Pedro Mejía',  'Medicina General',   '6043333333', 'pmejia@clinica.com', 'Sábados 8-12');

-- CITA
INSERT INTO cita (paciente_id, doctor_id, fecha_cita, hora_cita, motivo, estado) VALUES
(1, 1, '2025-11-06', '09:00:00', 'Control de presión',     'programada'),
(2, 2, '2025-11-08', '15:30:00', 'Control de crecimiento', 'programada'),
(3, 3, '2025-11-03', '10:15:00', 'Dolor de cabeza',        'realizada');

-- HISTORIAL MÉDICO
INSERT INTO historial_medico (paciente_id, doctor_id, fecha_visita, diagnostico, tratamiento) VALUES
(1, 1, '2025-10-01', 'Hipertensión controlada',         'Ajuste de dosis de medicamento'),
(2, 2, '2025-09-15', 'Infección respiratoria leve',     'Antibiótico por 7 días'),
(3, 3, '2025-11-03', 'Cefalea tensional',               'Analgésicos y reposo');

-- RECETA (MEDICAMENTOS ASOCIADOS A LAS CITAS)
INSERT INTO receta (cita_id, medicamento, dosis, frecuencia) VALUES
(1, 'Losartán 50mg',      '1 tableta',     'Cada 12 horas'),
(2, 'Amoxicilina 250mg',  '1 cucharadita', 'Cada 8 horas'),
(3, 'Acetaminofén 500mg', '1 tableta',     'Cada 6 horas');


-- =====================================================================
-- VISTA: vista_citas_proximas
-- =====================================================================

CREATE OR REPLACE VIEW vista_citas_proximas AS
SELECT
    c.cita_id,
    c.fecha_cita,
    c.hora_cita,
    c.motivo,
    p.nombre    AS nombre_paciente,
    p.telefono  AS telefono_paciente,
    d.nombre    AS nombre_doctor,
    d.especialidad,
    (c.fecha_cita - CURRENT_DATE) AS dias_faltantes
FROM cita c
JOIN paciente p ON c.paciente_id = p.paciente_id
JOIN doctor   d ON c.doctor_id   = d.doctor_id
WHERE c.fecha_cita BETWEEN CURRENT_DATE 
                      AND CURRENT_DATE + INTERVAL '7 days';
-- Si se quisiera solo citas aún no realizadas:
--   AND c.estado = 'programada';


-- =====================================================================
-- FUNCIÓN: calcular_edad_paciente
-- =====================================================================

CREATE OR REPLACE FUNCTION calcular_edad_paciente(p_paciente_id INTEGER)
RETURNS INTEGER AS
$$
DECLARE
    v_fecha_nac DATE;
    v_edad      INTEGER;
BEGIN
    -- Obtener la fecha de nacimiento del paciente
    SELECT fecha_nacimiento
    INTO v_fecha_nac
    FROM paciente
    WHERE paciente_id = p_paciente_id;

    -- Si no se encuentra el paciente, devolver NULL
    IF NOT FOUND THEN
        RETURN NULL;
    END IF;

    -- Calcular la edad en años usando age()
    v_edad := DATE_PART('year', age(CURRENT_DATE, v_fecha_nac));

    RETURN v_edad;
END;
$$ LANGUAGE plpgsql;

-- Ejemplo de uso:
-- SELECT calcular_edad_paciente(1) AS edad_paciente_1;
