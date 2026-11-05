/**
 * Cloudflare Worker (100% Free Tier - Stateless)
 * 1. API: /api/quote-and-verify (GET / POST)
 * 2. Keep-Alive Cron Trigger: '0 0 */3 * *' (Every 3 days to keep Supabase awake)
 */

// Curated motivational quotes regarding discipline and daily habits
const MOTIVATIONAL_QUOTES = [
  {
    quote: "Kỷ luật là cầu nối giữa mục tiêu và thành tựu.",
    author: "Jim Rohn",
    enQuote: "Discipline is the bridge between goals and accomplishment."
  },
  {
    quote: "Chúng ta là những gì chúng ta lặp lại nhiều lần. Sự xuất sắc không phải là hành động, mà là thói quen.",
    author: "Aristotle",
    enQuote: "We are what we repeatedly do. Excellence, then, is not an act, but a habit."
  },
  {
    quote: "Mỗi ngày tiến bộ 1% sẽ tạo ra thay đổi khổng lồ sau một năm.",
    author: "James Clear (Atomic Habits)",
    enQuote: "1% better every day compounds into remarkable results over a year."
  },
  {
    quote: "Động lực giúp bạn bắt đầu. Kỷ luật giúp bạn tiếp tục.",
    author: "Jim Ryun",
    enQuote: "Motivation is what gets you started. Habit is what keeps you going."
  },
  {
    quote: "Chiến thắng vĩ đại nhất là chiến thắng chính bản thân mình.",
    author: "Plato",
    enQuote: "The first and greatest victory is to conquer oneself."
  },
  {
    quote: "Đừng đếm ngày, hãy làm cho từng ngày có giá trị.",
    author: "Muhammad Ali",
    enQuote: "Don't count the days, make the days count."
  },
  {
    quote: "Thành công không đến từ những gì bạn thỉnh thoảng làm, mà đến từ những gì bạn kiên trì làm mỗi ngày.",
    author: "Marie Forleo",
    enQuote: "Success doesn't come from what you do occasionally, it comes from what you do consistently."
  }
];

// Helper: Calculate streak from sorted dates array (YYYY-MM-DD)
function calculateVerifiedStreak(completedDates = []) {
  if (!completedDates || completedDates.length === 0) return 0;

  // Normalize unique date strings in descending order
  const uniqueDates = Array.from(new Set(completedDates)).sort().reverse();
  
  const today = new Date();
  const todayStr = today.toISOString().split("T")[0];
  
  const yesterday = new Date(today);
  yesterday.setDate(today.getDate() - 1);
  const yesterdayStr = yesterday.toISOString().split("T")[0];

  // If latest completion is neither today nor yesterday, streak is broken
  const latest = uniqueDates[0];
  if (latest !== todayStr && latest !== yesterdayStr) {
    return 0;
  }

  let streak = 0;
  let cursor = new Date(latest);

  for (const dateStr of uniqueDates) {
    const currentExpect = cursor.toISOString().split("T")[0];
    if (dateStr === currentExpect) {
      streak++;
      cursor.setDate(cursor.getDate() - 1);
    } else {
      break;
    }
  }

  return streak;
}

// CORS headers for mobile app requests
const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "GET, POST, OPTIONS",
  "Access-Control-Allow-Headers": "Content-Type, Authorization",
  "Content-Type": "application/json; charset=utf-8"
};

export default {
  /**
   * Handle incoming HTTP requests
   */
  async fetch(request, env, ctx) {
    const url = new URL(request.url);

    // Handle CORS preflight
    if (request.method === "OPTIONS") {
      return new Response(null, { status: 204, headers: corsHeaders });
    }

    // Healthcheck endpoint
    if (url.pathname === "/" || url.pathname === "/health") {
      return new Response(
        JSON.stringify({ status: "ok", service: "habit-tracker-edge-worker" }),
        { status: 200, headers: corsHeaders }
      );
    }

    // Main API Route: /api/quote-and-verify
    if (url.pathname === "/api/quote-and-verify") {
      // Pick quote of the day based on day-of-year
      const now = new Date();
      const startOfYear = new Date(now.getFullYear(), 0, 0);
      const diff = now - startOfYear;
      const oneDay = 1000 * 60 * 60 * 24;
      const dayOfYear = Math.floor(diff / oneDay);
      const dailyQuote = MOTIVATIONAL_QUOTES[dayOfYear % MOTIVATIONAL_QUOTES.length];

      if (request.method === "GET") {
        return new Response(
          JSON.stringify({
            success: true,
            data: {
              quote: dailyQuote,
              date: now.toISOString().split("T")[0]
            }
          }),
          { status: 200, headers: corsHeaders }
        );
      }

      if (request.method === "POST") {
        try {
          const body = await request.json();
          const { habitId, completedDates = [] } = body;
          const verifiedStreak = calculateVerifiedStreak(completedDates);

          return new Response(
            JSON.stringify({
              success: true,
              data: {
                habitId,
                quote: dailyQuote,
                verifiedStreak,
                totalRecordedCompletions: completedDates.length,
                verifiedAt: now.toISOString()
              }
            }),
            { status: 200, headers: corsHeaders }
          );
        } catch (err) {
          return new Response(
            JSON.stringify({ success: false, error: "Invalid JSON body" }),
            { status: 400, headers: corsHeaders }
          );
        }
      }
    }

    return new Response(
      JSON.stringify({ error: "Endpoint not found" }),
      { status: 404, headers: corsHeaders }
    );
  },

  /**
   * Cron Trigger Scheduled Event
   * Runs every 3 days (0 0 * / 3 * *) to ping Supabase REST API
   * Prevents free-tier project from pausing after 7 days of inactivity!
   */
  async scheduled(event, env, ctx) {
    console.log(`[Keep-Alive Cron] Triggered at ${new Date().toISOString()}`);

    const supabaseUrl = env.SUPABASE_URL;
    const supabaseAnonKey = env.SUPABASE_ANON_KEY;

    if (!supabaseUrl || !supabaseAnonKey) {
      console.warn("[Keep-Alive Cron] Missing SUPABASE_URL or SUPABASE_ANON_KEY in environment variables.");
      return;
    }

    try {
      // Simple lightweight query to PostgreSQL via PostgREST
      const pingUrl = `${supabaseUrl}/rest/v1/habits?select=id&limit=1`;
      const response = await fetch(pingUrl, {
        method: "GET",
        headers: {
          "apikey": supabaseAnonKey,
          "Authorization": `Bearer ${supabaseAnonKey}`,
          "Range": "0-0"
        }
      });

      console.log(`[Keep-Alive Cron] Supabase Ping Status: ${response.status} ${response.statusText}`);
    } catch (error) {
      console.error("[Keep-Alive Cron] Failed to ping Supabase:", error);
    }
  }
};

