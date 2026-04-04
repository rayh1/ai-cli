#!/usr/bin/env -S uv run --python python3
"""Simple web server that lists markdown files and renders them via mindspark.nu viewer."""

import argparse
import base64
import html
import os
import sys
import time
import urllib.parse
import zlib
from http.server import HTTPServer, BaseHTTPRequestHandler
from pathlib import Path


VIEWER_URL = "https://mindspark.nu/markdown_viewer"


def compress_for_viewer(text: str) -> str:
    """Compress text using raw deflate + base64, matching pako.deflateRaw + btoa."""
    compressor = zlib.compressobj(9, zlib.DEFLATED, -15)
    compressed = compressor.compress(text.encode("utf-8"))
    compressed += compressor.flush()
    return base64.b64encode(compressed).decode("ascii")


def format_size(size: int) -> str:
    for unit in ("B", "KB", "MB", "GB"):
        if size < 1024:
            return f"{size:.0f} {unit}" if unit == "B" else f"{size:.1f} {unit}"
        size /= 1024
    return f"{size:.1f} TB"


class MarkdownHandler(BaseHTTPRequestHandler):
    root_dir: Path

    def do_HEAD(self):
        self.do_GET()

    def do_GET(self):
        parsed = urllib.parse.urlparse(self.path)
        path = urllib.parse.unquote(parsed.path)
        query = urllib.parse.parse_qs(parsed.query)

        sort_by = query.get("sort", ["name"])[0]
        sort_order = query.get("order", ["asc"])[0]

        rel_path = path.strip("/")

        # Prevent directory traversal
        try:
            full_path = (self.root_dir / rel_path).resolve()
            if not full_path.is_relative_to(self.root_dir):
                self.send_error(403, "Forbidden")
                return
        except (ValueError, OSError):
            self.send_error(400, "Bad request")
            return

        if full_path.is_dir():
            self._serve_directory(full_path, rel_path, sort_by, sort_order)
        elif full_path.is_file() and full_path.suffix.lower() == ".md":
            self._serve_markdown(full_path)
        else:
            self.send_error(404, "Not found")

    def _serve_directory(self, dir_path: Path, rel_path: str, sort_by: str, sort_order: str):
        dirs, files = [], []
        try:
            for entry in dir_path.iterdir():
                if entry.name.startswith("."):
                    continue
                is_dir = entry.is_dir()
                if not is_dir and not (entry.is_file() and entry.suffix.lower() == ".md"):
                    continue
                stat = entry.stat()
                item = {
                    "name": entry.name,
                    "size": stat.st_size if not is_dir else 0,
                    "mtime": stat.st_mtime,
                }
                (dirs if is_dir else files).append(item)
        except PermissionError:
            self.send_error(403, "Permission denied")
            return

        reverse = sort_order == "desc"
        key_fn = {
            "name": lambda e: e["name"].lower(),
            "modified": lambda e: e["mtime"],
            "size": lambda e: e["size"],
        }.get(sort_by, lambda e: e["name"].lower())
        dirs.sort(key=key_fn, reverse=reverse)
        files.sort(key=key_fn, reverse=reverse)

        base = "/" + rel_path if rel_path else "/"
        if not base.endswith("/"):
            base += "/"

        def sort_url(col):
            new_order = "desc" if sort_by == col and sort_order == "asc" else "asc"
            return f"{base}?sort={col}&order={new_order}"

        def sort_indicator(col):
            if sort_by == col:
                return " \u25b2" if sort_order == "asc" else " \u25bc"
            return ""

        rows = []
        if rel_path:
            parent = str(Path(rel_path).parent)
            parent_href = "/" if parent == "." else "/" + parent + "/"
            rows.append(
                f'<tr><td>\U0001f4c1</td><td><a href="{html.escape(parent_href)}">..</a></td>'
                f"<td></td><td></td></tr>"
            )

        for entry in dirs:
            name = html.escape(entry["name"])
            href = html.escape(base + entry["name"] + "/")
            mtime_str = time.strftime("%Y-%m-%d %H:%M", time.localtime(entry["mtime"]))
            rows.append(
                f'<tr><td>\U0001f4c1</td><td><a href="{href}">{name}</a></td>'
                f"<td>\u2014</td><td>{mtime_str}</td></tr>"
            )

        for entry in files:
            name = html.escape(entry["name"])
            href = html.escape(base + entry["name"])
            mtime_str = time.strftime("%Y-%m-%d %H:%M", time.localtime(entry["mtime"]))
            rows.append(
                f'<tr><td>\U0001f4d3</td><td><a href="{href}">{name}</a></td>'
                f"<td>{format_size(entry['size'])}</td><td>{mtime_str}</td></tr>"
            )

        display_path = "/" + rel_path if rel_path else "/"
        body = DIR_TEMPLATE.format(
            title=html.escape(display_path),
            sort_name_url=sort_url("name"),
            sort_name_ind=sort_indicator("name"),
            sort_size_url=sort_url("size"),
            sort_size_ind=sort_indicator("size"),
            sort_modified_url=sort_url("modified"),
            sort_modified_ind=sort_indicator("modified"),
            rows="\n".join(rows),
        )

        self.send_response(200)
        self.send_header("Content-Type", "text/html; charset=utf-8")
        self.end_headers()
        self.wfile.write(body.encode("utf-8"))

    def _serve_markdown(self, file_path: Path):
        try:
            content = file_path.read_text(encoding="utf-8")
        except (PermissionError, OSError) as e:
            self.send_error(500, str(e))
            return

        encoded = compress_for_viewer(content)
        url = f"{VIEWER_URL}?p={urllib.parse.quote(encoded, safe='')}"

        self.send_response(302)
        self.send_header("Location", url)
        self.end_headers()

    def log_message(self, format, *args):
        print(f"[{time.strftime('%H:%M:%S')}] {args[0]}")


DIR_TEMPLATE = """\
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Markdown Files \u2014 {title}</title>
<style>
  body {{ font-family: system-ui, -apple-system, sans-serif; max-width: 900px;
         margin: 2rem auto; padding: 0 1rem; color: #333; background: #fafafa; }}
  h1 {{ font-size: 1.3rem; border-bottom: 1px solid #ddd; padding-bottom: 0.5rem;
        font-weight: 500; color: #222; }}
  table {{ width: 100%; border-collapse: collapse; }}
  th, td {{ text-align: left; padding: 0.4rem 0.8rem; }}
  th {{ border-bottom: 2px solid #ddd; font-size: 0.85rem; color: #555;
        font-weight: 600; white-space: nowrap; }}
  th a {{ color: inherit; text-decoration: none; }}
  th a:hover {{ text-decoration: underline; }}
  tr:hover {{ background: #eef2f7; }}
  td:first-child {{ width: 1.5rem; text-align: center; }}
  td:nth-child(3), th:nth-child(3) {{ text-align: right; }}
  a {{ color: #0066cc; text-decoration: none; }}
  a:hover {{ text-decoration: underline; }}
  .empty {{ color: #999; font-style: italic; padding: 2rem; text-align: center; }}
</style>
</head>
<body>
<h1>{title}</h1>
<table>
<thead>
<tr>
  <th></th>
  <th><a href="{sort_name_url}">Name{sort_name_ind}</a></th>
  <th><a href="{sort_size_url}">Size{sort_size_ind}</a></th>
  <th><a href="{sort_modified_url}">Modified{sort_modified_ind}</a></th>
</tr>
</thead>
<tbody>
{rows}
</tbody>
</table>
</body>
</html>"""


def main():
    parser = argparse.ArgumentParser(description="Serve and render markdown files")
    parser.add_argument("directory", help="Directory containing markdown files")
    parser.add_argument(
        "-p", "--port", type=int, default=8080, help="Port (default: 8080)"
    )
    args = parser.parse_args()

    root = Path(args.directory).resolve()
    if not root.is_dir():
        print(f"Error: {args.directory} is not a directory", file=sys.stderr)
        sys.exit(1)

    MarkdownHandler.root_dir = root

    server = HTTPServer(("0.0.0.0", args.port), MarkdownHandler)
    print(f"Serving markdown from {root}")
    print(f"Listening on http://0.0.0.0:{args.port}")
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print("\nStopped.")
        server.shutdown()


if __name__ == "__main__":
    main()
