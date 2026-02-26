#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Parses a WoW addon .toc file and extracts metadata.

.DESCRIPTION
    Reads .toc file and extracts:
    - Title
    - Version
    - Author
    - Notes
    - Interface (version)
    
    Returns PSCustomObject with metadata fields.

.PARAMETER TocPath
    Full path to .toc file

.OUTPUTS
    PSCustomObject - Addon metadata

.EXAMPLE
    $metadata = & ".\Get-TocMetadata.ps1" -TocPath "C:\...\Interface\AddOns\DBM-Core\DBM-Core.toc"
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$TocPath
)

$ErrorActionPreference = 'Stop'

try {
    if (-not (Test-Path $TocPath)) {
        throw "TOC file not found: $TocPath"
    }
    
    $metadata = @{
        title     = $null
        version   = $null
        author    = $null
        notes     = $null
        interface = $null
    }
    
    # Read .toc file
    $content = Get-Content -Path $TocPath -Encoding UTF8 -ErrorAction Stop
    
    foreach ($line in $content) {
        # Skip empty lines and non-metadata lines
        if ([string]::IsNullOrWhiteSpace($line) -or -not $line.StartsWith('##')) {
            continue
        }
        
        # Parse metadata line: ## Key: Value
        if ($line -match '##\s*([^:]+):\s*(.+)') {
            $key = $Matches[1].Trim()
            $value = $Matches[2].Trim()
            
            switch ($key) {
                'Title' { $metadata.title = $value }
                'Version' { $metadata.version = $value }
                'Author' { $metadata.author = $value }
                'Notes' { $metadata.notes = $value }
                'Interface' { $metadata.interface = $value }
            }
        }
    }
    
    return [PSCustomObject]$metadata
}
catch {
    Write-Error "Failed to parse TOC file: $TocPath - $($_.Exception.Message)"
    throw
}
