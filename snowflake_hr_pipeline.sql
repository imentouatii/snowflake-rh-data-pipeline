-- ============================================================
-- 1- DATABASE AND TABLES CREATION
-- ============================================================

CREATE DATABASE IF NOT EXISTS DMT_RH;
CREATE SCHEMA IF NOT EXISTS DMT_RH.PUBLIC;

-- Table: departement
CREATE OR REPLACE TABLE DMT_RH.PUBLIC.departement (
    id_departement INT AUTOINCREMENT START 1 INCREMENT 1,
    nom VARCHAR(255),
    localisation VARCHAR(255),
    id_responsable INT,
    date_create TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    date_modif TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    PRIMARY KEY (id_departement)
);

-- Table: poste
CREATE OR REPLACE TABLE DMT_RH.PUBLIC.poste (
    id_poste INT AUTOINCREMENT START 1 INCREMENT 1,
    intitule VARCHAR(255),
    niveau VARCHAR(50),
    id_salaire_base INT,
    date_create TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    date_modif TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    PRIMARY KEY (id_poste)
);

-- Table: employe
CREATE OR REPLACE TABLE DMT_RH.PUBLIC.employe (
    id_employe INT AUTOINCREMENT START 1 INCREMENT 1,
    nom VARCHAR(255),
    prenom VARCHAR(255),
    date_naissance VARCHAR(8),
    numero_secu VARCHAR(50),
    email VARCHAR(255),
    telephone VARCHAR(50),
    email_entreprise VARCHAR(255),
    id_departement INT,
    id_poste INT,
    date_create TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    date_modif TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    PRIMARY KEY (id_employe),
    FOREIGN KEY (id_departement) REFERENCES DMT_RH.PUBLIC.departement(id_departement),
    FOREIGN KEY (id_poste) REFERENCES DMT_RH.PUBLIC.poste(id_poste)
);

-- Table: contrat
CREATE OR REPLACE TABLE DMT_RH.PUBLIC.contrat (
    id_contrat INT AUTOINCREMENT START 1 INCREMENT 1,
    id_employe INT,
    type_contrat VARCHAR(50),
    date_debut DATE,
    date_fin DATE,
    salaire NUMBER(10, 2),
    statut VARCHAR(50),
    date_create TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    date_modif TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    PRIMARY KEY (id_contrat),
    FOREIGN KEY (id_employe) REFERENCES DMT_RH.PUBLIC.employe(id_employe)
);


-- ============================================================
-- 2- FILE FORMAT AND STAGE CREATION
-- ============================================================

CREATE OR REPLACE FILE FORMAT DMT_RH.PUBLIC.json_format
    TYPE = 'JSON'
    STRIP_OUTER_ARRAY = TRUE;

CREATE OR REPLACE STAGE DMT_RH.PUBLIC.Stage_RH
    FILE_FORMAT = DMT_RH.PUBLIC.json_format;


-- ============================================================
-- 3- INGESTION PIPES CREATION
-- ============================================================

-- Pipe 1: departement
CREATE OR REPLACE PIPE DMT_RH.PUBLIC.pipe_departement AS
COPY INTO DMT_RH.PUBLIC.departement (nom, localisation, id_responsable, date_create, date_modif)
FROM (
    SELECT 
        $1:nom::STRING,
        $1:localisation::STRING,
        $1:id_responsable::INT,
        CURRENT_TIMESTAMP(),
        CURRENT_TIMESTAMP()
    FROM @DMT_RH.PUBLIC.Stage_RH/organisation_rh.json
);

-- Pipe 2: poste
CREATE OR REPLACE PIPE DMT_RH.PUBLIC.pipe_poste AS
COPY INTO DMT_RH.PUBLIC.poste (intitule, niveau, id_salaire_base, date_create, date_modif)
FROM (
    SELECT 
        $1:intitule::STRING,
        $1:niveau::STRING,
        $1:id_salaire_base::INT,
        CURRENT_TIMESTAMP(),
        CURRENT_TIMESTAMP()
    FROM @DMT_RH.PUBLIC.Stage_RH/organisation_rh.json
);

-- Pipe 3: employe
CREATE OR REPLACE PIPE DMT_RH.PUBLIC.pipe_employe AS
COPY INTO DMT_RH.PUBLIC.employe (nom, prenom, date_naissance, numero_secu, email, telephone, email_entreprise, id_departement, id_poste, date_create, date_modif)
FROM (
    SELECT 
        $1:nom::STRING,
        $1:prenom::STRING,
        $1:date_naissance::STRING,
        $1:numero_secu::STRING,
        $1:email::STRING,
        $1:telephone::STRING,
        UPPER(SUBSTR($1:nom::STRING, 1, 1)) || LOWER($1:prenom::STRING) || '@RH.fr',
        $1:id_departement::INT,
        $1:id_poste::INT,
        CURRENT_TIMESTAMP(),
        CURRENT_TIMESTAMP()
    FROM @DMT_RH.PUBLIC.Stage_RH/organisation_rh.json
);

-- Pipe 4: contrat
CREATE OR REPLACE PIPE DMT_RH.PUBLIC.pipe_contrat AS
COPY INTO DMT_RH.PUBLIC.contrat (id_employe, type_contrat, date_debut, date_fin, salaire, statut, date_create, date_modif)
FROM (
    SELECT 
        $1:id_employe::INT,
        $1:type_contrat::STRING,
        TO_DATE($1:date_debut::STRING, 'YYYY-MM-DD'),
        TO_DATE($1:date_fin::STRING, 'YYYY-MM-DD'),
        $1:salaire::NUMBER(10,2),
        CASE 
            WHEN TO_DATE($1:date_fin::STRING, 'YYYY-MM-DD') IS NULL OR TO_DATE($1:date_fin::STRING, 'YYYY-MM-DD') >= CURRENT_DATE() 
            THEN 'Active' 
            ELSE NULL 
        END,
        CURRENT_TIMESTAMP(),
        CURRENT_TIMESTAMP()
    FROM @DMT_RH.PUBLIC.Stage_RH/organisation_rh.json
);


-- ============================================================
-- 4- TASK CREATION AND ORCHESTRATION
-- ============================================================

-- Root Task: departement
CREATE OR REPLACE TASK DMT_RH.PUBLIC.task_load_departement
    WAREHOUSE = COMPUTE_WH
    SCHEDULE = '60 MINUTE'
AS
    ALTER PIPE DMT_RH.PUBLIC.pipe_departement REFRESH;

-- Task: poste
CREATE OR REPLACE TASK DMT_RH.PUBLIC.task_load_poste
    WAREHOUSE = COMPUTE_WH
    AFTER DMT_RH.PUBLIC.task_load_departement
AS
    ALTER PIPE DMT_RH.PUBLIC.pipe_poste REFRESH;

-- Task: employe
CREATE OR REPLACE TASK DMT_RH.PUBLIC.task_load_employe
    WAREHOUSE = COMPUTE_WH
    AFTER DMT_RH.PUBLIC.task_load_poste
AS
    ALTER PIPE DMT_RH.PUBLIC.pipe_employe REFRESH;

-- Task: contrat
CREATE OR REPLACE TASK DMT_RH.PUBLIC.task_load_contrat
    WAREHOUSE = COMPUTE_WH
    AFTER DMT_RH.PUBLIC.task_load_employe
AS
    ALTER PIPE DMT_RH.PUBLIC.pipe_contrat REFRESH;

-- Resume Tasks
ALTER TASK DMT_RH.PUBLIC.task_load_contrat RESUME;
ALTER TASK DMT_RH.PUBLIC.task_load_employe RESUME;
ALTER TASK DMT_RH.PUBLIC.task_load_poste RESUME;
ALTER TASK DMT_RH.PUBLIC.task_load_departement RESUME;