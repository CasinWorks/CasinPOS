-- Connect service jobs to reports: collected revenue + same viewer gate as other reports.

create or replace function public.report_service_stats(
  p_store_id uuid,
  p_start timestamptz,
  p_end timestamptz,
  p_branch_id uuid default null
)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_sent int;
  v_accepted int;
  v_avg numeric;
  v_outstanding int;
  v_upcoming int;
  v_completed int;
  v_deposit_out numeric;
  v_collected numeric;
  v_jobs int;
  v_by_service jsonb;
begin
  if not public.can_view_store_reports(p_store_id) then
    raise exception 'FORBIDDEN' using errcode = 'P0001';
  end if;

  select
    count(*) filter (where status in ('sent', 'accepted', 'rejected'))::int,
    count(*) filter (where status = 'accepted')::int,
    avg(estimated_total) filter (where status in ('sent', 'accepted')),
    count(*) filter (
      where status = 'sent'
        and (valid_until is null or valid_until >= current_date)
    )::int
  into v_sent, v_accepted, v_avg, v_outstanding
  from public.quotes
  where store_id = p_store_id
    and created_at >= p_start
    and created_at < p_end
    and (p_branch_id is null or branch_id = p_branch_id);

  select
    count(*) filter (where status = 'upcoming')::int,
    count(*) filter (where status = 'completed')::int
  into v_upcoming, v_completed
  from public.service_bookings
  where store_id = p_store_id
    and (p_branch_id is null or branch_id = p_branch_id);

  select coalesce(sum(t.balance_due), 0)
  into v_deposit_out
  from public.transactions t
  where t.store_id = p_store_id
    and t.business_type = 'service'
    and t.payment_state in ('deposit_paid', 'unpaid')
    and t.balance_due > 0
    and (p_branch_id is null or t.branch_id = p_branch_id);

  select
    coalesce(sum(t.amount_paid), 0),
    count(*)::int
  into v_collected, v_jobs
  from public.transactions t
  where t.store_id = p_store_id
    and t.business_type = 'service'
    and t.status = 'paid'
    and t.paid_at >= p_start
    and t.paid_at < p_end
    and (p_branch_id is null or t.branch_id = p_branch_id);

  select coalesce(jsonb_agg(to_jsonb(x)), '[]'::jsonb)
  into v_by_service
  from (
    select
      ti.name_snapshot as item_name,
      sum(ti.quantity) as units_sold,
      sum(ti.line_total) as revenue
    from public.transaction_items ti
    join public.transactions t on t.id = ti.transaction_id
    where t.store_id = p_store_id
      and t.business_type = 'service'
      and t.status = 'paid'
      and t.paid_at >= p_start
      and t.paid_at < p_end
      and (p_branch_id is null or t.branch_id = p_branch_id)
    group by ti.name_snapshot
    order by sum(ti.line_total) desc
    limit 20
  ) x;

  return jsonb_build_object(
    'quotes_sent', coalesce(v_sent, 0),
    'quotes_accepted', coalesce(v_accepted, 0),
    'conversion_rate', case when coalesce(v_sent, 0) = 0 then 0
      else round((coalesce(v_accepted, 0)::numeric / v_sent) * 100, 1) end,
    'average_quote_value', coalesce(v_avg, 0),
    'outstanding_quotes', coalesce(v_outstanding, 0),
    'upcoming_bookings', coalesce(v_upcoming, 0),
    'completed_bookings', coalesce(v_completed, 0),
    'outstanding_deposits', coalesce(v_deposit_out, 0),
    'collected_revenue', coalesce(v_collected, 0),
    'paid_jobs', coalesce(v_jobs, 0),
    'revenue_by_service', coalesce(v_by_service, '[]'::jsonb)
  );
end;
$$;

grant execute on function public.report_service_stats(
  uuid, timestamptz, timestamptz, uuid
) to authenticated;

notify pgrst, 'reload schema';
