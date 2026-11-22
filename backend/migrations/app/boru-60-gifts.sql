BEGIN;

CREATE TABLE IF NOT EXISTS "Gift" (
  id SERIAL PRIMARY KEY,
  code TEXT NOT NULL UNIQUE,
  name TEXT NOT NULL,
  "priceCoins" BIGINT NOT NULL CHECK ("priceCoins" > 0),
  category TEXT NOT NULL DEFAULT 'NORMAL',
  "imageUrl" TEXT,
  "animationUrl" TEXT,
  "isActive" BOOLEAN NOT NULL DEFAULT TRUE,
  "createdAt" TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS "GiftTransaction" (
  id BIGSERIAL PRIMARY KEY,
  "senderId" INTEGER NOT NULL REFERENCES "User"(id),
  "receiverId" INTEGER NOT NULL REFERENCES "User"(id),
  "giftId" INTEGER NOT NULL REFERENCES "Gift"(id),
  quantity INTEGER NOT NULL DEFAULT 1 CHECK (quantity > 0),
  "totalCoins" BIGINT NOT NULL CHECK ("totalCoins" > 0),
  "roomId" INTEGER REFERENCES "Room"(id),
  "createdAt" TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS "GiftTransaction_sender_idx"
ON "GiftTransaction" ("senderId", "createdAt" DESC);

CREATE INDEX IF NOT EXISTS "GiftTransaction_receiver_idx"
ON "GiftTransaction" ("receiverId", "createdAt" DESC);

INSERT INTO "Gift" (code, name, "priceCoins", category)
VALUES

-- ROMANTIK: 10
('ROM_ROSE_BOUQUET', 'Gül Buketi', 100, 'ROMANTIC'),
('ROM_LOVE_LETTER', 'Aşk Mektubu', 250, 'ROMANTIC'),
('ROM_HEART_RAIN', 'Kalp Yağmuru', 500, 'ROMANTIC'),
('ROM_ENDLESS_LOVE', 'Sonsuz Aşk', 1000, 'ROMANTIC'),
('ROM_DIAMOND_RING', 'Elmas Yüzük', 2500, 'ROMANTIC'),
('ROM_LOVE_CASTLE', 'Aşk Şatosu', 5000, 'ROMANTIC'),
('ROM_DINNER', 'Romantik Akşam', 10000, 'ROMANTIC'),
('ROM_HEART_DANCE', 'Kalplerin Dansı', 20000, 'ROMANTIC'),
('ROM_LOVE_GALAXY', 'Aşk Galaksisi', 50000, 'ROMANTIC'),
('ROM_INFINITY_VOW', 'Sonsuzluk Yemini', 100000, 'ROMANTIC'),

-- EGLENCE: 10
('FUN_CONFETTI', 'Konfeti', 100, 'FUN'),
('FUN_BIRTHDAY_CAKE', 'Doğum Günü Pastası', 300, 'FUN'),
('FUN_FIREWORKS', 'Havai Fişek', 750, 'FUN'),
('FUN_DISCO_BALL', 'Disko Topu', 1500, 'FUN'),
('FUN_DJ_STAGE', 'DJ Sahnesi', 3000, 'FUN'),
('FUN_CHAMPION_CUP', 'Şampiyon Kupası', 5000, 'FUN'),
('FUN_GOLD_MIC', 'Altın Mikrofon', 10000, 'FUN'),
('FUN_LIGHT_SHOW', 'Işık Gösterisi', 20000, 'FUN'),
('FUN_FESTIVAL_STAGE', 'Festival Sahnesi', 50000, 'FUN'),
('FUN_BORU_FESTIVAL', 'BÖRÜ Festivali', 100000, 'FUN'),

-- HAYVANLAR: 10
('ANM_PANDA', 'Sevimli Panda', 500, 'ANIMALS'),
('ANM_WHITE_HORSE', 'Beyaz At', 1000, 'ANIMALS'),
('ANM_BLACK_PANTHER', 'Kara Panter', 2500, 'ANIMALS'),
('ANM_EAGLE', 'Kartal', 5000, 'ANIMALS'),
('ANM_GREY_WOLF', 'Bozkurt', 10000, 'ANIMALS'),
('ANM_WHITE_WOLF', 'Beyaz Kurt', 25000, 'ANIMALS'),
('ANM_LION_KING', 'Aslan Kral', 50000, 'ANIMALS'),
('ANM_FIRE_TIGER', 'Ateş Kaplanı', 100000, 'ANIMALS'),
('ANM_ICE_DRAGON', 'Buz Ejderhası', 250000, 'ANIMALS'),
('ANM_LEGEND_WOLF', 'Efsanevi Kurt', 500000, 'ANIMALS'),

-- LUKS ARACLAR: 10
('CAR_MOTORBIKE', 'Spor Motosiklet', 1000, 'VEHICLES'),
('CAR_SEDAN', 'Lüks Sedan', 2500, 'VEHICLES'),
('CAR_SPORTS', 'Spor Araba', 5000, 'VEHICLES'),
('CAR_GOLD_SUPERCAR', 'Altın Lamborghini', 10000, 'VEHICLES'),
('CAR_ROYAL_LIMO', 'Kraliyet Limuzini', 25000, 'VEHICLES'),
('CAR_PRIVATE_JET', 'Özel Jet', 50000, 'VEHICLES'),
('CAR_HELICOPTER', 'Helikopter', 100000, 'VEHICLES'),
('CAR_SUPER_YACHT', 'Süper Yat', 250000, 'VEHICLES'),
('CAR_GOLD_CONVOY', 'Altın Konvoy', 500000, 'VEHICLES'),
('CAR_SPACESHIP', 'Uzay Gemisi', 1000000, 'VEHICLES'),

-- KRALIYET: 10
('ROY_GOLD_CROWN', 'Altın Taç', 1000, 'ROYAL'),
('ROY_SCEPTER', 'Kraliyet Asası', 2500, 'ROYAL'),
('ROY_DIAMOND_THRONE', 'Elmas Taht', 5000, 'ROYAL'),
('ROY_GOLD_PALACE', 'Altın Saray', 10000, 'ROYAL'),
('ROY_GUARD', 'Kraliyet Muhafızı', 25000, 'ROYAL'),
('ROY_EMPEROR_CROWN', 'İmparator Tacı', 50000, 'ROYAL'),
('ROY_WOLF_KINGDOM', 'Kurt Krallığı', 100000, 'ROYAL'),
('ROY_LEGEND_THRONE', 'Efsanevi Taht', 250000, 'ROYAL'),
('ROY_BORU_EMPEROR', 'BÖRÜ İmparatoru', 500000, 'ROYAL'),
('ROY_KURTBEY_KINGDOM', 'KURTBEY Krallığı', 1000000, 'ROYAL'),

-- EFSANEVI SVIP: 10
('SVIP_METEOR_RAIN', 'Meteor Yağmuru', 10000, 'SVIP'),
('SVIP_GOLD_STORM', 'Altın Fırtına', 25000, 'SVIP'),
('SVIP_GALAXY_GATE', 'Galaksi Kapısı', 50000, 'SVIP'),
('SVIP_FIRE_DRAGON', 'Ateş Ejderhası', 100000, 'SVIP'),
('SVIP_PHOENIX', 'Anka Kuşu', 150000, 'SVIP'),
('SVIP_SKY_KINGDOM', 'Gökyüzü Krallığı', 250000, 'SVIP'),
('SVIP_DRAGON_EMPEROR', 'Ejderha İmparatoru', 500000, 'SVIP'),
('SVIP_WOLF_RISE', 'Kurtların Yükselişi', 750000, 'SVIP'),
('SVIP_UNIVERSE_RULER', 'Evrenin Hükümdarı', 1000000, 'SVIP'),
('SVIP_BORU_LEGEND', 'BÖRÜ Efsanesi', 2000000, 'SVIP')

ON CONFLICT (code)
DO UPDATE SET
  name = EXCLUDED.name,
  "priceCoins" = EXCLUDED."priceCoins",
  category = EXCLUDED.category;

COMMIT;
