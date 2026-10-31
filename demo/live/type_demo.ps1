# Types and runs the DevMemory commands for the terminal clip (demo/live/record_live.py terminal).
$env:PYTHONPATH = "C:\Users\thfal\Documents\Personal_Projects\MiskXHumain_Hackathon"
$env:PYTHONIOENCODING = "utf-8"
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
function devmem { python -m devmem.cli @args }
Set-Location "$HOME\devmem-live\blade-swarm"
Clear-Host
$task = "Add an Epic upgrade called Twin Spin: +2 blades for 120 coins. Make sure it shows up with the rarity colors we picked."

function Type-Line([string]$text) {
    Write-Host -NoNewline -ForegroundColor Green "blade-swarm> "
    foreach ($ch in $text.ToCharArray()) { Write-Host -NoNewline $ch; Start-Sleep -Milliseconds 22 }
    Write-Host ""
    Start-Sleep -Milliseconds 400
}

Start-Sleep -Seconds 1
Type-Line "devmem scan"
$t = Measure-Command { devmem scan | Out-Host }
Write-Host -ForegroundColor DarkGray ("  ({0:N0} ms)" -f $t.TotalMilliseconds)
Start-Sleep -Seconds 2
Type-Line "devmem status"
devmem status | Out-Host
Start-Sleep -Seconds 2
Type-Line "devmem pack `"$task`""
$packFile = "$HOME\devmem-live\pack.md"
cmd /c "python -m devmem.cli pack `"$task`" --out `"$packFile`" >NUL 2>NUL"
Get-Content $packFile -Encoding UTF8 | ForEach-Object { Write-Host $_; Start-Sleep -Milliseconds 90 }
$raw = Get-Content $packFile -Raw -Encoding UTF8
$sessions = (Select-String -Path $packFile -Pattern '^- \[session').Count
Write-Host ""
Write-Host -ForegroundColor Cyan ("pack: ~{0:N0} tokens (estimate)  |  {1} past sessions  |  0 LLM tokens used to build it" -f [math]::Floor($raw.Length / 4), $sessions)
Start-Sleep -Seconds 3
Start-Sleep -Seconds 1
New-Item -ItemType File -Force "$HOME\devmem-live\terminal_done.txt" | Out-Null
