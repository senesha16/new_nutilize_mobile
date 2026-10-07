import { serve } from 'https://deno.land/std@0.201.0/http/server.ts';

const PROJECT_URL = Deno.env.get('PROJECT_URL') || Deno.env.get('SUPABASE_URL');
const SERVICE_ROLE_KEY = Deno.env.get('SERVICE_ROLE_KEY');

function json(body: Record<string, unknown>, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { 'Content-Type': 'application/json' },
  });
}

function serviceHeaders(extra: Record<string, string> = {}) {
  return {
    apikey: SERVICE_ROLE_KEY!,
    Authorization: `Bearer ${SERVICE_ROLE_KEY!}`,
    ...extra,
  };
}

function tableUrl(table: string, filters: Array<[string, number | number[]]>) {
  const url = new URL(`${PROJECT_URL}/rest/v1/${table}`);
  for (const [column, value] of filters) {
    url.searchParams.set(
      column,
      Array.isArray(value) ? `in.(${value.join(',')})` : `eq.${value}`,
    );
  }
  return url;
}

async function getIds(
  table: string,
  idColumn: string,
  filters: Array<[string, number | number[]]>,
): Promise<number[]> {
  const ids: number[] = [];
  const pageSize = 1000;

  for (let offset = 0; ; offset += pageSize) {
    const url = tableUrl(table, filters);
    url.searchParams.set('select', idColumn);
    url.searchParams.set('limit', pageSize.toString());
    url.searchParams.set('offset', offset.toString());

    const response = await fetch(url, { headers: serviceHeaders() });
    if (!response.ok) {
      throw new Error(`Account data lookup failed for ${table}: ${await response.text()}`);
    }

    const rows = await response.json();
    if (!Array.isArray(rows)) {
      throw new Error(`Account data lookup returned invalid rows for ${table}`);
    }

    for (const row of rows) {
      const id = Number(row?.[idColumn]);
      if (!Number.isSafeInteger(id)) {
        throw new Error(`Account data lookup returned an invalid ${idColumn}`);
      }
      ids.push(id);
    }
    if (rows.length < pageSize) return ids;
  }
}

async function deleteRows(
  table: string,
  filters: Array<[string, number | number[]]>,
) {
  const response = await fetch(tableUrl(table, filters), {
    method: 'DELETE',
    headers: serviceHeaders({ Prefer: 'return=minimal' }),
  });
  if (!response.ok) {
    throw new Error(`Account data deletion failed for ${table}: ${await response.text()}`);
  }
}

async function deleteRowsByIds(table: string, column: string, ids: number[]) {
  const batchSize = 100;
  for (let offset = 0; offset < ids.length; offset += batchSize) {
    await deleteRows(table, [[column, ids.slice(offset, offset + batchSize)]]);
  }
}

async function getIdsByIds(
  table: string,
  idColumn: string,
  filterColumn: string,
  filterIds: number[],
): Promise<number[]> {
  const ids: number[] = [];
  const batchSize = 100;
  for (let offset = 0; offset < filterIds.length; offset += batchSize) {
    ids.push(
      ...await getIds(table, idColumn, [
        [filterColumn, filterIds.slice(offset, offset + batchSize)],
      ]),
    );
  }
  return ids;
}

async function deleteUserData(userId: number) {
  const userFilter: Array<[string, number | number[]]> = [['user_id', userId]];

  const reportIds = await getIds('reports', 'report_id', userFilter);
  const reservationIds = await getIds('reservations', 'reservation_id', userFilter);
  const importIds = await getIds('schedule_imports', 'import_id', userFilter);
  const reservationItemIds = await getIdsByIds(
    'reservation_items',
    'reservation_items_id',
    'reservation_id',
    reservationIds,
  );

  await deleteRowsByIds('report_targets', 'report_id', reportIds);
  await deleteRows('reports', userFilter);

  await deleteRowsByIds('reservation_item_units', 'reservation_items_id', reservationItemIds);
  await deleteRowsByIds('reservation_details', 'reservation_id', reservationIds);
  await deleteRowsByIds('reservation_approval_histories', 'reservation_id', reservationIds);
  await deleteRowsByIds('reservation_approvals', 'reservation_id', reservationIds);
  await deleteRowsByIds('reservation_rooms', 'reservation_id', reservationIds);
  await deleteRowsByIds('reservation_items', 'reservation_id', reservationIds);
  await deleteRowsByIds('reservations', 'reservation_id', reservationIds);

  await deleteRows('notifications', userFilter);
  await deleteRows('reservation_issues', userFilter);
  await deleteRowsByIds('schedule_import_details', 'import_id', importIds);
  await deleteRows('schedule_imports', userFilter);
  await deleteRows('sessions', userFilter);
  await deleteRows('admin_activity_logs', userFilter);

  const ownerUrl = tableUrl('item_owners', userFilter);
  const ownerResponse = await fetch(ownerUrl, {
    method: 'PATCH',
    headers: serviceHeaders({
      'Content-Type': 'application/json',
      Prefer: 'return=minimal',
    }),
    body: JSON.stringify({ user_id: null }),
  });
  if (!ownerResponse.ok) {
    throw new Error(`Account ownership cleanup failed: ${await ownerResponse.text()}`);
  }

  await deleteRows('users', userFilter);
}

async function removeUserStorage(bucket: string, userId: number) {
  const pageSize = 1000;
  for (;;) {
    const listResponse = await fetch(`${PROJECT_URL}/storage/v1/object/list/${bucket}`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        apikey: SERVICE_ROLE_KEY!,
      Authorization: `Bearer ${SERVICE_ROLE_KEY}`,
    },
      body: JSON.stringify({
        prefix: `${userId}/`,
        limit: pageSize,
        offset: 0,
        sortBy: { column: 'name', order: 'asc' },
      }),
    });
    if (!listResponse.ok) {
      throw new Error(`Storage list failed for ${bucket}: ${await listResponse.text()}`);
    }

    const objects = await listResponse.json();
    if (!Array.isArray(objects)) {
      throw new Error(`Storage list returned invalid objects for ${bucket}`);
    }
    if (objects.length === 0) return;
    const paths = objects
      .map((object) => object?.name?.toString())
      .filter((name): name is string => Boolean(name))
      .map((name) => `${userId}/${name}`);

    if (paths.length === 0) {
      throw new Error(`Storage list returned no usable paths for ${bucket}`);
    }

    const removeResponse = await fetch(`${PROJECT_URL}/storage/v1/object/${bucket}`, {
      method: 'DELETE',
      headers: {
        'Content-Type': 'application/json',
        apikey: SERVICE_ROLE_KEY!,
      Authorization: `Bearer ${SERVICE_ROLE_KEY}`,
    },
      body: JSON.stringify({ prefixes: paths }),
    });
    if (!removeResponse.ok) {
      throw new Error(`Storage delete failed for ${bucket}: ${await removeResponse.text()}`);
    }
  }
}

serve(async (req) => {
  try {
    if (req.method !== 'POST' || !PROJECT_URL || !SERVICE_ROLE_KEY) {
      return json({ ok: false, error: 'invalid_request' }, 400);
    }

    const authorization = req.headers.get('Authorization');
    const userToken = authorization?.replace(/^Bearer\s+/i, '').trim();
    if (!userToken || userToken === SERVICE_ROLE_KEY) {
      return json({ ok: false, error: 'authentication_required' }, 401);
    }

    const payload = await req.json();
    const code = payload.code?.toString().trim();
    if (!code) {
      return json({ ok: false, error: 'missing_code' }, 400);
    }

    const authResponse = await fetch(`${PROJECT_URL}/auth/v1/user`, {
      headers: {
        apikey: SERVICE_ROLE_KEY,
        Authorization: `Bearer ${userToken}`,
      },
    });
    if (!authResponse.ok) {
      return json({ ok: false, error: 'invalid_session' }, 401);
    }

    const authUser = await authResponse.json();
    const authUserId = authUser?.id?.toString();
    const email = authUser?.email?.toString().trim();
    if (!authUserId || !email) {
      return json({ ok: false, error: 'invalid_account' }, 400);
    }

    const profileResponse = await fetch(
      `${PROJECT_URL}/rest/v1/users?select=user_id,auth_user_id&auth_user_id=eq.${encodeURIComponent(authUserId)}&limit=1`,
      {
        headers: {
          apikey: SERVICE_ROLE_KEY,
          Authorization: `Bearer ${SERVICE_ROLE_KEY}`,
        },
      },
    );
    const profiles = await profileResponse.json().catch(() => []);
    const profile = Array.isArray(profiles) ? profiles[0] : null;
    const userId = profile?.user_id;
    if (!userId) {
      return json({ ok: false, error: 'profile_not_found' }, 404);
    }

    const otpQuery = `${PROJECT_URL}/rest/v1/email_otps?email=eq.${encodeURIComponent(email)}&code=eq.${encodeURIComponent(code)}&purpose=eq.account_deletion&expires_at=gt.${encodeURIComponent(new Date().toISOString())}&select=id&limit=1`;
    const otpResponse = await fetch(otpQuery, {
      headers: {
        apikey: SERVICE_ROLE_KEY,
        Authorization: `Bearer ${SERVICE_ROLE_KEY}`,
      },
    });
    const otpRows = await otpResponse.json().catch(() => []);
    if (!Array.isArray(otpRows) || otpRows.length === 0) {
      return json({ ok: false, error: 'invalid_code' }, 200);
    }

    await removeUserStorage('reports', userId);
    await removeUserStorage('proof_of_consent', userId);

    await deleteUserData(userId);

    const deleteAuthResponse = await fetch(
      `${PROJECT_URL}/auth/v1/admin/users/${encodeURIComponent(authUserId)}`,
      {
        method: 'DELETE',
        headers: {
          apikey: SERVICE_ROLE_KEY,
          Authorization: `Bearer ${SERVICE_ROLE_KEY}`,
        },
      },
    );
    if (!deleteAuthResponse.ok) {
      console.error('Auth account deletion failed:', await deleteAuthResponse.text());
      return json({ ok: false, error: 'auth_deletion_failed' }, 500);
    }

    const otpId = otpRows[0].id;
    await fetch(`${PROJECT_URL}/rest/v1/email_otps?id=eq.${encodeURIComponent(otpId)}`, {
      method: 'DELETE',
      headers: {
        apikey: SERVICE_ROLE_KEY,
        Authorization: `Bearer ${SERVICE_ROLE_KEY}`,
      },
    });

    return json({ ok: true });
  } catch (error) {
    console.error('Account deletion exception:', error);
    return json({ ok: false, error: 'exception' }, 500);
  }
});
