# Patreon Video Downloader

Download Patreon videos that use SproutVideo / vids.io embedding.

## How It Works

1. Tries `--video-password` via yt-dlp (if password is provided)
2. If that fails, extracts the SproutVideo embed URL from Patreon's API and downloads via the direct link (bypasses password for most videos)
3. Uses `--impersonate chrome` to bypass Cloudflare TLS fingerprinting

## Dependencies

- [yt-dlp](https://github.com/yt-dlp/yt-dlp)
- [curl_cffi](https://github.com/lexiforest/curl_cffi) (`pip install curl_cffi`)
- Python 3
- Chrome browser (for cookies)

## Setup

```bash
# Clone
git clone https://github.com/jokerlin/patreon-downloader.git
cd patreon-downloader

# Set password (optional, rotates monthly)
cp .patreon-password.example .patreon-password
# Edit .patreon-password with the current month's password
```

## Usage

```bash
# Single video
./download-patreon.sh -o videos/2025-04 "https://www.patreon.com/posts/example-123456"

# Batch download from URL list
./download-patreon.sh -f urls/2025-04.txt -o videos/2025-04

# With explicit password
./download-patreon.sh -p mypassword -o videos/2025-04 "https://www.patreon.com/posts/example-123456"
```

## Project Structure

```
.
├── download-patreon.sh          # Download script
├── .patreon-password            # Monthly password (git ignored)
├── .patreon-password.example    # Password file template
├── urls/                        # URL lists per batch (git ignored)
│   └── example.txt              # Example URL list
└── videos/                      # Downloaded videos (git ignored)
    └── YYYY-MM-DD/              # Organized by download date
```

## Password Priority

`-p` flag > `.patreon-password` file > no password (SproutVideo direct link)

## Tips

- Already downloaded videos are automatically skipped
- If a download fails with timeout, retry individually -- batch downloads can trigger rate limiting
- Videos returning 403 on the SproutVideo direct link require the correct monthly password
