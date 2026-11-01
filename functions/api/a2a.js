export async function onRequestPost({ request }) {
  let body;
  try { body = await request.json(); } catch { return Response.json({ jsonrpc: "2.0", id: null, error: { code: -32700, message: "Parse error" } }, { status: 400 }); }
  const id = body?.id ?? null;
  if (body?.jsonrpc !== "2.0" || typeof body?.method !== "string") {
    return Response.json({ jsonrpc: "2.0", id, error: { code: -32600, message: "Invalid Request" } }, { status: 400 });
  }
  if (body.method !== "message/send") {
    return Response.json({ jsonrpc: "2.0", id, error: { code: -32601, message: "Method not found" } }, { status: 404 });
  }
  const parts = body?.params?.message?.parts ?? [];
  const prompt = parts.filter(p => p?.kind === "text" && typeof p.text === "string").map(p => p.text).join("\n").trim();
  if (!prompt) return Response.json({ jsonrpc: "2.0", id, error: { code: -32602, message: "Provide params.message.parts with a text part" } }, { status: 400 });
  const base = new URL(request.url);
  const registryUrl = new URL("/registry/collections.json", base.origin);
  const upstream = await fetch(registryUrl, { headers: { accept: "application/json" } });
  if (!upstream.ok) return Response.json({ jsonrpc: "2.0", id, error: { code: -32000, message: "Collection registry unavailable" } }, { status: 502 });
  const registry = await upstream.json();
  let list = (registry.collections || []).filter(c => c.status === "deployed" && c.contractAddress);
  const q = prompt.toLowerCase();
  if (/agent.?id|binance/.test(q)) list = list.filter(c => c.agentIdRequired === true);
  const requested = q.match(/\b([a-z0-9]{2,12})\b/i)?.[1];
  if (requested && !/^(find|show|list|live|deployed|collection|collections|agent|binance|nft|mint|with|that|require|requires|id|the|on|bnb|chain|price|prices)$/i.test(requested)) {
    const exact = list.filter(c => String(c.symbol).toLowerCase() === requested.toLowerCase());
    if (exact.length) list = exact;
  }
  const result = {
    name: "Agentic NFT Launchpad",
    chainId: 56,
    network: "BNB Smart Chain Mainnet",
    registry: registryUrl.toString(),
    count: list.length,
    collections: list,
    guidance: "This is registry metadata, not a live chain-state quote. Verify contract state, allocations, price and wallet/Agent-ID quota on BNB Chain before preparing a mint. Never submit a transaction without explicit user authorization."
  };
  const task = {
    id: crypto.randomUUID(),
    contextId: body?.params?.message?.contextId || crypto.randomUUID(),
    status: { state: "completed" },
    artifacts: [{ artifactId: crypto.randomUUID(), parts: [{ kind: "text", text: JSON.stringify(result) }] }]
  };
  return Response.json({ jsonrpc: "2.0", id, result: task }, {
    headers: { "Cache-Control": "no-store", "Access-Control-Allow-Origin": "*" }
  });
}
