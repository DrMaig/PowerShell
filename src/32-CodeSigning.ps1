<#
.SYNOPSIS
    Profile component 32 - Code Signing Guidance
.DESCRIPTION
    Extracted from Microsoft.PowerShell_profile.ps1 region 32 (CODE SIGNING GUIDANCE) for modular dot-sourced loading.
#>

#region 32 - CODE SIGNING GUIDANCE
#==============================================================================
<#
.SYNOPSIS
    Instructions and helper for digitally signing the profile script.
.DESCRIPTION
    Provides a function to sign the profile with a code-signing certificate.
    Signing ensures the script has not been tampered with and is trusted.

    To sign your profile:
    1. Obtain a code-signing certificate (self-signed for local use, or CA-issued):
         New-SelfSignedCertificate -Type CodeSigningCert -Subject "CN=PowerShell Profile" `
             -CertStoreLocation Cert:\CurrentUser\My -NotAfter (Get-Date).AddYears(5)
    2. Trust the certificate:
         $cert = Get-ChildItem Cert:\CurrentUser\My -CodeSigningCert | Where-Object Subject -like '*PowerShell Profile*'
         Export-Certificate -Cert $cert -FilePath "$HOME\ProfileSign.cer"
         Import-Certificate -FilePath "$HOME\ProfileSign.cer" -CertStoreLocation Cert:\CurrentUser\TrustedPublisher
    3. Sign the profile:
         Sign-ProfileScript
    4. Set execution policy to AllSigned or RemoteSigned.
#>

function Sign-ProfileScript {
    <#
    .SYNOPSIS
        Signs the profile script with a code-signing certificate.
    .PARAMETER CertSubject
        Subject name filter for the certificate (default: '*PowerShell*').
    .PARAMETER TimestampServer
        URL of the timestamp server.
    .EXAMPLE
        Sign-ProfileScript
    #>
    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
        [string]$CertSubject = '*PowerShell*',
        [string]$TimestampServer = 'http://timestamp.digicert.com'
    )

    $profilePath = $PROFILE.CurrentUserAllHosts
    if (-not $profilePath -or -not (Test-Path $profilePath)) {
        $profilePath = $PROFILE.CurrentUserCurrentHost
    }
    if (-not (Test-Path $profilePath)) {
        Write-Host "Profile script not found." -ForegroundColor Yellow
        return $false
    }

    $cert = Get-ChildItem Cert:\CurrentUser\My -CodeSigningCert -ErrorAction SilentlyContinue |
        Where-Object { $_.Subject -like $CertSubject -and $_.NotAfter -gt (Get-Date) } |
        Sort-Object NotAfter -Descending | Select-Object -First 1

    if (-not $cert) {
        Write-Host "No valid code-signing certificate found matching '$CertSubject'." -ForegroundColor Yellow
        Write-Host "Create one with:" -ForegroundColor DarkGray
        Write-Host "  New-SelfSignedCertificate -Type CodeSigningCert -Subject 'CN=PowerShell Profile' -CertStoreLocation Cert:\CurrentUser\My" -ForegroundColor DarkGray
        return $false
    }

    if ($PSCmdlet.ShouldProcess($profilePath, "Sign with cert '$($cert.Subject)'")) {
        try {
            $signParams = @{
                FilePath      = $profilePath
                Certificate   = $cert
                TimeStampServer = $TimestampServer
                HashAlgorithm = 'SHA256'
            }
            $sig = Set-AuthenticodeSignature @signParams
            if ($sig.Status -eq 'Valid') {
                Write-Host "Profile signed successfully." -ForegroundColor Green
                return $true
            } else {
                Write-Host "Signing returned status: $($sig.Status)" -ForegroundColor Yellow
                return $false
            }
        } catch {
            Write-CaughtException -Context "Sign-ProfileScript" -ErrorRecord $_ -Component "Signing" -Level WARN
            return $false
        }
    }
}

#endregion ADDED: CODE SIGNING GUIDANCE
#Legacy starship init example intentionally disabled

#==============================================================================
# PROFILE END
#==============================================================================
# This PowerShell profile is complete and self-contained.
# For support and updates, refer to:
# - Microsoft Learn: https://learn.microsoft.com/powershell/
# - PowerShell Gallery: https://www.powershellgallery.com/
# - PSReadLine: https://github.com/PowerShell/PSReadLine
# - Oh-My-Posh: https://ohmyposh.dev/
#==============================================================================
