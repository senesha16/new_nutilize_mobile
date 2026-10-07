import { serve } from 'https://deno.land/std@0.199.0/http/server.ts';

const PROJECT_URL = Deno.env.get('PROJECT_URL') || Deno.env.get('SUPABASE_URL');
const SERVICE_ROLE_KEY = Deno.env.get('SERVICE_ROLE_KEY') ||
  Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');
const MAX_IMAGE_BYTES = 4 * 1024 * 1024;

function json(body: Record<string, unknown>, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { 'Content-Type': 'application/json' },
  });
}

function encodedPath(path: string) {
  return path.split('/').map(encodeURIComponent).join('/');
}

function safeFileName(fileName: string) {
  const cleaned = fileName.toLowerCase().replace(/[^a-z0-9_.-]/g, '_');
  return cleaned.slice(-120) || 'screenshot.jpg';
}

function imageContentType(fileName: string) {
  const extension = fileName.split('.').pop()?.toLowerCase();
  switch (extension) {
    case 'png':
      return 'image/png';
    case 'webp':
      return 'image/webp';
    case 'jpg':
    case 'jpeg':
      return 'image/jpeg';
    default:
      return null;
  }
}

async function requestUser(
  url: string,
  serviceRoleKey: string,
  accessToken: string,
) {
  const response = await fetch(`${url}/auth/v1/user`, {
    headers: {
      apikey: serviceRoleKey,
      Authorization: `Bearer ${accessToken}`,
    },
  });
  if (!response.ok) return null;
  return await response.json();
}

serve(async (req) => {
  if (req.method !== 'POST') {
    return json({ error: 'method_not_allowed' }, 405);
  }
  if (!PROJECT_URL || !SERVICE_ROLE_KEY) {
    console.error('Issue report function is missing Supabase configuration.');
    return json({ error: 'server_misconfigured' }, 500);
  }

  const accessToken = req.headers.get('Authorization')
    ?.replace(/^Bearer\s+/i, '')
    .trim();
  if (!accessToken || accessToken === SERVICE_ROLE_KEY) {
    return json({ error: 'authentication_required' }, 401);
  }

  let uploadedPath: string | null = null;
  try {
    const user = await requestUser(PROJECT_URL, SERVICE_ROLE_KEY, accessToken);
    const authUserId = user?.id?.toString();
    const email = user?.email?.toString().trim();
    if (!authUserId || !email) {
      return json({ error: 'invalid_session' }, 401);
    }

    const body = await req.json();
    const description = body.description?.toString().trim();
    if (!description) {
      return json({ error: 'description_required' }, 400);
    }

    const profileResponse = await fetch(
      `${PROJECT_URL}/rest/v1/users?select=user_id&auth_user_id=eq.${encodeURIComponent(authUserId)}&limit=1`,
      {
        headers: {
          apikey: SERVICE_ROLE_KEY,
          Authorization: `Bearer ${SERVICE_ROLE_KEY}`,
        },
      },
    );
    if (!profileResponse.ok) {
      console.error('Issue report profile lookup failed:', profileResponse.status);
      return json({ error: 'profile_lookup_failed' }, 500);
    }

    let profiles = await profileResponse.json();
    if (!Array.isArray(profiles) || profiles.length === 0) {
      const emailLookup = await fetch(
        `${PROJECT_URL}/rest/v1/users?select=user_id&email=ilike.${encodeURIComponent(email)}&limit=1`,
        {
          headers: {
            apikey: SERVICE_ROLE_KEY,
            Authorization: `Bearer ${SERVICE_ROLE_KEY}`,
          },
        },
      );
      if (!emailLookup.ok) {
        console.error('Issue report email profile lookup failed:', emailLookup.status);
        return json({ error: 'profile_lookup_failed' }, 500);
      }
      profiles = await emailLookup.json();
    }

    const userId = Array.isArray(profiles) ? profiles[0]?.user_id : null;
    if (userId == null) {
      return json({ error: 'profile_not_found' }, 404);
    }

    const payload: Record<string, unknown> = {
      user_id: userId,
      auth_user_id: authUserId,
      reported_by: email,
      description,
      status: 'Pending',
      created_at: new Date().toISOString(),
    };

    const reservationId = Number(body.reservation_id);
    if (Number.isSafeInteger(reservationId) && reservationId > 0) {
      payload.reservation_id = reservationId;
    }

    const reportedItems = Array.isArray(body.reported_items)
      ? body.reported_items.map((item: unknown) => String(item).trim()).filter(Boolean)
      : [];
    if (reportedItems.length > 0) {
      payload.description = `${description}\n\nReported items: ${reportedItems.join(', ')}`;
    }
    payload.reported_items = reportedItems;

    const imageName = body.image_name?.toString();
    const imageBase64 = body.image_base64?.toString();
    if (Boolean(imageName) !== Boolean(imageBase64)) {
      return json({ error: 'incomplete_image' }, 400);
    }

    if (imageName && imageBase64) {
      const contentType = imageContentType(imageName);
      if (!contentType) {
        return json({ error: 'unsupported_image_type' }, 415);
      }

      let imageBytes: Uint8Array;
      try {
        const binary = atob(imageBase64);
        if (binary.length === 0 || binary.length > MAX_IMAGE_BYTES) {
          return json({ error: 'image_size_invalid' }, 413);
        }
        imageBytes = Uint8Array.from(binary, (character) => character.charCodeAt(0));
      } catch {
        return json({ error: 'invalid_image_data' }, 400);
      }

      const fileName = `${crypto.randomUUID()}_${safeFileName(imageName)}`;
      const reservationFolder = Number.isSafeInteger(reservationId) && reservationId > 0
        ? reservationId
        : 0;
      uploadedPath = `${userId}/${reservationFolder}/${fileName}`;

      const uploadResponse = await fetch(
        `${PROJECT_URL}/storage/v1/object/reports/${encodedPath(uploadedPath)}`,
        {
          method: 'POST',
          headers: {
            apikey: SERVICE_ROLE_KEY,
            Authorization: `Bearer ${SERVICE_ROLE_KEY}`,
            'Content-Type': contentType,
            'x-upsert': 'false',
          },
          body: imageBytes,
        },
      );
      if (!uploadResponse.ok) {
        console.error('Issue report image upload failed:', uploadResponse.status);
        return json({ error: 'image_upload_failed' }, 502);
      }

      payload.image_name = imageName;
      payload.image_url =
        `${PROJECT_URL}/storage/v1/object/public/reports/${encodedPath(uploadedPath)}`;
    }

    const insertResponse = await fetch(
      `${PROJECT_URL}/rest/v1/reservation_issues`,
      {
        method: 'POST',
        headers: {
          apikey: SERVICE_ROLE_KEY,
          Authorization: `Bearer ${SERVICE_ROLE_KEY}`,
          'Content-Type': 'application/json',
          Prefer: 'return=representation',
        },
        body: JSON.stringify(payload),
      },
    );
    if (!insertResponse.ok) {
      const insertError = await insertResponse.text();
      console.error(
        'Issue report database insert failed:',
        insertResponse.status,
        insertError,
      );
      if (uploadedPath) {
        const cleanupResponse = await fetch(
          `${PROJECT_URL}/storage/v1/object/reports/${encodedPath(uploadedPath)}`,
          {
            method: 'DELETE',
            headers: {
              apikey: SERVICE_ROLE_KEY,
              Authorization: `Bearer ${SERVICE_ROLE_KEY}`,
            },
          },
        );
        if (!cleanupResponse.ok) {
          console.error('Orphaned issue report image cleanup failed:', cleanupResponse.status);
        }
      }
      return json({ error: 'report_insert_failed' }, 500);
    }

    const insertedRows = await insertResponse.json();
    const report = Array.isArray(insertedRows) ? insertedRows[0] : null;
    if (!report) {
      return json({ error: 'report_insert_failed' }, 500);
    }

    return json({
      ok: true,
      report_id: report.report_id ?? report.id ?? null,
      image_url: payload.image_url ?? null,
    });
  } catch (error) {
    console.error('Issue report submission failed:', error);
    if (uploadedPath) {
      const cleanupResponse = await fetch(
        `${PROJECT_URL}/storage/v1/object/reports/${encodedPath(uploadedPath)}`,
        {
          method: 'DELETE',
          headers: {
            apikey: SERVICE_ROLE_KEY,
            Authorization: `Bearer ${SERVICE_ROLE_KEY}`,
          },
        },
      ).catch(() => null);
      if (cleanupResponse && !cleanupResponse.ok) {
        console.error('Orphaned issue report image cleanup failed:', cleanupResponse.status);
      }
    }
    return json({ error: 'submission_failed' }, 500);
  }
});
