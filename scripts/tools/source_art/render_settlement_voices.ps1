param([string]$DataPath, [string]$OutputDirectory)
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Speech
$reviewData = Get-Content -LiteralPath $DataPath -Encoding UTF8 -Raw | ConvertFrom-Json
[System.IO.Directory]::CreateDirectory($OutputDirectory) | Out-Null
$voice = New-Object System.Speech.Synthesis.SpeechSynthesizer
try {
    $available = @($voice.GetInstalledVoices() | Where-Object { $_.Enabled -and $_.VoiceInfo.Culture.Name -eq 'zh-CN' })
    $selected = $available | Where-Object { $_.VoiceInfo.Name -eq 'Microsoft Kangkang' } | Select-Object -First 1
    if ($null -eq $selected) { $selected = $available | Select-Object -First 1 }
    if ($null -eq $selected) { throw 'No installed Chinese speech voice' }
    $voice.SelectVoice($selected.VoiceInfo.Name)
    $voice.Rate = 0
    $voice.Volume = 90
    foreach ($entry in $reviewData.cases) {
        $target = Join-Path $OutputDirectory ($entry.id + '.wav')
        $voice.SetOutputToWaveFile($target)
        $voice.Speak([string]$entry.speech)
        $voice.SetOutputToNull()
        Write-Output ('VOICE ' + $entry.id + ' | ' + $selected.VoiceInfo.Name)
    }
} finally {
    $voice.Dispose()
}
