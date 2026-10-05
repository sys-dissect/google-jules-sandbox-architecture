# Persistence Test Markers

To verify environment persistence between tasks, marker files containing the current date-time and the task ID (`14165408129265143467`) have been written to the following locations:

1. **Repository Working Directory:** `/app/marker.txt`
2. **Temporary Directory:** `/tmp/marker.txt`
3. **Home Directory:** `/home/jules/marker.txt`

## Persistence Check Results

A subsequent check revealed the following marker persistence:

*   **Repository Working Directory:** `/app/marker.txt` survived (contents: `Mon Oct 5 07:16:56 UTC 2026`, ID: `14165408129265143467`). Note: this was committed to git, so its presence is expected.
*   **Temporary Directory:** `/tmp/marker.txt` survived (contents: `Mon Oct  5 07:16:43 UTC 2026`, ID: `14165408129265143467`).
*   **Home Directory:** `/home/jules/marker.txt` survived (contents: `Mon Oct  5 07:16:43 UTC 2026`, ID: `14165408129265143467`). The current home directory (`/home/jules`) matches the path recorded in the initial setup.