# ===== config =====
$STORAGE = "pharma959094010"
$RG      = "web-rg"
$AppsDir = Resolve-Path .\apps
$RootIndex = Resolve-Path .\index.html      # your front page
$ExtraRootFiles = @(".\pipelinedesign.html") # any other root files to upload

# ===== connect =====
$ctx = New-AzStorageContext -StorageAccountName $STORAGE -UseConnectedAccount

# 1) ensure static website points to index.html
Enable-AzStorageStaticWebsite -Context $ctx -IndexDocument 'index.html' -ErrorDocument404Path '404.html' | Out-Null

# 2) upload root front page
Set-AzStorageBlobContent -Context $ctx -Container '$web' -File $RootIndex -Blob 'index.html' -Force | Out-Null

#    optional extra root files
foreach ($f in $ExtraRootFiles) {
  if (Test-Path $f) {
    $file = Resolve-Path $f
    Set-AzStorageBlobContent -Context $ctx -Container '$web' -File $file -Blob ([IO.Path]::GetFileName($file)) -Force | Out-Null
  }
}

# 3) upload the apps folder (preserve subfolders)
Get-ChildItem $AppsDir -Recurse -File | ForEach-Object {
  $rel = $_.FullName.Substring($AppsDir.Path.Length + 1).Replace('\','/')
  Set-AzStorageBlobContent -Context $ctx -Container '$web' -File $_.FullName -Blob ("apps/" + $rel) -Force | Out-Null
}

# 4) fix MIME types (so the browser renders, not downloads)
$mime = @{
  ".html"="text/html"; ".css"="text/css"; ".js"="application/javascript";
  ".json"="application/json"; ".svg"="image/svg+xml"; ".png"="image/png";
  ".jpg"="image/jpeg"; ".jpeg"="image/jpeg"; ".gif"="image/gif";
  ".webp"="image/webp"; ".ico"="image/x-icon"; ".xml"="application/xml";
  ".txt"="text/plain"
}
Get-AzStorageBlob -Container '$web' -Context $ctx -Prefix '' | ForEach-Object {
  $ext = [IO.Path]::GetExtension($_.Name).ToLower()
  if ($mime.ContainsKey($ext)) {
    $desired = $mime[$ext]
    if ($_.ICloudBlob.Properties.ContentType -ne $desired) {
      $_.ICloudBlob.Properties.ContentType = $desired
      # optional: make HTML always revalidate so updates show immediately
      if ($ext -eq ".html") { $_.ICloudBlob.Properties.CacheControl = "no-cache" }
      $_.ICloudBlob.SetProperties()
      "{0} -> {1}" -f $_.Name, $desired
    }
  }
}

# 5) print URLs to test
$base = "https://$STORAGE.z1.web.core.windows.net"
"Front page: $base/"
"TamGen:     $base/apps/TamGen/"
"EvoDiff:    $base/apps/EvoDiff/"
"nvidiaNIM:  $base/apps/nvidiaNIM/"
"RetroChim.: $base/apps/RetroChimera/"
"BioEmu:     $base/apps/BioEmu/"
