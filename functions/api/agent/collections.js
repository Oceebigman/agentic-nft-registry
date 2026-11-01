export async function onRequestGet({ request }) {
  const url = new URL(request.url);
  const registryUrl = new URL("/registry/collections.json", url.origin);
  const upstream = await fetch(registryUrl, { headers: { accept: "application/json" } });
  if (!upstream.ok) return Response.json({ error: "Registry unavailable" }, { status: 502 });
  const registry = await upstream.json();
  let collections = Array.isArray(registry.collections) ? registry.collections : [];
  const symbol = url.searchParams.get("symbol");
  const agentId = url.searchParams.get("agentIdRequired");
  const status = url.searchParams.get("status");
  if (symbol) collections = collections.filter(c => String(c.symbol).toLowerCase() === symbol.toLowerCase());
  if (agentId === "true") collections = collections.filter(c => c.agentIdRequired === true);
  if (agentId === "false") collections = collections.filter(c => c.agentIdRequired !== true);
  if (status) collections = collections.filter(c => c.status === status);
  return Response.json({
    name: "Agentic NFT Launchpad",
    chainId: 56,
    network: "BNB Smart Chain Mainnet",
    source: registryUrl.toString(),
    count: collections.length,
    collections
  }, {
    headers: {
      "Cache-Control": "public, max-age=60, s-maxage=120",
      "Access-Control-Allow-Origin": "*"
    }
  });
}
