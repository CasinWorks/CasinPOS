-- Disallow franchise store creation on Free plan stores (requires Premium).

create or replace function public.create_franchise_store(
  p_franchisor_store_id uuid,
  p_owner_email text,
  p_store_name text,
  p_copy_stock boolean default true,
  p_default_stock numeric default 0,
  p_notes text default null,
  p_primary_branch_name text default 'Main'
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_parent public.stores%rowtype;
  v_email text := lower(trim(p_owner_email));
  v_franchisee_id uuid;
  v_store_id uuid;
  v_branch_id uuid;
  v_cat record;
  v_prod record;
  v_new_cat_id uuid;
  v_new_prod_id uuid;
  v_cat_map jsonb := '{}'::jsonb;
  v_products_cloned int := 0;
  v_categories_cloned int := 0;
  v_invite public.store_invitations;
  v_owner_linked boolean := false;
  v_stock numeric;
begin
  if v_uid is null then
    raise exception 'NOT_AUTHENTICATED';
  end if;

  if length(trim(p_store_name)) < 1 then
    raise exception 'STORE_NAME_REQUIRED';
  end if;

  if v_email is null or position('@' in v_email) < 2 then
    raise exception 'OWNER_EMAIL_INVALID';
  end if;

  if not public.has_store_role(
    p_franchisor_store_id,
    array['owner', 'admin']::public.store_role[]
  ) then
    raise exception 'FORBIDDEN';
  end if;

  select * into v_parent from public.stores where id = p_franchisor_store_id for share;
  if not found then
    raise exception 'STORE_NOT_FOUND';
  end if;

  -- Only Premium stores may open franchises.
  if v_parent.plan_tier <> 'premium' then
    raise exception 'FREE_FRANCHISE_NOT_ALLOWED';
  end if;

  -- Only root (non-franchise) stores may open franchises.
  if v_parent.franchisor_store_id is not null then
    raise exception 'FRANCHISE_CANNOT_FRANCHISE';
  end if;

  -- Resolve franchisee profile if they already signed up
  select u.id into v_franchisee_id
  from auth.users u
  where lower(u.email) = v_email
  limit 1;

  if v_franchisee_id is not null and v_franchisee_id = v_uid then
    raise exception 'CANNOT_FRANCHISE_SELF';
  end if;

  -- Create child store. Temporary owner = franchisor until invite accepted when user is new;
  -- if user exists, franchisee is owner immediately.
  insert into public.stores (
    name,
    business_type,
    owner_id,
    plan_tier,
    currency_code,
    currency_symbol,
    accept_gcash,
    accept_maya,
    accept_card,
    franchisor_store_id,
    franchise_notes
  ) values (
    trim(p_store_name),
    v_parent.business_type,
    coalesce(v_franchisee_id, v_uid),
    'free',
    v_parent.currency_code,
    v_parent.currency_symbol,
    v_parent.accept_gcash,
    v_parent.accept_maya,
    v_parent.accept_card,
    p_franchisor_store_id,
    nullif(trim(coalesce(p_notes, '')), '')
  )
  returning id into v_store_id;

  insert into public.branches (store_id, name, is_primary)
  values (
    v_store_id,
    coalesce(nullif(trim(p_primary_branch_name), ''), 'Main'),
    true
  )
  returning id into v_branch_id;

  insert into public.subscriptions (store_id, plan_tier, status)
  values (v_store_id, 'free', 'active');

  -- Clone categories
  for v_cat in
    select * from public.categories
    where store_id = p_franchisor_store_id
    order by sort_order, name
  loop
    insert into public.categories (
      store_id, name, sort_order, color_token, icon_key
    ) values (
      v_store_id, v_cat.name, v_cat.sort_order, v_cat.color_token, v_cat.icon_key
    )
    returning id into v_new_cat_id;

    v_cat_map := v_cat_map || jsonb_build_object(v_cat.id::text, v_new_cat_id::text);
    v_categories_cloned := v_categories_cloned + 1;
  end loop;

  -- Clone products (new UUIDs; reuse image_path / URLs; independent stock going forward)
  for v_prod in
    select * from public.products
    where store_id = p_franchisor_store_id
    order by name
  loop
    if p_copy_stock then
      v_stock := v_prod.stock;
    else
      v_stock := case
        when v_prod.stock is null then null
        else coalesce(p_default_stock, 0)
      end;
    end if;

    insert into public.products (
      store_id,
      branch_id,
      category_id,
      kind,
      name,
      sku,
      barcode,
      description,
      image_path,
      price,
      cost_price,
      weight_label,
      calories,
      stock,
      low_stock_threshold,
      is_popular,
      is_active,
      metadata
    ) values (
      v_store_id,
      v_branch_id,
      case
        when v_prod.category_id is null then null
        else (v_cat_map ->> v_prod.category_id::text)::uuid
      end,
      v_prod.kind,
      v_prod.name,
      v_prod.sku,
      v_prod.barcode,
      v_prod.description,
      v_prod.image_path,
      v_prod.price,
      v_prod.cost_price,
      v_prod.weight_label,
      v_prod.calories,
      v_stock,
      v_prod.low_stock_threshold,
      v_prod.is_popular,
      v_prod.is_active,
      coalesce(v_prod.metadata, '{}'::jsonb) || jsonb_build_object(
        'cloned_from_product_id', v_prod.id,
        'cloned_from_store_id', p_franchisor_store_id
      )
    )
    returning id into v_new_prod_id;

    insert into public.product_additions (product_id, name, price, is_active)
    select v_new_prod_id, pa.name, pa.price, pa.is_active
    from public.product_additions pa
    where pa.product_id = v_prod.id;

    v_products_cloned := v_products_cloned + 1;
  end loop;

  if v_franchisee_id is not null then
    insert into public.store_members (store_id, user_id, role, status, invited_by)
    values (v_store_id, v_franchisee_id, 'owner', 'active', v_uid);
    v_owner_linked := true;
  else
    -- Pending owner handoff — token shown in franchisor UI (same invite-accept flow).
    insert into public.store_invitations (
      store_id, email, role, branch_ids, invited_by
    ) values (
      v_store_id, v_email, 'owner', null, v_uid
    )
    returning * into v_invite;
  end if;

  return jsonb_build_object(
    'store_id', v_store_id,
    'branch_id', v_branch_id,
    'store_name', trim(p_store_name),
    'owner_email', v_email,
    'owner_linked', v_owner_linked,
    'invite_token', case when v_owner_linked then null else v_invite.token end,
    'categories_cloned', v_categories_cloned,
    'products_cloned', v_products_cloned,
    'copy_stock', p_copy_stock
  );
end;
$$;
