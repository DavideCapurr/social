-- Invite "con link" per chi non e ancora su Halo (step Initial Inner Circle).
-- L'invite puo nascere senza invitee: chi apre il link si aggancia alla riga
-- al momento dell'accettazione (claim). Il check inviter_id <> invitee_id
-- resta valido (passa con invitee null, blocca l'auto-claim).

alter table public.invites
  alter column invitee_id drop not null;

-- Chi arriva dal link non e ancora ne inviter ne invitee: un invite aperto
-- pending deve essere leggibile per il lookup per token. Nota: il token e la
-- capability, ma questa policy rende gli invite aperti pending enumerabili
-- da qualunque utente autenticato (inviter_id + message). Accettato per il
-- lancio: il claim produce solo una proposta di tier, che chiunque puo gia
-- fare verso chiunque; se serve, si passa a una RPC security definer.
drop policy if exists invites_select_involved on public.invites;
create policy invites_select_involved on public.invites
  for select to authenticated
  using (
    inviter_id = auth.uid()
    or invitee_id = auth.uid()
    or (invitee_id is null and status = 'pending')
  );

drop policy if exists invites_insert_own on public.invites;
create policy invites_insert_own on public.invites
  for insert to authenticated
  with check (
    inviter_id = auth.uid()
    and (invitee_id is null or invitee_id <> auth.uid())
    and tier in ('inner', 'close')
    and status = 'pending'
  );

-- Il claim parte da una riga senza invitee (using) e deve uscirne accettata
-- con invitee_id = auth.uid() (with check, secondo ramo).
drop policy if exists invites_update_accept_or_owner_revoke on public.invites;
create policy invites_update_accept_or_owner_revoke on public.invites
  for update to authenticated
  using (
    inviter_id = auth.uid()
    or invitee_id = auth.uid()
    or (invitee_id is null and status = 'pending')
  )
  with check (
    (
      inviter_id = auth.uid()
      and status in ('pending', 'revoked')
    )
    or (
      invitee_id = auth.uid()
      and status in ('accepted', 'declined')
    )
  );

create index if not exists invites_inviter_open_pending_idx
  on public.invites (inviter_id, created_at desc)
  where invitee_id is null and status = 'pending';
