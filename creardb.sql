-- ============================================
--  Script Supabase (PostgreSQL) - Sitio Peliculas
--  Ejecutar en: Supabase Dashboard > SQL Editor > New query
-- ============================================
-- ------------------------
-- Tabla genero
-- ------------------------
CREATE TABLE IF NOT EXISTS genero (
  id SERIAL PRIMARY KEY,
  nombre VARCHAR(255) NOT NULL
);

-- ------------------------
-- Tabla popularidad
-- ------------------------
CREATE TABLE IF NOT EXISTS popularidad (
  id SERIAL PRIMARY KEY,
  nombre VARCHAR(255) NOT NULL
);

-- ------------------------
-- Tabla catalogo
-- ------------------------
CREATE TABLE IF NOT EXISTS catalogo (
  id SERIAL PRIMARY KEY,
  nombre VARCHAR(255) NOT NULL,
  id_genero INTEGER NOT NULL REFERENCES genero(id) ON DELETE CASCADE ON UPDATE CASCADE,
  id_popularidad INTEGER NOT NULL REFERENCES popularidad(id) ON DELETE CASCADE ON UPDATE CASCADE,
  puntuacion INTEGER NOT NULL DEFAULT 0
);

-- Indice para FK (como FK_catalogo_1 en MySQL)
CREATE INDEX IF NOT EXISTS idx_catalogo_id_genero ON catalogo(id_genero);
CREATE INDEX IF NOT EXISTS idx_catalogo_id_popularidad ON catalogo(id_popularidad);

-- ------------------------
-- Tabla usuarios (antes `user` en BD `users`)
-- ------------------------
CREATE TABLE IF NOT EXISTS app_user (
  id SERIAL PRIMARY KEY,
  username VARCHAR(50) NOT NULL UNIQUE,
  clave VARCHAR(255) NOT NULL
);

-- ------------------------
-- Tabla images (antes pruva.php / dbimgs.php)
-- En MySQL era LONGBLOB, en Postgres es BYTEA
-- ------------------------
CREATE TABLE IF NOT EXISTS images (
  id SERIAL PRIMARY KEY,
  image BYTEA NOT NULL,
  image_name VARCHAR(255) NOT NULL
);

-- ============================================
-- Datos iniciales (copiados de pelicula.sql)
-- ============================================

INSERT INTO genero (id, nombre) VALUES
(1, 'Horror'),
(2, 'Comedias'),
(4, 'Accion'),
(5, 'Drama'),
(9, 'Animacion'),
(10, 'gatuno'),
(25, '25'),
(27, '27'),
(29, '29'),
(34, '34001'),
(35, '35'),
(37, '37'),
(39, '3900'),
(40, '40')
ON CONFLICT (id) DO UPDATE SET nombre = EXCLUDED.nombre;

INSERT INTO popularidad (id, nombre) VALUES
(1, 'Buena'),
(2, 'Mala')
ON CONFLICT (id) DO UPDATE SET nombre = EXCLUDED.nombre;

INSERT INTO catalogo (id, nombre, id_genero, id_popularidad, puntuacion) VALUES
(1, 'Brave', 9, 1, 56),
(2, 'Beetlejuice', 2, 1, 89),
(3, 'John Wick', 5, 1, 34),
(4, 'cineterror', 1, 1, 76),
(5, 'Avengers', 4, 2, 4),
(6, 'Matrix', 4, 1, 5)
ON CONFLICT (id) DO UPDATE SET
  nombre = EXCLUDED.nombre,
  id_genero = EXCLUDED.id_genero,
  id_popularidad = EXCLUDED.id_popularidad,
  puntuacion = EXCLUDED.puntuacion;

-- Usuario de prueba (copiado de users.sql: user1 / 123)
INSERT INTO app_user (id, username, clave) VALUES
(1, 'user1', '123')
ON CONFLICT (id) DO NOTHING;

-- ============================================
-- Ajustar secuencias (equivale a AUTO_INCREMENT=...)
-- ============================================
SELECT setval('genero_id_seq', (SELECT MAX(id) FROM genero));
SELECT setval('popularidad_id_seq', (SELECT MAX(id) FROM popularidad));
SELECT setval('catalogo_id_seq', (SELECT MAX(id) FROM catalogo));
SELECT setval('app_user_id_seq', (SELECT MAX(id) FROM app_user));
-- images se ajusta sola al insertar, pero por si acaso:
SELECT setval('images_id_seq', (SELECT MAX(id) FROM images), true);

-- ============================================
-- Row Level Security (para que funcione con
-- anon key / REST API de Supabase)
-- Si solo usas conexion directa PDO (postgres),
-- RLS no te bloquea, pero estas policies permiten
-- usar tambien el cliente JS / REST sin errores 401.
-- ============================================
ALTER TABLE genero ENABLE ROW LEVEL SECURITY;
ALTER TABLE popularidad ENABLE ROW LEVEL SECURITY;
ALTER TABLE catalogo ENABLE ROW LEVEL SECURITY;
ALTER TABLE app_user ENABLE ROW LEVEL SECURITY;
ALTER TABLE images ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "allow all" ON genero;
DROP POLICY IF EXISTS "allow all" ON popularidad;
DROP POLICY IF EXISTS "allow all" ON catalogo;
DROP POLICY IF EXISTS "allow all" ON app_user;
DROP POLICY IF EXISTS "allow all" ON images;

CREATE POLICY "allow all" ON genero FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "allow all" ON popularidad FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "allow all" ON catalogo FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "allow all" ON app_user FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "allow all" ON images FOR ALL USING (true) WITH CHECK (true);
