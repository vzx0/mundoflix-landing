# baixar-assets.ps1
# Baixa todas as fotos (Unsplash) e logos (Wikimedia) usadas no index.html para a pasta ./assets
# e reescreve o index.html para usar os arquivos locais. Rode uma vez antes de publicar o site.
#
#   Botão direito > "Executar com PowerShell"  ou, no terminal:
#   powershell -ExecutionPolicy Bypass -File .\baixar-assets.ps1

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$html = Join-Path $root 'index.html'
$dir  = Join-Path $root 'assets'
New-Item -ItemType Directory -Force $dir | Out-Null

$content = [IO.File]::ReadAllText($html, [Text.Encoding]::UTF8)
$ua = 'Mozilla/5.0 (MundoFlix landing page; download de assets para hospedagem local)'
$bases = @{ WC = 'https://commons.wikimedia.org/wiki/Special:FilePath/'; WE = 'https://en.wikipedia.org/wiki/Special:FilePath/' }
$count = 0

function Get-Asset([string]$url, [string]$name) {
  $safe = $name -replace '[\\/:*?"<>|]', '_'
  $dest = Join-Path $dir $safe
  if (-not (Test-Path $dest)) {
    Write-Host "Baixando  $safe"
    Invoke-WebRequest -Uri $url -OutFile $dest -UserAgent $ua -MaximumRedirection 5
    Start-Sleep -Milliseconds 1500   # evita bloqueio por excesso de requisições no Wikimedia
  } else {
    Write-Host "Já existe $safe"
  }
  return "assets/$safe"
}

# 1) Logos declarados no JS como WC+'arquivo.svg' / WE+'arquivo.svg'
$logoMatches = [regex]::Matches($content, "(WC|WE)\+'([^']+)'")
foreach ($m in $logoMatches) {
  $file  = $m.Groups[2].Value
  $url   = $bases[$m.Groups[1].Value] + $file
  $name  = [uri]::UnescapeDataString($file)
  $local = Get-Asset $url $name
  $content = $content.Replace($m.Value, "'$local'")
  $count++
}

# 2) Fotos com URL completa (Unsplash e backdrop do TMDB) no HTML/CSS
$photoMatches = [regex]::Matches($content, 'https://(?:images\.unsplash\.com|media\.themoviedb\.org/t/p/w\d+|(?:en|pt)\.wikipedia\.org/wiki/Special:FilePath|commons\.wikimedia\.org/wiki/Special:FilePath)/([^"''\s)?]+)[^"''\s)]*')
$seen = @{}
foreach ($m in $photoMatches) {
  if ($seen.ContainsKey($m.Value)) { continue }
  $seen[$m.Value] = $true
  $id    = $m.Groups[1].Value
  $name  = [uri]::UnescapeDataString($id); if ($name -notmatch ".(jpg|png|svg|webp)$") { $name += ".jpg" }
  $local = Get-Asset $m.Value $name
  $content = $content.Replace($m.Value, $local)
  $count++
}

# 3) Pôsteres do TMDB declarados no JS como ['Título','hash.jpg','Tipo'] e montados com TM+hash
$tmBase = 'https://media.themoviedb.org/t/p/w342/'
$posterMatches = [regex]::Matches($content, "\['[^']*','([A-Za-z0-9]+\.jpg)','(?:Filme|Série|Anime)'\]")
foreach ($m in $posterMatches) {
  $hash = $m.Groups[1].Value
  Get-Asset ($tmBase + $hash) $hash | Out-Null
  $count++
}
$content = $content.Replace("const TM='$tmBase';", "const TM='assets/';")

[IO.File]::WriteAllText($html, $content, (New-Object Text.UTF8Encoding $false))
Write-Host ""
Write-Host "Pronto: $count arquivos em .\assets e index.html apontando para eles."
