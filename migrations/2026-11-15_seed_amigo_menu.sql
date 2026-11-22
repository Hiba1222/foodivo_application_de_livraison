-- Fills "Amigo" (Fast Food Bnine) with a street-food menu: tacos & burritos, smash burgers,
-- crispy chicken & wings, pizzas, hot-dogs & paninis, snacks, crêpes & desserts, shakes & drinks.
-- Different dishes, prices, photos and deals from Tozeur FastFood.
-- PREREQUISITE: 2026-11-15_menu_offers.sql (already applied).
-- Run ONCE in Supabase Dashboard -> SQL Editor. It refuses to run twice.
-- Prices are TND millimes (9500 = 9.500 TND). Photos: Unsplash (free to use).
begin;

-- ---------- helpers (temporary, disappear when the session ends) ----------
create or replace function pg_temp.img(p_id text) returns text language sql immutable as $$
  select 'https://images.unsplash.com/photo-' || p_id || '?w=800&q=80&auto=format&fit=crop'
$$;

create or replace function pg_temp.cat(p_rest uuid, p_name text, p_sort int) returns uuid language plpgsql as $$
declare v uuid;
begin
  select id into v from public.menu_categories
   where restaurant_id = p_rest and lower(name) = lower(p_name) limit 1;
  if v is null then
    insert into public.menu_categories (restaurant_id, name, sort_order)
    values (p_rest, p_name, p_sort) returning id into v;
  else
    update public.menu_categories set sort_order = p_sort where id = v;
  end if;
  return v;
end $$;

create or replace function pg_temp.item(
  p_rest uuid, p_cat uuid, p_name text, p_desc text, p_price int, p_img text,
  p_offer int default null, p_label text default null, p_ends timestamptz default null,
  p_featured boolean default false
) returns uuid language plpgsql as $$
declare v uuid;
begin
  insert into public.menu_items (restaurant_id, category_id, name, description, price_cents, image_url,
                                 is_available, offer_price_cents, offer_label, offer_ends_at, is_featured)
  values (p_rest, p_cat, p_name, p_desc, p_price, p_img, true, p_offer, p_label, p_ends, p_featured)
  returning id into v;
  return v;
end $$;

-- Option group + its options. p_opts: [{"n": name, "p": price, "d": default?, "x": can be extra?}]
create or replace function pg_temp.grp(
  p_item uuid, p_name text, p_kind text, p_min int, p_max int, p_sort int, p_opts jsonb
) returns void language plpgsql as $$
declare g uuid; o jsonb; i int := 0;
begin
  insert into public.menu_option_groups (menu_item_id, name, kind, min_select, max_select, sort_order)
  values (p_item, p_name, p_kind, p_min, p_max, p_sort) returning id into g;
  for o in select value from jsonb_array_elements(p_opts) loop
    insert into public.menu_options (group_id, name, price_cents, is_default, allow_extra, is_available, sort_order)
    values (g, o->>'n', coalesce((o->>'p')::int, 0), coalesce((o->>'d')::boolean, false),
            coalesce((o->>'x')::boolean, true), true, i);
    i := i + 1;
  end loop;
end $$;

do $$
declare
  r uuid := '404aaf07-8640-45e5-9b24-809fa2a46299';  -- Amigo
  c_mex uuid; c_burger uuid; c_chicken uuid; c_pizza uuid; c_hotdog uuid; c_snacks uuid; c_dessert uuid; c_drinks uuid;
  i uuid;

  -- Reusable option sets
  mex_meat jsonb := '[{"n":"Poulet mariné","p":0,"d":true},{"n":"Bœuf épicé","p":1000},{"n":"Mixte poulet-bœuf","p":1500}]';
  mex_ingr jsonb := '[{"n":"Oignon rouge","p":0,"x":false},{"n":"Coriandre","p":0,"x":false},{"n":"Pico de gallo","p":500},{"n":"Guacamole","p":1500},{"n":"Fromage râpé","p":1000},{"n":"Jalapeños","p":500}]';
  mex_sauce jsonb := '[{"n":"Salsa piquante","p":0},{"n":"Crème fraîche","p":0},{"n":"Sauce fromagère","p":0},{"n":"Chipotle","p":0},{"n":"Guacamole","p":1500}]';
  smash_ingr jsonb := '[{"n":"Cheddar","p":1000},{"n":"Bacon de bœuf","p":2000},{"n":"Oignons caramélisés","p":500},{"n":"Cornichons","p":0},{"n":"Salade","p":0},{"n":"Tomate","p":0},{"n":"Sauce Amigo","p":0}]';
  smash_extra jsonb := '[{"n":"Steak smash en plus","p":4000},{"n":"Œuf au plat","p":500},{"n":"Onion rings dans le burger","p":1500},{"n":"Jalapeños","p":500}]';
  combo_side jsonb := '[{"n":"Frites maison","p":3000},{"n":"Onion rings","p":4000},{"n":"Frites de patate douce","p":4500}]';
  drinks jsonb := '[{"n":"Eau 0,5 L","p":1000},{"n":"Soda 33 cl","p":2500},{"n":"Citronnade maison","p":3000},{"n":"Mojito virgin","p":4500}]';
  drink_included jsonb := '[{"n":"Soda 33 cl","p":0,"d":true},{"n":"Eau 0,5 L","p":0},{"n":"Citronnade maison","p":0},{"n":"Mojito virgin","p":1500}]';
  wing_sauce jsonb := '[{"n":"Buffalo","p":0,"d":true},{"n":"BBQ fumé","p":0},{"n":"Miel-moutarde","p":0},{"n":"Teriyaki sésame","p":0},{"n":"Très piquant","p":0}]';
  dips jsonb := '[{"n":"Ranch","p":0},{"n":"Cheddar","p":0},{"n":"Sauce à l''ail","p":0},{"n":"Chipotle","p":0}]';
  pizza_size jsonb := '[{"n":"Medium (29 cm)","p":0,"d":true},{"n":"Large (33 cm)","p":3500},{"n":"XL (40 cm)","p":7500}]';
  pizza_crust jsonb := '[{"n":"Pâte classique","p":0,"d":true},{"n":"Pâte fine","p":0},{"n":"Bords farcis au fromage","p":3000}]';
  pizza_top jsonb := '[{"n":"Mozzarella","p":1500},{"n":"Pepperoni","p":2500},{"n":"Poulet","p":2500},{"n":"Champignons","p":1000},{"n":"Jalapeños","p":500},{"n":"Ananas","p":1000}]';
  shake_top jsonb := '[{"n":"Chantilly","p":0},{"n":"Éclats d''Oreo","p":1000},{"n":"Coulis caramel","p":500},{"n":"Morceaux de brownie","p":1500}]';
  shake_size jsonb := '[{"n":"Regular (35 cl)","p":0,"d":true},{"n":"Large (50 cl)","p":2500}]';
  ice jsonb := '[{"n":"Avec glaçons","p":0,"d":true},{"n":"Sans glaçons","p":0}]';
begin
  if not exists (select 1 from public.restaurants where id = r) then
    raise exception 'Restaurant Amigo not found';
  end if;
  if exists (select 1 from public.menu_items where restaurant_id = r and name = 'Amigo Smash') then
    raise exception 'This menu was already added — nothing changed.';
  end if;

  -- Cover photo, only if the owner hasn't uploaded one yet.
  update public.restaurants
     set cover_image_url = pg_temp.img('1551782450-a2132b4ba21d')
   where id = r and cover_image_url is null;

  c_mex     := pg_temp.cat(r, 'Tacos & Burritos', 1);
  c_burger  := pg_temp.cat(r, 'Smash Burgers', 2);
  c_chicken := pg_temp.cat(r, 'Poulet & Grillades', 3);
  c_pizza   := pg_temp.cat(r, 'Pizzas & Pâtes', 4);
  c_hotdog  := pg_temp.cat(r, 'Hot-dogs & Paninis', 5);
  c_snacks  := pg_temp.cat(r, 'Snacks & Salades', 6);
  c_dessert := pg_temp.cat(r, 'Crêpes & Desserts', 7);
  c_drinks  := pg_temp.cat(r, 'Milkshakes & Boissons', 8);

  -- ===================== TACOS & BURRITOS =====================
  i := pg_temp.item(r, c_mex, 'Tacos al Pastor (x3)',
    '3 tortillas de maïs, viande marinée aux épices mexicaines, oignon, coriandre et citron vert.',
    9500, pg_temp.img('1552332386-f8dd00dc2f85'));
  perform pg_temp.grp(i, 'Choix de la viande', 'choice', 1, 1, 0, mex_meat);
  perform pg_temp.grp(i, 'Garniture', 'ingredients', 0, null, 1, mex_ingr);
  perform pg_temp.grp(i, 'Sauces', 'choice', 0, 2, 2, mex_sauce);

  i := pg_temp.item(r, c_mex, 'Tacos Crispy Chicken (x3)',
    'Poulet croustillant, chou rouge, maïs, pico de gallo et sauce fromagère coulante.',
    10500, pg_temp.img('1615870216519-2f9fa575fa5c'));
  perform pg_temp.grp(i, 'Garniture', 'ingredients', 0, null, 0, mex_ingr);
  perform pg_temp.grp(i, 'Sauces', 'choice', 0, 2, 1, mex_sauce);

  i := pg_temp.item(r, c_mex, 'Quesadilla Poulet Fromage',
    'Grande tortilla grillée, poulet, mozzarella et cheddar fondus, poivrons. Servie avec guacamole.',
    11500, pg_temp.img('1618040996337-56904b7850b9'),
    null, 'Nouveau', null, false);
  perform pg_temp.grp(i, 'Choix de la viande', 'choice', 1, 1, 0, mex_meat);
  perform pg_temp.grp(i, 'Sauces', 'choice', 0, 2, 1, mex_sauce);
  perform pg_temp.grp(i, 'Ajouter un accompagnement', 'choice', 0, 1, 2, combo_side);

  i := pg_temp.item(r, c_mex, 'Burrito Bœuf Épicé',
    'Tortilla roulée, bœuf épicé, frites, tomate, oignon rouge, salade et sauce chipotle.',
    12000, pg_temp.img('1633321702518-7feccafb94d5'));
  perform pg_temp.grp(i, 'Garniture', 'ingredients', 0, null, 0,
    '[{"n":"Frites","p":1000},{"n":"Tomate","p":0},{"n":"Oignon rouge","p":0,"x":false},{"n":"Salade","p":0},{"n":"Fromage râpé","p":1000},{"n":"Jalapeños","p":500}]');
  perform pg_temp.grp(i, 'Sauces', 'choice', 0, 2, 1, mex_sauce);

  -- ===================== SMASH BURGERS =====================
  i := pg_temp.item(r, c_burger, 'Amigo Smash',
    'Steak smashé grillé à la plancha, cheddar fondu, bacon de bœuf, salade et sauce Amigo.',
    10000, pg_temp.img('1550317138-10000687a72b'),
    null, 'Best-seller', null, true);
  perform pg_temp.grp(i, 'Dans le burger', 'ingredients', 0, null, 0, smash_ingr);
  perform pg_temp.grp(i, 'Suppléments', 'choice', 0, null, 1, smash_extra);
  perform pg_temp.grp(i, 'Ajouter un accompagnement', 'choice', 0, 1, 2, combo_side);

  i := pg_temp.item(r, c_burger, 'Double Smash Cheese',
    '2 steaks smashés, double cheddar, oignons caramélisés et cornichons.',
    13500, pg_temp.img('1572802419224-296b0aeee0d9'));
  perform pg_temp.grp(i, 'Dans le burger', 'ingredients', 0, null, 0, smash_ingr);
  perform pg_temp.grp(i, 'Suppléments', 'choice', 0, null, 1, smash_extra);
  perform pg_temp.grp(i, 'Ajouter un accompagnement', 'choice', 0, 1, 2, combo_side);

  -- Deal: -21% for 6 days
  i := pg_temp.item(r, c_burger, 'Triple Monster',
    '3 steaks smashés, triple cheddar, bacon de bœuf et sauce Amigo. Pour les très grosses faims !',
    17500, pg_temp.img('1553979459-d2229ba7433b'),
    13900, 'Défi Monster', now() + interval '6 days', true);
  perform pg_temp.grp(i, 'Dans le burger', 'ingredients', 0, null, 0, smash_ingr);
  perform pg_temp.grp(i, 'Ajouter un accompagnement', 'choice', 0, 1, 1, combo_side);

  i := pg_temp.item(r, c_burger, 'Classic Amigo',
    'Burger de bœuf, salade, tomate, cornichons, cheddar et sauce maison.',
    9000, pg_temp.img('1586190848861-99aa4a171e90'));
  perform pg_temp.grp(i, 'Dans le burger', 'ingredients', 0, null, 0, smash_ingr);
  perform pg_temp.grp(i, 'Ajouter un accompagnement', 'choice', 0, 1, 1, combo_side);
  perform pg_temp.grp(i, 'Ajouter une boisson', 'choice', 0, 1, 2, drinks);

  -- Combo (featured)
  i := pg_temp.item(r, c_burger, 'Menu Smash',
    'Amigo Smash + frites maison + boisson au choix.',
    16000, pg_temp.img('1551782450-a2132b4ba21d'),
    12900, 'Menu Smash', null, true);
  perform pg_temp.grp(i, 'Votre boisson', 'choice', 1, 1, 0, drink_included);
  perform pg_temp.grp(i, 'Votre accompagnement', 'choice', 1, 1, 1,
    '[{"n":"Frites maison","p":0,"d":true},{"n":"Onion rings","p":1000},{"n":"Frites de patate douce","p":1500}]');
  perform pg_temp.grp(i, 'Dans le burger', 'ingredients', 0, null, 2, smash_ingr);

  -- ===================== POULET & GRILLADES =====================
  -- Deal: -15% for 4 days
  i := pg_temp.item(r, c_chicken, 'Wings Buffalo (x6)',
    '6 ailes de poulet laquées sauce buffalo, céleri et dip ranch.',
    11000, pg_temp.img('1567620832903-9fc6debc209f'),
    9400, 'Promo Wings', now() + interval '4 days', false);
  perform pg_temp.grp(i, 'Sauce des wings', 'choice', 1, 1, 0, wing_sauce);
  perform pg_temp.grp(i, 'Dips', 'choice', 0, 2, 1, dips);

  i := pg_temp.item(r, c_chicken, 'Wings Teriyaki Sésame (x6)',
    '6 ailes de poulet caramélisées teriyaki, graines de sésame et pickles d''oignon.',
    11500, pg_temp.img('1527477396000-e27163b481c2'));
  perform pg_temp.grp(i, 'Dips', 'choice', 0, 2, 0, dips);
  perform pg_temp.grp(i, 'Ajouter un accompagnement', 'choice', 0, 1, 1, combo_side);

  i := pg_temp.item(r, c_chicken, 'Tenders Crispy (x5)',
    '5 aiguillettes de poulet panées maison, ultra croustillantes.',
    10500, pg_temp.img('1562967916-eb82221dfb92'));
  perform pg_temp.grp(i, 'Dips', 'choice', 0, 2, 0, dips);
  perform pg_temp.grp(i, 'Ajouter un accompagnement', 'choice', 0, 1, 1, combo_side);
  perform pg_temp.grp(i, 'Ajouter une boisson', 'choice', 0, 1, 2, drinks);

  i := pg_temp.item(r, c_chicken, 'Poulet Grillé Citron & Herbes',
    'Filets de poulet grillés, marinade citron-thym, légumes sautés et sauce crémeuse.',
    16000, pg_temp.img('1598515214211-89d3c73ae83b'));
  perform pg_temp.grp(i, 'Accompagnement', 'choice', 1, 1, 0,
    '[{"n":"Légumes sautés","p":0,"d":true},{"n":"Frites maison","p":0},{"n":"Riz","p":0}]');

  i := pg_temp.item(r, c_chicken, 'Entrecôte Grillée',
    'Entrecôte de bœuf grillée, jus de cuisson, frites maison et sauce au choix.',
    28000, pg_temp.img('1529692236671-f1f6cf9683ba'));
  perform pg_temp.grp(i, 'Cuisson', 'choice', 1, 1, 0,
    '[{"n":"Saignante","p":0},{"n":"À point","p":0,"d":true},{"n":"Bien cuite","p":0}]');
  perform pg_temp.grp(i, 'Sauce', 'choice', 0, 1, 1,
    '[{"n":"Sauce poivre","p":0},{"n":"Sauce champignons","p":0},{"n":"Beurre maître d''hôtel","p":0}]');

  -- Sharing combo (featured)
  i := pg_temp.item(r, c_chicken, 'Bucket Amigo (à partager)',
    '12 wings + 5 tenders + 2 frites maison + 3 dips. Idéal pour 3-4 personnes.',
    35000, pg_temp.img('1567620832903-9fc6debc209f'),
    27900, 'À partager', null, true);
  perform pg_temp.grp(i, 'Sauce des wings', 'choice', 1, 2, 0, wing_sauce);
  perform pg_temp.grp(i, 'Vos 3 dips', 'choice', 1, 3, 1, dips);

  -- ===================== PIZZAS & PÂTES =====================
  -- Deal: -25% for 2 days (countdown turns red in the last 24h)
  i := pg_temp.item(r, c_pizza, 'Pizza Pepperoni',
    'Sauce tomate, mozzarella et généreuses tranches de pepperoni.',
    13000, pg_temp.img('1534308983496-4fabb1a015ee'),
    9800, 'Happy Hour', now() + interval '2 days', true);
  perform pg_temp.grp(i, 'Taille', 'choice', 1, 1, 0, pizza_size);
  perform pg_temp.grp(i, 'Pâte', 'choice', 1, 1, 1, pizza_crust);
  perform pg_temp.grp(i, 'Garnitures en plus', 'choice', 0, null, 2, pizza_top);

  i := pg_temp.item(r, c_pizza, 'Pizza Napolitaine Basilic',
    'Pâte napolitaine, tomates San Marzano, mozzarella fior di latte et basilic frais.',
    10000, pg_temp.img('1595854341625-f33ee10dbf94'));
  perform pg_temp.grp(i, 'Taille', 'choice', 1, 1, 0, pizza_size);
  perform pg_temp.grp(i, 'Pâte', 'choice', 1, 1, 1, pizza_crust);
  perform pg_temp.grp(i, 'Garnitures en plus', 'choice', 0, null, 2, pizza_top);

  i := pg_temp.item(r, c_pizza, 'Pizza Épinards Ricotta',
    'Base tomate, épinards frais, ricotta crémeuse, mozzarella et ail.',
    12500, pg_temp.img('1593560708920-61dd98c46a4e'));
  perform pg_temp.grp(i, 'Taille', 'choice', 1, 1, 0, pizza_size);
  perform pg_temp.grp(i, 'Garnitures en plus', 'choice', 0, null, 1, pizza_top);

  i := pg_temp.item(r, c_pizza, 'Pizza Blanche Poulet',
    'Crème fraîche, mozzarella, poulet rôti, tomates confites et origan.',
    12000, pg_temp.img('1594007654729-407eedc4be65'));
  perform pg_temp.grp(i, 'Taille', 'choice', 1, 1, 0, pizza_size);
  perform pg_temp.grp(i, 'Pâte', 'choice', 1, 1, 1, pizza_crust);
  perform pg_temp.grp(i, 'Garnitures en plus', 'choice', 0, null, 2, pizza_top);

  i := pg_temp.item(r, c_pizza, 'Pizza Party XL + Soda 1,5 L',
    'Pizza XL au choix (pepperoni, poulet ou fromage) + une bouteille de soda 1,5 L.',
    26000, pg_temp.img('1571407970349-bc81e7e96d47'),
    21000, 'Soirée foot', null, true);
  perform pg_temp.grp(i, 'Votre pizza', 'choice', 1, 1, 0,
    '[{"n":"Pepperoni","p":0,"d":true},{"n":"Poulet","p":0},{"n":"4 fromages","p":0}]');
  perform pg_temp.grp(i, 'Pâte', 'choice', 1, 1, 1, pizza_crust);

  i := pg_temp.item(r, c_pizza, 'Spaghetti Bolognaise',
    'Spaghetti, sauce bolognaise mijotée au bœuf, parmesan et basilic.',
    9500, pg_temp.img('1600803907087-f56d462fd26b'));
  perform pg_temp.grp(i, 'Suppléments', 'choice', 0, null, 0,
    '[{"n":"Parmesan en plus","p":1000},{"n":"Piment","p":0},{"n":"Boulettes de bœuf","p":3000}]');

  -- ===================== HOT-DOGS & PANINIS =====================
  i := pg_temp.item(r, c_hotdog, 'Hot-dog Classique',
    'Pain brioché, saucisse de bœuf grillée, ketchup et moutarde.',
    6000, pg_temp.img('1612392062631-94dd858cba88'));
  perform pg_temp.grp(i, 'Garniture', 'ingredients', 0, null, 0,
    '[{"n":"Ketchup","p":0},{"n":"Moutarde","p":0},{"n":"Oignons frits","p":500},{"n":"Cornichons","p":0},{"n":"Cheddar fondu","p":1000}]');

  i := pg_temp.item(r, c_hotdog, 'Hot-dog Amigo Loaded',
    'Saucisse XL, bacon de bœuf, cheddar fondu, oignons, tomate, jalapeños et sauce Amigo.',
    8500, pg_temp.img('1619740455993-9e612b1af08a'));
  perform pg_temp.grp(i, 'Garniture', 'ingredients', 0, null, 0,
    '[{"n":"Bacon de bœuf","p":2000},{"n":"Cheddar fondu","p":1000},{"n":"Oignons","p":0},{"n":"Tomate","p":0},{"n":"Jalapeños","p":500},{"n":"Sauce Amigo","p":0}]');
  perform pg_temp.grp(i, 'Ajouter un accompagnement', 'choice', 0, 1, 1, combo_side);

  i := pg_temp.item(r, c_hotdog, 'Panini Poulet Pesto',
    'Pain ciabatta grillé, poulet, pesto au basilic, tomate et mozzarella.',
    8000, pg_temp.img('1621852004158-f3bc188ace2d'));
  perform pg_temp.grp(i, 'Garniture', 'ingredients', 0, null, 0,
    '[{"n":"Pesto","p":0},{"n":"Tomate","p":0},{"n":"Mozzarella","p":1000},{"n":"Roquette","p":0}]');
  perform pg_temp.grp(i, 'Ajouter un accompagnement', 'choice', 0, 1, 1, combo_side);

  i := pg_temp.item(r, c_hotdog, 'Sandwich Caprese',
    'Pain complet toasté, tomate, mozzarella, salade croquante et huile d''olive.',
    7500, pg_temp.img('1539252554453-80ab65ce3586'));
  perform pg_temp.grp(i, 'Suppléments', 'choice', 0, null, 0,
    '[{"n":"Poulet","p":2500},{"n":"Avocat","p":2000},{"n":"Pesto","p":500}]');

  -- ===================== SNACKS & SALADES =====================
  i := pg_temp.item(r, c_snacks, 'Onion Rings',
    'Rondelles d''oignon panées et croustillantes.',
    5000, pg_temp.img('1639024471283-03518883512d'));
  perform pg_temp.grp(i, 'Dips', 'choice', 0, 2, 0, dips);

  i := pg_temp.item(r, c_snacks, 'Frites Maison',
    'Frites fraîches coupées maison, sel de mer.',
    3500, pg_temp.img('1576107232684-1279f390859f'));
  perform pg_temp.grp(i, 'Taille', 'choice', 1, 1, 0,
    '[{"n":"Normale","p":0,"d":true},{"n":"Grande","p":2000}]');
  perform pg_temp.grp(i, 'Topping', 'choice', 0, null, 1,
    '[{"n":"Cheddar fondu","p":1500},{"n":"Bacon de bœuf","p":2000},{"n":"Paprika fumé","p":0}]');

  i := pg_temp.item(r, c_snacks, 'Frites de Patate Douce',
    'Patate douce croustillante, fleur de sel et paprika.',
    5500, pg_temp.img('1585109649139-366815a0d713'));
  perform pg_temp.grp(i, 'Dips', 'choice', 0, 2, 0, dips);

  i := pg_temp.item(r, c_snacks, 'Healthy Bowl Poulet',
    'Poulet grillé, quinoa, maïs, concombre, chou rouge, tomates cerises et œuf.',
    12500, pg_temp.img('1546069901-ba9599a7e63c'));
  perform pg_temp.grp(i, 'Dans le bowl', 'ingredients', 0, null, 0,
    '[{"n":"Poulet","p":2500},{"n":"Œuf","p":500},{"n":"Maïs","p":0},{"n":"Concombre","p":0},{"n":"Avocat","p":2000}]');
  perform pg_temp.grp(i, 'Sauce', 'choice', 0, 1, 1,
    '[{"n":"Vinaigrette citron","p":0,"d":true},{"n":"Sauce yaourt","p":0},{"n":"Sésame-soja","p":0}]');

  i := pg_temp.item(r, c_snacks, 'Salade Feta & Betterave',
    'Mesclun, betterave rôtie, feta, orange, noix et vinaigrette au miel.',
    10000, pg_temp.img('1561043433-aaf687c4cf04'));
  perform pg_temp.grp(i, 'Suppléments', 'choice', 0, null, 0,
    '[{"n":"Poulet grillé","p":2500},{"n":"Avocat","p":2000}]');

  -- ===================== CRÊPES & DESSERTS =====================
  i := pg_temp.item(r, c_dessert, 'Crêpe Sucrée',
    'Crêpe fine et dorée, garniture au choix.',
    5500, pg_temp.img('1519676867240-f03562e64548'));
  perform pg_temp.grp(i, 'Garniture', 'choice', 1, 1, 0,
    '[{"n":"Nutella","p":0,"d":true},{"n":"Nutella banane","p":1000},{"n":"Miel citron","p":0},{"n":"Orange & chantilly","p":500}]');
  perform pg_temp.grp(i, 'Topping', 'choice', 0, null, 1,
    '[{"n":"Chantilly","p":500},{"n":"Boule de glace vanille","p":2000},{"n":"Amandes grillées","p":1000}]');

  i := pg_temp.item(r, c_dessert, 'Brownie Fondant',
    'Brownie au chocolat noir, cœur fondant, nappage chocolat.',
    5000, pg_temp.img('1606313564200-e75d5e30476c'));
  perform pg_temp.grp(i, 'Topping', 'choice', 0, null, 0,
    '[{"n":"Boule de glace vanille","p":2000},{"n":"Chantilly","p":500}]');

  i := pg_temp.item(r, c_dessert, 'Gâteau Chocolat (part)',
    'Génoise au chocolat, crème ganache et copeaux de chocolat.',
    6500, pg_temp.img('1578985545062-69928b1d9587'));

  i := pg_temp.item(r, c_dessert, 'Layer Cake Framboise',
    'Génoise moelleuse, crème légère et framboises fraîches.',
    7000, pg_temp.img('1565958011703-44f9829ba187'));

  i := pg_temp.item(r, c_dessert, 'Cookies Pépites (x3)',
    '3 cookies maison aux pépites de chocolat, croustillants dehors, moelleux dedans.',
    4500, pg_temp.img('1558961363-fa8fdf82db35'));

  i := pg_temp.item(r, c_dessert, 'Coupe Oreo Glacée',
    'Glace vanille, crème chantilly, biscuits Oreo et sauce chocolat.',
    7500, pg_temp.img('1563805042-7684c019e1cb'));

  -- ===================== MILKSHAKES & BOISSONS =====================
  i := pg_temp.item(r, c_drinks, 'Milkshake Oreo',
    'Glace vanille, biscuits Oreo mixés, chantilly et sauce chocolat.',
    8500, pg_temp.img('1572490122747-3968b75cc699'));
  perform pg_temp.grp(i, 'Taille', 'choice', 1, 1, 0, shake_size);
  perform pg_temp.grp(i, 'Toppings', 'choice', 0, 2, 1, shake_top);

  i := pg_temp.item(r, c_drinks, 'Milkshake Fraise',
    'Fraises fraîches, glace vanille et lait frais.',
    8000, pg_temp.img('1579954115545-a95591f28bfc'));
  perform pg_temp.grp(i, 'Taille', 'choice', 1, 1, 0, shake_size);
  perform pg_temp.grp(i, 'Toppings', 'choice', 0, 2, 1, shake_top);

  i := pg_temp.item(r, c_drinks, 'Freakshake Amigo',
    'Le shake géant : chocolat, Oreo, brownie, chantilly et sauce caramel qui déborde !',
    12000, pg_temp.img('1541658016709-82535e94bc69'),
    null, 'Nouveau', null, true);
  perform pg_temp.grp(i, 'Toppings', 'choice', 0, 2, 0, shake_top);

  i := pg_temp.item(r, c_drinks, 'Mojito Virgin',
    'Menthe fraîche, citron vert, sucre de canne et eau pétillante. Sans alcool.',
    6500, pg_temp.img('1513558161293-cdaf765ed2fd'));
  perform pg_temp.grp(i, 'Glaçons', 'choice', 1, 1, 0, ice);
  perform pg_temp.grp(i, 'Saveur', 'choice', 1, 1, 1,
    '[{"n":"Classique","p":0,"d":true},{"n":"Fraise","p":1000},{"n":"Fruit de la passion","p":1000}]');

  i := pg_temp.item(r, c_drinks, 'Citronnade Maison',
    'Citrons pressés, menthe fraîche et une touche de miel.',
    5000, pg_temp.img('1621263764928-df1444c5e859'));
  perform pg_temp.grp(i, 'Glaçons', 'choice', 1, 1, 0, ice);
  perform pg_temp.grp(i, 'Sucre', 'choice', 1, 1, 1,
    '[{"n":"Normal","p":0,"d":true},{"n":"Peu sucré","p":0},{"n":"Sans sucre","p":0}]');

  i := pg_temp.item(r, c_drinks, 'Cocktail Fruité (sans alcool)',
    'Jus de fruits rouges, ananas et citron vert, servi bien frais.',
    7500, pg_temp.img('1544145945-f90425340c7e'));
  perform pg_temp.grp(i, 'Glaçons', 'choice', 1, 1, 0, ice);
end $$;

commit;
