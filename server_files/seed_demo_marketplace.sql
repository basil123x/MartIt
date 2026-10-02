-- Demo marketplace for App Review. Run manually after the moderation migration.
-- Image paths follow store_{storeId}/{itemId}/{index}.webp on the MartIt bucket.
-- Upload a real image to each path, or the feed shows the placeholder.
-- Reviewer login (only if MARTIT_DEMO_LOGIN_ENABLED is true in moderation_config.php):
--   phone 00000000  code 000000  uid 9001

INSERT INTO Users (uid, oid, Fullname, Email, Phone, login_type, store_id, Created_At, account_status)
SELECT '9001', '9001', 'Demo Reviewer', 'reviewer@mart-it.store', '00000000', 'Phone', '1', CURDATE(), 'active'
WHERE NOT EXISTS (SELECT 1 FROM Users WHERE uid = '9001');

INSERT INTO Users (uid, oid, Fullname, Email, Phone, login_type, store_id, Created_At, account_status)
SELECT '9101', '9101', 'Nora Home', 'nora@mart-it.store', '97451000001', 'Phone', '1', CURDATE(), 'active'
WHERE NOT EXISTS (SELECT 1 FROM Users WHERE uid = '9101');

INSERT INTO Users (uid, oid, Fullname, Email, Phone, login_type, store_id, Created_At, account_status)
SELECT '9102', '9102', 'Youssef Style', 'youssef@mart-it.store', '97451000002', 'Phone', '1', CURDATE(), 'active'
WHERE NOT EXISTS (SELECT 1 FROM Users WHERE uid = '9102');

INSERT INTO Users (uid, oid, Fullname, Email, Phone, login_type, store_id, Created_At, account_status)
SELECT '9103', '9103', 'Lina Tech', 'lina@mart-it.store', '97451000003', 'Phone', '1', CURDATE(), 'active'
WHERE NOT EXISTS (SELECT 1 FROM Users WHERE uid = '9103');

INSERT INTO Items (id, uid, store_id, name, eng, category, price, qtt, description, description_arb, Visibility, country, has_image, status, media)
SELECT * FROM (
  SELECT '9201' id, '9101' uid, '1' store_id, 'طقم أغطية قطن' name, 'Cotton bedding set' eng, 'Home' category, '180' price, 8 qtt, 'Soft cotton bedding for a double bed.' description, 'طقم أغطية قطن لسرير مزدوج.' description_arb, 'Public' Visibility, 'QA' country, 1 has_image, 1 status, 'https://martit.s3.ap-south-1.amazonaws.com/store_1/9201/1.webp' media
  UNION ALL SELECT '9202', '9101', '1', 'مزهرية سيراميك', 'Ceramic vase', 'Home', '75', 12, 'Handmade ceramic vase.', 'مزهرية سيراميك يدوية.', 'Public', 'QA', 1, 1, 'https://martit.s3.ap-south-1.amazonaws.com/store_1/9202/1.webp'
  UNION ALL SELECT '9203', '9101', '1', 'وسائد كتان', 'Linen cushions', 'Home', '60', 20, 'Set of two linen cushions.', 'طقم وسادتين من الكتان.', 'Public', 'QA', 1, 1, 'https://martit.s3.ap-south-1.amazonaws.com/store_1/9203/1.webp'
  UNION ALL SELECT '9204', '9102', '1', 'قميص كتان', 'Linen shirt', 'Fashion', '140', 6, 'Breathable linen shirt.', 'قميص كتان خفيف.', 'Public', 'QA', 1, 1, 'https://martit.s3.ap-south-1.amazonaws.com/store_1/9204/1.webp'
  UNION ALL SELECT '9205', '9102', '1', 'حقيبة يد', 'Leather tote', 'Fashion', '220', 4, 'Everyday leather tote.', 'حقيبة جلد للاستخدام اليومي.', 'Public', 'QA', 1, 1, 'https://martit.s3.ap-south-1.amazonaws.com/store_1/9205/1.webp'
  UNION ALL SELECT '9206', '9102', '1', 'وشاح حرير', 'Silk scarf', 'Fashion', '90', 15, 'Printed silk scarf.', 'وشاح حرير مطبوع.', 'Public', 'QA', 1, 1, 'https://martit.s3.ap-south-1.amazonaws.com/store_1/9206/1.webp'
  UNION ALL SELECT '9207', '9103', '1', 'سماعة لاسلكية', 'Wireless earbuds', 'Electronics', '260', 10, 'Noise-isolating earbuds.', 'سماعة لاسلكية عازلة للضوضاء.', 'Public', 'QA', 1, 1, 'https://martit.s3.ap-south-1.amazonaws.com/store_1/9207/1.webp'
  UNION ALL SELECT '9208', '9103', '1', 'شاحن سريع', 'Fast charger', 'Electronics', '85', 18, 'USB-C fast charger.', 'شاحن USB-C سريع.', 'Public', 'QA', 1, 1, 'https://martit.s3.ap-south-1.amazonaws.com/store_1/9208/1.webp'
  UNION ALL SELECT '9209', '9103', '1', 'حامل لابتوب', 'Laptop stand', 'Electronics', '110', 9, 'Aluminum laptop stand.', 'حامل لابتوب من الألومنيوم.', 'Public', 'QA', 1, 1, 'https://martit.s3.ap-south-1.amazonaws.com/store_1/9209/1.webp'
  UNION ALL SELECT '9210', '9101', '1', 'مصباح مكتب', 'Desk lamp', 'Home', '95', 7, 'Warm LED desk lamp.', 'مصباح مكتب بإضاءة دافئة.', 'Public', 'QA', 1, 1, 'https://martit.s3.ap-south-1.amazonaws.com/store_1/9210/1.webp'
) seed
WHERE NOT EXISTS (SELECT 1 FROM Items WHERE id = seed.id);
