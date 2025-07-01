# Release a new version
release VERSION:
    #!/usr/bin/env bash
    set -euo pipefail

    # Validate version format (v followed by semantic version)
    if [[ ! "{{VERSION}}" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        echo "Error: Version must be in format vX.Y.Z (e.g., v1.0.0)"
        exit 1
    fi

    # Update README.md with new version
    sed -i.bak "s|luxass/unicode-releases-action@v[0-9]\+\.[0-9]\+\.[0-9]\+|luxass/unicode-releases-action@{{VERSION}}|g" README.md
    rm README.md.bak

    # Commit the version update
    git add README.md
    git commit -m "chore: bump version to {{VERSION}}"

    # Create and push the tag
    git tag "{{VERSION}}"
    git push origin main
    git push origin "{{VERSION}}"

    echo "Released {{VERSION}} successfully!"
