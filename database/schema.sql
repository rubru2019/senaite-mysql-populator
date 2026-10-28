-- 1. LAB CONFIGURATIEDOMEIN (STAMDATA) --

-- 1. Laboratorium Afdelingen
CREATE TABLE lab_departments (
    uid VARCHAR(36) PRIMARY KEY,
    title VARCHAR(100) NOT NULL,
    description TEXT,
    review_state VARCHAR(32) DEFAULT 'active',
    creator VARCHAR(50) NOT NULL,
    created_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- 2. Meetinstrumenten
CREATE TABLE instruments (
    uid VARCHAR(36) PRIMARY KEY,
    title VARCHAR(100) NOT NULL,
    model VARCHAR(100),
    serial_number VARCHAR(50),
    manufacturer VARCHAR(100),
    calibration_expiry DATE,
    review_state VARCHAR(32) DEFAULT 'active',
    creator VARCHAR(50) NOT NULL,
    created_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- 3. Rekenformules / Calculaties
CREATE TABLE calculations (
    uid VARCHAR(36) PRIMARY KEY,
    title VARCHAR(100) NOT NULL,
    formula TEXT NOT NULL, -- Slaat de wiskundige formule op
    description TEXT,
    creator VARCHAR(50) NOT NULL,
    created_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- 4. Analysemethoden
CREATE TABLE methods (
    uid VARCHAR(36) PRIMARY KEY,
    title VARCHAR(100) NOT NULL,
    instructions TEXT,
    instrument_uid VARCHAR(36),
    review_state VARCHAR(32) DEFAULT 'active',
    creator VARCHAR(50) NOT NULL,
    created_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (instrument_uid) REFERENCES instruments(uid)
);

-- 5. Analysediensten (De testdefinities)
CREATE TABLE analysis_services (
    uid VARCHAR(36) PRIMARY KEY,
    title VARCHAR(100) NOT NULL,
    keyword VARCHAR(20) NOT NULL UNIQUE, -- Korte code bijv. 'pH', 'TH'
    unit VARCHAR(20),
    department_uid VARCHAR(36),
    method_uid VARCHAR(36),
    calculation_uid VARCHAR(36),
    price DECIMAL(10, 2) DEFAULT 0.00,
    review_state VARCHAR(32) DEFAULT 'active',
    creator VARCHAR(50) NOT NULL,
    created_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (department_uid) REFERENCES lab_departments(uid),
    FOREIGN KEY (method_uid) REFERENCES methods(uid),
    FOREIGN KEY (calculation_uid) REFERENCES calculations(uid)
);

-- 6. Monstertypes (Matrices)
CREATE TABLE sample_types (
    uid VARCHAR(36) PRIMARY KEY,
    title VARCHAR(100) NOT NULL,
    description TEXT,
    review_state VARCHAR(32) DEFAULT 'active',
    creator VARCHAR(50) NOT NULL,
    created_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- 2. RELATIE- & KLANTDOMEIN (CRM)
-- 7. Klanten
CREATE TABLE clients (
    uid VARCHAR(36) PRIMARY KEY,
    client_id VARCHAR(20) NOT NULL UNIQUE, -- Accountnummer of code
    name VARCHAR(150) NOT NULL,
    email VARCHAR(100),
    phone VARCHAR(30),
    address TEXT,
    review_state VARCHAR(32) DEFAULT 'active',
    creator VARCHAR(50) NOT NULL,
    created_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- 8. Contactpersonen per klant
CREATE TABLE contacts (
    uid VARCHAR(36) PRIMARY KEY,
    client_uid VARCHAR(36) NOT NULL,
    first_name VARCHAR(50) NOT NULL,
    last_name VARCHAR(50) NOT NULL,
    email VARCHAR(100),
    phone VARCHAR(30),
    review_state VARCHAR(32) DEFAULT 'active',
    creator VARCHAR(50) NOT NULL,
    created_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (client_uid) REFERENCES clients(uid) ON DELETE CASCADE
);

-- 3. OPERATIONELE WORKFLOW & RESULTATEN
-- 9. Monsters
CREATE TABLE samples (
    uid VARCHAR(36) PRIMARY KEY,
    sample_id VARCHAR(30) NOT NULL UNIQUE, -- Het unieke barcode/labnummer
    sample_type_uid VARCHAR(36) NOT NULL,
    date_sampled TIMESTAMP,
    date_received TIMESTAMP,
    review_state VARCHAR(32) DEFAULT 'sample_due', -- o.a. sample_due, received, verified, published
    creator VARCHAR(50) NOT NULL,
    created_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (sample_type_uid) REFERENCES sample_types(uid)
);

-- 10. Testaanvragen (De administratieve koppeling)
CREATE TABLE analysis_requests (
    uid VARCHAR(36) PRIMARY KEY,
    request_id VARCHAR(30) NOT NULL UNIQUE,
    client_uid VARCHAR(36) NOT NULL,
    contact_uid VARCHAR(36),
    sample_uid VARCHAR(36) NOT NULL UNIQUE, -- Strikte 1:1 met Sample
    date_requested TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    review_state VARCHAR(32) DEFAULT 'created',
    creator VARCHAR(50) NOT NULL,
    created_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (client_uid) REFERENCES clients(uid),
    FOREIGN KEY (contact_uid) REFERENCES contacts(uid),
    FOREIGN KEY (sample_uid) REFERENCES samples(uid) ON DELETE CASCADE
);

-- 11. Werklijsten (Voor de analisten in het lab)
CREATE TABLE worksheets (
    uid VARCHAR(36) PRIMARY KEY,
    worksheet_id VARCHAR(30) NOT NULL UNIQUE,
    instrument_uid VARCHAR(36),
    analyst VARCHAR(50),
    review_state VARCHAR(32) DEFAULT 'open', -- open, attachment_due, verified
    creator VARCHAR(50) NOT NULL,
    created_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (instrument_uid) REFERENCES instruments(uid)
);

-- 12. Analyses (De daadwerkelijke testresultaten per monster)
CREATE TABLE analyses (
    uid VARCHAR(36) PRIMARY KEY,
    analysis_request_uid VARCHAR(36) NOT NULL,
    analysis_service_uid VARCHAR(36) NOT NULL,
    worksheet_uid VARCHAR(36),
    raw_result VARCHAR(50),  -- Directe invoerwaarde van analist of apparaat
    formatted_result VARCHAR(50), -- Resultaat na berekening/afronding
    result_capture_date TIMESTAMP,
    analyst VARCHAR(50),
    verifier VARCHAR(50),
    review_state VARCHAR(32) DEFAULT 'unassigned', -- unassigned, assigned, received, verified
    creator VARCHAR(50) NOT NULL,
    created_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (analysis_request_uid) REFERENCES analysis_requests(uid) ON DELETE CASCADE,
    FOREIGN KEY (analysis_service_uid) REFERENCES analysis_services(uid),
    FOREIGN KEY (worksheet_uid) REFERENCES worksheets(uid) ON DELETE SET NULL
);

-- 4. RAPPORTEN & AUDIT TRAIL
-- 13. Analisecertificaten / Rapportages
CREATE TABLE reports (
    uid VARCHAR(36) PRIMARY KEY,
    report_id VARCHAR(30) NOT NULL UNIQUE,
    analysis_request_uid VARCHAR(36) NOT NULL,
    pdf_attachment_path VARCHAR(255), -- Verwijzing naar het opgeslagen PDF-bestand
    date_published TIMESTAMP,
    review_state VARCHAR(32) DEFAULT 'published',
    creator VARCHAR(50) NOT NULL,
    created_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (analysis_request_uid) REFERENCES analysis_requests(uid)
);

-- 14. Immutable Audit Log (Onveranderbaar logboek)
CREATE TABLE audit_logs (
    id BIGINT AUTO_INCREMENT PRIMARY KEY, -- Oplopend log-id
    object_uid VARCHAR(36) NOT NULL, -- UID van het gewijzigde object (bijv. van een Analysis of Sample)
    object_type VARCHAR(50) NOT NULL, -- Bijv. 'Analysis', 'Sample'
    action VARCHAR(50) NOT NULL, -- Bijv. 'edit', 'transition_to_verified'
    previous_state TEXT, -- JSON of tekst met oude waarden
    new_state TEXT, -- JSON of tekst met nieuwe waarden
    user_id VARCHAR(50) NOT NULL,
    ip_address VARCHAR(45) NOT NULL,
    timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- 5. MONSTER-PARTITIES (SUB-MONSTERS)
-- 15. Monster Partities
CREATE TABLE sample_partitions (
    uid VARCHAR(36) PRIMARY KEY,
    parent_sample_uid VARCHAR(36) NOT NULL,
    partition_id VARCHAR(10) NOT NULL, -- Bijv. 'P1', 'P2'
    container_type VARCHAR(50), -- Bijv. 'Glazen fles', 'Kunststof tube'
    review_state VARCHAR(32) DEFAULT 'active',
    creator VARCHAR(50) NOT NULL,
    created_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (parent_sample_uid) REFERENCES samples(uid) ON DELETE CASCADE
);



