#!/usr/bin/env python3
"""
Build a local, offline HTML case report for a set of accounts.

    python3 backend/tools/case_report.py MONK TM7 HesedHernandez phatrestard "El jefferies"
    python3 backend/tools/case_report.py --out ~/Desktop/case MONK TM7

Calls `moderation:caseFile` (internal, read-only) with the deployment's admin
key through `npx convex run`, downloads every photo and file into
<out>/media/ (feed posts expire, the local copy does not), and writes
<out>/index.html. Nothing is uploaded anywhere: the report holds people's
private messages, so it stays on this machine. Default output:
~/Documents/MonkeyHub Cases/<date>-<first username>/.
"""

import argparse
import datetime as dt
import hashlib
import html
import json
import mimetypes
import os
import subprocess
import sys
import urllib.request

BACKEND = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

EXT = {
    "image/png": ".png",
    "image/jpeg": ".jpg",
    "image/gif": ".gif",
    "image/webp": ".webp",
    "image/heic": ".heic",
    "video/mp4": ".mp4",
    "video/quicktime": ".mov",
    "audio/mpeg": ".mp3",
    "audio/mp4": ".m4a",
    "audio/aac": ".aac",
    "audio/wav": ".wav",
    "text/plain": ".txt",
    "application/pdf": ".pdf",
}


def fetch_case(usernames):
    args = json.dumps({"usernames": usernames})
    out = subprocess.run(
        ["npx", "convex", "run", "moderation:caseFile", args],
        cwd=BACKEND,
        capture_output=True,
        text=True,
    )
    if out.returncode != 0:
        sys.exit(out.stderr or out.stdout)
    text = out.stdout
    return json.loads(text[text.index("{"):])


def download(url, media_dir, cache):
    if not url:
        return None
    if url in cache:
        return cache[url]
    try:
        with urllib.request.urlopen(url, timeout=60) as r:
            body = r.read()
            ctype = (r.headers.get("Content-Type") or "").split(";")[0].strip()
    except Exception as e:  # a file deleted since: keep going
        print(f"  ! could not download {url}: {e}", file=sys.stderr)
        cache[url] = None
        return None
    ext = EXT.get(ctype) or mimetypes.guess_extension(ctype) or ".bin"
    name = hashlib.sha1(url.encode()).hexdigest()[:16] + ext
    with open(os.path.join(media_dir, name), "wb") as f:
        f.write(body)
    cache[url] = {"path": "media/" + name, "type": ctype}
    return cache[url]


def when(ms):
    if not ms:
        return ""
    return dt.datetime.fromtimestamp(ms / 1000, dt.timezone.utc).strftime("%a %d %b %H:%M")


def call_line(content):
    try:
        j = json.loads(content[5:])
    except Exception:
        return content
    secs = round((j.get("d") or 0) / 1000)
    dur = f" · {secs // 60}m {secs % 60}s" if secs else ""
    return f"{j.get('t', '')} call {j.get('s', '')}{dur}".strip()


def media_html(m):
    if not m:
        return '<div class="missing">file no longer available</div>'
    p = html.escape(m["path"])
    t = m["type"]
    if t.startswith("image/"):
        return f'<a href="{p}" target="_blank"><img loading="lazy" src="{p}" alt=""></a>'
    if t.startswith("video/"):
        return f'<video controls preload="metadata" src="{p}"></video>'
    if t.startswith("audio/"):
        return f'<audio controls src="{p}"></audio>'
    return f'<a class="file" href="{p}" target="_blank">open file</a>'


def message_html(msg, media):
    who = html.escape(msg["by"])
    typ = msg["type"]
    content = msg.get("content") or ""
    cls = "msg"
    if typ == "system":
        cls += " sys"
        if content.startswith("call:"):
            content = call_line(content)
    body = f'<div class="text">{html.escape(content)}</div>' if content else ""
    if msg.get("fileName"):
        body += f'<div class="fname">{html.escape(msg["fileName"])}</div>'
    if msg.get("url") is not None or typ in ("image", "video", "file", "audio", "videoNote"):
        body += media_html(media)
    return (
        f'<div class="{cls}" data-search="{html.escape((msg["by"] + " " + content).lower())}">'
        f'<div class="meta"><span class="who">@{who}</span>'
        f'<span class="type">{html.escape(typ)}</span><span class="at">{when(msg["at"])}</span></div>'
        f"{body}</div>"
    )


def chat_title(chat):
    members = ", ".join("@" + m for m in chat["members"])
    if chat["isDm"]:
        return f"DM · {members}"
    return f"{html.escape(chat['name'] or 'Group')} · {members}"


def build(case, out_dir):
    media_dir = os.path.join(out_dir, "media")
    os.makedirs(media_dir, exist_ok=True)
    cache = {}

    groups = [c for c in case["chats"] if not c["isDm"]]
    dms = [c for c in case["chats"] if c["isDm"]]

    def chats_html(chats):
        parts = []
        for c in sorted(chats, key=lambda c: -c["messages"][-1]["at"]):
            items = "".join(message_html(m, download(m.get("url"), media_dir, cache)) for m in c["messages"])
            parts.append(
                f'<section class="chat"><h3>{chat_title(c)}'
                f'<span class="count">{len(c["messages"])} messages</span></h3>{items}</section>'
            )
        return "".join(parts) or '<p class="empty">None.</p>'

    posts = []
    for p in case["people"]:
        for post in p["posts"]:
            posts.append((p["username"], post))
    posts.sort(key=lambda x: -x[1]["at"])
    feed = []
    for username, post in posts:
        media = download(post.get("url"), media_dir, cache) if post.get("url") else None
        comments = "".join(
            f'<div class="comment"><span class="who">@{html.escape(c["by"])}</span> '
            f'{html.escape(c["text"])} <span class="at">{when(c["at"])}</span></div>'
            for c in post["comments"]
        )
        expired = post["expiresAt"] and post["expiresAt"] < case["generatedAt"]
        feed.append(
            f'<div class="post" data-search="{html.escape((username + " " + post["caption"]).lower())}">'
            f'<div class="meta"><span class="who">@{html.escape(username)}</span>'
            f'<span class="at">{when(post["at"])}</span>'
            f'{"<span class=type>expired</span>" if expired else ""}</div>'
            f'{media_html(media) if post.get("url") else ""}'
            f'<div class="text">{html.escape(post["caption"])}</div>{comments}</div>'
        )

    people = []
    for p in case["people"]:
        av = download(p.get("avatarUrl"), media_dir, cache)
        avatar = f'<img class="avatar" src="{html.escape(av["path"])}" alt="">' if av else '<div class="avatar none"></div>'
        devices = "".join(
            f"<li>{html.escape(d['name'] or '?')} · {html.escape(d['platform'])} · {html.escape(d['locale'])}"
            f" · UTC{'+' if (d['tzOffsetMinutes'] or 0) >= 0 else ''}{(d['tzOffsetMinutes'] or 0) / 60:g}"
            f" · last seen {when(d['lastSeenAt'])}</li>"
            for d in p["devices"]
        )
        people.append(
            f'<div class="person">{avatar}<div><h3>@{html.escape(p["username"])}</h3>'
            f'<div class="sub">{html.escape(p["name"])} · joined {when(p["createdAt"])}'
            f' · {len(p["posts"])} feed posts</div><ul>{devices}</ul></div></div>'
        )

    names = ", ".join("@" + p["username"] for p in case["people"])
    page = TEMPLATE.format(
        title=html.escape(names),
        generated=when(case["generatedAt"]) + " UTC",
        n_groups=len(groups),
        n_dms=len(dms),
        n_posts=len(posts),
        groups=chats_html(groups),
        dms=chats_html(dms),
        feed="".join(feed) or '<p class="empty">None.</p>',
        people="".join(people),
    )
    with open(os.path.join(out_dir, "index.html"), "w", encoding="utf-8") as f:
        f.write(page)
    return os.path.join(out_dir, "index.html")


TEMPLATE = """<!doctype html>
<html lang="en"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Case report</title>
<style>
:root {{ --bg:#f6f6f4; --card:#fff; --ink:#1d1d1f; --muted:#6e6e73; --line:#e3e3e0; --accent:#c2410c; --sys:#fff7ed; }}
@media (prefers-color-scheme: dark) {{ :root {{ --bg:#111113; --card:#1c1c1f; --ink:#f2f2f2; --muted:#9a9aa0; --line:#2c2c30; --accent:#fb923c; --sys:#2a1d12; }} }}
* {{ box-sizing:border-box; }}
body {{ margin:0; background:var(--bg); color:var(--ink); font:15px/1.45 -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif; }}
header {{ position:sticky; top:0; z-index:2; background:var(--bg); border-bottom:1px solid var(--line); padding:14px 16px 0; }}
h1 {{ font-size:17px; margin:0 0 2px; }}
.gen {{ color:var(--muted); font-size:12px; margin-bottom:10px; }}
nav {{ display:flex; gap:4px; flex-wrap:wrap; }}
nav button {{ border:0; background:none; color:var(--muted); font:inherit; padding:8px 12px; border-bottom:2px solid transparent; cursor:pointer; }}
nav button.on {{ color:var(--ink); border-color:var(--accent); font-weight:600; }}
input[type=search] {{ width:100%; margin:10px 0 12px; padding:8px 10px; border:1px solid var(--line); border-radius:8px; background:var(--card); color:var(--ink); font:inherit; }}
main {{ max-width:860px; margin:0 auto; padding:16px; }}
.tab {{ display:none; }} .tab.on {{ display:block; }}
.chat, .person, .post {{ background:var(--card); border:1px solid var(--line); border-radius:12px; margin-bottom:16px; }}
.chat h3 {{ margin:0; padding:12px 14px; font-size:15px; border-bottom:1px solid var(--line); display:flex; justify-content:space-between; gap:12px; }}
.count {{ color:var(--muted); font-weight:400; font-size:13px; white-space:nowrap; }}
.msg {{ padding:8px 14px; border-bottom:1px solid var(--line); }}
.msg:last-child {{ border-bottom:0; }}
.msg.sys {{ background:var(--sys); }}
.meta {{ display:flex; gap:10px; align-items:baseline; font-size:12.5px; color:var(--muted); }}
.who {{ color:var(--accent); font-weight:600; }}
.type {{ border:1px solid var(--line); border-radius:6px; padding:0 6px; }}
.at {{ margin-left:auto; white-space:nowrap; }}
.text {{ white-space:pre-wrap; word-break:break-word; margin-top:2px; }}
.fname {{ color:var(--muted); font-size:13px; }}
img, video {{ display:block; max-width:min(100%, 360px); max-height:360px; border-radius:8px; margin-top:6px; }}
.post {{ padding:12px 14px; }}
.comment {{ font-size:14px; margin-top:6px; padding-top:6px; border-top:1px solid var(--line); }}
.person {{ display:flex; gap:14px; padding:14px; }}
.person h3 {{ margin:0; font-size:16px; }}
.person ul {{ margin:6px 0 0; padding-left:18px; font-size:13px; color:var(--muted); }}
.sub {{ color:var(--muted); font-size:13px; }}
.avatar {{ width:56px; height:56px; border-radius:50%; object-fit:cover; margin:0; flex:none; }}
.avatar.none {{ background:var(--line); }}
.missing, .empty {{ color:var(--muted); font-style:italic; }}
.hide {{ display:none !important; }}
</style></head><body>
<header>
<h1>{title}</h1>
<div class="gen">Generated {generated}. Private: do not share or upload.</div>
<nav>
<button data-tab="groups" class="on">Group chats ({n_groups})</button>
<button data-tab="dms">DMs ({n_dms})</button>
<button data-tab="feed">Feed ({n_posts})</button>
<button data-tab="people">People</button>
</nav>
</header>
<main>
<input type="search" id="q" placeholder="Search messages, captions, usernames">
<div class="tab on" id="groups">{groups}</div>
<div class="tab" id="dms">{dms}</div>
<div class="tab" id="feed">{feed}</div>
<div class="tab" id="people">{people}</div>
</main>
<script>
document.querySelectorAll('nav button').forEach(b => b.onclick = () => {{
  document.querySelectorAll('nav button, .tab').forEach(e => e.classList.remove('on'));
  b.classList.add('on'); document.getElementById(b.dataset.tab).classList.add('on');
}});
document.getElementById('q').oninput = e => {{
  const q = e.target.value.trim().toLowerCase();
  document.querySelectorAll('[data-search]').forEach(el =>
    el.classList.toggle('hide', q !== '' && !el.dataset.search.includes(q)));
}};
</script>
</body></html>
"""


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("usernames", nargs="+")
    ap.add_argument("--out")
    a = ap.parse_args()
    today = dt.date.today().isoformat()
    out = a.out or os.path.expanduser(
        f"~/Documents/MonkeyHub Cases/{today}-{a.usernames[0].replace(' ', '_')}"
    )
    out = os.path.expanduser(out)
    os.makedirs(out, exist_ok=True)
    print("Fetching case file…")
    case = fetch_case(a.usernames)
    print(f"{len(case['people'])} people, {len(case['chats'])} chats. Downloading media…")
    path = build(case, out)
    print(path)


if __name__ == "__main__":
    main()
