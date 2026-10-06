# Reversible cleanup only: native Windows Recycle Bin, no permanent deletion.
$ErrorActionPreference = 'Stop'
$taskWorkspace = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\..\..')).Path
if ($taskWorkspace -ne 'D:\project\useless\resources\infinite-build-dome-survival') { throw 'Unexpected workspace' }
$taskReview = Join-Path $taskWorkspace 'artifacts\previews\range_half_bonus_review'
$taskInstall = Join-Path $taskWorkspace 'artifacts\previews\range_half_bonus_install'
$taskTargets = @(
    (Join-Path $taskReview 'captures'),
    (Join-Path $taskReview 'sample'),
    (Join-Path $taskInstall 'captures'),
    (Join-Path $taskInstall 'control')
)
foreach ($name in @('range_comparison.gif', 'area_comparison.gif', 'combined_comparison.gif', 'range_gif_check.png', 'sample_gpu.json', 'sample_gpu.log')) {
    $taskTargets += Join-Path $taskReview $name
}
$taskTargets = @($taskTargets | Where-Object { Test-Path -LiteralPath $_ })
$taskFiles = @()
foreach ($target in $taskTargets) {
    $absolute = (Resolve-Path -LiteralPath $target).Path
    if (-not ($absolute.StartsWith($taskReview + '\', [StringComparison]::OrdinalIgnoreCase) -or $absolute.StartsWith($taskInstall + '\', [StringComparison]::OrdinalIgnoreCase))) { throw "Out of scope: $absolute" }
    $item = Get-Item -LiteralPath $absolute -Force
    if (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) { throw "Reparse point refused: $absolute" }
    if ($item.PSIsContainer) {
        $descendants = @(Get-ChildItem -LiteralPath $absolute -Recurse -Force)
        if (@($descendants | Where-Object { ($_.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0 }).Count) { throw "Nested reparse point refused: $absolute" }
        $taskFiles += @($descendants | Where-Object { -not $_.PSIsContainer })
    } else {
        $taskFiles += $item
    }
}

# Keep reports, import exclusions, and four representative production frames
# per weapon in memory before recycling their enclosing generated directories.
$retained = @{}
$taskFrames = @{ range = '019'; area = '025'; combined = '032' }
foreach ($captureRoot in @((Join-Path $taskReview 'captures'), (Join-Path $taskInstall 'captures'))) {
    foreach ($file in Get-ChildItem -LiteralPath $captureRoot -Recurse -Force -File) {
        if ($file.Extension -eq '.json' -or $file.Name -eq '.gdignore') { $retained[$file.FullName] = [IO.File]::ReadAllBytes($file.FullName) }
    }
}
foreach ($family in @('range', 'area', 'combined')) {
    foreach ($score in @('000', '050', '100', '200')) {
        $file = Join-Path $taskInstall ('captures\' + $family + '\' + $score + '_' + $taskFrames[$family] + '.png')
        $retained[$file] = [IO.File]::ReadAllBytes($file)
    }
}
$totalBytes = [long]0
foreach ($file in $taskFiles) { $totalBytes += $file.Length }
$restoredBytes = [long]0
foreach ($bytes in $retained.Values) { $restoredBytes += $bytes.Length }

Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
public static class RangePreviewRecycleBin {
    [StructLayout(LayoutKind.Sequential, CharSet=CharSet.Unicode)]
    public struct Operation {
        public IntPtr hwnd;
        public uint function;
        [MarshalAs(UnmanagedType.LPWStr)] public string from;
        [MarshalAs(UnmanagedType.LPWStr)] public string to;
        public ushort flags;
        [MarshalAs(UnmanagedType.Bool)] public bool aborted;
        public IntPtr mappings;
        [MarshalAs(UnmanagedType.LPWStr)] public string title;
    }
    [DllImport("shell32.dll", CharSet=CharSet.Unicode)]
    public static extern int SHFileOperation(ref Operation operation);
    public static void Recycle(string[] paths) {
        var operation = new Operation();
        operation.function = 3;
        operation.from = string.Join("\0", paths) + "\0\0";
        // ALLOWUNDO | SILENT | NOCONFIRMATION | NOERRORUI: reversible and no UI.
        operation.flags = 0x0040 | 0x0004 | 0x0010 | 0x0400;
        int result = SHFileOperation(ref operation);
        if (result != 0 || operation.aborted) throw new Exception("Recycle Bin operation failed: " + result);
    }
}
'@

try {
    [RangePreviewRecycleBin]::Recycle([string[]]$taskTargets)
} finally {
    foreach ($file in $retained.Keys) {
        [IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($file)) | Out-Null
        [IO.File]::WriteAllBytes($file, $retained[$file])
    }
}
$report = @{
    method = 'Windows Recycle Bin (recoverable)'
    recycled_targets = $taskTargets
    files_removed_from_workspace = $taskFiles.Count - $retained.Count
    bytes_removed_from_workspace = $totalBytes - $restoredBytes
    workspace_reduction_mib = [math]::Round(($totalBytes - $restoredBytes) / 1MB, 2)
    retained_production_frames = 12
    retained_review_gifs = 3
}
$report | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath (Join-Path $taskInstall 'cleanup_report.json') -Encoding UTF8
$report | ConvertTo-Json -Depth 4
