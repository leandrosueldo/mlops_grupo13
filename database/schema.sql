-- Esquema de base de datos para almacenar recomendaciones
-- Tabla para almacenar las recomendaciones de ambos modelos

CREATE TABLE IF NOT EXISTS recommendations (
    id SERIAL PRIMARY KEY,
    advertiser_id VARCHAR(50) NOT NULL,
    model_name VARCHAR(20) NOT NULL,  -- 'TopCTR' o 'TopProduct'
    product_id VARCHAR(50) NOT NULL,
    rank_position INTEGER NOT NULL,  -- Posición en el ranking (1-20)
    score FLOAT,  -- CTR para TopCTR, cantidad de vistas para TopProduct
    date DATE NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(advertiser_id, model_name, product_id, date)
);

-- Índices para mejorar las consultas
CREATE INDEX IF NOT EXISTS idx_recommendations_advertiser_model_date 
    ON recommendations(advertiser_id, model_name, date);
CREATE INDEX IF NOT EXISTS idx_recommendations_date 
    ON recommendations(date);
