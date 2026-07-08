// Edge Function « admin-users » : opérations réservées aux administrateurs.
//
// POST JSON : { action: 'list' } |
//             { action: 'create', email, password } |
//             { action: 'delete', userId }
//
// Sécurité : le JWT de l'appelant est vérifié, puis la claim app_metadata.role
// doit valoir 'admin'. Seule cette fonction manipule la clé service_role
// (injectée automatiquement par Supabase, jamais présente côté client).
//
// Déploiement : npx supabase functions deploy admin-users --project-ref <ref>

import { createClient } from 'npm:@supabase/supabase-js@2';

const cors = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers':
    'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};

const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), {
    status,
    headers: { ...cors, 'Content-Type': 'application/json' },
  });

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: cors });
  if (req.method !== 'POST') return json({ error: 'method_not_allowed' }, 405);

  const url = Deno.env.get('SUPABASE_URL')!;

  // Identifie l'appelant via SON jeton (client anon + header Authorization).
  const authClient = createClient(url, Deno.env.get('SUPABASE_ANON_KEY')!, {
    global: { headers: { Authorization: req.headers.get('Authorization') ?? '' } },
  });
  const { data: { user: caller }, error: authError } =
    await authClient.auth.getUser();
  if (authError || !caller) return json({ error: 'unauthorized' }, 401);
  if (caller.app_metadata?.role !== 'admin') {
    return json({ error: 'forbidden' }, 403);
  }

  const admin = createClient(url, Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!, {
    auth: { persistSession: false },
  });

  const body = await req.json().catch(() => null);

  switch (body?.action) {
    case 'list': {
      const { data, error } = await admin.auth.admin.listUsers({
        page: 1,
        perPage: 1000,
      });
      if (error) return json({ error: 'internal', message: error.message }, 500);
      return json({
        users: data.users.map((u) => ({
          id: u.id,
          email: u.email ?? null,
          created_at: u.created_at,
          last_sign_in_at: u.last_sign_in_at ?? null,
          is_admin: u.app_metadata?.role === 'admin',
        })),
      });
    }

    case 'create': {
      if (!body.email || !body.password) {
        return json({ error: 'bad_request', message: 'email et password requis' }, 400);
      }
      // email_confirm: le compte est actif immédiatement, sans email de confirmation.
      const { data, error } = await admin.auth.admin.createUser({
        email: body.email,
        password: body.password,
        email_confirm: true,
      });
      if (error) {
        const dup = /already|exists|registered/i.test(error.message);
        return json(
          { error: dup ? 'email_exists' : 'internal', message: error.message },
          dup ? 409 : 500,
        );
      }
      return json({
        user: {
          id: data.user.id,
          email: data.user.email,
          created_at: data.user.created_at,
        },
      });
    }

    case 'delete': {
      const id = body.userId;
      if (!id) return json({ error: 'bad_request', message: 'userId requis' }, 400);
      if (id === caller.id) {
        return json({ error: 'bad_request', message: 'auto-suppression interdite' }, 400);
      }
      const { data: target, error: getError } =
        await admin.auth.admin.getUserById(id);
      if (getError || !target?.user) {
        return json({ error: 'bad_request', message: 'utilisateur introuvable' }, 400);
      }
      if (target.user.app_metadata?.role === 'admin') {
        return json({ error: 'bad_request', message: 'suppression d’un admin interdite' }, 400);
      }
      // Purge défensive : les FK sont en ON DELETE CASCADE (schema.sql), mais
      // on supprime explicitement pour ne dépendre d'aucun détail du schéma.
      for (const t of ['favorites', 'history', 'collection', 'film_seasons', 'films']) {
        const { error } = await admin.from(t).delete().eq('user_id', id);
        if (error) return json({ error: 'internal', message: `${t}: ${error.message}` }, 500);
      }
      const { error } = await admin.auth.admin.deleteUser(id);
      if (error) return json({ error: 'internal', message: error.message }, 500);
      return json({ success: true });
    }

    default:
      return json({ error: 'bad_request', message: 'action inconnue' }, 400);
  }
});
