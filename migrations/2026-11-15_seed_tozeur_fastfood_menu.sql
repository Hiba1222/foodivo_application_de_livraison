-- Fills "Tozeur FastFood" with a Tunisian fast-food menu: categories, dishes, prices,
-- photos, options/extras, and a few sample offers.
-- PREREQUISITE: run 2026-11-15_menu_offers.sql first (adds the offer columns).
-- Run ONCE in Supabase Dashboard -> SQL Editor. It refuses to run twice.
-- Prices are TND millimes (9500 = 9.500 TND). Photos: Unsplash (free to use).
begin;

-- ---------- helpers (temporary, disappear when the session ends) ----------
create or replace function pg_temp.img(p_id text) returns text language sql immutable as $$
  select 'https://images.unsplash.com/photo-' || p_id || '?w=800&q=80&auto=format&fit=crop'
$$;

-- Find-or-create a category and set its position.
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
  r uuid := 'c51e5586-4e7b-4401-bfeb-3700db2187ef';  -- Tozeur FastFood
  c_sand uuid; c_pizza uuid; c_burger uuid; c_plats uuid; c_sides uuid; c_drinks uuid; c_dessert uuid;
  i uuid;

  -- Reusable option sets
  bread jsonb := '[{"n":"Baguette","p":0,"d":true},{"n":"Mlawi","p":500},{"n":"Chapati","p":500},{"n":"Pain libanais","p":0}]';
  sandwich_ingr jsonb := '[{"n":"Harissa","p":0},{"n":"Salade méchouia","p":500},{"n":"Œuf dur","p":500},{"n":"Olives","p":0},{"n":"Pommes de terre","p":0},{"n":"Salade","p":0},{"n":"Tomate","p":0},{"n":"Oignon","p":0,"x":false}]';
  sandwich_extras jsonb := '[{"n":"Supplément fromage","p":1000},{"n":"Œuf","p":500},{"n":"Thon","p":1500},{"n":"Double viande","p":3000},{"n":"Frites dedans","p":1000}]';
  sauces jsonb := '[{"n":"Mayonnaise","p":0},{"n":"Ketchup","p":0},{"n":"Algérienne","p":0},{"n":"Samouraï","p":0},{"n":"Barbecue","p":0},{"n":"Harissa","p":0}]';
  pizza_size jsonb := '[{"n":"Moyenne (30 cm)","p":0,"d":true},{"n":"Grande (36 cm)","p":4000},{"n":"Familiale (40 cm)","p":8000}]';
  pizza_extras jsonb := '[{"n":"Fromage","p":1500},{"n":"Champignons","p":1000},{"n":"Olives","p":500},{"n":"Œuf","p":500},{"n":"Thon","p":1500},{"n":"Merguez","p":2000}]';
  burger_ingr jsonb := '[{"n":"Salade","p":0},{"n":"Tomate","p":0},{"n":"Oignon","p":0},{"n":"Cornichons","p":0},{"n":"Cheddar","p":1000},{"n":"Sauce burger","p":0}]';
  side jsonb := '[{"n":"Frites","p":2500},{"n":"Salade méchouia","p":3000},{"n":"Salade tunisienne","p":3000}]';
  drink jsonb := '[{"n":"Eau 0,5 L","p":1000},{"n":"Boga","p":2000},{"n":"Coca-Cola","p":2500},{"n":"Jus d''orange frais","p":3500}]';
  drink_included jsonb := '[{"n":"Coca-Cola","p":0,"d":true},{"n":"Boga","p":0},{"n":"Eau 0,5 L","p":0},{"n":"Jus d''orange frais","p":1000}]';
begin
  if not exists (select 1 from public.restaurants where id = r) then
    raise exception 'Restaurant Tozeur FastFood not found';
  end if;
  if exists (select 1 from public.menu_items where restaurant_id = r and name = 'Casse-croûte tunisien') then
    raise exception 'This menu was already added — nothing changed.';
  end if;

  -- Categories (existing "Sandwich" and "Pizza" are reused)
  c_sand    := pg_temp.cat(r, 'Sandwich', 1);
  c_pizza   := pg_temp.cat(r, 'Pizza', 2);
  c_burger  := pg_temp.cat(r, 'Burgers', 3);
  c_plats   := pg_temp.cat(r, 'Plats', 4);
  c_sides   := pg_temp.cat(r, 'Accompagnements', 5);
  c_drinks  := pg_temp.cat(r, 'Boissons', 6);
  c_dessert := pg_temp.cat(r, 'Desserts', 7);

  -- Existing Pizza Neptune had no category: put it with the pizzas.
  update public.menu_items set category_id = c_pizza
   where restaurant_id = r and name = 'Pizza Neptune' and category_id is null;

  -- ===================== SANDWICHS =====================
  i := pg_temp.item(r, c_sand, 'Casse-croûte tunisien',
    'Baguette croustillante au thon, harissa, salade méchouia, œuf dur, olives et pommes de terre.',
    4500, pg_temp.img('1509722747041-616f39b57569'));
  perform pg_temp.grp(i, 'Choisissez votre pain', 'choice', 1, 1, 0, bread);
  perform pg_temp.grp(i, 'Ce qu''il y a dedans', 'ingredients', 0, null, 1, sandwich_ingr);
  perform pg_temp.grp(i, 'Suppléments', 'choice', 0, null, 2, sandwich_extras);

  i := pg_temp.item(r, c_sand, 'Chapati Thon',
    'Chapati grillé garni de thon, fromage, œuf, harissa et frites.',
    5000, pg_temp.img('1528735602780-2552fd46c7af'));
  perform pg_temp.grp(i, 'Ce qu''il y a dedans', 'ingredients', 0, null, 0, sandwich_ingr);
  perform pg_temp.grp(i, 'Sauces', 'choice', 0, 2, 1, sauces);
  perform pg_temp.grp(i, 'Suppléments', 'choice', 0, null, 2, sandwich_extras);

  -- Sample offer: -15% for 5 days
  i := pg_temp.item(r, c_sand, 'Chapati Escalope',
    'Chapati grillé, escalope de poulet marinée, fromage fondant, frites et sauce maison.',
    6500, pg_temp.img('1528735602780-2552fd46c7af'),
    5500, 'Promo du jour', now() + interval '5 days', false);
  perform pg_temp.grp(i, 'Ce qu''il y a dedans', 'ingredients', 0, null, 0, sandwich_ingr);
  perform pg_temp.grp(i, 'Sauces', 'choice', 0, 2, 1, sauces);
  perform pg_temp.grp(i, 'Suppléments', 'choice', 0, null, 2, sandwich_extras);

  i := pg_temp.item(r, c_sand, 'Mlawi Escalope',
    'Mlawi feuilleté maison, escalope grillée, fromage, salade, tomate et harissa.',
    7000, pg_temp.img('1626700051175-6818013e1d4f'));
  perform pg_temp.grp(i, 'Ce qu''il y a dedans', 'ingredients', 0, null, 0, sandwich_ingr);
  perform pg_temp.grp(i, 'Sauces', 'choice', 0, 2, 1, sauces);
  perform pg_temp.grp(i, 'Suppléments', 'choice', 0, null, 2, sandwich_extras);

  i := pg_temp.item(r, c_sand, 'Libanais Shawarma Poulet',
    'Pain libanais roulé, shawarma de poulet, frites, crudités et sauce blanche à l''ail.',
    8000, pg_temp.img('1529006557810-274b9b2fc783'),
    null, 'Best-seller', null, true);
  perform pg_temp.grp(i, 'Ce qu''il y a dedans', 'ingredients', 0, null, 0,
    '[{"n":"Frites","p":1000},{"n":"Salade","p":0},{"n":"Tomate","p":0},{"n":"Oignon","p":0},{"n":"Sauce blanche à l''ail","p":0},{"n":"Harissa","p":0}]');
  perform pg_temp.grp(i, 'Sauces', 'choice', 0, 2, 1, sauces);
  perform pg_temp.grp(i, 'Suppléments', 'choice', 0, null, 2, sandwich_extras);

  i := pg_temp.item(r, c_sand, 'Club Sandwich',
    'Pain de mie toasté, jambon de dinde, fromage, salade, tomate et mayonnaise.',
    7500, pg_temp.img('1553909489-cd47e0907980'));
  perform pg_temp.grp(i, 'Ce qu''il y a dedans', 'ingredients', 0, null, 0,
    '[{"n":"Jambon de dinde","p":1500},{"n":"Fromage","p":1000},{"n":"Salade","p":0},{"n":"Tomate","p":0},{"n":"Mayonnaise","p":0}]');
  perform pg_temp.grp(i, 'Accompagnement', 'choice', 0, 1, 1, side);

  -- ===================== PIZZAS =====================
  i := pg_temp.item(r, c_pizza, 'Pizza Margherita',
    'Sauce tomate maison, mozzarella fondante et basilic frais.',
    9000, pg_temp.img('1574071318508-1cdbab80d002'));
  perform pg_temp.grp(i, 'Taille', 'choice', 1, 1, 0, pizza_size);
  perform pg_temp.grp(i, 'Garnitures en plus', 'choice', 0, null, 1, pizza_extras);

  i := pg_temp.item(r, c_pizza, 'Pizza Thon',
    'Sauce tomate, mozzarella, thon, olives noires, oignon et origan.',
    11000, pg_temp.img('1513104890138-7c749659a591'));
  perform pg_temp.grp(i, 'Taille', 'choice', 1, 1, 0, pizza_size);
  perform pg_temp.grp(i, 'Garnitures en plus', 'choice', 0, null, 1, pizza_extras);

  -- Sample offer: -21% for 7 days
  i := pg_temp.item(r, c_pizza, 'Pizza Merguez',
    'Sauce tomate épicée, mozzarella, merguez grillées, poivrons et olives.',
    12500, pg_temp.img('1604382354936-07c5d9983bd3'),
    9900, 'Offre limitée', now() + interval '7 days', true);
  perform pg_temp.grp(i, 'Taille', 'choice', 1, 1, 0, pizza_size);
  perform pg_temp.grp(i, 'Garnitures en plus', 'choice', 0, null, 1, pizza_extras);

  i := pg_temp.item(r, c_pizza, 'Pizza Poulet BBQ',
    'Sauce barbecue, mozzarella, poulet grillé, oignons rouges et coriandre.',
    13500, pg_temp.img('1565299624946-b28f40a0ae38'));
  perform pg_temp.grp(i, 'Taille', 'choice', 1, 1, 0, pizza_size);
  perform pg_temp.grp(i, 'Garnitures en plus', 'choice', 0, null, 1, pizza_extras);

  i := pg_temp.item(r, c_pizza, 'Pizza Végétarienne',
    'Pâte fine, tomates, olives, basilic, poivrons et champignons.',
    10500, pg_temp.img('1585238342024-78d387f4a707'));
  perform pg_temp.grp(i, 'Taille', 'choice', 1, 1, 0, pizza_size);
  perform pg_temp.grp(i, 'Garnitures en plus', 'choice', 0, null, 1, pizza_extras);

  -- ===================== BURGERS =====================
  i := pg_temp.item(r, c_burger, 'Classic Burger',
    'Steak haché de bœuf 150 g, salade, tomate, oignon, cornichons et sauce burger.',
    9500, pg_temp.img('1568901346375-23c9450c58cd'));
  perform pg_temp.grp(i, 'Ce qu''il y a dedans', 'ingredients', 0, null, 0, burger_ingr);
  perform pg_temp.grp(i, 'Ajouter un accompagnement', 'choice', 0, 1, 1, side);
  perform pg_temp.grp(i, 'Ajouter une boisson', 'choice', 0, 1, 2, drink);

  i := pg_temp.item(r, c_burger, 'Cheeseburger',
    'Steak de bœuf, double cheddar fondant, salade, tomate et oignons.',
    10500, pg_temp.img('1571091718767-18b5b1457add'));
  perform pg_temp.grp(i, 'Ce qu''il y a dedans', 'ingredients', 0, null, 0, burger_ingr);
  perform pg_temp.grp(i, 'Ajouter un accompagnement', 'choice', 0, 1, 1, side);
  perform pg_temp.grp(i, 'Ajouter une boisson', 'choice', 0, 1, 2, drink);

  i := pg_temp.item(r, c_burger, 'Chicken Crispy Burger',
    'Filet de poulet pané croustillant, cornichons, sauce fromagère et coleslaw.',
    11000, pg_temp.img('1606755962773-d324e0a13086'));
  perform pg_temp.grp(i, 'Ce qu''il y a dedans', 'ingredients', 0, null, 0, burger_ingr);
  perform pg_temp.grp(i, 'Ajouter un accompagnement', 'choice', 0, 1, 1, side);
  perform pg_temp.grp(i, 'Ajouter une boisson', 'choice', 0, 1, 2, drink);

  -- Combo offers (featured)
  i := pg_temp.item(r, c_burger, 'Menu Étudiant',
    'Classic Burger + frites + boisson au choix. Le bon plan pour les petits budgets !',
    15000, pg_temp.img('1594212699903-ec8a3eca50f5'),
    12500, 'Menu Étudiant', null, true);
  perform pg_temp.grp(i, 'Votre boisson', 'choice', 1, 1, 0, drink_included);
  perform pg_temp.grp(i, 'Ce qu''il y a dans le burger', 'ingredients', 0, null, 1, burger_ingr);

  i := pg_temp.item(r, c_burger, 'Menu Duo Burgers',
    '2 Classic Burgers + 2 boissons au choix. Parfait à partager.',
    24000, pg_temp.img('1550547660-d9450f859349'),
    19900, 'Menu Duo', null, true);
  -- min 1 / max 2 so "2 × Coca" works (pick just Coca-Cola).
  perform pg_temp.grp(i, 'Vos boissons', 'choice', 1, 2, 0,
    '[{"n":"Coca-Cola","p":0},{"n":"Boga","p":0},{"n":"Eau 0,5 L","p":0},{"n":"Jus d''orange frais","p":1000}]');
  perform pg_temp.grp(i, 'Ajouter des frites', 'choice', 0, 1, 1, '[{"n":"Grande portion de frites","p":4000}]');

  -- ===================== PLATS =====================
  i := pg_temp.item(r, c_plats, 'Ojja Merguez',
    'Sauce tomate pimentée, merguez, poivrons et œufs pochés. Servie avec du pain.',
    9000, pg_temp.img('1590412200988-a436970781fa'));
  perform pg_temp.grp(i, 'Suppléments', 'choice', 0, null, 0,
    '[{"n":"Œuf en plus","p":500},{"n":"Merguez en plus","p":2000},{"n":"Fromage","p":1000}]');
  perform pg_temp.grp(i, 'Piquant', 'choice', 1, 1, 1,
    '[{"n":"Doux","p":0},{"n":"Normal","p":0,"d":true},{"n":"Très piquant","p":0}]');

  i := pg_temp.item(r, c_plats, 'Assiette Escalope Panée',
    'Escalope de poulet panée, frites, salade et sauce au choix.',
    14000, pg_temp.img('1562967914-608f82629710'));
  perform pg_temp.grp(i, 'Sauces', 'choice', 0, 2, 0, sauces);
  perform pg_temp.grp(i, 'Ajouter une boisson', 'choice', 0, 1, 1, drink);

  i := pg_temp.item(r, c_plats, 'Poulet Croustillant (4 pièces)',
    '4 morceaux de poulet frit croustillant, servis avec une sauce au choix.',
    12000, pg_temp.img('1626645738196-c2a7c87a8f58'));
  perform pg_temp.grp(i, 'Sauces', 'choice', 0, 2, 0, sauces);
  perform pg_temp.grp(i, 'Ajouter un accompagnement', 'choice', 0, 1, 1, side);
  perform pg_temp.grp(i, 'Ajouter une boisson', 'choice', 0, 1, 2, drink);

  i := pg_temp.item(r, c_plats, 'Assiette Poulet Grillé',
    'Blanc de poulet grillé aux épices, falafels, salade fraîche et sauce tahini.',
    15000, pg_temp.img('1561651823-34feb02250e4'));
  perform pg_temp.grp(i, 'Accompagnement', 'choice', 1, 1, 0,
    '[{"n":"Frites","p":0,"d":true},{"n":"Riz","p":0},{"n":"Salade tunisienne","p":0}]');
  perform pg_temp.grp(i, 'Ajouter une boisson', 'choice', 0, 1, 1, drink);

  i := pg_temp.item(r, c_plats, 'Makrouna Sauce Piquante',
    'Pâtes à la sauce tomate tunisienne, harissa et viande hachée.',
    8000, pg_temp.img('1621996346565-e3dbc646d9a9'));
  perform pg_temp.grp(i, 'Suppléments', 'choice', 0, null, 0,
    '[{"n":"Thon","p":1500},{"n":"Merguez","p":2000},{"n":"Fromage râpé","p":1000},{"n":"Œuf","p":500}]');

  -- ===================== ACCOMPAGNEMENTS =====================
  i := pg_temp.item(r, c_sides, 'Frites',
    'Frites dorées et croustillantes.',
    3000, pg_temp.img('1630384060421-cb20d0e0649d'));
  perform pg_temp.grp(i, 'Taille', 'choice', 1, 1, 0,
    '[{"n":"Normale","p":0,"d":true},{"n":"Grande","p":1500}]');
  perform pg_temp.grp(i, 'Sauces', 'choice', 0, 2, 1, sauces);

  -- Sample offer: -22% for 3 days
  i := pg_temp.item(r, c_sides, 'Frites Fromage',
    'Frites croustillantes nappées de fromage fondu et herbes.',
    4500, pg_temp.img('1573080496219-bb080dd4f877'),
    3500, null, now() + interval '3 days', false);
  perform pg_temp.grp(i, 'Sauces', 'choice', 0, 2, 0, sauces);

  i := pg_temp.item(r, c_sides, 'Briks au Thon (x4)',
    '4 mini briks croustillantes au thon, persil et œuf.',
    5000, pg_temp.img('1601050690597-df0568f70950'));
  perform pg_temp.grp(i, 'Sauces', 'choice', 0, 1, 0,
    '[{"n":"Harissa","p":0},{"n":"Mayonnaise","p":0},{"n":"Citron","p":0}]');

  i := pg_temp.item(r, c_sides, 'Salade Tunisienne',
    'Tomates, concombre, oignon, poivron, thon, œuf et olives, huile d''olive.',
    4500, pg_temp.img('1540420773420-3366772f4999'));
  perform pg_temp.grp(i, 'Ce qu''il y a dedans', 'ingredients', 0, null, 0,
    '[{"n":"Thon","p":1500},{"n":"Œuf","p":500},{"n":"Olives","p":0},{"n":"Oignon","p":0,"x":false}]');

  -- ===================== BOISSONS =====================
  i := pg_temp.item(r, c_drinks, 'Coca-Cola 33 cl', 'Canette bien fraîche.',
    2500, pg_temp.img('1622483767028-3f66f32aef97'));
  i := pg_temp.item(r, c_drinks, 'Boga 25 cl', 'La limonade tunisienne, bien fraîche.',
    2000, pg_temp.img('1581636625402-29b2a704ef13'));
  i := pg_temp.item(r, c_drinks, 'Eau minérale 0,5 L', 'Eau minérale naturelle.',
    1000, pg_temp.img('1548839140-29a749e1cf4d'));
  i := pg_temp.item(r, c_drinks, 'Jus d''orange frais', 'Pressé à la commande, 100 % oranges.',
    4000, pg_temp.img('1600271886742-f049cd451bba'));
  perform pg_temp.grp(i, 'Sucre', 'choice', 1, 1, 0,
    '[{"n":"Avec sucre","p":0,"d":true},{"n":"Sans sucre","p":0}]');

  -- ===================== DESSERTS =====================
  i := pg_temp.item(r, c_dessert, 'Donut Chocolat',
    'Donut moelleux glacé au chocolat et vermicelles colorés.',
    3000, pg_temp.img('1551024601-bec78aea704b'));
  perform pg_temp.grp(i, 'Quantité', 'choice', 1, 1, 0,
    '[{"n":"1 donut","p":0,"d":true},{"n":"Box de 3","p":5000}]');
end $$;

commit;
