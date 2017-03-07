################################################################################################################# 
# (Original by Robert Pearman (WSSMB MVP) )
# Script to Automated Email Reminders when Users Passwords due to Expire. 
# Requires: Windows PowerShell Module for Active Directory 

################################################################################################################## 
# Please Configure the following variables.... 
$smtpServer="smtp.office365.com" 
$SmtpUser = '[o365 email address]'
$smtpPassword = '[password]'
$expireindays = 7 
$from = "[o365 email address]" 
$logging = "Enabled" # Set to Disabled to Disable Logging 
$logFile = "E:\passwordexpirationlog\log.csv" # ie. c:\mylog.csv 
$testing = "Enabled" # Set to Disabled to Email Users 
$testRecipient = "[test email adderss]" 
$Credentials = New-Object System.Management.Automation.PSCredential -ArgumentList $SmtpUser, $($smtpPassword | ConvertTo-SecureString -AsPlainText -Force) 

 
# Check Logging Settings 
if (($logging) -eq "Enabled") 
{ 
    # Test Log File Path 
    $logfilePath = (Test-Path $logFile) 
    if (($logFilePath) -ne "True") 
    { 
        # Create CSV File and Headers 
        New-Item $logfile -ItemType File 
        Add-Content $logfile "Date,Name,EmailAddress,DaystoExpire,ExpiresOn,Notified" 
    } 
} # End Logging Check 
 
# System Settings 
$textEncoding = [System.Text.Encoding]::UTF8 
$date = Get-Date -format ddMMyyyy 
# End System Settings 
 
# Get Users From AD who are Enabled, Passwords Expire and are Not Currently Expired 
Import-Module ActiveDirectory 
$users = get-aduser -filter * -properties Name, PasswordNeverExpires, PasswordExpired, PasswordLastSet, EmailAddress |where {$_.Enabled -eq "True"} | where { $_.PasswordNeverExpires -eq $false } | where { $_.passwordexpired -eq $false } 
$DefaultmaxPasswordAge = (Get-ADDefaultDomainPasswordPolicy).MaxPasswordAge 
 
# Process Each User for Password Expiry 
foreach ($user in $users) 
{ 
    $Name = $user.Name 
    $emailaddress = $user.emailaddress 
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
 
    # Email Subject Set Here 
    $subject="Your password will expire $messageDays" 
   
    # Email Body Set Here, Note You can use HTML, including Images. 
    $body =" 
    Dear $name, 
    <p> Your password will expire $messageDays<br> 
    To change your password:
<ul><li>On a Windows PC, press CTRL+ALT+Delete  and choose Change Password; or</li>
<li>On Mac, connect to Remote Desktop and press CTRL+ALT+FN+DEL.</li>
</ul>
	<p>Thanks, <br>  
	[IT DEPARTMENT NAME and phone number]<br>
    </P> 
	<P> Note: this message was sent automatically.  Please do not reply to this message. </p>" 
 
    
    # If Testing Is Enabled - Email Administrator 
    if (($testing) -eq "Enabled") 
    { 
        $emailaddress = $testRecipient 
    } # End Testing 
 
    # If a user has no email address listed 
    if (($emailaddress) -eq $null) 
    { 
        $emailaddress = $testRecipient     
    }# End No Valid Email 
 
    # Send Email Message 
    if (($daystoexpire -ge "0") -and ($daystoexpire -lt $expireindays)) 
    { 
        $sent = "Yes" 
        # If Logging is Enabled Log Details 
        if (($logging) -eq "Enabled") 
        { 
            Add-Content $logfile "$date,$Name,$emailaddress,$daystoExpire,$expireson,$sent"  
        } 
        # Send Email Message 
        Send-Mailmessage -smtpServer $smtpServer -from $from -to $emailaddress -subject $subject -body $body -bodyasHTML -priority High -Encoding $textEncoding -UseSsl -Credential $Credentials 
 
    } # End Send Message 
    else # Log Non Expiring Password 
    { 
        $sent = "No" 
        # If Logging is Enabled Log Details 
        if (($logging) -eq "Enabled") 
        { 
            Add-Content $logfile "$date,$Name,$emailaddress,$daystoExpire,$expireson,$sent"  
        }         
    } 
     
} # End User Processing 
 
 
 
# End