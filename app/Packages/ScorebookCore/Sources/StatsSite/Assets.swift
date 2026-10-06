// The stats website's look and its one bit of behavior, written out beside the pages.

/// The style sheet: an old sports page, newsprint in light mode and dark in dark mode,
/// readable on a phone.
let style = """
:root {
  --paper: #f6f1e4; --ink: #1d1b16; --faint: #6d665a; --rule: #cfc5ad;
  --accent: #7a1f1f; --win: #2d5e2e; --loss: #8a2b2b; --stripe: #efe8d6;
}
@media (prefers-color-scheme: dark) {
  :root {
    --paper: #17150f; --ink: #ece5d3; --faint: #a39b8a; --rule: #3b362b;
    --accent: #e08a7a; --win: #8fc78f; --loss: #e59a9a; --stripe: #1f1c15;
  }
}
* { box-sizing: border-box; }
html { -webkit-text-size-adjust: 100%; }
body {
  margin: 0; background: var(--paper); color: var(--ink);
  font: 17px/1.45 Georgia, "Times New Roman", serif;
}
main { max-width: 960px; margin: 0 auto; padding: 0 16px 24px; }
a { color: inherit; text-decoration-color: var(--rule); text-underline-offset: 3px; }
a:hover { color: var(--accent); }
.masthead {
  border-bottom: 3px double var(--ink); text-align: center; padding: 14px 16px 10px;
  font-weight: bold; letter-spacing: .12em; text-transform: uppercase; font-size: 15px;
}
.masthead a { text-decoration: none; }
h1 { font-size: 30px; line-height: 1.15; margin: 22px 0 4px; }
h1 .num { color: var(--faint); font-weight: normal; }
h2 {
  font-size: 14px; letter-spacing: .1em; text-transform: uppercase;
  border-bottom: 1px solid var(--ink); padding-bottom: 3px; margin: 28px 0 8px;
}
h3 { font-size: 15px; margin: 18px 0 6px; color: var(--faint); font-weight: normal; font-style: italic; }
.record { font-size: 22px; margin: 0; font-variant-numeric: tabular-nums; }
.record span { font-size: 15px; color: var(--faint); }
.games { list-style: none; padding: 0; margin: 0; }
.games li { border-bottom: 1px dotted var(--rule); }
.games a { display: flex; gap: 12px; padding: 8px 0; text-decoration: none; align-items: baseline; }
.games .date { color: var(--faint); min-width: 92px; font-size: 15px; }
.games .opp { flex: 1; }
.win { color: var(--win); font-weight: bold; }
.loss { color: var(--loss); font-weight: bold; }
.scroll { overflow-x: auto; -webkit-overflow-scrolling: touch; margin: 0 -16px; padding: 0 16px; }
table {
  border-collapse: collapse; font: 15px/1.3 ui-monospace, Menlo, Consolas, monospace;
  font-variant-numeric: tabular-nums; white-space: nowrap; min-width: 100%;
}
th, td { padding: 6px 8px; text-align: left; }
th { font-weight: bold; border-bottom: 1px solid var(--ink); }
th.n, td.n { text-align: right; }
tbody tr:nth-child(even) { background: var(--stripe); }
tfoot td { border-top: 1px solid var(--ink); font-weight: bold; }
td:first-child, th:first-child {
  position: sticky; left: 0; background: var(--paper);
  font-family: Georgia, "Times New Roman", serif;
}
tbody tr:nth-child(even) td:first-child { background: var(--stripe); }
table.sortable th { cursor: pointer; user-select: none; }
th.sorted::after { content: " ▾"; color: var(--accent); }
th.sorted.up::after { content: " ▴"; }
pre.box {
  font: 14px/1.35 ui-monospace, Menlo, Consolas, monospace; white-space: pre-wrap;
  background: var(--stripe); border: 1px solid var(--rule); padding: 14px; margin: 16px 0;
}
@media (max-width: 480px) { pre.box { font-size: 12.5px; padding: 10px; margin: 16px -8px; } }
.hint { color: var(--faint); font-size: 14px; }
footer { max-width: 960px; margin: 0 auto; padding: 16px; color: var(--faint); font-size: 13px; border-top: 1px solid var(--rule); }
"""

/// Click a column heading to sort by it; click again to flip. Numbers sort highest first,
/// names A to Z.
let sortScript = """
document.querySelectorAll("table.sortable").forEach(function (table) {
  var heads = table.querySelectorAll("thead th");
  heads.forEach(function (th, col) {
    th.addEventListener("click", function () {
      var up = th.classList.contains("sorted") ? !th.classList.contains("up") : col === 0;
      heads.forEach(function (h) { h.classList.remove("sorted", "up"); });
      th.classList.add("sorted");
      if (up) th.classList.add("up");
      var body = table.tBodies[0];
      var rows = Array.prototype.slice.call(body.rows);
      rows.sort(function (a, b) {
        var x = a.cells[col], y = b.cells[col], d;
        if (x.dataset.v !== undefined) d = parseFloat(x.dataset.v) - parseFloat(y.dataset.v);
        else d = x.textContent.localeCompare(y.textContent);
        return up ? d : -d;
      });
      rows.forEach(function (r) { body.appendChild(r); });
    });
  });
});
"""
