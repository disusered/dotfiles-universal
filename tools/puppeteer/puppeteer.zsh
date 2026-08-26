# PuppeteerSharp (.NET) does not read ~/.cache/puppeteer or ~/.cache/ms-playwright.
# BrowserFetcher.GetBrowsersLocation() resolves to AppContext.BaseDirectory and scans
# a Chrome/ subfolder there, which only exists in container images that ran
# `--install-puppeteer-browser` at build time. Natively-run .NET workers therefore
# find no browser at all.
#
# Point it at the system Chromium instead. Arch's chromium tracks the same build
# PuppeteerSharp pins (Chrome.DefaultBuildId), so there is no CDP protocol drift and
# no per-project browser download.
#
# Guarded on -x because a configured-but-missing path makes PuppeteerSharp throw
# FileNotFoundException rather than fall back to discovery — strictly worse than
# leaving the variable unset.
if [[ -x /usr/bin/chromium ]]; then
  export PUPPETEER_EXECUTABLE_PATH=/usr/bin/chromium
fi
