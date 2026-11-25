// NXT Step USA – Admin-Funktion (Supabase Edge Function "admin-users").
// Legt Spieler-Zugänge an, setzt Passwörter, ändert E-Mails und löscht Spieler.
// Läuft auf dem Server von Supabase, nie im Browser. Den geheimen Schlüssel stellt Supabase selbst bereit.
import { createClient } from 'npm:@supabase/supabase-js@2';

const cors = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};
const json = (status: number, body: unknown) =>
  new Response(JSON.stringify(body), { status, headers: { ...cors, 'content-type': 'application/json' } });
const okEmail = (e: unknown) => typeof e === 'string' && /^\S+@\S+\.\S+$/.test(e.trim());
const okPw = (p: unknown) => typeof p === 'string' && p.length >= 8 && p.length <= 72;

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: cors });
  if (req.method !== 'POST') return json(405, { error: 'Nur POST erlaubt' });

  const url = Deno.env.get('SUPABASE_URL');
  const key = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') || Deno.env.get('SERVICE_ROLE_KEY');
  if (!url || !key) return json(500, { error: 'Server-Schlüssel fehlt' });
  const db = createClient(url, key, { auth: { autoRefreshToken: false, persistSession: false } });

  // 1) Wer ruft an? Nur angemeldete Admins.
  const token = (req.headers.get('authorization') || '').replace(/^Bearer\s+/i, '');
  if (!token) return json(401, { error: 'Nicht angemeldet' });
  const { data: who, error: whoErr } = await db.auth.getUser(token);
  if (whoErr || !who?.user) return json(401, { error: 'Sitzung abgelaufen, bitte neu anmelden' });
  const { data: adm } = await db.from('admins').select('user_id').eq('user_id', who.user.id).maybeSingle();
  if (!adm) return json(403, { error: 'Nur für Admins' });

  let body: any;
  try { body = await req.json(); } catch { return json(400, { error: 'Ungültige Anfrage' }); }
  const { action, player_id } = body || {};
  if (!player_id) return json(400, { error: 'player_id fehlt' });
  const { data: player, error: pErr } = await db.from('players').select('id,user_id,email,name').eq('id', player_id).maybeSingle();
  if (pErr) return json(500, { error: pErr.message });

  try {
    if (action === 'create') {
      const email = String(body.email || '').trim().toLowerCase();
      if (!okEmail(email)) return json(400, { error: 'Bitte eine gültige E-Mail angeben' });
      if (!okPw(body.password)) return json(400, { error: 'Passwort muss 8 bis 72 Zeichen haben' });
      // Das Profil ist evtl. noch nicht gespeichert: dann eine minimale Zeile anlegen.
      if (!player) { const { error } = await db.from('players').insert({ id: player_id, email, name: body.name || '' }); if (error) throw error; }
      else if (player.user_id) return json(409, { error: 'Dieser Spieler hat schon einen Zugang' });
      const { data, error } = await db.auth.admin.createUser({ email, password: body.password, email_confirm: true, user_metadata: { name: body.name || '' } });
      if (error) return json(400, { error: /already|registered|exists/i.test(error.message) ? 'Diese E-Mail hat schon einen Zugang' : error.message });
      const { error: uErr } = await db.from('players').update({ user_id: data.user.id, email }).eq('id', player_id);
      if (uErr) { await db.auth.admin.deleteUser(data.user.id); throw uErr; }
      return json(200, { user_id: data.user.id });
    }

    if (!player) return json(404, { error: 'Spieler nicht gefunden' });

    if (action === 'reset') {
      if (!player.user_id) return json(400, { error: 'Spieler hat noch keinen Zugang' });
      if (!okPw(body.password)) return json(400, { error: 'Passwort muss 8 bis 72 Zeichen haben' });
      const { error } = await db.auth.admin.updateUserById(player.user_id, { password: body.password });
      if (error) throw error;
      return json(200, { ok: true });
    }

    if (action === 'email') {
      const email = String(body.email || '').trim().toLowerCase();
      if (!okEmail(email)) return json(400, { error: 'Bitte eine gültige E-Mail angeben' });
      if (player.user_id) { const { error } = await db.auth.admin.updateUserById(player.user_id, { email, email_confirm: true }); if (error) throw error; }
      const { error } = await db.from('players').update({ email }).eq('id', player_id); if (error) throw error;
      return json(200, { ok: true });
    }

    if (action === 'delete') {
      for (const bucket of ['player-images', 'player-docs', 'player-thumbs']) {
        const { data: files } = await db.storage.from(bucket).list(player_id, { limit: 1000 });
        if (files?.length) await db.storage.from(bucket).remove(files.map((f) => `${player_id}/${f.name}`));
      }
      const { error } = await db.from('players').delete().eq('id', player_id); if (error) throw error;
      if (player.user_id) await db.auth.admin.deleteUser(player.user_id);
      return json(200, { ok: true });
    }

    return json(400, { error: 'Unbekannte Aktion' });
  } catch (e) {
    return json(500, { error: (e as Error).message || 'Serverfehler' });
  }
});
