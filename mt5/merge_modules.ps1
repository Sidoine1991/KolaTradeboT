function Merge-Module {
    param([string]$ModulePath, [hashtable]$Seen)
    
    $name = [System.IO.Path]::GetFileName($ModulePath)
    if($Seen.ContainsKey($name)) { return "" }
    $Seen[$name] = $true
    
    $lines = Get-Content $ModulePath
    $result = [System.Collections.Generic.List[string]]::new()
    
    # Skip #ifndef/#define/#endif guard (first 3 meaningful lines or so)
    $skipGuard = $true
    $guardDone = $false
    foreach($line in $lines) {
        $trimmed = $line.Trim()
        
        # Skip the include guard block
        if($skipGuard) {
            if($trimmed -match '^#ifndef\s+\w+_MQH$') { continue }
            if($trimmed -match '^#define\s+\w+_MQH$') { continue }
            if($trimmed -eq '#endif' -and -not $guardDone) { $skipGuard = $false; continue }
            $skipGuard = $false
        }
        
        # Replace nested module includes with inlined content
        if($trimmed -match '^\s*#include\s+"modules/(.+)"$') {
            $depName = $Matches[1]
            $depPath = "D:\Dev\TradBOT\mt5\modules\$depName"
            if(Test-Path $depPath) {
                $inlined = Merge-Module -ModulePath $depPath -Seen $Seen
                $result.Add("//--- inlined: $depName ---")
                foreach($il in ($inlined -split "`n")) { $result.Add($il) }
            }
            continue
        }
        
        # Keep all other lines
        $result.Add($line)
    }
    
    # Remove trailing #endif (guard closing)
    for($i = $result.Count - 1; $i -ge 0; $i--) {
        if($result[$i].Trim() -eq '#endif') {
            $result.RemoveAt($i)
            break
        }
    }
    
    return ($result -join "`r`n")
}

# Read the main .mq5
$mainLines = Get-Content "D:\Dev\TradBOT\mt5\SMC_Universal.mq5"
$seen = @{}
$output = [System.Collections.Generic.List[string]]::new()

foreach($line in $mainLines) {
    $trimmed = $line.Trim()
    
    # Replace active module includes
    if($trimmed -match '^\s*#include\s+"modules/(.+)"$') {
        $modName = $Matches[1]
        $modPath = "D:\Dev\TradBOT\mt5\modules\$modName"
        if(Test-Path $modPath) {
            $output.Add("//======== INLINED: $modName ========")
            $content = Merge-Module -ModulePath $modPath -Seen $seen
            foreach($cl in ($content -split "`n")) { $output.Add($cl) }
            $output.Add("//======== END: $modName ========")
            $output.Add("")
            Write-Host "Inlined: $modName"
        } else {
            Write-Host "WARNING: $modName not found!"
            $output.Add($line)
        }
        continue
    }
    
    # Keep all other lines (standard includes, code, etc.)
    $output.Add($line)
}

# Write merged file
$output | Set-Content "D:\Dev\TradBOT\mt5\SMC_Universal_merged.mq5" -Encoding UTF8
$totalLines = $output.Count
Write-Host ""
Write-Host "Merged file: $totalLines lines"
Write-Host "Saved to: D:\Dev\TradBOT\mt5\SMC_Universal_merged.mq5"
