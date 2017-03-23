################################################################################################################# 
# Script will send a balloon notification to desktop for users with expiring passwords.
# Requires: Windows PowerShell Module for Active Directory 
# 
################################################################################################################## 
# Please Configure the following variables.... 
$expireindays = 7 
$logging = "Enabled" # Set to Disabled to Disable Logging 
$logFile = "E:\passwordexpirationlog\balloonlog.csv" # ie. c:\mylog.csv 
# 
################################################################################################################### 
 
# Check Logging Settings 
if (($logging) -eq "Enabled") 
{ 
    # Test Log File Path 
    $logfilePath = (Test-Path $logFile) 
    if (($logFilePath) -ne "True") 
    { 
        # Create CSV File and Headers 
        New-Item $logfile -ItemType File 
        Add-Content $logfile "Date,Name,DaystoExpire,ExpiresOn,Notified" 
    } 
} # End Logging Check 
 
# System Settings 
$textEncoding = [System.Text.Encoding]::UTF8 
$date = Get-Date -format ddMMyyyy 
# End System Settings 
 
# Get Users From AD who are Enabled, Passwords Expire and are Not Currently Expired 
Import-Module ActiveDirectory 
$users = get-aduser -filter * -properties Name, PasswordNeverExpires, PasswordExpired, PasswordLastSet |where {$_.Enabled -eq "True"} | where { $_.PasswordNeverExpires -eq $false } | where { $_.passwordexpired -eq $false } 
$DefaultmaxPasswordAge = (Get-ADDefaultDomainPasswordPolicy).MaxPasswordAge 
 
# Process Each User for Password Expiry 
foreach ($user in $users) 
{ 
    $Name = $user.Name 
    $passwordSetDate = $user.PasswordLastSet 
    $PasswordPol = (Get-AduserResultantPasswordPolicy $user) 
    $sent = "" # Reset Sent Flag 
    # Check for Fine Grained Password 
    if (($PasswordPol) -ne $null) 
    { 
        $maxPasswordAge = ($PasswordPol).MaxPasswordAge 
    } 
    else 
    { 
        # No FGP set to Domain Default 
        $maxPasswordAge = $DefaultmaxPasswordAge 
    } 
 
   
    $expireson = $passwordsetdate + $maxPasswordAge 
    $today = (get-date) 
    $daystoexpire = (New-TimeSpan -Start $today -End $Expireson).Days 
         
    # Set Greeting based on Number of Days to Expiry. 
 
    # Check Number of Days to Expiry 
    $messageDays = $daystoexpire 
 
    if (($messageDays) -gt "1") 
    { 
        $messageDays = "in " + "$daystoexpire" + " days." 
    } 
    else 
    { 
        $messageDays = "today." 
    } 
 
     
    # Send balloon message  
    if (($daystoexpire -ge "0") -and ($daystoexpire -lt $expireindays)) 
    { 
        $sent = "Yes" 
        # If Logging is Enabled Log Details 
        if (($logging) -eq "Enabled") 
        { 
            Add-Content $logfile "$date,$Name,$daystoExpire,$expireson,$sent"  
        } 
        # Send balloon message  
        
		
		[system.Reflection.Assembly]::LoadWithPartialName('System.Windows.Forms') | Out-Null
		$balloon = New-Object System.Windows.Forms.NotifyIcon
		$path = Get-Process -id $pid | Select-Object -ExpandProperty Path
		$icon = [System.Drawing.Icon]::ExtractAssociatedIcon($path)
		$balloon.Icon = $icon
		$balloon.BalloonTipIcon = 'Info'
		$balloon.BalloonTipText = 'Your password expires',$messageDays,'.  Please change your password. If you need assistance, please call the helpdesk.'
		$balloon.BalloonTipTitle = 'Password Change Reminder'
		$balloon.Visible = $true
		$balloon.ShowBalloonTip(10000)
		 
    } # End Send Message 
    else # Log Non Expiring Password 
    { 
        $sent = "No" 
        # If Logging is Enabled Log Details 
        if (($logging) -eq "Enabled") 
        { 
            Add-Content $logfile "$date,$Name,$daystoExpire,$expireson,$sent"  
        }         
    } 
     
} # End User Processing 
 
 
 
# End
