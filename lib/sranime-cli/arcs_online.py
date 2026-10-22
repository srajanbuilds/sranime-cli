#!/usr/bin/env python3
"""
sranime-cli Online Story Arc Fetcher Engine
Fetches canonical story arcs, seasons, and episode ranges for ANY anime
via Wikipedia MediaWiki API and AniList GraphQL API, with local TSV caching.
"""

import sys
import os
import json
import urllib.request
import urllib.parse
import re
import html

def slugify(text):
    s = re.sub(r'[^a-zA-Z0-9]+', '-', text).strip('-').lower()
    return s

def clean_text(text):
    text = re.sub(r'&#91;.*?&#93;', '', text)
    text = re.sub(r'\[.*?\]', '', text)
    text = re.sub(r'<[^>]+>', '', text)
    return html.unescape(text).strip()

def fetch_from_wikipedia(title):
    candidates = [
        f"List of {title} episodes",
        f"List of {title} (TV series) episodes",
        f"{title} (TV series)",
        f"{title} (anime)"
    ]
    found_page = None
    for cand in candidates:
        search_url = f"https://en.wikipedia.org/w/api.php?action=opensearch&search={urllib.parse.quote(cand)}&limit=3&format=json"
        req = urllib.request.Request(search_url, headers={'User-Agent': 'sranime-cli/9.0 (https://github.com/srajanbuilds/sranime-cli)'})
        try:
            with urllib.request.urlopen(req, timeout=5) as resp:
                data = json.loads(resp.read().decode('utf-8'))
                if len(data) > 1 and data[1]:
                    for r in data[1]:
                        if "episodes" in r.lower():
                            found_page = r
                            break
                    if found_page:
                        break
                    if not found_page and data[1]:
                        found_page = data[1][0]
                        break
        except Exception:
            continue

    if not found_page:
        return []

    parse_url = f"https://en.wikipedia.org/w/api.php?action=parse&page={urllib.parse.quote(found_page)}&prop=sections|text&format=json"
    req = urllib.request.Request(parse_url, headers={'User-Agent': 'sranime-cli/9.0'})
    try:
        with urllib.request.urlopen(req, timeout=6) as resp:
            data = json.loads(resp.read().decode('utf-8'))
            parse = data.get('parse', {})
            sections = parse.get('sections', [])
            html_text = parse.get('text', {}).get('*', '')
    except Exception:
        return []

    arcs = []

    # Strategy 1: Wikitables in Series Overview
    tables = re.findall(r'<table class="[^"]*wikitable[^"]*"[^>]*>(.*?)</table>', html_text, re.DOTALL)
    current_ep = 1
    seen_seasons = set()
    for table in tables:
        rows = re.findall(r'<tr[^>]*>(.*?)</tr>', table, re.DOTALL)
        for row in rows[1:]:
            cells = re.findall(r'<t[hd][^>]*>(.*?)</t[hd]>', row, re.DOTALL)
            clean_cells = [clean_text(c) for c in cells]
            clean_cells = [c for c in clean_cells if c]
            if len(clean_cells) >= 2:
                name = None
                count = None
                for i, c in enumerate(clean_cells):
                    if re.match(r'^\d+$', c) and count is None and i > 0:
                        count = int(c)
                        name = clean_cells[i-1]
                
                if count and count > 0 and count < 1500 and name:
                    if name.lower() in ['season', 'series', 'total', 'part', 'episodes', 'tba']:
                        continue
                    if re.match(r'^\d+$', name):
                        name = f"Season {name}"
                    if name in seen_seasons:
                        break
                    seen_seasons.add(name)
                    
                    start = current_ep
                    end = current_ep + count - 1
                    current_ep = end + 1
                    slug = slugify(name)
                    arcs.append({
                        'slug': slug or f"arc-{len(arcs)+1}",
                        'range': f"{start}-{end}",
                        'name': name,
                        'count': str(count),
                        'synopsis': f"{name} of {title} (Episodes {start}-{end})."
                    })
        if arcs:
            break

    # Strategy 2: If table strategy gave < 2 arcs, check section headers
    if len(arcs) < 2:
        ep_secs = [s for s in sections if s.get('level') in ['2', '3'] and any(k in s.get('line', '').lower() for k in ['season', 'arc', 'saga', 'part'])]
        current_ep = 1
        for s in ep_secs:
            raw_title = clean_text(s.get('line', ''))
            m = re.search(r'\(?(?:episodes?\s*)?(\d+)[–\-](\d+)\)?', raw_title, re.IGNORECASE)
            if m:
                start = int(m.group(1))
                end = int(m.group(2))
                count = end - start + 1
                name = re.sub(r'\(?(?:episodes?\s*)?\d+[–\-]\d+\)?', '', raw_title).strip()
            else:
                count = 12
                start = current_ep
                end = current_ep + count - 1
                current_ep = end + 1
                name = raw_title
            
            if name:
                arcs.append({
                    'slug': slugify(name),
                    'range': f"{start}-{end}",
                    'name': name,
                    'count': str(count),
                    'synopsis': f"{name} of {title} (Episodes {start}-{end})."
                })

    return arcs

def fetch_from_anilist(title):
    graphql_query = """query ($search: String) {
  Media (search: $search, type: ANIME) {
    id
    title { english romaji }
    episodes
    description(asHtml: false)
    relations {
      edges {
        relationType
        node {
          title { english romaji }
          episodes
        }
      }
    }
  }
}"""
    req_data = json.dumps({'query': graphql_query, 'variables': {'search': title}}).encode('utf-8')
    req = urllib.request.Request('https://graphql.anilist.co', data=req_data, headers={
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'User-Agent': 'sranime-cli/9.0'
    })
    try:
        with urllib.request.urlopen(req, timeout=5) as resp:
            data = json.loads(resp.read().decode('utf-8'))
            media = data.get('data', {}).get('Media')
            if not media:
                return []
            
            main_title = media.get('title', {}).get('english') or media.get('title', {}).get('romaji') or title
            eps = media.get('episodes') or 12
            desc = (media.get('description') or f"{main_title} storyline.").replace('\n', ' ')[:100] + "..."

            arcs = []
            arcs.append({
                'slug': 'season-1',
                'range': f"1-{eps}",
                'name': f"{main_title} (Season 1)",
                'count': str(eps),
                'synopsis': desc
            })

            relations = media.get('relations', {}).get('edges', [])
            current_ep = eps + 1
            for edge in relations:
                if edge.get('relationType') == 'SEQUEL':
                    node = edge.get('node', {})
                    sub_title = node.get('title', {}).get('english') or node.get('title', {}).get('romaji')
                    sub_eps = node.get('episodes') or 12
                    if sub_title and sub_eps > 0:
                        start = current_ep
                        end = current_ep + sub_eps - 1
                        current_ep = end + 1
                        arcs.append({
                            'slug': slugify(sub_title),
                            'range': f"{start}-{end}",
                            'name': sub_title,
                            'count': str(sub_eps),
                            'synopsis': f"{sub_title} (Episodes {start}-{end})."
                        })
            return arcs
    except Exception:
        return []

def get_arcs(title, cache_dir=None):
    slug = slugify(title)
    if cache_dir:
        os.makedirs(cache_dir, exist_ok=True)
        cache_path = os.path.join(cache_dir, f"{slug}.tsv")
        if os.path.isfile(cache_path):
            with open(cache_path, 'r', encoding='utf-8') as f:
                lines = [line.strip().split('	') for line in f if line.strip()]
                parsed = [{'slug': p[0], 'range': p[1], 'name': p[2], 'count': p[3], 'synopsis': p[4] if len(p)>4 else ''} for p in lines if len(p)>=4]
                if parsed:
                    return parsed

    # 1. Fetch from Wikipedia
    arcs = fetch_from_wikipedia(title)
    # 2. Fallback to AniList
    if len(arcs) < 2:
        anilist_arcs = fetch_from_anilist(title)
        if len(anilist_arcs) > len(arcs):
            arcs = anilist_arcs

    # 3. Cache locally
    if arcs and cache_dir:
        cache_path = os.path.join(cache_dir, f"{slug}.tsv")
        with open(cache_path, 'w', encoding='utf-8') as f:
            for a in arcs:
                f.write(f"{a['slug']}	{a['range']}	{a['name']}	{a['count']}	{a['synopsis']}\n")

    return arcs

if __name__ == '__main__':
    if len(sys.argv) < 2:
        print("Usage: arcs_online.py <title> [cache_dir]")
        sys.exit(1)
    
    anime_title = sys.argv[1]
    cdir = sys.argv[2] if len(sys.argv) > 2 else os.path.expanduser("~/.cache/sranime-cli/arcs")
    results = get_arcs(anime_title, cdir)
    for r in results:
        print(f"{r['slug']}	{r['range']}	{r['name']}	{r['count']}	{r['synopsis']}")
