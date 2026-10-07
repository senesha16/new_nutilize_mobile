import { serve } from 'https://deno.land/std@0.201.0/http/server.ts';

const DEFAULT_MINIMUM_ANDROID_BUILD = 80;

serve((req) => {
  if (req.method !== 'GET') {
    return new Response(JSON.stringify({ error: 'method_not_allowed' }), {
      status: 405,
      headers: { 'Content-Type': 'application/json' },
    });
  }

  const configuredMinimum = Number(
    Deno.env.get('MINIMUM_ANDROID_BUILD') ?? DEFAULT_MINIMUM_ANDROID_BUILD,
  );
  if (!Number.isSafeInteger(configuredMinimum) || configuredMinimum < 1) {
    console.error('MINIMUM_ANDROID_BUILD must be a positive integer.');
    return new Response(JSON.stringify({ error: 'invalid_update_policy' }), {
      status: 500,
      headers: { 'Content-Type': 'application/json' },
    });
  }

  return new Response(
    JSON.stringify({
      minimumAndroidBuild: configuredMinimum,
    }),
    {
      status: 200,
      headers: {
        'Content-Type': 'application/json',
        'Cache-Control': 'no-store',
      },
    },
  );
});
