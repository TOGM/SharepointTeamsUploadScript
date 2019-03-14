
$clientId = "" 
$secret = ""
$SharepointSiteName = ""
$domain = "contoso.sharepoint.com"
$url = "https://$domain/sites/$SharepointSiteName"
$identifier = "00000003-0000-0ff1-ce00-000000000000" #this is a static GUID for Sharepoint DO NOT CHANGE
$redirecturi = "" #you set this in appregnew.aspx

#Variables
$FolderName = $env:COMPUTERNAME
$SharepointFolderPath ='Shared%20Documents/General/$FolderName'
$UploadFolderPath = "C:\test\logs"

function Get-AccessToken(){
    Param(
    [string]$clientId,
    [string]$secret,
    [string]$redirecturi,
    [string]$domain,
    [string]$url
    )


    $realm = ""
    $headers = @{Authorization = "Bearer "} 
    try { 
        $x = Invoke-WebRequest -Uri "$($url)/_vti_bin/client.svc" -Headers $headers -Method POST -UseBasicParsing
    } catch {
        #We will get a 401 here
          $realm = $_.Exception.Response.Headers["WWW-Authenticate"].Substring(7).Split(",")[0].Split("=")[1].Trim("`"")
    }

    [System.Reflection.Assembly]::LoadWithPartialName("System.Web") | Out-Null
    $body = "grant_type=client_credentials"
    $body += "&client_id=" +[System.Web.HttpUtility]::UrlEncode( $clientId + "@" + $realm)
    $body += "&client_secret=" +[System.Web.HttpUtility]::UrlEncode( $secret)
    $body += "&redirect_uri=" +[System.Web.HttpUtility]::UrlEncode( $redirecturi)
    $body += "&resource=" +[System.Web.HttpUtility]::UrlEncode($identifier + "/" + $domain + "@" + $realm)

    $or = Invoke-WebRequest -Uri "https://accounts.accesscontrol.windows.net/$realm/tokens/OAuth/2" `
        -Method Post -Body $body `
        -ContentType "application/x-www-form-urlencoded"
    $json = $or.Content | ConvertFrom-Json
    return $json.access_token
}

$accesstoken = Get-AccessToken -clientId $clientId -secret $secret -redirecturi $redirecturi -url $url -domain $domain

$headers = @{
    Authorization = "Bearer " + $accesstoken;
    accept ="application/json;odata=verbose"
}
$ContentType = "application/json;odata=verbose"

#Create Folder of Computer
$createfolderURL = "$url/_api/Web/Folders/add('$SharepointFolderPath')"
Invoke-RestMethod -ContentType $ContentType -Method post -uri $createfolderURL -headers $headers

$UploadFiles = Get-Childitem -Path $UploadFolderPath -af

Foreach ($file in $UploadFiles){   
    $fileUploadURL = "$url/_api/web/GetFolderByServerRelativePath(decodedurl='/sites/$SharepointSiteName/$SharepointFolderPath')/files/add(overwrite=true,url='$($file.Name)')"
    Invoke-RestMethod -ContentType $ContentType -Method post -uri $fileUploadURL -infile $file.FullName -Headers $headers
}
