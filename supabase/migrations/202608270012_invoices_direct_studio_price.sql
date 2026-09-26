alter table public.studios add column price_minor bigint not null default 0 check (price_minor >= 0);
update public.studios s set price_minor = coalesce((select pr.amount_minor from public.pricing_rules pr where pr.studio_id=s.id and pr.active=true and pr.rule_type='hourly' order by pr.priority,pr.created_at limit 1),0);
drop table public.pricing_rules;
drop type public.pricing_rule_type;
