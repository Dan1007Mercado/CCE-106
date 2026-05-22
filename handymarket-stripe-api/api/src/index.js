export default {
	async fetch(request, env) {
		const corsHeaders = {
			'Access-Control-Allow-Origin': '*',
			'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
			'Access-Control-Allow-Headers': 'Content-Type',
		};

		const url = new URL(request.url);

		if (request.method === 'OPTIONS') {
			return new Response(null, {
				status: 204,
				headers: corsHeaders,
			});
		}

		if (request.method === 'GET' && url.pathname === '/session-status') {
			const sessionId = url.searchParams.get('session_id')?.trim();

			if (!sessionId) {
				return new Response(JSON.stringify({ error: 'Missing session_id.' }), {
					status: 400,
					headers: {
						...corsHeaders,
						'Content-Type': 'application/json',
					},
				});
			}

			try {
				const stripeResponse = await fetch(`https://api.stripe.com/v1/checkout/sessions/${encodeURIComponent(sessionId)}`, {
					method: 'GET',
					headers: {
						Authorization: `Bearer ${env.STRIPE_SECRET_KEY}`,
					},
				});

				const session = await stripeResponse.json();

				if (!stripeResponse.ok) {
					return new Response(JSON.stringify(session), {
						status: stripeResponse.status,
						headers: {
							...corsHeaders,
							'Content-Type': 'application/json',
						},
					});
				}

				return new Response(
					JSON.stringify({
						sessionId: session.id,
						status: session.status,
						paymentStatus: session.payment_status,
						paymentIntent: session.payment_intent,
					}),
					{
						status: 200,
						headers: {
							...corsHeaders,
							'Content-Type': 'application/json',
						},
					},
				);
			} catch (error) {
				return new Response(JSON.stringify({ error: error.message }), {
					status: 500,
					headers: {
						...corsHeaders,
						'Content-Type': 'application/json',
					},
				});
			}
		}

		if (request.method === 'GET' && url.pathname === '/success') {
			return new Response(
				`<!doctype html>
<html lang="en">
  <head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title>Payment Successful</title>
  </head>
  <body>
    <main>
      <h1>Payment Successful</h1>
      <p>Your Stripe test payment was completed successfully.</p>
      <p>You may now return to the HandyMarket app.</p>
    </main>
  </body>
</html>`,
				{
					status: 200,
					headers: {
						...corsHeaders,
						'Content-Type': 'text/html',
					},
				},
			);
		}

		if (request.method === 'GET' && url.pathname === '/cancel') {
			return new Response(
				`<!doctype html>
<html lang="en">
  <head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title>Payment Cancelled</title>
  </head>
  <body>
    <main>
      <h1>Payment Cancelled</h1>
      <p>The Stripe payment was cancelled.</p>
      <p>You may return to the HandyMarket app and try again.</p>
    </main>
  </body>
</html>`,
				{
					status: 200,
					headers: {
						...corsHeaders,
						'Content-Type': 'text/html',
					},
				},
			);
		}

		if (request.method !== 'POST') {
			return new Response(JSON.stringify({ error: 'Method not allowed. Use POST.' }), {
				status: 405,
				headers: {
					...corsHeaders,
					'Content-Type': 'application/json',
				},
			});
		}

		try {
			const body = await request.json();

			const { bookingId, paymentId, serviceTitle, customerEmail, amount } = body;

			if (!bookingId || !paymentId || !serviceTitle || !amount) {
				return new Response(JSON.stringify({ error: 'Missing required fields.' }), {
					status: 400,
					headers: {
						...corsHeaders,
						'Content-Type': 'application/json',
					},
				});
			}

			const amountInCentavos = Math.round(Number(amount) * 100);

			if (!Number.isFinite(amountInCentavos) || amountInCentavos <= 0) {
				return new Response(JSON.stringify({ error: 'Invalid amount.' }), {
					status: 400,
					headers: {
						...corsHeaders,
						'Content-Type': 'application/json',
					},
				});
			}

			const formData = new URLSearchParams();

			formData.append('mode', 'payment');
			formData.append('payment_method_types[0]', 'card');

			formData.append('line_items[0][quantity]', '1');
			formData.append('line_items[0][price_data][currency]', 'php');
			formData.append('line_items[0][price_data][unit_amount]', amountInCentavos.toString());
			formData.append('line_items[0][price_data][product_data][name]', serviceTitle);

			if (customerEmail) {
				formData.append('customer_email', customerEmail);
			}

			formData.append('metadata[bookingId]', bookingId);
			formData.append('metadata[paymentId]', paymentId);

			formData.append('success_url', 'https://api.handymarket-api.workers.dev/success?session_id={CHECKOUT_SESSION_ID}');

			formData.append('cancel_url', 'https://api.handymarket-api.workers.dev/cancel');

			const stripeResponse = await fetch('https://api.stripe.com/v1/checkout/sessions', {
				method: 'POST',
				headers: {
					Authorization: `Bearer ${env.STRIPE_SECRET_KEY}`,
					'Content-Type': 'application/x-www-form-urlencoded',
				},
				body: formData,
			});

			const session = await stripeResponse.json();

			if (!stripeResponse.ok) {
				return new Response(JSON.stringify(session), {
					status: stripeResponse.status,
					headers: {
						...corsHeaders,
						'Content-Type': 'application/json',
					},
				});
			}

			return new Response(
				JSON.stringify({
					sessionId: session.id,
					checkoutUrl: session.url,
				}),
				{
					status: 200,
					headers: {
						...corsHeaders,
						'Content-Type': 'application/json',
					},
				},
			);
		} catch (error) {
			return new Response(JSON.stringify({ error: error.message }), {
				status: 500,
				headers: {
					...corsHeaders,
					'Content-Type': 'application/json',
				},
			});
		}
	},
};
