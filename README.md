# unicode-releases-action

GitHub Action for fetching the latest Unicode release information, including the current releases list and draft releases.

## Usage

This action fetches Unicode release information including:

- List of all releases
- Latest release version
- Latest draft version (if available)

### Outputs

| Name           | Description                                                   |
| -------------- | ------------------------------------------------------------- |
| all_releases   | JSON array containing all Unicode release versions            |
| latest_release | Latest stable Unicode release version                         |
| current_draft  | Current draft Unicode release version (if available)          |

### Example workflow

```yaml
name: Check Unicode Releases

on:
  schedule:
    - cron: "0 0 * * *" # run daily
  workflow_dispatch: # allow manual triggers

jobs:
  check-releases:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Check Unicode Releases
        uses: luxass/unicode-releases-action@v0.7.3
        id: unicode
      - name: Use Release Information
        run: |
          echo "Latest Release: ${{ steps.unicode.outputs.latest_release }}"
          echo "All Releases: ${{ steps.unicode.outputs.all_releases }}"
          echo "Current Draft: ${{ steps.unicode.outputs.current_draft }}"
```

## License

Licensed under the MIT License. See [LICENSE](LICENSE) for details.
