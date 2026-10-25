// Supabase Edge Function: parse-link
// Принимает { url }, возвращает { title, image_url, price, store }.
import { serve } from "https://deno.land/std@0.224.0/http/server.ts";

function domainOf(url) {
  try {
    const host = new URL(url).hostname;
    return host.indexOf("www.") === 0 ? host.slice(4) : host;
  } catch (_) {
    return "";
  }
}

// Достаёт content мета-тега с указанным property/name.
function meta(html, prop) {
  const tags = html.match(/<meta[^>]*>/gi) || [];
  for (const tag of tags) {
    const name = tag.match(/(?:property|name)=["']([^"']+)["']/i);
    if (!name || name[1].toLowerCase() !== prop.toLowerCase()) continue;
    const content = tag.match(/content=["']([^"']*)["']/i);
    return content ? content[1] : null;
  }
  return null;
}

serve(async (req) => {
  const cors = {
    "Access-Control-Allow-Origin": "*",
    "Access-Control-Allow-Headers": "*",
  };
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  let target = "";
  try {
    const body = await req.json();
    target = String(body.url || "");
    const res = await fetch(target, {
      headers: {
        "User-Agent":
          "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0 Safari/537.36",
        "Accept-Language": "ru-RU,ru;q=0.9,en;q=0.8",
      },
      redirect: "follow",
      signal: AbortSignal.timeout(9000),
    });
    const html = await res.text();
    const result = {
      title: meta(html, "og:title") || meta(html, "twitter:title"),
      image_url: meta(html, "og:image") || meta(html, "twitter:image"),
      price: meta(html, "product:price:amount") || meta(html, "og:price:amount"),
      store: domainOf(target),
    };
    return new Response(JSON.stringify(result), {
      headers: { ...cors, "Content-Type": "application/json" },
    });
  } catch (_) {
    // Сайт закрыт от ботов или не отвечает — магазин всё равно подставляем.
    return new Response(
      JSON.stringify({ title: null, image_url: null, price: null, store: domainOf(target) }),
      { headers: { ...cors, "Content-Type": "application/json" } }
    );
  }
});

