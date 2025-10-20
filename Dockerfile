name: "metrics"
description: "Generate metrics"
inputs:
  token:
    description: "GitHub token for metrics"
    required: true

runs:
  using: "composite"
  steps:
    # Node 20 + npm cache
    - uses: actions/setup-node@v4
      with:
        node-version: "20"
        cache: "npm"

    # Install Google Chrome + fonts & runtime libs for Puppeteer
    - name: Install Chrome and fonts
      shell: bash
      run: |
        set -euxo pipefail
        sudo apt-get update
        sudo apt-get install -y wget gnupg ca-certificates lsb-release
        wget -q -O - https://dl-ssl.google.com/linux/linux_signing_key.pub | sudo gpg --dearmor -o /usr/share/keyrings/google-linux.gpg
        echo "deb [arch=amd64 signed-by=/usr/share/keyrings/google-linux.gpg] http://dl.google.com/linux/chrome/deb/ stable main" | \
          sudo tee /etc/apt/sources.list.d/google-chrome.list
        sudo apt-get update
        sudo apt-get install -y \
          google-chrome-stable \
          fonts-ipafont-gothic fonts-wqy-zenhei fonts-thai-tlwg fonts-kacst fonts-freefont-ttf \
          libxss1 libx11-xcb1 libxtst6

    # Deno (you used it in the Dockerfile)
    - uses: denoland/setup-deno@v1
      with:
        deno-version: v1.x

    # Ruby (to run `licensed`), cleaner than apt: ruby/setup-ruby
    - uses: ruby/setup-ruby@v1
      with:
        ruby-version: '3.2'
    - name: Install licensed
      shell: bash
      run: gem install licensed

    # Python3 for node-gyp (if any native deps need it on CI)
    - name: Ensure python3 for node-gyp
      shell: bash
      run: |
        set -eux
        python3 --version || sudo apt-get install -y python3

    # Install node deps + build (same as in Dockerfile)
    - name: Install & build
      shell: bash
      env:
        PUPPETEER_SKIP_CHROMIUM_DOWNLOAD: "true"
        PUPPETEER_BROWSER_PATH: "google-chrome-stable"
      run: |
        npm ci
        npm run build

    # Run your action entrypoint
    - name: Run metrics
      shell: bash
      env:
        METRICS_TOKEN: ${{ inputs.token }}
        PUPPETEER_SKIP_CHROMIUM_DOWNLOAD: "true"
        PUPPETEER_BROWSER_PATH: "google-chrome-stable"
      run: node source/app/action/index.mjs
