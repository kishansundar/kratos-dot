# ProcessTable

The top processes by CPU (default) or memory: app (grouped processes show ×N and no single pid, "–"), pid, cpu %, memory, across two grid columns. 32px rows (`listRow`) on 1px `line` rules; no zebra, no boxes.

**Consumer provides:** a process list (name, pid, cpu %, rss), refreshed at `refreshSlow`; the sort key.

- Header in `label` `textMuted`; the sorted column in `text` with ▾ / ▴ and `aria-sort`. Click a header to sort; click again to reverse.
- Name in `body`, elided with a tooltip; pid in `mono` `textMuted`; numbers `label`, tabular, right-aligned. Memory in MiB / GiB.
- Show 8 rows; never page. Hover row `surfaceAlt`. Right-click a row: copy pid / terminate (asks first).
